import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../../ui/sugarleaf/paint/sl_surface.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/bake_meter.dart';
import '../logic/mix_meter.dart';
import 'level_art.dart';
import 'level_game.dart';
import 'level_layout.dart';
import 'level_paint.dart';

/// Độ dài phần đoạn [a]→[b] nằm trong [r] (cắt Liang–Barsky).
double segmentLengthInRect(Offset a, Offset b, Rect r) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  var t0 = 0.0, t1 = 1.0;
  for (final (p, q) in [(-dx, a.dx - r.left), (dx, r.right - a.dx), (-dy, a.dy - r.top), (dy, r.bottom - a.dy)]) {
    if (p == 0) {
      if (q < 0) return 0;
      continue;
    }
    final t = q / p;
    if (p < 0) {
      if (t > t1) return 0;
      if (t > t0) t0 = t;
    } else {
      if (t < t0) return 0;
      if (t < t1) t1 = t;
    }
  }
  return t1 > t0 ? (t1 - t0) * math.sqrt(dx * dx + dy * dy) : 0;
}

/// Bếp nhanh (y 440–720): cột thẻ món + 6 ô trạm (Khuôn · Trộn · Lò · Kem · Topping · Hộp). Mỗi ô chỉ nhận một thao
/// tác ngắn, vùng chạm ≥ 64 px; ô đang chờ thao tác phát sáng nhẹ.
class KitchenView {
  KitchenView(this.game);

  final LevelGame game;
  LevelSession get session => game.session;
  Kitchen get kitchen => session.kitchen;

  final List<double> _cardShake = List<double>.filled(8, 0);
  final List<double> _rowShake = List<double>.filled(3, 0);
  final List<double> _jarPop = List<double>.filled(2, 0);

  // Trộn.
  int? _mixPointer;
  MixMeter? _mix;
  Batch? _mixBatch;
  Offset _mixTip = Offset.zero;

  /// Quãng ngón tay đã kéo trong lần chạm hiện tại (chạm không kéo → hiện gợi ý xoay).
  double _mixMoved = 0;

  /// Giây còn lại của hoạt cảnh gợi ý xoay; [_mixIdle] = giây ở trạm trộn mà chưa khuấy.
  double _mixHint = 0;
  double _mixIdle = 0;

  // Phủ kem.
  int? _frostPointer;
  Offset _frostLast = Offset.zero;
  double _frostDist = 0;
  Batch? _frostBatch;

  // Hình của mẻ ở khu hoàn thiện (độ phủ kem đã chốt, topping đã đặt).
  Batch? _coverBatch;
  double _cover = 1;
  Batch? _toppingBatch;
  final List<ToppingId> _placed = [];

  double _smokeClock = 0;

  final Map<RecipeId, CakeVisual> _visuals = {};

  /// Quãng quẹt cần để phủ đủ kem (~3 đường ngang qua bánh).
  static double get frostNeeded => LevelLayout.frostCake().width * 0.8 * 3;

  /// Độ phủ kem của mẻ đang ở trạm kem (0..1).
  double get frostCoverage => _frostBatch == kitchen.finish ? (_frostDist / frostNeeded).clamp(0.0, 1.0) : 0;

  /// Đang chiếu hoạt cảnh gợi ý xoay (vừa chạm mà không kéo, hoặc đứng yên ở trạm trộn quá 2,5 giây).
  bool get showMixHint => kitchen.prep?.stage == BatchStage.mix && _mixPointer == null && (_mixHint > 0 || _mixIdle > 2.5);

  /// Số vòng đã trộn của mẻ đang ở trạm trộn.
  double get mixTurns => _mixBatch == kitchen.prep ? (_mix?.turns ?? 0) : 0;

  void reset() {
    _mixPointer = null;
    _mix = null;
    _mixBatch = null;
    _frostPointer = null;
    _frostBatch = null;
    _frostDist = 0;
    _coverBatch = null;
    _toppingBatch = null;
    _placed.clear();
    _frostVisBatch = null;
    _toppingVisBatch = null;
    clearArt();
  }

  // ------------------------------------------------------------------ Cập nhật

  void update(double dt) {
    for (var i = 0; i < _cardShake.length; i++) {
      if (_cardShake[i] > 0) _cardShake[i] = math.max(0, _cardShake[i] - dt);
    }
    for (var i = 0; i < _rowShake.length; i++) {
      if (_rowShake[i] > 0) _rowShake[i] = math.max(0, _rowShake[i] - dt);
    }
    for (var i = 0; i < _jarPop.length; i++) {
      if (_jarPop[i] > 0) _jarPop[i] = math.max(0, _jarPop[i] - dt);
    }
    if (_mixHint > 0) _mixHint = math.max(0, _mixHint - dt);
    final mixing = kitchen.prep?.stage == BatchStage.mix;
    _mixIdle = mixing && _mixPointer == null && mixTurns == 0 ? _mixIdle + dt : 0;
    if (!mixing) _mixHint = 0;
    // Mẻ đổi giữa lúc kéo (hết giờ, huỷ…) → nhả thao tác.
    if (_mixPointer != null && kitchen.prep?.stage != BatchStage.mix) _mixPointer = null;
    if (_frostPointer != null && kitchen.finish?.stage != BatchStage.frost) _frostPointer = null;

    // Khói lò cháy / hơi nóng khi đang nướng.
    _smokeClock += dt;
    if (_smokeClock >= 0.35) {
      _smokeClock = 0;
      final ovens = kitchen.ovens;
      for (var i = 0; i < ovens.length; i++) {
        final b = ovens[i];
        if (b == null) continue;
        final r = _ovenRect(i, ovens.length);
        if (b.burnt) {
          game.effects.puff(r.topCenter.translate(0, 10), const Color(0xFF8A7F78), count: 2, size: 18, rise: 60);
        } else if (b.stage == BatchStage.baking && game.time % 1.0 < 0.36) {
          game.effects.puff(r.topCenter.translate(0, 8), const Color(0xFFFFFFFF), count: 1, size: 12, rise: 40);
        }
      }
    }
  }

  // ------------------------------------------------------------------ Chạm

  bool pointerDown(int pointer, Offset p) {
    final menu = session.level.menu;
    final n = menu.length;
    for (var i = 0; i < n; i++) {
      if (!LevelLayout.cardRect(i, n).contains(p)) continue;
      if (session.startBatch(menu[i])) {
        game.effects.sparkle(LevelLayout.tile(LevelLayout.mouldTile).center, count: 8, speed: 140);
      } else if (i < _cardShake.length) {
        _cardShake[i] = 0.4;
      }
      return true;
    }

    final prep = kitchen.prep;
    final finish = kitchen.finish;

    if (prep != null && LevelLayout.cancelPrep().contains(p)) {
      session.cancelPrep();
      _mixPointer = null;
      _mix = null;
      _mixBatch = null;
      _mixHint = 0;
      game.effects.puff(LevelLayout.bowlCenter(), const Color(0xFFE8DDD0), count: 4, size: 18, rise: 30);
      return true;
    }

    final mouldTile = LevelLayout.tile(LevelLayout.mouldTile);
    if (mouldTile.contains(p)) {
      if (prep != null && prep.stage == BatchStage.mould) {
        for (var k = 0; k < prep.mouldChoices.length && k < 3; k++) {
          final row = LevelLayout.choiceRow(mouldTile, k);
          if (!row.contains(p)) continue;
          if (session.pickMould(prep.mouldChoices[k])) {
            game.effects.sparkle(row.center, count: 10, speed: 160);
          } else {
            _rowShake[k] = 0.45;
          }
          break;
        }
      }
      return true;
    }

    if (LevelLayout.tile(LevelLayout.mixTile).inflate(LevelLayout.tileGap / 2).contains(p)) {
      if (prep != null && prep.stage == BatchStage.mix && _mixPointer == null) {
        if (_mixBatch != prep || _mix == null) {
          _mixBatch = prep;
          _mix = MixMeter(center: LevelLayout.bowlCenter(), innerRadius: 10, outerRadius: 420);
        }
        _mixPointer = pointer;
        _mixTip = p;
        _mixMoved = 0;
        _mixHint = 0;
        _mix!.start(p);
      }
      return true;
    }

    final ovens = kitchen.ovens;
    for (var i = 0; i < ovens.length; i++) {
      if (!LevelLayout.ovenSlot(i, ovens.length).contains(p)) continue;
      final b = ovens[i];
      final progress = b?.ovenProgress ?? 0;
      if (b != null && session.takeOut(i)) {
        final perfect = (progress - b.bakeTarget).abs() <= session.modifiers.bakePerfectHalfWidth;
        game.effects.sparkle(_ovenRect(i, ovens.length).center, count: perfect ? 16 : 6, speed: perfect ? 200 : 120);
      }
      return true;
    }

    if (LevelLayout.tile(LevelLayout.frostTile).inflate(LevelLayout.tileGap / 2).contains(p)) {
      if (finish != null && finish.stage == BatchStage.frost) {
        _syncFrost(finish);
        if (LevelLayout.frostDone().inflate(9).contains(p)) {
          _finishFrost(finish);
        } else if (_frostPointer == null) {
          _frostPointer = pointer;
          _frostLast = p;
        }
      }
      return true;
    }

    if (LevelLayout.tile(LevelLayout.toppingTile).contains(p)) {
      if (finish != null && finish.stage == BatchStage.topping) {
        for (var k = 0; k < finish.toppingChoices.length && k < 2; k++) {
          final jar = LevelLayout.toppingJar(k);
          if (!jar.contains(p)) continue;
          final t = finish.toppingChoices[k];
          _syncToppings(finish);
          session.addTopping(t);
          _placed.add(t);
          _jarPop[k] = 0.25;
          game.effects.bits(LevelLayout.toppingCake().center.translate(0, -24), [ItemArt.toppingColor(t), AppColors.butter], count: 6);
          break;
        }
      }
      return true;
    }

    final boxTile = LevelLayout.tile(LevelLayout.boxTile);
    if (boxTile.contains(p)) {
      if (finish != null && finish.stage == BatchStage.box) {
        for (var k = 0; k < finish.boxChoices.length && k < 3; k++) {
          final row = LevelLayout.choiceRow(boxTile, k);
          if (!row.contains(p)) continue;
          session.pickBox(finish.boxChoices[k]);
          game.effects.hearts(row.center, count: 3);
          break;
        }
      }
      return true;
    }
    return false;
  }

  void pointerMove(int pointer, Offset p) {
    if (pointer == _mixPointer) {
      _mix?.move(p);
      _mixMoved += (p - _mixTip).distance;
      _mixTip = p;
    }
    if (pointer == _frostPointer) {
      final cake = LevelLayout.frostCake().deflate(6);
      _frostDist += segmentLengthInRect(_frostLast, p, cake);
      _frostLast = p;
    }
  }

  void pointerUp(int pointer, Offset p) {
    if (pointer == _mixPointer) {
      _mixPointer = null;
      final mix = _mix;
      final prep = kitchen.prep;
      if (mix != null) {
        mix.move(p);
        mix.end();
        if (mix.turns >= 0.5 && prep != null && prep == _mixBatch && prep.stage == BatchStage.mix) {
          session.finishMix(mix.turns);
          game.effects.sparkle(LevelLayout.bowlCenter(), count: 10, speed: 150);
        } else if (_mixMoved < 16) {
          // Chỉ chạm, không kéo: chỉ cách xoay.
          _mixHint = 2.4;
        }
      }
    }
    if (pointer == _frostPointer) {
      pointerMove(pointer, p);
      _frostPointer = null;
      final finish = kitchen.finish;
      if (finish != null && finish.stage == BatchStage.frost && frostCoverage >= 1) _finishFrost(finish);
    }
  }

  void pointerCancel(int pointer) {
    if (pointer == _mixPointer) {
      _mixPointer = null;
      _mix?.end();
    }
    if (pointer == _frostPointer) _frostPointer = null;
  }

  /// Nhả mọi thao tác kéo (tạm dừng, hết giờ).
  void releaseAll() {
    _mixPointer = null;
    _mix?.end();
    _frostPointer = null;
  }

  void _syncFrost(Batch b) {
    if (_frostBatch == b) return;
    _frostBatch = b;
    _frostDist = 0;
  }

  void _syncToppings(Batch b) {
    if (_toppingBatch == b) return;
    _toppingBatch = b;
    _placed.clear();
  }

  void _finishFrost(Batch b) {
    final cov = frostCoverage;
    session.finishFrost(cov);
    _coverBatch = b;
    _cover = cov;
    _frostPointer = null;
    game.effects.sparkle(LevelLayout.frostCake().center, count: cov >= 0.9 ? 14 : 6, speed: 160);
  }

  // ------------------------------------------------------------------ Hình dựng sẵn
  // Hình tĩnh của bếp thuộc riêng view (không qua cache LRU dùng chung): dựng một lần bằng `??=`, vòng vẽ không tạo
  // closure / khoá. Đổi chuỗi hoặc lượt chơi → [clearArt].

  GameArt? _bgArt, _tileArt, _cardArt, _rowArt, _jarArt, _checkArt, _cancelArt, _arrowArt, _hintArrowArt, _doneArt;
  GameArt? _frostMeterArt, _markerArt;

  /// Thanh nướng dựng sẵn theo từng lò (mỗi lò một mục tiêu riêng → không dựng lại xen kẽ mỗi khung).
  static const _ovenBarCache = 4;
  final List<GameArt?> _ovenBarArts = List<GameArt?>.filled(_ovenBarCache, null);
  final List<double> _ovenBarKeys = List<double>.filled(_ovenBarCache, -1);
  final List<GameArt?> _headers = List<GameArt?>.filled(6, null);
  final List<GameArt?> _tileGlows = List<GameArt?>.filled(kGlowLevels, null);
  final List<GameArt?> _cardGlows = List<GameArt?>.filled(kGlowLevels, null);
  final List<GameArt?> _ovenGlows = List<GameArt?>.filled(kGlowLevels, null);
  final Map<int, GameArt> _badges = {};
  final Map<Color, Map<String, GameArt>> _tags = {};
  final Map<MouldType, GameArt> _mouldNames = {};
  final Map<BoxType, GameArt> _boxNames = {};

  // Hình bánh theo mẻ (CakeVisual dựng lại chỉ khi mẻ / mức phủ kem đổi).
  Batch? _frostVisBatch;
  int _frostVisStep = -1;
  CakeVisual? _frostVis;
  Batch? _toppingVisBatch;
  CakeVisual? _toppingVis;
  Rect _toppingTop = Rect.zero;
  double _toppingSize = 0;

  static GameArt? _drop(GameArt? a) {
    a?.dispose();
    return null;
  }

  static void _dropAll(List<GameArt?> list) {
    for (var i = 0; i < list.length; i++) {
      list[i] = _drop(list[i]);
    }
  }

  static void _dropMap(Map<Object, GameArt> m) {
    for (final a in m.values) {
      a.dispose();
    }
    m.clear();
  }

  /// Giải phóng mọi hình dựng sẵn (đổi chuỗi / font / lượt chơi, hoặc gỡ game).
  void clearArt() {
    _bgArt = _drop(_bgArt);
    _tileArt = _drop(_tileArt);
    _cardArt = _drop(_cardArt);
    _rowArt = _drop(_rowArt);
    _jarArt = _drop(_jarArt);
    _checkArt = _drop(_checkArt);
    _cancelArt = _drop(_cancelArt);
    _arrowArt = _drop(_arrowArt);
    _hintArrowArt = _drop(_hintArrowArt);
    _doneArt = _drop(_doneArt);
    _frostMeterArt = _drop(_frostMeterArt);
    _markerArt = _drop(_markerArt);
    _dropAll(_ovenBarArts);
    _ovenBarKeys.fillRange(0, _ovenBarCache, -1);
    _dropAll(_headers);
    _dropAll(_tileGlows);
    _dropAll(_cardGlows);
    _dropAll(_ovenGlows);
    _dropMap(_badges);
    _dropMap(_mouldNames);
    _dropMap(_boxNames);
    for (final m in _tags.values) {
      _dropMap(m);
    }
    _tags.clear();
  }

  void dispose() => clearArt();

  GameArt _textArt(String s, {double size = 13, FontWeight weight = FontWeight.w700, double maxWidth = 150, int maxLines = 2}) =>
      buildTextArt(game.text.layout(s, size: size, weight: weight, maxWidth: maxWidth, maxLines: maxLines));

  void _drawCentered(Canvas canvas, GameArt art, Offset center) =>
      drawPictureAt(canvas, art.picture, center - Offset(art.size.width / 2, art.size.height / 2) - art.origin);

  /// Nhãn giấy [s] nền [backing] (dựng một lần theo chuỗi + màu nền).
  void _tag(Canvas canvas, String s, Offset center, {Color backing = SLColors.paper, double size = 13, double maxWidth = 150}) {
    final byColor = _tags[backing] ??= <String, GameArt>{};
    final art = byColor[s] ??= buildPaperTag(
      game.text.layout(s, size: size, weight: FontWeight.w800, maxWidth: maxWidth, maxLines: 2),
      color: backing,
      seed: SLRandom.hashString(s),
    );
    _drawCentered(canvas, art, center);
  }

  int get _glowLevel => (_pulse * (kGlowLevels - 1)).round();

  // ------------------------------------------------------------------ Vẽ

  void paint(Canvas canvas) {
    canvas.drawPicture((_bgArt ??= buildKitchenBackdrop()).picture);
    _paintCards(canvas);
    for (var i = 0; i < 6; i++) {
      _paintTile(canvas, i);
    }
    _paintMould(canvas);
    _paintMix(canvas);
    _paintOvens(canvas);
    _paintFrost(canvas);
    _paintTopping(canvas);
    _paintBox(canvas);
  }

  double get _pulse => 0.5 + 0.5 * math.sin(game.time * 4);

  bool _awaiting(int i) {
    final prep = kitchen.prep?.stage;
    final finish = kitchen.finish?.stage;
    return switch (i) {
      LevelLayout.mouldTile => prep == BatchStage.mould,
      LevelLayout.mixTile => prep == BatchStage.mix,
      LevelLayout.ovenTile => _anyOvenReady(),
      LevelLayout.frostTile => finish == BatchStage.frost,
      LevelLayout.toppingTile => finish == BatchStage.topping,
      _ => finish == BatchStage.box,
    };
  }

  bool _anyOvenReady() {
    for (final b in kitchen.ovens) {
      if (b != null && b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget - session.modifiers.bakeOkHalfWidth) return true;
    }
    return false;
  }

  void _paintTile(Canvas canvas, int i) {
    final r = LevelLayout.tile(i);
    if (_awaiting(i) && !session.isOver) {
      final lv = _glowLevel;
      drawPictureAt(canvas, (_tileGlows[lv] ??= buildGlowArt(r.size, lv)).picture, r.topLeft);
    }
    final art = _tileArt ??= buildCardArt(r.size, seed: 0x7110);
    drawPictureAt(canvas, art.picture, r.topLeft - art.origin);
    final header = _headers[i] ??= _textArt(game.labels.station(StationId.values[i]), size: 15, weight: FontWeight.w800, maxWidth: r.width - 16, maxLines: 1);
    _drawCentered(canvas, header, r.topCenter.translate(0, 17));
  }

  void _paintCards(Canvas canvas) {
    final menu = session.level.menu;
    final n = menu.length;
    final idle = kitchen.prep == null && !session.isOver;
    for (var i = 0; i < n; i++) {
      var r = LevelLayout.cardRect(i, n);
      final shake = i < _cardShake.length ? _cardShake[i] : 0.0;
      if (shake > 0) r = r.translate(math.sin(shake * 48) * 6, 0);
      if (idle) {
        final lv = _glowLevel;
        drawPictureAt(canvas, (_cardGlows[lv] ??= buildGlowArt(r.size, lv)).picture, r.topLeft);
      }
      final art = _cardArt ??= buildCardArt(r.size, color: AppColors.cream, material: SLMaterial.wash, seed: 0xCA4D);
      drawPictureAt(canvas, art.picture, r.topLeft - art.origin);
      final side = math.min(r.width, r.height) - 30;
      final bob = idle ? math.sin(game.time * 2.4 + i) * 2 : 0.0;
      _paintCake(canvas, Rect.fromCenter(center: Offset(r.center.dx, r.top + 12 + side / 2 + bob), width: side, height: side), menu[i], opacity: idle ? 1 : 0.55);
      final count = session.displayCase.countOf(menu[i]);
      final badge = _badges[count] ??= buildCountBadge(game.text, count);
      drawPictureAt(canvas, badge.picture, Offset(r.right - 18, r.bottom - 18) - badge.origin);
    }
  }

  void _paintCake(Canvas canvas, Rect r, RecipeId recipe, {double opacity = 1}) {
    final image = ArtSprites.cake(recipe).image;
    if (image != null) {
      drawArt(canvas, image, r, opacity: opacity);
    } else {
      CakeArt.paint(canvas, r, _visuals[recipe] ??= CakeVisual.recipe(recipe));
    }
  }

  /// Vẽ ảnh [ref] vào [r]; false nếu ảnh chưa có (người gọi vẽ hình dự phòng).
  bool _paintItem(Canvas canvas, ArtRef ref, Rect r, {double opacity = 1}) {
    final image = ref.image;
    if (image == null) return false;
    drawArt(canvas, image, r, opacity: opacity);
    return true;
  }

  void _hint(Canvas canvas, String s, Rect tile, {Color backing = SLColors.paper, double dx = 0}) =>
      _tag(canvas, s, Offset(tile.center.dx + dx, tile.bottom - 24), backing: backing, maxWidth: tile.width - 14);

  /// Hàng lựa chọn (khuôn / hộp): nền giấy + tên; trả ô ảnh để người gọi vẽ ảnh / hình dự phòng.
  Rect _paintRow(Canvas canvas, Rect row, double shake, GameArt name) {
    final r = shake > 0 ? row.translate(math.sin(shake * 48) * 7 * (shake / 0.45), 0) : row;
    final art = _rowArt ??= buildCardArt(r.size, color: SLColors.butterLight, material: SLMaterial.wash, radius: 14, inkWidth: 1.8, lift: 2, seed: 0x2077);
    drawPictureAt(canvas, art.picture, r.topLeft - art.origin);
    final icon = Rect.fromLTWH(r.left + 4, r.top + 4, r.height - 8, r.height - 8);
    _drawCentered(canvas, name, Offset((icon.right + r.right) / 2, r.center.dy));
    if (shake > 0) paintWrongMark(canvas, Offset(r.right - 12, r.top + 12), radius: 12);
    return icon;
  }

  static const double _rowNameWidth = LevelLayout.tileWidth - 12 - 62 - 6;

  // Khuôn ---------------------------------------------------------------

  void _paintMould(Canvas canvas) {
    final t = LevelLayout.tile(LevelLayout.mouldTile);
    final b = kitchen.prep;
    if (b == null) {
      _paintItem(canvas, ArtSprites.mould(MouldType.cupcakeLiner), Rect.fromCenter(center: t.center.translate(10, -6), width: 96, height: 96), opacity: 0.3);
      if (!session.isOver) {
        final a = (math.sin(game.time * 3) + 1) / 2;
        final arrow = _hintArrowArt ??= buildHintArrowArt();
        drawPictureAt(canvas, arrow.picture, Offset(t.left + 10 + a * 10, t.center.dy - 6) - arrow.origin);
        _hint(canvas, game.labels.pickTreat, t);
      }
      return;
    }
    if (b.stage == BatchStage.mould) {
      for (var k = 0; k < b.mouldChoices.length && k < 3; k++) {
        final m = b.mouldChoices[k];
        final name = _mouldNames[m] ??= _textArt(game.labels.mould(m), maxWidth: _rowNameWidth);
        final icon = _paintRow(canvas, LevelLayout.choiceRow(t, k), _rowShake[k], name);
        if (!_paintItem(canvas, ArtSprites.mould(m), icon)) ItemArt.paintMould(canvas, icon, m);
      }
      return;
    }
    // Đã chọn khuôn: khuôn đúng + dấu tích.
    final r = Rect.fromCenter(center: t.center.translate(0, 8), width: 104, height: 104);
    if (!_paintItem(canvas, ArtSprites.mould(b.correctMould), r)) ItemArt.paintMould(canvas, r, b.correctMould);
    final check = _checkArt ??= buildStickerDisc(15, SLColors.good, seed: 0xC4EC, inkWidth: 2.2, content: (c, o) => paintSLIcon(c, 'check', o, 22));
    drawPictureAt(canvas, check.picture, r.topRight.translate(-10, 10) - check.origin);
  }

  // Trộn ----------------------------------------------------------------

  void _paintMix(Canvas canvas) {
    final t = LevelLayout.tile(LevelLayout.mixTile);
    final b = kitchen.prep;
    final c = LevelLayout.bowlCenter();
    final bowl = Rect.fromCenter(center: c, width: 124, height: 124);
    if (b == null) {
      _paintItem(canvas, ArtSprites.bowl, bowl, opacity: 0.3);
      return;
    }
    final active = b.stage == BatchStage.mix;
    if (active) {
      // Vòng tiến độ: đủ 1 vòng = khép kín vòng tròn (vạch mốc ở đỉnh); quá tay → cung thứ hai màu dâu.
      final turns = mixTurns;
      final ring = Rect.fromCircle(center: c, radius: 72);
      canvas.drawCircle(c, 72, softStroke(SLColors.paperShade, 8));
      final first = math.min(1.0, turns);
      if (first > 0) canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * first, false, softStroke(AppColors.good, 7));
      if (turns > 1) {
        canvas.drawArc(ring.inflate(5), -math.pi / 2, math.pi * 2 * math.min(1.0, turns - 1), false, softStroke(AppColors.strawberry, 4));
      }
      canvas.drawLine(c.translate(0, -84), c.translate(0, -60), softStroke(SLColors.ink, 3.5));
    }
    if (b.stage == BatchStage.mould) {
      _paintItem(canvas, ArtSprites.bowl, bowl, opacity: 0.3);
    } else if (!_paintItem(canvas, ArtSprites.batter(b.recipeData.batter), bowl)) {
      paintBowl(canvas, c, 54, 40);
    }
    if (active) {
      if (_mixPointer != null) {
        _paintItem(canvas, ArtSprites.tool(ToolId.whisk), Rect.fromCenter(center: _mixTip.translate(16, -20), width: 64, height: 64));
      } else if (showMixHint) {
        // Mũi tên vòng quay + phới đi vòng quanh âu: cách khuấy (xoay hoặc kéo qua lại đều được tính theo góc quét).
        final a = game.time * 3.2;
        final arrow = _arrowArt ??= buildCircleArrowArt(72);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(a);
        drawPictureAt(canvas, arrow.picture, -arrow.origin);
        canvas.restore();
        final hand = c + Offset(math.cos(a + math.pi * 1.65), math.sin(a + math.pi * 1.65)) * 58;
        _paintItem(canvas, ArtSprites.tool(ToolId.whisk), Rect.fromCenter(center: hand.translate(12, -16), width: 58, height: 58));
        _hint(canvas, game.labels.stirHint, t, backing: SLColors.butterLight, dx: -24);
      } else if (mixTurns == 0) {
        _hint(canvas, game.labels.stirHint, t, dx: -24);
      }
    } else if (b.stage == BatchStage.waitingOven) {
      _hint(canvas, game.labels.waitOven, t, backing: SLColors.butterLight, dx: -24);
    }
    // Nút huỷ mẻ (mẻ còn ở khu chuẩn bị): nhãn dán "×", vùng chạm 64×64 ở góc dưới phải ô Trộn.
    final cancel = LevelLayout.cancelPrep();
    final art = _cancelArt ??= buildStickerDisc(18, SLColors.dangerSoft, seed: 0xCA9C, inkWidth: 2.2, content: (cv, o) => paintSLIcon(cv, 'close', o, 22));
    drawPictureAt(canvas, art.picture, cancel.center.translate(8, 8) - art.origin);
  }

  // Lò ------------------------------------------------------------------

  Rect _ovenRect(int i, int n) {
    final slot = LevelLayout.ovenSlot(i, n);
    // Nhiều lò: ô thấp hơn → bớt lề dưới (thanh nướng vẫn nằm gọn trong ô).
    final s = math.min(slot.width - 30, slot.height - (n > 1 ? 42 : 52));
    return Rect.fromCenter(center: Offset(slot.center.dx, slot.top + 4 + s / 2), width: s, height: s);
  }

  static void _bakeBarBack(Canvas c, Rect rr) => paintWashBand(c, rr.inflate(4), const Color(0xFFFFF3DE), 0x1B0, alpha: 1, highlight: false);

  /// Thanh lò (ống giấy + vùng được / vùng vàng quanh [target]); dựng lại chỉ khi mục tiêu / cỡ / vùng đổi.
  GameArt _ovenBar(int oven, Size size, double target) {
    final ok = session.modifiers.bakeOkHalfWidth;
    final perfect = session.modifiers.bakePerfectHalfWidth;
    final key = target * 1000 + size.width + size.height * 7 + ok * 13 + perfect * 17;
    final i = oven % _ovenBarCache;
    final cached = _ovenBarArts[i];
    if (cached != null && _ovenBarKeys[i] == key) return cached;
    cached?.dispose();
    _ovenBarKeys[i] = key;
    return _ovenBarArts[i] = buildMeterArt(size, seed: 0x1BA, back: _bakeBarBack, front: (c, rr) {
      double x(double v) => rr.left + rr.width * v.clamp(0.0, 1.0);
      paintWashBand(c, Rect.fromLTRB(x(target - ok), rr.top - 4, x(target + ok), rr.bottom + 4), const Color(0xFFFFE6A6), 0x1B1, alpha: 0.95);
      paintWashBand(c, Rect.fromLTRB(x(target - perfect), rr.top - 4, x(target + perfect), rr.bottom + 4), const Color(0xFFF2B33D), 0x1B2, alpha: 0.95);
      paintWashBand(c, Rect.fromLTRB(x(0.94), rr.top - 4, rr.right + 4, rr.bottom + 4), const Color(0xFF6E4A3C), 0x1B3, alpha: 0.75, highlight: false);
    });
  }

  void _paintOvens(Canvas canvas) {
    final ovens = kitchen.ovens;
    final n = ovens.length;
    final ok = session.modifiers.bakeOkHalfWidth;
    final ovenArt = ArtSprites.oven(game.ovenLevel);
    for (var i = 0; i < n; i++) {
      final slot = LevelLayout.ovenSlot(i, n);
      final r = _ovenRect(i, n);
      final b = ovens[i];
      if (b != null && b.stage == BatchStage.baking) {
        final glowRect = r.deflate(r.width * 0.1);
        final lv = (b.ovenProgress * (kGlowLevels - 1)).round().clamp(0, kGlowLevels - 1);
        final glow = _ovenGlows[lv] ??= buildGlowArt(glowRect.size, lv, radius: glowRect.width * 0.3, color: const Color(0xFFFFB25E));
        drawPictureAt(canvas, glow.picture, glowRect.topLeft);
      }
      if (!_paintItem(canvas, ovenArt, r, opacity: b == null ? 0.55 : 1)) {
        final body = RRect.fromRectAndRadius(r.deflate(8), const Radius.circular(14));
        canvas.drawRRect(body, fill(SLColors.paperShade));
        canvas.drawRRect(body, stroke(SLColors.ink, 2));
      }
      if (b != null && b.stage == BatchStage.baking) game.boosterFx.paintOven(canvas, r, i);
      if (b == null) continue;
      final target = b.bakeTarget;
      final bar = Rect.fromLTWH(slot.left + 10, r.bottom + 8, slot.width - 20, 18);
      final barArt = _ovenBar(i, bar.size, target);
      drawPictureAt(canvas, barArt.picture, bar.topLeft - barArt.origin);
      final overlay = barArt.overlay;
      if (overlay != null) drawPictureAt(canvas, overlay, bar.topLeft - barArt.origin);
      final marker = _markerArt ??= buildMarkerArt(bar.height);
      drawPictureAt(canvas, marker.picture, Offset(bar.left + bar.width * b.ovenProgress.clamp(0.0, 1.0), bar.top) - marker.origin);
      final labelAt = Offset(slot.center.dx, r.top + 14);
      if (b.burnt) {
        _tag(canvas, game.labels.burnt, labelAt, backing: SLColors.dangerSoft, size: 14, maxWidth: slot.width - 10);
      } else if (b.stage == BatchStage.ovenDone) {
        _tag(canvas, game.labels.waiting, labelAt, backing: SLColors.butterLight, maxWidth: slot.width - 10);
      } else if (b.ovenProgress >= target - ok) {
        canvas.save();
        canvas.translate(labelAt.dx, labelAt.dy);
        canvas.scale(1 + 0.08 * _pulse);
        _tag(canvas, game.labels.takeOut, Offset.zero, backing: SLColors.strawberryLight, size: 15, maxWidth: slot.width - 10);
        canvas.restore();
      }
    }
  }

  // Kem -----------------------------------------------------------------

  CakeVisual _bakedVisual(Batch b) {
    final r = b.recipeData;
    return CakeVisual(mould: r.mould, batter: r.batter, baked: bakedVisual(b.ovenProgress, b.bakeTarget), recipe: r.id);
  }

  /// Hình bánh ở trạm kem theo mức phủ (20 bậc như `CakeArt`): chỉ dựng lại khi mẻ / bậc đổi.
  CakeVisual _frostVisual(Batch b, double cov) {
    final step = (cov * 20).round();
    final cached = _frostVis;
    if (cached != null && _frostVisBatch == b && _frostVisStep == step) return cached;
    _frostVisBatch = b;
    _frostVisStep = step;
    final base = _bakedVisual(b);
    return _frostVis = step == 0 ? base : base.copyWith(frosting: b.recipeData.frostings.first, frostCoverage: step / 20);
  }

  void _paintFrost(Canvas canvas) {
    final t = LevelLayout.tile(LevelLayout.frostTile);
    final b = kitchen.finish;
    if (b == null || b.stage != BatchStage.frost) {
      _paintItem(canvas, ArtSprites.tool(ToolId.pipingBag), Rect.fromCenter(center: t.center.translate(0, 6), width: 96, height: 96), opacity: 0.3);
      return;
    }
    _syncFrost(b);
    final cov = frostCoverage;
    final cake = LevelLayout.frostCake();
    CakeArt.paint(canvas, cake, _frostVisual(b, cov));
    // Thanh độ phủ: ống giấy dựng sẵn + phần đã đầy tô bạc hà.
    final meter = Rect.fromLTWH(t.left + 18, cake.bottom + 4, t.width - 36, 12);
    final meterArt = _frostMeterArt ??= buildMeterArt(meter.size, seed: 0xF057);
    drawPictureAt(canvas, meterArt.picture, meter.topLeft - meterArt.origin);
    if (cov > 0) {
      final inner = meter.deflate(3);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
      canvas.drawRect(Rect.fromLTRB(meter.left, meter.top, meter.left + meter.width * cov, meter.bottom), fill(AppColors.mint));
      canvas.restore();
    }
    final meterOverlay = meterArt.overlay;
    if (meterOverlay != null) drawPictureAt(canvas, meterOverlay, meter.topLeft - meterArt.origin);
    if (_frostPointer != null) {
      _paintItem(canvas, ArtSprites.tool(ToolId.pipingBag), Rect.fromCenter(center: _frostLast.translate(14, -30), width: 60, height: 60));
    } else if (cov == 0) {
      _tag(canvas, game.labels.swipeHint, cake.bottomCenter.translate(0, -24), maxWidth: t.width - 14);
    }
    final done = LevelLayout.frostDone();
    final art = _doneArt ??= buildButtonArt(
      done.size,
      AppColors.mint,
      game.text.layout(game.labels.done, size: 20, weight: FontWeight.w800, maxWidth: done.width - 12, title: true),
      seed: 0xD0E,
    );
    drawPictureAt(canvas, art.picture, done.topLeft - art.origin);
  }

  // Topping -------------------------------------------------------------

  void _paintTopping(Canvas canvas) {
    final t = LevelLayout.tile(LevelLayout.toppingTile);
    final b = kitchen.finish;
    if (b == null || b.stage != BatchStage.topping) {
      _paintItem(canvas, ArtSprites.tool(ToolId.tongs), Rect.fromCenter(center: t.center.translate(0, 6), width: 92, height: 92), opacity: 0.3);
      return;
    }
    _syncToppings(b);
    final cake = LevelLayout.toppingCake();
    var visual = _toppingVis;
    if (visual == null || _toppingVisBatch != b) {
      final cover = _coverBatch == b ? _cover : 1.0;
      visual = _toppingVis = _bakedVisual(b).copyWith(frosting: b.recipeData.frostings.first, frostCoverage: cover);
      _toppingVisBatch = b;
      _toppingTop = CakeArt.topSurface(cake, visual.mould, recipe: visual.recipe);
      _toppingSize = toppingSize(_toppingTop);
    }
    CakeArt.paint(canvas, cake, visual);
    final top = _toppingTop;
    for (var k = 0; k < _placed.length && k < _toppingSpots.length; k++) {
      final u = _toppingSpots[k];
      paintToppingAt(canvas, Offset(top.center.dx + u.dx * top.width / 2, top.center.dy + u.dy * top.height / 2), _placed[k], _toppingSize);
    }
    _tag(canvas, _countText[b.toppingsPlaced.clamp(0, 3)], Offset(t.right - 34, t.top + 46), backing: SLColors.butterLight, size: 15, maxWidth: 60);
    final jarImage = LevelArt.image(LevelArtId.toppingJar);
    for (var k = 0; k < b.toppingChoices.length && k < 2; k++) {
      final jar = LevelLayout.toppingJar(k);
      final pop = _jarPop[k] > 0 ? 1 - 0.1 * math.sin(_jarPop[k] / 0.25 * math.pi) : 1.0;
      final tp = b.toppingChoices[k];
      if (jarImage != null) {
        _paintJar(canvas, jarImage, jar, pop, tp);
        continue;
      }
      final art = _jarArt ??= buildCardArt(jar.size, color: SLColors.mintLight, material: SLMaterial.wash, radius: 16, inkWidth: 1.8, lift: 2, seed: 0x7A12);
      canvas.save();
      canvas.translate(jar.center.dx, jar.center.dy);
      canvas.scale(pop);
      drawPictureAt(canvas, art.picture, Offset(-jar.width / 2, -jar.height / 2) - art.origin);
      canvas.restore();
      final icon = Rect.fromCenter(center: jar.center, width: 58 * pop, height: 58 * pop);
      if (!_paintItem(canvas, ArtSprites.topping(tp), icon)) ItemArt.paintTopping(canvas, icon, tp);
    }
  }

  /// Ảnh hũ thuỷ tinh (267×320) vừa ô [jar] (co theo [pop]): đống topping [tp] trong lòng hũ, một cái nhô lên trên miệng
  /// (dễ nhận ra), rồi phủ lại hũ mờ để kính có vệt sáng đè lên topping.
  void _paintJar(Canvas canvas, Image jarImage, Rect jar, double pop, ToppingId tp) {
    final h = jar.height * pop;
    final w = h * _jarAspect;
    final r = Rect.fromCenter(center: jar.center, width: w, height: h);
    drawArt(canvas, jarImage, r);
    final body = Offset(r.left + w * 0.49, r.top + h * 0.7);
    final s = w * 0.3;
    final image = ArtSprites.topping(tp).image;
    for (final o in _jarPile) {
      final at = Rect.fromCenter(center: body + o * s, width: s, height: s);
      if (image != null) {
        drawArt(canvas, image, at);
      } else {
        ItemArt.paintTopping(canvas, at, tp);
      }
    }
    drawArt(canvas, jarImage, r, opacity: 0.3);
    // Một cái lớn trên nắp bần: biết ngay hũ đựng gì.
    final lid = Rect.fromCenter(center: Offset(r.center.dx, r.top + h * 0.08), width: s * 1.35, height: s * 1.35);
    if (image != null) {
      drawArt(canvas, image, lid);
    } else {
      ItemArt.paintTopping(canvas, lid, tp);
    }
  }

  static const double _jarAspect = 267 / 320;

  /// Đống topping trong lòng hũ (theo cạnh topping, so với tâm lòng hũ): hàng đáy 3, giữa 2, đỉnh 1.
  static const _jarPile = [
    Offset(-0.78, 0.55), Offset(0, 0.6), Offset(0.78, 0.55), //
    Offset(-0.4, 0), Offset(0.42, 0.02), //
    Offset(0, -0.5),
  ];

  static const _toppingSpots = [Offset(-0.45, 0.15), Offset(0.45, 0.15), Offset(0, -0.3)];
  static const _countText = ['0/3', '1/3', '2/3', '3/3'];

  // Hộp -----------------------------------------------------------------

  void _paintBox(Canvas canvas) {
    final t = LevelLayout.tile(LevelLayout.boxTile);
    final b = kitchen.finish;
    if (b != null && b.stage == BatchStage.box) {
      for (var k = 0; k < b.boxChoices.length && k < 3; k++) {
        final box = b.boxChoices[k];
        final name = _boxNames[box] ??= _textArt(game.labels.box(box), maxWidth: _rowNameWidth);
        final icon = _paintRow(canvas, LevelLayout.choiceRow(t, k), 0, name);
        if (!_paintItem(canvas, ArtSprites.box(box), icon)) ItemArt.paintBox(canvas, icon, box);
      }
      return;
    }
    if (b != null && b.stage == BatchStage.waitingCase) {
      final box = b.boxChosen ?? b.correctBox;
      final r = Rect.fromCenter(center: t.center.translate(0, 4), width: 110, height: 110);
      if (!_paintItem(canvas, ArtSprites.box(box, open: true), r)) ItemArt.paintBox(canvas, r, box, open: true);
      _paintCake(canvas, Rect.fromCenter(center: r.center.translate(0, -18), width: 64, height: 64), b.recipe);
      canvas.save();
      canvas.translate(t.center.dx, t.top + 50);
      canvas.scale(1 + 0.08 * _pulse);
      _tag(canvas, game.labels.caseFull, Offset.zero, backing: SLColors.dangerSoft, size: 15, maxWidth: t.width - 12);
      canvas.restore();
      return;
    }
    _paintItem(canvas, ArtSprites.box(BoxType.small), Rect.fromCenter(center: t.center.translate(0, 6), width: 92, height: 92), opacity: 0.3);
  }
}
