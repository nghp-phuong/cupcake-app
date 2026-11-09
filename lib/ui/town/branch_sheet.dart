import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/branch/branch_economy.dart';
import '../../core/branch/city_branches.dart';
import '../../core/branch/staff.dart';
import '../../core/city/city_config.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/format.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';
import 'town_l10n.dart';

/// Khung bảng bên phải dùng chung cho [BranchSheet] và `RealtySheet`: lớp chạm ngoài (đóng), Esc, tiêu đề + nút X.
/// Esc / chạm ngoài gọi [onBack] (mặc định = [onClose]); nút X luôn gọi [onClose]. Tự bọc `Positioned.fill`.
class BranchPanelFrame extends StatelessWidget {
  const BranchPanelFrame({
    super.key,
    required this.title,
    required this.onClose,
    this.onBack,
    required this.child,
    this.overlay,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget child;

  /// Lớp phủ trong bảng (panel xác nhận); null = không có.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final s = Shop3dStyle.scaleOf(size);
    final back = onBack ?? onClose;
    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): back},
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: back,
                ),
              ),
              Positioned(
                top: 10 + pad.top,
                bottom: 10 + pad.bottom,
                right: 10 + pad.right,
                width: math.min(430 * s, size.width * 0.62),
                // Chạm vào bảng không đóng.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: RepaintBoundary(
                    child: Container(
                      padding: EdgeInsets.all(12 * s),
                      decoration: Shop3dStyle.box(
                        color: AppColors.cream,
                        radius: 22,
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Shop3dStyle.title(context, 24 * s),
                                    ),
                                  ),
                                  Tooltip(
                                    message: l.commonClose,
                                    child: Semantics(
                                      button: true,
                                      label: l.commonClose,
                                      excludeSemantics: true,
                                      onTap: onClose,
                                      child: GestureDetector(
                                        key: const ValueKey('panel-close'),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: onClose,
                                        child: SizedBox(
                                          width: SLMetrics.minTap,
                                          height: SLMetrics.minTap,
                                          child: Center(
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: Shop3dStyle.circle(
                                                color: AppColors.butter,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                color: AppColors.chocolate,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6 * s),
                              Expanded(child: RepaintBoundary(child: child)),
                            ],
                          ),
                          if (overlay != null)
                            Positioned.fill(
                              child: RepaintBoundary(child: overlay!),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel xác nhận nằm trong bảng: nền mờ + thẻ giữa có tiêu đề, nội dung, nút Huỷ / Xác nhận.
class BranchConfirmPanel extends StatelessWidget {
  const BranchConfirmPanel({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title, body;
  final VoidCallback onConfirm, onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = Shop3dStyle.scaleOf(MediaQuery.sizeOf(context));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCancel,
      child: ColoredBox(
        color: const Color(0x73000000),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              margin: EdgeInsets.all(8 * s),
              padding: EdgeInsets.all(14 * s),
              decoration: Shop3dStyle.box(color: Colors.white, radius: 18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Shop3dStyle.title(context, 20 * s),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: Shop3dStyle.body(15 * s),
                    ),
                    SizedBox(height: 12 * s),
                    Row(
                      children: [
                        Expanded(
                          child: Shop3dPillButton(
                            key: const ValueKey('confirm-cancel'),
                            label: l.commonCancel,
                            color: AppColors.cream,
                            width: double.infinity,
                            fontSize: 15,
                            maxLines: 2,
                            onPressed: onCancel,
                          ),
                        ),
                        SizedBox(width: 8 * s),
                        Expanded(
                          child: Shop3dPillButton(
                            key: const ValueKey('confirm-ok'),
                            label: l.commonConfirm,
                            color: AppColors.mint,
                            width: double.infinity,
                            fontSize: 15,
                            maxLines: 2,
                            onPressed: onConfirm,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng chi nhánh (panel bên phải) với 3 thẻ: Két, Nâng cấp, Nhân viên. Widget thuần: dữ liệu vào qua tham số, hành
/// động ra qua callback (nơi gọi dựng lại bảng khi dữ liệu đổi). [staff] là mọi nhân viên đang làm (lọc theo lô ở
/// đây; người ở lô khác hiện "Đang làm ở Chi nhánh m"). Dùng icon vai trò, không dùng chân dung.
class BranchSheet extends StatefulWidget {
  const BranchSheet({
    super.key,
    required this.view,
    required this.staff,
    required this.coins,
    required this.playerLevel,
    required this.clockBehind,
    required this.onCollect,
    required this.onUpgrade,
    required this.onHire,
    required this.onDismiss,
    required this.onClose,
  });

  final BranchView view;
  final List<StaffMember> staff;
  final int coins, playerLevel;

  /// Giờ máy đang lùi so với lần chơi trước: hiện ghi chú két tạm nghỉ.
  final bool clockBehind;
  final VoidCallback onCollect, onUpgrade, onClose;
  final ValueChanged<String> onHire, onDismiss;

  @override
  State<BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<BranchSheet> {
  /// Id nhân viên đang chờ xác nhận cho nghỉ.
  String? _dismissing;

  /// Số thứ tự chi nhánh của một lô (theo cấu hình), 0 nếu không rõ.
  static int _branchNo(String lotId) {
    for (final d in CityConfig.alpha.districts) {
      final n = d.branchNumber(lotId);
      if (n > 0) return n;
    }
    return 0;
  }

  static IconData roleIcon(StaffRole r) => switch (r) {
    StaffRole.server => Icons.room_service_rounded,
    StaffRole.baker => Icons.bakery_dining_rounded,
    StaffRole.manager => Icons.assignment_ind_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = Shop3dStyle.scaleOf(MediaQuery.sizeOf(context));
    final v = widget.view;
    final mine = [
      for (final m in widget.staff)
        if (m.lotId == v.lotId) m,
    ];
    final others = {
      for (final m in widget.staff)
        if (m.lotId != v.lotId) m.id: m.lotId,
    };
    final working = {for (final m in widget.staff) m.id};

    Widget? confirm;
    final dismissing = _dismissing;
    if (dismissing != null) {
      final def = StaffRoster.byId(dismissing);
      final refund =
          (def?.hireCost ?? 0) * BranchEconomy.dismissRefundPct ~/ 100;
      confirm = BranchConfirmPanel(
        title: l.branchDismiss,
        body: l.branchDismissConfirm(staffName(l, dismissing), refund),
        onCancel: () => setState(() => _dismissing = null),
        onConfirm: () {
          setState(() => _dismissing = null);
          widget.onDismiss(dismissing);
        },
      );
    }

    return BranchPanelFrame(
      title: '${l.townBranchN(v.branchNo)} · ${l.cityMaiLevel(v.level)}',
      onClose: widget.onClose,
      onBack: dismissing != null
          ? () => setState(() => _dismissing = null)
          : widget.onClose,
      overlay: confirm,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _tillCard(context, l, s),
          SizedBox(height: 8 * s),
          _upgradeCard(l, s),
          SizedBox(height: 8 * s),
          _staffCard(context, l, s, mine, others, working),
        ],
      ),
    );
  }

  // RepaintBoundary: đổi một thẻ (nâng cấp, thuê) không bắt CanvasKit vẽ lại cả bảng.
  Widget _card(
    double s,
    String? title,
    List<Widget> children, {
    required String key,
  }) => RepaintBoundary(
    child: Container(
      key: ValueKey(key),
      padding: EdgeInsets.all(10 * s),
      decoration: Shop3dStyle.box(
        color: Colors.white,
        radius: 16,
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Shop3dStyle.body(
                17 * s,
                weight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: 4 * s),
          ],
          ...children,
        ],
      ),
    ),
  );

  Widget _line(
    double s,
    String text, {
    Color color = AppColors.chocolate,
    double size = 14,
    FontWeight w = FontWeight.w700,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 2 * s),
    child: Text(
      text,
      style: Shop3dStyle.body(size * s, weight: w, color: color, height: 1.2),
    ),
  );

  Widget _coinLine(double s, String text) => Padding(
    padding: EdgeInsets.only(bottom: 2 * s),
    child: Row(
      children: [
        CoinIcon(size: 18 * s),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: Shop3dStyle.body(
              14 * s,
              weight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );

  String _duration(AppLocalizations l, Duration d) {
    final mins = d.inMinutes;
    if (mins < 60) return l.offlineDurationMinutes(math.max(1, mins));
    if (d.inHours < 24) {
      final rest = mins % 60;
      return rest == 0
          ? l.offlineDurationHours(d.inHours)
          : l.offlineDurationHoursMinutes(d.inHours, rest);
    }
    return l.offlineDurationDays(d.inDays);
  }

  Widget _tillCard(BuildContext context, AppLocalizations l, double s) {
    final v = widget.view;
    final frac = v.cap <= 0 ? 0.0 : (v.till / v.cap).clamp(0.0, 1.0);
    return _card(s, l.branchTill, key: 'card-till', [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 16 * s,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(8),
            border: const Border.fromBorderSide(AppTheme.border),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            key: const ValueKey('till-bar'),
            widthFactor: frac,
            child: ColoredBox(
              color: v.full ? AppColors.good : AppColors.butter,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
      SizedBox(height: 4 * s),
      _coinLine(
        s,
        '${formatInt(context, v.till)} / ${formatInt(context, v.cap)}',
      ),
      _line(s, l.branchIncome(v.ratePerHour)),
      // Két tạm nghỉ khi giờ máy lùi: không hứa "Đầy sau …".
      if (v.full || !widget.clockBehind)
        _line(
          s,
          v.full ? l.branchTillFull : l.branchFullIn(_duration(l, v.fullIn)),
          color: v.full ? const Color(0xFF3F8A44) : AppColors.chocolate,
          w: FontWeight.w800,
        ),
      if (widget.clockBehind)
        Padding(
          padding: EdgeInsets.only(bottom: 4 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16 * s,
                color: SLColors.badDeep,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l.branchClockBehind,
                  key: const ValueKey('clock-behind'),
                  style: Shop3dStyle.body(
                    12 * s,
                    weight: FontWeight.w800,
                    color: SLColors.badDeep,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      SizedBox(height: 4 * s),
      Shop3dPillButton(
        key: const ValueKey('collect'),
        label: l.branchCollect(v.till),
        color: AppColors.mint,
        width: double.infinity,
        fontSize: 15,
        maxLines: 2,
        onPressed: v.till >= 1 ? widget.onCollect : null,
      ),
    ]);
  }

  Widget _upgradeCard(AppLocalizations l, double s) {
    final v = widget.view;
    final cost = v.nextCost;
    String? reason;
    if (cost != null) {
      final req = v.nextLevelReq ?? 0;
      if (widget.playerLevel < req) {
        reason = l.branchNeedMaiLevel(req);
      } else if (widget.coins < cost) {
        reason = l.cityNotEnoughCoins;
      }
    }
    return _card(s, null, key: 'card-upgrade', [
      if (cost == null)
        _line(s, l.commonMax, size: 17, w: FontWeight.w800)
      else ...[
        _line(
          s,
          l.branchNextLevel(v.level + 1, v.nextRatePerHour ?? 0),
          size: 15,
          w: FontWeight.w800,
        ),
        if (reason != null)
          _line(
            s,
            reason,
            color: SLColors.badDeep,
            size: 13,
            w: FontWeight.w800,
          ),
        SizedBox(height: 4 * s),
        Shop3dPillButton(
          key: const ValueKey('upgrade'),
          label: l.branchUpgrade(cost),
          width: double.infinity,
          fontSize: 15,
          maxLines: 2,
          onPressed: reason == null ? widget.onUpgrade : null,
        ),
      ],
    ]);
  }

  Widget _staffCard(
    BuildContext context,
    AppLocalizations l,
    double s,
    List<StaffMember> mine,
    Map<String, String> others,
    Set<String> working,
  ) {
    final v = widget.view;
    final free = v.slots - mine.length;
    return _card(
      s,
      '${l.branchStaff} · ${l.branchSlots(mine.length, v.slots)}',
      key: 'card-staff',
      [
        for (final m in mine)
          if (StaffRoster.byId(m.id) case final def?)
            _staffRow(l, s, def, [
              Shop3dPillButton(
                key: ValueKey('dismiss-${def.id}'),
                label: l.branchDismiss,
                color: AppColors.cream,
                width: double.infinity,
                fontSize: 15,
                maxLines: 2,
                onPressed: () => setState(() => _dismissing = def.id),
              ),
            ]),
        // Chỗ chỉ tăng ở cấp 3 (1/1/2/2/2): từ cấp 3 trở đi không còn gì để mở thêm.
        if (free <= 0 && v.level < 3)
          _line(
            s,
            l.branchNoSlot,
            size: 13,
            color: AppColors.caramel,
            w: FontWeight.w800,
          ),
        for (final def in StaffRoster.all)
          if (!working.contains(def.id))
            _staffRow(
              l,
              s,
              def,
              [
                Shop3dPillButton(
                  key: ValueKey('hire-${def.id}'),
                  label: l.branchHire(def.hireCost),
                  width: double.infinity,
                  fontSize: 15,
                  maxLines: 2,
                  onPressed:
                      free <= 0 ||
                          widget.playerLevel < def.requiresLevel ||
                          widget.coins < def.hireCost
                      ? null
                      : () => widget.onHire(def.id),
                ),
              ],
              note: widget.playerLevel < def.requiresLevel
                  ? l.branchNeedMaiLevel(def.requiresLevel)
                  : widget.coins < def.hireCost
                  ? l.cityNotEnoughCoins
                  : null,
              locked: widget.playerLevel < def.requiresLevel,
            )
          else if (others.containsKey(def.id))
            _staffRow(
              l,
              s,
              def,
              const [],
              note: l.branchWorksAt(_branchNo(others[def.id]!)),
              noteIsBad: false,
            ),
      ],
    );
  }

  Widget _staffRow(
    AppLocalizations l,
    double s,
    StaffDef def,
    List<Widget> actions, {
    String? note,
    bool locked = false,
    bool noteIsBad = true,
  }) {
    final effect = def.depositPct > 0
        ? l.staffEffectDeposit(def.depositPct)
        : l.staffEffectBonus(def.bonusPct);
    return Container(
      key: ValueKey('staff-${def.id}'),
      margin: EdgeInsets.only(top: 6 * s),
      padding: EdgeInsets.all(8 * s),
      decoration: Shop3dStyle.box(
        color: AppColors.cream,
        radius: 14,
        shadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40 * s,
                height: 40 * s,
                decoration: Shop3dStyle.circle(color: AppColors.butter),
                child: Icon(
                  roleIcon(def.role),
                  size: 22 * s,
                  color: AppColors.chocolate,
                ),
              ),
              SizedBox(width: 8 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${staffName(l, def.id)} · ${staffRoleText(l, def.role)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Shop3dStyle.body(
                        15 * s,
                        weight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      effect,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Shop3dStyle.body(
                        13 * s,
                        color: const Color(0xFF3F8A44),
                        weight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (note != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (locked) ...[
                            Icon(
                              Icons.lock_rounded,
                              size: 13 * s,
                              color: AppColors.chocolate,
                            ),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
                            child: Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Shop3dStyle.body(
                                12 * s,
                                weight: FontWeight.w800,
                                color: noteIsBad
                                    ? SLColors.badDeep
                                    : AppColors.caramel,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) SizedBox(height: 6 * s),
          ...actions,
        ],
      ),
    );
  }
}
