import '../shop3d/interact/shop3d_nav.dart';
import 'town_layout.dart';

/// Điều hướng ngoài phố (thành phố V3): dùng lại [Shop3dNav] (va chạm hình tròn – hộp, trượt, A*) với biên của quận
/// thay cho biên cảnh tiệm, nguồn chặn là [TownLayout.blockers] (đã gồm hộp chặn quanh biên quận — không thêm tường
/// tiệm), mặt đất phẳng (đường / vỉa hè / hiên chênh nhau ≤ 5 cm) và ô A* thô hơn ([cellSize]) cho quận 48 × 32 m. Dart
/// thuần.
abstract final class TownNav {
  /// Ô A* (m): 0,15 → quận 48 × 32 m ≈ 320 × 214 ô (dựng lười một lần, ~68k phép thử đứng được).
  static const double cellSize = 0.15;

  /// Bán kính va chạm của Mai ngoài phố (như trong tiệm: `Shop3dPilot.maxNavRadius`).
  static const double radius = 0.27;

  /// Khoảng hở khi tìm đường (tự đi tới ghế quán ăn): nhỏ hơn mặc định 0,3 m của tiệm một chút vì ghế hiên sát bàn.
  static const double clearance = 0.27;

  static Shop3dNav of(TownLayout t) => Shop3dNav(
        t.blockers,
        addWalls: false,
        bounds: NavBounds(t.minX, t.maxX, t.minZ, t.maxZ),
        cellSize: cellSize,
        floorHeight: flat,
      );

  /// Mặt đứng phẳng y = 0.
  static double flat(double x, double z) => 0;
}
