import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/art/shop_art.dart';
import '../../core/catalog.dart';
import '../../core/constants.dart' show kRefSize;
import '../../core/economy.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/services/iap_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/shop_scene.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';

/// Cửa hàng (giả lập): dải vải thông báo thử nghiệm dán băng dính, 6 thẻ giấy gói IAP, thẻ nhận gem qua quảng cáo.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  IapProductId? _buying;
  bool _watching = false;

  Future<void> _buy(IapProduct product) async {
    if (_buying != null) return;
    final l = AppLocalizations.of(context);
    final services = AppScope.read(context);
    final ok = await showConfirmDialog(
      context,
      title: l.storeConfirmTitle,
      body: l.storeConfirmBody(l.iapName(product.id), product.displayPrice),
      confirmLabel: l.commonBuy,
      titleColor: SLColors.butter,
      illustration: SizedBox(width: 120, height: 96, child: _ProductArt(id: product.id)),
    );
    if (!ok || !mounted) return;
    setState(() => _buying = product.id);
    final bought = await services.iap.buy(product.id);
    if (!mounted) return;
    setState(() => _buying = null);
    if (bought) {
      services.audio.success();
      showToast(context, l.storePurchaseSuccess);
    }
  }

  Future<void> _watchForGem() async {
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    if (_watching) return;
    if (!services.ads.canShowRewarded()) {
      showToast(context, l.adsLimitReached, success: false);
      return;
    }
    setState(() => _watching = true);
    final watched = await services.ads.showRewarded(context, AdPlacement.freeGem);
    if (!mounted) return;
    setState(() => _watching = false);
    if (watched) {
      services.state.addGems(Economy.freeGemPerAd);
      services.audio.success();
      showToast(context, l.adRewardGranted);
    } else {
      showToast(context, l.adsLimitReached, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final products = services.iap.products;
    return SugarScreen(
      title: l.storeTitle,
      titleIconId: 'shop_bag',
      body: Stack(
        children: [
          // Băng thông báo giả lập — luôn hiện: dải vải vàng bơ dán băng dính hai đầu.
          Positioned(
            left: 34,
            right: 34,
            top: 10,
            height: 52,
            child: _NoticeBand(text: l.storeSimulatedNotice),
          ),
          Positioned(
            left: 24,
            top: 80,
            width: 900,
            bottom: 24,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 289 / 254,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final p in products)
                  _ProductCard(
                    product: p,
                    owned: services.iap.isOwned(p.id),
                    busy: _buying == p.id,
                    onBuy: _buying == null ? () => _buy(p) : null,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 944,
            right: 24,
            top: 80,
            bottom: 24,
            child: _FreeGemCard(canWatch: services.ads.canShowRewarded(), busy: _watching, onWatch: _watchForGem),
          ),
        ],
      ),
    );
  }
}

String _productDesc(AppLocalizations l, IapProductId id) => switch (id) {
  IapProductId.starterPack => l.storeStarterPackDesc(Catalog.iapCoins[id] ?? 0, Catalog.iapGems[id] ?? 0),
  IapProductId.pantryS || IapProductId.pantryM || IapProductId.pantryL => l.storePantryDesc(Catalog.iapCoins[id] ?? 0),
  IapProductId.decorSetSeaside => l.storeDecorSetDesc,
  IapProductId.removeAds => l.storeRemoveAdsDesc,
};

/// Dải vải thông báo (chỉ khâu dọc mép) dán hai mẩu băng dính ở hai đầu.
class _NoticeBand extends StatelessWidget {
  const _NoticeBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SLSurface(
              spec: const SLSurfaceSpec(
                shape: SLRoundRect(8),
                material: SLMaterial.fabric,
                color: SLColors.butterLight,
                seed: 0x5707,
              ),
              lift: 3,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  const SLIcon('info', size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTextStyles.of(context).label.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(left: -18, top: 14, child: SLTapeStrip(angle: -1.2, width: 50, height: 20, seed: 0x5708)),
          const Positioned(
            right: -18,
            top: 14,
            child: SLTapeStrip(angle: 1.2, width: 50, height: 20, seed: 0x5709, color: Color(0xB3A8DCC8)),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.owned, required this.busy, required this.onBuy});

  final IapProduct product;
  final bool owned;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final best = product.id == IapProductId.starterPack;
    final seed = 0x5700 + product.id.index * 13;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SLPaperCard(
            color: owned ? SLColors.paperShade : SLColors.paper,
            radius: 20,
            seed: seed,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                SizedBox(width: 130, height: 84, child: _ProductArt(id: product.id)),
                Text(
                  l.iapName(product.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.title.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(
                    _productDesc(l, product.id),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
                  ),
                ),
                Row(
                  children: [
                    // Nhãn giá: mẩu giấy vàng bơ viền mực.
                    SizedBox(
                      height: 48,
                      child: SLSurface(
                        spec: SLSurfaceSpec(
                          shape: const SLRoundRect(12),
                          material: SLMaterial.wash,
                          color: SLColors.butterLight,
                          inkWidth: 2,
                          seed: seed + 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          widthFactor: 1,
                          child: Text(product.displayPrice, style: styles.number.copyWith(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      // Đang mua: ba chấm mực nhảy trong nút (chặn bấm).
                      child: SLButton(
                        label: owned ? l.storeOwned : l.commonBuy,
                        icon: owned ? 'check' : null,
                        color: SLColors.strawberry,
                        height: 48,
                        fontSize: 18,
                        loading: busy,
                        onPressed: owned ? null : (busy ? () {} : onBuy),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (best && !owned) ...[
          const Positioned(top: -10, right: -8, child: StarIcon(size: 42)),
          const Positioned(top: -16, right: 26, child: SLSparkle(size: 20)),
        ],
      ],
    );
  }
}

class _FreeGemCard extends StatelessWidget {
  const _FreeGemCard({required this.canWatch, required this.busy, required this.onWatch});

  final bool canWatch;
  final bool busy;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return SLPanel(
      color: SLColors.mintLight,
      radius: 26,
      seed: 0x6E31,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox.square(
            dimension: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: SLSurface(
                    spec: SLSurfaceSpec(
                      shape: SLCircle(),
                      material: SLMaterial.wash,
                      color: Color(0xFFDDF1F6),
                      sticker: true,
                      inkWidth: SLMetrics.inkWidth + 0.4,
                      seed: 0x6E32,
                    ),
                    lift: 4,
                  ),
                ),
                // Vệt màu nước loang trong lòng đĩa (lệch tâm, không viền mực) dưới viên kim cương.
                const Positioned(
                  left: 26,
                  top: 22,
                  right: 20,
                  bottom: 26,
                  child: SLSurface(
                    spec: SLSurfaceSpec(
                      shape: SLCircle(),
                      material: SLMaterial.wash,
                      color: Color(0xFFBFE3EC),
                      paper: Color(0x00FFFFFF),
                      outline: false,
                      roughness: 2,
                      seed: 0x6E33,
                    ),
                  ),
                ),
                const Positioned.fill(child: Center(child: GemIcon(size: 96))),
                Positioned(right: 4, top: -4, child: SLSparkle(size: 30, trigger: canWatch)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l.storeFreeGem(Economy.freeGemPerAd),
            textAlign: TextAlign.center,
            style: styles.title.copyWith(fontSize: 22),
          ),
          const Spacer(),
          if (!canWatch) ...[
            Text(
              l.adsLimitReached,
              textAlign: TextAlign.center,
              style: styles.body.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: SLColors.badDeep),
            ),
            const SizedBox(height: 8),
          ],
          SLButton(
            label: l.commonWatchAd,
            icon: 'play_video',
            color: SLColors.mint,
            height: 60,
            loading: busy,
            onPressed: canWatch ? onWatch : null,
          ),
        ],
      ),
    );
  }
}

/// Hình minh hoạ từng gói: ảnh vẽ tay (hộp quà, bao nguyên liệu, xu, gem, cảnh tiệm bộ biển, huy hiệu xoá quảng
/// cáo); chưa có ảnh → hình code.
class _ProductArt extends StatelessWidget {
  const _ProductArt({required this.id});

  final IapProductId id;

  @override
  Widget build(BuildContext context) {
    if (id == IapProductId.removeAds) {
      // Huy hiệu nhãn dán vẽ tay; chưa nạp xong / thiếu ảnh → đĩa màu nước + icon vẽ code.
      return ListenableBuilder(
        listenable: ArtSprites.changes,
        builder: (context, _) => Center(
          child: _noAdsBadge.image == null
              ? const SLIconDisc('no_ads', size: 78, color: SLColors.strawberryLight, iconScale: 0.7, seed: 0x5AD5)
              : const ArtImage(_noAdsBadge, size: 96),
        ),
      );
    }
    final art = ArtCanvas(repaintKey: id, repaint: ArtSprites.changes, paint: (c, s) => _paint(c, s));
    if (id != IapProductId.decorSetSeaside) return art;
    // Bộ trang trí: ảnh polaroid giấy dán nghiêng, ảnh cắt theo khung run tay.
    return Center(
      child: AspectRatio(
        aspectRatio: 1.25,
        child: SLPaperCard(
          tilt: -0.035,
          radius: 5,
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 13),
          seed: 0x5EA5,
          child: SLHandClip(shape: const SLRoundRect(3), seed: 0x5EA6, amplitude: 0.8, child: art),
        ),
      ),
    );
  }

  static const _noAdsBadge = ArtRef(ArtGroup.items, 'no_ads_badge');
  static const _pantrySack = ArtRef(ArtGroup.items, 'pantry_sack');

  /// Bao nguyên liệu: ảnh vẽ tay ([flip] = lật ngang cho bao xếp bên trái); chưa có ảnh → bao vẽ code.
  static void _sack(Canvas canvas, Rect r, {required int seed, bool patch = true, bool flip = false}) {
    final image = _pantrySack.image;
    if (image == null) {
      paintSLSack(canvas, r, seed: seed, patch: patch);
    } else {
      paintArt(canvas, r, image, flipHorizontally: flip);
    }
  }

  static void _coin(Canvas canvas, Rect r) {
    if (!paintArtRef(canvas, r, ArtSprites.coin)) ItemArt.coin(canvas, r);
  }

  static void _gem(Canvas canvas, Rect r) {
    if (!paintArtRef(canvas, r, ArtSprites.gem)) ItemArt.gem(canvas, r);
  }

  void _paint(Canvas canvas, Size size) {
    final h = size.height;
    final center = size.center(Offset.zero);
    Rect sq(Offset c, double side) => Rect.fromCenter(center: c, width: side, height: side);
    switch (id) {
      case IapProductId.starterPack:
        final box = sq(center, h);
        if (!paintArtRef(canvas, box, ArtSprites.box(BoxType.gift))) ItemArt.paintBox(canvas, box, BoxType.gift);
        _coin(canvas, sq(center.translate(-h * 0.5, h * 0.2), h * 0.5));
        _gem(canvas, sq(center.translate(h * 0.5, h * 0.2), h * 0.5));
      case IapProductId.pantryS:
      case IapProductId.pantryM:
      case IapProductId.pantryL:
        final n = switch (id) {
          IapProductId.pantryS => 2,
          IapProductId.pantryM => 4,
          _ => 6,
        };
        // Gói to dần: bao chính lớn hơn, thêm bao nhỏ xếp sau (M: 1, L: 2).
        final (main, extra) = switch (id) {
          IapProductId.pantryS => (0.78, 0),
          IapProductId.pantryM => (0.88, 1),
          _ => (0.98, 2),
        };
        final seed = 0x5AC0 + id.index * 7;
        if (extra >= 1) _sack(canvas, sq(center.translate(h * 0.5, -h * 0.02), h * 0.6), seed: seed + 1, patch: false);
        if (extra >= 2) _sack(canvas, sq(center.translate(-h * 0.5, 0), h * 0.56), seed: seed + 2, patch: false, flip: true);
        _sack(canvas, sq(center.translate(0, -h * 0.06 + (1 - main) * h * 0.3), h * main), seed: seed);
        for (var i = 0; i < n; i++) {
          final row = i ~/ 3;
          final col = i % 3;
          final x = center.dx + (col - 1) * h * 0.32 + (row.isOdd ? h * 0.16 : 0);
          final y = center.dy + h * 0.3 - row * h * 0.18;
          _coin(canvas, sq(Offset(x, y), h * 0.36));
        }
      case IapProductId.decorSetSeaside:
        const set = {
          DecorSlot.wallpaper: DecorId.wallpaperFloral,
          DecorSlot.window: DecorId.windowSeaView,
          DecorSlot.plant: DecorId.plantLemonTree,
        };
        if (ShopScene.usesArt(set)) {
          _paintSeasideArt(canvas, size, set);
          return;
        }
        // Cắt cảnh tiệm quanh cửa sổ hướng biển, giấy hoa nhí, cây chanh (phủ kín ô ảnh polaroid).
        const focus = Rect.fromLTWH(720, 40, 440, 352);
        final scale = math.max(size.width / focus.width, size.height / focus.height);
        canvas.save();
        canvas.translate((size.width - focus.width * scale) / 2, (size.height - focus.height * scale) / 2);
        canvas.scale(scale);
        canvas.translate(-focus.left, -focus.top);
        ShopArt.paint(canvas, kRefSize, set);
        canvas.restore();
      case IapProductId.removeAds:
        break;
    }
  }

  /// Ảnh vẽ tay: cảnh tiệm cắt quanh cửa sổ hướng biển trên tường hoa nhí (phủ kín ô ảnh), cây chanh ở góc phải.
  static void _paintSeasideArt(Canvas canvas, Size size, Map<DecorSlot, DecorId?> set) {
    const focus = Rect.fromLTWH(372, 96, 310, 242);
    final scale = math.max(size.width / focus.width, size.height / focus.height);
    canvas.save();
    canvas.translate((size.width - focus.width * scale) / 2, (size.height - focus.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-focus.left, -focus.top);
    ShopScene.paintRef(canvas, {...set, DecorSlot.plant: null});
    canvas.restore();
    final h = size.height;
    final tree = Rect.fromLTWH(size.width - h * 0.66, h * 0.3, h * 0.72, h * 0.72);
    paintArtRef(canvas, tree, ArtSprites.decor(DecorId.plantLemonTree));
  }
}
