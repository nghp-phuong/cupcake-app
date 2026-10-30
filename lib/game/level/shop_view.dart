import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/customer_art.dart';
import '../../core/constants.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import 'level_characters.dart';
import 'level_art.dart';
import 'level_game.dart';
import 'level_layout.dart';
import 'level_paint.dart';
import 'shop_figure.dart';
import 'shop_look.dart';
import 'staff_view.dart';

/// Trạng thái vẽ của một khách (theo id; đối tượng tái dùng). Vị trí làm mượt để không giật khi session đánh số lại
/// hàng chờ.
class _CustomerView extends ShopFigure {
  int id = -1;
  String sprite = '';
  final List<ui.Image?> images = List<ui.Image?>.filled(4, null);
  int imagesGen = -1;

  LevelCustomer? c;
  CustomerPhase phase = CustomerPhase.entering;
  bool placed = false;
  bool seen = false;

  double x = 0, floor = 0;
  double fromX = 0, fromFloor = 0, fromScale = 1;

  /// Đồng hồ bước đi (nhún) và lắc khi tủ không có món.
  double clock = 0, shake = 0;
  bool moving = false;
  int expr = LevelCharacters.neutral;

  /// Bong bóng lật sang trái đầu (khách đặc biệt khi có thu ngân đứng bên phải).
  bool bubbleLeft = false;

  Offset get head => Offset(drawX, top + height * 0.16);
  Offset get bubble {
    final o = bubbleLeft ? LevelLayout.bubbleOffsetLeft : LevelLayout.bubbleOffset;
    return Offset(drawX + o.dx * scale, top + o.dy * scale);
  }

  @override
  ui.Image? get image {
    final gen = LevelCharacters.generation;
    if (imagesGen != gen) {
      imagesGen = gen;
      for (var e = 0; e < 4; e++) {
        images[e] = LevelCharacters.cached(sprite, e);
      }
      // Ảnh đã bị bỏ khỏi cache (nạp sẵn màn khác trong lúc màn này còn sống) → xin nạp lại.
      if (images[0] == null && !LevelCharacters.isMissing(sprite, LevelCharacters.neutral)) {
        LevelCharacters.preload([(sprite, LevelCharacters.neutral)], urgent: true);
      }
    }
    final want = images[expr];
    if (want != null) return want;
    // Nét mặt này chưa nạp: tạm dùng nét mặt khác của cùng nhân vật (không bao giờ vẽ nhân vật bằng code).
    for (final img in images) {
      if (img != null) return img;
    }
    return null;
  }
}

/// Sân tiệm (y 0–440): nền `shop_base_empty` (tủ kính trống có sẵn trong ảnh), khách (ảnh nhân vật, giải mã sẵn ở cỡ
/// hiển thị), bánh trên hai tầng kệ của tủ, bong bóng ý nghĩ gọi món + vòng kiên nhẫn. Chạm khách ở quầy → `sell`;
/// khách đặc biệt → `onSpecialTap`.
///
/// Đồ mua thêm ([ShopLook]): bàn ghế + cây (sau quầy, xếp theo độ sâu cùng khách), kệ bánh tầng + đồ trang trí quầy
/// (trên quầy, đè lên khách); các ô tủ cuối nằm trên kệ tầng.
///
/// Nhân viên đã thuê ([staff], GĐ4) là hình cùng loại với khách: xếp độ sâu chung (cùng tỉ lệ thì khách che nhân
/// viên), cắt cùng [LevelLayout.customerClip]; vòng tiến độ thợ bánh vẽ sau mặt tủ, trước bong bóng.
///
/// Thứ tự vẽ: nền → khách + bàn ghế + cây (cắt theo [LevelLayout.customerClip]) → đồ trang trí quầy → mảng tủ của
/// chính ảnh nền vẽ lại đè lên khách (cắt theo [LevelLayout.caseOutline]: nhìn liền mạch, chỉ một tủ) → bánh (tủ +
/// kệ tầng) + vệt sáng kính + huy hiệu số → bong bóng.
///
/// Sức chứa ô (`wideCase`: 6 → 8 → 10) thấy được trong tủ: mỗi tầng kệ vẽ tới 3 / 4 / 5 cái ([caseShelfCapacityFor]);
/// quá 3 cái một tầng thì bánh nhỏ lại và xếp hai hàng (hàng sau nhô giữa khe hàng trước).
class ShopView {
  ShopView(this.game);

  final LevelGame game;
  LevelSession get session => game.session;
  ShopLook get look => game.look;

  final Map<int, _CustomerView> _byId = {};
  final List<_CustomerView> _views = [];
  final List<_CustomerView> _pool = [];
  final List<ShopFigure> _order = [];

  /// Nhân viên trong cảnh (đồng bộ ở [update] từ `LevelGame.staffPoses`).
  late final StaffView staff = StaffView(customerSpot: _spotOf);

  (double, double, double)? _spotOf(int id) {
    final v = _byId[id];
    return v == null ? null : (v.x, v.floor, v.scale);
  }

  ui.Picture? _casePicture;
  int _caseRevision = -1;
  int _caseArt = -1;
  ShopLook? _caseLook;
  ui.Image? _caseStandImage;
  double _caseShake = 0;

  // Hình tĩnh dựng một lần (giữ tới khi gỡ game).
  GameArt? _caseFrameArt, _caseShineArt, _bubbleFallback, _bubbleFallbackSmall, _starFallback;
  GameArt? _standFallback, _standPlateFallback, _tableFallback;
  final Map<int, GameArt> _badges = {};
  String? _badgeFont;

  final Map<RecipeId, CakeVisual> _visuals = {};

  static final Paint _bgPaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _spritePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  /// Màu vòng kiên nhẫn theo 21 mức (bạc hà → vàng bơ → đỏ), tính sẵn.
  static final List<Color> _ringColors = [
    for (var i = 0; i <= 20; i++)
      () {
        final f = i / 20;
        if (f >= 0.6) return Color.lerp(AppColors.butter, AppColors.mint, (f - 0.6) / 0.4)!;
        if (f >= LevelCustomer.sadBelow) return Color.lerp(AppColors.bad, AppColors.butter, (f - LevelCustomer.sadBelow) / (0.6 - LevelCustomer.sadBelow))!;
        return AppColors.bad;
      }(),
  ];

  int get viewCount => _views.length;

  void reset() {
    for (final v in _views) {
      v.c = null;
      _pool.add(v);
    }
    _views.clear();
    _byId.clear();
    staff.reset();
    _casePicture?.dispose();
    _casePicture = null;
    _caseRevision = -1;
  }

  void dispose() {
    reset();
    for (final a in [
      _caseFrameArt, _caseShineArt, _bubbleFallback, _bubbleFallbackSmall, _starFallback, //
      _standFallback, _standPlateFallback, _tableFallback, ..._badges.values,
    ]) {
      a?.dispose();
    }
    _caseFrameArt = _caseShineArt = _bubbleFallback = _bubbleFallbackSmall = _starFallback = null;
    _standFallback = _standPlateFallback = _tableFallback = null;
    _badges.clear();
  }

  void shakeCase() => _caseShake = 0.5;

  /// Đầu khách [id] (null nếu khách đã rời cảnh).
  Offset? headOf(int id) => _byId[id]?.head;

  /// Tâm ô tủ đang chứa món [r] (ô cuối cùng có món; không có → giữa tủ).
  Offset cellCenterOf(RecipeId r) {
    final dc = session.displayCase;
    for (var i = dc.slots - 1; i >= 0; i--) {
      if (dc.items[i].recipe == r) return slotCakeCenter(i);
    }
    return LevelLayout.caseGlass.center;
  }

  /// Khung ô tủ đang chứa món [r] (cột trong lòng kính, đủ hai tầng kệ; ô trên kệ tầng → các tầng của ô); null nếu tủ
  /// không có món [r].
  Rect? slotFrameOf(RecipeId r) {
    final dc = session.displayCase;
    for (var i = dc.slots - 1; i >= 0; i--) {
      if (dc.items[i].recipe != r) continue;
      final main = look.mainSlots(dc.slots);
      if (i < main) return caseCell(i, main);
      final (first, second) = _standTiersOf(i - main);
      final lower = standTier(first), upper = standTier(second ?? first);
      final half = _standHalfW(0);
      return Rect.fromLTRB(lower.dx - half, math.min(lower.dy, upper.dy) - LevelLayout.standCake - 6, lower.dx + half, math.max(lower.dy, upper.dy) + 6);
    }
    return null;
  }

  /// Tâm cái bánh "đại diện" (cái đầu ở tầng dưới) của ô tủ [i]: trong tủ kính hoặc trên kệ tầng.
  Offset slotCakeCenter(int i) {
    final main = look.mainSlots(session.displayCase.slots);
    if (i < main) return caseCakeCenter(caseCell(i, main));
    final t = standTier(_standTiersOf(i - main).$1);
    return Offset(t.dx, t.dy - LevelLayout.standCake / 2);
  }

  /// Huy hiệu số của ô tủ [i] có [count] cái.
  Offset slotBadgeAt(int i, int count) {
    final main = look.mainSlots(session.displayCase.slots);
    final per = _perShelf;
    if (i < main) return caseBadgeAt(caseCell(i, main), count, perShelf: per);
    final (first, second) = _standTiersOf(i - main);
    final tier = second != null && count > per ? second : first;
    final t = standTier(tier);
    return Offset(t.dx + _standHalfW(tier) * 0.8, t.dy - LevelLayout.standCake * 1.02);
  }

  /// Số bánh vẽ tối đa trên một tầng kệ (tủ hoặc kệ tầng) theo sức chứa ô của lượt chơi: 3 (ô 6) · 4 (ô 8) · 5 (ô 10).
  int get _perShelf => caseShelfCapacityFor(session.displayCase.slotCapacity);

  // ------------------------------------------------------------------ Kệ bánh tầng

  /// Tầng [tier] (0 dưới, 1 trên) của kệ: (tâm ngang, mặt tầng) — chỗ đáy bánh.
  static Offset standTier(int tier) {
    const r = LevelLayout.standRect;
    return Offset(r.center.dx, r.top + r.height * (tier == 0 ? LevelLayout.standLowerY : LevelLayout.standUpperY));
  }

  static double _standHalfW(int tier) =>
      LevelLayout.standRect.width * (tier == 0 ? LevelLayout.standLowerHalfW : LevelLayout.standUpperHalfW);

  /// Các tầng mà ô thứ [j] của kệ dùng (tầng đầu đầy trước): kệ 1 ô → cả hai tầng; kệ 2 ô → mỗi ô một tầng.
  (int, int?) _standTiersOf(int j) => look.standSlots <= 1 ? (0, 1) : (j.clamp(0, 1), null);

  // ------------------------------------------------------------------ Khách

  _CustomerView _obtain(LevelCustomer c) {
    final v = _pool.isNotEmpty ? _pool.removeLast() : _CustomerView();
    v
      ..id = c.id
      ..sprite = CustomerArt.spriteId(c.look)
      ..imagesGen = -1
      ..phase = c.phase
      ..placed = false
      ..depthKey = c.id
      ..clock = 0
      ..shake = 0
      ..alpha = 0;
    for (var e = 0; e < 4; e++) {
      v.images[e] = null;
    }
    _byId[c.id] = v;
    _views.add(v);
    if (LevelCharacters.cached(v.sprite, LevelCharacters.neutral) == null) {
      LevelCharacters.preload([(v.sprite, LevelCharacters.neutral)], urgent: true);
    }
    return v;
  }

  double _tx = 0, _tf = 0, _ts = 1;

  void _set(double x, double floor, double scale) {
    _tx = x;
    _tf = floor;
    _ts = scale;
  }

  void _lerpTo(double x0, double f0, double s0, double x1, double f1, double s1, double t) {
    _tx = x0 + (x1 - x0) * t;
    _tf = f0 + (f1 - f0) * t;
    _ts = s0 + (s1 - s0) * t;
  }

  /// Vị trí đích của khách [c] ở khung này (từ pha + chỗ + phaseT) → [_tx], [_tf], [_ts].
  void _target(LevelCustomer c, _CustomerView v, int spots) {
    final t = c.phaseT.clamp(0.0, 1.0);
    switch (c.phase) {
      case CustomerPhase.entering:
        final e = easeInOut(t);
        if (c.isSpecial) {
          _lerpTo(LevelLayout.doorX, LevelLayout.doorFloor, LevelLayout.doorScale, LevelLayout.specialX, LevelLayout.specialFloor,
              LevelLayout.counterScale, e);
        } else {
          final (qx, qs) = _queueSpot(c.slot);
          _lerpTo(LevelLayout.doorX, LevelLayout.doorFloor, LevelLayout.doorScale, qx, LevelLayout.floorFor(qs), qs, e);
        }
      case CustomerPhase.queued:
        final e = easeInOut(t);
        final (fx, fs) = _queueSpot(c.slot + 1);
        final (qx, qs) = _queueSpot(c.slot);
        _lerpTo(fx, LevelLayout.floorFor(fs), fs, qx, LevelLayout.floorFor(qs), qs, e);
      case CustomerPhase.atCounter:
        if (c.isSpecial) {
          _set(LevelLayout.specialX, LevelLayout.specialFloor, LevelLayout.counterScale);
        } else {
          final e = easeInOut(t);
          final (qx, qs) = _queueSpot(0);
          _lerpTo(qx, LevelLayout.floorFor(qs), qs, LevelLayout.counterX(c.slot, spots), LevelLayout.counterFloor,
              LevelLayout.counterScale, e);
        }
      case CustomerPhase.leavingHappy:
      case CustomerPhase.leavingSad:
        if (c.turnedAway) {
          // Ló vào cửa rồi quay đi.
          _set(LevelLayout.doorX - math.sin(t * math.pi) * 120, LevelLayout.doorFloor, LevelLayout.doorScale);
        } else {
          _lerpTo(v.fromX, v.fromFloor, v.fromScale, LevelLayout.doorX, LevelLayout.doorFloor, LevelLayout.doorScale, t * t);
        }
    }
  }

  (double, double) _queueSpot(int k) => LevelLayout.queueSpot(k, stand: look.caseStand, tables: look.cafeTables);

  int _expression(LevelCustomer c) {
    switch (c.phase) {
      case CustomerPhase.leavingHappy:
        return LevelCharacters.joy;
      case CustomerPhase.leavingSad:
        return LevelCharacters.sad;
      default:
        if (c.patienceFrac < LevelCustomer.sadBelow) return LevelCharacters.sad;
        if (c.phase == CustomerPhase.atCounter && !c.isSpecial && _caseHas(c)) return LevelCharacters.smile;
        return LevelCharacters.neutral;
    }
  }

  bool _caseHas(LevelCustomer c) {
    final dc = session.displayCase;
    for (final w in c.wants) {
      if (dc.countOf(w) > 0) return true;
    }
    return false;
  }

  void update(double dt) {
    staff.update(dt, game.staffPoses, festive: game.festiveOutfits);
    for (final v in _views) {
      v.seen = false;
    }
    final list = session.customers;
    final spots = session.tuning.counterSpots;
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      final v = _byId[c.id] ?? _obtain(c);
      v
        ..seen = true
        ..c = c;
      if (c.phase != v.phase) {
        if (c.isLeaving) {
          v
            ..fromX = v.x
            ..fromFloor = v.floor
            ..fromScale = v.scale;
        }
        v.phase = c.phase;
      }
      _target(c, v, spots);
      if (!v.placed) {
        v
          ..x = _tx
          ..floor = _tf
          ..scale = _ts
          ..placed = true;
      } else {
        v
          ..x = approach(v.x, _tx, dt, speed: 18)
          ..floor = approach(v.floor, _tf, dt, speed: 18)
          ..scale = approach(v.scale, _ts, dt, speed: 18);
      }
      final t = c.phaseT;
      v.moving = c.phase == CustomerPhase.entering || c.isLeaving || t < 1;
      v.clock = v.moving ? v.clock + dt : 0;
      if (v.shake > 0) v.shake = math.max(0, v.shake - dt);
      v.expr = _expression(c);
      v.bubbleLeft = c.isSpecial && staff.hasCashier;
      v.depth = v.scale;
      v.alpha = switch (c.phase) {
        CustomerPhase.entering => (t / 0.15).clamp(0.0, 1.0),
        CustomerPhase.leavingHappy || CustomerPhase.leavingSad => (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0),
        _ => 1.0,
      };
      // Hình học khung ảnh.
      final h = LevelLayout.customerHeight * v.scale;
      final bob = v.moving ? -(math.sin(v.clock * 9)).abs() * 5 * v.scale : 0.0;
      v
        ..height = h
        ..top = v.floor - h + bob
        ..drawX = v.x + (v.shake > 0 ? math.sin(v.shake * 45) * 7 * (v.shake / 0.45) : 0);
    }
    for (var i = _views.length - 1; i >= 0; i--) {
      final v = _views[i];
      if (v.seen) continue;
      _views.removeAt(i);
      _byId.remove(v.id);
      v.c = null;
      _pool.add(v);
    }
    if (_caseShake > 0) _caseShake = math.max(0, _caseShake - dt);
  }

  // ------------------------------------------------------------------ Vẽ

  void paint(Canvas canvas) {
    final bg = LevelArt.shopBase.image;
    _paintBackground(canvas, bg);

    // Quầng vàng sau khách đặc biệt.
    for (final v in _views) {
      final c = v.c;
      if (c == null || !c.isSpecial || c.isLeaving) continue;
      final pulse = 0.55 + 0.25 * math.sin(game.time * 3);
      paintGlow(canvas, Rect.fromCenter(center: Offset(v.drawX, v.top + v.height * 0.32), width: v.height * 0.62, height: v.height * 0.62), pulse * v.alpha);
    }

    _order
      ..clear()
      ..addAll(_views)
      ..addAll(staff.figures)
      ..sort(ShopFigure.byDepth);
    canvas.save();
    canvas.clipPath(LevelLayout.customerClip);
    // Bàn ghế + cây sau quầy xen giữa khách theo độ sâu (xa → vẽ trước).
    final props = _props;
    var p = 0;
    for (final v in _order) {
      while (p < props.length && props[p].$1 < v.depth) {
        _paintProp(canvas, props[p].$2);
        p++;
      }
      final img = v.image;
      if (img == null || v.alpha <= 0) continue;
      final w = v.height * 0.75;
      _spritePaint.color = Color.fromRGBO(0, 0, 0, v.alpha);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(v.drawX - w / 2, v.top, w, v.height),
        _spritePaint,
      );
    }
    for (; p < props.length; p++) {
      _paintProp(canvas, props[p].$2);
    }
    canvas.restore();

    _paintCounterDecor(canvas);
    _paintCase(canvas, bg);
    game.boosterFx.paintCase(canvas);
    staff.paintOverlays(canvas);

    for (final v in _views) {
      final c = v.c;
      if (c == null || c.phase != CustomerPhase.atCounter || c.phaseT < 0.95) continue;
      _paintBubble(canvas, v, c);
    }
    game.boosterFx.paintIcons(canvas);
  }

  static const Rect _shopFrame = Rect.fromLTWH(0, 0, 1280, LevelLayout.kitchenTop);

  // ------------------------------------------------------------------ Đồ sau quầy / trên quầy

  static const int _plantProp = -1;

  /// (độ sâu, mã) của đồ sau quầy theo [look], xa trước: mã ≥ 0 = bộ bàn ghế thứ mấy, [_plantProp] = cây. Dựng lại khi
  /// look đổi (không cấp phát mỗi khung).
  List<(double, int)> get _props {
    final l = look;
    if (!identical(l, _propsLook)) {
      _propsLook = l;
      _propsList = [
        if (l.cafeTables)
          for (var i = 0; i < LevelLayout.tableX.length; i++) (LevelLayout.tableDepth, i),
        if (l.plantDecor != null) (LevelLayout.plantDepth, _plantProp),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
    }
    return _propsList;
  }

  ShopLook? _propsLook;
  List<(double, int)> _propsList = const [];

  static const double _tableAspect = 309 / 420;

  /// Khung ảnh bộ bàn ghế thứ [i] (toạ độ khung).
  static Rect tableRect(int i) {
    const w = LevelLayout.tableWidth, h = w * _tableAspect;
    return Rect.fromLTWH(LevelLayout.tableX[i] - w / 2, LevelLayout.tableFloor - h, w, h);
  }

  void _paintProp(Canvas canvas, int id) {
    if (id == _plantProp) {
      final d = look.plantDecor;
      final img = d == null ? null : ArtSprites.decor(d).image;
      if (img != null) drawArt(canvas, img, LevelLayout.plantRect);
      return;
    }
    final r = tableRect(id);
    final img = LevelArt.image(LevelArtId.cafeTable);
    if (img != null) {
      drawArt(canvas, img, r);
    } else {
      final art = _tableFallback ??= buildCafeTableFallback(r.size);
      drawPictureAt(canvas, art.picture, r.topLeft - art.origin);
    }
  }

  void _paintCounterDecor(Canvas canvas) {
    final d = look.counterDecor;
    if (d == null) return;
    final img = ArtSprites.decor(d).image;
    if (img == null) return;
    const r = LevelLayout.counterDecorRect;
    paintShadow(canvas, Offset(r.center.dx, r.bottom - 6), r.width * 0.34, 5, alpha: 0.18);
    drawArt(canvas, img, r);
  }

  /// Vùng [frame] (toạ độ khung) → vùng tương ứng trong ảnh nền [img] (dải ảnh bắt đầu ở [LevelLayout.shopArtTop]).
  static Rect _artSrc(ui.Image img, Rect frame) {
    final k = img.height / 720;
    return Rect.fromLTRB(frame.left * k, (frame.top + LevelLayout.shopArtTop) * k, frame.right * k, (frame.bottom + LevelLayout.shopArtTop) * k);
  }

  void _paintBackground(Canvas canvas, ui.Image? img) {
    if (img == null) {
      final art = cachedArt('lvShopFallback', buildShopFallback);
      canvas.drawPicture(art.picture);
      return;
    }
    canvas.drawImageRect(img, _artSrc(img, _shopFrame), _shopFrame, _bgPaint);
  }

  void _paintCase(Canvas canvas, ui.Image? bg) {
    // Mặt tủ che khách: chính mảng tủ của ảnh nền (không vẽ tủ thứ hai); chưa có ảnh → tủ vẽ code cùng hình học.
    if (bg != null) {
      canvas.save();
      canvas.clipPath(LevelLayout.caseOutline);
      canvas.drawImageRect(bg, _artSrc(bg, LevelLayout.caseRect), LevelLayout.caseRect, _bgPaint);
      canvas.restore();
    } else {
      canvas.drawPicture((_caseFrameArt ??= buildCaseFrameArt()).picture);
    }
    final dc = session.displayCase;
    final l = look;
    final standImage = l.caseStand ? LevelArt.image(LevelArtId.caseStand) : null;
    canvas.save();
    if (_caseShake > 0) canvas.translate(math.sin(_caseShake * 50) * 4 * (_caseShake / 0.5), 0);
    if (_casePicture == null ||
        dc.revision != _caseRevision ||
        game.artGeneration != _caseArt ||
        !identical(l, _caseLook) ||
        !identical(standImage, _caseStandImage)) {
      _caseRevision = dc.revision;
      _caseArt = game.artGeneration;
      _caseLook = l;
      _caseStandImage = standImage;
      _casePicture?.dispose();
      _casePicture = recordArt((c) => _recordCase(c, dc, standImage));
    }
    canvas.drawPicture(_casePicture!);
    canvas.drawPicture((_caseShineArt ??= buildCaseShineArt()).picture);
    final font = game.text.fontFamily;
    if (font != _badgeFont) {
      _badgeFont = font;
      for (final a in _badges.values) {
        a.dispose();
      }
      _badges.clear();
    }
    for (var i = 0; i < dc.slots; i++) {
      final n = dc.items[i].count;
      if (n <= 0) continue;
      final badge = _badges[n] ??= buildCountBadge(game.text, n);
      drawPictureAt(canvas, badge.picture, slotBadgeAt(i, n) - badge.origin);
    }
    canvas.restore();
  }

  /// Bánh trong tủ (ghi một lần mỗi khi tủ đổi / có ảnh mới / look đổi): mỗi ô = một cột, kệ dưới đầy trước rồi tới
  /// kệ trên; mỗi tầng tối đa [_perShelf] cái (ô `wideCase` 8 / 10 cái → 4 / 5 cái một tầng, xếp hai hàng chặt). Các
  /// ô cuối nằm trên kệ bánh tầng nếu [look] có kệ.
  void _recordCase(Canvas canvas, DisplayCase dc, ui.Image? standImage) {
    final main = look.mainSlots(dc.slots);
    final per = _perShelf;
    if (main < dc.slots) _recordStand(canvas, dc, main, standImage);
    for (var i = 0; i < main; i++) {
      final slot = dc.items[i];
      final cell = caseCell(i, main);
      final s = caseCakeSize(cell);
      final recipe = slot.recipe;
      if (recipe == null || slot.isEmpty) {
        // Ô trống: giấy lót ren mờ trên kệ dưới.
        final doily = Rect.fromCenter(center: Offset(cell.center.dx, LevelLayout.lowerShelfY - 2), width: s * 1.5, height: s * 0.3);
        canvas.drawOval(doily, fill(const Color(0x40FFFFFF)));
        canvas.drawOval(doily, stroke(SLColors.pencil, 1.4));
        continue;
      }
      final n = math.min(slot.count, per * 2);
      // Kệ trên trước (nằm sau, cao hơn), rồi kệ dưới.
      // Kệ trên nhìn gần ngang tầm mắt (mặt kệ mỏng hơn) → cái ở sau nhô lên ít hơn.
      // Cái thứ j của ô (thứ tự vào tủ) ↔ topping thật `slot.toppingAt(j)`: kệ dưới 0..per−1, kệ trên per..n−1.
      for (final (shelf, k, depth, first) in [
        (LevelLayout.upperShelfY, n - per, 0.4, per),
        (LevelLayout.lowerShelfY, math.min(n, per), 1.0, 0),
      ]) {
        if (k <= 0) continue;
        paintShadow(canvas, Offset(cell.center.dx, shelf - 2), s * (k >= 2 ? 1.7 : 1.05), s * 0.2, alpha: 0.18);
        final w = s * caseShelfCakeScale(k);
        final stack = caseShelfStack[k];
        for (var j = 0; j < stack.length; j++) {
          final o = stack[j];
          _paintCake(canvas, Rect.fromCenter(center: Offset(cell.center.dx + o.dx * s, shelf - w / 2 + o.dy * depth * s), width: w, height: w),
              recipe, topping: _toppingOf(slot, first + j));
        }
      }
    }
  }

  /// Kệ bánh tầng (ảnh hoặc hình code dự phòng) + bánh của các ô từ [main] trên đó: tầng dưới → dải đĩa tầng trên vẽ
  /// lại đè lên (bánh tầng dưới nằm dưới tầng trên) → tầng trên.
  void _recordStand(Canvas canvas, DisplayCase dc, int main, ui.Image? img) {
    const r = LevelLayout.standRect;
    paintShadow(canvas, Offset(r.center.dx, r.bottom - 3), r.width * 0.62, 8, alpha: 0.2);
    if (img != null) {
      drawArt(canvas, img, r);
    } else {
      canvas.drawPicture((_standFallback ??= buildCaseStandFallback(r)).picture);
    }
    const s = LevelLayout.standCake;
    final per = _perShelf;
    for (final tier in const [0, 1]) {
      if (tier == 1) {
        // Dải đĩa tầng trên đè lên đầu bánh tầng dưới.
        final band = Rect.fromLTRB(
            r.left, r.top + r.height * LevelLayout.standUpperPlateTop, r.right, r.top + r.height * LevelLayout.standUpperPlateBottom);
        if (img != null) {
          final k = img.height / r.height;
          canvas.drawImageRect(img, Rect.fromLTRB(0, (band.top - r.top) * k, img.width.toDouble(), (band.bottom - r.top) * k), band, _bgPaint);
        } else {
          canvas.drawPicture((_standPlateFallback ??= buildCaseStandFallback(r, upperPlateOnly: true)).picture);
        }
      }
      for (var j = 0; main + j < dc.slots; j++) {
        final slot = dc.items[main + j];
        final recipe = slot.recipe;
        if (recipe == null || slot.isEmpty) continue;
        final (first, second) = _standTiersOf(j);
        final n = math.min(slot.count, second == null ? per : per * 2);
        final k = tier == first ? math.min(n, per) : (tier == second ? n - per : 0);
        if (k <= 0) continue;
        final base = tier == first ? 0 : per;
        final at = standTier(tier);
        paintShadow(canvas, Offset(at.dx, at.dy - 2), s * (k >= 2 ? 1.6 : 1.0), s * 0.18, alpha: 0.16);
        final w = s * caseShelfCakeScale(k);
        final stack = caseShelfStack[k];
        for (var q = 0; q < stack.length; q++) {
          final o = stack[q];
          _paintCake(canvas, Rect.fromCenter(center: Offset(at.dx + o.dx * s, at.dy - w / 2 + o.dy * 0.6 * s), width: w, height: w), recipe,
              topping: _toppingOf(slot, base + q));
        }
      }
    }
  }

  /// Topping của cái thứ [j] trong ô [slot] nếu KHÁC topping chuẩn (null = chuẩn → ảnh món như cũ).
  static ToppingId? _toppingOf(CaseSlot slot, int j) => j < slot.count && !slot.isDefaultToppingAt(j) ? slot.toppingAt(j) : null;

  /// Topping của cái mới nhất của món [r] trong tủ nếu khác topping chuẩn (bánh bay vào tủ — mẻ vừa xong).
  ToppingId? newestToppingOf(RecipeId r) {
    final dc = session.displayCase;
    for (var i = dc.slots - 1; i >= 0; i--) {
      final slot = dc.items[i];
      if (slot.recipe == r && slot.count > 0) return _toppingOf(slot, slot.count - 1);
    }
    return null;
  }

  /// Bánh [recipe] trong khung [r]: topping chuẩn → ảnh món; [topping] khác → bánh ghép đế + kem + topping thật.
  void _paintCake(Canvas canvas, Rect r, RecipeId recipe, {ToppingId? topping}) {
    if (topping != null) {
      game.toppedCakes.paint(canvas, r, recipe, topping);
      return;
    }
    final image = ArtSprites.cake(recipe).image;
    if (image != null) {
      drawArt(canvas, image, r);
    } else {
      CakeArt.paint(canvas, r, _visuals[recipe] ??= CakeVisual.recipe(recipe));
    }
  }

  /// Ảnh bong bóng ý nghĩ (320×270): tâm thân bong bóng ở tỉ lệ ([_cloudCx], [_cloudCy]) của ảnh.
  static const double _cloudCx = 0.5, _cloudCy = 0.437, _cloudAspect = 270 / 320;

  /// Bong bóng ý nghĩ rộng [w], tâm thân ở [center]; chưa có ảnh → bong bóng tròn vẽ code.
  void _paintCloud(Canvas canvas, ui.Image? img, Offset center, double w, {bool small = false}) {
    if (img != null) {
      final h = w * _cloudAspect;
      drawArt(canvas, img, Rect.fromLTWH(center.dx - w * _cloudCx, center.dy - h * _cloudCy, w, h));
      return;
    }
    final art = small ? (_bubbleFallbackSmall ??= buildBubbleArt(19, seed: 0xB0D)) : (_bubbleFallback ??= buildBubbleArt(LevelLayout.bubbleRadius + 6));
    drawPictureAt(canvas, art.picture, center - art.origin);
  }

  void _paintBubble(Canvas canvas, _CustomerView v, LevelCustomer c) {
    const r = LevelLayout.bubbleRadius;
    const w = LevelLayout.bubbleWidth;
    final center = v.bubble;
    final cloud = LevelArt.image(LevelArtId.thoughtBubble);
    _paintCloud(canvas, cloud, center, w);
    // Vòng kiên nhẫn: rãnh giấy + cung màu (bạc hà → vàng bơ → đỏ) co dần theo chiều kim đồng hồ.
    final frac = c.patienceFrac;
    if (!c.isSpecial && game.boosts.patience) game.boosterFx.paintPatienceHalo(canvas, center, r);
    canvas.drawCircle(center, r, softStroke(SLColors.paperShade, 6));
    if (frac > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, math.pi * 2 * frac, false,
          softStroke(_ringColors[(frac * 20).round().clamp(0, 20)], 5));
    }
    _paintCake(canvas, Rect.fromCircle(center: center, radius: r - 5), c.want);
    if (c.wants.length > 1) {
      // Món thứ hai: bong bóng nhỏ dính mép dưới-phải bong bóng chính (cụm mây ý nghĩ).
      final c2 = center + const Offset(w * 0.38, w * 0.24);
      _paintCloud(canvas, cloud, c2, w * 0.48, small: true);
      _paintCake(canvas, Rect.fromCircle(center: c2, radius: 14), c.wants[1]);
    }
    if (c.isSpecial) {
      final at = center + Offset(-w * 0.44, -r * 0.95 + math.sin(game.time * 4) * 2);
      final badge = LevelArt.image(LevelArtId.specialBadge);
      if (badge != null) {
        drawArt(canvas, badge, Rect.fromCircle(center: at, radius: 18));
      } else {
        final star = _starFallback ??=
            buildStickerDisc(15, AppColors.butter, seed: 0x57A2, inkWidth: 2.2, content: (cv, o) => paintSLIcon(cv, 'star', o, 22));
        drawPictureAt(canvas, star.picture, at - star.origin);
      }
    }
  }

  // ------------------------------------------------------------------ Chạm

  /// Chạm ở sân tiệm. Trả true nếu trúng một khách.
  bool pointerDown(Offset p) {
    _CustomerView? best;
    var bestD = double.infinity;
    for (final v in _views) {
      final c = v.c;
      if (c == null || c.phase != CustomerPhase.atCounter || c.isLeaving) continue;
      if (c.isSpecial && c.inSpecial) continue;
      final body = Rect.fromLTRB(v.drawX - 80, v.top + 4, v.drawX + 80, LevelLayout.counterFloor + 20);
      final hit = body.contains(p) || (p - v.bubble).distance <= LevelLayout.bubbleRadius + 18;
      if (!hit) continue;
      final d = (p.dx - v.drawX).abs();
      if (d < bestD) {
        bestD = d;
        best = v;
      }
    }
    final c = best?.c;
    if (best == null || c == null) return false;
    if (c.isSpecial) {
      game.onSpecialTap?.call(c.id);
      return true;
    }
    final r = session.sell(c.id);
    if (r == SellResult.notInCase) best.shake = 0.45;
    return true;
  }

  /// Khung ảnh của khách [id] đang đứng yên ở quầy (null nếu khách không ở quầy / đang bước lên / đang làm đơn đặc biệt).
  Rect? counterFrameOf(int id) {
    final v = _byId[id];
    final c = v?.c;
    if (v == null || c == null || c.phase != CustomerPhase.atCounter || c.phaseT < 0.95 || c.inSpecial) return null;
    final w = v.height * 0.75;
    return Rect.fromLTWH(v.drawX - w / 2, v.top, w, v.height);
  }

  /// Tâm thân bong bóng gọi món (tâm vòng kiên nhẫn) của khách [id].
  Offset? bubbleOf(int id) => _byId[id]?.bubble;

  /// Điểm chạm vào khách [id] (test).
  Offset? hitPointOf(int id) {
    final v = _byId[id];
    return v == null ? null : Offset(v.drawX, v.top + v.height * 0.3);
  }
}
