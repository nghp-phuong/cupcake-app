import 'package:flutter/widgets.dart';

import '../../core/art/cake_art.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/bake.dart';
import '../../core/models/customer.dart';
import '../../core/models/ids.dart';
import '../../core/models/order.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/speech_bubble.dart';
import '../common/star_row.dart';
import '../common/sugar_button.dart';
import '../sugarleaf/sugarleaf.dart';
import 'order_ticket.dart';

/// Nét mặt khách theo số sao.
CustomerMood moodForStars(int stars) => stars >= 4
    ? CustomerMood.happy
    : stars <= 2
    ? CustomerMood.sad
    : CustomerMood.neutral;

/// Hình chiếc bánh người chơi vừa làm, dựng lại từ số đo thô (độ nướng, độ phủ kem, topping đã đặt).
CakeVisual madeCakeVisual(Order order, BakeOutcome outcome) {
  final r = order.recipeData;
  final baked = (1 + (outcome.bakeRelease - r.bakeTarget) / 0.3).clamp(0.2, 2.0);
  return CakeVisual(
    mould: r.mould,
    batter: r.batter,
    baked: baked,
    frosting: order.frosting,
    frostCoverage: outcome.frostCoverage.clamp(0.0, 1.0),
    toppings: outcome.toppingsPlaced,
  );
}

/// Thẻ kết quả 720×440 — tờ giấy vẽ tay dán băng dính ([SLPaperCard]): khách trong khung tròn màu nước (mood
/// theo sao), bánh đã làm, 1–5 sao, khen/chê theo trạm, tiền/tip/XP, nút làm lại (quảng cáo) + khách tiếp theo.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.order,
    required this.customer,
    required this.outcome,
    required this.result,
    required this.canRemake,
    required this.onNext,
    required this.onRemake,
    this.busy = false,
  });

  final Order order;
  final Customer customer;
  final BakeOutcome outcome;
  final BakeResult result;
  final bool canRemake;
  final VoidCallback onNext;
  final VoidCallback onRemake;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final badge = customerBadge(l, customer);
    final complaint = result.complaint;
    final happy = result.stars >= 4;

    return SizedBox(
      width: 720,
      height: 440,
      child: SLPaperCard(
        attach: SLAttach.tapeCorners,
        radius: 28,
        padding: const EdgeInsets.all(20),
        seed: 0x5E5C,
        child: Row(
          children: [
            // Khách + bánh đã làm.
            SizedBox(
              width: 220,
              child: Column(
                children: [
                  _Portrait(customer: customer, stars: result.stars, happy: happy),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l.customerName(customer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.title.copyWith(fontSize: 21),
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 6), badge],
                    ],
                  ),
                  const Spacer(),
                  CakeImage(visual: madeCakeVisual(order, outcome), size: 130),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRow(stars: result.stars, size: 46, spacing: 6, animate: true),
                  const SizedBox(height: 12),
                  SpeechBubble(text: l.feedbackText(result.praise), fontSize: 21, tailX: 0.08),
                  if (complaint != null) ...[
                    const SizedBox(height: 8),
                    // Lời chê theo trạm (USP): mẩu giấy hồng nhạt, chữ đỏ đậm (đạt AA trên giấy).
                    SLSurface(
                      spec: const SLSurfaceSpec(
                        shape: SLRoundRect(14),
                        material: SLMaterial.wash,
                        color: SLColors.strawberryLight,
                        inkWidth: 1.8,
                        seed: 0xC0A1,
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.only(top: 2), child: SLIcon('error', size: 26)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.feedbackText(complaint),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: styles.label.copyWith(fontSize: 19, color: SLColors.badDeep),
                                ),
                                Text(
                                  l.feedbackNeedsWork(l.stationName(result.weakest)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: styles.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: SLColors.badDeep),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Một hàng, co lại nếu chữ dài (không tràn xuống dòng).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _Reward(icon: const CoinIcon(size: 26), text: l.resultPaid(result.payment), seed: 1),
                        const SizedBox(width: 10),
                        _Reward(icon: const CoinIcon(size: 26), text: l.resultTip(result.tip), color: SLColors.butter, seed: 2),
                        const SizedBox(width: 10),
                        _Reward(
                          icon: SLSparkle(size: 26, trigger: result.xp),
                          text: l.resultXp(result.xp),
                          color: SLColors.mint,
                          seed: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (canRemake) ...[
                        Expanded(
                          child: SugarButton(
                            label: l.dayRemakeWithAd,
                            iconId: 'play_video',
                            color: SLColors.mint,
                            height: 60,
                            fontSize: 18,
                            onPressed: busy ? null : onRemake,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SugarButton(
                          label: l.dayNextCustomer,
                          iconId: 'forward',
                          color: SLColors.strawberry,
                          height: 60,
                          onPressed: busy ? null : onNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khách trong khung tròn màu nước vẽ tay (bạc hà khi vui, hồng nhạt khi chưa vui); ảnh cắt tròn lọt trong nét mực.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.customer, required this.stars, required this.happy});

  final Customer customer;
  final int stars;
  final bool happy;

  static const _d = 200.0;
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    const inner = _d - _inset * 2;
    return SizedBox.square(
      dimension: _d,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLCircle(),
          material: SLMaterial.wash,
          color: happy ? SLColors.mint : SLColors.strawberryLight,
          inkWidth: 2.8,
          seed: happy ? 0xA11 : 0xA12,
        ),
        lift: 3,
        padding: const EdgeInsets.all(_inset),
        child: SLHandClip(
          seed: happy ? 0xA13 : 0xA14,
          child: OverflowBox(
            maxHeight: 280,
            alignment: Alignment.topCenter,
            child: CustomerImage(
              customer: customer,
              mood: moodForStars(stars),
              width: inner,
              height: inner * 1.33,
              // Ảnh vẽ tay toàn thân: phóng 1.8 lần, khung tròn cắt ngang eo.
              spriteZoom: 1.8,
              spriteDy: -6,
            ),
          ),
        ),
      ),
    );
  }
}

/// Phần thưởng (tiền / tip / XP): viên kẹo màu nước vẽ tay.
class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.text, this.color = SLColors.paper, this.seed = 0});

  final Widget icon;
  final String text;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SLSurface(
        spec: SLSurfaceSpec(shape: const SLRoundRect(21), material: SLMaterial.wash, color: color, inkWidth: 2, seed: 0x7E0 + seed),
        lift: 2.5,
        padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(text, style: SLTextStyles.of(context).label.copyWith(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

