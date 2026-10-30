import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/game_state.dart';
import '../../core/models/ids.dart' show AdPlacement;
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/staff_portrait.dart';
import '../level/level_common.dart';
import '../sugarleaf/sugarleaf.dart';

/// Thời gian vắng dễ đọc: "25 phút" / "3 giờ" / "2 giờ 15 phút" / "2 ngày" (≥ 1 ngày làm tròn xuống).
String offlineDurationText(AppLocalizations l, Duration d) {
  if (d.inDays >= 1) return l.offlineDurationDays(d.inDays);
  final hours = d.inHours;
  final minutes = d.inMinutes - hours * 60;
  if (hours == 0) return l.offlineDurationMinutes(minutes < 1 ? 1 : minutes);
  if (minutes == 0) return l.offlineDurationHours(hours);
  return l.offlineDurationHoursMinutes(hours, minutes);
}

/// Mở hộp "Khi bạn vắng nhà" nếu còn thu nhập chờ nhận (`GameState.pendingOffline`); không có → không mở. Hộp không
/// đóng bằng chạm nền; nút Back Android = "Nhận" (không mất xu). Người chơi bấm "Nhận" (cộng xu) hoặc "x2 (xem quảng
/// cáo)" (rewarded giả lập, xem xong cộng gấp đôi). Xong khi hộp đóng.
Future<void> showOfflineDialog(BuildContext context) async {
  final services = AppScope.read(context);
  final pending = services.state.pendingOffline;
  if (pending == null) return;
  services.audio.success();
  await showSLDialog<void>(context, dismissible: false, builder: (_) => OfflineEarningsDialog(earnings: pending));
}

/// Hộp "Khi bạn vắng nhà": chân dung quản lý (`staff_hanh`, thiếu ảnh → ảnh dự phòng), "cô Hạnh đã trông tiệm giúp
/// bạn 3 giờ 20 phút.", dòng nhắc khi đã cắt theo trần giờ, số xu nhận được; nút "x2 (xem quảng cáo)" (ẩn khi hết
/// lượt quảng cáo thưởng hôm nay) và "Nhận". Bấm một lần (chặn bấm đúp / bấm cả hai). Số liệu đọc thẳng
/// `GameState.pendingOffline` (đổi khi app ẩn/hiện, nâng quản lý → hộp hiện số mới); [earnings] chỉ là số lúc mở.
/// Thu nhập chờ thành null khi hộp đang mở (đã nhận ở nơi khác) → hộp tự đóng.
class OfflineEarningsDialog extends StatefulWidget {
  const OfflineEarningsDialog({super.key, required this.earnings});

  /// Thu nhập lúc mở hộp (dùng khi `pendingOffline` đã thành null trong lúc hộp đang đóng).
  final OfflineEarnings earnings;

  @override
  State<OfflineEarningsDialog> createState() => _OfflineEarningsDialogState();
}

class _OfflineEarningsDialogState extends State<OfflineEarningsDialog> {
  /// Đang xem quảng cáo / đã bấm: chặn bấm thêm.
  bool _busy = false;

  /// Đã đóng (hoặc đã lên lịch đóng): không đóng lần hai.
  bool _closed = false;

  /// Số hiện gần nhất (giữ khi `pendingOffline` thành null lúc hộp đang đóng).
  late OfflineEarnings _last = widget.earnings;

  GameState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.read(context).state;
    if (!identical(state, _state)) {
      _state?.removeListener(_onState);
      _state = state..addListener(_onState);
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_onState);
    super.dispose();
  }

  /// Thu nhập chờ hết (đã nhận ở nơi khác) → đóng hộp sau khung hình này. Đang xem quảng cáo (route quảng cáo nằm
  /// trên hộp) → để [_double] xử lý khi quảng cáo xong.
  void _onState() {
    if (_closed || _busy || _state?.pendingOffline != null) return;
    _closed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  /// Đóng hộp: hộp ở trên cùng → pop; có route khác đè lên → gỡ riêng route của hộp.
  void _close() {
    _closed = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null || route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }

  void _claim() {
    if (_busy || _closed) return;
    _busy = true;
    _closed = true;
    AppScope.read(context).state.claimOffline();
    _close();
  }

  Future<void> _double() async {
    if (_busy || _closed) return;
    final services = AppScope.read(context);
    setState(() => _busy = true);
    final watched = await services.ads.showRewarded(context, AdPlacement.offlineDouble);
    if (!mounted || _closed) return;
    if (services.state.pendingOffline == null) {
      // Đã nhận ở nơi khác trong lúc xem quảng cáo: không còn gì để nhân đôi.
      _close();
      return;
    }
    if (!watched) {
      // Không xem được (hết lượt / lỗi): ở lại hộp, nút x2 tự ẩn nếu hết lượt.
      setState(() => _busy = false);
      return;
    }
    _closed = true;
    services.state.claimOffline(doubled: true);
    showToast(context, AppLocalizations.of(context).offlineDoubled);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final services = AppScope.of(context);
    // AppScope.of → dựng lại khi GameState đổi: luôn hiện số mới nhất.
    final e = _last = services.state.pendingOffline ?? _last;
    final manager = services.state.unlockConfig.staffById(StaffIds.manager);
    final character = manager?.character ?? 'staff_hanh';
    final name = manager?.name(levelLang(context)) ?? l.staffRoleManager;
    final canDouble = services.ads.canShowRewarded();
    final number = styles.number.copyWith(fontSize: 40, fontWeight: FontWeight.w900);

    // Back Android = "Nhận" thường (không đóng hộp mà mất xu); đang xem quảng cáo → bỏ qua.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _claim();
      },
      child: SLDialog(
        key: const ValueKey('offline-dialog'),
        title: l.offlineTitle,
        titleIcon: 'moon',
        titleColor: SLColors.mintLight,
        width: 680,
        actions: [
          if (canDouble)
            SLButton(
              key: const ValueKey('offline-double'),
              label: l.offlineDouble,
              icon: 'play_video',
              color: SLColors.butter,
              height: 64,
              fontSize: 22,
              loading: _busy,
              onPressed: _busy ? null : _double,
            ),
          SLButton(
            key: const ValueKey('offline-claim'),
            label: l.offlineClaim,
            icon: 'check',
            color: SLColors.strawberry,
            width: 200,
            height: 64,
            fontSize: 24,
            onPressed: _busy ? null : _claim,
          ),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 176,
              height: 220,
              child: SLSurface(
                spec: const SLSurfaceSpec(
                  shape: SLRoundRect(18),
                  material: SLMaterial.wash,
                  color: SLColors.mintLight,
                  inkWidth: 2.2,
                  seed: 0x0FF1,
                ),
                lift: 2,
                padding: const EdgeInsets.all(5),
                child: LayoutBuilder(
                  builder: (context, box) => SLHandClip(
                    shape: const SLRoundRect(14),
                    seed: 0x0FF2,
                    child: StaffPortrait(
                      key: const ValueKey('offline-portrait'),
                      character: staffCharacterArt(AppScope.of(context).state, character),
                      width: box.maxWidth,
                      height: box.maxHeight,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.offlineBody(name, offlineDurationText(l, e.away)),
                    key: const ValueKey('offline-body'),
                    textAlign: TextAlign.start,
                    style: styles.body.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  if (e.capped) ...[
                    const SizedBox(height: 8),
                    Row(
                      key: const ValueKey('offline-capped'),
                      children: [
                        const SLIcon('clock', size: 24, color: SLColors.inkSoft),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.offlineCapped(e.capHours),
                            style: styles.label.copyWith(fontSize: 17, color: SLColors.inkSoft, height: 1.15),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    label: l.offlineEarned(e.coins),
                    child: ExcludeSemantics(
                      child: SLSurface(
                        spec: const SLSurfaceSpec(
                          shape: SLRoundRect(22),
                          material: SLMaterial.wash,
                          color: SLColors.butterLight,
                          inkWidth: 2,
                          seed: 0x0FF3,
                        ),
                        lift: 2,
                        padding: const EdgeInsets.fromLTRB(10, 4, 20, 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(size: 52),
                            const SizedBox(width: 8),
                            Text('+${formatInt(context, e.coins)}', key: const ValueKey('offline-coins'), style: number),
                          ],
                        ),
                      ),
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
}
