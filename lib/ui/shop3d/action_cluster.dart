import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../sugarleaf/sugarleaf.dart';
import 'shop3d_toasts.dart' show Shop3dStyle;

/// Cụm nút thao tác góc dưới phải khi điều khiển nhân vật (đặc tả `docs/v3/interaction-spec.md` 2.2):
/// A (chính, theo ngữ cảnh) Ø96, B "Ném" Ø68 (chạm nhanh / nhấn giữ nạp lực), C "Vẫy chào" Ø60 (hồi chiêu),
/// "Xong" 96×40. Widget thuần: nhãn, icon, callback do người nối truyền vào.

/// Vị trí tâm các nút theo khung màn: toạ độ tham chiếu (tính từ mép phải/dưới) nhân s, cộng padding an toàn.
@immutable
class Shop3dActionLayout {
  const Shop3dActionLayout({required this.primary, required this.throwButton, required this.wave, required this.done});

  factory Shop3dActionLayout.of(Size size, {EdgeInsets padding = EdgeInsets.zero}) {
    final s = Shop3dStyle.scaleOf(size);
    Offset at(double fromRight, double fromBottom) =>
        Offset(size.width - fromRight * s - padding.right, size.height - fromBottom * s - padding.bottom);
    return Shop3dActionLayout(primary: at(128, 128), throwButton: at(236, 200), wave: at(252, 92), done: at(128, 250));
  }

  static const primaryDiameter = 96.0;
  static const throwDiameter = 68.0;
  static const waveDiameter = 60.0;
  static const doneSize = Size(96, 40);

  final Offset primary;
  final Offset throwButton;
  final Offset wave;
  final Offset done;
}

/// Lớp phủ cụm nút. Tự trả về `Positioned.fill` — đặt làm con của `Stack` phủ cảnh; chỉ các nút nhận chạm.
///
/// - Nút A: [onPrimary] = null → mờ (truyền icon bàn tay, vd. `Icons.back_hand_rounded`).
/// - Nút B chỉ hiện khi [showThrow]. Nhả trước 0,2 s → [onThrowTap]; giữ 0,2–0,8 s (quá 0,8 s tính 0,8 s) →
///   [onThrowCharged] với lực 0..1, có vòng sáng hồng dâu khi nạp. Ngón bị huỷ / app vào nền / nút biến mất →
///   không gọi gì ([onThrowCancel] nếu có).
/// - Nút C: [waveCooldown] = phần hồi chiêu còn lại (1 → 0); > 0 thì vẽ quạt mờ và bỏ qua chạm.
/// - [visible] = false: mờ dần 150 ms, không nhận chạm.
class Shop3dActionCluster extends StatelessWidget {
  const Shop3dActionCluster({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.primarySemanticsLabel,
    this.showThrow = false,
    this.throwLabel = '',
    this.throwIcon = Icons.sports_handball_rounded,
    this.onThrowTap,
    this.onThrowCharged,
    this.onThrowChargeStart,
    this.onThrowCancel,
    required this.waveLabel,
    this.waveIcon = Icons.waving_hand_rounded,
    required this.onWave,
    this.waveCooldown,
    required this.doneLabel,
    required this.onDone,
    this.visible = true,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;

  /// Nhãn đọc màn hình của A khi khác nhãn hiện (vd. lúc mờ không có chữ).
  final String? primarySemanticsLabel;

  final bool showThrow;
  final String throwLabel;
  final IconData throwIcon;
  final VoidCallback? onThrowTap;
  final ValueChanged<double>? onThrowCharged;

  /// Bắt đầu nhấn B (để hiện tư thế lấy đà nếu muốn).
  final VoidCallback? onThrowChargeStart;
  final VoidCallback? onThrowCancel;

  final String waveLabel;
  final IconData waveIcon;
  final VoidCallback? onWave;
  final ValueListenable<double>? waveCooldown;

  final String doneLabel;
  final VoidCallback? onDone;

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Shop3dStyle.fade,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = constraints.hasBoundedHeight && constraints.hasBoundedWidth
                ? constraints.biggest
                : MediaQuery.sizeOf(context);
            final l = Shop3dActionLayout.of(size, padding: padding);
            Positioned place(Offset c, Size s, Widget child) =>
                Positioned(left: c.dx - s.width / 2, top: c.dy - s.height / 2, width: s.width, height: s.height, child: child);
            const doneHit = Size(96, 48);
            return Stack(
              children: [
                place(
                  l.done,
                  doneHit,
                  _DoneButton(label: doneLabel, onTap: onDone),
                ),
                place(
                  l.wave,
                  const Size.square(Shop3dActionLayout.waveDiameter),
                  Shop3dRoundActionButton(
                    key: const ValueKey('shop3d-wave'),
                    diameter: Shop3dActionLayout.waveDiameter,
                    label: waveLabel,
                    icon: waveIcon,
                    onTap: onWave,
                    cooldown: waveCooldown,
                  ),
                ),
                if (showThrow)
                  place(
                    l.throwButton,
                    const Size.square(Shop3dActionLayout.throwDiameter),
                    Shop3dThrowButton(
                      key: const ValueKey('shop3d-throw'),
                      label: throwLabel,
                      icon: throwIcon,
                      onTap: onThrowTap,
                      onCharged: onThrowCharged,
                      onChargeStart: onThrowChargeStart,
                      onCancel: onThrowCancel,
                    ),
                  ),
                place(
                  l.primary,
                  const Size.square(Shop3dActionLayout.primaryDiameter),
                  Shop3dRoundActionButton(
                    key: const ValueKey('shop3d-primary'),
                    diameter: Shop3dActionLayout.primaryDiameter,
                    label: primaryLabel,
                    icon: primaryIcon,
                    onTap: onPrimary,
                    semanticsLabel: primarySemanticsLabel,
                    iconSize: 36,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Mặt nút tròn: nền vàng bơ (mờ khi tắt), viền nâu 2px, bóng mềm, icon + nhãn Nunito đậm 13 một dòng.
class _RoundFace extends StatelessWidget {
  const _RoundFace({
    required this.diameter,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.pressed,
    this.iconSize,
    this.fontSize = 13,
  });

  final double diameter;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool pressed;
  final double? iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? AppColors.chocolate : SLColors.disabledInk;
    return AnimatedScale(
      scale: pressed ? 0.92 : 1,
      duration: SLMetrics.pressIn,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: Shop3dStyle.circle(color: enabled ? AppColors.butter : SLColors.disabledFill),
        padding: EdgeInsets.all(diameter * 0.12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize ?? diameter * 0.36, color: ink),
            if (label.isNotEmpty)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      softWrap: false,
                      style: Shop3dStyle.body(fontSize, weight: FontWeight.w800, color: ink, height: 1.1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nút tròn A / C. [onTap] = null → mờ. [cooldown] (1 → 0) > 0 → vẽ quạt mờ, bỏ qua chạm.
class Shop3dRoundActionButton extends StatefulWidget {
  const Shop3dRoundActionButton({
    super.key,
    required this.diameter,
    required this.label,
    required this.icon,
    required this.onTap,
    this.cooldown,
    this.semanticsLabel,
    this.iconSize,
    this.fontSize = 13,
  });

  final double diameter;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final ValueListenable<double>? cooldown;
  final String? semanticsLabel;
  final double? iconSize;
  final double fontSize;

  @override
  State<Shop3dRoundActionButton> createState() => _Shop3dRoundActionButtonState();
}

class _Shop3dRoundActionButtonState extends State<Shop3dRoundActionButton> {
  bool _pressed = false;

  bool get _cooling => (widget.cooldown?.value ?? 0) > 0;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _tap() {
    if (_cooling) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget face = _RoundFace(
      diameter: widget.diameter,
      label: widget.label,
      icon: widget.icon,
      enabled: enabled,
      pressed: _pressed,
      iconSize: widget.iconSize,
      fontSize: widget.fontSize,
    );
    final cd = widget.cooldown;
    if (cd != null) {
      face = CustomPaint(foregroundPainter: _CooldownPainter(cd), child: face);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel ?? widget.label,
      onTap: enabled ? _tap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? _tap : null,
        child: RepaintBoundary(child: face),
      ),
    );
  }
}

/// Quạt mờ hồi chiêu: phần còn lại tính từ 12 giờ theo chiều kim đồng hồ.
class _CooldownPainter extends CustomPainter {
  _CooldownPainter(this.cooldown) : super(repaint: cooldown);

  final ValueListenable<double> cooldown;

  static final _fill = Paint()..color = AppColors.chocolate.withValues(alpha: 0.35);

  @override
  void paint(Canvas canvas, Size size) {
    final f = cooldown.value.clamp(0.0, 1.0);
    if (f <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawArc(rect.deflate(2), -math.pi / 2, 2 * math.pi * f, true, _fill);
  }

  @override
  bool shouldRepaint(_CooldownPainter old) => old.cooldown != cooldown;
}

/// Nút B "Ném" Ø68: phân biệt chạm nhanh (< [tapMax]) và nhấn giữ nạp lực ([tapMax]..[holdMax] → 0..1).
/// Đo thời gian giữ bằng mốc thời gian của sự kiện chạm (lấy lớn hơn với đồng hồ hoạt ảnh — sự kiện không có mốc).
class Shop3dThrowButton extends StatefulWidget {
  const Shop3dThrowButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.onCharged,
    this.onChargeStart,
    this.onCancel,
    this.diameter = Shop3dActionLayout.throwDiameter,
  });

  /// Nhả trước mốc này = chạm nhanh.
  static const tapMax = Duration(milliseconds: 200);

  /// Giữ tới mốc này = lực tối đa.
  static const holdMax = Duration(milliseconds: 800);

  /// Lực ném 0..1 theo thời gian giữ; null = chạm nhanh.
  static double? powerFor(Duration held) {
    if (held < tapMax) return null;
    final span = (holdMax - tapMax).inMicroseconds;
    return ((held - tapMax).inMicroseconds / span).clamp(0.0, 1.0);
  }

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final ValueChanged<double>? onCharged;
  final VoidCallback? onChargeStart;
  final VoidCallback? onCancel;
  final double diameter;

  @override
  State<Shop3dThrowButton> createState() => _Shop3dThrowButtonState();
}

class _Shop3dThrowButtonState extends State<Shop3dThrowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: Shop3dThrowButton.holdMax);
  late final AppLifecycleListener _life;
  int? _pointer;
  Duration _downStamp = Duration.zero;

  bool get _enabled => widget.onTap != null || widget.onCharged != null;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: (s) {
      if (s != AppLifecycleState.resumed) _cancel();
    });
  }

  @override
  void dispose() {
    _life.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    if (!_enabled || _pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    _pointer = e.pointer;
    _downStamp = e.timeStamp;
    _hold.forward(from: 0);
    setState(() {});
    widget.onChargeStart?.call();
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final byEvent = e.timeStamp - _downStamp;
    final byClock = Shop3dThrowButton.holdMax * _hold.value;
    final held = byEvent > byClock ? byEvent : byClock;
    _release();
    final power = Shop3dThrowButton.powerFor(held);
    if (power == null) {
      widget.onTap?.call();
    } else {
      widget.onCharged?.call(power);
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _cancel();
  }

  void _cancel() {
    if (_pointer == null) return;
    _release();
    widget.onCancel?.call();
  }

  void _release() {
    _pointer = null;
    _hold.stop();
    _hold.value = 0;
    if (mounted) setState(() {});
  }

  void _semanticTap() => widget.onTap?.call();

  void _semanticLongPress() => widget.onCharged?.call(1);

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      onTap: widget.onTap == null ? null : _semanticTap,
      onLongPress: widget.onCharged == null ? null : _semanticLongPress,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: RepaintBoundary(
          child: CustomPaint(
            foregroundPainter: _ChargeRingPainter(_hold),
            child: _RoundFace(
              diameter: d,
              label: widget.label,
              icon: widget.icon,
              enabled: _enabled,
              pressed: _pointer != null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vòng sáng hồng dâu quanh nút B khi nạp lực (từ mốc chạm nhanh tới lực tối đa).
class _ChargeRingPainter extends CustomPainter {
  _ChargeRingPainter(this.hold) : super(repaint: hold);

  final Animation<double> hold;

  static final _track = Paint()
    ..color = AppColors.strawberry.withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;
  static final _arc = Paint()
    ..color = AppColors.strawberry
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final power = Shop3dThrowButton.powerFor(Shop3dThrowButton.holdMax * hold.value);
    if (power == null) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 + 5;
    canvas.drawCircle(c, r, _track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * math.max(power, 0.02), false, _arc);
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) => old.hold != hold;
}

/// Nút "Xong" 96×40 (vùng chạm 96×48), viên kẹo bạc hà.
class _DoneButton extends StatefulWidget {
  const _DoneButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<_DoneButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final ink = enabled ? AppColors.chocolate : SLColors.disabledInk;
    return Semantics(
      key: const ValueKey('shop3d-done'),
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: SLMetrics.pressIn,
            child: Container(
              width: Shop3dActionLayout.doneSize.width,
              height: Shop3dActionLayout.doneSize.height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: Shop3dStyle.box(color: enabled ? AppColors.mint : SLColors.disabledFill, radius: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.label,
                    maxLines: 1, softWrap: false, style: Shop3dStyle.body(15, weight: FontWeight.w800, color: ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
