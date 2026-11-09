import 'package:flutter/material.dart';

import '../../core/branch/branch_economy.dart';
import '../../core/city/city_config.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/format.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';
import 'branch_sheet.dart';
import 'town_l10n.dart';

/// Bảng văn phòng địa ốc (panel bên phải): mỗi lô chi nhánh một dòng "Lô số n", giá, "Mở ở cấp N" (ổ khoá) hoặc
/// "Của bạn", ~xu/giờ cấp 1, két 8 giờ, nút Mua (mờ kèm lý do). Chạm Mua → panel xác nhận trong bảng; xác nhận →
/// [onBuy] (nơi gọi gọi `branches.buy`). Esc / chạm ra ngoài / nút X → [onClose]. Đặt làm con của `Stack`.
class RealtySheet extends StatefulWidget {
  const RealtySheet({
    super.key,
    required this.district,
    required this.owned,
    required this.coins,
    required this.playerLevel,
    required this.onBuy,
    required this.onClose,
  });

  final DistrictDef district;

  /// Id các lô đã mua.
  final Set<String> owned;
  final int coins, playerLevel;
  final ValueChanged<String> onBuy;
  final VoidCallback onClose;

  @override
  State<RealtySheet> createState() => _RealtySheetState();
}

class _RealtySheetState extends State<RealtySheet> {
  /// Lô đang chờ xác nhận mua.
  String? _confirming;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = Shop3dStyle.scaleOf(MediaQuery.sizeOf(context));
    final lots = [
      for (final lot in widget.district.lots)
        if (lot.baseIncome > 0) lot,
    ];
    final confirming = _confirming;
    Widget? confirm;
    if (confirming != null) {
      final lot = widget.district.lot(confirming);
      confirm = BranchConfirmPanel(
        title: l.realtyConfirmTitle,
        body: l.realtyConfirmBody(lot.price),
        onCancel: () => setState(() => _confirming = null),
        onConfirm: () {
          setState(() => _confirming = null);
          widget.onBuy(lot.id);
        },
      );
    }
    return BranchPanelFrame(
      title: cityText(l, 'cityRealtyName'),
      onClose: widget.onClose,
      onBack: confirming != null
          ? () => setState(() => _confirming = null)
          : widget.onClose,
      overlay: confirm,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: lots.length,
        separatorBuilder: (_, _) => SizedBox(height: 8 * s),
        itemBuilder: (context, i) {
          final lot = lots[i];
          final owned = widget.owned.contains(lot.id);
          final locked = widget.playerLevel < lot.requiresLevel;
          final broke = widget.coins < lot.price;
          return _LotRow(
            lot: lot,
            number: widget.district.branchNumber(lot.id),
            owned: owned,
            locked: locked,
            broke: broke,
            onBuy: () => setState(() => _confirming = lot.id),
            scale: s,
          );
        },
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.number,
    required this.owned,
    required this.locked,
    required this.broke,
    required this.onBuy,
    required this.scale,
  });

  final LotDef lot;
  final int number;
  final bool owned, locked, broke;
  final VoidCallback onBuy;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rate = BranchEconomy.ratePerHour(lot, 1);
    final cap = BranchEconomy.capMilli(lot, 1) ~/ 1000;
    final canBuy = !owned && !locked && !broke;
    return RepaintBoundary(
      child: Container(
        key: ValueKey('lot-${lot.id}'),
        padding: EdgeInsets.all(10 * scale),
        decoration: Shop3dStyle.box(
          color: Colors.white,
          radius: 16,
          shadow: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.realtyLotN(number),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Shop3dStyle.body(
                      18 * scale,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                CoinIcon(size: 18 * scale),
                const SizedBox(width: 3),
                Text(
                  formatInt(context, lot.price),
                  style: Shop3dStyle.body(
                    14 * scale,
                    weight: FontWeight.w800,
                    color: owned || !broke
                        ? AppColors.chocolate
                        : SLColors.badDeep,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2 * scale),
            if (owned)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16 * scale,
                    color: AppColors.good,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l.realtyOwned,
                      style: Shop3dStyle.body(
                        14 * scale,
                        weight: FontWeight.w800,
                        color: const Color(0xFF3F8A44),
                      ),
                    ),
                  ),
                ],
              )
            else if (locked)
              Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 16 * scale,
                    color: AppColors.chocolate,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l.townLotLocked(lot.requiresLevel),
                      style: Shop3dStyle.body(
                        14 * scale,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            Text(
              l.branchIncome(rate),
              style: Shop3dStyle.body(14 * scale, height: 1.2),
            ),
            Text(
              l.branchTillCap(cap),
              style: Shop3dStyle.body(14 * scale, height: 1.2),
            ),
            if (!owned && !locked && broke)
              Text(
                l.cityNotEnoughCoins,
                style: Shop3dStyle.body(
                  13 * scale,
                  weight: FontWeight.w800,
                  color: SLColors.badDeep,
                ),
              ),
            if (!owned) ...[
              SizedBox(height: 6 * scale),
              Shop3dPillButton(
                key: ValueKey('buy-${lot.id}'),
                label: l.commonBuy,
                width: double.infinity,
                fontSize: 15,
                semanticsLabel: '${l.commonBuy}: ${l.realtyLotN(number)}',
                onPressed: canBuy ? onBuy : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
