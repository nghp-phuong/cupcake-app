# Thành phố V3, Giai đoạn 3: Ca bán trong tiệm của bà

Đặc tả do kiến trúc sư viết, trưởng phòng duyệt ngày 04/11/2026. Mọi người **chỉ code theo chữ ký đã chốt ở §8**.
Tài liệu nền: `city-gd1-spec.md`, `city-gd2-spec.md`, `thermion-api-notes.md` (§26 nói cách test trong gói tạm).

## Mặc định đã chốt (chủ dự án có thể đổi sau)
- **Hình thức ca:** mỗi ca có 4–6 khách 3D. Mỗi đơn đi qua đủ 6 trạm làm bánh (lớp 2D Flame), rồi tới phục vụ và thẻ kết quả. Thẻ nói rõ trạm nào chưa đạt (USP). Cuối ca hiện tổng kết.
- **Kinh tế:** `coinMult = 4`, thưởng hết ca 30 XP. Khoảng 4 ca lên cấp 5, khoảng 12–14 ca mua được lô s1.
- **Khách:** GĐ3 không có khách quen. Ông Hòa, Linh, Kenji chỉ ngồi làm nền. Khách VIP dùng `vip_01`/`vip_02`.
- **Món mùa** mở theo cấp, không khoá theo lịch.
- **Đóng ca sớm:** chỉ hiện toast, không có tổng kết. Đơn chỉ được tính khi bấm "Khách tiếp".
- **Làm lại (QC):** chỉ cho đơn ≤2★, mỗi đơn được một lần.
- **Interstitial:** tính theo `dayNumber`.
- **Sự kiện cãi nhau:** vẫn tắt khi ở phố, giữ nguyên mã.

## 1. Hiện trạng (API thật)
### Chuỗi làm bánh (dùng nguyên, không sửa)
- `BakeSessionView({order, modifiers, onComplete, tutorialFor, onTutorialShown, ovenLevel})` ở `lib/game/bake_session_view.dart:21-47`.
  - `onComplete` gọi đúng một lần.
  - Cần `RefMetrics.of(context)`, nên **phải bọc trong `RefFrame`**.
  - Nhận chạm bằng `Listener` mờ đục.
- Mô hình bánh ở `lib/core/models/bake.dart`:
  - `BakeOutcome` (:51-76);
  - `BakeModifiers.base` (:28-34);
  - `BakeResult`, với `net = payment + tip − cost` (:91-133).
- `Scoring.evaluate(order, customer, outcome, modifiers, decorTipBonusPct)` ở `lib/core/scoring.dart:114-171`.
  - XP = (15 + 5★), nhân ×1,5 nếu là VIP.
  - Có tip khi đạt từ 3★, tip được nhân thêm `(1 + decorTipBonusPct/100)`. **Buff No bụng truyền vào bằng `decorTipBonusPct = 10`.**
- `OrderGenerator.generateDay(level, unlockedRecipes, unlockedToppings, seenScenes, scene)` ở `lib/core/order_generator.dart:29-91`.
  - Số khách lấy từ `Economy.customersPerDay`.
  - Có VIP từ cấp 7.
  - Truyền `seenScenes` rỗng thì không có khách quen.
- **Cạm bẫy:** `Recipe.unlockLevel` và `Catalog.toppingUnlockLevel` đang theo thang v2. Các trạm dùng thang này để chọn khuôn và topping mồi:
  - `catalog.dart:259-292`;
  - `game/logic/station_setup.dart:13-38`;
  - `mould_station.dart:27`;
  - `bakery_game.dart:205`.

  Vì vậy **không đổi thang v2**. Cấp Mai được ánh xạ qua một bảng riêng (§4).
- `ResultCard(order, customer, outcome, result, canRemake, onNext, onRemake, busy)` ở `lib/ui/day/result_card.dart:43-62`.
  - Chân dung khách là sprite 2D, không khớp với chibi 3D. Vì vậy thêm tham số `showPortrait`.
- `OrderTicket(order, customer, height)` ở `lib/ui/day/order_ticket.dart:22-27`.
- Mã cũ tham khảo: `git show 58aa603:lib/core/day_controller.dart`. Đơn được tính khi bấm "Khách tiếp"; `canRemake` khi ≤2★.

### Cảnh 3D
- `Town3dView` (`town3d_view.dart`):
  - vòng cập nhật ở :393-449; khi đang trong tiệm chỉ gọi `embed.frame()` (:407-409);
  - thứ tự Stack ở :985-1025;
  - bộ đo chất lượng `auto` ở :350-389.
- `Shop3dEmbed` (`shop3d_view.dart:155-214`): nút A ở khe cửa là "Ra phố" (:1192-1215, :416-426).
- `Shop3dPilot` (`interact/pilot.dart`) chạy trên `Shop3dPilotWorld` (:34-52).
  - Mẫu đưa khách vào cảnh: `_spawnPair` (:1306-1346).
  - Gỡ khách: `_strays` (:1245-1252).
  - Bong bóng: `_bubble` (:1489), hiện là private.
- `Shop3dScene`:
  - `prepareModels` hiện chỉ nhận `regular_*` (:1034-1041);
  - `addActor` bỏ qua id trùng (:1084);
  - `removeActor` ở :1096-1104.
- Khách nền: `linh, hoa, kenji, vip_00` (`chibi_cast.dart:80-114`, :195-245). Đổi kịch bản bằng `ChibiActor.setScript(s, once)` (`chibi_actor.dart:444-452`).
- Các điểm trong layout (`shop3d_layout.dart`):
  - `queue[0..4]` và `counterSpots[0..2]` (z = 0,45, hướng π) ở :257-270;
  - `staffCashier (1.0, −1.45, 0)` ở :283;
  - `staffCashierSide` ở :359.
- `Shop3dFrameDriver` (native) tự vẽ trong hook (`shop3d_frame_driver.dart:27-58`).

### Ví và save
- `CityWallet` chưa có hàm cộng xu (`addXp` ở :129) và chưa có hàm tắt `fullBuff`.
- `CitySave.knownKeys` ở `city_save.dart:74-92`. Khoá lạ ở cấp trên cùng được giữ trong `extra`; khoá con lạ thì mất.
- `AdService` mới chỉ có quảng cáo thưởng. `showSLSimulatedAd` mở route hộp thoại (`app.dart:154-160`), cách này chưa thử trên web.

## 2. Kiến trúc lớp 2D Flame trên cảnh 3D
**Chốt:** dùng overlay trong cùng route, thêm một lớp vào Stack của `Town3dView`, sau `LocationBanner` và trước TownFade. **Không push route.**

| Pha | Lớp 2D | 3D |
|---|---|---|
| arriving / ordering | HUD nhẹ theo px màn (`Shop3dStyle.scaleOf`), không nền: chip "Khách 1/4", nút đóng ca, vé đơn và nút "Làm bánh" ở bên phải | Chạy; camera đóng khung Mai và khách |
| baking | `Positioned.fill(ColoredBox(cream) → SLScope → RefFrame → BakeSessionView)`, mờ đục, chặn mọi chạm | **Dừng vẽ** |
| result | Nền mờ nhạt (alpha ~0,25) và `FittedBox(SizedBox(720×440, ResultCard(showPortrait:false)))` đặt lệch phải, `textScaler: noScaling` | Chạy; khách 3D phản ứng và có bong bóng |
| finished | Nền mờ và thẻ tổng kết (`FittedBox`, khung ~760×520) | Chạy |

- **Dừng 3D khi đang làm bánh** (`ShiftLayerHost.setBaking(true)`):
  - native: `Shop3dFrameDriver.paused = true`;
  - web: `viewer.setRendering(false)`;
  - bỏ qua `embed.frame()`;
  - **tắt hoặc đặt lại `Shop3dQualityProbe`**, nếu không mức chất lượng sẽ tự hạ.

  Khi bật lại thì làm ngược các bước trên và đặt `_cameraDirty = true`.
- **Khoá Mai trong ca:** `pilot.locked` ẩn joystick, nút A/Ném/Vẫy và chạm vào nhân vật; `_onKey` của tiệm trả về `ignored`. `ShiftLayer` giữ `Focus(autofocus)`, Esc thì hỏi đóng ca. `PopScope(canPop:false)` để nút Back của Android cũng hỏi đóng ca.

**Thử nghiệm S0** (dev-game, chạy trên web trước):
- Trong chip debug (`?debug=1`, chỉ hiện khi ở trong tiệm), thêm hai nút:
  - **"bake"**: mở `RefFrame(BakeSessionView(order mẫu từ OrderGenerator(Random(1)), BakeModifiers.base))`, dừng 3D. Xong thì gỡ lớp, chạy lại 3D, in `outcome` ra log.
  - **"ad"**: gọi `showSLSimulatedAd(context, 2s)`.
- Đo bằng CDP:
  - (a) làm bánh khi 3D vẫn chạy;
  - (b) làm bánh khi 3D đã dừng;
  - (c) sau khi chạy lại.
- **Đạt khi:**
  - chạy 3 lần liền không treo, chibi chuyển động lại, không mất context WebGL;
  - kéo khuôn và trộn đúng toạ độ ở 1280 và 1600;
  - (b) nhẹ hơn (a) rõ rệt;
  - mức `auto` không bị hạ;
  - hộp thoại quảng cáo hiện trên canvas, đóng xong joystick và chạm 3D vẫn dùng được.
- **Phương án dự phòng:**
  - `setRendering` hỏng thì chỉ bỏ `embed.frame()`;
  - hộp thoại route hỏng thì dựng `presenter` ngay trong lớp ca.
- Ghi kết quả vào `thermion-api-notes.md` §30.

## 3. Dữ liệu và luồng
**Luồng ca:**
1. Mở ca: `ShiftSession(game)` sinh plan bằng `OrderGenerator(level = cấp Mai, recipes/toppings = RecipeUnlocks.*At(level), seenScenes: {})`.
2. Mỗi khách: `arriving → customerArrived → ordering → startBaking → baking → completeBake(outcome) → result`.
   - Ở `result`: `next()` **cộng đơn vào ví và thống kê**, rồi chuyển sang `arriving` của khách sau, hoặc `finished` nếu hết khách.
   - `remake()` đưa đơn từ `result` về `baking`, chỉ khi ≤2★ và mỗi đơn một lần.
3. `finished`: cộng `completeBonusXp`, tạo `ShiftSummary`, gọi `recordShift`.
4. `applyDouble()`: cộng thêm `net` một lần.
5. `abort()`: đơn đang ở `result` vẫn được tính, đơn đang làm thì bỏ; không có thưởng, không có x2; chuyển sang `aborted`.

**Buff No bụng:**
- Lúc mở ca, lưu lại `buffActive = wallet.fullBuff`. Mọi đơn trong ca dùng `decorTipBonusPct = 10`.
- `consumeFullBuff()` chạy ở lần tính đơn đầu tiên. Vì vậy huỷ ca trước khi xong đơn đầu thì buff vẫn còn.

**Xu:**
- `payment`, `tip`, `cost` đều nhân `coinMult = 4`.
- Dựng lại `BakeResult` với các số đã nhân để `ResultCard` hiện đúng.
- `buffTip` = tip − tip khi không có buff.

**Thoát app giữa ca:** không lưu ca dở. Đơn đã bấm "Khách tiếp" đã nằm trong ví (autosave 300 ms và flush khi onPause). Mở lại thì ra phố như thường.

**Save:** không tăng `v`. Thêm **khoá cấp trên cùng `"bakery"`** vào `knownKeys` (bản GĐ2 gặp khoá này sẽ cất vào `extra`, nên không mất dữ liệu):
```json
"bakery": {"shifts":0,"orders":0,"stars":0,"five":0,"coins":0,"best":0,"tutorial":["mould","mix"],"recipeSeen":0,"adDay":0}
```
- Các bộ đếm là số nguyên trong [0, 2^31−1]; `coins` và `best` trong [0, 2^53−1].
- `tutorial` là danh sách tên `StationId`, giữ cả chuỗi lạ.
- `recipeSeen` trong 0..30. Giá trị 0 nghĩa là lấy cấp hiện tại, không báo bù.
- `adDay` là `dayNumber` của lần interstitial gần nhất.
- Trường sai kiểu thì về mặc định và thêm `bakery.x` vào `bad`.

## 4. Mở món theo cấp và kinh tế
`RecipeUnlocks.maiLevelForStage` áp cho cả món lẫn topping:

| Thang v2 | 1 | 2 | 3 | 4 | 5 | 6 | 8 | 10 | 12 | 21 | 24 | 27 | 31 | 34 | 38 | 43 | 47 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Cấp Mai** | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 11 | 12 | 14 | 16 | 18 | 20 | 23 | 26 |
| Món | cupcake vani + choco | muffin | tart trứng | bánh dâu | macaron | red velvet | matcha | cheesecake | sinh nhật | croissant | pain au choc | madeleine | éclair | tart trái cây | pie táo | Trung thu | Bûche |

- Topping: blueberry 2, mint 3, sugarPearl 5, candle 9, almond/powdered 11, kiwi 18, sesame 23, meringue 26.
- Cấp 10 và 15 không mở món; hai cấp này mở lô.
- **Lên cấp:**
  - Tổng kết ca hiện "Lên cấp!" và mục "Mở mới": món, topping, "khách VIP" (cấp 7), "thêm khách" (cấp 4, 10).
  - Lên cấp khi đang ở ngoài tiệm: lúc mở ca hiện thẻ "Mở mới!" theo `recipeSeen`.
  - Lên cấp giữa ca: toast `cityLevelUp`.

Số liệu kinh tế (`coinMult = 4`, `completeBonusXp = 30`):

| Cấp Mai | Khách/ca | Xu ròng/ca ở 4★ (3★ ≈ ×0,6) | XP/ca ở 4★ |
|---|---|---|---|
| 1 | 4 | ~480 | 170 |
| 2–3 | 4 | ~530–570 | 170 |
| 4–6 | 5 | ~830–880 | 205 |
| 10+ | 6 | ~1 200+ | ~250 |

Mốc dự kiến:
- cấp 5 khoảng ca thứ 4;
- lô s1 khoảng ca 12–14 nếu chơi đều 3,5★, mỗi ngày ăn một bữa và làm tóc một lần;
- lô s3 và s4 chờ thu nhập từ chi nhánh ở GĐ4.

## 5. Luồng UI
1. **Vào tiệm lần đầu** (`bakery.shifts == 0`): hiện toast `shiftHintCounter` và mũi tên `Shop3dTargetArrow` chỉ vào quầy.
2. **Mở ca.** Vùng quầy gồm:
   - phía khách: x∈[−2,2; 2,0], z∈[0,1; 1,2];
   - phía bếp: z∈[−1,9; −1,0].

   Cửa được ưu tiên hơn quầy. Khi Mai đứng trong vùng quầy, nút A đổi thành `shiftOpen`. Bấm vào thì:
   - màn mờ 0,4 s;
   - Mai đặt đồ đang cầm xuống, đứng ở `staffCashier` (yaw 0) và bị khoá;
   - Nora đứng ở `staffCase`;
   - khách nền ngồi yên suốt ca;
   - nếu có món mới thì hiện thẻ "Mở mới!" trước.
3. **arriving:** khách tiến tới `counterSpots[2]`, khách sau đứng ở `queue[0]`. Hiện chip `dayCustomerProgress` và `shiftCustomerComing`. Sau 12 s khách chưa tới thì đặt thẳng vào quầy.
4. **ordering:** bong bóng `orderLineText`, `OrderTicket` bên phải, nút `dayStartBaking`.
5. **baking:** lớp mờ đục, 6 trạm, hướng dẫn hiện lần đầu (`tutorialFor`).
6. **result:**
   - khách phản ứng: ≥4★ `happy`, 3★ `talk`, ≤2★ phụng phịu;
   - bong bóng `feedbackText(complaint ?? praise)`;
   - `ResultCard(showPortrait:false)`;
   - đơn ≤2★, chưa làm lại và còn lượt quảng cáo thưởng thì có nút `dayRemakeWithAd`;
   - nút `dayNextCustomer` gọi `next()`.
7. **finished:** tổng kết, nút `summaryDouble` (chỉ hiện khi người chơi bấm được và còn lượt), nút `commonDone`.
   - Bấm `commonDone`: nếu `interstitialDue` thì gọi `ads.showInterstitial` và `registerInterstitialShown`, rồi `host.close()`.
8. **Đóng ca sớm** (nút X ≥48 dp, Esc hoặc Back, kể cả lúc đang làm bánh): panel ngay trong lớp với `dayExitConfirmTitle/Body`, `shiftCloseEarly`, `commonCancel`. Xác nhận thì `abort()`, hiện toast `shiftClosedToast(coins)`, rồi `host.close()`.
9. **Interstitial:** chỉ ở bước 7; khi `dayNumber ≥ 4` và `dayNumber − adDay ≥ 2`; không bao giờ khi có `removeAds`.

## 6. Khoá arb
**Thêm mới:**

| Khoá | en | vi | Placeholder |
|---|---|---|---|
| `shiftOpen` | Open shop | Mở ca | |
| `shiftHintCounter` | Go to the counter and tap “Open shop” to start selling | Tới quầy rồi bấm “Mở ca” để bắt đầu bán | |
| `shiftCustomerComing` | A customer is on the way… | Khách đang tới… | |
| `shiftSummaryTitle` | Shift complete! | Hết ca rồi! | |
| `shiftCloseEarly` | Close early | Đóng ca sớm | |
| `shiftClosedToast` | Shop closed · +{coins} coins kept | Đã đóng ca · giữ +{coins} xu | coins:int |
| `shiftBuffTip` | Full & happy: +{amount} tips | No bụng: +{amount} tip | amount:int |

**Sửa nội dung, giữ nguyên khoá và placeholder:**

| Khoá | en | vi |
|---|---|---|
| `summaryDayBonusXp` | Shift bonus +{xp} XP | Thưởng hết ca +{xp} XP |
| `summaryLevelUp` | Level up! Mai is now level {level} | Lên cấp! Mai đạt cấp {level} |
| `dayExitConfirmTitle` | Close the shop early? | Đóng ca sớm? |
| `dayExitConfirmBody` | You keep the coins from customers already served, but there's no shift bonus. | Xu của các khách đã phục vụ vẫn giữ, nhưng không có thưởng hết ca. |

**Dùng lại:** `summary*`, `unlock*`, `day*`, `result*`, `feedback*`, `orderLine*`, `customer*`, `adSimulated*`, `adRewardGranted`, `adNotCompleted`, `adsLimitReached`, `cityLevelUp`, `commonDone/Cancel/Close`.

## 7. Test
**core**
1. `RecipeUnlocks`:
   - đủ 18 món, cấp tăng dần theo thứ tự Catalog;
   - cấp 1 có vani và choco;
   - cấp 30 mở đủ;
   - topping mở ở `recipeLevel(r)` khớp với `station_setup` theo thang v2;
   - `newRecipes(4,5) == [macaron]`.
2. Plan theo seed: số khách 4/5/6; chỉ món đã mở; không khách quen; không có VIP dưới cấp 7.
3. Gọi hàm sai pha thì không làm gì.
4. Chấm điểm: xu nhân ×4; buff tip ×1,1 và `buffTip` đúng; XP đúng.
5. `next()`: cộng ví và thống kê; trả cấp mới; tắt `fullBuff` ở lần tính đơn đầu.
6. Remake: chỉ khi ≤2★, mỗi đơn một lần, không tính đơn hai lần.
7. Hết ca: thưởng 30 XP, tổng tiền khớp, sao trung bình, món mới, `shifts++`, `best`.
8. `applyDouble` chỉ chạy một lần; không áp khi `aborted` hoặc `net == 0`.
9. `abort`: đơn ở `result` vẫn được tính; không có thưởng; buff còn nếu huỷ trước đơn đầu.
10. Save `bakery`:
    - lưu rồi nạp lại giữ đủ; thiếu trường thì mặc định;
    - trường sai kiểu thì `bad` và backup một lần;
    - save GĐ2 nạp được;
    - bản GĐ2 nạp save GĐ3 thì `bakery` nằm trong `extra` và ghi lại nguyên vẹn.
11. Interstitial: ngày 1–3 không hiện; ngày 4 có; ngày 5 không; ngày 6 có; `removeAds` thì không bao giờ.
12. `CityWallet.earn` và `consumeFullBuff`.
13. `tutorialSeen` và `recipeSeen` lưu rồi nạp lại đúng.
14. Mô phỏng: bot 3,5★, mỗi ngày ăn một bữa. Lên cấp 5 trong khoảng ca 3–6; có 8 000 xu trong khoảng ca 10–16. In bảng kết quả.
15. `CityDebugParams`: `day=6` đặt `dayNumber` và bật save bộ nhớ.

**game** (dùng world giả như `pilot_test`)
1. `begin`: khách 1 tới quầy; khách 2 đứng ở `queue[0]`.
2. `dismiss`: khách ra và được gỡ; khách sau tiến lên; quá hạn thì đặt thẳng vào quầy.
3. `castFor`: id không trùng nhau; VIP chỉ là `vip_01`/`vip_02`; không trùng khách nền.
4. Khách nền ngồi suốt ca, hết ca quay lại vòng cũ.
5. `pilot.locked` chặn điều khiển; `pilot.say` hiện bong bóng.
6. `atShopCounter` đúng, và cửa được ưu tiên hơn quầy.
7. `ShiftBinder`: đổi pha thì gọi đúng hàm của stage; stage báo khách tới thì gọi `customerArrived`.
8. 7 test làm bánh hiện có vẫn qua.

**ui**
1. Các pha hiện đúng widget; mọi vùng chạm ≥48 dp.
2. Bấm "Làm bánh" thì `setBaking(true)`, `RefFrame` và `BakeSessionView` mờ đục; `completeBake` thì `setBaking(false)` và hiện `ResultCard`.
3. Có lời chê thì hiện `feedbackNeedsWork`; `showPortrait:false` thì không có `CustomerImage`.
4. Remake: quảng cáo trả `true` thì về `baking`, trả `false` thì hiện toast.
5. Tổng kết: nút x2 hiện đúng điều kiện; "Xong" gọi interstitial khi đến hạn, rồi `close`.
6. Đóng ca bằng X, Esc hoặc Back: hiện xác nhận, rồi `abort`, toast, `close`.
7. Không tràn chữ ở vi/en với 1280×720, 1600×720, 800×360.

## 8. Chữ ký chốt
```dart
// core: lib/core/city/recipe_unlocks.dart
abstract final class RecipeUnlocks {
  static const Map<int,int> maiLevelForStage; // bảng §4
  static int recipeLevel(RecipeId id); static int toppingLevel(ToppingId id);
  static List<RecipeId> recipesAt(int maiLevel); static List<ToppingId> toppingsAt(int maiLevel);
  static List<RecipeId> newRecipes(int from, int to); static List<ToppingId> newToppings(int from, int to); }
// core: lib/core/shift/shift_economy.dart
abstract final class ShiftEconomy { static const coinMult = 4, completeBonusXp = 30, buffTipPct = 10;
  static const arriveTimeout = Duration(seconds: 12); static int customersFor(int maiLevel); }
// core: lib/core/shift/shift_session.dart
enum ShiftPhase { arriving, ordering, baking, result, finished, aborted }
class ShiftOrder { final int index; final Customer customer; final Order order; }
class ShiftServed { final ShiftOrder order; final BakeOutcome outcome; final BakeResult result /*xu đã nhân*/; final int buffTip; }
class ShiftSummary { final bool completed; final int served, total, revenue, tips, costs, net, buffTips, doubledCoins,
  xp, bonusXp, levelBefore, levelAfter; final double averageStars; final List<RecipeId> newRecipes;
  final List<ToppingId> newToppings; final bool moreCustomers, vipGuests; final List<ShiftServed> records;
  bool get leveledUp; int get totalCoins; }
class ShiftSession extends ChangeNotifier {
  ShiftSession({required CityGame game, math.Random? random});
  int get levelAtStart; bool get buffActive; List<ShiftOrder> get orders;
  ShiftPhase get phase; int get index; int get total; ShiftOrder get current; ShiftServed? get served;
  List<ShiftServed> get records; BakeModifiers get modifiers;
  Set<StationId> get tutorialFor; void tutorialShown(StationId s);
  List<RecipeId> get recipeNews; void acknowledgeRecipeNews();
  void customerArrived(); void startBaking(); ShiftServed? completeBake(BakeOutcome o);
  bool get canRemake; void remake(); int? next(); ShiftSummary? get summary;
  bool get canDouble; void applyDouble(); void abort(); }
// core: lib/core/shift/shift_host.dart (Dart thuần, KHÔNG import thermion)
abstract interface class ShiftLayerHost { void setBaking(bool on); void close(); }
// core: CityWallet thêm
int? earn({int coins = 0, int xp = 0}); bool consumeFullBuff();
// core: CityGame thêm (ShiftStats ở lib/core/shift/shift_stats.dart)
ShiftStats get bakery; void recordOrder({required int stars, required int coins});
void recordShift({required int coins, required bool completed}); void addBakeryCoins(int coins);
Set<StationId> get tutorialSeen; void markTutorialSeen(StationId s);
int get recipeSeen; void markRecipeSeen(int level);
bool get interstitialDue; void registerInterstitialShown();
// core: AdService thêm
Future<void> showInterstitial(BuildContext context); // bản Fake dùng presenter, không cộng vào sổ quảng cáo thưởng
// ui
ShiftLayer({required ShiftSession session, required ShiftLayerHost host, required AdService ads, required CityGame game});
ResultCard({..., bool showPortrait = true});
// game
Town3dView({..., ShiftSession Function()? openShift,
  Widget Function(BuildContext, ShiftSession, ShiftLayerHost)? shiftLayer, bool shiftHint = false});
class Shop3dFrameDriver { bool paused; }
```

## 9. Các đợt
| Đợt | Mã | Người | Việc | File |
|---|---|---|---|---|
| 0 | S0 | dev-game | Thử nghiệm làm bánh và QC đè lên 3D (§2) | `town3d_view.dart` (chỉ phần debug), `shop3d_frame_driver.dart` (`paused`), `docs/v3/thermion-api-notes.md` §30 |
| 0 | L1 | localizer | Khoá §6 | `.arb` |
| 1 | C1 | dev-core | Toàn bộ core §3–§4, `debug_params` (`day=`), comment `unlockLevel`, test core | `lib/core/city/{recipe_unlocks,city_wallet,city_game}.dart`, `lib/core/shift/*`, `lib/core/save/city_save.dart`, `lib/core/services/ad_service.dart`, `lib/core/debug_params.dart`, `lib/core/catalog.dart` (chỉ comment), `test/core/**` |
| 1 | G1 | dev-game | `ShiftStage`, `castFor`; `ChibiCast.{ambientGuestIds, loopFor, seatedIdle}`; `Shop3dPilot.{say, locked}`; `prepareModels` nhận `vip_01/02`; `TownRules.{atShopCounter, shiftMai*}`; test | `lib/game/shop3d/shift/{shift_stage,shift_cast}.dart`, `chibi/chibi_cast.dart`, `interact/pilot.dart`, `shop3d_scene.dart`, `town3d/town_rules.dart`, `test/game/shop3d/shift/**`, `test/game/town3d/town_rules_test.dart` |
| 2 | U1 | dev-ui | `ShiftLayer` (các pha, PopScope, Esc, xác nhận, toast), thẻ tổng kết, thẻ "Mở mới!", `ResultCard.showPortrait`, test | `lib/ui/shift/**`, `lib/ui/day/result_card.dart`, `test/ui/shift/**` |
| 2 | G2 | dev-game | Nút A "Mở ca"; màn mờ, đưa Mai vào quầy và khoá; `ShiftBinder`; camera đóng khung quầy; `Town3dView.{openShift, shiftLayer, shiftHint}` và `ShiftLayerHost` (dừng/chạy 3D, tắt probe); gỡ debug S0; test binder | `shop3d_view.dart`, `town3d_view.dart`, `shop3d_frame_driver.dart`, `shift/shift_binder.dart`, test |
| 3 | G3 | dev-game | Nối vào `Town3dPage` | `town3d_page.dart` |
| 3 | C2 | trưởng phòng | analyze, test, build | — |
| 4 | QA | tester | 9 kịch bản trên web | — |
