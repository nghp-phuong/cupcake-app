import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/catalog.dart';
import '../../core/economy.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/models/recipe.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/panel.dart';
import '../common/star_row.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';

/// Sổ công thức của bà: lưới 10 món (5×2) — mỗi món là ô giấy có ảnh bánh dán băng dính, món khoá là "trang còn
/// thiếu"; bên phải trang sổ chi tiết (giấy kẻ bút chì, gáy lò xo).
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
              child: GridView.count(
                crossAxisCount: 5,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.53,
                clipBehavior: Clip.none,
                physics: const NeverScrollableScrollPhysics(),
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
            ),
          ),
        ],
      ),
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = SLTheme.of(context);
    final styles = SLTextStyles.of(context);
    final seed = 0x2EC0 + recipe.id.index * 13;
    final cake = CakeImage(visual: CakeVisual.recipe(recipe.id), recipe: recipe.id, size: 100);
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
                        child: SLIconDisc('lock', size: 44, iconScale: 0.62, lift: 2, seed: seed + 5),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: -9,
          child: Center(child: SLTapeStrip(width: 46, height: 16, angle: (recipe.id.index.isEven ? -1 : 1) * 0.06, seed: seed)),
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
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Column(
                  children: [
                    SizedBox(height: 116, child: photo),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        unlocked ? l.recipeName(recipe.id) : l.recipesMissingPage(recipe.unlockLevel),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: styles.label.copyWith(
                          fontSize: unlocked ? 17 : 14,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? theme.ink : theme.inkSoft,
                        ),
                      ),
                    ),
                    if (unlocked) StarRow(stars: mastery, max: 3, size: 26),
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

/// Trang sổ chi tiết: hình, tên, mô tả, giá, nguyên liệu, thành thạo — trên giấy kẻ bút chì có gáy lò xo.
class _RecipePage extends StatelessWidget {
  const _RecipePage({required this.recipe, required this.unlocked, required this.mastery});

  final Recipe recipe;
  final bool unlocked;
  final int mastery;

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
                          CakeImage(visual: CakeVisual.recipe(recipe.id), recipe: recipe.id, size: 120),
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
                                      l.recipesPrice(recipe.price),
                                      style: styles.body.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: styles.body.copyWith(fontSize: 17, fontStyle: FontStyle.italic, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      _Heading(l.recipesIngredients),
                      const SizedBox(height: 4),
                      _Ingredient(icon: MouldImage(recipe.mould, size: 30), text: l.mouldName(recipe.mould)),
                      _Ingredient(icon: BatterSwatch(recipe.batter, size: 26), text: l.batterName(recipe.batter)),
                      _Ingredient(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final f in recipe.frostings) FrostingSwatch(f, size: 26)],
                        ),
                        text: recipe.frostings.map(l.frostingName).join(', '),
                      ),
                      _Ingredient(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final t in recipe.toppings) ToppingImage(t, size: 26)],
                        ),
                        text: recipe.toppings.map(l.toppingName).join(', '),
                      ),
                      const Spacer(),
                      _Heading(l.recipesMastery),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StarRow(stars: mastery, max: 3, size: 40, spacing: 6),
                          const SizedBox(width: 12),
                          if (mastery >= 3)
                            Flexible(
                              child: SLBounceIn(
                                child: TagChip(
                                  l.recipesMasteryReward(Economy.masteryGemReward),
                                  color: SLColors.butter,
                                  iconId: 'trophy',
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.recipesMasteryHint,
                        style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: theme.inkSoft),
                      ),
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
                          l.recipesMissingPage(recipe.unlockLevel),
                          textAlign: TextAlign.center,
                          style: styles.heading.copyWith(fontSize: 24, color: theme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
