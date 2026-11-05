import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../sugarleaf/sugarleaf.dart';

/// Lớp phủ nhỏ của cảnh tiệm 3D (đặc tả `docs/v3/interaction-spec.md` 2.3–2.5): banner sự kiện có 2 nút, toast,
/// bong bóng thoại/phản ứng trên đầu, chip tên chọn khách, mũi tên đích nhấp nhô.
///
/// Widget thuần: nhận chuỗi đã dịch, icon, callback và điểm neo (Offset màn hình, đã chiếu từ thế giới). Mỗi widget
/// tự trả về `Positioned` — đặt làm con của `Stack` phủ cảnh (bọc trong `ValueListenableBuilder` được, miễn không có
/// RenderObject chen giữa). Vị trí đổi mỗi khung thì chỉ dựng lại `Positioned`; phần vẽ nằm trong `RepaintBoundary`.

/// Kiểu chung của lớp phủ cảnh 3D: khối nền + viền nâu 2px + bóng mềm, font tiêu đề/nội dung theo ngôn ngữ.
abstract final class Shop3dStyle {
  /// Hiện/ẩn mờ dần.
  static const fade = Duration(milliseconds: 150);

  /// Vùng chạm tối thiểu.
  static const minTap = SLMetrics.minTap;

  /// Hệ số co giãn `s = chiều cao / 720`, kẹp 0,85–1,4 (đặc tả 2.1).
  static double scaleOf(Size size) => (size.height / 720).clamp(0.85, 1.4).toDouble();

  /// Font tiêu đề (Fredoka; vi → Baloo 2 vì Fredoka thiếu dấu), có font dự phòng theo ký tự.
  static TextStyle title(BuildContext context, double size, {Color color = AppColors.chocolate}) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    return TextStyle(
      fontFamily: AppTheme.titleFontFamily(locale),
      fontFamilyFallback: AppTheme.titleFontFallback(locale),
      fontSize: size,
      fontWeight: AppTheme.titleWeight,
      color: color,
      height: 1.15,
    );
  }

  /// Font nội dung (Nunito).
  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w700, Color color = AppColors.chocolate, double height = 1.25}) =>
      TextStyle(fontFamily: AppTheme.nunito, fontSize: size, fontWeight: weight, color: color, height: height);

  /// Khối nền viền nâu 2px, bo [radius], bóng mềm.
  static BoxDecoration box({Color color = AppColors.butter, double radius = AppTheme.buttonRadius, bool shadow = true}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: const Border.fromBorderSide(AppTheme.border),
        boxShadow: shadow ? AppTheme.softShadow : null,
      );

  /// Khối tròn viền nâu 2px, bóng mềm.
  static BoxDecoration circle({Color color = AppColors.butter}) => BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: const Border.fromBorderSide(AppTheme.border),
        boxShadow: AppTheme.softShadow,
      );
}

// ---- Nút viên kẹo dùng chung ---------------------------------------------------------------------------------

/// Nút chữ dạng viên kẹo (nền vàng bơ, viền nâu 2px, bo 18, bóng mềm, nhấn lún nhẹ). Vùng chạm cao ≥ 48 dù
/// [height] nhỏ hơn. [onPressed] = null → mờ, không nhận chạm. Semantics lấy từ [semanticsLabel] hoặc [label].
class Shop3dPillButton extends StatefulWidget {
  const Shop3dPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.butter,
    this.width,
    this.height = 48,
    this.fontSize = 16,
    this.maxLines = 1,
    this.radius = AppTheme.buttonRadius,
    this.semanticsLabel,
    this.alignStart = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final double? width;
  final double height;
  final double fontSize;
  final int maxLines;
  final double radius;
  final String? semanticsLabel;

  /// Chữ canh trái (nút lựa chọn hội thoại); mặc định canh giữa.
  final bool alignStart;

  @override
  State<Shop3dPillButton> createState() => _Shop3dPillButtonState();
}

class _Shop3dPillButtonState extends State<Shop3dPillButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final ink = enabled ? AppColors.chocolate : SLColors.disabledInk;
    final text = Text(
      widget.label,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.alignStart ? TextAlign.start : TextAlign.center,
      style: Shop3dStyle.body(widget.fontSize, weight: FontWeight.w800, color: ink, height: 1.2),
    );
    final content = Row(
      mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: widget.alignStart ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.fontSize + 6, color: ink),
          const SizedBox(width: 8),
        ],
        if (widget.width == null) text else Flexible(child: text),
      ],
    );
    final visual = AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: SLMetrics.pressIn,
      child: Container(
        width: widget.width,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: Shop3dStyle.box(color: enabled ? widget.color : SLColors.disabledFill, radius: widget.radius),
        child: content,
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel ?? widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(widget.height, Shop3dStyle.minTap)),
          child: Align(widthFactor: 1, heightFactor: 1, child: visual),
        ),
      ),
    );
  }
}

// ---- Banner sự kiện ------------------------------------------------------------------------------------------

/// Banner sự kiện ở giữa mép trên (vd. "Có chuyện ồn ào trước cửa tiệm!") kèm 2 nút ("Xem", "Mai ra xem").
/// Trượt xuống khi hiện. Chỉ phần banner nhận chạm, ngoài banner vẫn tới cảnh.
class Shop3dEventBanner extends StatelessWidget {
  const Shop3dEventBanner({
    super.key,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.icon = Icons.campaign_rounded,
    this.primaryIcon = Icons.visibility_rounded,
    this.secondaryIcon = Icons.directions_walk_rounded,
    this.maxWidth = 640,
    this.top = 12,
  });

  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? icon;
  final IconData? primaryIcon;
  final IconData? secondaryIcon;
  final double maxWidth;

  /// Khoảng cách tới mép trên (cộng thêm padding an toàn).
  final double top;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final w = MediaQuery.sizeOf(context).width;
    return Positioned(
      top: pad.top + top,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(0, math.min(maxWidth, w - 32))),
          child: Shop3dSlideIn(
            from: const Offset(0, -1),
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: Shop3dStyle.box(color: AppColors.cream, radius: 20),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 26, color: AppColors.chocolate),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(message,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: Shop3dStyle.body(17, weight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Shop3dPillButton(label: primaryLabel, icon: primaryIcon, onPressed: onPrimary, color: AppColors.mint, height: 44),
                    const SizedBox(width: 8),
                    Shop3dPillButton(label: secondaryLabel, icon: secondaryIcon, onPressed: onSecondary, height: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Toast ---------------------------------------------------------------------------------------------------

/// Nội dung một toast; [id] tăng dần để toast trùng chữ vẫn hiện lại.
@immutable
class Shop3dToastData {
  const Shop3dToastData(this.message, {this.icon, this.id = 0});

  final String message;
  final IconData? icon;
  final int id;
}

/// Điều khiển toast: [show] thay toast đang hiện, tự ẩn sau [Shop3dToastController.defaultDuration]. Không phụ
/// thuộc widget — gọi được từ logic cảnh. Nhớ [dispose].
class Shop3dToastController {
  static const defaultDuration = SLMetrics.toastShow;

  final _current = ValueNotifier<Shop3dToastData?>(null);
  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  /// Toast đang hiện (null = không có).
  ValueListenable<Shop3dToastData?> get current => _current;

  void show(String message, {IconData? icon, Duration duration = defaultDuration}) {
    if (_disposed) return;
    _timer?.cancel();
    _current.value = Shop3dToastData(message, icon: icon, id: ++_seq);
    _timer = Timer(duration, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed) _current.value = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _current.dispose();
  }
}

/// Chỗ hiện toast của [controller] (phủ kín, không nhận chạm). [alignment] trong vùng an toàn; mặc định phía trên
/// giữa, dưới banner sự kiện.
class Shop3dToastHost extends StatelessWidget {
  const Shop3dToastHost({super.key, required this.controller, this.alignment = const Alignment(0, -0.55)});

  final Shop3dToastController controller;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: alignment,
            child: ValueListenableBuilder<Shop3dToastData?>(
              valueListenable: controller.current,
              builder: (context, data, _) => AnimatedSwitcher(
                duration: Shop3dStyle.fade,
                child: data == null
                    ? const SizedBox.shrink()
                    : Shop3dToast(key: ValueKey(data.id), message: data.message, icon: data.icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viên toast: nền kem, viền nâu, Nunito 18, tối đa 2 dòng.
class Shop3dToast extends StatelessWidget {
  const Shop3dToast({super.key, required this.message, this.icon, this.maxWidth = 520});

  final String message;
  final IconData? icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: Shop3dStyle.box(color: AppColors.cream, radius: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.chocolate),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Shop3dStyle.body(18, weight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Bong bóng trên đầu --------------------------------------------------------------------------------------

/// Kiểu bong bóng trên đầu nhân vật.
enum Shop3dBubbleKind {
  /// Câu nói ngắn ("Cảm ơn nha!", "Cho mình qua với!"): giấy ngà, Nunito 16, tối đa 3 dòng.
  speech,

  /// Phản ứng một chữ ("Ơ!", "!", "♥"): nền vàng bơ, chữ tiêu đề to.
  exclaim,

  /// Đám mây phồng khi cãi nhau (thường kèm "!" hoặc "#"): nền hồng dâu nhạt, viền mây.
  puff,

  /// Đang nói / đang nghĩ ("…"): giấy ngà, nhỏ.
  thinking,
}

/// Bong bóng trên đầu: đuôi chỉ xuống [anchor] (điểm trên đỉnh đầu, toạ độ màn). Không nhận chạm. Bật lên khi hiện
/// lần đầu (dùng `key` khác nhau để bật lại cho câu mới).
class Shop3dHeadBubble extends StatelessWidget {
  const Shop3dHeadBubble({
    super.key,
    required this.anchor,
    required this.text,
    this.kind = Shop3dBubbleKind.speech,
    this.maxWidth = 240,
    this.gap = 6,
  });

  final Offset anchor;
  final String text;
  final Shop3dBubbleKind kind;
  final double maxWidth;

  /// Khoảng hở giữa mũi đuôi và [anchor].
  final double gap;

  @override
  Widget build(BuildContext context) {
    final (Color fill, TextStyle style, EdgeInsets padding) = switch (kind) {
      Shop3dBubbleKind.speech => (SLColors.paper, Shop3dStyle.body(16, weight: FontWeight.w800), const EdgeInsets.symmetric(horizontal: 12, vertical: 7)),
      Shop3dBubbleKind.exclaim => (AppColors.butter, Shop3dStyle.title(context, 24), const EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
      Shop3dBubbleKind.puff => (SLColors.strawberryLight, Shop3dStyle.title(context, 22, color: SLColors.badDeep), const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
      Shop3dBubbleKind.thinking => (SLColors.paper, Shop3dStyle.title(context, 20), const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
    };
    final label = Text(text,
        maxLines: kind == Shop3dBubbleKind.speech ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style);
    final Widget bubble;
    if (kind == Shop3dBubbleKind.puff) {
      bubble = CustomPaint(painter: _PuffPainter(fill), child: Padding(padding: padding, child: label));
    } else {
      bubble = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: padding, decoration: Shop3dStyle.box(color: fill, radius: 16, shadow: false), child: label),
          // Đuôi chồng lên viền dưới 2px để che đoạn viền.
          Transform.translate(
            offset: const Offset(0, -2),
            child: CustomPaint(size: const Size(16, 10), painter: _TailPainter(fill)),
          ),
        ],
      );
    }
    return Positioned(
      left: anchor.dx,
      top: anchor.dy - gap,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: RepaintBoundary(child: Shop3dPopIn(child: bubble)),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    final edge = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
        edge,
        Paint()
          ..color = AppColors.caramel
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.fill != fill;
}

/// Đám mây phồng: hợp của các hình tròn quanh khung, viền nâu.
class _PuffPainter extends CustomPainter {
  _PuffPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = h * 0.36;
    var cloud = Path()..addRRect(RRect.fromLTRBR(r * 0.6, r * 0.6, w - r * 0.6, h - r * 0.6, Radius.circular(r)));
    final n = math.max(3, (w / (r * 1.3)).round());
    for (var i = 0; i < n; i++) {
      final x = r * 0.9 + (w - r * 1.8) * i / (n - 1);
      cloud = Path.combine(PathOperation.union, cloud, Path()..addOval(Rect.fromCircle(center: Offset(x, r * 0.9), radius: r)));
      cloud = Path.combine(
          PathOperation.union, cloud, Path()..addOval(Rect.fromCircle(center: Offset(x, h - r * 0.9), radius: r)));
    }
    canvas.drawShadow(cloud, AppColors.chocolate, 2, false);
    canvas.drawPath(cloud, Paint()..color = fill);
    canvas.drawPath(
        cloud,
        Paint()
          ..color = AppColors.caramel
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_PuffPainter old) => old.fill != fill;
}

// ---- Chip tên chọn khách -------------------------------------------------------------------------------------

/// Chip tên trên đầu khách khi chọn người để trò chuyện (đặc tả 2.3): nền bạc hà, chữ tiêu đề, icon bong bóng.
/// Vùng chạm cao ≥ 48. Đáy chip nằm ngay trên [anchor].
class Shop3dNameChip extends StatelessWidget {
  const Shop3dNameChip({
    super.key,
    required this.anchor,
    required this.label,
    required this.onTap,
    this.icon = Icons.chat_bubble_rounded,
    this.highlighted = false,
    this.semanticsLabel,
  });

  final Offset anchor;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Tô hồng dâu (vd. khách gần nhất).
  final bool highlighted;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1),
        child: Semantics(
          button: true,
          label: semanticsLabel ?? label,
          onTap: onTap,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Shop3dStyle.minTap, minWidth: Shop3dStyle.minTap),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: RepaintBoundary(
                  child: Shop3dPopIn(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: Shop3dStyle.box(color: highlighted ? AppColors.strawberry : AppColors.mint, radius: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: AppColors.chocolate),
                            const SizedBox(width: 6),
                          ],
                          Text(label, maxLines: 1, style: Shop3dStyle.title(context, 18)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Mũi tên đích --------------------------------------------------------------------------------------------

/// Mũi tên nhỏ nhấp nhô trên đầu đích của nút A (đặc tả 2.2). Mũi chỉ xuống [anchor]. Không nhận chạm.
/// Nhấp nhô bằng painter có repaint (không dựng lại widget mỗi khung); tắt hiệu ứng khi máy bật giảm chuyển động.
/// Lưu ý test: hoạt ảnh lặp → không dùng `pumpAndSettle` khi mũi tên đang hiện.
class Shop3dTargetArrow extends StatefulWidget {
  const Shop3dTargetArrow({
    super.key,
    required this.anchor,
    this.color = AppColors.butter,
    this.size = 24,
    this.bob = 6,
    this.period = const Duration(milliseconds: 900),
  });

  final Offset anchor;
  final Color color;

  /// Bề ngang mũi tên.
  final double size;

  /// Biên độ nhấp nhô (px).
  final double bob;
  final Duration period;

  @override
  State<Shop3dTargetArrow> createState() => _Shop3dTargetArrowState();
}

class _Shop3dTargetArrowState extends State<Shop3dTargetArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (slReduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size * 0.9 + widget.bob;
    return Positioned(
      left: widget.anchor.dx,
      top: widget.anchor.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(widget.size + 4, h + 4),
              painter: _ArrowPainter(_c, widget.color, widget.bob),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.t, this.color, this.bob) : super(repaint: t);

  final Animation<double> t;
  final Color color;
  final double bob;

  @override
  void paint(Canvas canvas, Size size) {
    final dy = bob * Curves.easeInOut.transform(t.value);
    final w = size.width - 4, h = size.height - 4 - bob;
    final top = 2 + dy;
    final path = Path()
      ..moveTo(2, top)
      ..lineTo(2 + w, top)
      ..lineTo(2 + w / 2, top + h)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x265A3E36));
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.caramel
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.t != t || old.color != color || old.bob != bob;
}

// ---- Hiệu ứng hiện -------------------------------------------------------------------------------------------

/// Bật lên (scale 0,6 → 1) một lần khi được gắn vào cây; tâm phóng ở [alignment].
class Shop3dPopIn extends StatelessWidget {
  const Shop3dPopIn({super.key, required this.child, this.alignment = Alignment.bottomCenter});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (slReduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, alignment: alignment, child: child),
      child: child,
    );
  }
}

/// Trượt vào từ [from] (đơn vị = kích thước con) và hiện dần, một lần khi được gắn vào cây.
class Shop3dSlideIn extends StatelessWidget {
  const Shop3dSlideIn({super.key, required this.from, required this.child});

  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (slReduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => FractionalTranslation(
        translation: from * (1 - v),
        child: Opacity(opacity: v, child: child),
      ),
      child: child,
    );
  }
}
