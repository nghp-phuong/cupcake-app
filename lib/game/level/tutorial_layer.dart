import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/constants.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import 'level_art.dart';
import 'level_game.dart';
import 'level_layout.dart';

/// Chỗ mà một bước hướng dẫn chỉ vào (gương của `TutorialTarget` ở core — game không phụ thuộc thứ tự enum của core).
enum TutorialSpot { customer, caseSlot, treatCard, mould, mix, oven, frost, topping, box, comboMeter, patienceRing, none }

/// Bước hướng dẫn đang hiện mà lớp hướng dẫn vẽ: chép từ `session.tutorial` mỗi khung (đối tượng tái dùng) — test
/// đưa dữ liệu giả lập thẳng vào đây (như `StaffPose`).
class TutorialPose {
  TutorialPose(this.step, this.spot, {this.customerId, this.recipe, this.oven, this.dismissible = false, this.exclusive = false});

  /// id bước (khoá chuỗi `LevelLabels.tutorial`, khoá cache hình của bước).
  String step;
  TutorialSpot spot;

  /// Khách được chỉ (customer / patienceRing); null → khách đầu tiên đứng quầy.
  int? customerId;

  /// Món được chỉ (thẻ bánh / ô tủ); null → món đầu menu / món đang làm.
  RecipeId? recipe;

  /// Lò được chỉ (bước Lò); null → lò đầu tiên có kim gần vạch.
  int? oven;

  /// Bước thông tin (có `autoHide`): chạm bất kỳ đâu → `session.dismissTutorialStep()` (chạm vẫn đi tiếp xuống cảnh).
  bool dismissible;

  /// Bước yêu cầu chạm đúng chỗ: chạm ngoài vùng sáng bị nuốt (mặc định không chặn).
  bool exclusive;
}

/// Hình của một bước: vùng sáng [hole], nền tối khoét lỗ (Path dựng một lần cho mỗi vùng), nhãn chữ đã dựng.
class _StepVisual {
  String step = '';
  TutorialSpot spot = TutorialSpot.none;
  int? customer;
  RecipeId? recipe;

  Rect hole = Rect.zero;
  bool round = false;

  /// Có vùng sáng (false: chỉ nhãn chữ — bước `none` hoặc khách đã rời cảnh).
  bool hasHole = false;

  /// Đã tra chuỗi của bước (chỉ tra một lần cho mỗi bước / mỗi lần đổi chuỗi, không gọi hàm chuỗi mỗi khung).
  bool textDone = false;
  Path? dim;
  GameArt? tag;
  Offset tagAt = Offset.zero;
  String tagText = '';

  /// 0..1 độ hiện (mờ dần vào / ra 200 ms).
  double fade = 0;
  bool live = false;

  bool same(TutorialPose p) => step == p.step && spot == p.spot && customer == p.customerId && recipe == p.recipe;

  void release() {
    tag?.dispose();
    tag = null;
    tagText = '';
    textDone = false;
    hasHole = false;
    dim = null;
    live = false;
    fade = 0;
  }
}

/// Lớp hướng dẫn L1–L3 vẽ trên cùng cảnh tiệm + bếp nhanh: nền tối mờ 45% (SLColors.barrier) khoét một vùng sáng bo
/// tròn quanh mục tiêu, viền vàng bơ, tay chỉ (`level/tutorial_hand`, thiếu ảnh → hình vẽ code) nhún nhẹ vào mục
/// tiêu — bước Trộn: tay đi vòng quanh âu, bước Kem: tay quẹt ngang bánh — và nhãn giấy chữ ngắn cạnh mục tiêu (không
/// tràn khung, không che vùng sáng / tay).
///
/// Toạ độ mục tiêu lấy từ đúng nơi nhận chạm ([LevelLayout], `ShopView`) → đầu ngón tay luôn nằm trong vùng chạm của
/// mục tiêu. Mục tiêu chưa sẵn sàng (khách chưa tới quầy, mẻ chưa tới trạm, kim lò còn xa vạch) → không vẽ gì.
///
/// Chạm ngoài vùng sáng: không chặn (trừ bước `exclusive`), tay chỉ nhấp nháy lại. Đổi bước: bước cũ mờ dần ra, bước
/// mới mờ dần vào (200 ms). Không cấp phát mỗi khung: Path nền tối + nhãn dựng một lần cho mỗi bước / vùng sáng (vùng
/// sáng chỉ đổi khi mục tiêu dời > 1.5 px); hình tay vẽ code dựng một lần.
class TutorialLayer {
  TutorialLayer(this.game);

  final LevelGame game;
  LevelSession get session => game.session;

  static const fadeSec = 0.2;
  static const flashSec = 0.6;

  /// Ô combo của HUD (ui, `_LevelHud` ở `level_screen.dart`): Row lề (12, 6, 12, 0), ô combo là `SizedBox` rộng 150 sát
  /// mép phải → x 1118–1268; `SLTopBarItem` cao 48–56 từ y 6. Ước lượng theo bố cục, không đo widget thật.
  static const Rect hudCombo = Rect.fromLTRB(1118, 6, 1268, 56);

  /// Cao hình tay chỉ khi vẽ (rộng theo tỉ lệ ảnh).
  static const double handHeight = 92;

  /// Đầu ngón trỏ trong ảnh `tutorial_hand` (152×200, ngón trỏ chếch lên trái, cổ tay dưới-phải) theo tỉ lệ rộng,
  /// cao — điểm chạm vào mục tiêu. Hình vẽ code dự phòng đặt ngón cùng chỗ.
  static const Offset handTipFrac = Offset(0.12, 0.03);
  static const double _fallbackAspect = 152 / 200;

  final _StepVisual _cur = _StepVisual();
  final _StepVisual _old = _StepVisual();

  double _clock = 0;
  double _flash = 0;

  // Mục tiêu của khung này (tính ở [update]).
  bool _ready = false;
  final _target = _Target();

  /// Tay chỉ: đầu ngón ở khung này, tay xoay ngang (chỉ sang phải, cổ tay bên trái) khi mục tiêu sát đáy khung.
  Offset _tip = Offset.zero;
  bool _side = false;

  GameArt? _handFallback;

  final Paint _dimPaint = Paint()..isAntiAlias = true;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..isAntiAlias = true;
  final Paint _haloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..isAntiAlias = true;
  final Paint _layerPaint = Paint();
  final Paint _handPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  /// Đang vẽ một bước (mục tiêu đã sẵn sàng).
  bool get visible => _cur.live && _ready;

  /// Vùng sáng của bước hiện tại (toạ độ khung 1280×720; null nếu không vẽ / bước không có mục tiêu).
  Rect? get targetRect => visible && _cur.hasHole ? _cur.hole : null;

  /// Đầu ngón tay chỉ (khung này, gồm cả nhún / xoay).
  Offset? get handTip => visible && _cur.hasHole ? _tip : null;

  /// Khung hình tay (để kiểm không bị nhãn che).
  Rect? get handRect => handTip == null ? null : _handBounds(_tip, _side);

  /// Khung nhãn chữ (null nếu bước không có chữ).
  Rect? get bubbleRect {
    final tag = _cur.tag;
    if (!visible || tag == null) return null;
    return Rect.fromCenter(center: _cur.tagAt, width: tag.size.width, height: tag.size.height);
  }

  /// Còn nhấp nháy tay chỉ (vừa chạm sai chỗ).
  bool get flashing => _flash > 0;

  /// Số lần đã dựng nền tối khoét lỗ / nhãn chữ (test: chỉ dựng khi đổi bước / mục tiêu dời).
  @visibleForTesting
  int debugDimBuilds = 0, debugTagBuilds = 0;

  /// Độ hiện của bước hiện tại (0..1).
  double get fade => _cur.fade;

  void reset() {
    _cur.release();
    _old.release();
    _flash = 0;
    _ready = false;
  }

  /// Giải phóng hình đã dựng (đổi chuỗi / font, gỡ game).
  void clearArt() {
    _cur.tag?.dispose();
    _cur
      ..tag = null
      ..tagText = ''
      ..textDone = false;
    _old.release();
    _handFallback?.dispose();
    _handFallback = null;
  }

  void dispose() {
    reset();
    clearArt();
  }

  // ------------------------------------------------------------------ Chạm

  /// Gọi trước khi chuyển chạm cho cảnh: chạm ngoài vùng sáng → tay nhấp nháy lại; trả false nếu chạm bị nuốt (bước
  /// `exclusive`).
  bool allowTap(Offset p) {
    final pose = game.tutorialPose;
    if (pose != null && pose.dismissible) {
      session.dismissTutorialStep();
      return true;
    }
    if (!visible || !_cur.hasHole) return true;
    if (_cur.hole.inflate(12).contains(p)) return true;
    _flash = flashSec;
    return !(pose?.exclusive ?? false);
  }

  // ------------------------------------------------------------------ Cập nhật

  void update(double dt) {
    _clock += dt;
    if (_flash > 0) _flash = math.max(0, _flash - dt);
    if (_old.live) {
      _old.fade -= dt / fadeSec;
      if (_old.fade <= 0) _old.release();
    }
    final pose = session.isOver ? null : game.tutorialPose;
    if (pose == null) {
      _retire();
      _ready = false;
      return;
    }
    if (_cur.live && !_cur.same(pose)) _retire();
    if (!_cur.live) {
      _cur
        ..live = true
        ..fade = 0
        ..step = pose.step
        ..spot = pose.spot
        ..customer = pose.customerId
        ..recipe = pose.recipe
        ..dim = null
        ..hole = Rect.zero;
    }
    _ready = !session.paused && _resolve(pose);
    if (!_ready) return;
    if (_cur.fade < 1) _cur.fade = math.min(1, _cur.fade + dt / fadeSec);
    _placeHand();
    _sync();
  }

  /// Bước hiện tại chuyển sang mờ dần ra.
  void _retire() {
    if (!_cur.live) return;
    _old.release();
    if (_ready && _cur.fade > 0) {
      _old
        ..live = true
        ..fade = _cur.fade
        ..step = _cur.step
        ..spot = _cur.spot
        ..hole = _cur.hole
        ..round = _cur.round
        ..hasHole = _cur.hasHole
        ..dim = _cur.dim
        ..tag = _cur.tag
        ..tagText = _cur.tagText
        ..tagAt = _cur.tagAt;
      _cur
        ..tag = null
        ..tagText = '';
    }
    _cur.release();
  }

  /// Tìm mục tiêu của [pose] trong cảnh khung này → [_target]. false nếu mục tiêu chưa sẵn sàng.
  bool _resolve(TutorialPose pose) {
    final t = _target..spot = pose.spot;
    final kitchen = session.kitchen;
    switch (pose.spot) {
      case TutorialSpot.customer:
      case TutorialSpot.patienceRing:
        final id = pose.customerId ?? _firstAtCounter();
        if (id == null) return false;
        final frame = game.shop.counterFrameOf(id);
        final bubble = game.shop.bubbleOf(id);
        if (frame == null || bubble == null) {
          // Khách được chỉ đang rời đi / đã rời cảnh: chỉ nhãn chữ (không chỉ vào chỗ trống); đang bước lên quầy → đợi.
          final c = session.customer(id);
          if (pose.customerId == null || (c != null && !c.isLeaving)) return false;
          _none(t);
          return true;
        }
        if (pose.spot == TutorialSpot.patienceRing) {
          t
            ..rect = Rect.fromCircle(center: bubble, radius: LevelLayout.bubbleRadius + 14)
            ..round = true
            ..anchor = bubble + const Offset(LevelLayout.bubbleRadius * 0.62, LevelLayout.bubbleRadius * 0.62)
            ..motion = _Motion.tap;
        } else {
          // Bong bóng + nửa trên người (vùng chạm bán: thân hoặc bong bóng); ngón tay chỉ vào ngực khách.
          final scale = frame.height / LevelLayout.customerHeight;
          final cloudHalf = LevelLayout.bubbleWidth * scale / 2;
          final left = math.min(frame.center.dx - frame.height * 0.26, bubble.dx - cloudHalf);
          final right = math.max(frame.center.dx + frame.height * 0.26, bubble.dx + cloudHalf);
          final top = math.max(LevelLayout.hudBottom + 6, math.min(frame.top, bubble.dy - cloudHalf * 0.85));
          t
            ..rect = Rect.fromLTRB(left, top, right, LevelLayout.caseRect.top + 8)
            ..round = false
            ..anchor = Offset(frame.center.dx, frame.top + frame.height * 0.45)
            ..motion = _Motion.tap;
        }
      case TutorialSpot.caseSlot:
        final r = pose.recipe ?? session.level.menu.first;
        final cell = game.shop.slotFrameOf(r);
        // Cột ô tủ (đủ hai tầng kệ); tủ chưa có món → cả lòng kính. Ngón tay chỉ vào cái bánh đại diện.
        t
          ..rect = cell == null ? LevelLayout.caseGlass.deflate(4) : cell.inflate(4)
          ..round = false
          ..anchor = cell == null ? LevelLayout.caseGlass.center : game.shop.cellCenterOf(r)
          ..motion = _Motion.tap;
      case TutorialSpot.treatCard:
        final menu = session.level.menu;
        final i = menu.indexOf(pose.recipe ?? kitchen.prep?.recipe ?? menu.first);
        final card = LevelLayout.cardRect(math.max(0, i), menu.length);
        t
          ..rect = card
          ..round = false
          ..anchor = card.center
          ..motion = _Motion.tap;
      case TutorialSpot.mould:
        final b = kitchen.prep;
        if (b == null || b.stage != BatchStage.mould) return false;
        final k = b.mouldChoices.indexOf(b.correctMould);
        if (k < 0 || k > 2) return false;
        final row = LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.mouldTile), k);
        t
          ..rect = row
          ..round = false
          ..anchor = row.center
          ..motion = _Motion.tap;
      case TutorialSpot.mix:
        final b = kitchen.prep;
        if (b == null || b.stage != BatchStage.mix) return false;
        final c = LevelLayout.bowlCenter();
        t
          ..rect = Rect.fromCircle(center: c, radius: 80)
          ..round = true
          ..anchor = c
          ..motion = _Motion.spin;
      case TutorialSpot.oven:
        final ovens = kitchen.ovens;
        final ok = session.modifiers.bakeOkHalfWidth;
        var at = -1;
        for (var i = 0; i < ovens.length; i++) {
          final b = ovens[i];
          if (pose.oven != null && pose.oven != i) continue;
          // Chỉ hiện khi kim đã gần vạch vàng.
          if (b != null && b.stage == BatchStage.baking && b.ovenProgress >= b.bakeTarget - ok - _ovenLead) {
            at = i;
            break;
          }
        }
        if (at < 0) return false;
        final slot = LevelLayout.ovenSlot(at, ovens.length);
        t
          ..rect = slot
          ..round = false
          ..anchor = slot.center.translate(0, -slot.height * 0.08)
          ..motion = _Motion.tap;
      case TutorialSpot.frost:
        final b = kitchen.finish;
        if (b == null || b.stage != BatchStage.frost) return false;
        final cake = LevelLayout.frostCake();
        t
          ..rect = cake.inflate(10)
          ..round = false
          ..anchor = cake.center
          ..motion = _Motion.swipe;
      case TutorialSpot.topping:
        final b = kitchen.finish;
        if (b == null || b.stage != BatchStage.topping) return false;
        final k = b.toppingChoices.indexOf(b.correctTopping);
        if (k < 0 || k > 1) return false;
        final jar = LevelLayout.toppingJar(k);
        t
          ..rect = jar
          ..round = false
          ..anchor = jar.center
          ..motion = _Motion.tap;
      case TutorialSpot.box:
        final b = kitchen.finish;
        if (b == null || b.stage != BatchStage.box) return false;
        final k = b.boxChoices.indexOf(b.correctBox);
        if (k < 0 || k > 2) return false;
        final row = LevelLayout.choiceRow(LevelLayout.tile(LevelLayout.boxTile), k);
        t
          ..rect = row
          ..round = false
          ..anchor = row.center
          ..motion = _Motion.tap;
      case TutorialSpot.comboMeter:
        if (session.combo < 2) return false;
        // HUD (ui) vẽ đè lên game ở y 0–64: vùng sáng nới xuống dưới ô combo 14 px (viền lộ ra dưới HUD), ngón tay
        // chạm mép dưới ô combo từ bên dưới.
        t
          ..rect = Rect.fromLTRB(hudCombo.left, hudCombo.top, hudCombo.right, hudCombo.bottom + 14)
          ..round = false
          ..anchor = Offset(hudCombo.center.dx - 20, hudCombo.bottom)
          ..motion = _Motion.tap;
      case TutorialSpot.none:
        _none(t);
    }
    return true;
  }

  static void _none(_Target t) => t
    ..spot = TutorialSpot.none
    ..rect = Rect.zero
    ..round = false
    ..anchor = Offset.zero
    ..motion = _Motion.none;

  /// Kim lò cách vạch vàng chừng này thì bước Lò mới hiện.
  static const double _ovenLead = 0.12;

  int? _firstAtCounter() {
    int? best;
    for (final c in session.customers) {
      if (!c.canBuy || c.phaseT < 0.95) continue;
      // Ưu tiên khách mà tủ đang có món.
      if (session.displayCase.countOf(c.want) > 0) return c.id;
      best ??= c.id;
    }
    return best;
  }

  /// Đầu ngón tay theo hoạt cảnh của bước: nhún (chạm), đi vòng (trộn), quẹt ngang (kem); nhấp nháy khi chạm sai.
  void _placeHand() {
    final t = _target;
    final a = t.anchor;
    switch (t.motion) {
      case _Motion.spin:
        final ang = _clock * 4.2;
        _tip = a + Offset(math.cos(ang), math.sin(ang)) * 46;
        _side = false;
      case _Motion.swipe:
        final w = t.rect.width / 2 - 22;
        final u = math.sin(_clock * 3.6);
        _tip = a + Offset(u * w, 0);
        _side = false;
      case _Motion.tap:
        // Nhún: tay nhích ra rồi ấn vào mục tiêu (~1,1 lần mỗi giây).
        final bob = (0.5 + 0.5 * math.sin(_clock * 7)) * 9;
        _side = a.dy + handHeight * (1 - handTipFrac.dy) + 6 > 720;
        final base = _keepInFrame(a, _side);
        _tip = _side ? base.translate(-bob, -bob * 0.3) : base.translate(bob * 0.45, bob);
      case _Motion.none:
        _tip = Offset.zero;
        _side = false;
    }
  }

  /// Dời [tip] (ít nhất có thể) để cả hình tay — kể cả khi nhún — nằm trong khung.
  Offset _keepInFrame(Offset tip, bool side) {
    final b = _handBounds(tip, side);
    final dx = b.right + 6 > 1276 ? 1276 - b.right - 6 : (b.left < 4 ? 4 - b.left : 0.0);
    final dy = b.bottom + 10 > 718 ? 718 - b.bottom - 10 : 0.0;
    return dx == 0 && dy == 0 ? tip : tip.translate(dx, dy);
  }

  double get _handAspect {
    final img = LevelArt.image(LevelArtId.tutorialHand);
    return img == null ? _fallbackAspect : img.width / img.height;
  }

  /// Khung hình tay khi đầu ngón ở [tip] (tay đứng: cổ tay dưới-phải; tay ngang: chỉ sang phải, cổ tay bên trái).
  Rect _handBounds(Offset tip, bool side) {
    const h = handHeight;
    final w = h * _handAspect;
    if (!side) return Rect.fromLTWH(tip.dx - w * handTipFrac.dx, tip.dy - h * handTipFrac.dy, w, h);
    // Xoay 90° theo chiều kim đồng hồ quanh đầu ngón: ngón chỉ sang phải.
    return Rect.fromLTWH(tip.dx - h * (1 - handTipFrac.dy), tip.dy - w * handTipFrac.dx, h, w);
  }

  /// Dựng lại nền tối / nhãn khi bước, vùng sáng hoặc chuỗi đổi.
  void _sync() {
    final v = _cur;
    final t = _target;
    final moved = (v.hole.left - t.rect.left).abs() > 1.5 ||
        (v.hole.top - t.rect.top).abs() > 1.5 ||
        (v.hole.width - t.rect.width).abs() > 1.5 ||
        (v.hole.height - t.rect.height).abs() > 1.5;
    final hole = t.spot != TutorialSpot.none;
    if (hole != v.hasHole) v.dim = null;
    v.hasHole = hole;
    if (!hole) {
      v.hole = Rect.zero;
    } else if (moved || v.dim == null) {
      v
        ..hole = t.rect
        ..round = t.round
        ..dim = (Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(_frame)
          ..addRRect(_holeRRect(t.rect, t.round)));
      debugDimBuilds++;
    }
    if (!v.textDone) {
      v.textDone = true;
      final text = game.labels.tutorial(v.step);
      v.tag?.dispose();
      if (text.isNotEmpty) debugTagBuilds++;
      v
        ..tagText = text
        ..tag = text.isEmpty
            ? null
            : buildPaperTag(
                game.text.layout(text, size: 17, weight: FontWeight.w800, maxWidth: _tagMaxWidth, maxLines: 3),
                color: SLColors.paper,
                padX: 14,
                padY: 8,
                seed: SLRandom.hashString(text),
              );
      v.tagAt = Offset.zero;
    }
    final tag = v.tag;
    if (tag != null && (moved || v.tagAt == Offset.zero)) v.tagAt = _placeTag(tag.size);
  }

  static const double _tagMaxWidth = 280;
  static const Rect _frame = Rect.fromLTWH(0, 0, 1280, 720);

  /// Vùng nhãn được phép nằm (dưới HUD, lề 8).
  static const Rect _tagArea = Rect.fromLTRB(8, LevelLayout.hudBottom + 6, 1272, 712);

  static RRect _holeRRect(Rect r, bool round) =>
      RRect.fromRectAndRadius(r, Radius.circular(round ? r.shortestSide / 2 : math.min(20, r.shortestSide / 2)));

  /// Tâm nhãn cỡ [size]: thử trên mép bếp (mục tiêu ở bếp) / trên / phải / trái / dưới vùng sáng (thứ tự theo nơi của mục tiêu), kẹp vào khung, bỏ
  /// chỗ đè lên vùng sáng hoặc tay chỉ. Không có mục tiêu → giữa sân tiệm.
  Offset _placeTag(Size size) {
    final t = _target;
    if (t.spot == TutorialSpot.none) return Offset(640, LevelLayout.hudBottom + 110);
    final hole = _cur.hole.inflate(6);
    final hand = _handReach();
    const gap = 14.0;
    final w = size.width, h = size.height;
    final above = Offset(hole.center.dx, hole.top - gap - h / 2);
    final below = Offset(hole.center.dx, hole.bottom + gap + h / 2);
    // Tay chỉ chìa sang phải / xuống dưới vùng sáng: nhãn bên phải tránh cả tay (không đè lên mặt khách bên trái).
    final right = Offset(math.max(hole.right, hand.right) + gap + w / 2, hole.center.dy);
    final left = Offset(hole.left - gap - w / 2, hole.center.dy);
    // Mục tiêu ở bếp: ưu tiên ngay trên mép bếp (không che các lựa chọn khác trong cùng ô trạm).
    final overKitchen = Offset(hole.center.dx, LevelLayout.kitchenTop + 6 - h / 2);
    final kitchen = hole.center.dy >= LevelLayout.kitchenTop;
    final hud = t.spot == TutorialSpot.comboMeter;
    final order = hud
        ? [below.translate(-w / 2 + hole.width / 2, 0), left, below]
        : kitchen
            ? [overKitchen, above, right, left, below]
            : [right, left, below, above];
    Offset? first;
    for (final c in order) {
      final at = _clampTag(c, size);
      first ??= at;
      final r = Rect.fromCenter(center: at, width: w, height: h);
      if (r.overlaps(hole) || r.overlaps(hand)) continue;
      return at;
    }
    return first!;
  }

  Offset _clampTag(Offset c, Size s) => Offset(
        c.dx.clamp(_tagArea.left + s.width / 2, _tagArea.right - s.width / 2),
        c.dy.clamp(_tagArea.top + s.height / 2, _tagArea.bottom - s.height / 2),
      );

  /// Khung mà tay chỉ quét qua trong cả hoạt cảnh (nhãn tránh khung này).
  Rect _handReach() {
    final t = _target;
    final a = t.anchor;
    switch (t.motion) {
      case _Motion.spin:
        return _handBounds(a + const Offset(-46, -46), false).expandToInclude(_handBounds(a + const Offset(46, 46), false));
      case _Motion.swipe:
        final w = t.rect.width / 2 - 22;
        return _handBounds(a.translate(-w, 0), false).expandToInclude(_handBounds(a.translate(w, 0), false));
      case _Motion.tap:
        final side = a.dy + handHeight * (1 - handTipFrac.dy) + 6 > 720;
        final base = _keepInFrame(a, side);
        return _handBounds(base, side).expandToInclude(_handBounds(side ? base.translate(-9, -3) : base.translate(4, 9), side));
      case _Motion.none:
        return Rect.zero;
    }
  }

  // ------------------------------------------------------------------ Vẽ

  void paint(Canvas canvas) {
    if (_old.live) _paintVisual(canvas, _old, easeInOut(_old.fade), hand: false);
    if (visible) _paintVisual(canvas, _cur, easeInOut(_cur.fade), hand: _cur.hasHole);
  }

  void _paintVisual(Canvas canvas, _StepVisual v, double a, {required bool hand}) {
    if (a <= 0) return;
    final dim = v.dim;
    if (dim != null && v.hasHole) {
      _dimPaint.color = SLColors.barrier.withValues(alpha: SLColors.barrier.a * a);
      canvas.drawPath(dim, _dimPaint);
      // Viền vùng sáng: quầng vàng bơ mềm + nét vàng đậm nhịp nhẹ (nhanh hơn khi đang nhấp nháy).
      final rr = _holeRRect(v.hole, v.round);
      final pulse = 0.5 + 0.5 * math.sin(_clock * (_flash > 0 ? 16 : 4));
      _haloPaint.color = AppColors.butter.withValues(alpha: (0.28 + 0.2 * pulse) * a);
      canvas.drawRRect(rr.inflate(5), _haloPaint);
      _ringPaint.color = const Color(0xFFF2B33D).withValues(alpha: (0.75 + 0.25 * pulse) * a);
      canvas.drawRRect(rr, _ringPaint);
    }
    if (hand) _paintHand(canvas, a);
    final tag = v.tag;
    if (tag != null) {
      final r = Rect.fromCenter(center: v.tagAt, width: tag.size.width, height: tag.size.height);
      final at = r.topLeft - tag.origin;
      if (a >= 1) {
        drawPictureAt(canvas, tag.picture, at);
      } else {
        // Chỉ lúc mờ dần (200 ms): lớp nhỏ đúng cỡ nhãn.
        _layerPaint.color = Color.fromRGBO(0, 0, 0, a);
        canvas.saveLayer(r.inflate(8), _layerPaint);
        drawPictureAt(canvas, tag.picture, at);
        canvas.restore();
      }
    }
  }

  void _paintHand(Canvas canvas, double a) {
    var alpha = a;
    var scale = 1.0;
    if (_flash > 0) {
      // Nhấp nháy 3 lần trong 0,6 s, phóng nhẹ.
      final k = _flash / flashSec;
      alpha *= 0.3 + 0.7 * (0.5 + 0.5 * math.cos((1 - k) * math.pi * 6));
      scale = 1 + 0.12 * k;
    }
    if (alpha <= 0) return;
    const h = handHeight;
    canvas.save();
    canvas.translate(_tip.dx, _tip.dy);
    if (_side) canvas.rotate(math.pi / 2);
    if (scale != 1) canvas.scale(scale);
    final img = LevelArt.image(LevelArtId.tutorialHand);
    if (img != null) {
      final w = h * img.width / img.height;
      _handPaint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(-w * handTipFrac.dx, -h * handTipFrac.dy, w, h),
        _handPaint,
      );
    } else {
      final art = _handFallback ??= buildTutorialHandArt(h);
      if (alpha >= 1) {
        drawPictureAt(canvas, art.picture, -art.origin);
      } else {
        _layerPaint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
        canvas.saveLayer(Rect.fromLTWH(-art.size.width, -art.size.height, art.size.width * 2, art.size.height * 2), _layerPaint);
        drawPictureAt(canvas, art.picture, -art.origin);
        canvas.restore();
      }
    }
    canvas.restore();
  }
}

enum _Motion { tap, spin, swipe, none }

class _Target {
  TutorialSpot spot = TutorialSpot.none;
  Rect rect = Rect.zero;
  bool round = false;
  Offset anchor = Offset.zero;
  _Motion motion = _Motion.tap;
}

/// Tay chỉ vẽ code (khi chưa có `level/tutorial_hand.webp`): ngón trỏ hướng lên, nắm tay da ấm, cổ tay áo kem viền
/// bạc hà; nét mực nâu. Cao [h]; gốc hình = đầu ngón trỏ ([TutorialLayer.handTipFrac]) trừ [GameArt.origin].
GameArt buildTutorialHandArt(double h) {
  final w = h * TutorialLayer._fallbackAspect;
  final tip = Offset(w * TutorialLayer.handTipFrac.dx, h * TutorialLayer.handTipFrac.dy);
  const skin = Color(0xFFFFE1CC);
  const skinShade = Color(0xFFF4C3A6);
  final u = h / 92; // đơn vị theo cao 92
  final picture = recordArt((c) {
    // Ngón trỏ + nắm tay + ngón cái (hợp thành một khối để nét viền liền).
    final finger = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 8 * u, tip.dy, 16 * u, 50 * u), Radius.circular(8 * u)));
    final fist = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 10 * u, 34 * u, 50 * u, 40 * u), Radius.circular(15 * u)));
    final thumb = Path()..addOval(Rect.fromLTWH(tip.dx - 16 * u, 44 * u, 20 * u, 16 * u));
    var body = Path.combine(PathOperation.union, finger, fist);
    body = Path.combine(PathOperation.union, body, thumb);
    final shadow = body.shift(Offset(2.5 * u, 3 * u));
    c.drawPath(shadow, fill(const Color(0x335A3E36)));
    c.drawPath(body, fill(skin));
    c.save();
    c.clipPath(body);
    c.drawRect(Rect.fromLTWH(tip.dx + 26 * u, 30 * u, 20 * u, 50 * u), fill(skinShade));
    c.restore();
    c.drawPath(body, stroke(SLColors.ink, 2.4 * u));
    // Ba ngón gập + móng ngón trỏ.
    for (var i = 0; i < 3; i++) {
      final x = tip.dx + (10 + i * 10) * u;
      c.drawLine(Offset(x, 38 * u), Offset(x, 50 * u), softStroke(SLColors.ink.withValues(alpha: 0.7), 1.8 * u));
    }
    c.drawLine(Offset(tip.dx - 3 * u, tip.dy + 7 * u), Offset(tip.dx + 3 * u, tip.dy + 7 * u), softStroke(SLColors.ink.withValues(alpha: 0.45), 1.6 * u));
    // Cổ tay áo kem.
    final cuff = RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 4 * u, 70 * u, 46 * u, 20 * u), Radius.circular(6 * u));
    c.drawRRect(cuff, fill(AppColors.cream));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tip.dx - 4 * u, 82 * u, 46 * u, 5 * u), Radius.circular(2 * u)),
      fill(AppColors.mint),
    );
    c.drawRRect(cuff, stroke(SLColors.ink, 2.2 * u));
  });
  return GameArt(picture, Size(w, h), origin: tip);
}
