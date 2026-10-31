import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../sugarleaf/sugarleaf.dart';
import 'art.dart';
import 'format.dart';

/// Nhãn giấy dán hiển thị một loại tiền (xu hoặc gem) — [SLTopBarItem]: ảnh xu/gem vẽ tay + số, nghiêng nhẹ,
/// băng dính ở góc. Số đổi → nảy nhẹ. Từ 1 triệu hiện rút gọn ([formatCompact]); nhãn đọc màn hình vẫn đủ số.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip.coins(this.value, {super.key, this.height = 44}) : gems = false;
  const CurrencyChip.gems(this.value, {super.key, this.height = 44}) : gems = true;

  final int value;
  final bool gems;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final icon = (height * 0.72).clamp(28.0, 40.0);
    return _Pop(
      key: ValueKey(value),
      child: SLTopBarItem(
        value: formatCompact(context, value), // ≥ 1 triệu rút gọn (1.2M / 1,2 Tr) — UI-06
        leading: gems ? GemIcon(size: icon) : CoinIcon(size: icon),
        semanticLabel: gems ? l.commonGems(value) : l.commonCoins(value),
        minWidth: height * 2.4,
        seed: gems ? 0x6E35 : 0xC015,
      ),
    );
  }
}

/// Xu + gem hiện tại (lắng nghe GameState).
class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CurrencyChip.coins(state.coins, height: height),
        const SizedBox(width: 14),
        CurrencyChip.gems(state.gems, height: height),
      ],
    );
  }
}

/// Giá (xu hoặc gem) kèm biểu tượng vẽ tay; không đủ tiền → chữ đỏ đậm (đạt AA trên giấy).
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.amount, this.gems = false, this.affordable = true, this.size = 22});

  final int amount;
  final bool gems;
  final bool affordable;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gems) GemIcon(size: size * 1.2) else CoinIcon(size: size * 1.2),
        const SizedBox(width: 4),
        Text(
          formatInt(context, amount),
          style: SLTextStyles.of(context).number.copyWith(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: affordable ? AppColors.chocolate : SLColors.badDeep,
              ),
        ),
      ],
    );
  }
}

/// Nảy một lần khi số đổi (đặt `key` theo giá trị). Tắt hiệu ứng → đứng yên.
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (slReduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: SLMetrics.bounce,
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
