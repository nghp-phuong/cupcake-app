import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/catalog.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/models/quest.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../sugarleaf/sugarleaf.dart';

Future<void> showQuestsDialog(BuildContext context) =>
    showSugarDialog<void>(context, builder: (_) => const QuestsDialog());

/// 3 nhiệm vụ hôm nay: mô tả, thanh tiến trình, thưởng, nút nhận.
class QuestsDialog extends StatelessWidget {
  const QuestsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final quests = AppScope.of(context).state.quests;
    final allDone = quests.isNotEmpty && quests.every((q) => q.claimed);

    return SLDialog(
      title: l.questsTitle,
      titleColor: SLColors.mint,
      titleIcon: 'quest_board',
      width: 800,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < quests.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _QuestRow(index: i, quest: quests[i]),
          ],
          const SizedBox(height: 16),
          if (allDone)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SLChip(label: l.questsAllDone, selected: true, color: SLColors.butter, icon: 'confetti'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SLIcon('clock', size: 24, color: SLColors.inkSoft),
              const SizedBox(width: 6),
              Text(
                l.questsResetHint,
                style: SLTextStyles.of(context).body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ảnh vẽ tay cho biểu tượng nhiệm vụ (null = chưa có ảnh, dùng icon).
ArtRef? _questArt(QuestType t) => switch (t) {
  QuestType.earnStars => ArtSprites.starOn,
  QuestType.earnCoins => ArtSprites.coin,
  _ => null,
};

/// Id icon vẽ tay ([SLIcon]) của từng loại nhiệm vụ.
String _questIcon(QuestType t) => switch (t) {
  QuestType.serveCustomers => 'customer',
  QuestType.earnStars => 'star',
  QuestType.perfectBakes => 'flame',
  QuestType.fiveStarTreats => 'sparkle',
  QuestType.earnCoins => 'coin',
  QuestType.earnTips => 'tip_jar',
};

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.index, required this.quest});

  final int index;
  final QuestProgress quest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.read(context);
    final def = Catalog.quest(quest.type);
    final progress = math.min(quest.progress, def.target);
    final done = progress >= def.target;

    final art = _questArt(quest.type);
    return SLPaperCard(
      color: quest.claimed ? SLColors.paperShade : SLColors.paper,
      radius: 18,
      tilt: quest.claimed ? 0 : (index - 1) * 0.004,
      seed: 0x9E50 + index,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 58,
            child: SLSurface(
              spec: SLSurfaceSpec(
                shape: const SLCircle(),
                material: SLMaterial.wash,
                color: done ? SLColors.mint : SLColors.butter,
                seed: 0x9E60 + index,
              ),
              child: Center(
                child: art == null
                    ? SLIcon(_questIcon(quest.type), size: 34)
                    : SLArtIcon(art, _questIcon(quest.type), size: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.questText(quest.type, def.target),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTextStyles.of(context).label.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 6),
                SLProgressBar(
                  value: progress / def.target,
                  label: l.questProgress(progress, def.target),
                  color: SLColors.good,
                  height: 24,
                  seed: 0x9E70 + index,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 96,
            child: Center(
              child: def.rewardGems > 0
                  ? PriceTag(amount: def.rewardGems, gems: true)
                  : PriceTag(amount: def.rewardCoins),
            ),
          ),
          const SizedBox(width: 8),
          SLButton(
            label: quest.claimed ? l.commonClaimed : l.commonClaim,
            icon: quest.claimed ? 'check' : null,
            color: SLColors.strawberry,
            width: 150,
            height: 52,
            fontSize: 18,
            onPressed: !quest.claimed && done
                ? () {
                    if (services.state.claimQuest(index) != null) services.audio.success();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
