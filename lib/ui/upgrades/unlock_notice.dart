import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/game_state.dart';
import '../../l10n/gen/app_localizations.dart';
import '../level/level_common.dart';
import '../sugarleaf/sugarleaf.dart';
import 'upgrades_screen.dart';

/// Một mục của thẻ "Mở khoá mới!": mở rộng / nhân viên (`UnlockData`) hoặc một cấp thiết bị mới (`"eq:<id>:<cấp>"`).
class UnlockNoticeItem {
  const UnlockNoticeItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.artPath,
    required this.fallbackIcon,
    this.tier,
    this.comingSoon = false,
  });

  /// Id gốc trong `newUnlocks` (để mở đúng tab/thẻ).
  final String id;
  final String name;
  final String desc;
  final String? artPath;
  final String fallbackIcon;

  /// Cấp thiết bị vừa khả dụng; null = không phải thiết bị.
  final int? tier;
  final bool comingSoon;
}

/// Dựng các mục thông báo từ [ids] (bỏ id lạ không có trong cấu hình, bỏ trùng, giữ thứ tự).
List<UnlockNoticeItem> unlockNoticeItems(UnlockConfig config, Iterable<String> ids, String lang) {
  final out = <UnlockNoticeItem>[];
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) continue;
    final eq = UnlockKeys.parseEquipment(id);
    if (eq != null) {
      final e = config.equipmentById(eq.id);
      if (e == null) continue;
      out.add(
        UnlockNoticeItem(
          id: id,
          name: e.name(lang),
          desc: e.desc(lang),
          artPath: e.artPath,
          fallbackIcon: 'oven',
          tier: eq.tier,
        ),
      );
      continue;
    }
    final u = config.unlock(id);
    if (u == null) continue;
    out.add(
      UnlockNoticeItem(
        id: id,
        name: u.name(lang),
        desc: u.desc(lang),
        artPath: u.artPath,
        fallbackIcon: unlockFallbackIcon(u.kind),
        comingSoon: u.comingSoon,
      ),
    );
  }
  return out;
}

/// Thẻ "Mở khoá mới!" cho [ids] (vd. `newUnlocks` của các lượt vừa chơi). Không có mục hợp lệ → không mở, trả null.
/// "Xem" → trả tham số mở màn Nâng cấp đúng tab/thẻ của mục đầu (ưu tiên mục mua được, không phải "Sắp có"); không
/// đánh dấu đã xem ở đây — màn Nâng cấp tự đánh dấu khi mở để các mục vẫn mang huy hiệu "Mới". "Để sau" / chạm nền →
/// null: chấm đỏ trên nút Nâng cấp còn tới khi mở màn Nâng cấp; thông báo không hiện lại (hàng chờ của bản đồ đã lấy
/// ra).
Future<UpgradesArgs?> showUnlockNotice(BuildContext context, Iterable<String> ids) async {
  final services = AppScope.read(context);
  final config = services.state.unlockConfig;
  final items = unlockNoticeItems(config, ids, levelLang(context));
  if (items.isEmpty) return null;
  services.audio.success();
  final view = await showSLDialog<bool>(context, builder: (_) => UnlockNoticeDialog(items: items));
  if (view != true) return null;
  final target = items.firstWhere((i) => !i.comingSoon, orElse: () => items.first);
  return UpgradesArgs.forUnlock(target.id, config);
}

/// Hộp thoại "Mở khoá mới!": một mục → ảnh lớn + tên + mô tả; nhiều mục → danh sách (tối đa [maxRows], phần còn lại
/// ghi "+N"). Nút "Để sau" (pop false) / "Xem" (pop true).
class UnlockNoticeDialog extends StatelessWidget {
  const UnlockNoticeDialog({super.key, required this.items});

  final List<UnlockNoticeItem> items;

  static const maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final single = items.length == 1;
    final rows = items.take(maxRows).toList();
    final more = items.length - rows.length;
    return SLDialog(
      key: const ValueKey('unlock-notice'),
      title: l.unlockNoticeTitle,
      titleIcon: 'sparkle',
      titleColor: SLColors.butter,
      width: single ? 600 : 680,
      actions: [
        SLButton(
          key: const ValueKey('unlock-notice-later'),
          label: l.unlockNoticeLater,
          variant: SLButtonVariant.secondary,
          width: 200,
          height: 60,
          fontSize: 22,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SLButton(
          key: const ValueKey('unlock-notice-view'),
          label: l.unlockNoticeView,
          icon: 'forward',
          color: SLColors.strawberry,
          width: 220,
          height: 60,
          fontSize: 22,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.unlockNoticeBody(items.length),
            textAlign: TextAlign.center,
            style: styles.body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: SLColors.inkSoft),
          ),
          const SizedBox(height: 10),
          if (single)
            _Single(item: items.first)
          else ...[
            for (final item in rows) ...[_Row(item: item), const SizedBox(height: 8)],
            if (more > 0)
              Text(l.unlockNoticeMore(more), style: styles.label.copyWith(fontSize: 17, color: SLColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

/// Dòng phụ dưới tên: cấp thiết bị mới / "Sắp có" / không có.
String? _subtitle(AppLocalizations l, UnlockNoticeItem item) {
  if (item.tier case final t?) return l.unlockNoticeTier(t);
  if (item.comingSoon) return l.upgComingSoon;
  return null;
}

class _Single extends StatelessWidget {
  const _Single({required this.item});

  final UnlockNoticeItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final sub = _subtitle(l, item);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SLBounceIn(
              child: UnlockArt(path: item.artPath, fallbackIcon: item.fallbackIcon, size: 168),
            ),
            const Positioned(right: -14, top: 0, child: SLSparkle(size: 30)),
            const Positioned(left: -10, bottom: 12, child: SLSparkle(size: 22)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.name,
          key: ValueKey('unlock-notice-name-${item.id}'),
          textAlign: TextAlign.center,
          style: styles.heading.copyWith(fontSize: 30, height: 1.15),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SLChip(
              label: sub,
              icon: item.comingSoon ? 'clock' : 'arrow_up',
              selected: true,
              color: SLColors.mintLight,
            ),
          ),
        const SizedBox(height: 6),
        Text(item.desc, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final UnlockNoticeItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final sub = _subtitle(l, item);
    return SLSurface(
      spec: SLSurfaceSpec(
        shape: const SLRoundRect(16),
        material: SLMaterial.wash,
        color: item.comingSoon ? SLColors.paperShade : SLColors.butterLight,
        inkWidth: 1.6,
        seed: slSeed(content: item.id, salt: 0x0C10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          UnlockArt(path: item.artPath, fallbackIcon: item.fallbackIcon, size: 76),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        key: ValueKey('unlock-notice-name-${item.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.heading.copyWith(fontSize: 22),
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(width: 8),
                      Text(sub, style: styles.label.copyWith(fontSize: 15, color: SLColors.goodDeep)),
                    ],
                  ],
                ),
                Text(
                  item.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
