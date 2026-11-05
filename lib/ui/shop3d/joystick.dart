import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants.dart';
import 'shop3d_toasts.dart' show Shop3dStyle;

/// Joystick điều khiển nhân vật của cảnh tiệm 3D (đặc tả `docs/v3/interaction-spec.md` 2.1).
///
/// - [Shop3dJoystickController]: trạng thái thuần (vector, cờ chạy, ngón đang giữ) — logic cảnh đọc
///   [Shop3dJoystickController.value] / [Shop3dJoystickController.running] mỗi khung, không cần widget.
/// - [Shop3dJoystick]: lớp phủ nhận chạm bằng `Listener` (pointer thô), vẽ bằng `CustomPainter` repaint theo notifier,
///   không `setState` theo ngón.

/// Trạng thái joystick: vector đầu ra trong [−1; 1]² (trục y màn hình, đẩy lên = y âm), cờ chạy có trễ, id ngón.
///
/// Một ngón giữ joystick tới khi nhấc lên; ngón khác bị bỏ qua. Người tạo controller gọi [dispose].
class Shop3dJoystickController {
  /// Độ lớn dưới ngưỡng này → đầu ra 0.
  static const deadZone = 0.15;

  /// Độ lớn ≥ ngưỡng này → bắt đầu chạy.
  static const runEnter = 0.8;

  /// Đang chạy, độ lớn < ngưỡng này → thôi chạy.
  static const runExit = 0.75;

  final _value = ValueNotifier<Offset>(Offset.zero);
  final _running = ValueNotifier<bool>(false);
  final _active = ValueNotifier<bool>(false);
  final _knob = ValueNotifier<Offset>(Offset.zero);
  int? _pointer;
  bool _disposed = false;

  /// Vector đầu ra (0 trong vùng chết). Hướng đi = `x·right + (−y)·forward` theo camera.
  ValueListenable<Offset> get value => _value;

  /// Đang chạy (độ lớn ≥ [runEnter], thôi khi < [runExit]).
  ValueListenable<bool> get running => _running;

  /// Có ngón (hoặc [drive]) đang giữ joystick — dùng để huỷ việc tự đi khi người chơi đẩy cần.
  ValueListenable<bool> get active => _active;

  /// Vị trí núm (đơn vị hành trình, chưa qua vùng chết) — chỉ để vẽ.
  ValueListenable<Offset> get knob => _knob;

  /// Id ngón đang giữ (null = không có).
  int? get pointer => _pointer;

  /// Độ lớn của [value] (0..1).
  double get magnitude => _value.value.distance;

  bool get isDisposed => _disposed;

  /// Ngón [pointer] chạm vào: nhận nếu chưa có ngón nào (trả true), ngón thứ hai bị bỏ qua (trả false).
  /// [delta] = vị trí ngón − tâm đế (px), [travel] = hành trình (px).
  bool begin(int pointer, Offset delta, double travel) {
    if (_disposed || _pointer != null) return false;
    _pointer = pointer;
    _active.value = true;
    _apply(delta, travel);
    return true;
  }

  /// Ngón [pointer] di chuyển; bỏ qua nếu không phải ngón đang giữ.
  void move(int pointer, Offset delta, double travel) {
    if (_disposed || pointer != _pointer) return;
    _apply(delta, travel);
  }

  /// Ngón [pointer] nhấc lên hoặc bị huỷ → về 0.
  void end(int pointer) {
    if (pointer != _pointer) return;
    reset();
  }

  /// Đặt vector trực tiếp (bàn phím web) khi không có ngón giữ; [v] được kẹp vào hình tròn đơn vị.
  /// `Offset.zero` = thả.
  void drive(Offset v) {
    if (_disposed || _pointer != null) return;
    _active.value = v != Offset.zero;
    _apply(v, 1);
  }

  /// Thả hết (app vào nền, pointer bị huỷ, ẩn joystick): vector 0, thôi chạy.
  void reset() {
    _pointer = null;
    if (_disposed) return;
    _active.value = false;
    _knob.value = Offset.zero;
    _value.value = Offset.zero;
    _running.value = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pointer = null;
    _value.dispose();
    _running.dispose();
    _active.dispose();
    _knob.dispose();
  }

  void _apply(Offset delta, double travel) {
    var v = travel <= 0 ? Offset.zero : delta / travel;
    final m = v.distance;
    if (m > 1) v = v / m;
    final mag = math.min(m, 1.0);
    _knob.value = v;
    _value.value = mag < deadZone ? Offset.zero : v;
    _running.value = _running.value ? mag >= runExit : mag >= runEnter;
  }
}

/// Hình học joystick theo khung màn (đơn vị dp, gốc góc trên trái màn).
@immutable
class Shop3dJoystickGeometry {
  const Shop3dJoystickGeometry({required this.center, required this.scale, this.minX = 0});

  /// Tâm đế (150, H−150)·s, cộng phần lấn của mép trái/dưới (lấy lớn hơn giữa padding an toàn và
  /// `systemGestureInsets`), mép đế cách cạnh trái ≥ 80 dp.
  factory Shop3dJoystickGeometry.of(Size size, {EdgeInsets padding = EdgeInsets.zero, EdgeInsets gestureInsets = EdgeInsets.zero}) {
    final s = Shop3dStyle.scaleOf(size);
    final left = math.max(padding.left, gestureInsets.left);
    final bottom = math.max(padding.bottom, gestureInsets.bottom);
    final cx = math.max(150 * s + left, minEdge + baseRadiusRef * s);
    final cy = size.height - 150 * s - bottom;
    return Shop3dJoystickGeometry(center: Offset(cx, cy), scale: s, minX: gestureInsets.left);
  }

  /// Khoảng cách tối thiểu từ mép đế tới cạnh trái (dp).
  static const minEdge = 80.0;
  static const baseRadiusRef = 68.0;
  static const knobRadiusRef = 28.0;
  static const travelRef = 52.0;
  static const hitRadiusRef = 120.0;

  final Offset center;

  /// Hệ số s.
  final double scale;

  /// Chạm có x nhỏ hơn giá trị này không bắt vào joystick (vuốt mép hệ thống, `immersiveSticky`).
  final double minX;

  double get baseRadius => baseRadiusRef * scale;
  double get knobRadius => knobRadiusRef * scale;
  double get travel => travelRef * scale;

  /// Bán kính vùng nhận chạm.
  double get hitRadius => hitRadiusRef * scale;

  /// Điểm màn [p] có nằm trong vùng nhận chạm không (để lớp camera loại ngón joystick khỏi phép chụm nếu cần).
  bool contains(Offset p) => p.dx >= minX && (p - center).distance <= hitRadius;

  @override
  bool operator ==(Object other) =>
      other is Shop3dJoystickGeometry && other.center == center && other.scale == scale && other.minX == minX;

  @override
  int get hashCode => Object.hash(center, scale, minX);
}

/// Lớp phủ joystick ở góc dưới trái. Tự trả về `Positioned.fill` — đặt làm con của `Stack` phủ cảnh, phía trên
/// lớp nhận cử chỉ camera. Chỉ vùng tròn bán kính 120·s nhận chạm; ngoài vùng đó chạm đi xuống cảnh (xoay camera).
///
/// [visible] = false: mờ dần trong 150 ms, không nhận chạm, controller được thả về 0. App vào nền → về 0.
class Shop3dJoystick extends StatefulWidget {
  const Shop3dJoystick({super.key, required this.controller, this.visible = true});

  final Shop3dJoystickController controller;
  final bool visible;

  @override
  State<Shop3dJoystick> createState() => _Shop3dJoystickState();
}

class _Shop3dJoystickState extends State<Shop3dJoystick> {
  late final AppLifecycleListener _life;
  Shop3dJoystickGeometry? _geom;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: (s) {
      if (s != AppLifecycleState.resumed) _resetSoon(widget.controller);
    });
  }

  @override
  void didUpdateWidget(Shop3dJoystick old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _resetSoon(old.controller);
    } else if (old.visible && !widget.visible) {
      _resetSoon(widget.controller);
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _resetSoon(widget.controller);
    super.dispose();
  }

  /// Thả controller sau khung hiện tại (không báo notifier giữa lúc dựng/gỡ cây).
  void _resetSoon(Shop3dJoystickController c) {
    if (c.isDisposed || (c.pointer == null && !c.active.value)) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      c.reset();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!c.isDisposed) c.reset();
    });
  }

  bool _accepts(PointerEvent e) => e.kind != PointerDeviceKind.mouse || e.buttons == kPrimaryButton;

  Offset _delta(PointerEvent e) {
    final g = _geom!;
    final r = g.hitRadius;
    return e.localPosition - Offset(r, r);
  }

  void _onDown(PointerDownEvent e) {
    if (!widget.visible || _geom == null || !_accepts(e)) return;
    widget.controller.begin(e.pointer, _delta(e), _geom!.travel);
  }

  void _onMove(PointerMoveEvent e) {
    if (_geom == null) return;
    widget.controller.move(e.pointer, _delta(e), _geom!.travel);
  }

  void _onUp(PointerUpEvent e) => widget.controller.end(e.pointer);

  void _onCancel(PointerCancelEvent e) => widget.controller.end(e.pointer);

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final gesture = MediaQuery.systemGestureInsetsOf(context);
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.hasBoundedHeight && constraints.hasBoundedWidth
            ? constraints.biggest
            : MediaQuery.sizeOf(context);
        final g = _geom = Shop3dJoystickGeometry.of(size, padding: padding, gestureInsets: gesture);
        final r = g.hitRadius;
        return Stack(
          children: [
            Positioned(
              left: g.center.dx - r,
              top: g.center.dy - r,
              width: 2 * r,
              height: 2 * r,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: AnimatedOpacity(
                  opacity: widget.visible ? 1 : 0,
                  duration: Shop3dStyle.fade,
                  child: RepaintBoundary(
                    child: Listener(
                      behavior: HitTestBehavior.deferToChild,
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerCancel: _onCancel,
                      child: CustomPaint(
                        size: Size.square(2 * r),
                        painter: _JoystickPainter(
                          controller: widget.controller,
                          geometry: g,
                          // Toạ độ trong ô vẽ của mép chặn vuốt hệ thống.
                          minLocalX: g.minX - (g.center.dx - r),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.controller, required this.geometry, required this.minLocalX})
      : super(repaint: Listenable.merge([controller.knob, controller.running, controller.active]));

  final Shop3dJoystickController controller;
  final Shop3dJoystickGeometry geometry;
  final double minLocalX;

  static final _baseFill = Paint()..color = AppColors.cream.withValues(alpha: 0.7);
  static final _border = Paint()
    ..color = AppColors.caramel
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _ring = Paint()
    ..color = AppColors.caramel.withValues(alpha: 0.28)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _shadow = Paint()..color = const Color(0x265A3E36);
  static final _knobIdle = Paint()..color = AppColors.butter;
  static final _knobRun = Paint()..color = AppColors.strawberry;

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.isDisposed) return;
    final c = size.center(Offset.zero);
    final g = geometry;
    canvas.drawCircle(c, g.baseRadius, _baseFill);
    canvas.drawCircle(c, g.baseRadius, _border);
    canvas.drawCircle(c, g.travel * Shop3dJoystickController.runEnter, _ring);
    final k = c + controller.knob.value * g.travel;
    canvas.drawCircle(k + Offset(0, 3 * g.scale), g.knobRadius, _shadow);
    canvas.drawCircle(k, g.knobRadius, controller.running.value ? _knobRun : _knobIdle);
    canvas.drawCircle(k, g.knobRadius, _border);
  }

  @override
  bool? hitTest(Offset position) {
    if (position.dx < minLocalX) return false;
    final r = geometry.hitRadius;
    return (position - Offset(r, r)).distance <= r;
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.controller != controller || old.geometry != geometry || old.minLocalX != minLocalX;
}
