import 'dart:math' as math;
import 'dart:ui';

/// Đường gợi ý phủ kem: xoắn ốc [turns] vòng trong elip [r] (từ mép ngoài vào tâm), lấy mẫu
/// đúng [samples] điểm cách đều theo chiều dài cung.
List<Offset> spiralGuide(Rect r, {int samples = 120, double turns = 2.5}) {
  if (samples <= 0) return const [];
  if (samples == 1) return [r.center];
  const fine = 2400;
  const outer = 0.86;
  const inner = 0.1;
  Offset at(double t) {
    final a = t * turns * 2 * math.pi - math.pi / 2;
    final k = outer - (outer - inner) * t;
    return Offset(r.center.dx + math.cos(a) * k * r.width / 2, r.center.dy + math.sin(a) * k * r.height / 2);
  }

  // Đường mịn → bảng chiều dài cung tích luỹ → lấy mẫu cách đều.
  final pts = [for (var i = 0; i <= fine; i++) at(i / fine)];
  final acc = List<double>.filled(pts.length, 0);
  for (var i = 1; i < pts.length; i++) {
    acc[i] = acc[i - 1] + (pts[i] - pts[i - 1]).distance;
  }
  final total = acc.last;
  final out = <Offset>[];
  var j = 1;
  for (var k = 0; k < samples; k++) {
    final target = total * k / (samples - 1);
    while (j < pts.length - 1 && acc[j] < target) {
      j++;
    }
    final seg = acc[j] - acc[j - 1];
    final f = seg <= 0 ? 0.0 : ((target - acc[j - 1]) / seg).clamp(0.0, 1.0);
    out.add(Offset.lerp(pts[j - 1], pts[j], f)!);
  }
  return out;
}

/// Tỉ lệ 0..1 điểm của [guide] có ít nhất một điểm nét [stroke] cách nó ≤ [r].
double frostCoverage(List<Offset> guide, List<Offset> stroke, double r) {
  if (guide.isEmpty || stroke.isEmpty) return 0;
  final r2 = r * r;
  var covered = 0;
  for (final g in guide) {
    for (final s in stroke) {
      if ((g - s).distanceSquared <= r2) {
        covered++;
        break;
      }
    }
  }
  return covered / guide.length;
}

/// Theo dõi phủ kem tăng dần khi người chơi vẽ: chèn điểm nội suy (không bỏ sót khi kéo nhanh)
/// và đánh dấu điểm gợi ý đã phủ.
///
/// Nét kem được cộng dồn vào một [path] duy nhất ngay lúc nhận điểm (mỗi điểm thêm đúng một lần),
/// nên khung hình chỉ cần vẽ [path] — chi phí phía Dart mỗi khung không tăng theo độ dài nét.
class FrostTracker {
  FrostTracker({required this.guide, required this.radius}) : covered = List<bool>.filled(guide.length, false);

  final List<Offset> guide;
  final double radius;
  final List<bool> covered;

  /// Mọi nét kem (mỗi lần nhấn–nhấc là một đoạn con bắt đầu bằng moveTo), đã nội suy.
  /// Nét chỉ có một điểm (chạm rồi nhấc) là một đoạn rất ngắn để bút đầu tròn vẽ thành chấm.
  final Path path = Path();

  int _strokeCount = 0;
  int _pointCount = 0;
  Offset? _last;
  int _coveredCount = 0;

  double get coverage => guide.isEmpty ? 0 : _coveredCount / guide.length;
  bool get hasStroke => _strokeCount > 0;

  /// Số nét đã vẽ.
  int get strokeCount => _strokeCount;

  /// Tổng số điểm (kể cả điểm nội suy) đã thêm vào [path].
  int get pointCount => _pointCount;

  /// Chỉ số điểm gợi ý đầu tiên chưa phủ (để nhấp nháy dẫn đường), -1 nếu đã phủ hết.
  int get nextIndex => covered.indexOf(false);

  void begin(Offset p) {
    _strokeCount++;
    _pointCount++;
    _last = p;
    path
      ..moveTo(p.dx, p.dy)
      ..lineTo(p.dx + 0.01, p.dy);
    _mark(p);
  }

  void extend(Offset p) {
    final last = _last;
    if (last == null) return begin(p);
    final d = (p - last).distance;
    final step = math.max(2.0, radius * 0.4);
    if (d < step * 0.5) return;
    final n = (d / step).ceil();
    for (var i = 1; i <= n; i++) {
      final q = Offset.lerp(last, p, i / n)!;
      path.lineTo(q.dx, q.dy);
      _pointCount++;
      _mark(q);
    }
    _last = p;
  }

  void _mark(Offset p) {
    final r2 = radius * radius;
    for (var i = 0; i < guide.length; i++) {
      if (!covered[i] && (guide[i] - p).distanceSquared <= r2) {
        covered[i] = true;
        _coveredCount++;
      }
    }
  }
}
