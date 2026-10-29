import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'constants.dart';

/// Khung tham chiếu 1280×720: co giãn giữ tỉ lệ (letterbox màu kem). Bên trong, `MediaQuery`
/// luôn báo size 1280×720, không padding/insets, không phóng chữ → mọi màn dùng toạ độ cố định.
class RefFrame extends StatelessWidget {
  const RefFrame({super.key, required this.child});

  final Widget child;

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
    return ColoredBox(
      color: AppColors.cream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : outer.size.width;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : outer.size.height;
          final portrait = w < h;
          final frame = Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: kRefSize,
                child: ClipRect(child: MediaQuery(data: inner, child: child)),
              ),
            ),
          );
          if (!portrait) return frame;
          // Màn dọc: vẫn cho chơi trong khung, phần letterbox phía trên hiện lời nhắc xoay máy.
          final letterbox = (h - w * kRefSize.height / kRefSize.width) / 2;
          return Stack(
            children: [
              Positioned.fill(child: frame),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: math.max(letterbox, 72),
                child: const _RotatePrompt(),
              ),
            ],
          );
        },
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
