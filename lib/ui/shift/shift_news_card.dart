import 'package:flutter/widgets.dart';

import '../../core/art/cake_art.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/sugar_button.dart';
import '../sugarleaf/sugarleaf.dart';

/// Thẻ "Mở mới!" lúc mở ca (docs/v3/city-gd3-spec.md §4–§5.2): món + topping mở từ lần báo trước (lên cấp khi ở ngoài
/// tiệm). Cỡ cố định [size] (đơn vị ref); tối đa [maxTiles] ô hình, phần dư ghi "+N".
class ShiftNewsCard extends StatelessWidget {
  const ShiftNewsCard({super.key, required this.recipes, required this.toppings, required this.onClose});

  final List<RecipeId> recipes;
  final List<ToppingId> toppings;
  final VoidCallback onClose;

  static const size = Size(620, 460);
  static const maxTiles = 7;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final tiles = <Widget>[
      for (final r in recipes)
        _Tile(
          name: l.recipeName(r),
          image: CakeImage(visual: CakeVisual.recipe(r), recipe: r, size: 64),
        ),
      for (final t in toppings) _Tile(name: l.toppingName(t), image: ToppingImage(t, size: 50)),
    ];
    final count = tiles.length;
    final more = count - maxTiles;
    return SizedBox.fromSize(
      size: size,
      child: SLPaperCard(
        color: SLColors.butterLight,
        attach: SLAttach.tapeCorners,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        seed: 0x2E3A,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SLIcon('confetti', size: 36),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l.unlockNoticeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.title.copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(width: 8),
                const SLSparkle(size: 26),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.unlockNoticeBody(count),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ...tiles.take(maxTiles),
                    if (more > 0)
                      SizedBox(
                        width: 120,
                        height: 112,
                        child: Center(
                          child: Text(
                            l.unlockNoticeMore(more),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: styles.label.copyWith(fontSize: 18, color: SLColors.inkSoft),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SugarButton(
              key: const ValueKey('shift-news-close'),
              label: l.commonDone,
              iconId: 'check',
              color: SLColors.mint,
              width: 240,
              height: 60,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Một mục mới: hình (bánh / topping) trên mẩu giấy ngà + tên (tối đa 2 dòng).
class _Tile extends StatelessWidget {
  const _Tile({required this.name, required this.image});

  final String name;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 112,
      child: SLPaperCard(
        color: SLColors.paper,
        radius: 14,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        seed: SLRandom.hashString(name),
        child: Column(
          children: [
            Expanded(child: Center(child: image)),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SLTextStyles.of(context).label.copyWith(fontSize: 15, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}
