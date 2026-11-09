import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/city/city_config.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shop3d/shop3d_toasts.dart';
import 'minimap.dart';
import 'town_l10n.dart';

/// Bản đồ lớn mở khi chạm minimap: phủ cả màn (nền tối), thẻ giữa màn có bản đồ, tên lô (qua l10n), lô chưa đủ cấp
/// ghi "Mở ở cấp N", nhãn "Bạn ở đây" cạnh chấm Mai. Đóng bằng nút Đóng hoặc chạm ngoài thẻ → [onClose].
class TownMapSheet extends StatelessWidget {
  const TownMapSheet({
    super.key,
    required this.district,
    required this.maiPos,
    this.maiYaw,
    required this.playerLevel,
    this.branches = TownBranchMarks.none,
    required this.onClose,
  });

  final DistrictDef district;
  final ValueListenable<Offset> maiPos;
  final ValueListenable<double>? maiYaw;

  /// Cấp hiện tại của Mai (lô có `requiresLevel` cao hơn bị khoá).
  final int playerLevel;

  /// Chi nhánh đã mua / két đầy / cấp: tô màu nhấn, huy hiệu két đầy, ghi "Cấp L".
  final TownBranchMarks branches;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final s = Shop3dStyle.scaleOf(size);
    final aspect =
        (district.maxX - district.minX) / (district.maxZ - district.minZ);
    // Thẻ: tiêu đề + bản đồ + nút đóng; bản đồ vừa khung còn lại.
    final maxMapH = size.height - 190 * s;
    final maxMapW = size.width - 96;
    final mapW = (maxMapH * aspect).clamp(0.0, maxMapW).toDouble();
    final mapH = mapW / aspect;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0x73000000)),
          ),
        ),
        Center(
          // Chạm vào thẻ không đóng.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              padding: EdgeInsets.all(14 * s),
              decoration: Shop3dStyle.box(color: AppColors.cream, radius: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cityText(l, district.nameKey),
                    style: Shop3dStyle.title(context, 24 * s),
                  ),
                  SizedBox(height: 10 * s),
                  SizedBox(
                    width: mapW,
                    height: mapH,
                    child: _MapBody(
                      district: district,
                      maiPos: maiPos,
                      maiYaw: maiYaw,
                      playerLevel: playerLevel,
                      branches: branches,
                      scale: s,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Shop3dPillButton(
                    label: l.commonClose,
                    onPressed: onClose,
                    width: 160,
                    fontSize: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.district,
    required this.maiPos,
    required this.maiYaw,
    required this.playerLevel,
    required this.branches,
    required this.scale,
  });

  final DistrictDef district;
  final ValueListenable<Offset> maiPos;
  final ValueListenable<double>? maiYaw;
  final int playerLevel;
  final TownBranchMarks branches;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final repaint = Listenable.merge([maiPos, if (maiYaw != null) maiYaw!]);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: TownMapPainter(
                      district: district,
                      maiPos: maiPos,
                      maiYaw: maiYaw,
                      dotRadius: 8,
                      playerLevel: playerLevel,
                      cornerLock: true,
                      branches: branches,
                      repaint: repaint,
                    ),
                  ),
                ),
              ),
              for (final lot in district.lots)
                Positioned.fromRect(
                  rect: TownMapPainter.lotRect(district, lot, size),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _LotLabel(
                          name: cityText(l, lot.nameKey),
                          locked: lot.requiresLevel > playerLevel
                              ? l.townLotLocked(lot.requiresLevel)
                              : null,
                          unlocked:
                              lot.kind == LotKind.branch &&
                                  lot.requiresLevel <= playerLevel &&
                                  !branches.owned.contains(lot.id)
                              ? l.townLotUnlocked
                              : null,
                          level: branches.owned.contains(lot.id)
                              ? l.cityMaiLevel(branches.levels[lot.id] ?? 1)
                              : null,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                ),
              ValueListenableBuilder<Offset>(
                valueListenable: maiPos,
                builder: (context, m, _) {
                  final p = TownMapPainter.toPx(district, m, size);
                  // Nhãn nằm trên chấm; sát mép trên thì xuống dưới.
                  final above = p.dy > 36;
                  return Positioned(
                    left: p.dx - 70,
                    width: 140,
                    top: above ? p.dy - 38 : p.dy + 14,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: Shop3dStyle.box(
                            color: AppColors.bad,
                            radius: 12,
                            shadow: false,
                          ),
                          child: Text(
                            l.townYouAreHere,
                            maxLines: 1,
                            style: Shop3dStyle.body(
                              14,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LotLabel extends StatelessWidget {
  const _LotLabel({
    required this.name,
    required this.locked,
    required this.unlocked,
    this.level,
    required this.scale,
  });

  final String name;
  final String? locked;

  /// Lô chi nhánh đã đủ cấp (chưa bán): biểu tượng mở khoá + chữ màu "đúng".
  final String? unlocked;

  /// Lô chi nhánh đã mua: "Cấp L".
  final String? level;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          style: Shop3dStyle.body(
            15 * scale,
            weight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        if (locked != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 14 * scale,
                color: AppColors.chocolate,
              ),
              const SizedBox(width: 2),
              Text(
                locked!,
                textAlign: TextAlign.center,
                style: Shop3dStyle.body(
                  13 * scale,
                  weight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        if (level != null)
          Text(
            level!,
            textAlign: TextAlign.center,
            style: Shop3dStyle.body(13 * scale, weight: FontWeight.w700, height: 1.1),
          ),
        if (unlocked != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_open_rounded,
                size: 14 * scale,
                color: AppColors.good,
              ),
              const SizedBox(width: 2),
              Text(
                unlocked!,
                textAlign: TextAlign.center,
                style: Shop3dStyle.body(
                  13 * scale,
                  weight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.good,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
