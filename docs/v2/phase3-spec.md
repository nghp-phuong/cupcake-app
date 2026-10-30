# V2 · Giai đoạn 3 — Mở khoá theo level, mở rộng tiệm, nâng cấp thiết bị

Nhánh `v2`. Tiếp nối `phase1-spec.md`, `phase2-spec.md`. Nhân viên (thuê, tự làm, thu nhập offline) là **GĐ4** — GĐ3 chỉ
khai báo các mục nhân viên trong `unlocks.json` và hiện chúng ở trạng thái "Sắp có".

## 1. Mục tiêu
1. **`assets/config/unlocks.json`** chứa mọi mở khoá của chương 1–5 (sửa không cần code). Mỗi mục: level tối thiểu + giá xu
   (+ tuỳ chọn giá kim cương). Mở khoá "khả dụng" khi đã **qua** level đó (`highestCompletedLevel ≥ level`), rồi người chơi
   mua bằng xu. Đã mua thì áp dụng cho **mọi level sau**.
2. **Mở rộng tiệm làm cảnh tiệm thay đổi thấy được** (dev-game), áp dụng cho mọi level sau khi mua.
3. **Thiết bị có cấp** (lò nhanh, khay lớn, tủ rộng) + giữ dụng cụ V1 (lò vùng vàng, phới, túi bắt kem, kẹp) nhưng khoá
   theo level thay vì "cấp tiệm".
4. **Thông báo khi tới mốc**: thắng level làm mở khoá mới khả dụng → sau hoạt cảnh bản đồ hiện thẻ "Mở khoá mới!" có nút
   "Xem" → màn Nâng cấp đúng tab, đúng thẻ. Nút Nâng cấp trên thanh bản đồ có chấm đỏ khi có mục khả dụng chưa xem.
5. **Giá cân theo thu nhập thật** (bot): mỗi mở khoá mua được trong 1–3 level kể từ khi khả dụng. Bỏ hẳn "cấp tiệm".

## 2. Danh sách mở khoá (nội dung `unlocks.json`)
`level` = phải qua level này. `kind`: `expansion` (mở rộng, có hiệu ứng), `staff` (GĐ4, hiện "Sắp có"), `staffUpgrade`
(GĐ4), `decorSet` (chương 5, hiện "Sắp có"). Hiệu ứng `effect` cộng dồn; khoá chưa hỗ trợ ở GĐ3 vẫn đọc được (bỏ qua,
ghi chú) để chương sau dùng.

| id | Ch | level | kind | Hiệu ứng (`effect`) | Hiển thị trong tiệm (dev-game) |
|---|---|---|---|---|---|
| `case_stand` | 1 | 5 | expansion | `caseSlots +1` | Kệ bánh tầng (ảnh mới) đặt trên quầy cạnh tủ kính, chứa ô thứ 4+ |
| `staff_cashier` | 1 | 10 | staff | (GĐ4) | — |
| `oven_2` | 2 | 12 | expansion | `ovens +1` | Lò thứ 2 trong bếp nhanh (đã hỗ trợ n lò) |
| `staff_baker` | 2 | 15 | staff | (GĐ4) | — |
| `cafe_tables` | 2 | 18 | expansion | `patienceMult ×1.15`, `maxQueue +2` | 2 bộ bàn ghế (ảnh mới) trên sàn tiệm; khách chờ đứng cạnh bàn |
| `kitchen_2` | 3 | 22 | expansion | `prepSlots +1` (chưa hỗ trợ GĐ3) | (chương 3) |
| `staff_waiter` | 3 | 25 | staff | (GĐ4) | — |
| `staff_baker_2` | 3 | 28 | staff | (GĐ4) | — |
| `garden` | 3 | 30 | expansion | `tipPct +5`, `maxQueue +2` | (chương 3) |
| `staff_manager` | 4 | 32 | staff | (GĐ4: thu nhập offline) | — |
| `floor_2` | 4 | 35 | expansion | `counterSpots +1`, `maxQueue +3`, `spawnRatePct +10` | (chương 4) |
| `staff_training` | 5 | 41 | staffUpgrade | (GĐ4+) | — |
| `rare_decor` | 5 | 45 | decorSet | (sau) | — |

L1–3 hướng dẫn (GĐ5), L20 "Giờ cao điểm", L40 bà Rosa là **level**, không phải mục mua.

## 3. Thiết bị (cũng trong `unlocks.json`, mục `equipment`)
Mỗi dòng có các cấp; cấp 1 có sẵn; cấp k cần qua `level` và trả `price`. Thông số áp vào `LevelDefaults` của mọi level.

| id | Thông số | Cấp 1 → … | level mở (gợi ý, dev-core chỉnh theo bot) |
|---|---|---|---|
| `fastOven` | `ovenSec` | 7 → 6.3 → 5.6 → 5.0 | 3 / 8 / 14 |
| `bigTray` | `batchSize` | 3 → 4 → 5 | 9 / 17 |
| `wideCase` | `slotCapacity` | 6 → 8 → 10 | 7 / 16 |
| `goldenOven` (lò V1) | vùng vàng nướng (special) | 5 cấp như V1 | trải L2–L19 |
| `whisk`, `pipingBag`, `tongs` (V1) | như V1 | 3 cấp | trải L2–L18 |

Cấp đã mua của lò/dụng cụ V1 trong bản lưu giữ nguyên. Đồ trang trí (`Catalog.decor`) giữ trong code nhưng `unlockLevel`
đổi nghĩa thành "qua level N" (dev-core trải lại trong L1–L20) và giá cân lại theo thu nhập mới.

## 4. Giá và cân bằng (dev-core)
- Đo thu nhập: bot `newcomer` và bot 0.75 chơi L1→L20 theo thứ tự (thua thì chơi lại, tối đa 5 lần/level), **có mua sắm**:
  mỗi khi đủ xu mua theo ưu tiên mở rộng → thiết bị mới → dụng cụ → trang trí rẻ nhất. Thiết bị/mở rộng đã mua áp vào level
  sau (qua `ShopSetup`).
- Giá mở rộng ≈ 1.5–2.5 × xu trung bình một level quanh mốc; thiết bị ≈ 0.8–1.5 ×. Mục tiêu: người mới mua được mỗi mở rộng
  trong 1–3 level sau khi khả dụng; người giỏi trong 1–2.
- Test in bảng (giống `level_balance_test`): xu/level, level mua từng mục, số lần chơi lại, tỉ lệ thắng lần đầu theo level
  **với bộ đồ đã mua lúc đó**. Giữ mức độ khó ~ GĐ2 (0.75: 85–100%; người mới 25–55% từ L5) — được phép chỉnh `levels.json`
  (caseSlots gốc, nhịp khách, mốc sao) để bù phần dễ hơn do mua đồ.
- `levels.json` `caseSlots` giờ là số ô **của tiệm gốc**; ô thêm từ `case_stand` cộng vào.

## 5. Hợp đồng API

`lib/core` (dev-core):
```dart
// lib/core/unlock/unlock_config.dart (+ loader chặt/khoan dung như LevelConfigLoader, loadOrEmpty)
enum UnlockKind { expansion, staff, staffUpgrade, decorSet }
class UnlockData { String id; int chapter; int level; UnlockKind kind; int price; int gemPrice;
  Map<String, num> effect; String art; String name(String lang); String desc(String lang);
  bool get comingSoon; /* kind != expansion ở GĐ3 */ }
class EquipmentData { String id; String art; String name(String lang); String desc(String lang);
  List<EquipmentTier> tiers; }            // tiers[0] = cấp 1 có sẵn
class EquipmentTier { int level; int price; num value; }
class UnlockConfig { List<UnlockData> unlocks; List<EquipmentData> equipment;
  UnlockData? unlock(String id); EquipmentData? equipmentById(String id); static UnlockConfig empty(); }

/// Cấu hình tiệm áp cho một lượt chơi (GameState tính từ đồ đã mua).
class ShopSetup {
  final int caseSlotsBonus, ovens, batchSize, slotCapacity, maxQueueBonus, counterSpotsBonus, tipPct, spawnRatePct;
  final double ovenSec, patienceMult;
  final Set<String> owned;                  // id mở rộng đã mua (dev-game vẽ theo đây)
  final Map<String, int> equipmentTiers;    // id → cấp hiện tại
  LevelDefaults applyTo(LevelDefaults base);
  static const ShopSetup base;
}

// LevelSession: thêm tham số tuỳ chọn `ShopSetup setup = ShopSetup.base` (caseSlots = level.caseSlots + bonus, …).
//   `LevelSession.setup` getter cho dev-game.

// GameState
void attachUnlockConfig(UnlockConfig cfg); UnlockConfig get unlockConfig;
enum UnlockState { locked, available, owned, comingSoon }
UnlockState unlockState(String id);
PurchaseResult buyUnlock(String id);                  // ok / locked / notEnoughCoins / notEnoughGems / alreadyOwned / comingSoon
int equipmentTier(String id); PurchaseResult buyEquipment(String id);   // gồm cả goldenOven/whisk/pipingBag/tongs
ShopSetup get shopSetup;
List<String> get unseenUnlocks;                       // khả dụng (available) mà chưa xem, theo thứ tự level
void markUnlocksSeen(Iterable<String> ids);
// LevelProgressDelta thêm: final List<String> newUnlocks;   // mục vừa khả dụng nhờ lượt này (mở rộng + nhân viên + thiết bị cấp mới: "eq:<id>:<tier>")
```
- `buyOvenUpgrade` / `buyToolUpgrade` cũ: giữ làm lớp mỏng gọi `buyEquipment` (hoặc xoá nếu không còn ai dùng — báo dev-ui).
- `Economy.shopLevelForProgress`, `levelToReachShopLevel`, `requiredShopLevel` → bỏ; thay bằng level trong cấu hình.
- Bản lưu: vẫn `v: 2`, thêm `"shop": {"owned": [...], "equipment": {"fastOven": 2, ...}, "seen": [...]}`, đọc độc lập;
  lò/dụng cụ V1 (`oven`, `tools`) quy về `equipment.goldenOven/whisk/...` khi đọc (giữ trường cũ khi ghi để app cũ không mất).
- `main.dart` nạp `unlocks.json` song song với `levels.json`; `AppServices` tự gắn như `attachLevelConfig`.

`lib/game` (dev-game): `LevelPlayView` đọc `session.setup` để vẽ: kệ bánh tầng (`case_stand`), lò thứ 2, bàn ghế
(`cafe_tables`), ảnh lò theo cấp `fastOven` (`assets/art/items/oven_1..5.webp` nếu hợp), đồ trang trí quầy/cây đã đặt
(`assets/art/decor/counterFlowers|counterCakeStand|plantFern|plantLemonTree.webp`) nếu có chỗ hợp phối cảnh. Hiệu năng giữ
như GĐ1 (20+ khách, 2 lò, bàn ghế: avg < 1 ms/khung ở test perf).

`lib/ui` (dev-ui):
- **Màn Nâng cấp** thành 2 tab: **Mở rộng tiệm** (thẻ theo chương, ảnh, tên, mô tả hiệu ứng, trạng thái: "Qua màn X để mở"
  / giá + Mua / "Đã có" / "Sắp có"; chương chưa mở hiện mờ) và **Thiết bị** (mỗi dòng: cấp hiện tại → cấp sau, thông số
  trước/sau, giá, khoá theo màn). Mở được thẳng một tab/thẻ (tham số route).
- **Thông báo mở khoá**: sau hoạt cảnh bản đồ (và sau hộp mở chương nếu có), nếu `delta.newUnlocks` / `unseenUnlocks` có
  mục → thẻ "Mở khoá mới!" (ảnh + tên + "Xem" / "Để sau"); "Xem" → Nâng cấp đúng thẻ, đánh dấu đã xem. Chấm đỏ trên nút
  Nâng cấp khi `unseenUnlocks` không rỗng.
- Thẻ "Sẵn sàng": dòng nhỏ tóm tắt tiệm hiện tại (vd "Tủ 4 ô · 2 lò · Khay 4 bánh") — tuỳ chọn nếu gọn.
- Màn Trang trí: nhãn khoá theo màn (đã có `mapUnlockAfterLevel`).
- Chuỗi mới ghi ở `docs/v2/phase3-strings-ui.md`; tên/mô tả mở khoá và thiết bị nằm trong `unlocks.json` (en + vi).

## 6. Ảnh (trưởng phòng, Gemini)
- `assets/art/level/case_stand.webp` — kệ bánh tầng gỗ + kính nhỏ, nền trong suốt.
- `assets/art/level/cafe_table.webp` — bàn tròn + 2 ghế gỗ, nền trong suốt.
- Thẻ thiết bị dùng ảnh có sẵn: `items/oven_*.webp`, `items/baking_tray.webp`, `level/display_case.webp`,
  `items/tool_*.webp`. Mở rộng chương 3–5 (bếp 2, vườn, tầng 2) và nhân viên: ảnh làm ở giai đoạn có nội dung đó.

## 7. Chia việc
| Ai | Khu vực | Việc |
|---|---|---|
| dev-core | lib/core, main.dart, assets/config, test/core | mục 2–5 phần core, giá + bot tiến trình, cân lại levels.json |
| dev-game | lib/game, test/game | vẽ tiệm theo `ShopSetup` |
| dev-ui | lib/ui, test/ui, tool/screens | màn Nâng cấp 2 tab, thông báo mở khoá, chấm đỏ, Trang trí |
| localizer | .arb | chuỗi ở `docs/v2/phase3-strings-ui.md` |
| trưởng phòng | assets/art/level | 2 ảnh mục 6 |
