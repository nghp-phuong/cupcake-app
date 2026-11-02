import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'constants.dart';

/// Khung tham chiếu cao 720, rộng W co giãn 1280–1600 theo tỉ lệ máy ([widthFor]); co giãn giữ tỉ lệ (letterbox màu
/// kem). Bên trong, `MediaQuery` báo size W×720, không phóng chữ → mọi màn dùng toạ độ cố định; vùng nội dung 1280×720
/// nằm giữa khung, lệch [RefMetrics.inset] (bọc [RefCenter] để màn cũ giữ toạ độ 1280×720).
///
/// - W = 1280 (16:9, 4:3, màn dọc, hoặc tai thỏ lấn vào vùng nội dung): giống hệt bản cũ — padding/insets bên trong
///   bằng 0, khung nằm trong vùng an toàn (`MediaQuery.viewPadding`), nền kem phủ cả màn — xem [frameRect].
/// - W > 1280 (máy dài): khung lấp cả màn, kể cả dưới tai thỏ (nền tràn kín); `MediaQuery.padding`/`viewPadding`
///   bên trong = phần inset an toàn quy ra đơn vị ref ([safeInsetsFor]) để phần tử bám mép tự lùi vào.
class RefFrame extends StatelessWidget {
  const RefFrame({super.key, required this.child});

  final Widget child;

  /// Rộng khung (đơn vị ref) cho màn [screen] có vùng không an toàn [safe]: 720 × rộng/cao màn, kẹp 1280–1600. Tính
  /// trên cả màn để nền tràn dưới tai thỏ. Trả 1280 (hành vi cũ, khung đặt trong vùng an toàn bằng [frameRect]) khi:
  /// màn dọc, hoặc inset trái/phải quy ra ref lấn vào vùng nội dung 1280 ở giữa (> (W−1280)/2). Inset trên/dưới (thanh hệ
  /// thống chưa kịp ẩn, cử chỉ điều hướng) không làm khung hẹp lại: chỉ đi vào `MediaQuery.padding` bên trong khung.
  static double widthFor(Size screen, EdgeInsets safe) {
    if (screen.width <= 0 || screen.height <= 0 || screen.width < screen.height) return kRefMinWidth;
    final width = (kRefHeight * screen.width / screen.height).clamp(kRefMinWidth, kRefMaxWidth);
    if (width <= kRefMinWidth) return kRefMinWidth;
    final pad = safeInsetsFor(screen, safe, width);
    final inset = (width - kRefMinWidth) / 2;
    // Sai số dấu phẩy động: inset vừa khít mép vùng nội dung vẫn tính là không lấn.
    if (pad.left > inset + 1e-6 || pad.right > inset + 1e-6) return kRefMinWidth;
    return width;
  }

  /// Phần inset an toàn [safe] (dp) quy ra đơn vị ref bên trong khung rộng [width] đặt giữa màn [screen] (đã trừ phần
  /// letterbox nằm ngoài khung, vd. máy 21:9 với khung 1600).
  static EdgeInsets safeInsetsFor(Size screen, EdgeInsets safe, double width) {
    final scale = math.min(screen.width / width, screen.height / kRefHeight);
    if (scale <= 0) return EdgeInsets.zero;
    final mx = (screen.width - width * scale) / 2, my = (screen.height - kRefHeight * scale) / 2;
    double x(double v) => math.max(0.0, (v - mx) / scale);
    double y(double v) => math.max(0.0, (v - my) / scale);
    return EdgeInsets.fromLTRB(x(safe.left), y(safe.top), x(safe.right), y(safe.bottom));
  }

  /// Vị trí khung trong màn [screen] có vùng không an toàn [safe]: cỡ = min(cỡ vừa cả màn, cỡ vừa vùng an toàn),
  /// đặt giữa màn rồi đẩy vào trong vùng an toàn (dời ít nhất có thể). Padding bằng 0 → giống hệt căn giữa thường.
  static Rect frameRect(Size screen, EdgeInsets safe) {
    final safeW = math.max(0.0, screen.width - safe.horizontal);
    final safeH = math.max(0.0, screen.height - safe.vertical);
    final scale = math.min(
      math.min(screen.width / kRefSize.width, screen.height / kRefSize.height),
      math.min(safeW / kRefSize.width, safeH / kRefSize.height),
    );
    final fw = kRefSize.width * scale, fh = kRefSize.height * scale;
    double place(double centered, double lo, double hi) => centered < lo ? lo : (centered > hi ? hi : centered);
    final left = place((screen.width - fw) / 2, safe.left, screen.width - safe.right - fw);
    final top = place((screen.height - fh) / 2, safe.top, screen.height - safe.bottom - fh);
    return Rect.fromLTWH(left, top, fw, fh);
  }

  @override
  Widget build(BuildContext context) {
    final outer = MediaQuery.of(context);
    final inner = outer.copyWith(
      size: kRefSize,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      textScaler: TextScaler.noScaling,
    );
    // viewPadding (không phải padding): không đổi khi bàn phím hiện → khung không nhảy cỡ.
    final safe = outer.viewPadding;
    return ColoredBox(
      color: AppColors.cream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : outer.size.width;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : outer.size.height;
          final width = widthFor(Size(w, h), safe);
          if (width > kRefMinWidth) return _wideFrame(outer, Size(w, h), safe, width);
          // Từ đây: W = 1280, cây widget giữ nguyên như bản cũ.
          final portrait = w < h;
          final rect = frameRect(Size(w, h), safe);
          Widget frame = Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: kRefSize,
                child: ClipRect(child: MediaQuery(data: inner, child: child)),
              ),
            ),
          );
          // Không có vùng không an toàn → giữ nguyên cây widget cũ (ảnh màn không tai thỏ không đổi).
          if (safe != EdgeInsets.zero) {
            frame = Padding(
              padding: EdgeInsets.fromLTRB(
                rect.left,
                rect.top,
                math.max(0.0, w - rect.right),
                math.max(0.0, h - rect.bottom),
              ),
              child: frame,
            );
          }
          if (!portrait) return frame;
          // Màn dọc: vẫn cho chơi trong khung, phần letterbox phía trên hiện lời nhắc xoay máy.
          return Stack(
            children: [
              Positioned.fill(child: frame),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: math.max(rect.top, 72),
                child: const _RotatePrompt(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Khung W×720 (W > 1280) lấp màn, kể cả dưới tai thỏ; vùng an toàn chuyển vào `MediaQuery` bên trong.
  Widget _wideFrame(MediaQueryData outer, Size screen, EdgeInsets safe, double width) {
    final size = Size(width, kRefHeight);
    final pad = safeInsetsFor(screen, safe, width);
    final inner = outer.copyWith(
      size: size,
      padding: pad,
      viewPadding: pad,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      textScaler: TextScaler.noScaling,
    );
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: size,
          child: ClipRect(
            child: RefScope(
              metrics: RefMetrics(width: width, safe: pad),
              child: MediaQuery(data: inner, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Số đo khung hiện tại (đơn vị ref): rộng [width] (1280–1600), cao 720; vùng nội dung 1280×720 lệch [inset] từ mép
/// trái; [safe] = vùng không an toàn (tai thỏ) đã quy ra ref. Không có [RefScope] phía trên → khung chuẩn 1280×720.
@immutable
class RefMetrics {
  const RefMetrics({this.width = kRefMinWidth, this.safe = EdgeInsets.zero});

  /// Khung chuẩn 1280×720, không inset (máy 16:9, test widget lẻ).
  static const standard = RefMetrics();

  final double width;
  final EdgeInsets safe;

  /// dx của vùng nội dung 1280 ở giữa = (W − 1280) / 2.
  double get inset => (width - kRefMinWidth) / 2;

  /// Cỡ khung W×720.
  Size get size => Size(width, kRefHeight);

  /// Vùng nội dung 1280×720 ở giữa khung (toạ độ khung).
  Rect get content => Rect.fromLTWH(inset, 0, kRefMinWidth, kRefHeight);

  /// Cả khung W×720 (toạ độ khung).
  Rect get full => Offset.zero & size;

  bool get isWide => width > kRefMinWidth;

  static RefMetrics of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RefScope>()?.metrics ?? standard;

  @override
  bool operator ==(Object other) => other is RefMetrics && other.width == width && other.safe == safe;

  @override
  int get hashCode => Object.hash(width, safe);

  @override
  String toString() => 'RefMetrics(width: $width, safe: $safe)';
}

/// Truyền [RefMetrics] xuống cây (RefFrame đặt khi W > 1280; [RefCenter] đặt lại về chuẩn cho nội dung bên trong).
class RefScope extends InheritedWidget {
  const RefScope({super.key, required this.metrics, required super.child});

  final RefMetrics metrics;

  @override
  bool updateShouldNotify(RefScope oldWidget) => metrics != oldWidget.metrics;
}

/// Đặt [child] vào vùng nội dung 1280×720 ở giữa khung: `MediaQuery.size` = 1280×720, padding bằng 0, cắt mép.
/// Dùng cho màn/phần chưa co giãn theo W (nền vẽ ngoài, nội dung bên trong). Khung 1280 → trả thẳng [child].
class RefCenter extends StatelessWidget {
  const RefCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = RefMetrics.of(context);
    if (!metrics.isWide) return child;
    final inner = MediaQuery.of(context).copyWith(
      size: kRefSize,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
    );
    return Center(
      child: SizedBox.fromSize(
        size: kRefSize,
        child: ClipRect(
          child: RefScope(
            metrics: RefMetrics.standard,
            child: MediaQuery(data: inner, child: child),
          ),
        ),
      ),
    );
  }
}

class _RotatePrompt extends StatelessWidget {
  const _RotatePrompt();

  @override
  Widget build(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 72, height: 72, child: CustomPaint(painter: RotateDevicePainter())),
            if (l != null) ...[
              const SizedBox(height: 8),
              Text(
                l.rotateDevicePrompt,
                textAlign: TextAlign.center,
                // Chỉ đặt màu/cỡ/độ đậm; họ font lấy từ DefaultTextStyle (SLScope ở app.dart → font nội dung).
                style: const TextStyle(
                  color: AppColors.chocolate,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Biểu tượng "xoay thiết bị" vẽ tay bằng code (tông mực nâu, cùng tinh thần bộ SL* nhưng không phụ thuộc lib/ui):
/// điện thoại nằm ngang tô màu nước hồng dâu, màn bạc hà, mũi tên cong; nét mực run nhẹ theo seed cố định.
class RotateDevicePainter extends CustomPainter {
  const RotateDevicePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final w = s * 0.055;
    Paint ink(double width, [double alpha = 1]) => Paint()
      ..color = AppColors.chocolate.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Rect.fromCenter(center: c.translate(0, s * 0.1), width: s * 0.72, height: s * 0.42);
    final phone = Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(s * 0.09)));
    final screen = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(body.left + s * 0.1, body.top + s * 0.06, body.right - s * 0.16, body.bottom - s * 0.06),
        Radius.circular(s * 0.03),
      ));
    // Màu nước lệch khỏi nét mực một chút.
    canvas
      ..drawPath(phone.shift(Offset(s * 0.012, s * 0.016)), Paint()..color = AppColors.strawberry.withValues(alpha: 0.85))
      ..drawPath(screen.shift(Offset(-s * 0.008, s * 0.01)), Paint()..color = AppColors.mint.withValues(alpha: 0.9));
    canvas
      ..drawPath(_wobble(phone, s, 1), ink(w))
      ..drawPath(_wobble(phone, s, 7), ink(w * 0.4, 0.45))
      ..drawPath(_wobble(screen, s, 3), ink(w * 0.6));
    canvas.drawCircle(Offset(body.right - s * 0.08, body.center.dy), s * 0.028, Paint()..color = AppColors.chocolate);

    // Mũi tên cong phía trên.
    final arcRect = Rect.fromCircle(center: c.translate(0, s * 0.1), radius: s * 0.46);
    final arc = Path()..addArc(arcRect, -math.pi * 0.85, math.pi * 0.6);
    canvas.drawPath(_wobble(arc, s, 5), ink(w));
    final tip = Offset(
      arcRect.center.dx + arcRect.width / 2 * math.cos(-math.pi * 0.25),
      arcRect.center.dy + arcRect.height / 2 * math.sin(-math.pi * 0.25),
    );
    final head = Path()
      ..moveTo(tip.dx - s * 0.15, tip.dy - s * 0.01)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - s * 0.03, tip.dy - s * 0.15);
    canvas.drawPath(_wobble(head, s, 9), ink(w));
  }

  /// Nét run tay: lấy mẫu theo chiều dài đường, đẩy lệch theo pháp tuyến bằng tổng sin (seed cố định, không ngẫu nhiên).
  static Path _wobble(Path source, double s, int seed) {
    final out = Path();
    final step = s * 0.035;
    final amp = s * 0.012;
    for (final m in source.computeMetrics()) {
      final n = math.max(2, (m.length / step).ceil());
      for (var i = 0; i <= n; i++) {
        final d = m.isClosed && i == n ? 0.0 : m.length * i / n;
        final t = m.getTangentForOffset(d);
        if (t == null) continue;
        final k = i.toDouble();
        final off = amp * (0.6 * math.sin(k * 0.9 + seed) + 0.4 * math.sin(k * 2.3 + seed * 1.7));
        final p = t.position + Offset(-t.vector.dy, t.vector.dx) * off;
        if (i == 0) {
          out.moveTo(p.dx, p.dy);
        } else {
          out.lineTo(p.dx, p.dy);
        }
      }
      if (m.isClosed) out.close();
    }
    return out;
  }

  @override
  bool shouldRepaint(RotateDevicePainter oldDelegate) => false;
}
