import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/catalog.dart';
import '../../core/game_state.dart';
import '../../core/models/ids.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/navigation.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';
import 'login_gift_dialog.dart';
import 'quests_dialog.dart';

/// Menu chính: cảnh phố trước tiệm (vẽ tay; chưa có ảnh → cảnh tiệm với decor đang đặt), Mai bên trái, các nút
/// bên phải.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  /// Hộp quà đăng nhập chỉ tự mở 1 lần mỗi phiên chạy app.
  static bool giftShownThisSession = false;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  /// Đang mở một màn con: chặn bấm đúp push hai màn chồng nhau.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    menuReturns.addListener(_onMenuReturn);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());
  }

  @override
  void dispose() {
    menuReturns.removeListener(_onMenuReturn);
    super.dispose();
  }

  /// `goToMenu` đưa menu trở lại trên cùng (vd. từ tổng kết ngày).
  void _onMenuReturn() => WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());

  /// Vào (hoặc quay lại) menu: làm mới ngày lịch; tự mở quà nếu có và chưa mở trong phiên.
  void _onEnter() {
    if (!mounted) return;
    final state = AppScope.read(context).state;
    state.refreshDaily();
    // Nạp sẵn (không chặn) cảnh tiệm + đồ trang trí đang đặt (và giấy dán tường — nền chờ của màn ngày) để bấm
    // "Mở cửa tiệm" là có ảnh ngay.
    unawaited(ArtSprites.preload([WallpaperBackdrop.tile]));
    unawaited(ArtSprites.preloadDay(equippedDecor: state.equippedDecor));
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop && state.pendingLoginReward != null && !MainMenuScreen.giftShownThisSession) {
      MainMenuScreen.giftShownThisSession = true;
      showLoginGiftDialog(context);
    }
  }

  Future<void> _open(String route) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.of(context).pushNamed(route);
    } finally {
      _navigating = false;
    }
    // Màn ngày bị thay bằng tổng kết thì future xong khi menu chưa ở trên cùng → để `_onMenuReturn` lo.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _onEnter();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context).state;
    final questReady = state.quests.any((q) => !q.claimed && q.progress >= Catalog.quest(q.type).target);

    // Khung không Material: nền kem + cảnh phố; chữ mặc định lấy từ SLScope (mực nâu, font nội dung).
    return ColoredBox(
      color: SLColors.cream,
      child: SLScope(
        child: Stack(
          children: [
            Positioned.fill(
              child: SceneBackdrop(scene: ArtScene.menu, fallback: ShopBackdrop(equipped: state.equippedDecor)),
            ),
            // Biển tên tiệm: đặt đè lên biển hiệu vẽ sẵn trong cảnh phố (x 320–660, y 180–255) để chỉ thấy tên app.
            Positioned(
              left: 40,
              top: 160,
              width: 600,
              child: _TitleSign(title: l.appTitle, tagline: l.menuTagline),
            ),
            // Mai (nửa người) nhô lên từ mép dưới màn hình, đứng trước cửa tiệm.
            const Positioned(
              left: 110,
              top: 316,
              child: SpeakerImage(speaker: Speaker.mai, width: 390, height: 520, clipBottom: 116),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 2,
              height: 72,
              child: _TopBar(state: state, onSettings: () => _open(AppRoutes.settings)),
            ),
            Positioned(
              left: 836,
              top: 92,
              width: 412,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SLButton(
                    label: l.menuPlay,
                    subtitle: l.menuDayLabel(state.dayNumber),
                    icon: 'storefront',
                    color: SLColors.strawberry,
                    height: 116,
                    fontSize: 32,
                    radius: 28,
                    onPressed: () => _open(AppRoutes.day),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SLButton(
                          label: l.menuRecipeBook,
                          leading: const SLArtIcon(ArtSprites.book, 'book', size: 32),
                          color: SLColors.butter,
                          height: 84,
                          fontSize: 21,
                          onPressed: () => _open(AppRoutes.recipes),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SLButton(
                          label: l.menuUpgrades,
                          leading: SLArtIcon(ArtSprites.oven(1), 'oven', size: 32),
                          color: SLColors.mint,
                          height: 84,
                          fontSize: 21,
                          onPressed: () => _open(AppRoutes.upgrades),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SLButton(
                          label: l.menuDecor,
                          icon: 'decor_chair',
                          color: SLColors.strawberryLight,
                          height: 84,
                          fontSize: 21,
                          onPressed: () => _open(AppRoutes.decor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SLButton(
                          label: l.menuStore,
                          icon: 'shop_bag',
                          color: SLColors.butterLight,
                          height: 84,
                          fontSize: 21,
                          onPressed: () => _open(AppRoutes.store),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StickerLabelButton(
                          icon: const SLIcon('quest_board', size: 34),
                          label: l.menuQuests,
                          badge: questReady,
                          color: SLColors.mint,
                          seed: 0x9E57,
                          onPressed: () => showQuestsDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StickerLabelButton(
                          icon: const SLArtIcon(ArtSprites.giftDaily, 'gift', size: 36),
                          label: l.menuLoginGift,
                          badge: state.pendingLoginReward != null,
                          color: SLColors.strawberry,
                          seed: 0x61F7,
                          onPressed: () => showLoginGiftDialog(context),
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

/// Biển tên tiệm: khung gỗ lòng giấy, huy hiệu lá vẽ tay + tên app (font tiêu đề) + khẩu hiệu.
class _TitleSign extends StatelessWidget {
  const _TitleSign({required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return SLPanel(
      style: SLPanelStyle.wood,
      color: SLColors.cream,
      radius: 26,
      seed: 0x5164,
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 10),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 66,
            child: SLSurface(
              spec: SLSurfaceSpec(shape: SLCircle(), material: SLMaterial.wash, color: SLColors.mint, sticker: true, seed: 0x1EAF),
              lift: 2.5,
              child: Center(child: SLIcon('leaf_logo', size: 44)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title, maxLines: 1, style: styles.heading.copyWith(fontSize: 42, height: 1.15)),
                ),
                Text(
                  tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh trên: nhãn giấy dán (cấp tiệm + XP), nhãn xu/gem, nút cài đặt tròn — nổi trên cảnh, không có dải nền.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onSettings});

  final GameState state;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLTopBar(
      leading: _LevelTag(state: state),
      children: [
        const CurrencyBar(),
        const SizedBox(width: 4),
        SLButton.icon(icon: 'settings', tooltip: l.menuSettings, size: 54, onPressed: onSettings),
      ],
    );
  }
}

/// Nhãn giấy dán cấp tiệm: huy hiệu tròn màu nước vàng bơ mang số cấp + chữ "Tiệm cấp N" + ống XP.
class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.state});

  final GameState state;

  static const _seed = 0x1E7E;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final maxed = state.xpForNextLevel == 0;
    final card = SLSurface(
      spec: const SLSurfaceSpec(shape: SLRoundRect(12), sticker: true, inkWidth: SLMetrics.inkWidth - 0.2, seed: _seed),
      lift: 3,
      padding: const EdgeInsets.fromLTRB(6, 4, 16, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 46,
            child: SLSurface(
              spec: const SLSurfaceSpec(shape: SLCircle(), material: SLMaterial.wash, color: SLColors.butter, seed: _seed + 1),
              child: Center(
                child: Text('${state.level}', style: styles.number.copyWith(fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.menuShopLevel(state.level), maxLines: 1, style: styles.label.copyWith(fontSize: 16, height: 1.15)),
              const SizedBox(height: 3),
              SLProgressBar(
                width: 240,
                height: 20,
                color: SLColors.butter,
                value: maxed ? 1 : state.xpIntoLevel / state.xpForNextLevel,
                label: maxed ? l.menuXpMax : l.menuXpProgress(state.xpIntoLevel, state.xpForNextLevel),
                seed: _seed + 2,
              ),
            ],
          ),
        ],
      ),
    );
    return RepaintBoundary(
      child: Transform.rotate(
        angle: -0.012,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            const Positioned(left: -8, top: -6, child: SLTapeStrip(angle: -0.6, width: 30, height: 13, seed: _seed)),
          ],
        ),
      ),
    );
  }
}

/// Nhãn dán giấy hình viên thuốc bấm được (nhiệm vụ, quà): đĩa màu nước mang icon + chữ; nhấn lún cả nhãn.
/// [badge] = chấm báo có việc chờ.
class _StickerLabelButton extends StatelessWidget {
  const _StickerLabelButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    required this.seed,
    this.badge = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final int seed;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    final disc = SizedBox.square(
      dimension: 56,
      child: SLSurface(
        spec: SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: color, seed: seed + 1),
        child: Center(child: icon),
      ),
    );
    return RepaintBoundary(
      child: SizedBox(
        height: 72,
        child: SLPressable(
          onPressed: onPressed,
          builder: (context, press) => SLSurface(
            spec: SLSurfaceSpec(shape: const SLRoundRect(36), sticker: true, seed: seed),
            lift: SLMetrics.buttonLift,
            press: press,
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [disc, if (badge) const Positioned(right: -4, top: -2, child: SLBadge.dot())],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.label.copyWith(fontSize: 18, height: 1.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
