import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../sugarleaf/sugarleaf.dart';

/// Hình vẽ tay tĩnh của bản đồ chương: nền dự phòng (khi chưa có ảnh `assets/art/map/<mapArt>.webp`) và đường đi
/// nét đứt nối các nút level. Mỗi hình ghi MỘT lần thành `Picture` (cache LRU nhỏ theo chương/cỡ/tiến trình), mỗi
/// khung chỉ `drawPicture` — trang bản đồ nằm trong `RepaintBoundary` nên gần như không vẽ lại.

const _sea = Color(0xFFA8DCC8);
const _seaDeep = Color(0xFF8CCDB6);
const _sand = Color(0xFFFFE8B5);
const _grain = Color(0x22B9805A);

/// Cache Picture nhỏ (LinkedHashMap: cuối = dùng gần nhất); mục bị đẩy ra được `dispose`.
class _PictureCache {
  _PictureCache(this.max);

  final int max;
  final _map = <String, ui.Picture>{};

  ui.Picture obtain(String key, ui.Picture Function() build) {
    final hit = _map.remove(key);
    if (hit != null) return _map[key] = hit;
    final p = _map[key] = build();
    while (_map.length > max) {
      _map.remove(_map.keys.first)!.dispose();
    }
    return p;
  }
}

final _backdrops = _PictureCache(4);
final _trails = _PictureCache(6);

ui.Picture _record(Size size, void Function(Canvas c) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec, Offset.zero & size));
  return rec.endRecording();
}

// ---------------------------------------------------------------------------------------------------- Nền dự phòng

/// Nền bản đồ vẽ bằng code (chưa có ảnh): giấy kem có hạt, đồi cỏ bạc hà loang màu nước, dải cát vàng bơ và biển
/// bạc hà có sóng nét mực ở mép dưới. Mỗi chương một bố cục (theo [seed]). Không vẽ nhân vật.
class MapPaperBackdrop extends StatelessWidget {
  const MapPaperBackdrop({super.key, required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BackdropPainter(seed), size: Size.infinite);
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = '$seed|${size.width.round()}x${size.height.round()}';
    canvas.drawPicture(_backdrops.obtain(key, () => _record(size, (c) => _paintBackdrop(c, size, seed))));
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.seed != seed;
}

void _paintBackdrop(Canvas c, Size s, int seed) {
  final w = s.width, h = s.height;
  final rnd = SLRandom(seed);
  c.drawRect(Offset.zero & s, Paint()..color = SLColors.cream);

  // Hạt giấy.
  final grain = Paint()..color = _grain;
  for (var i = 0; i < 260; i++) {
    c.drawCircle(Offset(rnd.range(0, w), rnd.range(0, h)), rnd.range(0.6, 1.6), grain);
  }

  // Đồi cỏ: các mảng bạc hà loang (2 lớp lệch nhau như màu nước thấm giấy) + nét mực run nhạt.
  final hillInk = Paint()
    ..color = const Color(0x667A5442)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 5; i++) {
    final cx = w * (0.08 + 0.21 * i + rnd.range(-0.04, 0.04));
    final cy = h * rnd.range(0.2, 0.62);
    final rx = w * rnd.range(0.09, 0.15), ry = h * rnd.range(0.08, 0.14);
    final oval = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    final blob = wobblePath(Path()..addOval(oval), seed: SLRandom.mix(seed, i), amplitude: 7, step: 8);
    c.drawPath(blob.shift(const Offset(5, 4)), Paint()..color = const Color(0x55A8DCC8));
    c.drawPath(blob, Paint()..color = const Color(0x8CD7EFE5));
    c.drawPath(extractFraction(blob, 0.55, 0.95), hillInk);
  }

  // Bờ cát + biển ở mép dưới (mép sóng lượn, nét mực run).
  Path shore(double base, double amp, int salt) {
    final p = Path()..moveTo(0, h);
    final r = SLRandom(SLRandom.mix(seed, salt));
    final phase = r.range(0, math.pi * 2);
    for (var x = 0.0; x <= w + 1; x += 16) {
      final y = h * base + amp * math.sin(x / w * math.pi * 2.4 + phase) + amp * 0.35 * math.sin(x / 37 + phase);
      p.lineTo(x, y);
    }
    return p
      ..lineTo(w, h)
      ..close();
  }

  final sand = shore(0.8, 10, 11);
  c.drawPath(sand, Paint()..color = _sand);
  final sea = shore(0.86, 8, 12);
  c.drawPath(sea, Paint()..color = _sea);
  c.drawPath(
    wobblePath(sea, seed: SLRandom.mix(seed, 13), amplitude: 1.6, step: 6),
    Paint()
      ..color = const Color(0x997A5442)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2,
  );
  // Sóng: vài nét cong ngắn.
  final wave = Paint()
    ..color = _seaDeep
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 9; i++) {
    final x = w * (0.05 + 0.105 * i + rnd.range(-0.02, 0.02));
    final y = h * rnd.range(0.91, 0.97);
    c.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 14, y - 8, x + 28, y),
      wave,
    );
  }
}

// ---------------------------------------------------------------------------------------------------- Đường đi

/// Đường đi vẽ tay qua [points] (tâm các nút theo thứ tự level): đường cong mượt (Catmull-Rom) run tay, hai lớp để
/// nổi trên cả ảnh bản đồ nhiều chi tiết (mái ngói chương 4–5): bóng mềm + viền kem dày (~6,5 px mỗi bên) + lõi nâu.
/// [done] đoạn đầu (đã qua): lõi nâu đậm liền; phần còn lại: lõi caramel có nét đứt kem ở giữa.
class MapTrail extends StatelessWidget {
  const MapTrail({super.key, required this.points, required this.done, required this.seed});

  /// Viền kem sáng (bề rộng cả nét) và lõi nâu: lõi 6 → viền ~6,5 px mỗi bên.
  static const casingWidth = 19.0;
  static const coreWidth = 6.0;
  static const casing = Color(0xFFFFF4E6);
  static const doneCore = Color(0xFF8E5F3E);
  static const todoCore = Color(0xFFB9805A);

  final List<Offset> points;
  final int done;
  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TrailPainter(points, done, seed), size: Size.infinite);
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter(this.points, this.done, this.seed);

  final List<Offset> points;
  final int done;
  final int seed;

  String get _key => '$seed|$done|${points.map((p) => '${p.dx.round()},${p.dy.round()}').join(';')}';

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    canvas.drawPicture(_trails.obtain(_key, () => _record(size, _paintTrail)));
  }

  void _paintTrail(Canvas c) {
    final n = points.length;
    Offset p(int i) => points[i.clamp(0, n - 1)];
    final segs = <Path>[];
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shadow = stroke(const Color(0x405A3E36), MapTrail.casingWidth + 4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final casing = stroke(MapTrail.casing, MapTrail.casingWidth);
    final doneCore = stroke(MapTrail.doneCore, MapTrail.coreWidth);
    final todoCore = stroke(MapTrail.todoCore, MapTrail.coreWidth);
    final todoDash = stroke(MapTrail.casing, 2.4);
    for (var i = 0; i < n - 1; i++) {
      final a = p(i), b = p(i + 1);
      final c1 = a + (b - p(i - 1)) / 6;
      final c2 = b - (p(i + 2) - a) / 6;
      final seg = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy);
      segs.add(wobblePath(seg, seed: SLRandom.mix(seed, i), amplitude: 1.8, step: 6));
    }
    // Từng lớp cho cả đường (lớp sau đè lớp trước ở chỗ nối, không thấy viền cắt ngang lõi).
    for (final hand in segs) {
      c.drawPath(hand.shift(const Offset(0, 2)), shadow);
    }
    for (final hand in segs) {
      c.drawPath(hand, casing);
    }
    for (final (i, hand) in segs.indexed) {
      final done = i < this.done;
      c.drawPath(hand, done ? doneCore : todoCore);
      if (!done) c.drawPath(dashPath(hand, dash: 9, gap: 9), todoDash);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old._key != _key;
}

// ---------------------------------------------------------------------------------------------------- Cờ

/// Lá cờ nhỏ cắm cạnh nút "đang tới": cán gỗ + cờ đuôi nheo hồng dâu, viền mực run.
class MapFlag extends StatelessWidget {
  const MapFlag({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: const CustomPaint(painter: _FlagPainter()));
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  static final _cache = <int, (Path, Path)>{};

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final (pole, cloth) = _cache.putIfAbsent(s.round(), () {
      final pole = wobblePath(
        Path()
          ..moveTo(s * 0.2, s * 0.98)
          ..lineTo(s * 0.2, s * 0.06),
        seed: 0xF1A6,
        amplitude: 0.6,
      );
      final cloth = wobblePath(
        Path()
          ..moveTo(s * 0.22, s * 0.08)
          ..quadraticBezierTo(s * 0.6, s * 0.02, s * 0.94, s * 0.24)
          ..lineTo(s * 0.7, s * 0.34)
          ..lineTo(s * 0.9, s * 0.48)
          ..quadraticBezierTo(s * 0.56, s * 0.52, s * 0.22, s * 0.5)
          ..close(),
        seed: 0xF1A7,
        amplitude: 0.8,
      );
      return (pole, cloth);
    });
    final ink = Paint()
      ..color = SLColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(pole, Paint()
        ..color = SLColors.woodDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round)
      ..drawPath(cloth, Paint()..color = SLColors.strawberry)
      ..drawPath(cloth, ink);
  }

  @override
  bool shouldRepaint(_FlagPainter old) => false;
}
