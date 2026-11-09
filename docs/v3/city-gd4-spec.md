# Thành phố V3, Giai đoạn 4: Văn phòng địa ốc, chi nhánh, nhân viên, két 8 giờ

Kiến trúc sư viết, trưởng phòng duyệt ngày 05/11/2026. **Chỉ code theo chữ ký đã chốt ở §8.** Tài liệu nền: `city-gd1..3-spec.md`, `thermion-api-notes.md` (§26 nói cách test trong gói tạm, §27 cách đo).

## Mặc định đã chốt (chủ dự án có thể đổi sau)
1. Không có lương định kỳ. Nhân viên chỉ tốn phí thuê một lần; cho nghỉ thì hoàn 50% phí.
2. Quản lý gửi 25% tiền bán về ví, nên két đầy sau khoảng 10,7 giờ. Trần két vẫn là 8 giờ tiền.
3. Chống chỉnh giờ:
   - giờ máy lùi thì két tạm nghỉ;
   - giờ máy lùi quá 72 giờ thì đặt lại mốc;
   - rủi ro chấp nhận được: mỗi vòng chỉnh giờ chỉ kiếm thêm tối đa 1 két đầy.
4. Nhân viên mới: Biscuit/Bánh Quy, Nutmeg/Hạt Dẻ, Cocoa/Ca Cao, Maple/Lá Phong, cùng Ami và Hạnh có sẵn. Chủ văn phòng địa ốc dùng chibi `regular_12` (schnauzer).
5. Có quảng cáo thưởng "x2 lần thu": mỗi chi nhánh 1 lần/ngày, chỉ khi số tiền thu ≥ 50% trần két.
6. Mở app sau khi vắng: chỉ hiện một toast, không mở bảng.
7. Mặt tiền chi nhánh ở dãy phía nam chỉ thấy rõ ở góc cận (khi mở bảng). Camera thường chỉ thấy sân trước, mái hiên và mái nhà.
8. Cuối game, người chơi ít có thể kiếm từ chi nhánh mỗi ngày nhiều hơn từ ca bán. Chấp nhận, sẽ cân lại ở GĐ6.

## 0. Ràng buộc 3D
- Camera phố đặt phía nam Mai và nhìn về bắc: xoay ±60°, nghiêng 40–50°, cách 10–12 m (`town_camera.dart:22-24`, `:47-52`).
- Lô s1, s3, s4 có cửa quay về hướng −z (`city_config.dart:167-222`), nên camera thường không thấy chính diện.
- **Nhà cao sẽ che Mai.** Vì vậy mọi khối của chi nhánh phải nằm dưới **đường bao** `y ≤ 0,6 + 0,8·d`, với d (m) là khoảng cách từ mép vỉa hè vào trong lô.
  - Tường trước lùi vào d ≥ 2,4 m và cao tối đa 2,6 m.
  - Mái lệch, dốc lên về phía sau.
  - Chi tiết từng cấp đặt ở chỗ nhìn được từ trên xuống: sân, mái hiên sọc, ô dù, biển hai mặt, màu mái, nhân viên đứng ở sân.
- Khi Mai đứng giữa đường thì lô phía nam nằm ngoài khung hình. Vì vậy **minimap là tín hiệu chính báo két đầy**.

## 1. Chỗ móc vào code
| Việc | Chỗ |
|---|---|
| Lô | `lib/core/city/city_config.dart`: n1 `:111-124`, s1 `:167-180`, s3 `:195-208`, s4 `:209-222`; `LotDef` `:6-45` |
| Vùng, nút A | `town_rules.dart`: `TownAction` `:22-35`, `zonesOf` `:103-109`, `actionFor` `:139-147` |
| Băng tên | `TownBannerNote` `:59-72`, `bannerFor` `:153-160`; hiển thị ở `town3d_view.dart:523-533` |
| Nút A trong view | `_pressA` `town3d_view.dart:625-641`; `_actionOf` `:1353-1358`; `_TownButtons` `:1229-1238`, `:1461` |
| Bảng 2D | `enum _Sheet` `:155`; `_sheetLayer` `:1306-1351` (mẫu `RestaurantSheet` `:1312-1319`); `_menuCloseUp` `:618-621`; Esc `:1034-1047`; toast `_toasts.show` `:535`; bộ đếm 1 Hz `_fpsTimer` `:307` |
| Mặt tiền | `town_layout.dart`: `_lot` `:599-626`; `_emptyLot` `:1147-1208`; `_realty` `:1076-1117`; mẫu ô quầy `_hatch` `:913-945`; chỗ đứng ở tiệm tóc `:1053-1059`; cache `forDistrict` `:85-86` |
| Gộp lưới | `town_batches.dart:80-123` (ô 16 m); dựng lưới tĩnh `town_scene.dart:134-170`; `setActive` `:454` |
| Điều hướng | `TownPilot` dựng `nav` một lần (`town_pilot.dart:99-101`), nên hộp chặn phải cố định; chủ quán `:106-114`; `_keeperOf` `:235-246`; `_decide` `:321-328`; `beginMenu` `:378-386` |
| Bản đồ | `ui/town/minimap.dart`: `townLotColor` `:13-20`, tô lô `:95-103`; `town_map_sheet.dart:152` |
| Ví và game | `CityWallet.earn` `city_wallet.dart:138-144`; `CityGame` `city_game.dart:32-41`, `refreshDay` `:105-111`, `toSave` `:204-222`, `restore` `:225-250` |
| Save | `city_save.dart`: `branches`/`staff` lưu thô (`:42-43`, `:131-133`); decode `:311-322`; toJson `:163-164`; `knownKeys` `:77-96`. Store: merge `city_save_store.dart:174-179`, `_refreshDay` `:167-169`, `resetAll` `:223-238`. `main.dart:84-88` |
| Nối view | `town3d_page.dart:111-127` |
| Quảng cáo | `AdPlacement` `core/models/ids.dart:88`; `AdService` `core/services/ad_service.dart:13-22` |
| Chibi | `staff_ami`, `staff_hanh` (`chibi_characters.dart:36-37`). Bao và Theo làm ở tiệm của bà nên không dùng. Mỗi chibi khoảng 9 entity, 3k tam giác |

## 2. Dữ liệu và API (core, Dart thuần, thư mục `lib/core/branch/`)
```dart
// city_config.dart
class LotDef { ...; final int baseIncome; /* xu/giờ ở cấp 1; 0 = không phải chi nhánh */ } // s1 150, s3 250, s4 400
extension on DistrictDef { int branchNumber(String lotId); } // s1=1, s3=2, s4=3

// branch_economy.dart
abstract final class BranchEconomy {
  static const maxLevel = 5;
  static const tillTime = Duration(hours: 8);
  static const levelPct = [100, 125, 150, 175, 200];
  static const upgradeCostFrac = [0.25, 0.40, 0.60, 0.85]; // lên cấp 2..5 = phân số × giá lô, làm tròn tới 500
  static const upgradeLevelPlus = [0, 2, 5, 8];            // cấp Mai cần = lot.requiresLevel + …
  static const dismissRefundPct = 50, doubleMinPct = 50;
  static int slotsFor(int level) => level >= 3 ? 2 : 1;
  static int upgradeCost(LotDef lot, int toLevel);
  static int upgradeLevelReq(LotDef lot, int toLevel);
  static int rateMilliPerHour(LotDef lot, int level, {int bonusPct = 0}); // base*levelPct*(100+bonus)/10
  static int ratePerHour(LotDef lot, int level, {int bonusPct = 0});
  static int capMilli(LotDef lot, int level, {int bonusPct = 0});         // 8 × rate
  static ProduceResult produce({required int tillMilli, required int rateMilliPerHour,
      required int capMilli, int depositPct = 0, required int ms, int carry = 0});
}
class ProduceResult { final int tillMilli, depositMilli, usedMs, carry; }

// staff.dart
enum StaffRole { server, baker, manager }
class StaffDef { final String id, nameKey; final StaffRole role;
  final int hireCost, requiresLevel, bonusPct, depositPct; const StaffDef(...); }
abstract final class StaffRoster { static const List<StaffDef> all; static StaffDef? byId(String id); }
class StaffMember { final String id, lotId; final int since; /* toJson, == */ }

// branch_state.dart
class BranchState { final String lotId; final int level, tillMilli, boughtAt, earned; final String adDate; }
class BranchBook {
  BranchBook({int clock = 0, Map<String, BranchState> lots = const {}, List<StaffMember> staff = const [],
      Map<String, Object?> extraLots = const {}, List<Object?> extraStaff = const []});
  Map<String, Object?> branchesJson(); List<Object?> staffJson();
  static ({BranchBook book, List<String> bad}) decode(Object? branches, Object? staff);
}

// till_clock.dart
enum ClockAnomaly { none, first, behind, rescued }
class ClockStep { final int creditMs, markMs; final ClockAnomaly anomaly; }
abstract final class TillClock {
  static const rollbackTolerance = Duration(minutes: 10), rescueAfter = Duration(hours: 72);
  static ClockStep wall({required int markMs, required int wallMs});
  static ClockStep mono({required int markMs, required int monoDeltaMs});
}

// city_branches.dart
class CityBranches extends ChangeNotifier {
  CityBranches({required CityWallet wallet, required DateTime Function() clock,
      Duration Function()? mono, DistrictDef? district});
  bool owns(String lotId); List<String> get owned;
  BranchView? view(String lotId);
  List<StaffMember> get staff; List<StaffMember> staffAt(String lotId);
  Set<String> get fullLots; int get totalTill; ClockAnomaly get anomaly;
  BranchBuy buy(String lotId);
  BranchUpgrade upgrade(String lotId);
  BranchCollect collect(String lotId);
  bool canDouble(String lotId); int applyDouble(String lotId);
  StaffHire hire(String staffId, String lotId); StaffDismiss dismiss(String staffId);
  BranchAway resume(); BranchAway? takeAway();
  BranchBook snapshot(); void restore(BranchBook b);
}
class BranchView { final String lotId; final int branchNo, level, till, cap, ratePerHour, bonusPct,
  depositPct, slots; final Duration fullIn; final bool full; final int? nextCost, nextLevelReq,
  nextRatePerHour, nextCap; }
class BranchAway { final Duration away; final int sold, deposited; final ClockAnomaly anomaly;
  bool get worthToast => away >= const Duration(minutes: 30) && sold + deposited > 0; }
enum BranchBuy { ok, notBranch, owned, levelTooLow, notEnoughCoins }
enum BranchUpgrade { ok, notOwned, maxLevel, levelTooLow, notEnoughCoins }
class BranchCollect { final int coins; final bool wasFull; bool get ok => coins > 0; }
enum StaffHire { ok, unknown, taken, notOwned, noSlot, levelTooLow, notEnoughCoins }
class StaffDismiss { final bool ok; final int collected, refund; }
```

**Luật**
- **Sản xuất tiền:**
  - `rate = base × levelPct × (100 + Σ bonusPct)`; `cap = 8 giờ × rate`.
  - Két nhận (1 − depositPct) × rate, ví nhận depositPct × rate. Cả hai dừng khi két ≥ cap.
  - Tính bằng mili-xu nguyên, có `carry` giữ phần dư nên chia bước nào cũng ra cùng kết quả (lệch ≤ 1 xu). `carry` không lưu vào save.
- **Ghi:** settle (bù sản lượng theo đồng hồ đơn điệu) → `wallet.earn` phần quản lý gửi về → đổi trạng thái → `notifyListeners` đúng 1 lần.
- **Đọc** (`view`, `fullLots`, `totalTill`): cũng settle, nhưng không notify.
- **Thu tiền** (`collect`):
  - lấy phần nguyên xu, giữ phần lẻ, cộng vào `earned`;
  - `canDouble` khi lần thu đó ≥ 50% cap và `adDate` ≠ hôm nay;
  - `applyDouble` cộng thêm đúng số xu vừa thu, đặt `adDate`, mỗi lần thu chỉ dùng được một lần.
- **Thuê** (`hire`): nhân viên chưa làm ở đâu, lô đã mua, còn chỗ, đủ cấp Mai, đủ xu.
- **Cho nghỉ** (`dismiss`): thu hết két vào ví, gỡ nhân viên, hoàn 50% phí (làm tròn xuống).
- **Nâng cấp** (`upgrade`): chỉ đổi `level`; két giữ nguyên. Khi `restore`, kẹp két ≤ cap.
- **Mua lô** (`buy`): trừ xu, thêm lô ở cấp 1; nếu `clock == 0` thì đặt `clock` = giờ máy.

**Thời gian (`TillClock`)**
- Dùng `millisecondsSinceEpoch` (UTC), nên đổi múi giờ không ảnh hưởng. Ngày lịch chỉ dùng cho x2 quảng cáo.
- `branches.clock` là mốc đã tính tới (không bao giờ lùi). Không dùng `savedAt`.
- **Trong phiên** (`mono`): dùng `Stopwatch` đơn điệu; `mark += monoΔ`.
- **Mở app / quay lại app** (`wall`): settle theo đồng hồ đơn điệu trước, rồi xét `d = giờ máy − mark`:

  | Trường hợp | Kết quả | Cộng thời gian | Mốc `mark` |
  |---|---|---|---|
  | `mark == 0` | `first` | không | đặt = giờ máy |
  | `d ≥ 0` | `none` | cộng `d` (trần két tự kẹp) | đặt = giờ máy |
  | −10 phút ≤ d < 0 | `none` | không | giữ nguyên |
  | −72 giờ ≤ d < −10 phút | `behind` | không | giữ nguyên |
  | d < −72 giờ | `rescued` | không | đặt = giờ máy (két giữ nguyên) |

  Xong thì đặt lại mốc của đồng hồ đơn điệu, để không cộng hai lần.
- `CityGame`:
  - thêm `final CityBranches branches` và tham số ctor `Duration Function()? mono`;
  - `toSave()` gọi `branches.snapshot()` **trước** khi đọc ví;
  - `restore` gọi `branches.restore`;
  - thêm `BranchAway resume([DateTime? now])` = `refreshDay` + `branches.resume()`.
- Store gọi `game.resume()` sau khi nạp; autosave merge thêm `game.branches`; `main.dart` dùng `onShow: game.resume`. `resetAll` xoá chi nhánh và nhân viên.

**Save** (không tăng `v`; `CitySave.branches` đổi kiểu thành `BranchBook`, bỏ field `staff` riêng; JSON vẫn có 2 khoá):
```json
"branches": {"clock": 1762300000000,
  "lots": {"s1": {"lv": 2, "till": 845123, "bought": 1762200000000, "earned": 12345, "ad": "2026-11-05"}}},
"staff": [{"id": "ami", "lot": "s1", "since": 1762250000000}]
```
- Kẹp giá trị:
  - `clock`, `bought`, `earned`: [0, 2^53−1];
  - `lv`: 1..5;
  - `till` ≥ 0 (khi restore thì ≤ cap);
  - `ad` sai dạng thì về `''`.
- Không phải Map/List thì về mặc định, ghi vào `bad`, backup 1 lần. Mục con sai thì ghi `branches.s1.lv`.
- Lô lạ giữ trong `extraLots`; nhân viên lạ giữ trong `extraStaff`.
- Nhân viên ở lô chưa mua, trùng id, hoặc vượt số chỗ thì bỏ và ghi vào `bad`.
- Save GĐ3 (`{}`/`[]`) nạp ra sổ rỗng.

## 3. Bảng số
| Lô | Giá | Cấp Mai | Xu/giờ cấp 1..5 | Két 8 giờ cấp 1..5 | Nâng lên cấp 2/3/4/5 (xu) | Cấp Mai cần để nâng |
|---|---|---|---|---|---|---|
| s1 | 8 000 | 5 | 150/188/225/263/300 | 1 200/1 500/1 800/2 100/2 400 | 2 000/3 000/5 000/7 000 | 5/7/10/13 |
| s3 | 20 000 | 10 | 250/313/375/438/500 | 2 000/2 500/3 000/3 500/4 000 | 5 000/8 000/12 000/17 000 | 10/12/15/18 |
| s4 | 45 000 | 15 | 400/500/600/700/800 | 3 200/4 000/4 800/5 600/6 400 | 11 500/18 000/27 000/38 500 | 15/17/20/23 |

Số chỗ nhân viên: cấp 1–2 có 1 chỗ; cấp 3–5 có 2 chỗ.

| id | Chibi | en / vi | Vai | Phí thuê | Hiệu ứng | Cấp Mai |
|---|---|---|---|---|---|---|
| biscuit | `regular_01` | Biscuit / Bánh Quy | phục vụ | 1 500 | +10% | 5 |
| nutmeg | `regular_04` | Nutmeg / Hạt Dẻ | phục vụ | 1 500 | +10% | 5 |
| ami | `staff_ami` | Ami / Ami | thợ bánh | 3 500 | +20% | 8 |
| hanh | `staff_hanh` | Hanh / Hạnh | quản lý | 6 000 | gửi 25% tiền bán về ví | 10 |
| cocoa | `regular_11` | Cocoa / Ca Cao | thợ bánh | 3 500 | +20% | 12 |
| maple | `regular_07` | Maple / Lá Phong | thợ bánh | 3 500 | +20% | 16 |

**Mô phỏng** (C1 đo bằng `test/core/branch/branch_economy_sim_test.dart`, 8 seed; bảng tay cũ ghi trong ngoặc):
- Dồn tiền mua lô: mua s1 ở ca 10–11, s3 ở ca 23–24, s4 ở ca 44–47 (cũ: 13 / 29 / 59).
- Chơi cân bằng (luôn làm việc rẻ nhất: nâng cấp, thuê, mua lô kế): s3 ở ca 32–35, s4 ở ca 60–63 (cũ: 34 / 66–70).
- Một két 8 giờ của s1 cấp 1 = 1 200 xu, bằng 1,18–1,47 ca ở cấp Mai 5–9 (cũ: 1,7).
- Lệch vì ca bán thực tế ròng ~820–1 020 xu ở cấp 5–9 (~1 150–1 300 xu ở cấp 11–23), cao hơn mức ~700 xu mà bảng tay
  giả định. Mai lên cấp 15 quanh ca 24 nên cổng cấp của lô không chặn; chỉ xu là nút thắt. Trưởng phòng chốt 05/11: giữ
  `baseIncome` 150/250/400, nới mục tiêu ở §7-12.
- Chi nhánh không cho XP. Khi đang chơi, ca bán được khoảng 13 nghìn xu/giờ, còn ba chi nhánh ở cấp tối đa chỉ khoảng 3 nghìn xu/giờ.
- x2 quảng cáo: thêm `AdPlacement.branchDouble` ở **cuối** enum; dùng chung hạn 12 lần/ngày.

## 4. Luồng UI
1. **Văn phòng địa ốc (n1).**
   - Thêm ô quầy và chủ văn phòng (`regular_12`) ở local l = +3. Vùng quầy quanh (−15, −5,0), cách vùng cửa 3 m.
   - Băng tên bỏ "Sắp mở".
   - Bấm nút A "Xem lô đất" thì gọi `pilot.beginCounter()`, camera chuyển sang góc cận, mở `_Sheet.realty`.
   - `RealtySheet` (bảng bên phải), mỗi lô có:
     - "Lô số n" và giá;
     - "Mở ở cấp N" kèm ổ khoá, hoặc "Của bạn";
     - "~xu/giờ" và "Két 8 giờ: xu";
     - nút "Mua" (mờ kèm lý do nếu chưa mua được).
   - Bấm "Mua" thì hiện panel xác nhận ngay trong bảng, rồi gọi `buy`. Sau đó đóng bảng, hiện toast "Chi nhánh n khai trương!", đổi mặt tiền 3D và minimap.
2. **Cửa chi nhánh đã mua.**
   - Băng tên: "Chi nhánh n" + "Cấp L · Két x/y xu", hoặc "Két đầy!".
   - Nút A:
     - két ≥ 1 xu → **"Thu tiền"**: thu ngay, toast, Mai vui, nhân viên vẫy tay. Nếu được x2 thì `BranchDoubleChip` hiện 8 s trên nút A.
     - két = 0 → **"Chi nhánh"**: mở `BranchSheet` với camera cận nhìn mặt tiền (yaw ≈ π − 0,5).
   - `BranchSheet` có 3 thẻ:
     - **Két:** thanh tiến độ, xu/giờ, "Đầy sau …" hoặc "Đầy rồi…", nút "Thu N xu", ghi chú khi giờ máy đang lùi.
     - **Nâng cấp:** thông tin cấp kế, giá hoặc lý do chưa nâng được, hoặc "Tối đa".
     - **Nhân viên:** "a/b chỗ"; người đang làm (icon vai trò, tên, hiệu ứng, "Cho nghỉ" có xác nhận); danh sách để thuê. Dùng icon vai trò, không dùng ảnh chân dung.
3. **Lô chưa mua nhưng đủ cấp:** băng tên `townLotUnlocked` (đã đổi nội dung); nút A không có thao tác.
4. **Mở app sau khi vắng:**
   - nếu `takeAway().worthToast` thì hiện toast `branchAwayToast` (+ `branchDepositToast` nếu có tiền quản lý gửi về);
   - nếu `behind` thì hiện `branchClockBehind`.
5. **Minimap / bản đồ lớn:**
   - lô đã mua tô màu nhấn: s1 hồng dâu, s3 bạc hà, s4 vàng bơ;
   - két đầy có huy hiệu đồng xu (vẽ bằng path);
   - bản đồ lớn ghi thêm "Cấp L";
   - dữ liệu qua `TownBranchMarks`.

## 5. 3D
- `TownLayout.forDistrict` không còn chứa đồ của lô chi nhánh, chỉ giữ hộp chặn cố định `[-5,4; 5,4] × [0,3; 9,95]` (local) cho mọi cấp. Lô trống có hàng rào trước kín (cổng đóng).
- `TownLayout.branchFacade(lot, level)` (level 0 = lô trống) đi qua `TownBatches.buildLot`, mỗi lô tối đa 2 lưới. `TownScene.setBranchLevel` dựng lưới mới xong mới gỡ lưới cũ.

| Cấp | Mô tả | Tam giác tối đa |
|---|---|---|
| 0 | Lô trống: rào kín, biển hai mặt, cây non | 1 000 |
| 1 | Tiệm nhỏ mái lệch màu nhấn, tường trước d = 2,4 cao 2,5 m, 1 cửa sổ sáng, cửa, biển cupcake hai mặt ở sân | 800 |
| 2 | + mái hiên sọc + 2 chậu hoa | 950 |
| 3 | + nhà rộng hết lô, 2 cửa sổ, 1 bàn có ô dù | 1 100 |
| 4 | + mái hiên dài + dây đèn + bồn hoa cửa sổ | 1 200 |
| 5 | + ô cửa trên mái / ống khói, sao vàng trên biển, 2 đèn lồng | 1 300 |

- **Nhân viên đứng ở sân:**
  - mỗi lô tối đa 1 chibi, ưu tiên quản lý > thợ bánh > phục vụ, rồi tới người vào làm trước;
  - vị trí l = −1,6, d = 1,0, quay ra đường;
  - chỉ đưa vào scene khi |Mai.x − lô.x| ≤ 12 m và Mai.z ≥ −1, hoặc khi đang ở góc cận của lô đó;
  - tối đa 2 chibi cùng lúc.
- **Biểu tượng két đầy:** bóng nói kem + chồng xu, khoảng 150 tam giác, đặt ở l = +2,5, d = 1,4, y = 2,3. Lắc nhẹ. Chỉ hiện khi két đầy và Mai không đứng ở vùng cửa lô đó.
- **Ngân sách:** tổng tĩnh ≤ 20k tam giác (mục tiêu 19,5k), ≤ 40 entity, ≤ 8 material.
  - Nếu vượt thì cắt theo thứ tự:
    1. Cầu trang trí dùng (6, 10) thay (8, 12) (tham số tuỳ chọn của `Shop3dMeshBuilder`).
    2. Đơn giản hoá nửa sau của nhà.
    3. Bỏ hàng rào sau.
  - Hiệu năng: đứng giữa s1 và s3 có 2 nhân viên thì rAF 60 ở 1280×720, chip `dart` ≤ 1,0 ms.

## 6. Khoá arb
**Thêm mới** (số dùng `"format": "decimalPattern"`):

| Khoá | en | vi | Placeholder |
|---|---|---|---|
| townActionCollect | Collect | Thu tiền | |
| townActionBranch | Branch | Chi nhánh | |
| townActionRealty | Browse lots | Xem lô đất | |
| realtyLotN | Lot {n} | Lô số {n} | n:int |
| realtyOwned | Yours | Của bạn | |
| realtyConfirmTitle | Buy this lot? | Mua lô này? | |
| realtyConfirmBody | {price} coins. It becomes a little branch that sells on its own. | {price} xu. Lô sẽ thành một chi nhánh nhỏ tự bán hàng. | price:int |
| branchOpenedToast | Branch {n} is open! | Chi nhánh {n} khai trương! | n:int |
| branchBannerTill | Level {level} · Till {coins}/{cap} | Cấp {level} · Két {coins}/{cap} xu | level, coins, cap: int |
| branchBannerFull | Level {level} · Till full! | Cấp {level} · Két đầy! | level:int |
| branchIncome | ~{coins} coins/hour | ~{coins} xu/giờ | coins:int |
| branchTillCap | Till holds {coins} coins (8 h) | Két chứa {coins} xu (8 giờ) | coins:int |
| branchTill | Till | Két | |
| branchTillFull | Full — collect to keep selling | Đầy rồi — thu tiền để bán tiếp | |
| branchFullIn | Full in {time} | Đầy sau {time} | time:String |
| branchCollect | Collect {coins} | Thu {coins} xu | coins:int |
| branchCollectedToast | +{coins} coins from the branch | +{coins} xu từ chi nhánh | coins:int |
| branchUpgrade | Upgrade · {coins} | Nâng cấp · {coins} xu | coins:int |
| branchNextLevel | Level {level}: {coins} coins/hour | Cấp {level}: {coins} xu/giờ | level, coins: int |
| branchNeedMaiLevel | Mai needs level {level} | Cần Mai cấp {level} | level:int |
| branchUpgradedToast | Branch {n} is now level {level}! | Chi nhánh {n} lên cấp {level}! | n, level: int |
| branchStaff | Staff | Nhân viên | |
| branchSlots | {used}/{total} spots | {used}/{total} chỗ | used, total: int |
| branchNoSlot | No free spot — level 3 adds one | Hết chỗ — cấp 3 có thêm một chỗ | |
| branchHire | Hire · {coins} | Thuê · {coins} xu | coins:int |
| branchDismiss | Let go | Cho nghỉ | |
| branchDismissConfirm | {name} will take a long rest. You get {coins} coins back. | {name} sẽ nghỉ dài ngày. Bạn được hoàn {coins} xu. | name:String, coins:int |
| branchHiredToast | {name} now works at Branch {n} | {name} bắt đầu làm ở Chi nhánh {n} | name:String, n:int |
| branchWorksAt | Works at Branch {n} | Đang làm ở Chi nhánh {n} | n:int |
| staffRoleServer / staffRoleBaker / staffRoleManager | Server / Baker / Manager | Phục vụ / Thợ bánh / Quản lý | |
| staffEffectBonus | +{pct}% sales | +{pct}% doanh thu | pct:int |
| staffEffectDeposit | Sends {pct}% of sales home | Gửi {pct}% tiền bán về ví | pct:int |
| charAmi / charHanh / charBiscuit / charNutmeg / charCocoa / charMaple | Ami / Hanh / Biscuit / Nutmeg / Cocoa / Maple | Ami / Hạnh / Bánh Quy / Hạt Dẻ / Ca Cao / Lá Phong | |
| branchAwayToast | While you were away your branches sold {coins} coins — drop by to collect! | Trong lúc bạn đi vắng, các chi nhánh đã bán được {coins} xu — ghé thu nhé! | coins:int |
| branchDepositToast | Your manager sent home +{coins} coins | Quản lý gửi về +{coins} xu | coins:int |
| branchClockBehind | Your device clock is behind your last visit, so the till is resting. | Giờ trên máy đang chậm hơn lần chơi trước nên két tạm nghỉ. | |

**Sửa nội dung:**
- `townLotUnlocked`: "Unlocked · for sale at Harbor Realty" / "Đã mở · đang bán ở văn phòng địa ốc".

**Dùng lại:** `townBranchN`, `townLotLocked`, `cityRealtyName`, `commonBuy/Max/Confirm/Cancel`, `cityNotEnoughCoins`, `offlineDouble`, `offlineDuration*`, `adRewardGranted`, `adsLimitReached`.

## 7. Test
Dùng thời gian giả: `CityGame(clock: () => now, mono: () => monoNow)`.

**Core** (`test/core/branch/**`, sửa `test/core/save/**`)
1. Bảng kinh tế: xu/giờ, trần, giá nâng cấp, cấp Mai cần, số chỗ, thưởng nhân viên cộng dồn.
2. `produce`:
   - tăng tuyến tính, dừng ở trần;
   - quản lý chia 75/25;
   - 3 600 bước × 1 s bằng 1 bước 1 giờ.
3. `TillClock`:
   - `first`, chạy thường, lùi trong 10 phút, `behind` rồi giờ máy đuổi kịp, `rescued`, năm 1970;
   - trong phiên dùng đồng hồ đơn điệu;
   - đổi múi giờ → 0;
   - +1 năm → chỉ đầy két.
4. Gian lận: chỉnh giờ tới 8 giờ, thu, rồi lùi lại → 16 giờ thật vẫn ra bằng chơi thật (±1 két). Lùi giờ nhiều lần → 0.
5. `buy`: đủ 5 kết quả; mua lô đầu thì đặt mốc; notify 1 lần.
6. `collect` / x2: phần nguyên và phần lẻ; `earned`; điều kiện ≥ 50%; 1 lần/ngày.
7. `upgrade`: các trường hợp bị chặn; settle theo tốc độ cũ trước khi nâng.
8. `hire` / `dismiss`: trùng người, hết chỗ, thiếu cấp, thiếu xu; quản lý gửi về ví; cho nghỉ thì thu két, hoàn 50%, trả chỗ.
9. `resume`: trả `BranchAway`; `takeAway` chỉ trả 1 lần; không cộng hai lần.
10. Save:
    - lưu rồi nạp lại giữ nguyên; thiếu khoá thì mặc định; sai kiểu thì `bad` + backup 1 lần;
    - giữ lô và nhân viên lạ; kẹp `lv`/`till`; bỏ nhân viên ở lô chưa mua;
    - nạp được save GĐ3; JSON thô vẫn là Map/List;
    - `toSave` settle trước khi đọc ví.
11. Store: autosave nghe `branches`; `resetAll` xoá chi nhánh; quay lại app thì gọi `resume`.
12. Mô phỏng (in bảng), mỗi ngày 2 phiên × 4 ca, hai phiên cách 12 giờ:
    - dồn tiền: s3 ở ca 22–36, s4 ở ca 42–70 (nới 05/11, trước là 24–36 / 50–70);
    - cân bằng: s3 ở ca 28–40, s4 ở ca 58–80;
    - tiền chi nhánh tới lúc có s4: dồn tiền ≤ 40% (đo 29–32%); cân bằng ≤ 50% (chốt tạm 05/11, chờ chủ dự án; đo
      48–50% — bot nâng tối đa và thuê đủ trước khi mua lô kế, chỉnh `levelPct` / `upgradeCostFrac` không hạ dưới 40%
      mà không làm nâng cấp vô nghĩa);
    - két 8 giờ của s1 cấp 1 = 1,15–2,0 ca ở cấp Mai 5–9 (nới 05/11, trước là 1,2–2,0).
13. `CityDebugParams` (chỉ khi dùng save bộ nhớ): `branches=s1:3,s3:1`, `staff=ami@s1`, `till=full`, `away=9`.

**Game** (`test/game/town3d/**`, không import thermion)
1. `actionFor`: lô đã mua → branch; lô chưa mua → none; quầy địa ốc → realty; cửa địa ốc → none.
2. `bannerFor`: đã mua → branch; chưa mua nhưng đủ cấp → unlocked; thiếu cấp → locked.
3. Layout:
   - văn phòng địa ốc có quầy và chủ văn phòng; vùng quầy không chồng vùng cửa;
   - hộp chặn giống nhau ở mọi cấp;
   - mặt tiền cấp 0..5 không rỗng, nằm trong lô, dưới đường bao, không lấn vỉa hè.
4. Ngân sách: tĩnh + 3 lô ở cấp 5 ≤ 20k tam giác / 40 entity / 8 material; số tam giác tăng theo cấp và ≤ bảng §5; in số từng lô.
5. `TownBranchCast.plan`: đúng thứ tự ưu tiên, khoảng LOD, tối đa 2; lô không có nhân viên thì không có chibi.
6. `TownPilot`: có chủ văn phòng địa ốc; `beginCounter` / `endCounter`; đổi `ownedLots` thì gọi lại `_decide`.

**UI** (`test/ui/town/**`)
1. `RealtySheet`: 3 dòng; các trạng thái khoá / của bạn / thiếu xu; mua → xác nhận → `onBuy`; Esc đóng.
2. `BranchSheet`: két; nút thu chỉ bật khi ≥ 1 xu; lý do chưa nâng cấp được; thuê / cho nghỉ có xác nhận; ghi chú giờ máy lùi.
3. Minimap / bản đồ lớn: màu lô đã mua, huy hiệu két đầy.
4. `BranchDoubleChip`: tự ẩn khi hết giờ; gọi `onTap`.
5. Vùng chạm ≥ 48 dp; không tràn chữ vi/en ở 1280×720, 1600×720, 800×360.

## 8. Chữ ký chốt
Core: toàn bộ §2.
```dart
// game
enum TownAction { none, enterShop, orderFood, getHaircut, realty, branch }
enum TownBannerNote { none, comingSoon, locked, unlocked, branch }
TownRules.actionFor(TownZone? z, {Set<String> owned = const {}});
TownRules.bannerFor(LotDef lot, int level, {bool owned = false});
static double TownRules.branchEnvelope(double d);
static List<Shop3dProp> TownLayout.branchFacade(LotDef lot, int level);
static Map<Shop3dSurfaceKey, Shop3dMesh> TownBatches.buildLot(LotDef lot, int level);
TownPilot: static const realtyKeeperId = 'regular_12'; set ownedLots(Set<String>); void beginCounter(); void endCounter(); // TownMode.counter
class TownBranchActor { final String lotId, staffId, chibiId; final TownPoint at; }
abstract final class TownBranchCast { static const Map<String,String> chibiOf; static const lodRange = 12.0, maxVisible = 2;
  static List<TownBranchActor> plan(TownLayout t, Map<String, List<StaffMember>> staffByLot, double maiX, double maiZ, {String? focusLot}); }
TownScene: Future<void> setBranchLevel(String lotId, int level); void setFullIcons(Set<String> lots); void setBranchActors(List<TownBranchActor> a);
Town3dView({..., CityBranches? branches, Future<bool> Function(BuildContext)? watchBranchAd, bool Function()? canWatchBranchAd});
// ui
class TownBranchMarks { const TownBranchMarks({Set<String> owned, Set<String> full, Map<String,int> levels}); static const none; } // minimap.dart
TownMinimap(..., ValueListenable<TownBranchMarks>? branches); TownMapPainter(..., TownBranchMarks? branches); TownMapSheet(..., TownBranchMarks branches = TownBranchMarks.none);
RealtySheet({required DistrictDef district, required Set<String> owned, required int coins, required int playerLevel, required ValueChanged<String> onBuy, required VoidCallback onClose});
BranchSheet({required BranchView view, required List<StaffMember> staff, required int coins, required int playerLevel, required bool clockBehind, required VoidCallback onCollect, required VoidCallback onUpgrade, required ValueChanged<String> onHire, required ValueChanged<String> onDismiss, required VoidCallback onClose});
BranchDoubleChip({required int coins, required VoidCallback onTap, Duration visibleFor = const Duration(seconds: 8), VoidCallback? onExpired});
String staffName(AppLocalizations l, String staffId); String staffRoleText(AppLocalizations l, StaffRole r); // town_l10n.dart
```

## 9. Các đợt
| Đợt | Mã | Người | Việc | File |
|---|---|---|---|---|
| 0 | L1 | localizer | Khoá §6 | `.arb` |
| 0 | C0 | dev-core | Khung: `BranchEconomy`, `StaffRoster` chạy thật; lớp dữ liệu, `BranchView`, các enum; `CityBranches` mới có chữ ký; `LotDef.baseIncome`; `branchNumber`; `AdPlacement.branchDouble`; test bảng §3 | `lib/core/branch/*`, `city_config.dart`, `models/ids.dart`, `test/core/branch/branch_economy_test.dart` |
| 0 | G0 | dev-game | Đo tam giác; tách lô chi nhánh khỏi lưới chung; `branchFacade` cấp 0..5; ô quầy địa ốc; hộp chặn cố định; ghi notes §32 | `town_layout.dart`, `town_batches.dart`, `shop3d_mesh.dart` (tham số tuỳ chọn), test layout/batches, notes |
| 1 | C1 | dev-core | Logic `CityBranches`, `TillClock`, `produce`; nối `CityGame`/save/store/main/debug; test core 1–13 | `lib/core/branch/**`, `city_game.dart`, `city_save.dart`, `city_save_store.dart`, `debug_params.dart`, `main.dart`, `test/core/**` |
| 1 | G1 | dev-game | `TownRules`, `TownPilot`, `town_branch_cast.dart`; test game 1, 2, 5, 6 | `town_rules.dart`, `town_pilot.dart`, `town_branch_cast.dart`, test |
| 1 | U1 | dev-ui | `RealtySheet`, `BranchSheet`, `BranchDoubleChip`, `TownBranchMarks`, bản đồ lớn, `staffName`; test UI | `lib/ui/town/**`, `test/ui/town/**` |
| 2 | G2 | dev-game | Ghép vào view, scene, page; đo CDP | `town3d_view.dart`, `town_scene.dart`, `town3d_page.dart`, notes |
| 2 | U2 | dev-ui | Sửa giao diện sau khi ghép | `lib/ui/town/**` |
| 3 | C2 | trưởng phòng | analyze, test, build | — |
| 4 | QA | tester | 10 kịch bản trên web | — |
