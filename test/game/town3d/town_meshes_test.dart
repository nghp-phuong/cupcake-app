import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/game/town3d/town_meshes.dart';

/// Lưới món ăn trên bàn hiên (town_meshes.dart): vài trăm tam giác, gốc ở đáy, vừa mặt bàn Ø0,9 m. Dart thuần.
void main() {
  test('mỗi món của thực đơn có lưới riêng ≤ ngân sách tam giác, đáy ở y = 0, nằm gọn trên bàn', () {
    final seen = <int>{};
    for (final d in RestaurantMenu.dishes) {
      final m = TownMeshes.dish(d.id);
      // ignore: avoid_print
      print('${d.id}: ${m.triangleCount} tris');
      expect(m.triangleCount, greaterThan(40), reason: d.id);
      expect(m.triangleCount, lessThanOrEqualTo(TownMeshes.maxTriangles), reason: d.id);
      expect(m.minY, closeTo(0, 0.01), reason: d.id);
      expect(m.maxY, lessThan(0.15), reason: d.id);
      expect(m.minX, greaterThan(-0.2), reason: d.id);
      expect(m.maxX, lessThan(0.2), reason: d.id);
      expect(m.minZ, greaterThan(-0.2), reason: d.id);
      expect(m.maxZ, lessThan(0.2), reason: d.id);
      expect(m.colors.length ~/ 4, m.positions.length ~/ 3);
      seen.add(m.triangleCount);
    }
    expect(seen.length, greaterThan(1), reason: 'các món khác hình nhau');
  });
}
