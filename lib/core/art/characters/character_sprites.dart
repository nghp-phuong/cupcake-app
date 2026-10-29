import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ảnh nhân vật vẽ tay (raster, nền trong suốt) ở `assets/characters/<id>_<expr>.webp`, 480×640 (3:4),
/// nhân vật toàn thân, chân cách đáy ảnh ~5%.
///
/// Nạp bất đồng bộ từ asset bundle (tối đa [_maxActive] ảnh cùng lúc), giải mã thành `ui.Image`, giữ trong
/// cache LRU tối đa [cacheLimit] ảnh (~1,2 MB/ảnh) để máy yếu không tốn RAM. File không có trong
/// AssetManifest hoặc đọc lỗi bị coi là thiếu: không nạp lại, không log ồn — người gọi vẽ hình code dự phòng.
/// [changes] báo mỗi khi có ảnh mới nạp xong để painter vẽ lại.
abstract final class CharacterSprites {
  static const cacheLimit = 24;
  static const _maxActive = 2;
  static const _dir = 'assets/characters/';

  /// Mọi nét mặt có ảnh, theo thứ tự ưu tiên khi cần ảnh tạm.
  static const expressions = ['neutral', 'smile', 'joy', 'sad'];

  static String assetPath(String id, String expr) => '$_dir${id}_$expr.webp';

  /// Báo khi có ảnh mới nạp xong (dùng làm `repaint` cho CustomPainter).
  static Listenable get changes => _changes;
  static final _changes = _SpriteNotifier();

  static AssetBundle _bundle = rootBundle;
  static final _cache = <String, ui.Image>{}; // LinkedHashMap: cuối = dùng gần nhất.
  static final _missing = <String>{};
  static final _queue = ListQueue<String>();
  static final _waiters = <String, Completer<void>>{}; // đang xếp hàng hoặc đang nạp.
  static var _active = 0;
  static var _generation = 0;
  static Future<Set<String>?>? _manifest;

  /// Ảnh của [id] với nét mặt [expr]. Chưa nạp → xếp hàng nạp (ưu tiên) và trả về tạm một nét mặt khác
  /// của cùng nhân vật nếu đã có (tránh nháy sang hình code), không có thì null.
  static ui.Image? image(String id, String expr) {
    final key = assetPath(id, expr);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    _request(key, urgent: true);
    for (final e in expressions) {
      final other = _cache[assetPath(id, e)];
      if (other != null) return other;
    }
    return null;
  }

  /// Ảnh đã được xác định là thiếu (không có file hoặc đọc lỗi).
  static bool isMissing(String id, String expr) => _missing.contains(assetPath(id, expr));

  /// Nạp sẵn các cặp (id, expr) theo thứ tự, không ưu tiên hơn ảnh đang cần vẽ. Future xong khi mọi ảnh
  /// đã nạp hoặc được xác định là thiếu; không bao giờ báo lỗi. Không cần `await` (không chặn UI).
  static Future<void> preload(Iterable<(String, String)> sprites) {
    final waits = <Future<void>>[];
    for (final (id, expr) in sprites) {
      final key = assetPath(id, expr);
      final hit = _cache.remove(key);
      if (hit != null) {
        _cache[key] = hit;
        continue;
      }
      final wait = _request(key, urgent: false);
      if (wait != null) waits.add(wait);
    }
    return Future.wait(waits);
  }

  static Future<void>? _request(String key, {required bool urgent}) {
    if (_missing.contains(key)) return null;
    final pending = _waiters[key];
    if (pending != null) {
      // Đang chờ trong hàng mà giờ cần vẽ ngay → đưa lên đầu.
      if (urgent && _queue.remove(key)) _queue.addFirst(key);
      return pending.future;
    }
    final waiter = _waiters[key] = Completer<void>();
    urgent ? _queue.addFirst(key) : _queue.addLast(key);
    _pump();
    return waiter.future;
  }

  static void _pump() {
    while (_active < _maxActive && _queue.isNotEmpty) {
      _active++;
      unawaited(_load(_queue.removeFirst(), _generation));
    }
  }

  static Future<void> _load(String key, int generation) async {
    ui.Image? image;
    try {
      final assets = await (_manifest ??= _loadManifest());
      if (assets != null && assets.contains(key)) {
        final codec = await ui.instantiateImageCodecFromBuffer(await _bundle.loadBuffer(key));
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } catch (e) {
      // File có trong manifest mà đọc/giải mã lỗi: báo một lần (chỉ bản debug), sau đó dùng hình code.
      if (kDebugMode) debugPrint('CharacterSprites: bỏ qua $key ($e)');
    }
    if (generation != _generation) {
      image?.dispose(); // Đã reset trong lúc nạp.
      return;
    }
    _active--;
    if (image == null) {
      _missing.add(key);
    } else {
      _cache.remove(key)?.dispose();
      _cache[key] = image;
      while (_cache.length > cacheLimit) {
        _cache.remove(_cache.keys.first)!.dispose();
      }
    }
    _waiters.remove(key)?.complete();
    if (image != null) _changes.ping();
    _pump();
  }

  /// Danh sách ảnh nhân vật đóng gói trong app; null nếu không đọc được manifest (vd. test thuần không binding).
  static Future<Set<String>?> _loadManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      return {for (final a in manifest.listAssets()) if (a.startsWith(_dir)) a};
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static int get debugCachedCount => _cache.length;

  /// Xoá cache/hàng chờ; [bundle] thay cho rootBundle (test).
  @visibleForTesting
  static void debugReset({AssetBundle? bundle}) {
    _generation++;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _missing.clear();
    _queue.clear();
    for (final w in _waiters.values) {
      w.complete();
    }
    _waiters.clear();
    _active = 0;
    _manifest = null;
    _bundle = bundle ?? rootBundle;
  }
}

class _SpriteNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
