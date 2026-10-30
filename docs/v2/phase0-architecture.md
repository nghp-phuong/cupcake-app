# Sugarleaf Bakery V2 — Giai đoạn 0: hiện trạng và kiến trúc theo level

Ngày 29/10/2026. Chưa sửa code. Tài liệu này để chủ dự án duyệt trước khi làm Giai đoạn 1.

---

## 1. Hiện trạng (V1, commit `58aa603`)

### Luồng chơi
`MainMenuScreen` → `DayScreen` (một "ngày" 4–6 khách, phục vụ **lần lượt từng người**) → `DaySummaryScreen` →
nâng cấp / trang trí / sổ công thức / cửa hàng. Không có đồng hồ, không có hàng chờ, không có tủ kính.

| Thành phần | File | Ghi chú cho V2 |
|---|---|---|
| Trạng thái + lưu game | `lib/core/game_state.dart` (770 dòng) | Một `ChangeNotifier` duy nhất, JSON `v: 1`, khoá `sugarleaf_save_v1` trong shared_preferences, autosave 300 ms. Đọc **từng trường độc lập**, trường hỏng → mặc định + chép bản dự phòng; `v` lớn hơn bản app → khoá ghi cả phiên. Nền tảng tốt, giữ nguyên cách làm. |
| Kinh tế | `lib/core/economy.dart` | Cấp tiệm 1–15 theo XP, lò 5 cấp (nới vùng hoàn hảo), 3 dụng cụ × 3 cấp, tip theo sao và loại khách, trần trang trí +30% tip. |
| Ngày kinh doanh | `lib/core/day_controller.dart`, `order_generator.dart` | Sinh sẵn cả ngày, tuần tự. **Thay bằng `LevelSession`.** |
| Chấm điểm | `lib/core/scoring.dart` | Trọng số nướng 30 / kem 25 / topping 25 / trộn 10 / hộp 10 → 1–5★, chỉ ra trạm yếu nhất. **Giữ nguyên**, dùng cho cả bánh vào tủ và đơn đặc biệt. |
| 6 trạm (Flame) | `lib/game/bake_session_view.dart` + `stations/*` | Cầu nối duy nhất ui↔game: nhận `Order` + `BakeModifiers`, trả `BakeOutcome` thô. Không đụng `GameState`. **Giữ nguyên giao diện này.** |
| Danh mục | `lib/core/catalog.dart` | **10 món** (không phải 18), 8 topping, 6 kem, 3 hộp, 10 đồ trang trí, 11 cảnh truyện (prologue → finale), 7 quà đăng nhập, 6 loại nhiệm vụ. |
| Khách | `models/customer.dart` | `regular` (15 kiểu ảnh), `friend` (Hòa, Linh, Kenji), `vip` (3 kiểu, vip_00 = bà Rosa), mèo Mochi ngày mưa. 4 nét mặt mỗi nhân vật. |
| Quảng cáo / IAP | `services/ad_service.dart`, `iap_service.dart` | Giả lập. Rewarded tối đa 8/ngày; interstitial từ ngày 4, cách 2 ngày. |
| Giao diện | `lib/ui/sugarleaf/*` (bộ SL*: nút, panel, dialog, toast, icon vẽ tay) | Dùng lại toàn bộ cho màn mới. Khung tham chiếu 1280×720 (`RefFrame`). |
| Ảnh | `assets/art/**`, `assets/characters/**` | Đã có: `menu_bg`, `kitchen_overview`, `story_grandma_kitchen`, `shop_base`, 6 nền trạm bếp, 5 cấp lò, 10 bánh, 88 ảnh nhân vật. |
| Test | `test/core|game|ui` | 10 file; có test lưu/tải và test hiệu năng trạm phủ kem. |

Tài liệu thiết kế đồ hoạ: `docs/design/sugarleaf-characters.html` (phong cách vẽ tay màu nước – gouache, viền nâu mảnh,
4 nét mặt cùng dáng/khung, nền trong suốt).

### Những chỗ lệch giữa yêu cầu V2 và code hiện có
1. **Chỉ có 10 món.** Đủ cho chương 1–3; chương 4–5 cần thêm món (kèm ảnh khuôn/bột/đế/bánh và dữ liệu trạm).
2. **"Cấp tiệm" theo XP (1–15)** trùng vai trò với "level" mới. Đề xuất: bỏ hiển thị cấp tiệm, mọi điều kiện mở khoá dùng
   **level cao nhất đã qua**. Trường `xp` vẫn đọc/ghi để không mất dữ liệu.
3. **Quy tắc quảng cáo trong `CLAUDE.md`** (interstitial từ ngày 4, cách 2 ngày) khác yêu cầu V2 (1 lần mỗi 3 level).
   Sẽ cập nhật `CLAUDE.md` và `docs/alpha-spec.md` khi làm Giai đoạn 6.
4. Một màn 2–4 phút mà **mỗi bánh đi đủ 6 trạm toàn màn hình** (30–60 giây/bánh) thì không kịp nuôi tủ kính khi khách
   dồn dập. Cần chốt cách bổ sung tủ — xem mục 6.

---

## 2. Kiến trúc V2

Nguyên tắc: **logic màn chơi là Dart thuần, chạy theo bước thời gian cố định**, không phụ thuộc Flutter/Flame. Nhờ vậy
cùng một mã dùng được cho (a) màn chơi thật, (b) test, (c) script mô phỏng 50 level ở Giai đoạn 7.

```
assets/config/levels.json ─┐                         ┌─ lib/game/shop_floor/  (Flame: vẽ tiệm, khách, nhân viên)
assets/config/unlocks.json ─┼─► ConfigRepository ──►  │
                            │     (LevelData,          ├─ lib/ui/level/  (HUD, kết quả, bản đồ, mở khoá, nhân viên)
                            │      UnlockConfig)       │
GameState (save v2) ────────┴─► PlayerProgress ──► LevelSession (Dart thuần, tick(dt)) ◄── tool/simulate.dart
                                      │                    │
                                      └──► ShopLayout ─────┘   BakeSessionView (6 trạm, giữ nguyên) ◄── đơn đặc biệt
```

### 2.1 Thư mục mới

| Đường dẫn | Nội dung | Người làm |
|---|---|---|
| `assets/config/levels.json`, `unlocks.json` | Dữ liệu level, mở khoá, thiết bị, nhân viên | dev-core |
| `lib/core/level/` | `LevelData`, `ChapterData`, `LevelSession`, `DisplayCase`, `LevelCustomer`, `SpawnCurve`, `LevelResult` | dev-core |
| `lib/core/progress/` | `PlayerProgress`, `UnlockConfig`, `UnlockService`, `ShopLayout`, `Staff`, `OfflineIncome`, migration | dev-core |
| `lib/core/config/` | `ConfigRepository` (đọc + kiểm tra JSON, báo lỗi rõ dòng nào sai) | dev-core |
| `lib/game/shop_floor/` | Cảnh tiệm Flame: tủ kính, hàng chờ, khách đi/đứng/ngồi, nhân viên, hạt lấp lánh | dev-game |
| `lib/ui/level/`, `lib/ui/map/`, `lib/ui/intro/`, `lib/ui/staff/` | HUD màn chơi, kết quả, bản đồ chương, thông báo mở khoá, thuê nhân viên, intro | dev-ui |
| `tool/simulate.dart` | Mô phỏng cân bằng (Giai đoạn 7) | dev-core |

### 2.2 Mô hình dữ liệu

**`LevelData`** (đọc từ `levels.json`, bất biến)
```dart
class LevelData {
  final int id;                       // 1..N, toàn cục
  final int chapter;
  final Map<String, String> title;    // {"en": "...", "vi": "..."} — sửa được không cần build lại chuỗi
  final int durationSec;              // 120..240
  final LevelGoal goal;               // type: coins | customers | specialOrders, target
  final List<int> starThresholds;     // 3 mốc, cùng đơn vị với goal; mốc 1 = điều kiện thắng
  final List<RecipeId> menu;          // món được bán trong màn
  final SpawnCurve spawn;             // nhịp khách
  final int patienceSec;              // kiên nhẫn gốc của khách vãng lai
  final List<SpecialVisit> specials;  // khách quen / VIP: lúc nào đến, món gì, cảnh truyện nào
  final int startStock;               // số bánh có sẵn trong tủ khi vào màn
  final TutorialId? tutorial;         // L1–3
  final bool isSpecial;               // L10, 20, 30…
}
```

**`SpawnCurve`** — khách thưa → dày → giờ cao điểm:
```json
"spawn": { "startEverySec": 9, "endEverySec": 4.5, "rushAtPct": 80, "rushEverySec": 2.5,
           "maxQueue": 5, "jitterPct": 20 }
```
Khoảng cách giữa hai khách nội suy tuyến tính từ `startEverySec` → `endEverySec` trong 0–80% thời gian, rồi 20% cuối là
giờ cao điểm. Có `jitter` để không đều như máy. Hàng đầy → khách kế đi qua cửa (tính là bỏ đi).

**`LevelSession`** (Dart thuần, `tick(double dt)` bước cố định 1/30 s, `Random` có seed)
- Trạng thái: `timeLeft`, `DisplayCase`, `queue` + `seated` (`List<LevelCustomer>`), `combo`, `coinsEarned`,
  `served`, `lost`, `specialsDone`, sự kiện ra ngoài (`Stream`/danh sách `SessionEvent` để UI phát âm thanh, hiệu ứng).
- Hành động người chơi: `sell(customerId)`, `startRestock(recipe)` / `finishRestock(recipe, BakeResult)`,
  `beginSpecial(id)` / `finishSpecial(id, BakeResult)`, `addTime(30)` (rewarded), `applyBoosters(...)`.
- Nhân viên chạy ngay trong `tick` (thu ngân bán, thợ làm bánh nạp tủ, phục vụ dọn bàn) — không cần Flame.
- Kết thúc: `LevelResult { stars, coins, served, lost, specials, won, comboMax }`.

**`DisplayCase`** — `slots` (số ô từ `ShopLayout`), mỗi ô `{recipe, count, quality}`; một mẻ nạp `batchSize` cái
(theo cấp lò). `take(recipe)` lấy ô chất lượng cao nhất. Chất lượng bánh (sao từ `Scoring`) ảnh hưởng giá + tip.

**`LevelCustomer`** (khách trong màn; ngoại hình dùng lại `Customer` hiện có)
```dart
class LevelCustomer {
  final int id; final Customer look; final CustomerType type; // walkIn | special
  final List<RecipeId> wants;          // khách vãng lai: 1–2 món chấp nhận, ưu tiên món đầu
  double patience, patienceMax;        // giảm theo dt; dưới 30% → nét mặt buồn
  CustomerPhase phase;                 // entering, queued, atCounter, seated, leaving
  int? seat;                           // khi có bàn ghế (L18+)
}
```

**`UnlockConfig`** (đọc từ `unlocks.json`)
```json
{ "id": "cashier", "kind": "staffRole", "minLevel": 10, "cost": {"coins": 1500},
  "chapter": 1, "goTo": "staff", "params": {"role": "cashier"} }
```
`kind`: `displaySlot | oven | staffRole | staffSlot | seating | kitchenRow | garden | floor2 | staffTier | decorRare`.
Thêm các bảng `equipment` (cấp lò: thời gian nướng, mẻ, vùng hoàn hảo; cấp tủ: số ô) và `staff` (vai trò, chỉ số theo
cấp, giá nâng cấp) trong cùng file.

**`ShopLayout`** — tính ra từ những gì đã mua: `displaySlots`, `ovens`, `stationRows`, `seats`, `hasGarden`,
`hasFloor2`, `maxQueue`. Vừa là số liệu cho `LevelSession`, vừa là thứ tự lớp ảnh cho cảnh tiệm (tủ kính ngắn/dài, lò 1/2,
dãy trạm 1/2, bàn ghế, sân vườn, tầng 2). Áp dụng cho mọi level sau khi mua.

**`Staff`** — `role` (cashier, baker, waiter, manager), `nameKey`, `portrait`, `speed`, `skill`, `level`, `skin`
(ngoại hình IAP), `assignedRecipe` (thợ làm bánh). Chất lượng bánh thợ làm = theo `skill`, luôn thấp hơn bánh 5★ người
chơi tự làm để việc tự làm vẫn có giá trị.

**`PlayerProgress`** — phần lưu mới (nằm trong cùng JSON của `GameState`, đọc từng trường như hiện nay):
```json
"progress": {
  "levels": { "1": {"stars": 3, "best": 412, "plays": 2, "firstWin": true} },
  "unlocksOwned": ["displaySlot3", "cashier"],
  "unlocksAnnounced": ["displaySlot3", "cashier"],
  "equipment": {"oven": 2, "case": 1},
  "staff": { "cashier": {"level": 2, "skin": "default"} },
  "bakerAssign": { "baker1": "cupcakeVanilla" },
  "boosters": {"fullCase": 1, "patience": 0, "fastOven": 2},
  "intro": {"fullSeen": true},
  "ads": {"levelsSinceInterstitial": 1},
  "offline": {"lastSeenMs": 0}
}
```
Số sao chương = tổng `stars`; mở chương mới khi đủ sao (`starsToUnlock` trong `levels.json`).

### 2.3 Điều hướng mới
`/intro` → `/map` (bản đồ chương — thay menu chính làm "nhà"; các nút cũ: nhiệm vụ, quà, sổ công thức, trang trí,
cửa hàng, cài đặt chuyển lên thanh trên của bản đồ) → `/level/prepare` (mục tiêu + booster) → `/level` → `/level/result`
→ quay về `/map` (hiện thông báo mở khoá nếu có). Thêm `/staff`, `/expand`. Màn `/day` cũ giữ trong code tới hết
Giai đoạn 2 để so sánh, rồi gỡ.

### 2.4 Hiệu năng (20+ khách, 10 nhân viên, 60 fps)
- Logic bước cố định 30 Hz, vẽ 60 Hz nội suy; không cấp phát trong vòng lặp (danh sách tái dùng).
- Cảnh tiệm dựng bằng **Flame** (một canvas), không phải mỗi khách một widget. Ảnh nhân vật (đang ~3:4, lớn) được giải
  mã một lần ở kích thước hiển thị (~200 px cao) và cache; chuyển động = nhún/lắc bằng biến đổi, không cần sprite sheet.
- HUD Flutter chỉ dựng lại khi số liệu đổi (ValueListenable riêng cho xu, giờ, combo), không theo mỗi khung hình.
- Test hiệu năng tự động như `frost_perf_test.dart`: 25 khách + 10 nhân viên, 3 phút mô phỏng, đo thời gian `tick`.

---

## 3. Migration dữ liệu đã lưu (v1 → v2)

1. Giữ **cùng khoá** `sugarleaf_save_v1`, tăng `saveVersion` lên 2. Trước lần ghi v2 đầu tiên, chép nguyên chuỗi v1 sang
   `sugarleaf_save_v1_pre_v2` (không bao giờ ghi đè) → luôn khôi phục được.
2. **Giữ mọi trường v1**: xu, đá quý, trang trí đã mua/đang đặt, thành thạo công thức, nhiệm vụ, chuỗi đăng nhập, cảnh
   truyện đã xem, hướng dẫn trạm, cài đặt, IAP đã mua, xoá quảng cáo, thống kê, Mochi, cấp lò, cấp dụng cụ.
3. Quy đổi tiến trình: người chơi V1 ở **ngày D** được tính đã qua level `1..min(D−1, 9)` với 2★ mỗi level (đủ mở chương 2
   khi chơi xong L10), và nhận quà "Chào mừng phiên bản mới" (đề xuất 500 xu + 20 đá quý). Lò V1 cấp n → thiết bị lò cấp n.
4. Bản app V1 mở bản lưu v2 → tự khoá ghi (cơ chế có sẵn: `v > saveVersion`) → không làm hỏng dữ liệu nếu người chơi hạ cấp.
5. Test: bản lưu v1 mẫu (mới, giữa game, cuối game, hỏng một phần) → v2 → kiểm từng trường; v2 → ghi → đọc lại khớp.

---

## 4. Định dạng `levels.json` (mẫu rút gọn)

```json
{
  "version": 1,
  "chapters": [
    { "id": 1, "title": {"en": "Grandma's Kitchen", "vi": "Căn bếp của bà"}, "starsToUnlock": 0,
      "mapArt": "chapter1_map" }
  ],
  "levels": [
    { "id": 1, "chapter": 1, "title": {"en": "First Morning", "vi": "Buổi sáng đầu tiên"},
      "durationSec": 120, "goal": {"type": "customers", "target": 5}, "stars": [5, 7, 9],
      "menu": ["cupcakeVanilla"], "patienceSec": 40, "startStock": 3,
      "spawn": {"startEverySec": 14, "endEverySec": 10, "rushAtPct": 85, "rushEverySec": 7, "maxQueue": 3},
      "specials": [], "tutorial": "sellFromCase" },
    { "id": 10, "chapter": 1, "special": true, "goal": {"type": "specialOrders", "target": 2}, "...": "...",
      "specials": [ {"atSec": 20, "who": "hoa", "recipe": "eggTart", "scene": "hoa3"},
                    {"atSec": 90, "who": "linh", "recipe": "macaron", "scene": "finale"} ] }
  ]
}
```
Chủ dự án thêm/sửa level bằng cách sửa file này. `ConfigRepository` kiểm tra khi khởi động (bản debug: báo lỗi to trên
màn hình chỉ rõ level nào, trường nào; bản phát hành: bỏ level hỏng, ghi log).

---

## 5. Chia việc theo giai đoạn

| GĐ | dev-core | dev-game | dev-ui | localizer |
|---|---|---|---|---|
| 1 | config loader, `LevelSession`, `DisplayCase`, kết quả, 10 level chương 1, test | cảnh tiệm Flame: tủ kính, hàng chờ, khách, thanh kiên nhẫn | HUD (giờ, mục tiêu, combo), màn chuẩn bị, màn kết quả, nối 6 trạm | chuỗi mới |
| 2 | `PlayerProgress`, sao, khoá chương, migration v1→v2 | — | bản đồ chương vẽ tay | chuỗi |
| 3 | `unlocks.json`, `UnlockService`, `ShopLayout`, thiết bị | lớp ảnh tiệm theo layout | thông báo mở khoá, màn mở rộng/nâng cấp | chuỗi |
| 4 | `Staff`, tự động hoá trong `tick`, thu nhập offline | vẽ nhân viên làm việc | màn thuê/nâng cấp, "Trong lúc bạn vắng mặt" | chuỗi |
| 5 | cờ intro | cutscene parallax, hạt lấp lánh | intro ngắn, hướng dẫn L1–3 | chuỗi |
| 6 | booster, quy tắc quảng cáo/IAP mới | — | chọn booster, +30 giây, ×2 xu, cửa hàng mới | chuỗi |
| 7 | `tool/simulate.dart` + bảng cân bằng, chỉnh JSON | — | — | — |

Mỗi giai đoạn kết thúc bằng `flutter analyze`, `flutter test`, build web, chụp màn hình, `/quality-gate`, danh sách ảnh
cần vẽ + prompt Gemini.

---

## 6. Cần chủ dự án quyết định trước Giai đoạn 1

**Cách bổ sung tủ kính trong màn có đồng hồ** (ảnh hưởng toàn bộ Giai đoạn 1):

- **A — Bếp nhanh trong màn (đề xuất).** Dãy 6 trạm thu nhỏ ngay trong cảnh tiệm; mỗi trạm là 1 thao tác ngắn
  (chạm khuôn → xoay 1 vòng → giữ-thả lò như cũ → quẹt kem → chạm topping → chạm hộp), ~6–8 giây/mẻ, đồng hồ vẫn chạy,
  ra một mẻ 3–6 cái theo cấp lò. Đơn đặc biệt mở **màn 6 trạm đầy đủ** như hiện nay, đồng hồ và kiên nhẫn **tạm dừng**.
  Giữ cảm giác "tự tay làm bánh", vẫn đúng chất time-management.
- **B — Luôn dùng màn 6 trạm đầy đủ, đồng hồ tạm dừng khi làm bánh.** Dùng lại 100% code trạm, nhưng mất áp lực thời
  gian (khách không bỏ đi khi đang làm bánh) → khó tạo "giờ cao điểm".
- **C — Lò hẹn giờ.** Chạm lò → chọn món → chờ đếm ngược → bánh vào tủ; 6 trạm chỉ dùng cho đơn đặc biệt. Nhanh, dễ cân
  bằng, nhưng làm bánh thường không còn mini-game.

Các đề xuất khác (sẽ áp dụng nếu không có ý kiến khác): bỏ hiển thị cấp tiệm XP; bản đồ thay menu chính; quy đổi tiến
trình V1 như mục 3; làm V2 trên nhánh git riêng `v2` để bản V1 (`main`) còn nguyên.

---

## 7. Ảnh sẽ cần (sơ bộ, tạo theo từng giai đoạn)

| GĐ | Ảnh | Ghi chú |
|---|---|---|
| 1 | Tủ kính trưng bày (ngắn), khay bánh trong tủ, quầy thu ngân nhìn ngang, nền cảnh tiệm có lối vào + hàng chờ | 1280×720 nền; vật thể nền trong suốt |
| 2 | Bản đồ thị trấn chương 1–5 (đường đi vẽ tay), nút level (khoá/mở/1–3 sao), biển tên chương | |
| 3 | Tủ kính dài, lò thứ 2, dãy trạm thứ 2, bàn ghế, sân vườn, tầng 2 | Ghép lớp lên `shop_base` |
| 4 | 4 nhân viên (thu ngân, thợ làm bánh, phục vụ, quản lý) × 4 nét mặt + chân dung; 2–3 skin IAP | Cùng phong cách 88 ảnh hiện có |
| 5 | Bếp buổi sáng có lớp tách (nền / lò / hơi nước / tủ kính / cửa), biển "Mở cửa"/"Đóng cửa", logo Sugarleaf | Cho parallax |
| 6 | Icon booster (tủ đầy, kiên nhẫn, lò nhanh), gói đá quý, season pass | |

Giai đoạn 0 không có màn hình mới nên chưa tạo ảnh; mỗi giai đoạn sau sẽ mở Chrome, chạy prompt Gemini đúng phong cách
(vẽ tay màu nước, viền nâu, nền trong suốt) và đưa ảnh vào trang duyệt `sugarleaf-characters.html`.
