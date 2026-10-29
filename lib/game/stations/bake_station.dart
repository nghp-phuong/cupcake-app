import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../bakery_game.dart';
import '../components/backdrop.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/bake_meter.dart';
import 'station.dart';

/// Trạm 3 — nướng: nhấn giữ (bất kỳ đâu trong vùng chơi) để thanh chạy 0→1 trong 3 giây; thả tay ở
/// vùng vàng. Giữ tới 1.0 thì tự thả (cháy).
class BakeStation extends Station {
  BakeStation(BakeryGame game) : super(game, StationId.bake);

  static const Rect ovenRect = Rect.fromLTWH(140, 170, 440, 420);
  static const Rect windowRect = Rect.fromLTWH(185, 268, 350, 250);
  static const Offset buttonCenter = Offset(760, 400);
  static const double buttonRadius = 82;
  static const Rect barRect = Rect.fromLTWH(110, 636, 720, 30);

  final BakeMeter meter = BakeMeter(fullSeconds: 3.0);

  // ------------------------------------------------------------------ Bộ đệm vẽ (không tạo lại mỗi khung)

  /// Số mức lượng tử hoá độ nóng cho shader (17 mức 0..16 — mắt không thấy bậc).
  static const int _heatLevels = 16;
  static final List<Shader?> _windowShaders = List<Shader?>.filled(_heatLevels + 1, null);
  static final List<Shader?> _innerGlowShaders = List<Shader?>.filled(_heatLevels + 1, null);
  static final Shader _frameShadeShader = Gradient.linear(windowRect.topCenter, windowRect.topCenter.translate(0, 26), const [
    Color(0x554A2E24),
    Color(0x004A2E24),
  ]);
  static final Path _coilPath = () {
    final path = Path()..moveTo(windowRect.left + 20, windowRect.bottom - 18);
    for (var i = 0; i < 8; i++) {
      final x = windowRect.left + 20 + (windowRect.width - 40) * (i + 0.5) / 8;
      path.quadraticBezierTo(x, windowRect.bottom - (i.isEven ? 34 : 4), windowRect.left + 20 + (windowRect.width - 40) * (i + 1) / 8, windowRect.bottom - 18);
    }
    return path;
  }();
  static final Path _glassShine = () {
    final path = Path();
    for (final (x, w) in [(windowRect.right - 120, 34.0), (windowRect.right - 74, 12.0)]) {
      path
        ..moveTo(x, windowRect.top)
        ..lineTo(x + w, windowRect.top)
        ..lineTo(x + w - 90, windowRect.bottom)
        ..lineTo(x - 90, windowRect.bottom)
        ..close();
    }
    return path;
  }();

  /// Nền ô kính theo mức nóng: tối nâu → cam ấm.
  static Shader _windowShader(int level) => _windowShaders[level] ??= () {
        final glow = Color.lerp(const Color(0xFF6B4A3A), const Color(0xFFFFB25E), 0.35 + 0.65 * level / _heatLevels)!;
        return Gradient.linear(windowRect.topCenter, windowRect.bottomCenter, [
          Color.lerp(glow, const Color(0xFF4A2E24), 0.45)!,
          glow,
          Color.lerp(glow, const Color(0xFFFFE3A3), 0.3)!,
        ], const [
          0,
          0.6,
          1,
        ]);
      }();

  /// Quầng sáng ấm giữa lò: gradient tròn mô phỏng đĩa bán kính 200 làm mờ sigma 40 (không dùng blur).
  static Shader _innerGlowShader(int level) => _innerGlowShaders[level] ??= () {
        final a = 0.25 + 0.45 * level / _heatLevels;
        const c = Color(0xFFFFE3A3);
        return Gradient.radial(windowRect.center.translate(0, 40), 300, [
          for (final k in const [1.0, 0.977, 0.84, 0.5, 0.16, 0.023, 0.0]) c.withValues(alpha: a * k),
        ], const [
          0,
          0.4,
          0.533,
          0.667,
          0.8,
          0.933,
          1,
        ]);
      }();

  /// Ô kính của lò âm tường trong ảnh nền `station_bake` (toạ độ ảnh: vòm trên 484..797, đáy 387), đã dời
  /// theo `KitchenBackdrop.bakeArtRect` → toạ độ khung. Chỉ dùng khi có ảnh nền.
  static final Path _artGlass = () {
    final o = KitchenBackdrop.bakeArtRect.topLeft;
    return (Path()
          ..moveTo(484, 250)
          ..quadraticBezierTo(640, 166, 797, 250)
          ..lineTo(797, 376)
          ..quadraticBezierTo(797, 387, 786, 387)
          ..lineTo(495, 387)
          ..quadraticBezierTo(484, 387, 484, 376)
          ..close())
        .shift(o);
  }();
  static final Rect _artGlassRect = _artGlass.getBounds();

  /// Màu tối phủ ô kính ảnh nền khi lò nguội (ảnh vẽ sẵn ô kính đang sáng).
  static const Color _coolTint = Color(0xFF4A2E24);

  bool get _hasArt => ArtSprites.station(StationId.bake).image != null;

  final Paint _shaderPaint = Paint()..isAntiAlias = true;
  final Paint _counterGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
  final Paint _lampGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _coilGlow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 14
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _halo = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  double _heat = 0;
  double _press = 0;
  double _smokeClock = 0;
  double _doneT = 0;

  double get target => game.recipe.bakeTarget;

  @override
  void pointerDown(Offset p) {
    if (!kPlayArea.contains(p)) return;
    meter.press();
  }

  @override
  void pointerUp(Offset p) => _lift();

  @override
  void pointerCancel() => _lift();

  void _lift() {
    if (!meter.holding) return;
    meter.lift();
    if (meter.released) _complete();
  }

  void _complete() {
    if (isDone) return;
    final r = meter.release ?? meter.value;
    game.record.bakeRelease = r;
    final d = (r - target).abs();
    final cakeCenter = windowRect.center;
    if (d <= game.modifiers.bakePerfectHalfWidth) {
      game.effects.sparkle(cakeCenter, count: 24, speed: 260);
    } else if (d <= game.modifiers.bakeOkHalfWidth) {
      game.effects.sparkle(cakeCenter, count: 10, speed: 180);
    } else if (r > target) {
      game.effects.puff(cakeCenter.translate(0, -60), const Color(0xFF8A7F78), count: 6, size: 26, rise: 60);
    }
    finish(delay: 1.1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (meter.tick(dt)) _complete();
    _heat = approach(_heat, meter.holding ? 1 : 0, dt, speed: meter.holding ? 4 : 2);
    _press = approach(_press, meter.holding ? 1 : 0, dt, speed: 18);
    if (isDone) _doneT += dt;
    // Khói khi quá lửa.
    final baked = bakedVisual(meter.value, target);
    if (meter.holding && baked > 1.25) {
      _smokeClock += dt;
      if (_smokeClock > 0.18) {
        _smokeClock = 0;
        game.effects.puff(Offset(ovenRect.center.dx + (math.sin(time * 7) * 60), ovenRect.top + 10), const Color(0xFF9A918A), count: 1, size: 20, rise: 70);
      }
    } else if (meter.holding && time % 0.5 < dt) {
      game.effects.puff(Offset(ovenRect.center.dx + math.sin(time * 5) * 80, ovenRect.top + 6), const Color(0xFFFFFFFF), count: 1, size: 14, rise: 50);
    }
  }

  @override
  void paintFixed(Canvas canvas) {
    // Có ảnh nền: lò là lò âm tường trong ảnh (không trượt) → chỉ vẽ phần bên trong ô kính.
    if (_hasArt) _paintArtOven(canvas);
  }

  @override
  void paintStation(Canvas canvas) {
    if (!_hasArt) _paintOven(canvas);
    _paintButton(canvas);
    _paintBar(canvas);
  }

  /// Bên trong ô kính lò của ảnh nền: tối khi nguội, sáng cam khi đang giữ; giá nướng + bánh nở dần.
  void _paintArtOven(Canvas canvas) {
    final g = _artGlassRect;
    // Quầng cam hắt xuống mặt bàn và quanh ô kính khi lò nóng.
    if (_heat > 0.02) {
      _counterGlow.color = const Color(0xFFFFA24A).withValues(alpha: 0.3 * _heat);
      canvas.drawOval(Rect.fromCenter(center: Offset(g.center.dx, ovenRect.bottom + 22), width: ovenRect.width * 1.1, height: 60), _counterGlow);
    }
    final haloA = 0.1 + 0.5 * _heat;
    for (final (w, k) in const [(30.0, 0.16), (22.0, 0.22), (14.0, 0.3), (7.0, 0.4)]) {
      _halo
        ..color = const Color(0xFFFF9A3C).withValues(alpha: haloA * k)
        ..strokeWidth = w;
      canvas.drawPath(_artGlass, _halo);
    }
    final level = (_heat.clamp(0.0, 1.0) * _heatLevels).round();
    canvas.save();
    canvas.clipPath(_artGlass);
    canvas.drawRect(g, fill(_coolTint.withValues(alpha: 0.62 * (1 - _heat.clamp(0.0, 1.0)))));
    canvas.drawRect(g, _shaderPaint..shader = _innerGlowShader(level));
    // Giá nướng thép vẽ tay.
    final rackY = g.bottom - 22;
    paintOvenRack(canvas, g.left, g.right, rackY);
    _paintCake(canvas, Offset(g.center.dx, rackY), 180);
    canvas.restore();
  }

  /// Bánh đang nướng (ảnh đế đã nướng / hình code, cùng kiểu với các trạm sau): đáy ở [bottom], nở dần theo
  /// độ chín (ép dọc từ đáy) và đổi màu theo độ chín.
  void _paintCake(Canvas canvas, Offset bottom, double size) {
    final baked = bakedVisual(meter.released ? meter.release! : meter.value, target);
    final rise = math.min(1.0, baked);
    // Đáy thân bánh (ảnh hoặc hình code) ngồi trên giá, bất kể khuôn.
    final cakeRect = seatedCakeRect(game.recipe.mould, bottom.dx, bottom.dy, size, seat: 0.5);
    canvas.save();
    final pop = _doneT > 0 && _doneT < 0.4 ? 1 + 0.06 * math.sin(_doneT / 0.4 * math.pi) : 1.0;
    canvas.translate(bottom.dx, bottom.dy);
    canvas.scale(pop, (0.8 + 0.2 * rise) * pop);
    canvas.translate(-bottom.dx, -bottom.dy);
    CakeArt.paint(canvas, cakeRect, CakeVisual(mould: game.recipe.mould, batter: game.recipe.batter, baked: baked));
    canvas.restore();
  }

  void _paintOven(Canvas canvas) {
    final r = ovenRect;
    paintShadow(canvas, r.bottomCenter.translate(0, -4), r.width * 1.05, 36, alpha: 0.24);
    // Quầng cam hắt xuống mặt bàn khi lò nóng.
    if (_heat > 0.02) {
      _counterGlow.color = const Color(0xFFFFA24A).withValues(alpha: 0.3 * _heat);
      canvas.drawOval(Rect.fromCenter(center: r.bottomCenter.translate(0, 10), width: r.width * 1.25, height: 70), _counterGlow);
    }
    // Chân lò gỗ.
    for (final x in [r.left + 40, r.right - 40]) {
      final foot = RRect.fromRectAndRadius(Rect.fromLTWH(x - 18, r.bottom - 10, 36, 26), const Radius.circular(8));
      canvas.drawRRect(foot, fill(const Color(0xFFA86E45)));
      canvas.drawRect(Rect.fromLTWH(x - 14, r.bottom - 6, 28, 8), fill(const Color(0xFFC48A55)));
      canvas.drawRRect(foot, stroke(kInk, 3));
    }
    // Thân lò men hồng đào: lớp bóng trái-dưới, lớp sáng phải.
    const enamel = Color(0xFFF4B9AE);
    final body = RRect.fromRectAndRadius(r, const Radius.circular(34));
    canvas.drawRRect(body, fill(shadeOf(enamel, 0.22)));
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRRect(body.shift(const Offset(12, -10)), fill(enamel));
    canvas.drawRRect(RRect.fromLTRBR(r.right - 22, r.top + 40, r.right - 13, r.bottom - 48, const Radius.circular(5)), fill(lightOf(enamel, 0.55)));
    canvas.drawRRect(RRect.fromLTRBR(r.left + 40, r.top + 6, r.right - 50, r.top + 12, const Radius.circular(3)), fill(lightOf(enamel, 0.45)));
    canvas.restore();
    canvas.drawRRect(body, stroke(kInk, 4));

    // Bảng điều khiển: 2 núm đồng + đồng hồ (kim chạy theo thanh nướng) + đèn báo.
    final panel = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 24, r.top + 18, r.width - 48, 64), const Radius.circular(18));
    canvas.drawRRect(panel, fill(const Color(0xFFF1E0C9)));
    canvas.save();
    canvas.clipRRect(panel);
    canvas.drawRRect(panel.shift(const Offset(4, -5)), fill(const Color(0xFFFFF6E8)));
    canvas.restore();
    canvas.drawRRect(panel, stroke(kInk, 3));
    for (final x in [r.left + 70, r.right - 70]) {
      final k = Offset(x, r.top + 50);
      canvas.drawCircle(k.translate(-2, 3), 19, fill(const Color(0x337A4A34)));
      canvas.drawCircle(k, 18, fill(shadeOf(const Color(0xFFE9B85F), 0.25)));
      canvas.drawCircle(k.translate(2, -2), 15, fill(const Color(0xFFE9B85F)));
      canvas.drawArc(Rect.fromCircle(center: k, radius: 13), -math.pi * 0.45, math.pi * 0.35, false, softStroke(const Color(0xCCFFF6DA), 3));
      canvas.drawCircle(k, 18, stroke(kInk, 3));
      final a = -math.pi / 2 + (x < r.center.dx ? _heat * 1.6 : 0.6);
      canvas.drawLine(k, k + Offset(math.cos(a), math.sin(a)) * 12, softStroke(kInk, 3));
    }
    // Đèn báo nhiệt.
    final lamp = Offset(r.left + 122, r.top + 50);
    final lampColor = Color.lerp(const Color(0xFFD9C3AE), const Color(0xFFFF8A3D), _heat)!;
    if (_heat > 0.05) {
      _lampGlow.color = const Color(0xFFFFA24A).withValues(alpha: 0.6 * _heat);
      canvas.drawCircle(lamp, 14, _lampGlow);
    }
    canvas.drawCircle(lamp, 6, fill(lampColor));
    canvas.drawCircle(lamp.translate(1.5, -1.5), 2, fill(const Color(0xCCFFFFFF)));
    canvas.drawCircle(lamp, 6, stroke(kInk, 2));
    final dial = Offset(r.center.dx, r.top + 50);
    canvas.drawCircle(dial, 24, fill(const Color(0xFFFFFDF7)));
    for (var i = 0; i <= 6; i++) {
      final ta = math.pi * 0.75 + math.pi * 1.5 * i / 6;
      final dir = Offset(math.cos(ta), math.sin(ta));
      canvas.drawLine(dial + dir * 17, dial + dir * 21, softStroke(const Color(0x99B9805A), 1.6));
    }
    canvas.drawArc(Rect.fromCircle(center: dial, radius: 14), math.pi * 0.75, math.pi * 1.5, false, stroke(const Color(0x26B9805A), 4));
    final na = math.pi * 0.75 + math.pi * 1.5 * meter.value;
    canvas.drawLine(dial, dial + Offset(math.cos(na), math.sin(na)) * 17, softStroke(AppColors.bad, 3));
    canvas.drawArc(Rect.fromCircle(center: dial, radius: 21), -math.pi * 0.4, math.pi * 0.3, false, softStroke(const Color(0x14000000), 3));
    canvas.drawCircle(dial, 24, stroke(kInk, 3));
    canvas.drawCircle(dial, 3.5, fill(kInk));

    // Cửa lò kem + quầng sáng cam quanh ô kính.
    final door = RRect.fromRectAndRadius(windowRect.inflate(16), const Radius.circular(30));
    canvas.drawRRect(door, fill(const Color(0xFFEFDDC6)));
    canvas.save();
    canvas.clipRRect(door);
    canvas.drawRRect(door.shift(const Offset(5, -5)), fill(const Color(0xFFFFF8EC)));
    canvas.restore();
    final win = RRect.fromRectAndRadius(windowRect, const Radius.circular(22));
    // Quầng cam: vài vành chồng nhau mờ dần ra ngoài (thay cho làm mờ — rẻ hơn khi vẽ mỗi khung).
    final haloA = 0.18 + 0.5 * _heat;
    for (final (w, k) in const [(30.0, 0.16), (22.0, 0.22), (14.0, 0.3), (7.0, 0.4)]) {
      _halo
        ..color = const Color(0xFFFF9A3C).withValues(alpha: haloA * k)
        ..strokeWidth = w;
      canvas.drawRRect(win, _halo);
    }
    canvas.drawRRect(door, stroke(kInk, 3.5));
    final level = (_heat.clamp(0.0, 1.0) * _heatLevels).round();
    canvas.save();
    canvas.clipRRect(win);
    canvas.drawRect(windowRect, _shaderPaint..shader = _windowShader(level));
    // Quầng sáng ấm ở giữa.
    canvas.drawRect(windowRect, _shaderPaint..shader = _innerGlowShader(level));
    // Giá nướng thép vẽ tay.
    final rackY = windowRect.bottom - 54;
    paintOvenRack(canvas, windowRect.left, windowRect.right, rackY);
    // Thanh nhiệt đỏ rực khi đang giữ (có quầng mờ).
    final coil = Color.lerp(const Color(0xFF8A5A42), const Color(0xFFFF5A3C), _heat)!;
    final coilPath = _coilPath;
    if (_heat > 0.05) {
      _coilGlow.color = const Color(0xFFFF7A3C).withValues(alpha: 0.55 * _heat);
      canvas.drawPath(coilPath, _coilGlow);
    }
    canvas.drawPath(coilPath, stroke(coil, 5));
    canvas.drawPath(coilPath, stroke(Color.lerp(coil, const Color(0xFFFFE3A3), 0.5 * _heat)!, 1.5));
    // Bánh: nở dần theo độ chín.
    final baked = bakedVisual(meter.released ? meter.release! : meter.value, target);
    final rise = math.min(1.0, baked);
    final cakeRect = seatedCakeRect(game.recipe.mould, windowRect.center.dx, rackY, 190, seat: 0.5);
    canvas.save();
    final bottom = Offset(cakeRect.center.dx, rackY);
    final pop = _doneT > 0 && _doneT < 0.4 ? 1 + 0.06 * math.sin(_doneT / 0.4 * math.pi) : 1.0;
    canvas.translate(bottom.dx, bottom.dy);
    canvas.scale(pop, (0.8 + 0.2 * rise) * pop);
    canvas.translate(-bottom.dx, -bottom.dy);
    CakeArt.paint(canvas, cakeRect, CakeVisual(mould: game.recipe.mould, batter: game.recipe.batter, baked: baked));
    canvas.restore();
    // Bóng khung đổ vào mép trên kính + phản chiếu kính chéo.
    canvas.drawRect(Rect.fromLTWH(windowRect.left, windowRect.top, windowRect.width, 26), _shaderPaint..shader = _frameShadeShader);
    canvas.drawPath(_glassShine, fill(const Color(0x40FFFFFF)));
    canvas.restore();
    canvas.drawRRect(win, stroke(kInk, 3));
    // Tay nắm đồng trên hai chân đỡ.
    final hy = windowRect.top - 12;
    for (final x in [windowRect.left + 68, windowRect.right - 68]) {
      final post = RRect.fromRectAndRadius(Rect.fromLTWH(x - 6, hy + 4, 12, 14), const Radius.circular(3));
      canvas.drawRRect(post, fill(shadeOf(const Color(0xFFE9B85F), 0.25)));
      canvas.drawRRect(post, stroke(kInk, 2));
    }
    final handle = RRect.fromRectAndRadius(Rect.fromLTWH(windowRect.left + 56, hy - 2, windowRect.width - 112, 14), const Radius.circular(7));
    canvas.drawRRect(handle, fill(shadeOf(const Color(0xFFE9B85F), 0.2)));
    canvas.drawRRect(handle.shift(const Offset(0, -2)).deflate(1), fill(const Color(0xFFE9B85F)));
    canvas.drawLine(Offset(handle.right - 70, hy + 2), Offset(handle.right - 14, hy + 2), softStroke(const Color(0xE6FFF6DA), 2.5));
    canvas.drawRRect(handle, stroke(kInk, 2.5));
    // Ngăn kéo dưới cửa.
    final drawer = RRect.fromRectAndRadius(Rect.fromLTRB(r.left + 44, windowRect.bottom + 26, r.right - 44, r.bottom - 14), const Radius.circular(12));
    canvas.drawRRect(drawer, fill(shadeOf(enamel, 0.12)));
    canvas.drawRRect(drawer, stroke(kInk, 2.5));
    final pull = RRect.fromRectAndRadius(Rect.fromCenter(center: drawer.center, width: 60, height: 9), const Radius.circular(4.5));
    canvas.drawRRect(pull, fill(const Color(0xFFE9B85F)));
    canvas.drawRRect(pull, stroke(kInk, 2));
  }

  /// Độ lún của mặt nút Giữ khi nhấn (nhãn dán lún xuống, bóng đứng yên).
  static const double _pressDepth = 5;

  /// Nút Giữ kiểu nhãn dán vẽ tay: đế giấy + bóng (cố định), vòng tiến độ màu nước, mặt nút (ngọn lửa + chữ)
  /// lún xuống khi giữ. Các phần run tay đều là Picture trong cache; mỗi khung chỉ vẽ lại vòng tiến độ.
  void _paintButton(Canvas canvas) {
    const c = buttonCenter;
    const r = buttonRadius;
    final base = cachedArt(('holdBase', r), () => _buildHoldBase(r));
    drawPictureAt(canvas, base.picture, c - base.origin);
    final v = meter.released ? meter.release! : meter.value;
    final step = (v.clamp(0.0, 1.0) * _ringSteps).round();
    if (step > 0) {
      // Vòng tiến độ màu nước chạy theo vòng run tay (đoạn cắt sẵn theo bậc, không dựng path mỗi khung).
      final arc = _ringArc(step);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.drawPath(arc, softStroke(const Color(0xE6F2B33D), 10));
      canvas.translate(-0.8, -1);
      canvas.drawPath(arc, softStroke(const Color(0x80FFE6A6), 3.5));
      canvas.translate(1.6, 6.2);
      canvas.drawPath(arc, softStroke(const Color(0x8CB9805A), 1.4));
      canvas.restore();
    }
    // 0 nghỉ, 1 đang giữ, 2 đã thả (tắt).
    final state = meter.released ? 2 : (_press > 0.5 ? 1 : 0);
    final label = game.labels.hold;
    final font = game.text.titleFontFamily;
    final face = cachedArt(('holdFace', r, state, label, font), () => _buildHoldFace(r, state, label));
    drawPictureAt(canvas, face.picture, c.translate(0, _pressDepth * _press) - face.origin);
  }

  /// Số bậc của vòng tiến độ (mỗi bậc một đoạn cắt sẵn, mắt không thấy bậc).
  static const int _ringSteps = 90;
  static final List<Path?> _ringArcs = List<Path?>.filled(_ringSteps + 1, null);
  static PathMetric? _ringMetric;

  /// Đoạn [0, step/_ringSteps] của vòng run tay bán kính `buttonRadius + 10` quanh gốc toạ độ, bắt đầu ở đỉnh,
  /// chạy theo chiều kim đồng hồ. Cắt một lần cho mỗi bậc rồi giữ lại.
  static Path _ringArc(int step) => _ringArcs[step] ??= () {
        final m = _ringMetric ??= () {
          final rect = Rect.fromCircle(center: Offset.zero, radius: buttonRadius + 10);
          final ideal = Path()
            ..moveTo(0, -rect.height / 2)
            ..arcTo(rect, -math.pi / 2, math.pi, false)
            ..arcTo(rect, math.pi / 2, math.pi, false)
            ..close();
          return wobblePath(ideal, seed: 0x4010, amplitude: 1.8, step: 4).computeMetrics().first;
        }();
        return m.extractPath(0, m.length * step / _ringSteps);
      }();

  /// Đế giấy dưới nút Giữ (vòng ngoài chứa vòng tiến độ, có rãnh bút chì nhạt) + bóng nâu mềm của mặt nút.
  static GameArt _buildHoldBase(double r) {
    final outer = r + 18;
    final disc = buildStickerDisc(outer, SLColors.paper, seed: 0x401D, inkWidth: 2.6);
    final m = disc.origin;
    final picture = recordArt((cv) {
      paintShadow(cv, m.translate(0, outer * 0.85), outer * 1.9, outer * 0.42, alpha: 0.2);
      cv.drawPicture(disc.picture);
      cv.save();
      cv.translate(m.dx, m.dy);
      cv.drawPath(_ringArc(_ringSteps), softStroke(const Color(0x1FB9805A), 9));
      cv.restore();
      final shade = wobblePath(Path()..addOval(Rect.fromCircle(center: m.translate(0, SLMetrics.buttonLift + 2), radius: r)), seed: 0x401F, amplitude: 1.4);
      cv.drawPath(shade, fill(SLColors.shadow));
    });
    return GameArt(picture, Size.square(outer * 2), origin: m, parts: [disc]);
  }

  /// Mặt nút Giữ: nhãn dán màu nước vàng bơ (đang giữ: cam nắng, đã thả: xám nhạt), ngọn lửa + chữ [label] mực.
  GameArt _buildHoldFace(double r, int state, String label) {
    final color = switch (state) {
      0 => AppColors.butter,
      1 => const Color(0xFFFFB25E),
      _ => SLColors.disabledFill,
    };
    final ink = state == 2 ? SLColors.disabledInk : SLColors.ink;
    final text = game.text.layout(label, size: 26, weight: FontWeight.w700, color: ink, maxWidth: r * 1.6, title: true);
    return buildStickerDisc(r, color, seed: 0x401E, inkWidth: 3.2, ink: ink, text: text, content: (cv, o) {
      paintSLIcon(cv, 'flame', o.translate(0, -22), 50, ink: ink);
      text.paint(cv, o.translate(-text.width / 2, 12));
    });
  }

  /// Thanh nướng vẽ tay: ống giấy tô chuyển màu bột sống → cháy, vùng "được" và vùng vàng "hoàn hảo" bằng màu nước
  /// (cache theo mục tiêu / độ rộng vùng); mỗi khung chỉ vẽ kim.
  void _paintBar(Canvas canvas) {
    double xOf(double v) => barRect.left + barRect.width * v.clamp(0.0, 1.0);
    final ok = game.modifiers.bakeOkHalfWidth;
    final perfect = game.modifiers.bakePerfectHalfWidth;
    final t = target;
    paintSketchMeter(
      canvas,
      barRect,
      ('bake', t, ok, perfect),
      back: (c, r) {
        // Bột sống → vàng → cháy: nền kem + các lớp màu nước trong suốt chồng dần sang phải (mép mỗi lớp đọng màu,
        // run tay) → màu đậm dần như tô nhiều lượt.
        paintWashBand(c, Rect.fromLTRB(r.left - 6, r.top - 4, r.right + 6, r.bottom + 4), const Color(0xFFFFF3DE), 0xBA0, alpha: 1, highlight: false);
        for (final (from, color, alpha, seed) in const [
          (0.24, Color(0xFFF3D9B5), 0.55, 0xBA1),
          (0.44, Color(0xFFEBC596), 0.55, 0xBA2),
          (0.6, Color(0xFFD9A877), 0.6, 0xBA3),
          (0.72, Color(0xFFC48F62), 0.65, 0xBA4),
          (0.82, Color(0xFF9E6A4C), 0.7, 0xBA5),
          (0.91, Color(0xFF6E4A3C), 0.75, 0xBA6),
        ]) {
          paintWashBand(c, Rect.fromLTRB(r.left + r.width * from, r.top - 4, r.right + 6, r.bottom + 4), color, seed, alpha: alpha, highlight: false);
        }
      },
      front: (c, r) {
        double x(double v) => r.left + r.width * v.clamp(0.0, 1.0);
        paintWashBand(c, Rect.fromLTRB(x(t - ok), r.top - 4, x(t + ok), r.bottom + 4), const Color(0xFFFFE6A6), 0xB0, alpha: 0.95);
        paintWashBand(c, Rect.fromLTRB(x(t - perfect), r.top - 4, x(t + perfect), r.bottom + 4), const Color(0xFFF2B33D), 0xB1, alpha: 0.95);
      },
    );
    final v = meter.released ? meter.release! : meter.value;
    paintSketchMarker(canvas, barRect, xOf(v));
  }
}
