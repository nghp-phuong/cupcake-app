import 'package:flutter/widgets.dart';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/customer.dart';
import '../../core/models/ids.dart';
import '../../core/models/order.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../sugarleaf/sugarleaf.dart';

/// Nhãn VIP / khách quen của khách (null với khách thường) — huy hiệu nhãn dán vẽ tay.
Widget? customerBadge(AppLocalizations l, Customer c) => switch (c.kind) {
  CustomerKind.vip => const SLBadge.vip(),
  CustomerKind.friend => SLBadge.label(l.customerFriendBadge, color: SLColors.mint, icon: 'heart'),
  CustomerKind.regular => null,
};

/// Vé đơn hàng — vé giấy răng cưa ghim trên quầy ([SLOrderTicket]): cuống ghi "Đơn hàng" + nhãn VIP/khách quen;
/// thân: hình món trên đĩa, kem, topping × số, hộp. Cao đúng [height] (mặc định 420, như khung cũ trên quầy).
class OrderTicket extends StatelessWidget {
  const OrderTicket({super.key, required this.order, required this.customer, this.height = 420});

  final Order order;
  final Customer customer;
  final double height;

  static const _stub = 60.0;

  /// Lề thân vé của [SLOrderTicket]: 12 trên + (răng cưa 12 + 12) dưới.
  static const _bodyPadding = 36.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final badge = customerBadge(l, customer);
    return SLOrderTicket(
      width: null,
      stub: _stub,
      tilt: -0.006,
      seed: 0x71C4,
      header: Row(
        children: [
          const SLArtIcon(ArtSprites.ticket, 'ticket', size: 28),
          const SizedBox(width: 8),
          Flexible(child: Text(l.dayOrderTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: styles.title)),
          const Spacer(),
          if (badge != null) badge,
        ],
      ),
      child: SizedBox(
        height: height - _stub - _bodyPadding,
        child: Row(
          children: [
            // Hình món trên đĩa vẽ tay.
            SizedBox(
              width: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Đĩa sứ vẽ tay: vành bạc hà loang, chấm hồng, bóng mềm (như đĩa ở trạm làm bánh).
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: SizedBox(width: 196, height: 44, child: SLPlate(seed: 0x9A7E)),
                      ),
                      CakeImage(visual: CakeVisual.order(order), recipe: order.recipe, size: 190),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.recipeName(order.recipe),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: styles.label.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(
                    label: l.dayOrderFrosting,
                    seed: 1,
                    child: Row(
                      children: [
                        FrostingSwatch(order.frosting, size: 40),
                        const SizedBox(width: 8),
                        Flexible(child: _value(context, l.frostingName(order.frosting))),
                      ],
                    ),
                  ),
                  _Line(
                    label: l.dayOrderToppings,
                    seed: 2,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [for (final t in order.toppings) _ToppingChip(request: t)],
                    ),
                  ),
                  _Line(
                    label: l.dayOrderBox,
                    last: true,
                    child: Row(
                      children: [
                        BoxImage(order.box, size: 48),
                        const SizedBox(width: 8),
                        Flexible(child: _value(context, l.boxName(order.box))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _value(BuildContext context, String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SLTextStyles.of(context).label.copyWith(fontSize: 20),
      );
}

/// Một dòng của vé: nhãn nhỏ (mực nhạt) + nội dung, kẻ bút chì ngăn dòng sau.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.child, this.last = false, this.seed = 0});

  final String label;
  final Widget child;
  final bool last;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: last ? 6 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SLTextStyles.of(context).caption.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
          ),
          const SizedBox(height: 4),
          child,
          if (!last) SLRule(echo: SLRuleEcho.partial, seed: 0x5E1 + seed),
        ],
      ),
    );
  }
}

/// Topping × số: viên kẹo màu nước; tên dài cắt "…", tên đầy đủ ở tooltip (mẩu giấy vẽ tay).
class _ToppingChip extends StatelessWidget {
  const _ToppingChip({required this.request});

  final ToppingRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final name = l.toppingName(request.topping);
    return SLTooltip(
      message: name,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(20),
          material: SLMaterial.wash,
          color: SLColors.cream,
          inkWidth: 1.8,
          seed: request.topping.index * 7 + request.count,
        ),
        padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToppingImage(request.topping, size: 36),
            const SizedBox(width: 4),
            Text('×${request.count}', style: styles.label.copyWith(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            // Tên dài (hoặc font hẹp chỗ) → cắt "…" thay vì tràn; tên đầy đủ ở tooltip.
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
