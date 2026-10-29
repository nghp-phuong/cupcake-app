import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'sl_theme.dart';

/// Nét thứ hai của [SLRule] (kẻ tay hai lần).
enum SLRuleEcho {
  /// Chỉ một nét.
  none,

  /// Nét mảnh đi lại một đoạn (5% → 62% bề ngang), lệch xuống nửa nét — như kẻ vội rồi tô lại.
  partial,

  /// Nét mảnh chồng lệch suốt chiều dài (xuống 0,6 độ dày nét) — như kẻ tay hai lần.
  full,
}

/// Nét kẻ bút chì run tay chạy ngang (thay `Divider`/viền dưới của Material), chiếm hết bề ngang được cấp, cao
/// [height] (nét nằm giữa). Tất định theo [seed]; Path run tay cache theo (cỡ, tham số).
///
/// - [inset]: chừa hai đầu; [rise]: đầu phải lệch xuống (px) cho khỏi thẳng tắp; [amplitude]: độ run.
/// - [echo]: nét thứ hai mảnh bằng nửa [thickness], màu [echoColor] (mặc định [color] đậm 40%), run nhẹ hơn
///   (`partial`: [amplitude] − 0,3, seed + 1; `full`: [amplitude] × 0,75, seed + 16).
class SLRule extends StatelessWidget {
  const SLRule({
    super.key,
    this.height = 14,
    this.thickness = 2,
    this.color = SLColors.pencil,
    this.echo = SLRuleEcho.none,
    this.echoColor,
    this.amplitude = 1.3,
    this.inset = 3,
    this.rise = 0,
    this.seed = 0,
  });

  final double height;
  final double thickness;
  final Color color;
  final SLRuleEcho echo;
  final Color? echoColor;
  final double amplitude;
  final double inset;
  final double rise;
  final int seed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SLRulePainter(this)),
      );
}

typedef _RuleKey = (double, double, int, double, double, double, SLRuleEcho, double);

class _SLRulePainter extends CustomPainter {
  const _SLRulePainter(this.rule);

  final SLRule rule;

  /// Path run tay (nét chính, nét thứ hai) theo cỡ + tham số — dựng một lần.
  static final _cache = <_RuleKey, (Path, Path?)>{};

  (Path, Path?) _paths(Size size) {
    final r = rule;
    final key = (size.width, size.height, r.seed, r.amplitude, r.inset, r.rise, r.echo, r.thickness);
    return _cache.putIfAbsent(key, () {
      if (_cache.length > 48) _cache.clear();
      final w = size.width, y = size.height / 2, t = r.thickness;
      final main = wobblePath(
        Path()
          ..moveTo(r.inset, y)
          ..lineTo(w - r.inset, y + r.rise),
        seed: r.seed,
        amplitude: r.amplitude,
        step: 6,
      );
      final echo = switch (r.echo) {
        SLRuleEcho.none => null,
        SLRuleEcho.partial => wobblePath(
            Path()
              ..moveTo(w * 0.05, y + t * 0.5 + r.rise * 0.05)
              ..lineTo(w * 0.62, y + t * 0.3 + r.rise * 0.62),
            seed: r.seed + 1,
            amplitude: (r.amplitude - 0.3).clamp(0.3, double.infinity),
            step: 6,
          ),
        SLRuleEcho.full => wobblePath(
            Path()
              ..moveTo(r.inset, y + t * 0.6)
              ..lineTo(w - r.inset, y + t * 0.6 + r.rise),
            seed: r.seed + 16,
            amplitude: r.amplitude * 0.75,
            step: 6,
          ),
      };
      return (main, echo);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 * rule.inset + 2) return;
    final (main, echo) = _paths(size);
    final pen = Paint()
      ..color = rule.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = rule.thickness;
    canvas.drawPath(main, pen);
    if (echo == null) return;
    canvas.drawPath(
      echo,
      pen
        ..color = rule.echoColor ?? rule.color.withValues(alpha: rule.color.a * 0.4)
        ..strokeWidth = rule.thickness * 0.5,
    );
  }

  @override
  bool shouldRepaint(_SLRulePainter old) {
    final a = old.rule, b = rule;
    return a.thickness != b.thickness ||
        a.color != b.color ||
        a.echo != b.echo ||
        a.echoColor != b.echoColor ||
        a.amplitude != b.amplitude ||
        a.inset != b.inset ||
        a.rise != b.rise ||
        a.seed != b.seed;
  }
}
