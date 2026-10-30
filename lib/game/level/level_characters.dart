import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/art/characters/character_sprites.dart';
import '../../core/constants.dart';

/// Ảnh nhân vật cho màn chơi level, giải mã MỘT lần ở cỡ hiển thị: [decodeHeight] = [refDecodeHeight] × [pixelScale]
/// px cao (hệ số màn = điểm ảnh thật / px khung 1280×720, làm tròn lên theo bậc [scaleStep], kẹp [minScale]..[maxScale]).
/// Bộ nhớ mỗi ảnh: 1.0× → 264×352 ≈ 370 KB; 1.6× (màn 1080p+) → 422×563 ≈ 950 KB — vẫn dưới 1,2 MB của ảnh gốc
/// 480×640. Chỉ giữ dàn nhân vật của màn đang chơi ([retainOnly] khi nạp sẵn một màn): 15 khách thường × 4 nét mặt +
/// khách đặc biệt của màn × 4 + nhân viên đã thuê × 2 ≈ 70 ảnh ≈ 26 MB (1.0×) / ≈ 66 MB (ca nặng nhất 1.6×). Cùng file
/// ảnh với `CharacterSprites` (`assets/characters/<id>_<expr>.webp`); không có hình vẽ bằng code.
///
/// Nạp bất đồng bộ (tối đa [_maxActive] ảnh cùng lúc). File thiếu / lỗi → coi là thiếu, không nạp lại. [generation]
/// tăng mỗi khi có ảnh mới, để nơi vẽ chỉ tra lại cache khi cần (không dựng chuỗi khoá mỗi khung).
abstract final class LevelCharacters {
  /// Cao khung ảnh khi giải mã ở hệ số màn 1 (khách ở quầy vẽ cao 348 px tham chiếu, `LevelLayout.counterScale`).
  static const refDecodeHeight = 352;

  /// Hệ số màn kẹp trong [minScale]..[maxScale], làm tròn lên theo bậc [scaleStep]: đổi cỡ cửa sổ / xoay máy chỉ giải
  /// mã lại khi sang bậc khác.
  static const minScale = 1.0, maxScale = 1.6, scaleStep = 0.2;

  /// Nét mặt theo chỉ số: 0 neutral, 1 smile, 2 joy, 3 sad.
  static const expressions = CharacterSprites.expressions;
  static const neutral = 0, smile = 1, joy = 2, sad = 3;

  static const _maxActive = 2;

  static AssetBundle _bundle = rootBundle;
  static final _images = <String, ui.Image>{};
  static final _missing = <String>{};
  static final _queue = ListQueue<String>();
  static final _waiters = <String, Completer<void>>{};

  /// Khoá đang giải mã (đã rời hàng chờ).
  static final _active = <String>{};

  /// Khoá đang giải mã nhưng đã bị [retainOnly] bỏ: giải mã xong thì giải phóng luôn, không giữ.
  static final _dropped = <String>{};
  static var _generation = 0;
  static var _loaded = 0;
  static double? _scale;
  static Future<Set<String>?>? _manifest;

  /// Tăng mỗi khi có ảnh mới nạp xong.
  static int get generation => _loaded;

  /// Hệ số màn đang dùng để giải mã. Chưa đặt qua [updatePixelScale] → tính từ cửa sổ chính (`PlatformDispatcher`).
  static double get pixelScale => _scale ??= scaleFor(_viewSize());

  /// Cao khung ảnh khi giải mã ở hệ số màn hiện tại.
  static int get decodeHeight => (refDecodeHeight * pixelScale).round();

  /// Bậc hệ số màn cho cửa sổ [physicalSize] (điểm ảnh thật). Khung 1280×720 co giãn giữ tỉ lệ như `RefFrame`, nên
  /// điểm ảnh thật / px khung = min(rộng / 1280, cao / 720) (đã gồm devicePixelRatio).
  static double scaleFor(ui.Size physicalSize) {
    if (physicalSize.isEmpty) return minScale;
    final k = math.min(physicalSize.width / kRefSize.width, physicalSize.height / kRefSize.height);
    // Lên bậc trên (bớt chút sai số để đúng 1.2 không thành 1.4), rồi kẹp.
    final steps = (k / scaleStep - 1e-6).ceil();
    return (steps * scaleStep * 100).round().clamp(minScale * 100, maxScale * 100) / 100;
  }

  /// Cửa sổ của màn chơi đổi cỡ ([physicalSize] = `View.physicalSize`). Sang bậc khác → giải mã lại các ảnh đang giữ
  /// ở cỡ mới (ảnh cũ vẫn vẽ tới khi ảnh mới xong); cùng bậc → không làm gì.
  static void updatePixelScale(ui.Size physicalSize) {
    final next = scaleFor(physicalSize);
    if (next == pixelScale) return;
    _scale = next;
    for (final key in _images.keys) {
      if (_waiters.containsKey(key)) continue;
      _waiters[key] = Completer<void>();
      _queue.addLast(key);
    }
    _pump();
  }

  static ui.Size _viewSize() {
    final dispatcher = ui.PlatformDispatcher.instance;
    final view = dispatcher.implicitView ?? (dispatcher.views.isEmpty ? null : dispatcher.views.first);
    return view?.physicalSize ?? ui.Size.zero;
  }

  static String _key(String id, int expr) => CharacterSprites.assetPath(id, expressions[expr]);

  /// Ảnh đã giải mã (null nếu chưa nạp / thiếu). Không xếp hàng nạp.
  static ui.Image? cached(String id, int expr) => _images[_key(id, expr)];

  static bool isMissing(String id, int expr) => _missing.contains(_key(id, expr));

  /// Xếp hàng nạp các cặp (id, nét mặt) theo thứ tự; [urgent] → lên đầu hàng. Future xong khi mọi ảnh đã nạp, được
  /// xác định là thiếu hoặc bị [retainOnly] bỏ; không bao giờ báo lỗi, không cần `await`.
  static Future<void> preload(Iterable<(String, int)> sprites, {bool urgent = false}) {
    final waits = <Future<void>>[];
    final list = urgent ? sprites.toList().reversed : sprites;
    for (final (id, expr) in list) {
      final w = _request(_key(id, expr), urgent: urgent);
      if (w != null) waits.add(w);
    }
    return Future.wait(waits);
  }

  /// Bỏ (giải phóng) ảnh của mọi nhân vật không thuộc [ids] — gọi khi nạp sẵn một màn để bộ nhớ chỉ giữ dàn nhân vật
  /// của màn đó. Ảnh ngoài [ids] đang xếp hàng → rút khỏi hàng (Future chờ của nó xong ngay); đang giải mã → xong thì
  /// giải phóng luôn. Nơi vẽ tra lại cache vì [generation] tăng.
  static void retainOnly(Set<String> ids) {
    final keep = {for (final id in ids) for (var e = 0; e < expressions.length; e++) _key(id, e)};
    final unqueued = _queue.length;
    _queue.removeWhere((k) => !keep.contains(k));
    final unwanted = [for (final k in _waiters.keys) if (!keep.contains(k)) k];
    for (final k in unwanted) {
      if (_active.contains(k)) {
        _dropped.add(k);
      } else {
        _waiters.remove(k)!.complete();
      }
    }
    final drop = [for (final k in _images.keys) if (!keep.contains(k)) k];
    for (final k in drop) {
      _images.remove(k)?.dispose();
    }
    if (drop.isNotEmpty || unqueued != _queue.length) _loaded++;
  }

  static Future<void>? _request(String key, {required bool urgent}) {
    if (_images.containsKey(key) || _missing.contains(key)) return null;
    final pending = _waiters[key];
    if (pending != null) {
      // Bị bỏ lúc đang giải mã nhưng lại được xin → giữ lại khi xong.
      _dropped.remove(key);
      if (urgent && _queue.remove(key)) _queue.addFirst(key);
      return pending.future;
    }
    final waiter = _waiters[key] = Completer<void>();
    urgent ? _queue.addFirst(key) : _queue.addLast(key);
    _pump();
    return waiter.future;
  }

  static void _pump() {
    while (_active.length < _maxActive && _queue.isNotEmpty) {
      final key = _queue.removeFirst();
      _active.add(key);
      unawaited(_load(key, _generation));
    }
  }

  static Future<void> _load(String key, int generation) async {
    ui.Image? image;
    final height = decodeHeight;
    try {
      final assets = await (_manifest ??= _loadManifest());
      if (assets != null && assets.contains(key)) {
        final codec = await ui.instantiateImageCodecWithSize(
          await _bundle.loadBuffer(key),
          getTargetSize: (w, h) => h <= height
              ? const ui.TargetImageSize()
              : ui.TargetImageSize(width: (w * height / h).round(), height: height),
        );
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LevelCharacters: bỏ qua $key ($e)');
    }
    if (generation != _generation) {
      image?.dispose();
      return;
    }
    _active.remove(key);
    if (_dropped.remove(key)) {
      image?.dispose();
    } else if (image == null) {
      // Giải mã lại (đổi bậc hệ số màn) mà lỗi → giữ ảnh cũ.
      if (!_images.containsKey(key)) _missing.add(key);
    } else {
      _images.remove(key)?.dispose();
      _images[key] = image;
      _loaded++;
    }
    _waiters.remove(key)?.complete();
    // Hệ số màn đổi trong lúc giải mã → giải mã lại ở cỡ mới.
    if (image != null && height != decodeHeight && _images.containsKey(key)) {
      _waiters[key] = Completer<void>();
      _queue.addLast(key);
    }
    _pump();
  }

  static Future<Set<String>?> _loadManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      return {for (final a in manifest.listAssets()) if (a.startsWith('assets/characters/')) a};
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static int get debugCachedCount => _images.length;

  /// Số ảnh còn xếp hàng chờ giải mã (test).
  @visibleForTesting
  static int get debugQueuedCount => _queue.length;

  /// Xoá cache/hàng chờ; [bundle] thay cho rootBundle (test); [pixelScale] đặt sẵn hệ số màn (null → tính lại từ cửa
  /// sổ chính khi cần).
  @visibleForTesting
  static void debugReset({AssetBundle? bundle, double? pixelScale}) {
    _generation++;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _missing.clear();
    _queue.clear();
    for (final w in _waiters.values) {
      w.complete();
    }
    _waiters.clear();
    _active.clear();
    _dropped.clear();
    _manifest = null;
    _scale = pixelScale;
    _loaded++;
    _bundle = bundle ?? rootBundle;
  }
}
