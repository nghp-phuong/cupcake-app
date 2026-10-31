import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/catalog.dart';
import '../../core/economy.dart';
import '../../core/game_state.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/models/recipe.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/panel.dart';
import '../common/star_row.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';

/// Sổ công thức của bà: lưới đủ mọi món trên một trang (18 món = 6×3, ≤ 10 món = 5×2; ô co theo khung, không cuộn) —
/// mỗi món là ô giấy có ảnh bánh dán băng dính, món khoá là "trang còn thiếu"; bên phải trang sổ chi tiết (giấy kẻ
/// bút chì, gáy lò xo).
/// "Trang còn thiếu" của món chưa mở (V2): món mở khi level đầu tiên có món trong thực đơn được mở → "Có ở màn N";
/// chưa level nào có món (chương sau) → "Sẽ có ở chương sau".
String missingPageText(BuildContext context, RecipeId id) {
  final l = AppLocalizations.of(context);
  final config = AppScope.read(context).levels;
  for (final level in config.levels) {
    if (level.menu.contains(id)) return l.mapRecipeFromLevel(level.id);
  }
  return l.mapRecipeLater;
}

/// Nhãn ngắn trên ô món khoá trong lưới: "Màn N" (level đầu tiên có món); chưa level nào có món → câu dài
/// [missingPageText]. Trang chi tiết vẫn ghi câu đầy đủ.
String missingTileText(BuildContext context, RecipeId id) {
  final config = AppScope.read(context).levels;
  for (final level in config.levels) {
    if (level.menu.contains(id)) return AppLocalizations.of(context).levelNumber(level.id);
  }
  return missingPageText(context, id);
}

class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  RecipeId _selected = RecipeId.cupcakeVanilla;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context).state;
    return SugarScreen(
      title: l.recipesTitle,
      titleIconId: 'book',
      titleArt: ArtSprites.book,
      body: Stack(
        children: [
          Positioned(
            left: 24,
            top: 16,
            width: 770,
            height: 600,
            child: Panel(
              color: const Color(0xFFF7E3CC),
              radius: 26,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: RecipeGrid(
                children: [
                  for (final r in Catalog.recipes)
                    _RecipeTile(
                      recipe: r,
                      unlocked: state.isRecipeUnlocked(r.id),
                      mastery: state.recipeMastery(r.id),
                      selected: r.id == _selected,
                      onTap: () => setState(() => _selected = r.id),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 816,
            top: 16,
            right: 24,
            height: 600,
            child: _RecipePage(
              recipe: Catalog.recipe(_selected),
              unlocked: state.isRecipeUnlocked(_selected),
              mastery: state.recipeMastery(_selected),
              state: state,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lưới ô món lấp đầy khung được cấp, không cuộn: ≤ 10 món → 5 cột, nhiều hơn → 6 cột; số hàng theo số món (hàng
/// cuối thiếu thì để trống bên phải). Ô co giãn theo khung (18 món trong khung 1280×720: ô ~115×180).
class RecipeGrid extends StatelessWidget {
  const RecipeGrid({super.key, required this.children, this.columnSpacing = 10, this.rowSpacing = 14});

  final List<Widget> children;
  final double columnSpacing;
  final double rowSpacing;

  static int columnsFor(int count) => count <= 10 ? 5 : 6;

  @override
  Widget build(BuildContext context) {
    final cols = columnsFor(children.length);
    final rows = (children.length / cols).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) SizedBox(height: rowSpacing),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) SizedBox(width: columnSpacing),
                  Expanded(
                    child: row * cols + col < children.length ? children[row * cols + col] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Ô giấy một món: ảnh bánh dán băng dính, tên, sao thành thạo. Đang chọn → giấy hồng nhạt viền đậm + đinh ghim;
/// khoá → giấy cũ, bóng bánh + ổ khoá.
class _RecipeTile extends StatelessWidget {
  const _RecipeTile({
    required this.recipe,
    required this.unlocked,
    required this.mastery,
    required this.selected,
    required this.onTap,
  });

  final Recipe recipe;
  final bool unlocked;
  final int mastery;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(context, box.maxHeight));

  Widget _build(BuildContext context, double height) {
    final l = AppLocalizations.of(context);
    final theme = SLTheme.of(context);
    final styles = SLTextStyles.of(context);
    final seed = 0x2EC0 + recipe.id.index * 13;
    // Ô thấp (lưới 6×3, cao ~180) → ảnh, chữ, sao, khoá nhỏ lại; ô cao (5×2, ~260) giữ cỡ cũ.
    final compact = height < 230;
    final photoHeight = (height * 0.47).clamp(60.0, 116.0);
    final cake = CakeImage(visual: CakeVisual.recipe(recipe.id), recipe: recipe.id, size: photoHeight * 0.86);
    final fill = unlocked
        ? (selected ? SLColors.strawberryLight : SLColors.paper)
        : (selected ? const Color(0xFFF6DCD3) : SLColors.paperShade);
    final spec = SLSurfaceSpec(
      shape: const SLRoundRect(16),
      color: fill,
      ink: theme.ink,
      inkWidth: selected ? theme.inkWidth + 1.2 : theme.inkWidth - 0.2,
      roughness: theme.roughness,
      seed: seed,
    );

    // Ảnh bánh dán lên ô (giấy trắng, băng dính ở mép trên).
    final photo = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SLSurface(
            spec: SLSurfaceSpec(
              shape: const SLRoundRect(6),
              color: unlocked ? const Color(0xFFFFFDF8) : const Color(0xFFEDE0CF),
              inkWidth: 1.4,
              seed: seed + 1,
            ),
            lift: 1.5,
          ),
        ),
        Positioned.fill(
          child: Center(
            child: unlocked
                ? cake
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Món chưa mở: ảnh bánh phai màu, mờ trên giấy cũ + nhãn khoá dán.
                      const Positioned(left: -4, top: 2, right: -4, bottom: 2, child: _FadedPhoto()),
                      _faded(cake),
                      Positioned(
                        right: 2,
                        bottom: 4,
                        child: SLIconDisc('lock', size: compact ? 32 : 44, iconScale: 0.62, lift: 2, seed: seed + 5),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: -9,
          child: Center(child: SLTapeStrip(width: compact ? 38 : 46, height: compact ? 13 : 16, angle: (recipe.id.index.isEven ? -1 : 1) * 0.06, seed: seed)),
        ),
      ],
    );

    return RepaintBoundary(
      child: SLPressable(
        onPressed: onTap,
        selected: selected,
        builder: (context, press) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SLSurface(
                spec: spec,
                lift: selected ? 4.5 : 3,
                press: press,
                padding: compact ? const EdgeInsets.fromLTRB(6, 12, 6, 6) : const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Column(
                  children: [
                    SizedBox(height: photoHeight, child: photo),
                    SizedBox(height: compact ? 5 : 8),
                    Expanded(
                      child: Text(
                        unlocked ? l.recipeName(recipe.id) : missingTileText(context, recipe.id),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: styles.label.copyWith(
                          fontSize: unlocked ? (compact ? 14.5 : 17) : (compact ? 16 : 18),
                          height: compact ? 1.15 : null,
                          fontWeight: unlocked ? FontWeight.w800 : FontWeight.w900,
                          color: theme.ink,
                        ),
                      ),
                    ),
                    if (unlocked) StarRow(stars: mastery, max: 3, size: compact ? 20 : 26),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(left: 0, right: 0, top: -12, child: Center(child: SLPushPin(seed: seed))),
          ],
        ),
      ),
    );
  }
}

/// Trang sổ chi tiết: hình, tên, mô tả, giá (đã cộng bí quyết), nguyên liệu, thành thạo, Bí quyết của bà — trên giấy
/// kẻ bút chì có gáy lò xo.
class _RecipePage extends StatelessWidget {
  const _RecipePage({required this.recipe, required this.unlocked, required this.mastery, required this.state});

  final Recipe recipe;
  final bool unlocked;
  final int mastery;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = SLTheme.of(context);
    final styles = SLTextStyles.of(context);
    return RepaintBoundary(
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(20),
          color: const Color(0xFFFFFBF2),
          ink: theme.ink,
          inkWidth: theme.inkWidth + 0.3,
          roughness: theme.roughness,
          seed: 0x500C,
        ),
        lift: SLMetrics.panelLift,
        child: CustomPaint(
          painter: const _NotebookPainter(),
          child: unlocked
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(44, 14, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CakeImage(visual: CakeVisual.recipe(recipe.id), recipe: recipe.id, size: 96),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.recipeName(recipe.id),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: styles.heading.copyWith(fontSize: 26),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      l.recipesPrice(state.recipeSellPrice(recipe.id)),
                                      key: const ValueKey('recipe-price'),
                                      style: styles.body.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: state.recipeSecretPricePct(recipe.id) > 0 ? SLColors.goodDeep : null,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const CoinIcon(size: 22),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        l.recipeDesc(recipe.id),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: styles.body.copyWith(fontSize: 17, fontStyle: FontStyle.italic, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      _Heading(l.recipesIngredients),
                      const SizedBox(height: 2),
                      // Khuôn và bột tên ngắn → chung một hàng; kem và topping (có thể nhiều loại) mỗi thứ một hàng.
                      Row(
                        children: [
                          Expanded(
                            child: _Ingredient(icon: MouldImage(recipe.mould, size: 28), text: l.mouldName(recipe.mould)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Ingredient(icon: BatterSwatch(recipe.batter, size: 24), text: l.batterName(recipe.batter)),
                          ),
                        ],
                      ),
                      _Ingredient(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final f in recipe.frostings) FrostingSwatch(f, size: 24)],
                        ),
                        text: recipe.frostings.map(l.frostingName).join(', '),
                      ),
                      _Ingredient(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final t in recipe.toppings) ToppingImage(t, size: 24)],
                        ),
                        text: recipe.toppings.map(l.toppingName).join(', '),
                      ),
                      const SizedBox(height: 12),
                      _Heading(l.recipesMastery),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StarRow(stars: mastery, max: 3, size: 34, spacing: 5),
                          const SizedBox(width: 10),
                          if (mastery >= 3)
                            // Cả chip co nhỏ cho vừa chỗ còn lại thay vì cắt chữ ("Thành thạo! +2 kim cương").
                            Flexible(
                              child: SLBounceIn(
                                child: FittedBox(
                                  key: const ValueKey('recipe-mastery-chip'),
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 480),
                                    child: TagChip(
                                      l.recipesMasteryReward(Economy.masteryGemReward),
                                      color: SLColors.butter,
                                      iconId: 'trophy',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.recipesMasteryHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: theme.inkSoft),
                      ),
                      const SizedBox(height: 12),
                      _SecretsSection(recipe: recipe.id, state: state),
                      const Spacer(),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(44, 32, 32, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ảnh bánh phai màu, mờ trên mảng màu nước giấy cũ; nhãn khoá dán ở góc.
                        SizedBox(
                          width: 250,
                          height: 220,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned(left: 6, top: 14, right: 6, bottom: 0, child: _FadedPhoto(large: true)),
                              Positioned.fill(
                                child: Center(
                                  child: _faded(CakeImage(visual: CakeVisual.recipe(recipe.id), recipe: recipe.id, size: 200)),
                                ),
                              ),
                              const Positioned(right: 0, bottom: -6, child: SLIconDisc('lock', size: 72, lift: 3, seed: 0x10C4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          missingPageText(context, recipe.id),
                          textAlign: TextAlign.center,
                          style: styles.heading.copyWith(fontSize: 24, color: theme.inkSoft),
                        ),
                        if (state.recipeSecretsUnlocked) ...[
                          const SizedBox(height: 10),
                          _SecretNote(
                            key: const ValueKey('recipe-secret-recipe-locked'),
                            icon: 'lock',
                            text: l.recipeSecretsRecipeLocked,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Bí quyết của bà" (GĐ8) trên trang sổ: hàng huy hiệu lá các bậc (đã học = bạc hà, chưa = xám), % giá đang cộng →
/// bậc kế (đậm, lớn), nút "Học bí quyết" có giá xu bên trong. Khoá tới màn `recipeSecretsConfig.level` (41) — kèm dòng giải
/// thích; đã học hết → huy hiệu. Thiếu xu: nút mờ, giá đỏ, vẫn bấm được để rung + nhắc "Không đủ xu".
class _SecretsSection extends StatefulWidget {
  const _SecretsSection({required this.recipe, required this.state});

  final RecipeId recipe;
  final GameState state;

  @override
  State<_SecretsSection> createState() => _SecretsSectionState();
}

class _SecretsSectionState extends State<_SecretsSection> {
  int _shortTries = 0;

  /// Chống chạm đúp (UI-05, như nút nâng thiết bị): khoảng nghỉ sau mỗi lần học + chỉ học khi bậc hiện tại khớp bậc
  /// lúc dựng gần nhất (lần bấm thứ hai trước khi khu dựng lại bị bỏ).
  bool _cooling = false;
  int _shownTier = 0;
  Timer? _coolTimer;

  static const cooldown = Duration(milliseconds: 400);

  @override
  void dispose() {
    _coolTimer?.cancel();
    super.dispose();
  }

  void _buy() {
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final state = services.state;
    if (_cooling || state.recipeSecretTier(widget.recipe) != _shownTier) return;
    final price = state.recipeSecretPrice(widget.recipe);
    if (state.buyRecipeSecret(widget.recipe)) {
      _cooling = true;
      _coolTimer?.cancel();
      _coolTimer = Timer(cooldown, () => _cooling = false);
      services.audio.success();
      showToast(context, l.recipeSecretsTier(state.recipeSecretTier(widget.recipe), state.recipeSecretMaxTier));
    } else if (price != null && state.coins < price) {
      // Chỉ nhắc "không đủ xu" khi thật sự thiếu xu; không mua được vì lý do khác (khoá / tối đa) → im lặng.
      services.audio.fail();
      setState(() => _shortTries++);
      showToast(context, l.commonNotEnoughCoins, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final state = widget.state;
    final id = widget.recipe;
    final cfg = state.recipeSecretsConfig;
    if (cfg == null) return const SizedBox.shrink();
    final max = state.recipeSecretMaxTier;
    final open = state.recipeSecretsUnlocked;
    final tier = _shownTier = state.recipeSecretTier(id);
    final pct = state.recipeSecretPricePct(id);
    final nextPct = state.recipeSecretNextPricePct(id);
    final price = state.recipeSecretPrice(id);
    final bonusStyle = styles.body.copyWith(fontWeight: FontWeight.w800);

    final Widget info;
    if (!open) {
      info = Text(
        l.recipeSecretsHint,
        key: const ValueKey('recipe-secret-hint'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: styles.body.copyWith(fontSize: 14, height: 1.15, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
      );
    } else {
      info = FittedBox(
        key: const ValueKey('recipe-secret-bonus'),
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (nextPct == null)
              Text(l.recipeSecretsBonus(pct), style: bonusStyle.copyWith(fontSize: 21, color: SLColors.goodDeep))
            else ...[
              Text(
                l.recipeSecretsBonus(pct),
                key: const ValueKey('recipe-secret-bonus-now'),
                style: bonusStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
              ),
              const SizedBox(width: 6),
              const SLIcon('forward', size: 22, color: SLColors.ink),
              const SizedBox(width: 6),
              Text(
                l.recipeSecretsBonus(nextPct),
                key: const ValueKey('recipe-secret-bonus-next'),
                style: bonusStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w900, color: SLColors.goodDeep),
              ),
            ],
          ],
        ),
      );
    }

    final Widget action;
    if (!open) {
      action = _SecretNote(key: const ValueKey('recipe-secret-locked'), icon: 'lock', text: l.recipeSecretsLocked(cfg.level));
    } else if (!state.isRecipeUnlocked(id)) {
      action = _SecretNote(key: const ValueKey('recipe-secret-recipe-locked'), icon: 'lock', text: l.recipeSecretsRecipeLocked);
    } else if (price == null) {
      action = _SecretNote(
        key: const ValueKey('recipe-secret-maxed'),
        icon: 'medal_max',
        text: l.recipeSecretsMaxed,
        color: SLColors.goodDeep,
      );
    } else {
      final affordable = state.coins >= price;
      action = SLShake(
        trigger: _shortTries,
        child: Opacity(
          opacity: affordable ? 1 : 0.6,
          child: SLButton(
            key: const ValueKey('recipe-secret-buy'),
            label: l.recipeSecretsBuy,
            icon: 'sparkle',
            trailing: PriceTag(key: const ValueKey('recipe-secret-price'), amount: price, affordable: affordable, size: 20),
            color: affordable ? SLColors.butter : SLColors.paperShade,
            width: double.infinity,
            height: 48,
            fontSize: 18,
            onPressed: _buy,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: _Heading(l.recipeSecretsTitle)),
              ),
            ),
            const SizedBox(width: 8),
            if (open)
              Text(
                l.recipeSecretsTier(tier, max),
                key: const ValueKey('recipe-secret-tier'),
                style: styles.label.copyWith(fontSize: 15, color: SLColors.inkSoft),
              ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: Row(
            children: [
              for (var i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _SecretPip(learned: i < tier, seed: 0x5EC0 + i),
              ],
              const SizedBox(width: 10),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: info)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(height: SLMetrics.minTap, child: action),
      ],
    );
  }
}

/// Một bậc bí quyết: huy hiệu lá vẽ tay (đã học → bạc hà, chưa → giấy cũ, lá xám) — khác sao thành thạo.
class _SecretPip extends StatelessWidget {
  const _SecretPip({required this.learned, required this.seed});

  final bool learned;
  final int seed;

  @override
  Widget build(BuildContext context) => SLIconDisc(
        'leaf_logo',
        size: 36,
        iconScale: 0.66,
        lift: learned ? 2 : 1,
        color: learned ? SLColors.mint : SLColors.paperShade,
        iconColor: learned ? null : SLColors.disabledInk,
        seed: seed,
      );
}

/// Dòng trạng thái của bí quyết (khoá / món chưa mở / đã học hết): icon + chữ tối đa 2 dòng.
class _SecretNote extends StatelessWidget {
  const _SecretNote({super.key, required this.icon, required this.text, this.color = SLColors.inkSoft});

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SLIcon(icon, size: 26, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTextStyles.of(context).body.copyWith(fontSize: 15, height: 1.15, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      );
}

/// Ảnh món chưa mở: giảm ~80% độ bão hoà, ngả ấm về màu giấy, mờ còn ~45% (một lớp lọc màu duy nhất, gồm cả
/// độ trong) — vẫn nhận ra hình bánh, không thành mảng nâu phẳng.
Widget _faded(Widget child) => ColorFiltered(colorFilter: _fadedFilter, child: child);

final ColorFilter _fadedFilter = ColorFilter.matrix(_fadedMatrix());

List<double> _fadedMatrix() {
  const keep = 0.2, alpha = 0.45;
  const luma = [0.2126, 0.7152, 0.0722];
  // Ngả nhẹ về sepia giấy cũ (đỏ/xanh lá hơi cao hơn xanh dương).
  const warm = [1.04, 0.98, 0.86];
  return [
    for (var i = 0; i < 3; i++) ...[
      for (var j = 0; j < 3; j++) warm[i] * ((1 - keep) * luma[j] + (i == j ? keep : 0)),
      0,
      0,
    ],
    0, 0, 0, alpha, 0,
  ];
}

/// Mảng màu nước giấy cũ (be nâu nhạt, không viền mực) đặt sau ảnh món chưa mở.
class _FadedPhoto extends StatelessWidget {
  const _FadedPhoto({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) => SLSurface(
        spec: SLSurfaceSpec(
          shape: large ? const SLCircle() : const SLRoundRect(10),
          material: SLMaterial.wash,
          color: const Color(0xFFE9D6BC),
          paper: const Color(0x00FFFFFF),
          outline: false,
          roughness: 2,
          seed: large ? 0xFAD1 : 0xFAD2,
        ),
      );
}

/// Tiêu đề mục trên trang sổ: chữ tiêu đề màu mực, gạch dạ quang hồng dâu run tay bên dưới.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _HighlighterPainter(slSeed(content: text)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text, style: SLTextStyles.of(context).title.copyWith(fontSize: 20)),
        ),
      );
}

class _HighlighterPainter extends CustomPainter {
  const _HighlighterPainter(this.seed);

  final int seed;

  /// Nét đã run tay theo (seed, cỡ) — dựng một lần.
  static final _cache = <(int, int, int), Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8) return;
    final path = _cache.putIfAbsent((seed, size.width.round(), size.height.round()), () {
      if (_cache.length > 16) _cache.clear();
      final y = size.height * 0.72;
      return wobblePath(Path()..moveTo(2, y)..lineTo(size.width - 2, y - 1.5), seed: seed, amplitude: 1.4, step: 8);
    });
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.36
        ..strokeCap = StrokeCap.round
        ..color = SLColors.strawberry.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_HighlighterPainter old) => old.seed != seed;
}

class _Ingredient extends StatelessWidget {
  const _Ingredient({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTextStyles.of(context).body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giấy sổ: dòng kẻ bút chì run tay, lề hồng nhạt, gáy lò xo bên trái (lỗ đục + vòng thép). Vẽ một lần theo kích
/// thước (Picture trong cache), các lần sau chỉ phát lại.
class _NotebookPainter extends CustomPainter {
  const _NotebookPainter();

  static final _cache = <(int, int), ui.Picture>{};

  static const _spine = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = (size.width.round(), size.height.round());
    var picture = _cache[key];
    if (picture == null) {
      if (_cache.length > 8) {
        for (final p in _cache.values) {
          p.dispose();
        }
        _cache.clear();
      }
      picture = _cache[key] = _build(size);
    }
    canvas.drawPicture(picture);
  }

  static ui.Picture _build(Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final w = size.width, h = size.height;
    // Dòng kẻ bút chì.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x33B9805A);
    var i = 0;
    for (var y = 44.0; y < h - 14; y += 30, i++) {
      c.drawPath(
        wobblePath(Path()..moveTo(_spine + 4, y)..lineTo(w - 14, y + 0.8), seed: 0x11E0 + i, amplitude: 0.9, step: 10),
        line,
      );
    }
    // Lề hồng.
    c.drawPath(
      wobblePath(Path()..moveTo(_spine + 8, 10)..lineTo(_spine + 9, h - 10), seed: 0x3A61, amplitude: 1, step: 10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x66F49AB0),
    );
    // Gáy: dải màu nước caramel nhạt (mép run, đọng màu ở mép) + lỗ đục run tay + vòng thép vẽ tay không khép.
    final band = wobblePath(
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, 6, _spine - 6, h - 12), const Radius.circular(5))),
      seed: 0x5B1E,
      amplitude: 1.3,
      step: 6,
    );
    c.drawPath(band, Paint()..color = const Color(0x1FB9805A));
    c.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x14B9805A),
    );
    final hole = Paint()..color = const Color(0xFFE9D7C0);
    final holeInk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = SLColors.inkSoft;
    Paint pen(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final ringInk = pen(SLColors.ink, 4.6);
    final ring = pen(const Color(0xFF9AA5AE), 2.6);
    final shine = pen(const Color(0xCCF4F7F9), 1.1);
    var k = 0;
    for (var y = 34.0; y < h - 20; y += 38, k++) {
      final rnd = SLRandom(SLRandom.mix(0x5B1F, k));
      final center = Offset(_spine * 0.6 + rnd.range(-0.8, 0.8), y + rnd.range(-1, 1));
      final r = rnd.range(4.0, 5.0);
      final holePath = wobblePath(
        Path()..addOval(Rect.fromCenter(center: center, width: r * 2 * rnd.range(0.95, 1.1), height: r * 2 * rnd.range(0.88, 1.02))),
        seed: rnd.nextInt32(),
        amplitude: 0.45,
        step: 2,
      );
      c.drawPath(holePath, hole);
      c.drawPath(holePath, holeInk);
      // Vòng thép: từ trong lỗ vòng ra ngoài gáy rồi quay lại, đầu cuối hở (không khép hẳn), run tay theo seed.
      final lift = rnd.range(11.5, 14);
      final arc = wobblePath(
        Path()
          ..moveTo(center.dx - 0.5, center.dy + 0.5)
          ..cubicTo(center.dx - 6, y - 2, -9 + rnd.range(-1, 1), y - lift * 0.35, -3 + rnd.range(-0.8, 0.8), y - lift)
          ..quadraticBezierTo(rnd.range(0.5, 2), y - lift - 2, rnd.range(3, 4.5), y - lift + 1),
        seed: rnd.nextInt32(),
        amplitude: 0.7,
        step: 3,
      );
      c.drawPath(arc, ringInk);
      c.drawPath(arc, ring);
      c.drawPath(extractFraction(arc, 0.32, 0.62).shift(const Offset(-0.6, -0.4)), shine);
    }
    return recorder.endRecording();
  }

  @override
  bool shouldRepaint(_NotebookPainter oldDelegate) => false;
}
