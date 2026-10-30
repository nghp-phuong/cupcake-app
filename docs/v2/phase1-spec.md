# V2 · Giai đoạn 1 — Màn chơi theo level (đặc tả + hợp đồng API)

Chủ dự án đã chốt: **phương án A — Bếp nhanh trong màn**. Nhánh git: `v2`. Kiến trúc tổng: `docs/v2/phase0-architecture.md`.

Phạm vi Giai đoạn 1: tủ kính, khách vãng lai, hàng chờ, kiên nhẫn, bếp nhanh 6 trạm, combo, khách đặc biệt (6 trạm
đầy đủ, dừng giờ), mục tiêu, 3 sao, màn kết quả, +30 giây (rewarded, giả lập), 10 level chương 1 trong `levels.json`,
màn chọn level TẠM (danh sách 10 ô, mở hết). **Chưa làm**: bản đồ, lưu sao/tiến trình (GĐ2), mở khoá/mở rộng (GĐ3), nhân
viên (GĐ4), intro + hướng dẫn (GĐ5), booster + interstitial (GĐ6). Màn `/day` cũ giữ nguyên, vẫn vào được.

---

## 1. Luồng màn chơi

```
Menu chính ─[Màn chơi]→ /levels (danh sách tạm) → /level (LevelScreen, args LevelArgs(levelId))
  LevelScreen: (cảnh truyện mở màn nếu có) → thẻ "Sẵn sàng" (mục tiêu, thời gian, món) → chơi → hết giờ
  → (chưa đạt mốc 1★ và chưa dùng: hỏi "+30 giây" xem quảng cáo) → LevelResultScreen
  LevelResultScreen: sao, xu, khách hài lòng / bỏ đi, đơn đặc biệt, combo cao nhất
     thắng: [Level tiếp] [Chơi lại] [Danh sách]   thua: [Chơi lại] [Danh sách]
```
Trong màn: nút tạm dừng (Tiếp tục / Chơi lại / Thoát). App vào nền → tự tạm dừng.

## 2. Bố cục khung 1280×720

```
y 0–64     HUD (Flutter): ⏸ | đồng hồ | thanh mục tiêu + 3 vạch sao | xu kiếm trong màn | combo xN
y 64–440   SÂN TIỆM (Flame): nền shop_base; quầy + TỦ KÍNH ở giữa-trái (ô bánh + số lượng);
           3 chỗ đứng quầy phía sau tủ (khách nửa người trên nhô trên tủ); hàng chờ kéo về cửa bên phải
           (xa hơn → nhỏ hơn); chỗ khách đặc biệt ở mép trái quầy (viền vàng + ngôi sao).
           Khách ở quầy có bong bóng: ảnh món muốn + vòng kiên nhẫn (bạc hà → vàng bơ → đỏ).
y 440–720  BẾP NHANH (Flame): cột trái = thẻ món của level (chạm để bắt đầu mẻ);
           6 ô trạm: Khuôn · Trộn · Lò (1 lò ở GĐ1) · Kem · Topping · Hộp.
```

## 3. Luật chơi (logic ở `LevelSession`, Dart thuần, không import widget/Flame)

**Thời gian**: `advance(dt)` gom vào bước cố định 1/30 s. `paused == true` → không chạy gì (kể cả kiên nhẫn).

**Khách vãng lai** (`LevelCustomer`):
- Sinh theo `SpawnCurve`: khoảng cách nội suy `startEverySec → endEverySec` trong 0..`rushAtPct`% thời gian, sau đó
  `rushEverySec` (giờ cao điểm); ±`jitterPct`%. Ngừng sinh khi còn < 6 s. Hàng (đứng quầy + chờ) đầy `maxQueue` →
  khách mới quay đi (tính `lost`).
- Mỗi khách muốn 1 món trong `menu` (món mới nhất của level trọng số 2); từ L6 có `flexibleChance` để chấp nhận
  thêm món thứ 2.
- Kiên nhẫn `patienceSec` (×`config.patienceMult`); trong hàng chờ giảm 50% tốc độ; ở quầy 100%. Về 0 → bỏ đi,
  `lost++`, combo về 0.
- `sell(customerId)`: chỉ khách đang ở quầy, tủ có món khách muốn → lấy bánh sao cao nhất của món đó → trả xu.
  Không có → trả `SellResult.notInCase` (UI lắc nhẹ).
- Xu một lần bán = `round((price × payMult[stars] + tip) × comboMult)`; tip = `price × tipRate[stars]` nếu kiên nhẫn
  còn ≥ 50%, 50% tip nếu còn 25–50%, 0 nếu dưới; tip cộng thêm `decorTipBonusPct` như V1. (`payMult`, `tipRate`
  dùng lại `Economy`.)
- **Combo**: bán trong vòng `comboWindowSec` (6 s) kể từ lần bán trước → `combo++`; `comboMult = 1 + 0.1 × min(combo−1, 10)`.
  Hết cửa sổ hoặc có khách bỏ đi → combo = 0.

**Tủ kính** (`DisplayCase`): `slots` ô (GĐ1 lấy từ `caseSlots` của level), mỗi ô 1 món, tối đa `slotCapacity` cái
(6). Mỗi cái mang số sao. Mẻ mới vào ô cùng món còn chỗ, nếu không thì ô trống; không có chỗ → mẻ nằm chờ ở trạm Hộp,
báo "Tủ đầy". `startStock`: đầu màn tủ có sẵn N cái 3★ của món đầu menu.

**Bếp nhanh** (`Kitchen`, trong `LevelSession`) — 1 mẻ đi qua: chuẩn bị (Khuôn → Trộn) → Lò → hoàn thiện
(Kem → Topping → Hộp). Mỗi khu chứa 1 mẻ (lò: `ovens` mẻ), nên có thể vừa nướng mẻ này vừa chuẩn bị mẻ sau.
| Trạm | Thao tác trong UI | Hàm session | Chấm (dùng lại `Scoring`) |
|---|---|---|---|
| Khuôn | chọn 1 trong 3 khuôn (1 đúng + 2 nhiễu) | `pickMould(MouldType)` → sai: `wrongDrops++`, ở lại | `Scoring.mould` |
| Trộn | xoay ngón tay quanh âu ~1 vòng, nhấc tay = xong | `finishMix(double turns)` (mục tiêu 1.0 vòng) | `Scoring.mix(turns, 1, band)` |
| Lò | mẻ tự vào lò trống; kim chạy; chạm lò để lấy ra | `takeOut(int oven)` | `Scoring.bake(release, recipe.bakeTarget, …)` |
| Kem | quẹt qua bánh; độ phủ = quãng quẹt hợp lệ / quãng cần | `finishFrost(double coverage)` | `Scoring.frost` |
| Topping | chạm hũ đúng (1 đúng + 1 nhiễu) đủ 3 lần, tự sang bước sau | `addTopping(ToppingId)` | `Scoring.topping` với yêu cầu chuẩn `[toppings.first × 3]` |
| Hộp | chọn 1 trong 3 hộp → mẻ vào tủ | `pickBox(BoxType)` | `Scoring.box` |
- Lò: kim `progress = elapsed / ovenSec × bakeTarget` (tới `bakeTarget` đúng lúc `ovenSec`), tiếp tục tới 1.0 thì tự
  lấy ra (cháy). Lấy ra khi khu hoàn thiện đang bận → mẻ dừng nướng, nằm trong lò chờ (lò bận).
- Hết 6 trạm → `Scoring.evaluate` với `Order` chuẩn (frosting đầu, topping chuẩn, hộp chuẩn, khách regular) →
  `batchSize` cái (GĐ1: 3) cùng số sao vào tủ. `cancelPrep()` bỏ mẻ đang chuẩn bị.
- `ovenSec` mặc định 7 s; `BakeModifiers` (lò/dụng cụ đã nâng cấp) áp như V1.

**Khách đặc biệt** (`SpecialVisit` trong levels.json: `atSec`, `who` hoa|linh|kenji|vip, `recipe`, `scene`):
- Đến đúng `atSec`, đứng ở chỗ đặc biệt, kiên nhẫn `specialPatienceSec` (90 s). Chạm → `beginSpecial(id)`: session
  tự `paused = true`; UI chiếu cảnh truyện (nếu `scene` chưa xem) → vé đơn → `BakeSessionView` 6 trạm đầy đủ →
  `ResultCard` → `finishSpecial(id, BakeResult)` → xu = `(payment + tip) × specialRewardMult (2.0)`, `specialsDone++`,
  bỏ pause. Đơn được tạo bằng `OrderGenerator.makeOrder` (khách friend/vip).
- Cảnh truyện không gắn khách (prologue, finale) đặt ở `introScene` / `outroScene` của level.
- Cảnh đã xem (`GameState.seenScenes`) **dùng chung** giữa V1 và V2 có chủ ý: một câu chuyện, mỗi cảnh xem một lần.
  Chế độ "ngày" V1 chỉ còn để so sánh trong lúc chuyển đổi và sẽ gỡ ở Giai đoạn 2, nên việc V2 đánh dấu cảnh làm V1
  bỏ qua cảnh đó là chấp nhận được.
- Thoát giữa màn (Tạm dừng → Thoát / Chơi lại, hoặc app bị tắt) không cộng xu của lượt đó; hết giờ (thắng hay thua)
  mới cộng. Quảng cáo +30 giây dùng chung hạn mức rewarded trong ngày với các quảng cáo khác.

**Mục tiêu & sao**: `goal.type` ∈ `coins | customers | specialOrders`; `stars: [a, b, c]` cùng đơn vị; thắng ⇔ đạt `a`.
Hết giờ → kết thúc. `addTime(30)` (rewarded, 1 lần/lượt chơi) → chơi tiếp. Đạt mốc 3★ trước giờ: KHÔNG kết thúc sớm.

**Kết thúc**: `LevelResult { levelId, won, stars, coins, served, lost, specialsDone, bestCombo, perfectBakes,
recipeStars: Map<RecipeId,int> }`. `GameState.applyLevelResult(r)`: + xu (thua vẫn nhận xu đã kiếm), cập nhật nhiệm vụ
ngày (serveCustomers, earnStars, perfectBakes, fiveStarTreats, earnCoins, earnTips), `served`, thành thạo công thức.
Chưa lưu sao level (GĐ2).

## 4. `assets/config/levels.json`

```json
{
  "version": 1,
  "defaults": { "ovenSec": 7, "batchSize": 3, "slotCapacity": 6, "comboWindowSec": 6,
                "specialPatienceSec": 90, "specialRewardMult": 2.0, "maxQueue": 5, "jitterPct": 20 },
  "chapters": [ { "id": 1, "title": {"en": "Grandma's Kitchen", "vi": "Căn bếp của bà"}, "starsToUnlock": 0 } ],
  "levels": [ { "id": 1, "chapter": 1, "title": {"en": "...", "vi": "..."}, "durationSec": 120,
                "goal": {"type": "customers"}, "stars": [5, 7, 9], "menu": ["cupcakeVanilla"],
                "caseSlots": 3, "startStock": 3, "patienceSec": 40,
                "spawn": {"startEverySec": 14, "endEverySec": 10, "rushAtPct": 85, "rushEverySec": 7},
                "flexibleChance": 0, "specials": [], "introScene": "prologue", "outroScene": null,
                "special": false } ]
}
```
Trường của level ghi đè `defaults`. Món / cảnh dùng đúng `.name` của enum (`RecipeId`, `StorySceneId`).

**Chương 1 (gợi ý, dev-core cân lại bằng bot):**
| L | Thời gian | Mục tiêu | Món (mới in đậm) | Ô tủ | Đặc biệt / truyện |
|---|---|---|---|---|---|
| 1 | 120 s | khách 5/7/9 | **cupcakeVanilla** | 3 | intro: prologue |
| 2 | 120 | khách | + **cupcakeChocolate** | 3 | Hòa (hoa1) |
| 3 | 140 | xu | + **muffinBlueberry** | 3 | Linh (linh1) |
| 4 | 150 | xu | + **eggTart** | 3 | Hòa (hoa2) |
| 5 | 150 | khách | + **strawberryCake** | 4 | Kenji (kenji1) |
| 6 | 160 | xu | + **macaron** | 4 | Linh (linh2) |
| 7 | 170 | xu | + **redVelvetCupcake** | 4 | Kenji (kenji2) |
| 8 | 180 | khách | 4 món xoay vòng | 4 | Hòa (hoa3) |
| 9 | 180 | xu | + **matchaCake** | 4 | Linh (linh3) |
| 10 ★ | 200 | đơn đặc biệt 1/2/3 | + **cheesecake** | 4 | Kenji (kenji3) + Hòa + Linh, outro: finale |
Mỗi level tối đa 4 món trong menu. Độ khó tăng: `patienceSec` 40 → 28, `endEverySec` 10 → 5, `rushEverySec` 7 → 3.

## 5. Hợp đồng API (các khu vực phải khớp đúng tên)

`lib/core/level/` (dev-core):
```dart
class LevelConfig { LevelDefaults defaults; List<ChapterData> chapters; List<LevelData> levels; LevelData level(int id); }
abstract final class LevelConfigLoader { static Future<LevelConfig> load(AssetBundle bundle); static LevelConfig parse(String json); }
// AppServices có thêm `levels` (LevelConfig) — nạp trong main.dart trước runApp cùng lúc với save.

class LevelSession {
  LevelSession({required LevelData level, required LevelDefaults defaults, required BakeModifiers modifiers,
                int decorTipBonusPct = 0, math.Random? random});
  final LevelData level;
  bool paused;
  void advance(double dt);                       // gọi mỗi khung hình (Flame update)
  // Đọc
  double get timeLeft; double get elapsed; bool get isOver; bool get isRush;
  int get coins; int get served; int get lost; int get specialsDone; int get combo; double get comboMult;
  int get goalValue; int get starsNow;          // 0..3 theo mốc
  List<LevelCustomer> get customers;            // mọi khách đang trong cảnh (vào, chờ, quầy, rời đi)
  DisplayCase get displayCase; Kitchen get kitchen;
  List<SessionEvent> drainEvents();             // sự kiện từ lần gọi trước: sold, walkedOut, batchReady, burnt, caseFull, specialArrived, rushStarted, timeUp…
  ValueListenable<int> get hudRevision;         // tăng khi số liệu HUD đổi (xu, giây còn lại, combo, mục tiêu)
  // Hành động
  SellResult sell(int customerId);
  bool startBatch(RecipeId r); void cancelPrep();
  bool pickMould(MouldType m); void finishMix(double turns); bool takeOut(int oven);
  void finishFrost(double coverage); void addTopping(ToppingId t); bool pickBox(BoxType b);
  Order? beginSpecial(int customerId);          // tự pause; trả đơn để chạy BakeSessionView
  void finishSpecial(int customerId, BakeResult r); void cancelSpecial(int customerId);
  bool get canAddTime; void addTime(int seconds);
  LevelResult finish();                          // gọi khi isOver và UI xong hỏi +30 giây
}
class LevelCustomer { int id; Customer look; bool isSpecial; List<RecipeId> wants; double patience; double patienceMax;
                      CustomerPhase phase; int slot; /* vị trí quầy/hàng */ double phaseT; /* 0..1 cho hoạt cảnh */ }
enum CustomerPhase { entering, queued, atCounter, leavingHappy, leavingSad }
class DisplayCase { int get slots; List<CaseSlot> get items; int countOf(RecipeId r); }
class Kitchen { Batch? prep; List<Batch?> ovens; Batch? finish; /* Batch: recipe, stage, mouldChoices, toppingChoices, boxChoices, ovenProgress, toppingsPlaced, stars */ }
```
`lib/core/routes.dart`: `AppRoutes.levels = '/levels'`, `AppRoutes.level = '/level'` (args `LevelArgs(levelId)`),
`AppRoutes.levelResult = '/level/result'` (args `LevelResultArgs(LevelResult)`). `AdPlacement.extraTime` (thêm cuối enum).

`lib/game/level/` (dev-game) — widget DUY NHẤT ui import:
```dart
class LevelPlayView extends StatefulWidget {
  const LevelPlayView({required LevelSession session, required ValueChanged<int> onSpecialTap,
                       ValueChanged<SessionEvent>? onEvent /* âm thanh/rung ở ui */});
}
```
Chiếm khung 1280×720 (chừa y 0–64 cho HUD; HUD do ui vẽ đè). Flame `update(dt)` gọi `session.advance(dt)`. Vẽ sân
tiệm + bếp nhanh, nhận chạm và gọi hàm session. Không đọc/ghi `GameState`.

`lib/ui/level/` (dev-ui): `LevelSelectScreen`, `LevelScreen` (HUD, tạm dừng, cảnh truyện, đơn đặc biệt bằng
`BakeSessionView` + `ResultCard`, hỏi +30 giây), `LevelResultScreen`; thêm nút "Màn chơi" ở menu chính; đăng ký route
trong `ui_routes.dart`.

## 6. Hiệu năng
- Không cấp phát trong `advance`; danh sách khách tái dùng; tối đa ~25 khách trong cảnh.
- Ảnh nhân vật giải mã một lần ở cỡ hiển thị (~220 px cao) rồi cache; khách đi = trượt + nhún bằng biến đổi.
- HUD dựng lại theo `hudRevision`, không theo khung hình.
- Test: 25 khách + 3 phút mô phỏng, `advance` trung bình < 0.5 ms/khung trên máy dev.

## 7. Ảnh cần vẽ thêm (sau GĐ1)
Tủ kính trống (cửa kính, 3–6 ô), nền tiệm không có bánh trong tủ, 6 biểu tượng trạm bếp nhanh cỡ nhỏ, bong bóng ý
nghĩ, khay bánh nhỏ. Tạm thời vẽ bằng code (CustomPainter, bộ SL*) — **riêng nhân vật luôn dùng ảnh có sẵn**.
