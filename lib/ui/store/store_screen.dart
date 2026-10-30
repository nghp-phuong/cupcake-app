import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/art/shop_art.dart';
import '../../core/constants.dart' show kRefSize;
import '../../core/economy.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/monetization/monetization_config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/shop_scene.dart';
import '../common/staff_portrait.dart';
import '../common/sugar_screen.dart';
import '../level/level_common.dart';
import '../sugarleaf/sugarleaf.dart';

/// Cửa hàng V2 (giả lập): con dấu "Chế độ thử" + dải vải thông báo thử nghiệm dán băng dính; thẻ giấy các gói IAP
/// V2 (kim cương S/M/L, thẻ mùa, trang phục lễ hội, bỏ quảng cáo; gói khởi đầu nổi bật đứng đầu từ L4 tới khi mua);
/// thẻ nhận kim cương qua quảng cáo. Gói xu V1 và bộ trang trí Seaside ẩn (`IapCatalog.hidden`, vẫn giữ quyền sở hữu).
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
      body: l.storeConfirmBody(_productName(context, l, product), product.displayPrice),
      confirmLabel: l.commonBuy,
      titleColor: SLColors.butter,
      illustration: SizedBox(width: 120, height: 96, child: _ProductArt(product: product)),
    );
    if (!ok || !mounted) return;
    setState(() => _buying = product.id);
    final bought = await services.iap.buy(product.id);
    if (!mounted) return;
    setState(() => _buying = null);
    if (bought) {
      services.audio.success();
      showToast(context, l.storePurchaseSuccess);
    } else {
      services.audio.fail();
      showToast(context, l.storePurchaseFailed, success: false);
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
    final products = [
      for (final p in services.iap.products)
        if (_shown(p, services)) p,
    ]..sort((a, b) => _order(a.id).compareTo(_order(b.id)));
    return SugarScreen(
      title: l.storeTitle,
      titleIconId: 'shop_bag',
      body: Stack(
        children: [
          // Băng thông báo giả lập — luôn hiện: con dấu "Chế độ thử" + dải vải vàng bơ dán băng dính hai đầu.
          Positioned(left: 210, right: 34, top: 10, height: 52, child: _NoticeBand(text: l.storeSimulatedNotice)),
          Positioned(left: 24, top: 6, child: _TestModeStamp(label: l.storeTestMode)),
          Positioned(
            left: 24,
            top: 80,
            width: 900,
            bottom: 24,
            child: LayoutBuilder(
              builder: (context, box) {
                // 7 gói (có gói khởi đầu) → 4 cột; ≤ 6 gói → 3 cột; luôn 2 hàng vừa khung.
                final cols = products.length > 6 ? 4 : 3;
                const gap = 16.0;
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                final h = (box.maxHeight - gap) / 2;
                return GridView.count(
                  crossAxisCount: cols,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: w / h,
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: [
                    for (final p in products)
                      _ProductCard(
                        key: ValueKey('store-product-${p.id.name}'),
                        product: p,
                        owned: _owned(p, services),
                        available: services.state.canBuyIap(p.id),
                        featured: p.id == IapProductId.starterPack,
                        busy: _buying == p.id,
                        onBuy: _buying == null ? () => _buy(p) : null,
                      ),
                  ],
                );
              },
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

/// Gói có hiện ở cửa hàng V2: bỏ gói V1 ẩn; gói khởi đầu chỉ từ L4 (đã qua L3) tới khi mua.
bool _shown(IapProduct p, AppServices services) {
  if (IapCatalog.hidden.contains(p.id)) return false;
  if (p.id == IapProductId.starterPack) return services.state.starterPackFeatured;
  return true;
}

/// Đã sở hữu: gói một lần → `isOwned`; thẻ mùa → đã mở cao cấp mùa này.
bool _owned(IapProduct p, AppServices services) =>
    p.id == IapProductId.seasonPass ? services.state.seasonPremium : services.iap.isOwned(p.id);

/// Thứ tự hiện: gói khởi đầu (nổi bật) → kim cương S/M/L → thẻ mùa → trang phục → bỏ quảng cáo.
int _order(IapProductId id) => switch (id) {
  IapProductId.starterPack => 0,
  IapProductId.gemsS => 1,
  IapProductId.gemsM => 2,
  IapProductId.gemsL => 3,
  IapProductId.seasonPass => 4,
  IapProductId.staffOutfits => 5,
  IapProductId.removeAds => 6,
  _ => 9,
};

String _productName(BuildContext context, AppLocalizations l, IapProduct p) {
  final name = p.name(levelLang(context));
  return name.isNotEmpty ? name : l.iapName(p.id, fallback: l.storeTitle);
}

String _productDesc(BuildContext context, AppLocalizations l, IapProduct p) {
  final desc = p.desc(levelLang(context));
  if (desc.isNotEmpty) return desc;
  final r = p.reward;
  final perBooster = r.boosters.values.fold<int>(0, (a, b) => a > b ? a : b);
  return switch (p.id) {
    IapProductId.starterPack => l.storeStarterPackDescV2(r.coins, r.gems, perBooster),
    IapProductId.gemsS || IapProductId.gemsM || IapProductId.gemsL => l.storeGemsDesc(r.gems),
    IapProductId.removeAds => l.storeRemoveAdsDescV2,
    IapProductId.staffOutfits => l.storeStaffOutfitsDesc,
    IapProductId.seasonPass => l.storeSeasonPassDesc,
    IapProductId.pantryS || IapProductId.pantryM || IapProductId.pantryL => l.storePantryDesc(r.coins),
    IapProductId.decorSetSeaside => l.storeDecorSetDesc,
  };
}

/// Con dấu "Chế độ thử": nhãn dán hồng dâu nghiêng nhẹ, luôn hiện ở góc trên trái cửa hàng.
class _TestModeStamp extends StatelessWidget {
  const _TestModeStamp({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.05,
    child: SizedBox(
      key: const ValueKey('store-test-mode'),
      width: 170,
      height: 60,
      child: SLSurface(
        spec: const SLSurfaceSpec(
          shape: SLRoundRect(14),
          material: SLMaterial.wash,
          color: SLColors.strawberryLight,
          sticker: true,
          inkWidth: 2.4,
          seed: 0x57E5,
        ),
        lift: 3,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SLIcon('warning', size: 26),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: SLTextStyles.of(context).label.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
  const _ProductCard({
    super.key,
    required this.product,
    required this.owned,
    this.available = true,
    required this.busy,
    required this.onBuy,
    this.featured = false,
  });

  final IapProduct product;
  final bool owned;

  /// Mua được lúc này (`GameState.canBuyIap`); false và chưa sở hữu → thẻ mờ, nút khoá (thẻ mùa: "Chưa có mùa mới").
  final bool available;
  final bool busy;
  final VoidCallback? onBuy;

  /// Gói khởi đầu: giấy hồng dâu nhạt + nhãn "Ưu đãi nhất" + sao lấp lánh.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final best = featured;
    final seed = 0x5700 + product.id.index * 13;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: SLPaperCard(
            color: owned || !available ? SLColors.paperShade : (best ? SLColors.strawberryLight : SLColors.paper),
            radius: 20,
            seed: seed,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                SizedBox(width: 130, height: 78, child: _ProductArt(product: product)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _productName(context, l, product),
                    maxLines: 1,
                    style: styles.title.copyWith(fontSize: 21),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _FitDesc(
                    !owned && !available && product.id == IapProductId.seasonPass
                        ? l.storeSeasonNone
                        : _productDesc(context, l, product),
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
                        icon: owned ? 'check' : (available ? null : 'lock'),
                        color: SLColors.strawberry,
                        height: 48,
                        fontSize: 18,
                        loading: busy,
                        onPressed: owned || !available ? null : (busy ? () {} : onBuy),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (best && !owned) ...[
          Positioned(
            top: -14,
            left: -6,
            child: SLBadge.label(
              l.storeStarterBadge,
              key: const ValueKey('store-starter-badge'),
              color: SLColors.strawberry,
              sparkle: true,
            ),
          ),
          const Positioned(top: -10, right: -8, child: StarIcon(size: 42)),
          const Positioned(top: -16, right: 26, child: SLSparkle(size: 20)),
        ],
      ],
    );
  }
}

/// Mô tả gói: chữ giữa lấp vùng còn lại của thẻ; dài quá thì co cỡ chữ dần (15 → 11.5) cho đủ đọc thay vì cắt "…".
class _FitDesc extends StatelessWidget {
  const _FitDesc(this.text, {required this.style});

  final String text;
  final TextStyle style;

  static const _minFontSize = 11.5;
  static const _lineHeight = 1.15;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style).copyWith(height: _lineHeight);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        var size = base.fontSize ?? 15;
        if (box.maxWidth.isFinite && box.maxHeight.isFinite) {
          while (size > _minFontSize) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: base.copyWith(fontSize: size),
              ),
              textAlign: TextAlign.center,
              textDirection: direction,
              textScaler: scaler,
            )..layout(maxWidth: box.maxWidth);
            final fits = painter.height <= box.maxHeight;
            painter.dispose();
            if (fits) break;
            size = (size - 0.5).clamp(_minFontSize, size);
          }
        }
        final lines = box.maxHeight.isFinite
            ? (box.maxHeight / scaler.scale(size * _lineHeight)).floor().clamp(1, 8)
            : null;
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(fontSize: size),
        );
      },
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
  const _ProductArt({required this.product});

  final IapProduct product;

  IapProductId get id => product.id;

  @override
  Widget build(BuildContext context) {
    // Gói V2 có ảnh riêng (`items/gem_pouch`, `items/season_ticket`…): ảnh đóng gói, thiếu → hình code bên dưới.
    final path = product.artPath;
    if (path != null && id != IapProductId.removeAds) {
      return AssetArt(path, width: 130, height: 78, fallback: _fallback());
    }
    return _fallback();
  }

  Widget _fallback() {
    switch (id) {
      case IapProductId.staffOutfits:
        // Chưa có ảnh riêng của gói: chân dung tròn Nora + Bảo mặc trang phục lễ hội (ảnh `_fest`); co theo ô
        // (thẻ gói / minh hoạ hộp xác nhận mua).
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in const ['staff_nora_fest', 'staff_bao_fest'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SizedBox.square(
                    dimension: 60,
                    child: SLSurface(
                      spec: SLSurfaceSpec(
                        shape: const SLCircle(),
                        material: SLMaterial.wash,
                        color: SLColors.strawberryLight,
                        inkWidth: 1.8,
                        seed: slSeed(content: c, salt: 0x5AD7),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: SLHandClip(
                        seed: slSeed(content: c, salt: 0x5AD8),
                        child: StaffPortrait(character: c, width: 54, height: 54, shown: 0.3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      case IapProductId.seasonPass:
        return const Center(child: SLArtIcon(ArtSprites.ticket, 'ticket', size: 84));
      default:
        break;
    }
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
        if (extra >= 2) {
          _sack(canvas, sq(center.translate(-h * 0.5, 0), h * 0.56), seed: seed + 2, patch: false, flip: true);
        }
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
      case IapProductId.gemsS:
      case IapProductId.gemsM:
      case IapProductId.gemsL:
        // Đống kim cương to dần (S: 1, M: 3, L: 5 viên).
        final n = switch (id) {
          IapProductId.gemsS => 1,
          IapProductId.gemsM => 3,
          _ => 5,
        };
        const spots = [Offset(0, 0), Offset(-0.42, 0.14), Offset(0.42, 0.14), Offset(-0.22, -0.2), Offset(0.22, -0.2)];
        for (var i = n - 1; i >= 0; i--) {
          final o = spots[i];
          _gem(canvas, sq(center.translate(o.dx * h, o.dy * h), h * (i == 0 ? 0.7 : 0.5)));
        }
      case IapProductId.removeAds:
      case IapProductId.staffOutfits:
      case IapProductId.seasonPass:
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
