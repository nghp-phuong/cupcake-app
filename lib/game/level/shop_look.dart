import 'dart:math' as math;

import '../../core/level/level.dart';
import '../../core/models/ids.dart';

/// Những gì sân tiệm / bếp nhanh vẽ thêm theo đồ người chơi đã mua (suy từ `ShopSetup` của session) và đồ trang
/// trí đã đặt. Chỉ để vẽ — luật chơi (số ô tủ, số lò, kiên nhẫn…) đã nằm trong session; ảnh lò theo hàm chung
/// `ShopSetup.ovenArtLevel` (xem `LevelGame.ovenLevel`).
class ShopLook {
  const ShopLook({this.standSlots = 0, this.cafeTables = false, this.counterDecor, this.plantDecor});

  static const ShopLook base = ShopLook();

  /// id mở rộng / thiết bị trong `unlocks.json` mà cảnh tiệm vẽ theo.
  static const String caseStandId = 'case_stand', cafeTablesId = 'cafe_tables';

  /// Tủ kính chính vẽ gọn tối đa chừng này cột; ô dư sang kệ bánh tầng.
  static const int mainCaseMax = 4;

  /// Kệ bánh tầng chứa tối đa chừng này ô (1 ô: hai tầng như tủ; 2 ô: mỗi tầng một ô).
  static const int standMax = 2;

  /// Số ô tủ vẽ trên kệ bánh tầng (ô cuối của tủ); 0 = không có kệ.
  final int standSlots;

  /// 2 bộ bàn ghế trên sàn tiệm; khách chờ đứng quanh bàn bên phải.
  final bool cafeTables;

  /// Đồ trang trí đã đặt ở ô quầy / cây (tường, sàn, cửa sổ không vẽ ở màn chơi level).
  final DecorId? counterDecor, plantDecor;

  bool get caseStand => standSlots > 0;

  /// Số ô vẽ trong tủ kính chính khi tủ có [slots] ô.
  int mainSlots(int slots) => math.max(1, slots - standSlots);

  /// Gộp đồ đã mua ([owned], [caseSlotsBonus]) với tủ [caseSlots] ô thành cách vẽ: có
  /// `case_stand` → các ô cộng thêm nằm trên kệ tầng; tủ quá [mainCaseMax] ô (dù chưa mua kệ) → ô dư cũng lên kệ.
  factory ShopLook.resolve({
    required int caseSlots,
    Set<String> owned = const {},
    int caseSlotsBonus = 0,
    Map<DecorSlot, DecorId?> decor = const {},
  }) {
    var stand = owned.contains(caseStandId) ? math.max(1, caseSlotsBonus) : 0;
    stand += math.max(0, caseSlots - stand - mainCaseMax);
    stand = math.min(math.min(stand, standMax), caseSlots - 1);
    final counter = decor[DecorSlot.counter];
    final plant = decor[DecorSlot.plant];
    return ShopLook(
      standSlots: math.max(0, stand),
      cafeTables: owned.contains(cafeTablesId),
      counterDecor: counter == DecorId.counterFlowers || counter == DecorId.counterCakeStand ? counter : null,
      plantDecor: plant == DecorId.plantFern || plant == DecorId.plantLemonTree ? plant : null,
    );
  }

  /// Cách vẽ của lượt chơi [s] (đọc `s.setup`) với đồ trang trí đã đặt [decor].
  factory ShopLook.of(LevelSession s, {Map<DecorSlot, DecorId?> decor = const {}}) {
    final setup = s.setup;
    return ShopLook.resolve(
      caseSlots: s.displayCase.slots,
      owned: setup.owned,
      caseSlotsBonus: setup.caseSlotsBonus,
      decor: decor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShopLook &&
      other.standSlots == standSlots &&
      other.cafeTables == cafeTables &&
      other.counterDecor == counterDecor &&
      other.plantDecor == plantDecor;

  @override
  int get hashCode => Object.hash(standSlots, cafeTables, counterDecor, plantDecor);

  @override
  String toString() => 'ShopLook(stand $standSlots, tables $cafeTables, $counterDecor, $plantDecor)';
}
