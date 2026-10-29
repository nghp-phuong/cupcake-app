import 'dart:ui';

import '../../core/models/bake.dart';
import '../../core/models/ids.dart';

/// Một topping đã đặt lên bánh — vị trí lưu theo toạ độ chuẩn hoá của elip mặt bánh.
class PlacedTopping {
  PlacedTopping(this.topping, this.unit);

  final ToppingId topping;
  Offset unit;

  /// Thời gian từ lúc thả (cho hoạt cảnh nảy).
  double age = 0;
}

/// Số đo thô gom qua 6 trạm → [BakeOutcome]. Không chấm điểm (việc của `Scoring` ở core).
class BakeRecord {
  int wrongMouldDrops = 0;
  double mixTurns = 0;
  double bakeRelease = 0;
  double frostCoverage = 0;
  final List<PlacedTopping> toppings = [];
  BoxType? boxChosen;

  Map<ToppingId, int> get toppingCounts {
    final m = <ToppingId, int>{};
    for (final t in toppings) {
      m[t.topping] = (m[t.topping] ?? 0) + 1;
    }
    return m;
  }

  BakeOutcome toOutcome() => BakeOutcome(
        wrongMouldDrops: wrongMouldDrops,
        mixTurns: mixTurns,
        bakeRelease: bakeRelease.clamp(0.0, 1.0),
        frostCoverage: frostCoverage.clamp(0.0, 1.0),
        toppingsPlaced: Map.unmodifiable(toppingCounts),
        boxChosen: boxChosen ?? BoxType.small,
      );
}
