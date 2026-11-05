# Thành phố V3 — Giai đoạn 1: đặc tả và giao diện chung

Chủ dự án duyệt 04/11/2026. Kế hoạch tổng có 6 giai đoạn, xem mục cuối.

Các lựa chọn đã chốt:
- Thành phố alpha có 2 quận, đi lại bằng xe buýt. Mỗi lúc chỉ có một quận nằm trong bộ nhớ.
- Mai có một cấp duy nhất, từ 1 đến 30. Mỗi chi nhánh có cấp riêng từ 1 đến 5.
- Tiệm bánh bán theo ca 3–5 phút, cuối ca có tổng kết.
- Tiệm dịch vụ dùng quầy ở mặt tiền và một bảng 2D, không dựng nội thất.
- Chế độ 50 màn 2D bị thay hẳn bằng thành phố (gỡ ở giai đoạn 2).
- Chi nhánh tự bán hàng, tiền dồn vào két (trần 8 giờ), Mai phải tới tận cửa để thu.
- Chỉ đo hiệu năng trên web, không thử máy thật.

## Phạm vi giai đoạn 1
- Quận "Phố Tiệm Bánh" đi dạo được: Mai đi bằng joystick, camera bám theo, có minimap và bản đồ lớn.
- Vào và ra tiệm của bà. Nội thất là cảnh `Shop3dScene` hiện có, dùng chung một viewer; chuyển cảnh bằng màn mờ đen 0,4 s.
- **Quán ăn "Bếp Hải Đăng":** Mai tới quầy, bấm A "Gọi món", chọn món trong bảng 2D. Bị trừ xu, được XP. Mai ngồi ăn ở bàn hiên, rồi nhận buff "No bụng".
- **Tiệm tóc "Vỏ Sò":** Mai tới quầy, bấm A "Làm tóc". Bảng 2D cho chọn 4 kiểu × 4 màu, Mai 3D đổi ngay để xem trước. Bấm Xác nhận mới trừ xu.
- HUD hiện xu và cấp Mai. Ví giữ trong bộ nhớ, **chưa lưu save** (save làm ở giai đoạn 2).
- Văn phòng địa ốc, 3 lô chi nhánh và công viên chỉ dựng mặt tiền. Chưa tương tác được (chỉ hiện băng tên "Sắp mở").
- Entry mới: `lib/main_town3d.dart`. Giữ nguyên `lib/main_shop3d.dart` chạy được như cũ.

## Toạ độ quận 1 (mét, hệ toạ độ của lớp phố, độc lập với nội thất)
- Biên quận: x ∈ [-24, 24], z ∈ [-16, 16].
- Lòng đường z ∈ [-3, 3]. Vỉa hè z ∈ [-5.5, -3] và [3, 5.5].
- Mỗi lô rộng 11 m theo x, sâu 10 m theo z. Lô phía bắc: tâm z = -10.5, cửa ở z = -5.5, cửa quay về +z (yaw 0). Lô phía nam: tâm z = 10.5, cửa ở z = 5.5, cửa quay về -z (yaw π).

| id | phía | x tâm | kind | giá (xu) | cấp cần | nameKey |
|---|---|---|---|---|---|---|
| `n1` | bắc | -18 | realty | 0 | 1 | `cityRealtyName` |
| `n2` | bắc | -6 | home | 0 | 1 | `townHomeShop` |
| `n3` | bắc | 6 | restaurant | 0 | 1 | `cityRestaurantName` |
| `n4` | bắc | 18 | salon | 0 | 1 | `citySalonName` |
| `s1` | nam | -18 | branch | 8000 | 5 | `townLotForSale` |
| `s2` | nam | -6 | park | 0 | 1 | `cityParkName` |
| `s3` | nam | 6 | branch | 20000 | 10 | `townLotForSale` |
| `s4` | nam | 18 | branch | 45000 | 15 | `townLotForSale` |

- Cửa lô: (x tâm, -5.5) với lô bắc, (x tâm, 5.5) với lô nam.
- Trạm xe buýt (giai đoạn 5, giai đoạn 1 chỉ dựng mái chờ): (-23, -4).
- Điểm xuất hiện của Mai: (-6, -4.4), trước cửa tiệm của bà.

## Giao diện Dart chung (dev-core viết; người khác chỉ dùng, không sửa)

`lib/core/city/city_config.dart`:
```dart
enum LotKind { home, branch, restaurant, salon, realty, park }
class LotDef {
  final String id; final LotKind kind;
  final double x, z;            // tâm lô
  final double w, d;            // kích thước theo x, theo z
  final double doorX, doorZ;    // điểm cửa (mép lô giáp vỉa hè)
  final double yaw;             // 0 = cửa quay về +z; pi = quay về -z
  final int price, requiresLevel;
  final String nameKey;         // khoá AppLocalizations
  const LotDef({...});
}
class DistrictDef {
  final String id, nameKey;     // 'bakery_street', 'townStreetName'
  final double minX, maxX, minZ, maxZ;
  final double roadHalfWidth;   // 3
  final double sidewalkOuter;   // 5.5
  final double busX, busZ, spawnX, spawnZ;
  final List<LotDef> lots;
  LotDef lot(String id); LotDef? lotOfKind(LotKind k);
}
class CityConfig {
  final List<DistrictDef> districts;
  static const CityConfig alpha = ...; // quận 1 như bảng trên; quận 2 'sea_market' để trống lots (giai đoạn 5)
  DistrictDef district(String id);
}
```

`lib/core/city/mai_look.dart`:
```dart
enum MaiHair { ponytail, bob, bun, twinTails }
enum MaiHairColor { chestnut, caramel, black, strawberry }
class MaiLook {
  final MaiHair hair; final MaiHairColor hairColor;
  const MaiLook({this.hair = MaiHair.ponytail, this.hairColor = MaiHairColor.chestnut});
  static const MaiLook defaults = MaiLook();
  MaiLook copyWith({MaiHair? hair, MaiHairColor? hairColor});
  Map<String, Object?> toJson(); factory MaiLook.fromJson(Map<String, Object?> j); // khoá lạ → mặc định
  // == và hashCode
}
class SalonPrices { static const int hairStyle = 300; static const int hairColor = 200;
  static int priceFor(MaiLook from, MaiLook to); } // đổi kiểu +300, đổi màu +200, không đổi → 0
```
`MaiLook.defaults` phải trông **y hệt Mai hiện nay**. dev-game ánh xạ enum sang hình và màu trong `chibi_characters.dart`; core không chứa màu.

`lib/core/city/player_level.dart`:
```dart
class PlayerLevel {
  static const int maxLevel = 30;
  static int xpToReach(int level);   // tổng XP để đạt cấp level; cấp 1 = 0; tăng dần (ví dụ 100*(l-1)^1.5 làm tròn)
  static int levelForXp(int xp);     // kẹp 1..30
  static double progress(int xp);    // 0..1 trong cấp hiện tại; ở cấp 30 → 1
}
```

`lib/core/city/restaurant_menu.dart`:
```dart
class Dish { final String id, nameKey; final int price, xp; const Dish(...); }
class RestaurantMenu {
  static const List<Dish> dishes = [ // id, nameKey, price, xp
    Dish('fish_soup', 'dishFishSoup', 120, 40), Dish('omelette_rice', 'dishOmeletteRice', 160, 55),
    Dish('veggie_curry', 'dishVeggieCurry', 200, 70), Dish('seafood_noodles', 'dishSeafoodNoodles', 260, 90)];
  static int xpFor(Dish d, int timesEatenToday); // lần đầu trong ngày 100%, các lần sau 25% (làm tròn, tối thiểu 1)
}
```

`lib/core/city/city_wallet.dart` là ChangeNotifier, giữ trong bộ nhớ:
```dart
class EatResult { final bool ok; final int xpGained; final bool reducedXp; final int? newLevel; }  // newLevel != null khi lên cấp
class CityWallet extends ChangeNotifier {
  CityWallet({int coins = 1500, int xp = 0, MaiLook look = MaiLook.defaults});
  int get coins; int get xp; int get level; MaiLook get look;
  bool get fullBuff;                 // buff "No bụng" (+10% tip ca sau; giai đoạn 3 mới dùng)
  bool canAfford(int price);
  EatResult eat(Dish dish);          // thiếu xu → ok=false, không đổi gì; ok → trừ xu, cộng XP, đếm lần ăn trong ngày, bật fullBuff
  bool buyLook(MaiLook to);          // giá = SalonPrices.priceFor(look, to); thiếu xu → false
  int? addXp(int xp);                // trả cấp mới nếu lên cấp
  bool markFirstVisit(String lotId); // lần đầu ghé → true và +firstVisitXp
  static const int firstVisitXp = 50;
  void newDay();                     // xoá bộ đếm ăn trong ngày (giai đoạn 1 chưa gọi)
}
```

## Giao diện mà dev-game phụ A cung cấp

`lib/game/town3d/town_layout.dart`:
```dart
class TownPoint { final double x, z, yaw; const TownPoint(this.x, this.z, [this.yaw = 0]); }
class TownLotSpots {
  final String lotId;
  final TownPoint door;             // điểm vào cửa
  final TownPoint? counter;         // chỗ Mai đứng để thao tác với quầy (quán ăn, tiệm tóc)
  final TownPoint? keeper;          // chỗ chủ tiệm NPC đứng sau ô cửa
  final TownPoint? seat;            // ghế hiên của quán ăn, nơi Mai ngồi
}
class TownLayout {
  static TownLayout forDistrict(DistrictDef d);
  final List<Shop3dProp> props;     // đồ tĩnh để gộp lưới (pickable: false)
  final List<Aabb2> blockers;       // hộp chặn điều hướng (minX, minZ, maxX, maxZ)
  final Map<String, TownLotSpots> spots;
}
```
`lib/game/town3d/town_batches.dart` gộp lưới theo ô 16 m × vật liệu, đi lại `Shop3dBatches` / `Shop3dMeshBuilder`.

**Ngân sách mỗi quận:** ≤40 entity tĩnh, ≤20k tam giác tĩnh, ≤8 material (dùng chung với nội thất). Có test `town3d_batches_test`.

## Kế hoạch 6 giai đoạn
1. Phố Tiệm Bánh, quán ăn, tiệm tóc, HUD (tài liệu này).
2. Save v3 cùng migration. App mở thẳng vào thành phố. Gỡ 50 màn. Mở khoá theo cấp Mai.
3. Ghép 6 trạm làm bánh vào tiệm. Ca bán hàng có tổng kết. Phản hồi của khách về trạm chưa đạt.
4. Văn phòng địa ốc, chi nhánh, nhân viên, két 8 giờ.
5. Quận 2 "Phố Chợ Biển" (chợ, quần áo, cà phê, nhiệm vụ, quà đăng nhập) và xe buýt.
6. Tiệm sau alpha, cân kinh tế, `/quality-gate`.
