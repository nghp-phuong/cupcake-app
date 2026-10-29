import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/catalog.dart';
import '../../core/models/quest.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../sugarleaf/sugarleaf.dart';

Future<void> showLoginGiftDialog(BuildContext context) =>
    showSugarDialog<void>(context, builder: (_) => const LoginGiftDialog());

/// Quà đăng nhập 7 ngày: mỗi ngày một thẻ giấy; hôm nay tô vàng bơ, dán băng dính, lấp lánh; ngày đã nhận
/// là giấy cũ đóng dấu tích; ngày chưa tới là giấy trắng.
class LoginGiftDialog extends StatelessWidget {
  const LoginGiftDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final state = services.state;
    final pending = state.pendingLoginReward;
    final streak = state.loginStreakDay;
    final today = pending?.day ?? streak;

    return SLDialog(
      title: l.loginTitle,
      titleIcon: 'gift',
      width: 960,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              for (final reward in Catalog.loginRewards)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _GiftTile(reward: reward, claimed: reward.day <= streak, isToday: reward.day == today),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 250),
            child: pending != null
                ? SLButton(
                    key: const ValueKey('claim'),
                    label: l.commonClaim,
                    leading: const SLArtIcon(ArtSprites.giftDaily, 'gift', size: 32),
                    color: SLColors.strawberry,
                    width: 260,
                    height: 60,
                    onPressed: () {
                      if (state.claimLogin() != null) services.audio.success();
                    },
                  )
                : _ComeBackNote(key: const ValueKey('comeBack'), text: l.loginComeBack),
          ),
        ],
      ),
    );
  }
}

/// Mẩu giấy bạc hà "Mai quay lại nhé" có trái tim vẽ tay.
class _ComeBackNote extends StatelessWidget {
  const _ComeBackNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SLSurface(
        spec: const SLSurfaceSpec(shape: SLRoundRect(26), material: SLMaterial.wash, color: SLColors.mintLight, seed: 0xC0BA),
        lift: 3,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SLIcon('heart', size: 30),
            const SizedBox(width: 10),
            Flexible(
              child: Text(text, style: SLTextStyles.of(context).label.copyWith(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.reward, required this.claimed, required this.isToday});

  final LoginReward reward;
  final bool claimed;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final big = reward.day == 7;
    final seed = 0x6100 + reward.day * 17;
    // Hôm nay: vàng bơ; đã nhận: giấy cũ; chưa tới: giấy trắng ngà (ngày 7 hơi hồng cho nổi).
    final paper = isToday
        ? SLColors.butterLight
        : claimed
            ? SLColors.paperShade
            : (big ? const Color(0xFFFFF0F3) : SLColors.paper);
    final tab = isToday ? SLColors.strawberry : (claimed ? SLColors.disabledFill : SLColors.butterLight);

    Widget tile = SizedBox(
      height: 168,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(16),
          color: paper,
          inkWidth: isToday ? SLMetrics.inkWidth + 0.6 : SLMetrics.inkWidth,
          seed: seed,
        ),
        lift: isToday ? 5 : 3,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          children: [
            // Nhãn "Ngày N": dải màu nước nhỏ ở đầu thẻ.
            SLSurface(
              spec: SLSurfaceSpec(shape: const SLRoundRect(10), material: SLMaterial.wash, color: tab, inkWidth: 1.6, seed: seed + 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l.loginDay(reward.day), maxLines: 1, style: styles.label.copyWith(fontSize: 16, height: 1.15)),
                ),
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: claimed && !isToday ? 0.7 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Quà lớn ngày 7: hộp quà vẽ tay trên các phần thưởng.
                    if (big) ...[const SLArtIcon(ArtSprites.giftDaily, 'gift', size: 48), const SizedBox(height: 2)],
                    if (reward.coins > 0) _Amount(coins: true, amount: reward.coins, big: big),
                    if (reward.coins > 0 && reward.gems > 0) const SizedBox(height: 4),
                    if (reward.gems > 0) _Amount(coins: false, amount: reward.gems, big: big),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final children = <Widget>[
      tile,
      // Dấu mộc đóng ở góc dưới phải, để vẫn đọc được phần quà đã nhận.
      if (claimed) const Positioned(right: 0, bottom: 0, child: SLStamp()),
      if (isToday) Positioned(left: 0, right: 0, top: -12, child: Center(child: SLTapeStrip(width: 54, height: 18, seed: seed))),
      if (isToday && !claimed) const Positioned(right: -8, top: -10, child: SLSparkle(size: 26)),
    ];
    tile = Stack(clipBehavior: Clip.none, children: children);
    return RepaintBoundary(
      child: AnimatedScale(
        scale: isToday && !claimed ? 1.06 : 1,
        duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 250),
        child: Transform.rotate(angle: isToday ? -0.025 : 0, child: tile),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.coins, required this.amount, required this.big});

  final bool coins;
  final int amount;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 28.0 : 40.0;
    final icon = coins ? CoinIcon(size: size) : GemIcon(size: size);
    final text = Text(
      formatInt(context, amount),
      style: SLTextStyles.of(context).number.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
    );
    // Ô quà lớn (hộp quà ở trên): biểu tượng và số nằm cùng hàng cho vừa ô.
    return big
        ? Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 4), text])
        : Column(mainAxisSize: MainAxisSize.min, children: [icon, text]);
  }
}
