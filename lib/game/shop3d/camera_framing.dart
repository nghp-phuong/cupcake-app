import 'dart:math' as math;

/// Điểm trong thế giới (m).
typedef FramePoint = ({double x, double y, double z});

/// Kết quả lấy khung: điểm nhìn + khoảng cách camera.
typedef FrameResult = ({FramePoint target, double distance});

/// Lấy khung bao các điểm [points] (Mai + người đang nói). Dart thuần.
/// Điểm nhìn = trung điểm hộp bao (x, z), y = trung bình y (kẹp 0,6–1,2).
/// Khoảng cách = [baseDistance] + [perMeter] × (cạnh xa nhất giữa hai điểm trên mặt đất), kẹp [minDistance]..[maxDistance].
/// Danh sách rỗng → null.
FrameResult? frameTargets(
  List<FramePoint> points, {
  double baseDistance = 5.2,
  double perMeter = 1.1,
  double minDistance = 5.2,
  double maxDistance = 11,
}) {
  if (points.isEmpty) return null;
  var minX = points.first.x, maxX = minX, minZ = points.first.z, maxZ = minZ, sumY = 0.0;
  for (final p in points) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minZ = math.min(minZ, p.z);
    maxZ = math.max(maxZ, p.z);
    sumY += p.y;
  }
  var span = 0.0;
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      span = math.max(span, math.sqrt(math.pow(points[i].x - points[j].x, 2) + math.pow(points[i].z - points[j].z, 2)));
    }
  }
  final y = (sumY / points.length).clamp(0.6, 1.2).toDouble();
  final d = (baseDistance + perMeter * span).clamp(minDistance, maxDistance).toDouble();
  return (target: (x: (minX + maxX) / 2, y: y, z: (minZ + maxZ) / 2), distance: d);
}
