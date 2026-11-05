import 'dart:math' as math;

import 'shop3d_layout.dart';
import 'shop3d_math.dart';

/// Quy đổi độ sang rad.
double degToRad(double deg) => deg * math.pi / 180;

/// Quấn góc về [-π, π).
double wrapAngle(double a) {
  const twoPi = 2 * math.pi;
  var r = a - twoPi * ((a + math.pi) / twoPi).floorToDouble();
  if (r >= math.pi) r -= twoPi;
  return r;
}

/// Camera quỹ đạo 360° quanh [target] (giữa tiệm). Dart thuần — cảnh Thermion chỉ việc đọc [eye] / [target] mỗi khung
/// hình và gọi `lookAt`.
///
/// Toạ độ: `eye = target + distance · (sin yaw · cos pitch, sin pitch, cos yaw · cos pitch)`. yaw 0 = đứng ở +z nhìn
/// về -z (xem [Shop3dLayout]); yaw tăng = camera đi về phía +x. pitch = góc nhìn xuống so với mặt ngang (dương).
///
/// **Chống xuyên tường / sàn theo kiểu "nhà búp bê"**: camera được phép ra ngoài phòng; thay vì chặn camera, cảnh
/// ẩn hoặc làm mờ các mặt phòng nằm giữa camera và target ([hiddenWallMask], [wallOpacity]). Thêm nữa, pitch kẹp
/// trong [minPitch]..[maxPitch] (không lật ngược), và [eye] luôn có `y ≥ minEyeHeight` (nâng pitch hiệu dụng khi cần)
/// nên không bao giờ chui xuống sàn.
///
/// Dùng với cử chỉ Flutter: `onScaleStart` → [onScaleStart] + [onDragStart]; `onScaleUpdate` với `pointerCount == 1`
/// → [onDrag] (`focalPointDelta`), với 2 ngón → [onScale] (`scale`); `onScaleEnd` → [onDragEnd] + [onScaleEnd];
/// `onDoubleTap` → [onDoubleTap]; con lăn chuột web → [onMouseWheel]; mỗi khung hình → [update].
class OrbitCameraController {
  OrbitCameraController({
    Vec3? target,
    this.room = Shop3dLayout.room,
    double? defaultYaw,
    double? defaultPitch,
    double? defaultDistance,
    this.minPitch = 0.2617993877991494, // 15°
    this.maxPitch = 1.3089969389957472, // 75°
    this.minDistance = 5,
    this.maxDistance = 16,
    this.minEyeHeight = 1.5,
    this.rotateSpeed = math.pi,
    this.inertia = true,
    this.inertiaDamping = 4,
    this.resetDuration = 0.7,
    this.wheelZoomSpeed = 0.0015,
    this.wallMargin = 0.25,
  })  : assert(minPitch < maxPitch),
        assert(minDistance > 0 && minDistance < maxDistance),
        target = target ?? Shop3dLayout.cameraTarget() {
    this.defaultYaw = wrapAngle(defaultYaw ?? 0.4);
    // Mặc định (03/11, vòng cute 3): gần hơn và chúc ít hơn để đọc được mặt nhân vật chibi (thú 0,8–1,1 m), vẫn thấy
    // gần hết tiệm.
    this.defaultPitch = (defaultPitch ?? degToRad(34)).clamp(minPitch, maxPitch).toDouble();
    this.defaultDistance = (defaultDistance ?? 9).clamp(minDistance, maxDistance).toDouble();
    _yaw = this.defaultYaw;
    _pitch = this.defaultPitch;
    _distance = this.defaultDistance;
    _updateEye();
  }

  // ---- Cấu hình ------------------------------------------------------------------------------------------

  /// Điểm nhìn. Đổi giá trị rồi gọi [refresh].
  final Vec3 target;
  final RoomBox room;

  late final double defaultYaw;
  late final double defaultPitch;
  late final double defaultDistance;

  final double minPitch;
  final double maxPitch;
  final double minDistance;
  final double maxDistance;

  /// Độ cao tối thiểu của camera (m).
  final double minEyeHeight;

  /// Độ nhạy xoay: số rad xoay khi kéo hết chiều cao viewport.
  final double rotateSpeed;

  /// Quán tính khi thả ngón. Tắt = dừng ngay.
  bool inertia;

  /// Hệ số tắt dần vận tốc quán tính (1/s): v *= exp(-damping · dt).
  final double inertiaDamping;

  /// Thời gian (s) animation chạm đúp về góc mặc định.
  final double resetDuration;

  /// Độ nhạy con lăn chuột: distance *= exp(delta · speed).
  final double wheelZoomSpeed;

  /// Biên an toàn khi ẩn tường: ẩn khi camera cách mặt tường < margin về phía trong (tránh near-plane cắt tường).
  final double wallMargin;

  // ---- Trạng thái ----------------------------------------------------------------------------------------

  late double _yaw;
  late double _pitch;
  late double _distance;

  /// Vị trí camera. Cùng một đối tượng suốt vòng đời, được cập nhật tại chỗ — không cấp phát.
  final Vec3 eye = Vec3();

  double _yawVel = 0;
  double _pitchVel = 0;
  bool _dragging = false;
  double _dragYawAcc = 0;
  double _dragPitchAcc = 0;

  bool _scaling = false;
  double _scaleBase = 0;

  bool _resetting = false;
  double _resetT = 0;
  double _resetFromYaw = 0;
  double _resetDeltaYaw = 0;
  double _resetFromPitch = 0;
  double _resetFromDistance = 0;

  /// Góc quay quanh trục y, rad, luôn trong [-π, π).
  double get yaw => _yaw;

  /// Góc nhìn xuống đã kẹp trong [minPitch, maxPitch].
  double get pitch => _pitch;
  double get distance => _distance;

  /// Pitch thực dùng để đặt camera: bằng [pitch], hoặc cao hơn nếu cần để giữ `eye.y ≥ minEyeHeight`.
  double get effectivePitch {
    final needed = (minEyeHeight - target.y) / _distance;
    if (needed <= 0) return _pitch;
    final minP = math.asin(needed > 1 ? 1.0 : needed);
    return minP > _pitch ? minP : _pitch;
  }

  bool get isDragging => _dragging;

  /// Đang chạy animation về góc mặc định.
  bool get isResetting => _resetting;

  /// Còn đang chuyển động (kéo / quán tính / animation) — cảnh có thể bỏ qua việc cập nhật camera khi false.
  bool get isMoving => _resetting || _dragging || _yawVel != 0 || _pitchVel != 0;

  // ---- Cử chỉ --------------------------------------------------------------------------------------------

  void onDragStart() {
    _dragging = true;
    _resetting = false;
    _yawVel = 0;
    _pitchVel = 0;
    _dragYawAcc = 0;
    _dragPitchAcc = 0;
  }

  /// Kéo một ngón: [dx],[dy] là độ dời (pixel) kể từ lần gọi trước, [viewportHeight] là chiều cao viewport (pixel).
  /// Kéo sang phải = thế giới quay theo ngón (camera đi sang trái); kéo xuống = nhìn từ cao hơn.
  void onDrag(double dx, double dy, double viewportHeight) {
    if (!_dragging) onDragStart();
    final k = rotateSpeed / (viewportHeight < 1 ? 1 : viewportHeight);
    final dYaw = -dx * k;
    final oldPitch = _pitch;
    _yaw = wrapAngle(_yaw + dYaw);
    _pitch = _clampPitch(_pitch + dy * k);
    _dragYawAcc += dYaw;
    _dragPitchAcc += _pitch - oldPitch;
    _updateEye();
  }

  /// Thả ngón. Có [inertia] thì camera trôi tiếp theo vận tốc ước lượng (cần [update] chạy mỗi khung trong lúc kéo).
  void onDragEnd() {
    _dragging = false;
    if (!inertia) {
      _yawVel = 0;
      _pitchVel = 0;
    }
  }

  void onScaleStart() {
    _scaling = true;
    _scaleBase = _distance;
    _resetting = false;
    _yawVel = 0;
    _pitchVel = 0;
  }

  /// Chụm hai ngón: [scale] là tỉ lệ so với lúc bắt đầu (>1 = phóng to = lại gần).
  void onScale(double scale) {
    if (scale <= 0 || scale.isNaN) return;
    if (!_scaling) onScaleStart();
    _distance = _clampDistance(_scaleBase / scale);
    _updateEye();
  }

  void onScaleEnd() => _scaling = false;

  /// Con lăn chuột (web): [delta] dương = cuộn xuống = thu nhỏ.
  void onMouseWheel(double delta) {
    _resetting = false;
    _distance = _clampDistance(_distance * math.exp(delta * wheelZoomSpeed));
    _updateEye();
  }

  /// Chạm đúp: animation mượt về yaw/pitch/distance mặc định (yaw đi đường ngắn nhất).
  void onDoubleTap() {
    _dragging = false;
    _yawVel = 0;
    _pitchVel = 0;
    _resetting = true;
    _resetT = 0;
    _resetFromYaw = _yaw;
    _resetDeltaYaw = wrapAngle(defaultYaw - _yaw);
    _resetFromPitch = _pitch;
    _resetFromDistance = _distance;
  }

  /// Về góc mặc định ngay, không animation.
  void snapToDefault() {
    _resetting = false;
    _yawVel = 0;
    _pitchVel = 0;
    _yaw = defaultYaw;
    _pitch = defaultPitch;
    _distance = defaultDistance;
    _updateEye();
  }

  /// Đặt góc nhìn trực tiếp (giá trị được kẹp / quấn).
  void setView({double? yaw, double? pitch, double? distance}) {
    if (yaw != null) _yaw = wrapAngle(yaw);
    if (pitch != null) _pitch = _clampPitch(pitch);
    if (distance != null) _distance = _clampDistance(distance);
    _updateEye();
  }

  /// Tính lại [eye] sau khi đổi [target] trực tiếp.
  void refresh() => _updateEye();

  // ---- Cập nhật mỗi khung ---------------------------------------------------------------------------------

  /// Tiến animation / quán tính [dt] giây. Trả true nếu [eye] có thể đã đổi. Không cấp phát.
  bool update(double dt) {
    if (!(dt > 0)) return false;
    if (dt > 0.1) dt = 0.1;
    if (_resetting) {
      _resetT += dt / (resetDuration <= 0 ? dt : resetDuration);
      if (_resetT >= 1) {
        _resetting = false;
        _yaw = defaultYaw;
        _pitch = defaultPitch;
        _distance = defaultDistance;
      } else {
        final t = _resetT;
        final e = t * t * t * (t * (6 * t - 15) + 10); // smootherstep
        _yaw = wrapAngle(_resetFromYaw + _resetDeltaYaw * e);
        _pitch = _resetFromPitch + (defaultPitch - _resetFromPitch) * e;
        _distance = _resetFromDistance + (defaultDistance - _resetFromDistance) * e;
      }
      _updateEye();
      return true;
    }
    if (_dragging) {
      // Ước lượng vận tốc ngón: làm mượt vận tốc tức thời của khung này (đứng yên → về 0).
      final a = 1 - math.exp(-dt * 20);
      _yawVel += (_dragYawAcc / dt - _yawVel) * a;
      _pitchVel += (_dragPitchAcc / dt - _pitchVel) * a;
      _dragYawAcc = 0;
      _dragPitchAcc = 0;
      return false;
    }
    if (_yawVel != 0 || _pitchVel != 0) {
      _yaw = wrapAngle(_yaw + _yawVel * dt);
      final newPitch = _pitch + _pitchVel * dt;
      _pitch = _clampPitch(newPitch);
      if (_pitch != newPitch) _pitchVel = 0;
      final decay = math.exp(-inertiaDamping * dt);
      _yawVel *= decay;
      _pitchVel *= decay;
      if (_yawVel.abs() < 0.02) _yawVel = 0;
      if (_pitchVel.abs() < 0.02) _pitchVel = 0;
      _updateEye();
      return true;
    }
    return false;
  }

  // ---- Tường ---------------------------------------------------------------------------------------------

  /// Mặt nạ bit ([RoomWall.bit]) các mặt phòng nằm giữa camera [eye] và phòng: cảnh nên ẩn / làm mờ chúng.
  /// Không cấp phát; gọi mỗi khung được.
  int hiddenWallMask([Vec3? at]) => room.hiddenWallMask(at ?? eye, margin: wallMargin);

  /// Danh sách các mặt cần ẩn (bản tiện dụng, có cấp phát).
  List<RoomWall> wallsFacingCamera([Vec3? at]) => room.wallsFacing(at ?? eye, margin: wallMargin);

  /// Độ mờ 0..1 của mặt [wall] (0 = ẩn hẳn, 1 = hiện rõ), chuyển mượt trong [fade] mét.
  double wallOpacity(RoomWall wall, {double fade = 1, Vec3? at}) =>
      room.wallOpacity(wall, at ?? eye, margin: wallMargin, fade: fade);

  // ---- Nội bộ ---------------------------------------------------------------------------------------------

  double _clampPitch(double p) => p < minPitch ? minPitch : (p > maxPitch ? maxPitch : p);
  double _clampDistance(double d) => d < minDistance ? minDistance : (d > maxDistance ? maxDistance : d);

  void _updateEye() {
    final p = effectivePitch;
    final cp = math.cos(p);
    var y = target.y + _distance * math.sin(p);
    if (y < minEyeHeight) y = minEyeHeight;
    eye.setValues(target.x + _distance * math.sin(_yaw) * cp, y, target.z + _distance * math.cos(_yaw) * cp);
  }
}
