import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_theme.dart';

enum _SLBadgeKind { count, dot, label }

/// Huy hiệu nhỏ dạng nhãn dán: số (đỏ đậm, chữ kem), chấm báo, hoặc nhãn chữ (VIP, "Mới"…).
/// Số đổi → nảy một lần; VIP → lấp lánh một lần khi hiện. Không có hiệu ứng lặp vô hạn.
class SLBadge extends StatelessWidget {
  /// Số (lớn hơn [max] hiện "[max]+").
  const SLBadge.count(int this.count, {super.key, this.max = 99})
      : _kind = _SLBadgeKind.count,
        text = null,
        icon = null,
        color = SLColors.badDeep,
        sparkle = false;

  /// Chấm báo có việc chờ.
  const SLBadge.dot({super.key})
      : _kind = _SLBadgeKind.dot,
        count = null,
        max = 99,
        text = null,
        icon = null,
        color = SLColors.badDeep,
        sparkle = false;

  /// Nhãn chữ tuỳ ý (nền màu nước [color], chữ mực).
  const SLBadge.label(String this.text, {super.key, this.color = SLColors.butter, this.icon, this.sparkle = false})
      : _kind = _SLBadgeKind.label,
        count = null,
        max = 99;

  /// Nhãn khách VIP (chữ lấy từ AppLocalizations `customerVipBadge`).
  const SLBadge.vip({super.key})
      : _kind = _SLBadgeKind.label,
        count = null,
        max = 99,
        text = null,
        icon = 'vip',
        color = SLColors.butter,
        sparkle = true;

  final _SLBadgeKind _kind;
  final int? count;
  final int max;
  final String? text;
  final String? icon;
  final Color color;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    switch (_kind) {
      case _SLBadgeKind.dot:
        // Chấm mực đỏ chấm tay: viền run rõ hơn chấm tròn + vệt sáng cong phía trên trái.
        return const SizedBox.square(
          dimension: 18,
          child: SLSurface(
            spec: SLSurfaceSpec(
              shape: SLCircle(),
              material: SLMaterial.wash,
              color: SLColors.badDeep,
              sticker: true,
              inkWidth: 1.6,
              roughness: 1.8,
              seed: 7,
            ),
            child: CustomPaint(painter: _DotShinePainter()),
          ),
        );
      case _SLBadgeKind.count:
        final n = count!;
        final label = n > max ? '$max+' : '$n';
        final style = styles.caption.copyWith(color: SLColors.cream, fontWeight: FontWeight.w800, fontSize: 14, height: 1);
        return Semantics(
          label: label,
          child: ExcludeSemantics(
            child: _Pop(
              key: ValueKey(n),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                child: SLSurface(
                  spec: SLSurfaceSpec(
                    shape: label.length > 1 ? const SLRoundRect(13) : const SLCircle(),
                    material: SLMaterial.wash,
                    color: SLColors.badDeep,
                    sticker: true,
                    inkWidth: 1.6,
                    seed: n,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  child: Text(label, textAlign: TextAlign.center, style: style),
                ),
              ),
            ),
          ),
        );
      case _SLBadgeKind.label:
        final value = text ?? AppLocalizations.of(context).customerVipBadge;
        final badge = SLSurface(
          spec: SLSurfaceSpec(
            shape: const SLRoundRect(10),
            material: SLMaterial.wash,
            color: color,
            sticker: true,
            inkWidth: 1.8,
            seed: slSeed(content: value),
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[SLIcon(icon!, size: 18), const SizedBox(width: 4)],
              Flexible(
                child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: styles.caption.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        if (!sparkle) return badge;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            badge,
            const Positioned(right: -8, top: -10, child: SLSparkle(size: 18)),
          ],
        );
    }
  }
}

/// Vệt sáng cong run tay trên chấm báo (dựng một lần theo cỡ).
class _DotShinePainter extends CustomPainter {
  const _DotShinePainter();

  static final _cache = <int, Path>{};
  static final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xCCFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final d = size.shortestSide;
    final path = _cache.putIfAbsent(d.round(), () {
      final r = Rect.fromCircle(center: size.center(Offset.zero), radius: d * 0.27);
      return wobblePath(Path()..addArc(r, math.pi * 1.05, math.pi * 0.42), seed: 0xD07, amplitude: 0.35, step: 1.5);
    });
    canvas.drawPath(path, _paint..strokeWidth = math.max(1.4, d * 0.13));
  }

  @override
  bool shouldRepaint(_DotShinePainter old) => false;
}

/// Nảy một lần khi xuất hiện (đặt `key` đổi theo giá trị để nảy lại khi giá trị đổi).
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (slReduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SLMetrics.bounce,
      builder: (context, t, child) => Transform.scale(scale: 1 + 0.28 * math.sin(math.pi * t) * (1 - t * 0.5), child: child),
      child: child,
    );
  }
}

/// Ngôi sao lấp lánh: xoay + phóng một lần khi hiện (hoặc khi [trigger] đổi), sau đó đứng yên.
class SLSparkle extends StatelessWidget {
  const SLSparkle({super.key, this.size = 24, this.trigger});

  final double size;

  /// Đổi giá trị → lấp lánh lại.
  final Object? trigger;

  @override
  Widget build(BuildContext context) {
    final icon = SLIcon('sparkle', size: size);
    if (slReduceMotion(context)) return icon;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: (t * 3).clamp(0, 1),
        child: Transform.rotate(angle: (1 - t) * 1.2, child: Transform.scale(scale: 0.4 + 0.6 * t + 0.25 * math.sin(math.pi * t), child: child)),
      ),
      child: icon,
    );
  }
}

/// Dấu mộc tròn đóng nghiêng (vd. "đã nhận"): vòng mực [color] đậm, nền [fill] trong như mực đóng dấu, icon
/// [icon] (mặc định dấu tích) ở giữa cỡ 2/3 dấu. Trang trí — không đọc màn hình (nội dung đi kèm tự nói trạng thái).
class SLStamp extends StatelessWidget {
  const SLStamp({
    super.key,
    this.icon = 'check',
    this.size = 48,
    this.color = SLColors.goodDeep,
    this.fill = const Color(0x99D7EFE5),
    this.angle = -0.22,
    this.inkWidth = 2.6,
    this.seed = 0x57A9,
  });

  final String icon;
  final double size;
  final Color color;
  final Color fill;

  /// Góc nghiêng (radian).
  final double angle;
  final double inkWidth;
  final int seed;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: SizedBox.square(
          dimension: size,
          child: SLSurface(
            spec: SLSurfaceSpec(
              shape: const SLCircle(),
              material: SLMaterial.wash,
              color: fill,
              ink: color,
              inkWidth: inkWidth,
              seed: seed,
            ),
            child: Center(child: SLIcon(icon, size: size * 2 / 3, color: color)),
          ),
        ),
      );
}
