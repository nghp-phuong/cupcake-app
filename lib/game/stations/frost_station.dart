import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../bakery_game.dart';
import '../components/backdrop.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/frost.dart';
import 'station.dart';

/// Trạm 4 — phủ kem: vẽ theo đường chấm xoắn ốc (2.5 vòng, 120 điểm) trên mặt bánh. Nét kem bán kính
/// `frostBrushRadius`. Xong khi bấm nút (đã có nét) hoặc tự dừng khi phủ ≥ 98%.
class FrostStation extends Station {
  FrostStation(BakeryGame game)
      : cakeBox = cakeRectFor(game.recipe.mould, recipe: game.recipe.id),
        super(game, StationId.frost) {
    top = CakeArt.topSurface(cakeBox, game.recipe.mould, recipe: game.recipe.id);
    tracker = FrostTracker(guide: spiralGuide(top), radius: game.modifiers.frostBrushRadius);
  }

  /// Khung bánh chuẩn (cạnh 460, ≈ khung của cupcake); đế xoay vẽ code đặt theo khung này. Khung thật của
  /// bánh đang làm là [cakeBox] / [cakeRectFor].
  static const Rect cakeRect = Rect.fromLTWH(220, 190, 460, 460);

  /// Khung bánh theo khuôn: đáy thân bánh ngồi trên mặt bàn xoay (tâm `KitchenBackdrop.frostTurntable`).
  static Rect cakeRectFor(MouldType mould, {RecipeId? recipe}) =>
      seatedCakeRect(mould, cakeRect.center.dx, KitchenBackdrop.frostTurntable.dy, cakeRect.width, recipe: recipe);

  /// Khung bánh đang làm (theo khuôn).
  final Rect cakeBox;
  static const Rect meterRect = Rect.fromLTWH(170, 104, 600, 22);
  static const double autoFinish = 0.98;

  late final Rect top;
  late final FrostTracker tracker;
  Offset? _bag;
  bool _drawing = false;
  double _settle = -1;
  double _dripClock = 0;

  Color get _cream => ItemArt.frostingColor(game.order.frosting);

  @override
  bool get usesDone => true;

  @override
  bool get canDone => tracker.hasStroke;

  @override
  void pointerDown(Offset p) {
    _bag = p;
    _drawing = true;
    tracker.begin(p);
    _check();
  }

  @override
  void pointerMove(Offset p) {
    if (!_drawing) return;
    _bag = p;
    tracker.extend(p);
    _check();
  }

  @override
  void pointerUp(Offset p) {
    _drawing = false;
    _bag = null;
  }

  @override
  void pointerCancel() => pointerUp(Offset.zero);

  @override
  void done() => _complete();

  void _check() {
    if (tracker.coverage >= autoFinish) _complete();
  }

  void _complete() {
    if (isDone) return;
    _drawing = false;
    _bag = null;
    game.record.frostCoverage = tracker.coverage;
    _settle = 0;
    if (tracker.coverage >= 0.9) game.effects.sparkle(top.center, count: 22);
    finish(delay: 1.2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_settle >= 0) _settle += dt;
    if (_drawing) {
      _dripClock += dt;
      if (_dripClock > 0.25 && _bag != null) {
        _dripClock = 0;
        game.effects.bits(_bag!, [_cream, const Color(0xFFFFFFFF)], count: 2);
      }
    }
  }

  @override
  void paintStation(Canvas canvas) {
    _paintMeter(canvas);
    if (ArtSprites.station(StationId.frost).image != null) {
      // Ảnh nền có sẵn bàn xoay ngay dưới bánh (KitchenBackdrop.frostTurntable): chỉ thêm bóng tiếp xúc.
      paintShadow(canvas, KitchenBackdrop.frostTurntable.translate(0, -4), 300, 46, alpha: 0.22);
    } else {
      // Đế xoay bánh.
      final standTop = Rect.fromCenter(center: Offset(cakeRect.center.dx, cakeRect.bottom - 26), width: 380, height: 70);
      paintShadow(canvas, standTop.center.translate(0, 40), 300, 40, alpha: 0.2);
      paintCakeStand(canvas, standTop);
    }

    final settleT = _settle < 0 ? 0.0 : easeInOut(_settle / 0.6);
    // Bánh trơn (chưa kem) mờ dần khi kem "lắng" thành lớp phủ thật.
    if (settleT < 1) CakeArt.paint(canvas, cakeBox, game.bakedCake);
    if (settleT > 0) {
      final wob = _settle < 0.6 ? 1 + 0.035 * math.sin(_settle * 18) * (1 - _settle / 0.6) : 1.0;
      canvas.save();
      final pivot = Offset(cakeBox.center.dx, cakeBox.center.dy + cakeBottomFactor(game.recipe.mould, recipe: game.recipe.id) * cakeBox.height);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(1 / wob, wob);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.saveLayer(cakeBox.inflate(40), Paint()..color = Color.fromRGBO(0, 0, 0, settleT));
      CakeArt.paint(canvas, cakeBox, game.bakedCake.copyWith(frosting: game.order.frosting, frostCoverage: tracker.coverage));
      canvas.restore();
      canvas.restore();
    }
    if (settleT < 1) {
      final a = 1 - settleT;
      _paintGuide(canvas, a);
      _paintStrokes(canvas, a);
    }
    // Túi kem.
    final b = _bag;
    if (b != null) {
      _paintBag(canvas, b, -0.45, squeeze: 1);
    } else if (_settle < 0) {
      _paintBag(canvas, Offset(780, 330 + math.sin(time * 2) * 4), 0.35);
    }
  }

  /// Túi bắt kem: ảnh vẽ tay của loại kem (custard là chén → dùng ảnh túi bắt kem chung), đầu túi tại [tip],
  /// thân túi hướng lên, nghiêng [tilt] rad như hình code. Chưa có ảnh → hình code.
  void _paintBag(Canvas canvas, Offset tip, double tilt, {double squeeze = 0}) {
    final custard = game.order.frosting == FrostingId.custard;
    final image = (custard ? ArtSprites.tool(ToolId.pipingBag) : ArtSprites.frosting(game.order.frosting)).image;
    if (image == null) {
      paintPipingBag(canvas, tip, _cream, tilt: tilt, squeeze: squeeze);
      return;
    }
    // Đầu đui và nút buộc túi trong ảnh 512×512 (ảnh túi kem: đầu dưới-trái, vốc kem nhỏ ở ngay sau đầu đui).
    final (anchor, top) = custard ? (const Offset(44, 468), const Offset(488, 42)) : (const Offset(88, 408), const Offset(420, 60));
    final axis = top - anchor;
    final scale = 200 / axis.distance * (1 - 0.04 * squeeze);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    // Xoay hệ toạ độ để trục túi trùng trục −y (thân túi hướng lên), rồi nghiêng [tilt].
    canvas.rotate(tilt);
    canvas.clipRect(const Rect.fromLTRB(-300, -400, 300, 3)); // bỏ phần quá đầu đui (vốc kem mẫu).
    drawArtRotated(canvas, image, Offset.zero, anchor, -math.pi / 2 - axis.direction, scale);
    canvas.restore();
  }

  /// Thanh % phủ kem vẽ tay: ống giấy + mốc 90% (cache), phần đã phủ tô màu kem (động), sao ở mốc.
  void _paintMeter(Canvas canvas) {
    final c = tracker.coverage;
    paintSketchMeter(
      canvas,
      meterRect,
      'frost',
      level: c,
      fillColor: Color.lerp(_cream, AppColors.strawberry, 0.25)!,
      front: (cv, r) {
        // Mốc 90% = điểm tối đa.
        final x = r.left + r.width * 0.9;
        cv.drawPath(wobblePath(Path()..moveTo(x, r.top + 2)..lineTo(x + 0.5, r.bottom - 2), seed: 0x90, amplitude: 0.8, step: 2), softStroke(SLColors.goodDeep, 3));
      },
    );
    final x = meterRect.left + meterRect.width * 0.9;
    final starRect = Rect.fromCenter(center: Offset(x, meterRect.top - 14), width: 30, height: 30);
    final star = ArtSprites.star(filled: c >= 0.9).image;
    if (star != null) {
      drawArt(canvas, star, starRect);
    } else {
      ItemArt.star(canvas, starRect.deflate(2), filled: c >= 0.9);
    }
  }

  static const double _dotRadius = 3.8;
  static const Color _dotColor = Color(0x805A3E36);

  /// Đường chấm gợi ý: chấm mực màu nước run tay (vài biến thể dựng sẵn) + vòng nhấp nháy run tay ở điểm kế tiếp.
  /// Khi kem đang "lắng" ([alpha] < 1) cả lớp mờ dần qua một lớp vẽ.
  void _paintGuide(Canvas canvas, double alpha) {
    final dots = [
      for (var v = 0; v < kGuideDotVariants; v++) cachedArt(('frostDot', v), () => buildInkDotArt(_dotRadius, _dotColor, v)),
    ];
    final fade = alpha < 0.999;
    if (fade) canvas.saveLayer(top.inflate(30), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    for (var i = 0; i < tracker.guide.length; i++) {
      if (tracker.covered[i]) continue;
      final art = dots[i % kGuideDotVariants];
      drawPictureAt(canvas, art.picture, tracker.guide[i] - art.origin);
    }
    // Điểm kế tiếp nhấp nháy dẫn đường: vòng mực hồng phồng ra + chấm hồng.
    final n = tracker.nextIndex;
    if (n >= 0 && _settle < 0) {
      final pulse = (math.sin(time * 5) + 1) / 2;
      final p = tracker.guide[n];
      final ring = cachedArt('frostRing', () => buildInkRingArt(12, AppColors.strawberry, 3, seed: 0xF2));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale((9 + pulse * 6) / 12);
      drawPictureAt(canvas, ring.picture, -ring.origin);
      canvas.restore();
      final dot = cachedArt('frostNext', () => buildInkDotArt(5.5, AppColors.strawberry, 7));
      drawPictureAt(canvas, dot.picture, p - dot.origin);
    }
    if (fade) canvas.restore();
  }

  // Bút kem tái sử dụng (mép đọng màu 2 lớp lệch nhau → nét dày mỏng, thân, lòng nhạt, rãnh kem, vệt sáng) + vùng cắt
  // mặt bánh (elip run tay) dựng một lần.
  final Paint _edgePaint = _creamPen();
  final Paint _bodyPaint = _creamPen();
  final Paint _innerPaint = _creamPen();
  final Paint _ridgePaint = _creamPen();
  final Paint _shinePaint = _creamPen();
  late final Path _strokeClip = wobblePath(
    Path()..addOval(top.inflate(tracker.radius * 0.6)),
    seed: 0xF205,
    amplitude: 2.4,
    step: 4,
  );

  static Paint _creamPen() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Vẽ toàn bộ nét kem kiểu màu nước: vài lệnh vẽ trên cùng một path cộng dồn (không dựng lại path mỗi khung).
  /// Mép đọng màu vẽ hai lần lệch nhau → viền nét dày mỏng theo hướng nét như vệt cọ; thân kem, lòng nét nhạt hơn, rãnh kem mảnh, vệt sáng lệch lên-trái. Cắt theo elip mặt bánh run tay.
  void _paintStrokes(Canvas canvas, double alpha) {
    if (!tracker.hasStroke) return;
    final r = tracker.radius;
    final path = tracker.path;
    _edgePaint
      ..color = Color.lerp(_cream, AppColors.caramel, 0.5)!.withValues(alpha: 0.7 * alpha)
      ..strokeWidth = r * 2 + 3;
    _bodyPaint
      ..color = _cream.withValues(alpha: alpha)
      ..strokeWidth = r * 2;
    _innerPaint
      ..color = Color.lerp(_cream, const Color(0xFFFFFFFF), 0.4)!.withValues(alpha: 0.55 * alpha)
      ..strokeWidth = r * 1.15;
    _ridgePaint
      ..color = Color.lerp(_cream, AppColors.caramel, 0.4)!.withValues(alpha: 0.32 * alpha)
      ..strokeWidth = r * 0.14;
    _shinePaint
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5 * alpha)
      ..strokeWidth = r * 0.42;
    canvas.save();
    canvas.clipPath(_strokeClip);
    canvas.drawPath(path, _edgePaint);
    canvas.save();
    canvas.translate(r * 0.14, r * 0.1);
    canvas.drawPath(path, _edgePaint);
    canvas.restore();
    canvas.drawPath(path, _bodyPaint);
    // Rãnh kem (vệt đầu đui để lại) chạy song song trong lòng nét.
    canvas.save();
    canvas.translate(r * 0.46, r * 0.4);
    canvas.drawPath(path, _ridgePaint);
    canvas.restore();
    canvas.translate(-r * 0.08, -r * 0.1);
    canvas.drawPath(path, _innerPaint);
    canvas.translate(-r * 0.24, -r * 0.27);
    canvas.drawPath(path, _shinePaint);
    canvas.restore();
  }
}
