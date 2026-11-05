import 'dart:math' as math;

import '../shop3d/orbit_camera.dart';
import '../shop3d/shop3d_math.dart';

/// Góc nhìn cận (bảng làm tóc: camera lia sát Mai) — điểm nhìn + yaw / pitch / khoảng cách, KHÔNG bị kẹp theo giới hạn
/// của camera phố.
class TownCloseUp {
  const TownCloseUp({
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
    required this.distance,
  });

  final double x, y, z, yaw, pitch, distance;
}

/// Camera ngoài phố (thành phố V3) — Dart thuần, dùng lại [OrbitCameraController] (kéo xoay, chụm / con lăn phóng, quán
/// tính, chạm đúp về góc mặc định) với giới hạn của phố:
/// - hướng chuẩn [defaultYaw] = 0: camera ở phía nam (+z) nhìn về phía bắc (-z) — mặt tiền hàng lô bắc (tiệm của bà,
///   quán ăn, tiệm tóc) quay về camera, hàng lô nam (thấp: hàng rào, công viên) không che Mai;
/// - xoay giới hạn ±[yawLimit] (60°) quanh hướng chuẩn, pitch [minPitch]..[maxPitch] (40–50°), cách [minDistance]..
///   [maxDistance] (10–12 m); không ẩn tường;
/// - điểm nhìn bám Mai mượt ([followRate]/s) ở độ cao ngang ngực;
/// - góc nhìn cận [closeUp] (lia mượt vào / ra, [closeRate]/s) — lúc đó bỏ qua cử chỉ.
///
/// Mỗi khung: [update] (đưa điểm Mai) → đọc [eye] / [target] (toạ độ lớp phố) → `camera.lookAt`.
class TownCamera {
  TownCamera()
      : orbit = OrbitCameraController(
          target: Vec3(0, targetHeight, 0),
          defaultYaw: 0,
          defaultPitch: defaultPitch,
          defaultDistance: defaultDistance,
          minPitch: minPitch,
          maxPitch: maxPitch,
          minDistance: minDistance,
          maxDistance: maxDistance,
        ) {
    _compose();
  }

  static const double defaultYaw = 0;
  static final double defaultPitch = degToRad(45);
  static const double defaultDistance = 11;
  static final double minPitch = degToRad(40), maxPitch = degToRad(50);
  static const double minDistance = 10, maxDistance = 12;
  static final double yawLimit = degToRad(60);

  /// Độ cao điểm nhìn trên chân Mai (≈ đỉnh đầu × 0,62 như camera bám nhân vật trong tiệm).
  static const double targetHeight = 0.8;

  static const double followRate = 6;
  static const double closeRate = 3.2;

  final OrbitCameraController orbit;

  /// Điểm nhìn / vị trí camera đã ghép góc cận (toạ độ lớp phố). Cùng đối tượng suốt vòng đời.
  final Vec3 target = Vec3();
  final Vec3 eye = Vec3();

  TownCloseUp? _close;
  TownCloseUp? _lastClose;
  double _w = 0;
  double _yaw = 0;

  /// Yaw đang dùng (đã ghép góc cận) — hướng đi của joystick theo camera.
  double get yaw => _yaw;

  /// Đang ở (hoặc đang lia vào / ra) góc cận.
  bool get inCloseUp => _close != null || _w > 0;

  bool get isDragging => orbit.isDragging;

  /// Lia vào góc cận [c] (null = lia về camera phố).
  set closeUp(TownCloseUp? c) {
    _close = c;
    if (c != null) _lastClose = c;
  }

  TownCloseUp? get closeUp => _close;

  // ---- Cử chỉ (bỏ qua khi đang ở góc cận) ----------------------------------------------------------------

  void onDragStart() {
    if (!inCloseUp) orbit.onDragStart();
  }

  void onDrag(double dx, double dy, double viewportHeight) {
    if (inCloseUp) return;
    orbit.onDrag(dx, dy, viewportHeight);
    _clampYaw();
    _compose();
  }

  void onDragEnd() => orbit.onDragEnd();

  void onScaleStart() {
    if (!inCloseUp) orbit.onScaleStart();
  }

  void onScale(double scale) {
    if (inCloseUp) return;
    orbit.onScale(scale);
    _compose();
  }

  void onScaleEnd() => orbit.onScaleEnd();

  void onMouseWheel(double delta) {
    if (inCloseUp) return;
    orbit.onMouseWheel(delta);
    _compose();
  }

  /// Về góc mặc định (mượt).
  void onDoubleTap() {
    if (!inCloseUp) orbit.onDoubleTap();
  }

  // ---- Mỗi khung ----------------------------------------------------------------------------------------

  /// Tiến [dt] giây, điểm nhìn bám (fx, fz) (chân Mai). Trả true nếu [eye] / [target] đổi.
  bool update(double dt, double fx, double fz) {
    if (!(dt > 0)) return false;
    var changed = orbit.update(dt);
    if (_clampYaw()) changed = true;
    final t = orbit.target;
    final k = 1 - math.exp(-followRate * math.min(dt, 0.1));
    final nx = t.x + (fx - t.x) * k, nz = t.z + (fz - t.z) * k;
    if ((nx - t.x).abs() + (nz - t.z).abs() > 1e-5) {
      t.setValues(nx, targetHeight, nz);
      orbit.refresh();
      changed = true;
    }
    final goal = _close == null ? 0.0 : 1.0;
    if (_w != goal) {
      _w += (goal - _w) * (1 - math.exp(-closeRate * math.min(dt, 0.1)));
      if ((goal - _w).abs() < 2e-3) _w = goal;
      changed = true;
    }
    if (changed) _compose();
    return changed;
  }

  /// Đặt điểm nhìn ngay tại (fx, fz) và về góc mặc định, không lia (vừa ra phố / xuất hiện).
  void snapTo(double fx, double fz) {
    orbit.target.setValues(fx, targetHeight, fz);
    orbit.snapToDefault();
    _close = null;
    _w = 0;
    _compose();
  }

  bool _clampYaw() {
    final y = orbit.yaw - defaultYaw;
    if (y.abs() <= yawLimit) return false;
    orbit.setView(yaw: defaultYaw + y.sign * yawLimit);
    return true;
  }

  void _compose() {
    final c = _lastClose;
    final w = c == null ? 0.0 : _w;
    final o = orbit.target;
    final p0 = orbit.effectivePitch;
    var tx = o.x, ty = o.y, tz = o.z, yaw = orbit.yaw, pitch = p0, dist = orbit.distance;
    if (c != null && w > 0) {
      tx += (c.x - tx) * w;
      ty += (c.y - ty) * w;
      tz += (c.z - tz) * w;
      yaw += wrapAngle(c.yaw - yaw) * w;
      pitch += (c.pitch - pitch) * w;
      dist += (c.distance - dist) * w;
    }
    _yaw = wrapAngle(yaw);
    target.setValues(tx, ty, tz);
    final cp = math.cos(pitch);
    eye.setValues(tx + dist * math.sin(_yaw) * cp, ty + dist * math.sin(pitch), tz + dist * math.cos(_yaw) * cp);
  }
}
