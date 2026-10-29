import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'sl_random.dart';

/// Làm "run tay" một Path lý tưởng: lấy mẫu dọc đường (PathMetrics) mỗi [step] px, đẩy từng điểm theo pháp tuyến
/// một lượng nhiễu mượt (tổng 3 sóng sin, pha/tần số theo [seed]) rồi nối lại bằng đường cong bậc hai qua trung
/// điểm. Đường khép kín dùng số chu kỳ nguyên → nhiễu tuần hoàn, không lộ mối nối. Đường ngắn (lỗ đục, chấm) run
/// ít hơn để không méo. Tất định: cùng (path, seed, amplitude, step) → cùng kết quả.
Path wobblePath(Path ideal, {required int seed, required double amplitude, double step = 3}) {
  final out = Path()..fillType = ideal.fillType;
  var index = 0;
  for (final metric in ideal.computeMetrics()) {
    final rnd = SLRandom(SLRandom.mix(seed, index++));
    final len = metric.length;
    if (len < 0.5) continue;
    final closed = metric.isClosed;
    final amp = amplitude * (len / 80).clamp(0.25, 1.0);
    final n = math.max(closed ? 8 : 2, (len / step).ceil());
    final f1 = math.max(1, (len / 260).round()) + rnd.nextInt(2);
    final f2 = math.max(2, (len / 70).round()) + rnd.nextInt(3);
    final f3 = math.max(3, (len / 24).round()) + rnd.nextInt(4);
    final p1 = rnd.range(0, 2 * math.pi), p2 = rnd.range(0, 2 * math.pi), p3 = rnd.range(0, 2 * math.pi);
    double noise(double s) {
      final t = s / len * 2 * math.pi;
      return amp * (0.55 * math.sin(f1 * t + p1) + 0.3 * math.sin(f2 * t + p2) + 0.15 * math.sin(f3 * t + p3));
    }

    final pts = <Offset>[];
    final count = closed ? n : n + 1;
    for (var i = 0; i < count; i++) {
      final s = len * i / n;
      final tan = metric.getTangentForOffset(math.min(s, len));
      if (tan == null) continue;
      final normal = Offset(-tan.vector.dy, tan.vector.dx);
      pts.add(tan.position + normal * noise(s));
    }
    if (pts.length < 2) continue;
    _smoothThrough(out, pts, closed);
  }
  return out;
}

/// Nối các điểm bằng đường bậc hai qua trung điểm (bo nhẹ góc, giống nét bút).
void _smoothThrough(Path path, List<Offset> pts, bool closed) {
  Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  if (closed) {
    final n = pts.length;
    final start = mid(pts[n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final p = pts[i], m = mid(p, pts[(i + 1) % n]);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    path.close();
  } else {
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final p = pts[i], m = mid(p, pts[i + 1]);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
  }
}

/// Cắt các đoạn [from, to] (tính theo phần đường, 0..1) của mọi contour — dùng cho nét đậm cục bộ, nét chỉ khâu.
Path extractFraction(Path path, double from, double to) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    final a = m.length * from.clamp(0, 1), b = m.length * to.clamp(0, 1);
    if (b > a) out.addPath(m.extractPath(a, b), Offset.zero);
  }
  return out;
}

/// Nét đứt (khâu chỉ, đường đục lỗ) theo [dash]/[gap] px.
Path dashPath(Path path, {double dash = 6, double gap = 4}) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------- Hình

/// Hướng đuôi bong bóng thoại.
enum SLTail { none, bottom, top, left, right }

/// Hình dạng lý tưởng (chưa run) đặt trong một Rect. Là giá trị (có ==) để làm khoá cache.
@immutable
sealed class SLShape {
  const SLShape();

  /// Đường viền lý tưởng trong [r].
  Path ideal(Rect r);

  /// Gốc các nét "lố" kiểu bút chì: (điểm trên đường viền lý tưởng, hướng đơn vị kéo ra). Nét lố được vẽ từ điểm
  /// gần nhất trên đường viền ĐÃ RUN nên luôn dính liền nét viền (xem [overshootStrokes]); rỗng = không có.
  List<(Offset, Offset)> overshootAnchors(Rect r, SLRandom rnd) => const [];
}

/// Độ dài tối đa (px) của một nét lố tính từ tâm nét viền.
const kSLOvershootMax = 3.6;

/// Nét lố: từ điểm gần [anchor] nhất trên contour đầu của [outline] (đường viền đã run), kéo thẳng theo hướng
/// của anchor 2,2–[kSLOvershootMax] px. Hướng lệch khỏi tiếp tuyến của viền ~25–35° nên nét tách ra như vẩy bút,
/// nhưng gốc nằm giữa nét viền → không bao giờ thành vạch rời.
Path overshootStrokes(Path outline, List<(Offset, Offset)> anchors, SLRandom rnd) {
  final out = Path();
  if (anchors.isEmpty) return out;
  final it = outline.computeMetrics().iterator;
  if (!it.moveNext()) return out;
  final m = it.current;
  final len = m.length;
  if (len < 1) return out;
  for (final (p, dir) in anchors) {
    double dist(double s) => (m.getTangentForOffset(s.clamp(0, len))!.position - p).distanceSquared;
    var best = 0.0, bestD = double.infinity;
    for (var s = 0.0; s < len; s += 3) {
      final d = dist(s);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    for (var s = best - 3; s <= best + 3; s += 0.5) {
      final d = dist(s);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    final q = m.getTangentForOffset(best.clamp(0, len))!.position;
    final l = rnd.range(2.2, kSLOvershootMax);
    out
      ..moveTo(q.dx - dir.dx * 0.6, q.dy - dir.dy * 0.6)
      ..lineTo(q.dx + dir.dx * l, q.dy + dir.dy * l);
  }
  return out;
}

/// Chữ nhật bo góc; [topOnly] = chỉ bo hai góc trên (tab, thẻ đánh dấu trang).
class SLRoundRect extends SLShape {
  const SLRoundRect(this.radius, {this.topOnly = false});

  final double radius;
  final bool topOnly;

  double _r(Rect r) => math.min(radius, r.shortestSide / 2);

  @override
  Path ideal(Rect r) {
    final rad = Radius.circular(_r(r));
    final small = Radius.circular(math.min(4, _r(r)));
    return Path()
      ..addRRect(topOnly
          ? RRect.fromRectAndCorners(r, topLeft: rad, topRight: rad, bottomLeft: small, bottomRight: small)
          : RRect.fromRectAndRadius(r, rad));
  }

  @override
  List<(Offset, Offset)> overshootAnchors(Rect r, SLRandom rnd) {
    final rad = _r(r);
    if (rad > r.shortestSide * 0.36) return const []; // viên thuốc / tròn: không có góc để lố.
    final first = rnd.nextInt(4);
    final corners = [first, if (r.shortestSide >= 60) (first + 1 + rnd.nextInt(3)) % 4];
    final out = <(Offset, Offset)>[];
    for (final c in corners) {
      final horizontal = rnd.nextDouble() < 0.5;
      final theta = rnd.range(0.44, 0.6); // 25–35°: góc tách khỏi nét viền.
      if (topOnly && c >= 2) continue;
      // Góc K, hướng "về phía góc" dọc cạnh ngang (dh) và cạnh dọc (dv); tâm cung C = K − rad·(dh + dv).
      final (Offset k, Offset dh, Offset dv) = switch (c) {
        0 => (r.topLeft, const Offset(-1, 0), const Offset(0, -1)),
        1 => (r.topRight, const Offset(1, 0), const Offset(0, -1)),
        2 => (r.bottomRight, const Offset(1, 0), const Offset(0, 1)),
        _ => (r.bottomLeft, const Offset(-1, 0), const Offset(0, 1)),
      };
      final center = k - (dh + dv) * rad;
      final (Offset along, Offset across) = horizontal ? (dh, dv) : (dv, dh);
      // Điểm trên cung, cách tiếp điểm của cạnh một góc theta; nét lố đi thẳng tiếp theo hướng cạnh (không uốn theo cung).
      final p = center + (across * math.cos(theta) + along * math.sin(theta)) * rad;
      out.add((p, along));
    }
    return out;
  }

  @override
  bool operator ==(Object other) => other is SLRoundRect && other.radius == radius && other.topOnly == topOnly;

  @override
  int get hashCode => Object.hash(SLRoundRect, radius, topOnly);
}

/// Hình tròn / bầu dục; nét lố = nét vẩy ngắn ở chỗ vòng tròn khép lại (vòng tròn vẽ tay không khép khít).
class SLCircle extends SLShape {
  const SLCircle();

  @override
  Path ideal(Rect r) => Path()..addOval(r);

  @override
  List<(Offset, Offset)> overshootAnchors(Rect r, SLRandom rnd) {
    final a = rnd.range(-math.pi, math.pi);
    final rx = r.width / 2, ry = r.height / 2;
    final p = r.center + Offset(rx * math.cos(a), ry * math.sin(a));
    // Tiếp tuyến (chiều ngẫu nhiên) nghiêng ra ngoài ~30°: nét tròn vẽ tay khép lại rồi vẩy ra một chút.
    final sign = rnd.sign();
    final tangent = Offset(-rx * math.sin(a), ry * math.cos(a)) * sign;
    final t = tangent / math.max(1e-6, tangent.distance);
    final n = Offset(math.cos(a), math.sin(a));
    final d = t * math.cos(0.52) + n * math.sin(0.52);
    return [(p, d / d.distance)];
  }

  @override
  bool operator ==(Object other) => other is SLCircle;

  @override
  int get hashCode => (SLCircle).hashCode;
}

/// Dải vải có hai đuôi cắt chữ V ([notch] = độ sâu vết cắt theo chiều cao).
class SLRibbon extends SLShape {
  const SLRibbon({this.notch = 0.32});

  final double notch;

  @override
  Path ideal(Rect r) {
    final n = r.height * notch;
    return Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right - n, r.center.dy)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left + n, r.center.dy)
      ..close();
  }

  @override
  bool operator ==(Object other) => other is SLRibbon && other.notch == notch;

  @override
  int get hashCode => Object.hash(SLRibbon, notch);
}

/// Vé giấy: cuống trên cao [stub] có hai khuyết bán nguyệt hai bên + hàng lỗ đục, mép dưới răng cưa. Răng cưa
/// và lỗ đục xé/đục bằng tay: độ sâu từng răng lệch ±1,5px, đỉnh răng lệch ngang chút ít, lỗ to nhỏ/lệch vị trí
/// theo [seed] (tất định).
class SLTicket extends SLShape {
  const SLTicket({this.stub = 44, this.tooth = 12, this.notchRadius = 7, this.holes = true, this.seed = 0});

  final double stub;
  final double tooth;
  final double notchRadius;
  final bool holes;

  /// Seed của nét xé răng cưa / lỗ đục.
  final int seed;

  /// Toạ độ y (tương đối mép trên) của đường đục lỗ.
  double stubLine(Rect r) => math.min(stub, r.height * 0.45);

  @override
  Path ideal(Rect r) {
    final rnd = SLRandom(SLRandom.mix(seed, 0x71C));
    final y = r.top + stubLine(r), nr = notchRadius, t = math.min(tooth, r.height * 0.15);
    final path = Path()..fillType = PathFillType.evenOdd;
    path
      ..moveTo(r.left + 6, r.top)
      ..lineTo(r.right - 6, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + 6)
      ..lineTo(r.right, y - nr)
      ..arcToPoint(Offset(r.right, y + nr), radius: Radius.circular(nr), clockwise: false)
      ..lineTo(r.right, r.bottom - t);
    final teeth = math.max(3, (r.width / (t * 1.6)).round());
    final w = r.width / teeth;
    final jitter = math.min(1.5, t * 0.2);
    for (var i = 0; i < teeth; i++) {
      final x = r.right - w * i;
      final tip = x - w / 2 + rnd.range(-w * 0.08, w * 0.08);
      final valley = i == teeth - 1 ? r.bottom - t : r.bottom - t + rnd.range(-jitter, jitter);
      path
        ..lineTo(tip, r.bottom - rnd.range(0, jitter))
        ..lineTo(x - w, valley);
    }
    path
      ..lineTo(r.left, y + nr)
      ..arcToPoint(Offset(r.left, y - nr), radius: Radius.circular(nr), clockwise: false)
      ..lineTo(r.left, r.top + 6)
      ..quadraticBezierTo(r.left, r.top, r.left + 6, r.top)
      ..close();
    if (holes) {
      final span = r.width - 2 * (nr + 10);
      final count = math.max(2, (span / 14).floor());
      for (var i = 0; i <= count; i++) {
        final x = r.left + nr + 10 + span * i / count + (i == 0 || i == count ? 0 : rnd.range(-1.5, 1.5));
        final hole = Rect.fromCenter(
          center: Offset(x, y + rnd.range(-0.8, 0.8)),
          width: 2 * rnd.range(2.1, 3.1),
          height: 2 * rnd.range(2.1, 3.0),
        );
        path.addOval(hole);
      }
    }
    return path;
  }

  @override
  bool operator ==(Object other) =>
      other is SLTicket &&
      other.stub == stub &&
      other.tooth == tooth &&
      other.notchRadius == notchRadius &&
      other.holes == holes &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(SLTicket, stub, tooth, notchRadius, holes, seed);
}

/// Bong bóng thoại: thân bo góc + đuôi cong ở cạnh [tail], vị trí [tailAt] (0..1 dọc cạnh), dài [tailSize].
/// Thân chừa chỗ cho đuôi bên trong Rect (widget đã cộng padding tương ứng).
class SLBubble extends SLShape {
  const SLBubble({this.tail = SLTail.bottom, this.tailAt = 0.25, this.tailSize = 18, this.radius = 20});

  final SLTail tail;
  final double tailAt;
  final double tailSize;
  final double radius;

  Rect body(Rect r) => switch (tail) {
        SLTail.none => r,
        SLTail.bottom => Rect.fromLTRB(r.left, r.top, r.right, r.bottom - tailSize),
        SLTail.top => Rect.fromLTRB(r.left, r.top + tailSize, r.right, r.bottom),
        SLTail.left => Rect.fromLTRB(r.left + tailSize, r.top, r.right, r.bottom),
        SLTail.right => Rect.fromLTRB(r.left, r.top, r.right - tailSize, r.bottom),
      };

  @override
  Path ideal(Rect r) {
    final b = body(r);
    final rad = math.min(radius, b.shortestSide / 2);
    final bodyPath = Path()..addRRect(RRect.fromRectAndRadius(b, Radius.circular(rad)));
    if (tail == SLTail.none || tailSize <= 0) return bodyPath;
    final half = tailSize * 0.8;
    final horizontal = tail == SLTail.bottom || tail == SLTail.top;
    final along = horizontal
        ? (b.left + rad + half + (b.width - 2 * (rad + half)).clamp(0, double.infinity) * tailAt.clamp(0, 1))
        : (b.top + rad + half + (b.height - 2 * (rad + half)).clamp(0, double.infinity) * tailAt.clamp(0, 1));
    // Đỉnh đuôi lệch về phía gần góc hơn → đuôi cong như nét vẽ.
    final lean = (tailAt < 0.5 ? -1 : 1) * tailSize * 0.7;
    // Đáy đuôi (a, b) nằm hơi trong thân, đỉnh [tip] ở mép ngoài; hai cạnh hơi phồng ra ngoài như nét vẽ.
    final (Offset a, Offset c, Offset tip) = switch (tail) {
      SLTail.bottom => (Offset(along - half, b.bottom - 2), Offset(along + half, b.bottom - 2), Offset(along + lean, r.bottom)),
      SLTail.top => (Offset(along - half, b.top + 2), Offset(along + half, b.top + 2), Offset(along + lean, r.top)),
      SLTail.left => (Offset(b.left + 2, along - half), Offset(b.left + 2, along + half), Offset(r.left, along + lean)),
      _ => (Offset(b.right - 2, along - half), Offset(b.right - 2, along + half), Offset(r.right, along + lean)),
    };
    final dir = (a - c) / (a - c).distance * (tailSize * 0.18);
    final c1 = Offset.lerp(a, tip, 0.5)! + dir, c2 = Offset.lerp(c, tip, 0.5)! - dir;
    final p = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, c.dx, c.dy)
      ..close();
    return Path.combine(PathOperation.union, bodyPath, p);
  }

  @override
  bool operator ==(Object other) =>
      other is SLBubble && other.tail == tail && other.tailAt == tailAt && other.tailSize == tailSize && other.radius == radius;

  @override
  int get hashCode => Object.hash(SLBubble, tail, tailAt, tailSize, radius);
}

/// Mẩu băng dính: chữ nhật, hai đầu xé răng cưa.
class SLTapeShape extends SLShape {
  const SLTapeShape();

  @override
  Path ideal(Rect r) {
    const teeth = 4;
    final h = r.height / teeth, d = math.min(3.0, r.width * 0.08);
    final p = Path()..moveTo(r.left, r.top)..lineTo(r.right, r.top);
    for (var i = 0; i < teeth; i++) {
      p
        ..lineTo(r.right - d, r.top + h * (i + 0.5))
        ..lineTo(r.right, r.top + h * (i + 1));
    }
    p.lineTo(r.left, r.bottom);
    for (var i = teeth; i > 0; i--) {
      p
        ..lineTo(r.left + d, r.top + h * (i - 0.5))
        ..lineTo(r.left, r.top + h * (i - 1));
    }
    return p..close();
  }

  @override
  bool operator ==(Object other) => other is SLTapeShape;

  @override
  int get hashCode => (SLTapeShape).hashCode;
}
