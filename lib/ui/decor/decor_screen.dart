import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/shop_art.dart';
import '../../core/catalog.dart';
import '../../core/constants.dart';
import '../../core/game_state.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/decor.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/panel.dart';
import '../common/shop_scene.dart';
import '../common/sugar_button.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';

/// Id icon vẽ tay của từng ô trang trí.
String _slotIcon(DecorSlot s) => switch (s) {
  DecorSlot.wallpaper => 'slot_wallpaper',
  DecorSlot.floor => 'slot_floor',
  DecorSlot.counter => 'slot_counter',
  DecorSlot.window => 'slot_window',
  DecorSlot.plant => 'slot_plant',
};

/// Chiều cao hàng tab 5 ô (thẻ đánh dấu trang, icon trên chữ).
const _tabsHeight = 82.0;

/// Trang trí tiệm: trái xem trước cảnh tiệm trong khung gỗ; phải tab 5 ô (thẻ đánh dấu trang) + danh sách món
/// trên giấy; dưới cảnh tiệm là tổng % tip và 5 nút tròn cho biết ô nào đã đặt đồ.
class DecorScreen extends StatefulWidget {
  const DecorScreen({super.key});

  @override
  State<DecorScreen> createState() => _DecorScreenState();
}

class _DecorScreenState extends State<DecorScreen> {
  DecorSlot _slot = DecorSlot.wallpaper;

  /// Món đang xem thử trong ô [_slot] (chưa chọn → theo món đang đặt).
  DecorId? _preview;
  bool _previewSet = false;

  void _selectSlot(DecorSlot s) => setState(() {
    _slot = s;
    _previewSet = false;
    _preview = null;
  });

  void _selectItem(DecorId? id) => setState(() {
    _previewSet = true;
    _preview = id;
  });

  void _buy(DecorItem item) {
    final services = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final result = services.state.buyDecor(item.id);
    switch (result) {
      case PurchaseResult.ok:
        services.state.equipDecor(item.slot, item.id);
        services.audio.success();
        showToast(context, l.decorEquipped);
      case PurchaseResult.notEnoughCoins:
        services.audio.fail();
        showToast(context, l.commonNotEnoughCoins, success: false);
      case PurchaseResult.notEnoughGems:
        services.audio.fail();
        showToast(context, l.commonNotEnoughGems, success: false);
      case _:
        break;
    }
    _selectItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context).state;
    final equipped = state.equippedDecor;
    final previewMap = {...equipped, if (_previewSet) _slot: _preview};
    final highlighted = _previewSet ? _preview : equipped[_slot];
    final styles = SLTextStyles.of(context);

    return SugarScreen(
      title: l.decorTitle,
      titleIconId: 'decor_chair',
      body: Stack(
        children: [
          // Xem trước (16:9) trong khung gỗ.
          Positioned(
            left: 24,
            top: 16,
            width: 760,
            height: 600,
            child: SLPanel(
              style: SLPanelStyle.wood,
              radius: 26,
              seed: 0xDEC0,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _InkFrame(
                    radius: 14,
                    seed: 0xDEC1,
                    child: SizedBox(width: 720, height: 405, child: ShopBackdrop(equipped: previewMap)),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SLSurface(
                      spec: const SLSurfaceSpec(
                        shape: SLRoundRect(16),
                        material: SLMaterial.wash,
                        color: SLColors.butterLight,
                        inkWidth: 1.8,
                        seed: 0xDEC2,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const SLIcon('tip_jar', size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.decorTotalBonus(state.decorTipBonusPct),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: styles.heading.copyWith(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final s in DecorSlot.values)
                                _SlotDot(
                                  slot: s,
                                  filled: equipped[s] != null,
                                  tooltip: '${l.decorSlotName(s)}: ${l.decorName(equipped[s])}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tab ô (thẻ đánh dấu trang thò ra sau mép trên tờ giấy) + danh sách món.
          Positioned(
            left: 808,
            top: 8,
            right: 24,
            height: 608,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  right: 10,
                  top: 0,
                  height: _tabsHeight,
                  child: SLTabBar(
                    tabs: [for (final s in DecorSlot.values) SLTabItem(l.decorSlotName(s), icon: _slotIcon(s))],
                    selected: _slot.index,
                    onChanged: (i) => _selectSlot(DecorSlot.values[i]),
                    expand: true,
                    iconAbove: true,
                    height: _tabsHeight,
                    spacing: 4,
                    seed: 0x7AB0,
                  ),
                ),
                Positioned.fill(
                  top: _tabsHeight - 6,
                  child: Panel(
                    color: AppColors.cream,
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      children: [
                        _DecorRow(
                          slot: _slot,
                          item: null,
                          state: state,
                          highlighted: highlighted == null,
                          onSelect: () => _selectItem(null),
                          onEquip: () {
                            state.equipDecor(_slot, null);
                            _selectItem(null);
                          },
                          onBuy: null,
                        ),
                        for (final item in Catalog.decorForSlot(_slot))
                          _DecorRow(
                            slot: _slot,
                            item: item,
                            state: state,
                            highlighted: highlighted == item.id,
                            onSelect: () => _selectItem(item.id),
                            onEquip: () {
                              state.equipDecor(_slot, item.id);
                              _selectItem(item.id);
                            },
                            onBuy: () => _buy(item),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút tròn vẽ tay cho một ô trang trí ở dải tổng tip: màu nước bạc hà + dấu tích = đã đặt đồ; giấy cũ = "Cơ bản".
/// Không bấm được; giữ lâu (hoặc rê chuột) hiện [tooltip] "Ô: món".
class _SlotDot extends StatelessWidget {
  const _SlotDot({required this.slot, required this.filled, required this.tooltip});

  final DecorSlot slot;
  final bool filled;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SLTooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: SLMetrics.minTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SLSurface(
                spec: SLSurfaceSpec(
                  shape: const SLCircle(),
                  material: SLMaterial.wash,
                  color: filled ? SLColors.mint : SLColors.paperShade,
                  inkWidth: filled ? 2.2 : 1.6,
                  seed: 0x5107 + slot.index,
                ),
                lift: 2,
                child: Center(child: SLIcon(_slotIcon(slot), size: 28, dimmed: !filled)),
              ),
            ),
            if (filled)
              const Positioned(
                right: -4,
                bottom: -4,
                child: SizedBox.square(
                  dimension: 20,
                  child: SLSurface(
                    spec: SLSurfaceSpec(
                      shape: SLCircle(),
                      material: SLMaterial.wash,
                      color: SLColors.good,
                      inkWidth: 1.4,
                      sticker: true,
                      seed: 0x5C4E,
                    ),
                    child: Center(child: SLIcon('check', size: 13)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Một món trong ô (thẻ giấy chọn được): hình thu nhỏ trong khung mực, tên, % tip, giá, nút mua/đặt.
/// Đang xem thử → giấy vàng bơ viền đậm; khoá → giấy cũ, hình mờ có ổ khoá; đang đặt → nhãn bạc hà "Đã đặt".
class _DecorRow extends StatelessWidget {
  const _DecorRow({
    required this.slot,
    required this.item,
    required this.state,
    required this.highlighted,
    required this.onSelect,
    required this.onEquip,
    required this.onBuy,
  });

  final DecorSlot slot;

  /// null = "Cơ bản".
  final DecorItem? item;
  final GameState state;
  final bool highlighted;
  final VoidCallback onSelect;
  final VoidCallback onEquip;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = SLTheme.of(context);
    final styles = SLTextStyles.of(context);
    final id = item?.id;
    final owned = id == null || state.ownedDecor.contains(id);
    final equipped = state.equippedDecor[slot] == id;
    // V2 GĐ3: `unlockLevel` = phải qua màn đó (không còn "cấp tiệm").
    final locked = !owned && state.highestCompletedLevel < item!.unlockLevel;

    final Widget action;
    if (equipped) {
      action = SLChip(label: l.decorEquipped, icon: 'check', selected: true, color: SLColors.mint);
    } else if (owned) {
      action = _button(l.decorEquip, 'decor_chair', SLColors.mint, onEquip);
    } else if (locked) {
      action = _button(l.mapUnlockAfterLevel(item!.unlockLevel), 'lock', SLColors.butter, null);
    } else {
      action = _button(l.commonBuy, 'basket', SLColors.butter, onBuy);
    }

    final fill = highlighted ? SLColors.butterLight : (locked ? SLColors.paperShade : SLColors.paper);
    final spec = SLSurfaceSpec(
      shape: const SLRoundRect(18),
      color: fill,
      ink: theme.ink,
      inkWidth: highlighted ? theme.inkWidth + 1 : theme.inkWidth - 0.2,
      roughness: theme.roughness,
      seed: 0xD0C0 + slot.index * 8 + (id?.index ?? 7),
    );

    Widget thumb = _InkFrame(
      radius: 12,
      seed: 0xD1C0 + (id?.index ?? 99),
      inkWidth: 1.8,
      child: SizedBox(width: 120, height: 96, child: _SlotThumb(slot: slot, id: id)),
    );
    if (locked) {
      thumb = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0.5, child: thumb),
          const SLIcon('lock', size: 40),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RepaintBoundary(
        child: SLPressable(
          onPressed: onSelect,
          selected: highlighted,
          bounce: false,
          builder: (context, press) => SLSurface(
            spec: spec,
            lift: highlighted ? 4 : 3,
            press: press,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.decorName(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.label.copyWith(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      if (item != null) ...[
                        SLChip(
                          label: l.decorTipBonus(item!.tipBonusPct),
                          icon: 'tip_jar',
                          selected: true,
                          color: SLColors.mintLight,
                        ),
                        const SizedBox(height: 6),
                        if (!owned)
                          PriceTag(
                            amount: item!.paidWithGems ? item!.gemPrice : item!.coinPrice,
                            gems: item!.paidWithGems,
                            affordable: item!.paidWithGems
                                ? state.gems >= item!.gemPrice
                                : state.coins >= item!.coinPrice,
                            size: 18,
                          ),
                      ],
                      const SizedBox(height: 8),
                      action,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(String label, String iconId, Color color, VoidCallback? onPressed) =>
      SugarButton(label: label, iconId: iconId, color: color, height: 48, fontSize: 17, onPressed: onPressed);
}

/// Khung mực run tay quanh một hình (cắt hình theo viền run tay, vẽ nét mực đè lên mép).
class _InkFrame extends StatelessWidget {
  const _InkFrame({required this.child, required this.radius, required this.seed, this.inkWidth = 2.2});

  final Widget child;
  final double radius;
  final int seed;
  final double inkWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _InkFramePainter(radius, seed, inkWidth, SLTheme.of(context).ink),
        child: ClipPath(clipper: _InkFrameClipper(radius, seed), child: child),
      );
}

/// Viền run tay theo (cỡ, bo góc, seed) — dựng một lần, dùng chung cho cắt và vẽ.
final _framePaths = <(int, int, double, int), Path>{};

Path _framePath(Size size, double radius, int seed) {
  final w = size.width.round(), h = size.height.round();
  return _framePaths.putIfAbsent((w, h, radius, seed), () {
    if (_framePaths.length > 64) _framePaths.clear();
    final rect = Rect.fromLTWH(1.5, 1.5, w - 3.0, h - 3.0);
    final amp = (size.shortestSide * 0.012).clamp(0.6, 1.6);
    return wobblePath(Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))), seed: seed, amplitude: amp);
  });
}

class _InkFrameClipper extends CustomClipper<Path> {
  const _InkFrameClipper(this.radius, this.seed);

  final double radius;
  final int seed;

  @override
  Path getClip(Size size) => _framePath(size, radius, seed);

  @override
  bool shouldReclip(_InkFrameClipper old) => old.radius != radius || old.seed != seed;
}

class _InkFramePainter extends CustomPainter {
  const _InkFramePainter(this.radius, this.seed, this.width, this.ink);

  final double radius;
  final int seed;
  final double width;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(
      _framePath(size, radius, seed),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_InkFramePainter old) =>
      old.radius != radius || old.seed != seed || old.width != width || old.ink != ink;
}

/// Hình thu nhỏ: món có ảnh vẽ tay → ảnh riêng món (hoạ tiết lặp cho giấy dán tường/sàn, đồ vật trên nền kem);
/// "Cơ bản" (hoặc chưa có ảnh) → cảnh tiệm chỉ đặt món [id] ở ô [slot], phóng vào vùng của ô đó.
class _SlotThumb extends StatelessWidget {
  const _SlotThumb({required this.slot, required this.id});

  final DecorSlot slot;
  final DecorId? id;

  static Rect _focus(DecorSlot s) => switch (s) {
    DecorSlot.wallpaper => const Rect.fromLTWH(0, 0, 640, 512),
    DecorSlot.floor => const Rect.fromLTWH(200, 520, 250, 200),
    DecorSlot.counter => const Rect.fromLTWH(880, 300, 280, 224),
    DecorSlot.window => const Rect.fromLTWH(740, 60, 380, 304),
    DecorSlot.plant => const Rect.fromLTWH(980, 390, 300, 240),
  };

  @override
  Widget build(BuildContext context) {
    final equipped = {for (final s in DecorSlot.values) s: s == slot ? id : null};
    final item = id == null ? null : ArtSprites.decor(id!);
    return ArtCanvas(
      repaintKey: Object.hash(slot, id),
      repaint: ArtSprites.changes,
      paint: (canvas, size) {
        final rect = Offset.zero & size;
        final image = item?.image;
        if (image != null) {
          if (item!.group == ArtGroup.tiles) {
            paintArtTiled(canvas, rect, image, tileSize: size.height);
          } else {
            canvas.drawRect(rect, Paint()..color = AppColors.cream);
            paintArt(canvas, rect.deflate(4), image);
          }
          return;
        }
        final art = ShopScene.usesArt(equipped);
        final focus = art ? ShopScene.focus(slot) : _focus(slot);
        canvas.save();
        canvas.scale(size.width / focus.width, size.height / focus.height);
        canvas.translate(-focus.left, -focus.top);
        if (art) {
          ShopScene.paintRef(canvas, equipped);
        } else {
          ShopArt.paint(canvas, kRefSize, equipped);
        }
        canvas.restore();
      },
    );
  }
}
