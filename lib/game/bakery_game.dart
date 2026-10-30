import 'dart:async';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/art/art_sprites.dart';
import '../core/art/cake_art.dart';
import '../core/catalog.dart';
import '../core/constants.dart';
import '../core/economy.dart';
import '../core/models/bake.dart';
import '../core/models/ids.dart';
import '../core/models/order.dart';
import '../core/models/recipe.dart';
import 'components/backdrop.dart';
import 'components/effects.dart';
import 'components/game_paint.dart';
import 'logic/bake_meter.dart';
import 'logic/bake_record.dart';
import 'logic/station_setup.dart';
import 'stations/bake_station.dart';
import 'stations/box_station.dart';
import 'stations/frost_station.dart';
import 'stations/mix_station.dart';
import 'stations/mould_station.dart';
import 'stations/station.dart';
import 'stations/topping_station.dart';

/// Lời nhắn ngắn hiện trên vùng chơi.
enum GameToast { wrongMould }

/// Chuỗi vẽ trên canvas (tên khuôn, topping, hộp, nút Giữ). Widget dựng từ `AppLocalizations`.
class BakeLabels {
  const BakeLabels({required this.mould, required this.topping, required this.box, required this.hold});

  final String Function(MouldType m) mould;
  final String Function(ToppingId t) topping;
  final String Function(BoxType b) box;
  final String hold;

  /// Dự phòng khi chưa có l10n (không hiện cho người chơi trong app thật).
  static final fallback = BakeLabels(mould: (m) => m.name, topping: (t) => t.name, box: (b) => b.name, hold: 'Hold');
}

/// Trạng thái để lớp Flutter phía trên (thanh bước, nút Xong, thẻ hướng dẫn) vẽ theo.
class BakeHud extends ChangeNotifier {
  StationId _station = StationId.mould;
  bool _doneEnabled = false;
  bool _doneVisible = false;
  StationId? _tutorial;
  GameToast? _toast;
  int _toastSerial = 0;
  BakeOutcome? _outcome;

  StationId get station => _station;
  int get stepIndex => _station.index;
  bool get doneEnabled => _doneEnabled;

  /// Trạm có dùng nút Xong (trộn, phủ kem, topping).
  bool get doneVisible => _doneVisible;

  /// Trạm đang hiện thẻ hướng dẫn (null = không).
  StationId? get tutorial => _tutorial;
  GameToast? get toast => _toast;
  int get toastSerial => _toastSerial;

  /// Khác null khi đã xong cả 6 trạm.
  BakeOutcome? get outcome => _outcome;

  void _set({StationId? station, bool? doneEnabled, bool? doneVisible}) {
    var changed = false;
    if (station != null && station != _station) {
      _station = station;
      changed = true;
    }
    if (doneEnabled != null && doneEnabled != _doneEnabled) {
      _doneEnabled = doneEnabled;
      changed = true;
    }
    if (doneVisible != null && doneVisible != _doneVisible) {
      _doneVisible = doneVisible;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _showTutorial(StationId? s) {
    if (_tutorial == s) return;
    _tutorial = s;
    notifyListeners();
  }

  void _showToast(GameToast t) {
    _toast = t;
    _toastSerial++;
    notifyListeners();
  }

  void _clearToast(int serial) {
    if (serial != _toastSerial || _toast == null) return;
    _toast = null;
    notifyListeners();
  }

  void _complete(BakeOutcome o) {
    if (_outcome != null) return;
    _outcome = o;
    notifyListeners();
  }
}

/// Game Flame cho một lần làm bánh: 6 trạm nối tiếp, chỉ đo số thô → [BakeOutcome].
///
/// Đầu vào con trỏ KHÔNG đi qua hệ cử chỉ của Flame: `BakeSessionView` bọc `GameWidget` trong một
/// `Listener` và gọi [pointerDown]/[pointerMove]/[pointerUp] với `localPosition` — Flutter đã đổi
/// toạ độ qua mọi phép biến đổi (FittedBox của `RefFrame`), nên luôn là toạ độ khung 1280×720.
class BakeryGame extends FlameGame {
  BakeryGame({required this.order, required this.modifiers, Set<StationId> tutorialFor = const {}, int? ovenLevel})
      : _tutorialFor = {...tutorialFor},
        ovenLevel = ovenLevel ?? ovenLevelFor(modifiers);

  final Order order;
  final BakeModifiers modifiers;
  final Set<StationId> _tutorialFor;

  /// Cấp lò 1..5 (chọn ảnh lò). Không truyền → suy từ [modifiers] (vùng hoàn hảo của từng cấp lò).
  final int ovenLevel;

  /// Cấp lò có vùng nướng hoàn hảo đúng bằng của [m] (`Economy.ovenTiers`); không khớp → 1.
  static int ovenLevelFor(BakeModifiers m) {
    for (final t in Economy.ovenTiers) {
      if ((t.perfectHalfWidth - m.bakePerfectHalfWidth).abs() < 1e-9) return t.level;
    }
    return 1;
  }

  final BakeHud hud = BakeHud();
  final BakeRecord record = BakeRecord();
  final EffectsLayer effects = EffectsLayer();
  final CanvasText text = CanvasText();

  BakeLabels labels = BakeLabels.fallback;

  Recipe get recipe => Catalog.recipe(order.recipe);

  Station? _current;
  int _index = -1;
  double? _advanceIn;
  double _toastTimer = 0;
  bool _finished = false;

  int? _pointer;
  bool _swallow = false;

  Station? get currentStation => _current;

  /// Đang khoá thao tác (thẻ hướng dẫn đang mở).
  bool get inputLocked => hud.tutorial != null;

  @override
  Color backgroundColor() => AppColors.cream;

  /// Chờ tối đa chừng này giây cho ảnh nền trạm 1 + khay nướng + ảnh các khuôn trước khi vào trạm 1 (quá thì vẫn chạy, vẽ
  /// hình code dự phòng). Trong lúc chờ nền là tờ giấy kem vẽ tay.
  static const double maxArtWait = 1.5;

  /// Ảnh cần có trước khi hiện trạm 1: nền trạm khuôn + khay nướng + các khuôn của ô chọn.
  late final List<ArtRef> _firstArt = [
    ArtSprites.station(StationId.mould),
    ArtSprites.bakingTray,
    for (final m in mouldChoices(recipe.mould, seededRandom(order, 1), unlockLevel: recipe.unlockLevel)) ArtSprites.mould(m),
  ];
  double _artWait = 0;

  /// Đang chờ ảnh của trạm 1 (chưa vào trạm nào).
  bool get waitingForArt => _index < 0;

  /// Ảnh của trạm 1 đã nạp xong hoặc được xác định là thiếu. Hỏi `image` = xin nạp ưu tiên (đưa lên đầu hàng).
  bool get _firstArtSettled => _firstArt.every((r) => r.image != null || r.isMissing);

  @override
  Future<void> onLoad() async {
    // Nạp sẵn ảnh vẽ tay của phiên (không chặn: trạm 1 chờ tối đa [maxArtWait] cho ảnh của nó, các trạm sau chưa
    // có ảnh thì vẽ hình code dự phòng).
    unawaited(ArtSprites.preloadKitchen(ovenLevel: ovenLevel, mould: recipe.mould, batter: recipe.batter, recipe: recipe.id));
    add(KitchenBackdrop(station: () => hud.station, loading: () => waitingForArt));
    add(effects);
  }

  /// Chuỗi + font cho phần chữ vẽ trên canvas: [fontFamily] nội dung, [titleFontFamily] (+ [titleFallback])
  /// tiêu đề (nút Giữ).
  void setLabels(BakeLabels l, {String? fontFamily, String? titleFontFamily, List<String>? titleFallback}) {
    labels = l;
    text
      ..fontFamily = fontFamily
      ..titleFontFamily = titleFontFamily
      ..titleFallback = titleFallback
      ..clear();
  }

  // ------------------------------------------------------------------ Hình bánh theo tiến độ

  /// Độ chín để vẽ (0 sống, 1 vàng, 2 cháy) theo lần thả tay ở trạm nướng.
  double get bakedLevel => bakedVisual(record.bakeRelease, recipe.bakeTarget);

  /// Bánh sau khi nướng (chưa kem).
  CakeVisual get bakedCake => CakeVisual(mould: recipe.mould, batter: recipe.batter, baked: bakedLevel, recipe: recipe.id);

  /// Bánh sau khi phủ kem.
  CakeVisual get frostedCake => bakedCake.copyWith(frosting: order.frosting, frostCoverage: record.frostCoverage);

  // ------------------------------------------------------------------ Vòng đời trạm

  Station _create(StationId id) => switch (id) {
        StationId.mould => MouldStation(this),
        StationId.mix => MixStation(this),
        StationId.bake => BakeStation(this),
        StationId.frost => FrostStation(this),
        StationId.topping => ToppingStation(this),
        StationId.box => BoxStation(this),
      };

  void _enter(int i) {
    _index = i;
    final id = StationId.values[i];
    _current?.leave();
    final s = _create(id);
    _current = s;
    add(s);
    _pointer = null;
    hud._set(station: id, doneVisible: s.usesDone, doneEnabled: false);
    if (_tutorialFor.remove(id)) hud._showTutorial(id);
  }

  /// Trạm hiện tại báo xong; chuyển trạm sau [delay] giây (hoạt cảnh mừng).
  void stationFinished({double delay = 0.8}) {
    if (_advanceIn != null || _finished) return;
    _advanceIn = delay;
  }

  void dismissTutorial() => hud._showTutorial(null);

  void showToast(GameToast t) {
    hud._showToast(t);
    _toastTimer = 1.4;
  }

  /// Nút Xong (lớp Flutter).
  void pressDone() {
    final s = _current;
    if (s == null || inputLocked || !s.acceptsInput || !s.canDone) return;
    s.done();
  }

  @override
  void update(double dt) {
    // Trạm đầu tiên vào ở khung hình (không trong lúc build widget), khi ảnh của nó đã sẵn hoặc chờ quá lâu.
    if (_index < 0) {
      _artWait += dt;
      if (_artWait >= maxArtWait || _firstArtSettled) _enter(0);
    }
    super.update(dt);
    if (_toastTimer > 0) {
      _toastTimer -= dt;
      if (_toastTimer <= 0) hud._clearToast(hud.toastSerial);
    }
    final adv = _advanceIn;
    if (adv != null) {
      final left = adv - dt;
      if (left <= 0) {
        _advanceIn = null;
        if (_index >= StationId.values.length - 1) {
          _finished = true;
          hud._set(doneEnabled: false);
          hud._complete(record.toOutcome());
        } else {
          _enter(_index + 1);
        }
      } else {
        _advanceIn = left;
      }
    }
    final s = _current;
    if (s != null) hud._set(doneEnabled: !_finished && _advanceIn == null && s.acceptsInput && s.canDone);
  }

  // ------------------------------------------------------------------ Con trỏ (toạ độ 1280×720)

  void pointerDown(int pointer, Offset p) {
    if (_pointer != null) return; // chỉ theo một ngón
    _pointer = pointer;
    final s = _current;
    _swallow = s == null || inputLocked || !s.acceptsInput || _advanceIn != null;
    if (!_swallow) s?.pointerDown(p);
  }

  void pointerMove(int pointer, Offset p) {
    if (pointer != _pointer || _swallow) return;
    _current?.pointerMove(p);
  }

  void pointerUp(int pointer, Offset p) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (_swallow) return;
    _current?.pointerUp(p);
  }

  void pointerCancel(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (_swallow) return;
    _current?.pointerCancel();
  }

  @override
  void onRemove() {
    text.clear();
    super.onRemove();
  }
}
