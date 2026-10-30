import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/sl_theme.dart';

enum _Shape { twinkle, dot, bit, heart, puff }

class _Particle {
  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.color,
    required this.shape,
    this.gravity = 0,
    this.spin = 0,
    this.angle = 0,
    this.grow = 0,
    this.variant = 0,
  });

  Offset pos;
  Offset vel;
  final double life;
  double age = 0;
  final double size;
  final Color color;
  final _Shape shape;
  final double gravity;
  final double spin;
  double angle;
  final double grow;

  /// Biến thể hình run tay (0..2).
  final int variant;
}

/// Lớp hiệu ứng nhẹ trên cùng: lấp lánh, bụi bột, vụn topping, tim. Tự vẽ (không cần ảnh) bằng hình run tay dựng
/// sẵn ([_FxShapes]); mỗi hạt chỉ co giãn + tô màu.
class EffectsLayer extends Component {
  EffectsLayer() : super(priority: 100);

  final List<_Particle> _ps = [];
  final math.Random _rnd = math.Random(7);

  static const _sparkleColors = [AppColors.butter, Color(0xFFFFFFFF), AppColors.strawberry, AppColors.mint];

  /// Lấp lánh toả ra (hoàn thành trạm, đặt đúng).
  void sparkle(Offset at, {int count = 14, double speed = 220}) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final v = speed * (0.4 + _rnd.nextDouble() * 0.6);
      _ps.add(_Particle(
        pos: at + Offset(math.cos(a), math.sin(a)) * 10,
        vel: Offset(math.cos(a), math.sin(a)) * v,
        life: 0.6 + _rnd.nextDouble() * 0.4,
        size: 7 + _rnd.nextDouble() * 9,
        color: _sparkleColors[i % _sparkleColors.length],
        shape: i % 3 == 0 ? _Shape.dot : _Shape.twinkle,
        gravity: 140,
        variant: i % 3,
      ));
    }
  }

  /// Tim bay lên (đóng hộp xong).
  void hearts(Offset at, {int count = 6}) {
    for (var i = 0; i < count; i++) {
      _ps.add(_Particle(
        pos: at + Offset((_rnd.nextDouble() - 0.5) * 120, (_rnd.nextDouble() - 0.5) * 30),
        vel: Offset((_rnd.nextDouble() - 0.5) * 60, -90 - _rnd.nextDouble() * 80),
        life: 1.0 + _rnd.nextDouble() * 0.4,
        size: 18 + _rnd.nextDouble() * 10,
        color: i.isEven ? AppColors.strawberry : const Color(0xFFF7B6C6),
        shape: _Shape.heart,
        variant: i % 2,
      ));
    }
  }

  /// Bụi bột / hơi nóng / khói mềm.
  void puff(Offset at, Color color, {int count = 3, double size = 18, double rise = 25}) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      _ps.add(_Particle(
        pos: at + Offset(math.cos(a), math.sin(a)) * 6,
        vel: Offset(math.cos(a) * 30, math.sin(a) * 30 - rise),
        life: 0.7 + _rnd.nextDouble() * 0.3,
        size: size * (0.6 + _rnd.nextDouble() * 0.5),
        color: color,
        shape: _Shape.puff,
        grow: 1.2,
        variant: i % 3,
      ));
    }
  }

  /// Vụn bắn ra rồi rơi (cốm, đường) khi đặt topping.
  void bits(Offset at, List<Color> colors, {int count = 10}) {
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 2.4;
      final v = 120 + _rnd.nextDouble() * 140;
      _ps.add(_Particle(
        pos: at,
        vel: Offset(math.cos(a), math.sin(a)) * v,
        life: 0.55 + _rnd.nextDouble() * 0.3,
        size: 4 + _rnd.nextDouble() * 4,
        color: colors[i % colors.length],
        shape: _Shape.bit,
        gravity: 700,
        spin: (_rnd.nextDouble() - 0.5) * 14,
        angle: _rnd.nextDouble() * math.pi,
        variant: i % 3,
      ));
    }
  }

  @override
  void update(double dt) {
    for (final p in _ps) {
      p.age += dt;
      final damp = math.exp(-1.5 * dt);
      p.vel = Offset(p.vel.dx * damp, p.vel.dy * damp + p.gravity * dt);
      p.pos += p.vel * dt;
      p.angle += p.spin * dt;
    }
    _ps.removeWhere((p) => p.age >= p.life);
  }

  // Paint tái sử dụng (chỉ gán màu / độ dày rồi vẽ ngay).
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// Vẽ ngay một sao lấp lánh 4 cánh (cùng dáng hạt `sparkle`) tâm [at], bán kính [size] px, màu [color] + viền mực
  /// nhạt — cho hiệu ứng kéo dài do nơi gọi tự định nhịp (vd. vật phẩm hỗ trợ), không tạo hạt.
  void twinkleAt(Canvas canvas, Offset at, double size, Color color, {int variant = 0, double angle = 0}) {
    if (color.a <= 0) return;
    final ink = Color.lerp(color, _umber, 0.55)!.withValues(alpha: 0.7 * color.a);
    _draw(canvas, _FxShapes.twinkles[variant % _FxShapes.twinkles.length], at, size, color, edge: ink, angle: angle);
  }

  /// Vẽ hình [shape] (dựng sẵn ở cỡ tham chiếu [_FxShapes.unit]) tâm [at], cỡ [size] px, xoay [angle]: lớp màu nước
  /// [color] + nét mép [edge] dày [edgeWidth] px (null = không viền).
  void _draw(Canvas canvas, Path shape, Offset at, double size, Color color, {Color? edge, double edgeWidth = 1.2, double angle = 0}) {
    final k = size / _FxShapes.unit;
    if (k <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (angle != 0) canvas.rotate(angle);
    canvas.scale(k);
    _fill.color = color;
    canvas.drawPath(shape, _fill);
    if (edge != null) {
      _edge
        ..color = edge
        ..strokeWidth = edgeWidth / k;
      canvas.drawPath(shape, _edge);
    }
    canvas.restore();
  }

  static const Color _umber = Color(0xFF6B4532);

  @override
  void render(Canvas canvas) {
    for (final p in _ps) {
      final t = p.age / p.life;
      final a = (1 - t).clamp(0.0, 1.0);
      final color = p.color.withValues(alpha: p.color.a * a);
      final ink = Color.lerp(p.color, _umber, 0.55)!.withValues(alpha: 0.7 * a);
      switch (p.shape) {
        case _Shape.twinkle:
          // Sao lấp lánh 4 cánh vẽ tay: màu nước + nét mực mảnh (như icon "sparkle" của bộ SL*).
          _draw(canvas, _FxShapes.twinkles[p.variant], p.pos, p.size * (1 - 0.4 * t), color, edge: ink, angle: (p.variant - 1) * 0.12);
        case _Shape.dot:
          _draw(canvas, _FxShapes.dots[p.variant], p.pos, p.size * 0.35, color, edge: ink, edgeWidth: 0.9);
        case _Shape.heart:
          // Tim vẽ tay (cùng dáng icon "heart" của bộ SL*): màu nước + viền mực.
          _draw(canvas, _FxShapes.hearts[p.variant], p.pos, p.size * 0.62, color, edge: SLColors.ink.withValues(alpha: 0.8 * a), edgeWidth: 1.6);
        case _Shape.puff:
          // Khói / bụi bột: vệt màu nước loang mềm (mép đọng màu nhạt + lõi sáng hơn), nở dần.
          final r = p.size * (1 + p.grow * t);
          _draw(canvas, _FxShapes.puffs[p.variant], p.pos, r, color.withValues(alpha: color.a * 0.5),
              edge: Color.lerp(p.color, _umber, 0.3)!.withValues(alpha: 0.16 * a), edgeWidth: 1.6);
          _draw(canvas, _FxShapes.puffCores[p.variant], p.pos.translate(-r * 0.15, -r * 0.18), r * 0.62,
              Color.lerp(p.color, const Color(0xFFFFFFFF), 0.45)!.withValues(alpha: 0.22 * a));
        case _Shape.bit:
          // Mảnh vụn: mẩu giấy màu run tay.
          _draw(canvas, _FxShapes.bits[p.variant], p.pos, p.size, color, edge: ink, edgeWidth: 0.9, angle: p.angle);
      }
    }
  }
}

/// Hình run tay của hiệu ứng, dựng một lần ở cỡ tham chiếu (bán kính ≈ [unit]) rồi co giãn khi vẽ — không sinh path
/// trong lúc vẽ khung.
abstract final class _FxShapes {
  static const double unit = 20;

  static Path _w(Path p, int seed, double amp) => wobblePath(p, seed: seed, amplitude: amp, step: 2.5);

  /// Sao 4 cánh cong (cánh hơi lệch nhau theo biến thể).
  static final twinkles = [
    for (var v = 0; v < 3; v++)
      () {
        final q = unit * (0.16 + 0.04 * v);
        const r = unit;
        return _w(
          Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(q, -q, r * (0.92 + 0.04 * v), 0)
            ..quadraticBezierTo(q, q, 0, r * (0.96 - 0.03 * v))
            ..quadraticBezierTo(-q, q, -r * 0.94, 0)
            ..quadraticBezierTo(-q, -q, 0, -r)
            ..close(),
          0xF100 + v,
          0.9,
        );
      }(),
  ];

  static final dots = [for (var v = 0; v < 3; v++) _w(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: unit)), 0xF110 + v, 1.6)];

  /// Tim (dáng icon "heart" của bộ SL*), tâm ở giữa khung 2·unit.
  static final hearts = [
    for (var v = 0; v < 2; v++)
      () {
        const s = unit * 2;
        Offset o(double x, double y) => Offset((x - 0.5) * s, (y - 0.5) * s);
        final a = o(.5, .84), b = o(.17, .26), c = o(.5, .32), d = o(.83, .26);
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(o(.18, .62).dx, o(.18, .62).dy, o(.05, .42).dx, o(.05, .42).dy, b.dx, b.dy)
          ..cubicTo(o(.29, .11).dx, o(.29, .11).dy, o(.46, .17).dx, o(.46, .17).dy, c.dx, c.dy)
          ..cubicTo(o(.54, .17).dx, o(.54, .17).dy, o(.71, .11).dx, o(.71, .11).dy, d.dx, d.dy)
          ..cubicTo(o(.95, .42).dx, o(.95, .42).dy, o(.82, .62).dx, o(.82, .62).dy, a.dx, a.dy)
          ..close();
        return _w(path, 0xF120 + v, 1.1);
      }(),
  ];

  /// Vệt khói / bụi: đốm loang méo nhiều.
  static final puffs = [for (var v = 0; v < 3; v++) _w(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: unit)), 0xF130 + v, 4.2)];
  static final puffCores = [for (var v = 0; v < 3; v++) _w(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: unit)), 0xF138 + v, 3.2)];

  /// Mẩu giấy vụn (dài 2·unit, cao 0,8·unit).
  static final bits = [
    for (var v = 0; v < 3; v++)
      _w(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: unit * 2, height: unit * 0.8), const Radius.circular(unit * 0.4))), 0xF140 + v, 1.4),
  ];
}
