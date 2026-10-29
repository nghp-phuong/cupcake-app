# Sugarleaf Bakery — Đặc tả Alpha (hợp đồng cho cả nhóm)

> Tài liệu này là **hợp đồng**: tên file, tên class, chữ ký công khai, khoá l10n và số liệu ở đây là chốt.
> Ai cần đổi hợp đồng thì **không tự đổi** — ghi vào mục "Việc cho người khác" trong báo cáo để trưởng phòng quyết.
> Nguồn yêu cầu: `CLAUDE.md` + yêu cầu chủ dự án "xây dựng app hoàn chỉnh đến giai đoạn alpha … build html … chiều ngang".

---

## 0. Mục tiêu và phạm vi

**Làm (alpha):**
- App Flutter + Flame, **chỉ ngang màn hình**, khung tham chiếu **1280×720**, chạy được trên web (`flutter build web --release`) và Android.
- Menu chính; ngày kinh doanh 4–6 khách; 6 trạm làm bánh chơi bằng chuột + cảm ứng; chấm điểm + thẻ phản hồi (khen trạm tốt nhất, chê trạm yếu nhất); tổng kết ngày.
- 10 món; cấp tiệm 1–15; nâng cấp lò (5 cấp) + 3 dụng cụ (3 cấp); trang trí tiệm 5 ô (+% tip); sổ công thức (thành thạo 0–3★).
- 3 nhiệm vụ ngày; quà đăng nhập 7 ngày; truyện chương 1 (Mai + ông Hòa, Linh, Kenji; 11 cảnh).
- Quảng cáo và IAP **giả lập** (interface + bản fake, không SDK, không trừ tiền thật).
- Cài đặt: ngôn ngữ en/vi/theo máy, âm thanh bật/tắt, xoá dữ liệu. Lưu/tải tự động (shared_preferences).
- Ngôn ngữ en (nguồn) + vi, mọi chuỗi qua `AppLocalizations`.

**Không làm (alpha):** ảnh vẽ tay/sprite, file âm thanh, SDK quảng cáo/IAP thật, kho nguyên liệu/nguyên liệu hiếm, bà Rosa, mèo Mochi, món mùa, đồng hồ kiên nhẫn của khách, đám mây/đăng nhập tài khoản, analytics, iOS.

---

## 1. Kỹ thuật nền (dev-core)

| Mục | Chốt |
|---|---|
| Tạo dự án | Trong thư mục gốc: `flutter create --org com.sugarleafbakery --project-name sugarleaf_bakery --platforms=android,web .` (không xoá `CLAUDE.md`, `.claude/`, `docs/`) |
| Package | `sugarleaf_bakery` → import `package:sugarleaf_bakery/...` |
| Phụ thuộc | `flame` (bản mới nhất tương thích Dart 3.8, thêm bằng `flutter pub add flame`), `shared_preferences`, `google_fonts`, `flutter_localizations: {sdk: flutter}`, `intl: any`. Không thêm `provider`/router package. |
| pubspec | `flutter: generate: true`, `uses-material-design: true` |
| `l10n.yaml` | xem dưới |
| Khoá hướng | `main.dart`: `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`; `AndroidManifest.xml`: `android:screenOrientation="sensorLandscape"`; `web/manifest.json`: `"orientation": "landscape"` |
| Web | `web/index.html` title "Sugarleaf Bakery", `theme_color`/`background_color` `#FFF4E6` |
| Android | label "Sugarleaf Bakery", applicationId `com.sugarleafbakery.sugarleaf_bakery` (mặc định của flutter create) |
| Font | `google_fonts`: tiêu đề **Fredoka** khi en; khi vi tiêu đề dùng **Nunito w800** (tránh thiếu dấu tiếng Việt); nội dung **Nunito**. `AppTheme.build(locale:, useGoogleFonts:)` — test truyền `useGoogleFonts: false` (không gọi mạng). |

`l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/gen
synthetic-package: false
nullable-getter: false
```
Import: `import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';`. Thư mục `lib/l10n/gen/` là **file sinh tự động** — không ai sửa tay (sinh khi `flutter pub get` / `flutter gen-l10n`).

### 1.1 Khung tham chiếu 1280×720 (chốt cách co giãn)
`lib/core/ref_frame.dart` — `RefFrame(child:)`:
- Đặt con trong `SizedBox(1280, 720)` bọc `FittedBox(fit: BoxFit.contain)`, phần thừa (letterbox) tô màu kem `#FFF4E6`.
- **Ghi đè `MediaQuery`** bên trong: `size: Size(1280, 720)`, `padding/viewPadding/viewInsets: EdgeInsets.zero`, `textScaler: TextScaler.noScaling`.
- Nếu màn thật dọc (width < height) → hiện chữ `rotateDevicePrompt` + biểu tượng xoay vẽ bằng code (vẫn cho chơi trong khung letterbox).
- `SugarleafApp` dùng `MaterialApp(builder: (ctx, child) => RefFrame(child: child!))` → **mọi màn, dialog, Flame đều dùng toạ độ 1280×720 cố định**. Dev-ui/dev-game bố cục bằng toạ độ tuyệt đối/Flex trong 1280×720, không cần tính tỉ lệ.

### 1.2 Bảng màu và theme (`lib/core/constants.dart`, `lib/core/theme.dart`)
```dart
const Size kRefSize = Size(1280, 720);
abstract final class AppColors {
  static const cream = Color(0xFFFFF4E6);
  static const strawberry = Color(0xFFF49AB0);
  static const mint = Color(0xFFA8DCC8);
  static const butter = Color(0xFFFFD27A);
  static const caramel = Color(0xFFB9805A);
  static const chocolate = Color(0xFF5A3E36); // màu chữ
  static const good = Color(0xFF7BC47F);
  static const bad = Color(0xFFE86A5C);
}
abstract final class AppTheme {
  static ThemeData build({required Locale locale, bool useGoogleFonts = true});
}
```
Nút: bo 18px, viền `AppColors.caramel` 2px, bóng mềm (blur 8, offset (0,3), alpha 0.15). Nền màn: kem.

---

## 2. Hợp đồng `lib/core` (dev-core viết, game/ui chỉ dùng)

### 2.1 Danh sách file lib/core
| File | Nội dung công khai |
|---|---|
| `constants.dart` | `kRefSize`, `AppColors` |
| `theme.dart` | `AppTheme` |
| `ref_frame.dart` | `RefFrame` |
| (ngoài core) `lib/app.dart` | `SugarleafApp` |
| `app_scope.dart` | `AppServices`, `AppScope` |
| `routes.dart` | `AppRoutes`, `DaySummaryArgs` |
| `models/ids.dart` | toàn bộ enum |
| `models/recipe.dart` | `Recipe` |
| `models/order.dart` | `ToppingRequest`, `Order` |
| `models/customer.dart` | `Customer` |
| `models/bake.dart` | `BakeModifiers`, `BakeOutcome`, `StationScore`, `BakeResult` |
| `models/day_summary.dart` | `OrderRecord`, `Unlock`, `DaySummary` |
| `models/quest.dart` | `QuestDef`, `QuestProgress`, `LoginReward` |
| `models/story.dart` | `StoryLine`, `StoryScene` |
| `models/decor.dart` | `DecorItem` |
| `models/upgrade.dart` | `OvenTier`, `ToolTier` |
| `catalog.dart` | `Catalog` (dữ liệu tĩnh: món, topping, decor, cảnh truyện, nhiệm vụ, quà) |
| `economy.dart` | `Economy` (số liệu + hàm thuần) |
| `scoring.dart` | `Scoring` (**toàn bộ chấm điểm nằm ở core**) |
| `order_generator.dart` | `OrderGenerator` (thuần, Random có seed) |
| `game_state.dart` | `GameState extends ChangeNotifier` |
| `save_repository.dart` | `SaveRepository`, `PrefsSaveRepository`, `MemorySaveRepository` |
| `day_controller.dart` | `DayController extends ChangeNotifier` |
| `services/ad_service.dart` | `AdService`, `FakeAdService` (+ dialog giả lập) |
| `services/iap_service.dart` | `IapProduct`, `IapService`, `FakeIapService` |
| `services/audio_service.dart` | `AudioService`, `FakeAudioService` |
| `l10n_lookup.dart` | `extension AppL10nLookup on AppLocalizations` (tra chuỗi theo enum) |
| `art/cake_art.dart` | `CakeVisual`, `CakeArt.paint(Canvas, Rect, CakeVisual)` |
| `art/item_art.dart` | `ItemArt.paintTopping/paintMould/paintBox/paintFrostingSwatch(Canvas, Rect, …)`, `ItemArt.coin/gem/star(Canvas, Rect)` |
| `art/customer_art.dart` | `CustomerArt.paint(Canvas, Rect, Customer, {CustomerMood mood})`, `CustomerArt.paintSpeaker(Canvas, Rect, Speaker)` |
| `art/shop_art.dart` | `ShopArt.paint(Canvas, Size, Map<DecorSlot, DecorId?> equipped)` (nền tiệm + đồ trang trí) |

**Mọi hình vẽ dùng chung gom ở `lib/core/art/`** (hàm nhận `Canvas` nên dùng được cả trong `CustomPainter` lẫn `Component.render` của Flame). Hình chỉ riêng trạm (tô trộn, lò, túi kem…) do dev-game vẽ trong `lib/game/`.

### 2.2 Enum (`lib/core/models/ids.dart`) — tên chốt, dùng `.name` làm khoá lưu
```dart
enum RecipeId { cupcakeVanilla, cupcakeChocolate, muffinBlueberry, eggTart, strawberryCake, macaron, redVelvetCupcake, matchaCake, cheesecake, birthdayCake }
enum MouldType { cupcakeLiner, muffinCup, tartShell, roundPan, macaronMat, springformPan, tallPan }
enum BatterType { vanilla, chocolate, redVelvet, matcha, butter, almond, cheese }
enum FrostingId { vanillaCream, chocolateGanache, strawberryCream, matchaCream, creamCheese, custard }
enum ToppingId { sprinkles, strawberry, cherry, chocolateChips, blueberry, mintLeaf, sugarPearl, candle }
enum BoxType { small, cake, gift }
enum StationId { mould, mix, bake, frost, topping, box }   // thứ tự chơi
enum StationIssue { none, wrongMould, underMixed, overMixed, underBaked, burnt, patchy, missingTopping, wrongTopping, wrongBox }
enum FeedbackKey { allGood, mouldGood, mixGood, bakeGood, frostGood, toppingGood, boxGood,
                   mouldWrong, mixUnder, mixOver, bakeUnder, bakeBurnt, frostPatchy, toppingMissing, toppingWrong, boxWrong }
enum CustomerKind { regular, friend, vip }
enum FriendId { hoa, linh, kenji }
enum CustomerMood { neutral, happy, sad }
enum Speaker { narrator, mai, hoa, linh, kenji }
enum OrderLineKind { generic1, generic2, generic3, generic4, generic5, generic6, vip, hoa, linh, kenji }
enum ToolId { whisk, pipingBag, tongs }
enum DecorSlot { wallpaper, floor, counter, window, plant }
enum DecorId { wallpaperStripes, wallpaperFloral, floorCheckered, floorHerringbone, counterFlowers, counterCakeStand, windowCurtains, windowSeaView, plantFern, plantLemonTree }
enum QuestType { serveCustomers, earnStars, perfectBakes, fiveStarTreats, earnCoins, earnTips }
enum StorySceneId { prologue, hoa1, linh1, hoa2, kenji1, linh2, kenji2, hoa3, linh3, kenji3, finale }
enum AdPlacement { doubleCoins, remake, freeGem }
enum IapProductId { starterPack, pantryS, pantryM, pantryL, decorSetSeaside, removeAds }
enum PurchaseResult { ok, notEnoughCoins, notEnoughGems, locked, maxed, alreadyOwned }
enum UnlockKind { recipe, topping, vipGuests, upgrade, decor, moreCustomers }
enum LanguagePref { system, en, vi }
```

### 2.3 Mô hình dữ liệu (bất biến, `const` constructor, `==`/`hashCode` cho Order/ToppingRequest)
```dart
class Recipe {
  const Recipe({required this.id, required this.unlockLevel, required this.price, required this.cost,
    required this.mould, required this.batter, required this.frostings, required this.toppings,
    required this.mixTurns, required this.bakeTarget, required this.box});
  final RecipeId id;
  final int unlockLevel;
  final int price;              // xu khi 4★ (hệ số 1.0)
  final int cost;               // chi phí nguyên liệu, trừ mỗi lần phục vụ
  final MouldType mould;
  final BatterType batter;
  final List<FrostingId> frostings;   // phần tử đầu = mặc định
  final List<ToppingId> toppings;     // topping được phép gọi
  final int mixTurns;           // số vòng trộn mục tiêu
  final double bakeTarget;      // vị trí mục tiêu trên thanh nướng 0..1
  final BoxType box;            // hộp chuẩn (khách VIP luôn đòi BoxType.gift)
}

class ToppingRequest { const ToppingRequest(this.topping, this.count); final ToppingId topping; final int count; }

class Order {
  const Order({required this.id, required this.recipe, required this.frosting,
    required this.toppings, required this.box, required this.line});
  final int id;                        // số thứ tự trong ngày, 0-based
  final RecipeId recipe;
  final FrostingId frosting;
  final List<ToppingRequest> toppings; // 1–2 loại, mỗi loại count 1–4
  final BoxType box;
  final OrderLineKind line;            // câu gọi món
  Recipe get recipeData => Catalog.recipe(recipe);
}

class Customer {
  const Customer({required this.kind, this.friend, required this.appearanceSeed});
  final CustomerKind kind;
  final FriendId? friend;              // != null khi kind == friend
  final int appearanceSeed;            // CustomerArt dùng để chọn màu tóc/áo
}

/// Thông số do nâng cấp ảnh hưởng — game dùng để vẽ vùng/brush, Scoring dùng để chấm.
class BakeModifiers {
  const BakeModifiers({required this.bakePerfectHalfWidth, required this.bakeOkHalfWidth,
    required this.mixPerfectBand, required this.frostBrushRadius, required this.toppingSnapRadius});
  final double bakePerfectHalfWidth;   // 0.05..0.10 (theo lò)
  final double bakeOkHalfWidth;        // 0.15..0.20
  final double mixPerfectBand;         // 0.10..0.20 (theo phới)
  final double frostBrushRadius;       // px tham chiếu 22..32 (theo túi kem)
  final double toppingSnapRadius;      // px tham chiếu 0..32 (theo kẹp)
  static const base = BakeModifiers(bakePerfectHalfWidth: .05, bakeOkHalfWidth: .15,
    mixPerfectBand: .10, frostBrushRadius: 22, toppingSnapRadius: 0);
}

/// Số đo THÔ do game trả về sau 6 trạm. Game không tự chấm điểm.
class BakeOutcome {
  const BakeOutcome({required this.wrongMouldDrops, required this.mixTurns, required this.bakeRelease,
    required this.frostCoverage, required this.toppingsPlaced, required this.boxChosen});
  final int wrongMouldDrops;                 // số lần thả sai khuôn
  final double mixTurns;                     // số vòng đã trộn (thực)
  final double bakeRelease;                  // vị trí thả tay 0..1 (giữ tới 1.0 = tự thả, cháy)
  final double frostCoverage;                // 0..1 tỉ lệ điểm đường gợi ý được phủ
  final Map<ToppingId, int> toppingsPlaced;  // CHỈ topping nằm trên bánh (đã tính snap)
  final BoxType boxChosen;
}

class StationScore {
  const StationScore(this.station, this.score, this.issue);
  final StationId station; final double score; /*0..1*/ final StationIssue issue;
}

class BakeResult {
  final Map<StationId, StationScore> stations;  // đủ 6 trạm
  final double quality;      // 0..1
  final int stars;           // 1..5
  final int payment;         // xu khách trả (chưa trừ cost)
  final int tip;
  final int cost;            // = recipe.cost
  final int xp;
  final FeedbackKey praise;  // khen trạm tốt nhất (allGood nếu 5★ và không có complaint)
  final FeedbackKey? complaint; // chê trạm yếu nhất, null nếu trạm yếu nhất >= 0.9
  final StationId weakest;
  int get net => payment + tip - cost;
}
```

### 2.4 Chấm điểm — `lib/core/scoring.dart` (**chốt: ở core**, test ở `test/core/scoring_test.dart`)
```dart
abstract final class Scoring {
  static const weights = {StationId.bake: 30, StationId.frost: 25, StationId.topping: 25,
                          StationId.mix: 10, StationId.box: 10, StationId.mould: 0};
  static StationScore mould(int wrongDrops);
  static StationScore mix(double turns, int target, double perfectBand);
  static StationScore bake(double release, double target, double perfectHalf, double okHalf);
  static StationScore frost(double coverage);
  static StationScore topping(Map<ToppingId, int> placed, List<ToppingRequest> required);
  static StationScore box(BoxType chosen, BoxType required);
  static int starsFor(double quality);
  static BakeResult evaluate({required Order order, required Customer customer,
    required BakeOutcome outcome, required BakeModifiers modifiers, required int decorTipBonusPct});
}
```
Công thức (clamp mọi kết quả vào 0..1):

| Trạm | Điểm | Issue khi điểm < 0.9 |
|---|---|---|
| mould | `max(0.3, 1 − 0.35·wrong)` | `wrongMould` (khi wrong > 0) |
| mix | `d = |turns/target − 1|`; `d ≤ band → 1`; ngược lại `1 − (d − band)·2` | `turns < target → underMixed`, ngược lại `overMixed` |
| bake | `d = |release − target|`; `d ≤ perfect → 1`; `d ≤ ok → 1 − 0.4·(d−perfect)/(ok−perfect)` (1→0.6); ngược lại `0.6 − (d − ok)·3` | `release < target → underBaked`, ngược lại `burnt` |
| frost | `c ≥ 0.9 → 1`; ngược lại `(c − 0.3)/0.6` | `patchy` |
| topping | `R = Σcount yêu cầu`; `correct = Σ min(placed_i, req_i)`; `wrong = Σ placed loại không yêu cầu + Σ max(0, placed_i − req_i)`; điểm `correct/R − 0.15·wrong` | `wrong > 0 → wrongTopping`, ngược lại `missingTopping` |
| box | đúng `1.0`, sai `0.3` | `wrongBox` |

Issue = `none` khi điểm ≥ 0.9 (trạm mould: `none` khi wrong = 0).

- **quality** = `Σ weight·score / 100 − 0.05·min(wrongMouldDrops, 2)`, clamp 0..1.
- **stars**: `q ≥ 0.90 → 5`, `≥ 0.75 → 4`, `≥ 0.60 → 3`, `≥ 0.40 → 2`, còn lại `1`.
- **payment** = `round(price × payMult[stars])`, payMult = {1: 0.5, 2: 0.7, 3: 0.85, 4: 1.0, 5: 1.1}.
- **tip** = 0 nếu stars < 3; ngược lại `round(price × tipRate[stars] × kindMult × (1 + min(decorPct, 30)/100))`, tipRate = {3: 0.10, 4: 0.20, 5: 0.35}, kindMult = {regular: 1.0, friend: 1.5, vip: 2.0}.
- **xp** = `round((15 + 5·stars) × (vip ? 1.5 : 1))`.
- **weakest** = trạm điểm thấp nhất; hoà thì ưu tiên theo thứ tự `bake, frost, topping, mix, box, mould`. **best** = trạm điểm cao nhất, hoà theo cùng thứ tự.
- **complaint** = khoá chê theo issue của trạm weakest (bảng dưới) nếu score(weakest) < 0.9, ngược lại `null`.
- **praise** = `allGood` nếu `complaint == null && stars == 5`; ngược lại khoá khen của trạm best.

| Trạm | Khen | Chê theo issue |
|---|---|---|
| mould | `mouldGood` | wrongMould→`mouldWrong` |
| mix | `mixGood` | underMixed→`mixUnder`, overMixed→`mixOver` |
| bake | `bakeGood` | underBaked→`bakeUnder`, burnt→`bakeBurnt` |
| frost | `frostGood` | patchy→`frostPatchy` |
| topping | `toppingGood` | missingTopping→`toppingMissing`, wrongTopping→`toppingWrong` |
| box | `boxGood` | wrongBox→`boxWrong` |

"Nướng hoàn hảo" (nhiệm vụ) = điểm trạm bake == 1.0.

### 2.5 Kinh tế — `lib/core/economy.dart`
```dart
abstract final class Economy {
  static const maxLevel = 15;
  static const startCoins = 100, startGems = 5;
  static const dayBonusXp = 30;
  static const maxRewardedPerDay = 8;       // theo ngày lịch thật
  static const interstitialMinDay = 4;      // ngày game đã hoàn thành
  static const interstitialGapDays = 2;
  static const decorTipCapPct = 30;
  static const masteryGemReward = 5;
  static const freeGemPerAd = 1;
  static const Map<int, double> payMult, tipRate;  // như 2.4
  static int xpToReachLevel(int level);     // bảng dưới; level 1 → 0
  static int levelForXp(int xp);            // 1..15
  static int customersPerDay(int level);    // 1–3: 4, 4–9: 5, 10+: 6
  static double vipChance(int level);       // <7: 0, 7–8: 0.20, 9+: 0.30
  static int levelUpCoins(int newLevel) => 50 * newLevel;
  static const levelUpGems = 2;
  static const List<OvenTier> ovenTiers;    // index 0 = cấp 1
  static const Map<ToolId, List<ToolTier>> toolTiers;
  static List<Unlock> unlocksAtLevel(int level);
}
class OvenTier { final int level, cost, requiredShopLevel; final double perfectHalfWidth, okHalfWidth; }
class ToolTier { final int level, cost, requiredShopLevel; final double value; }
```

**XP lên cấp** (tổng XP tích luỹ để đạt cấp):

| Cấp | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| XP tích luỹ | 0 | 80 | 200 | 360 | 560 | 800 | 1080 | 1400 | 1760 | 2160 | 2600 | 3080 | 3600 | 4160 | 4760 |

(XP cho cấp kế = 80 + 40·(cấp−1)). Cấp 15 là trần; XP vẫn cộng nhưng không lên. Mỗi lần lên cấp: `+50×cấp mới` xu, `+2` gem (cộng ngay trong `addXp`).

**10 món alpha** (`Catalog.recipes`, đúng thứ tự):

| RecipeId | Mở cấp | Giá | Cost | Khuôn | Bột | Kem (đầu = mặc định) | Topping cho phép | Vòng trộn | bakeTarget | Hộp |
|---|---|---|---|---|---|---|---|---|---|---|
| cupcakeVanilla | 1 | 30 | 8 | cupcakeLiner | vanilla | vanillaCream, strawberryCream | sprinkles, strawberry, cherry | 3 | 0.65 | small |
| cupcakeChocolate | 1 | 34 | 9 | cupcakeLiner | chocolate | chocolateGanache, vanillaCream | sprinkles, chocolateChips, cherry | 3 | 0.70 | small |
| muffinBlueberry | 2 | 38 | 10 | muffinCup | vanilla | vanillaCream | blueberry, sugarPearl, sprinkles | 3 | 0.72 | small |
| eggTart | 3 | 42 | 11 | tartShell | butter | custard | mintLeaf, strawberry | 4 | 0.62 | small |
| strawberryCake | 4 | 60 | 15 | roundPan | vanilla | strawberryCream, vanillaCream | strawberry, sprinkles, mintLeaf | 4 | 0.68 | cake |
| macaron | 5 | 50 | 13 | macaronMat | almond | strawberryCream, vanillaCream, matchaCream | sugarPearl, sprinkles | 5 | 0.55 | small |
| redVelvetCupcake | 6 | 46 | 12 | cupcakeLiner | redVelvet | creamCheese | cherry, chocolateChips, sprinkles | 4 | 0.70 | small |
| matchaCake | 8 | 70 | 18 | roundPan | matcha | matchaCream, vanillaCream | strawberry, mintLeaf, sugarPearl | 4 | 0.66 | cake |
| cheesecake | 10 | 80 | 20 | springformPan | cheese | creamCheese | blueberry, strawberry, cherry | 4 | 0.75 | cake |
| birthdayCake | 12 | 110 | 28 | tallPan | vanilla | vanillaCream, chocolateGanache, strawberryCream | candle, sprinkles, strawberry, cherry | 5 | 0.72 | cake |

Topping chỉ được gọi khi **đã mở**: `Catalog.toppingUnlockLevel` = sprinkles 1, strawberry 1, cherry 1, chocolateChips 1, blueberry 2, mintLeaf 3, sugarPearl 5, candle 12.

**Mở khoá theo cấp** (`Economy.unlocksAtLevel`, dùng cho màn tổng kết):

| Cấp | Mở |
|---|---|
| 1 | cupcakeVanilla, cupcakeChocolate; topping sprinkles/strawberry/cherry/chocolateChips |
| 2 | muffinBlueberry; blueberry; nâng cấp lò 2, kẹp 2; decor floorCheckered, plantFern |
| 3 | eggTart; mintLeaf; phới 2, túi kem 2; decor windowCurtains |
| 4 | strawberryCake; lò 3; 5 khách/ngày |
| 5 | macaron; sugarPearl; kẹp 3; decor counterCakeStand |
| 6 | redVelvetCupcake; phới 3; decor wallpaperFloral |
| 7 | khách VIP (20%); lò 4; túi kem 3; decor floorHerringbone |
| 8 | matchaCake; decor plantLemonTree |
| 9 | VIP 30% |
| 10 | cheesecake; lò 5; 6 khách/ngày |
| 11 | (chỉ thưởng lên cấp) |
| 12 | birthdayCake; candle |
| 13–15 | (chỉ thưởng lên cấp) |

**Lò nướng** (`ovenTiers`): bắt đầu cấp 1.

| Cấp lò | Giá (xu) | Cần tiệm cấp | perfect ± | ok ± |
|---|---|---|---|---|
| 1 | — | — | 0.05 | 0.15 |
| 2 | 300 | 2 | 0.06 | 0.16 |
| 3 | 800 | 4 | 0.07 | 0.17 |
| 4 | 1800 | 7 | 0.08 | 0.18 |
| 5 | 3500 | 10 | 0.10 | 0.20 |

**Dụng cụ** (`toolTiers`, cấp 1 có sẵn, `value` theo cấp):

| Dụng cụ | Ảnh hưởng | Cấp 1 | Cấp 2 (giá / cần cấp tiệm) | Cấp 3 |
|---|---|---|---|---|
| whisk | `mixPerfectBand` | 0.10 | 0.15 — 250 xu / 3 | 0.20 — 900 xu / 6 |
| pipingBag | `frostBrushRadius` | 22 | 27 — 250 xu / 3 | 32 — 900 xu / 7 |
| tongs | `toppingSnapRadius` | 0 | 16 — 200 xu / 2 | 32 — 700 xu / 5 |

**Trang trí** (`Catalog.decor`; mỗi ô 1 món đặt; `null` = mặc định "Cơ bản" miễn phí; % tip của các món đang đặt cộng dồn, trần 30%):

| DecorId | Ô | Giá | Mở cấp | +% tip |
|---|---|---|---|---|
| wallpaperStripes | wallpaper | 400 xu | 1 | 3 |
| wallpaperFloral | wallpaper | 1200 xu | 6 | 6 |
| floorCheckered | floor | 400 xu | 2 | 3 |
| floorHerringbone | floor | 1200 xu | 7 | 6 |
| counterFlowers | counter | 300 xu | 1 | 2 |
| counterCakeStand | counter | 1000 xu | 5 | 5 |
| windowCurtains | window | 350 xu | 3 | 2 |
| windowSeaView | window | 30 gem | 1 | 6 |
| plantFern | plant | 250 xu | 2 | 2 |
| plantLemonTree | plant | 25 gem | 8 | 5 |

```dart
class DecorItem { final DecorId id; final DecorSlot slot; final int coinPrice; final int gemPrice; /*0 nếu trả xu*/ final int unlockLevel; final int tipBonusPct; }
```

**Nhiệm vụ ngày** (`Catalog.quests`): mỗi ngày lịch chọn **3 loại khác nhau** từ 6 bằng `Random(yyyymmdd)`.

| QuestType | Mục tiêu | Thưởng |
|---|---|---|
| serveCustomers | 8 khách | 60 xu |
| earnStars | 15 sao | 60 xu |
| perfectBakes | 3 lần bake = 1.0 | 80 xu |
| fiveStarTreats | 2 bánh 5★ | 80 xu |
| earnCoins | 250 xu (tổng `net` dương của các đơn) | 2 gem |
| earnTips | 50 xu tip | 70 xu |

```dart
class QuestDef { final QuestType type; final int target; final int rewardCoins; final int rewardGems; }
class QuestProgress { final QuestType type; final int progress; final bool claimed; /* target lấy từ Catalog */ }
class LoginReward { final int day; /*1..7*/ final int coins; final int gems; }
```

**Quà đăng nhập 7 ngày**: N1 50 xu · N2 80 xu · N3 3 gem · N4 120 xu · N5 150 xu · N6 5 gem · N7 300 xu + 10 gem. Nhận 1 lần/ngày lịch. Nếu ngày nhận trước là **hôm qua** → ngày kế (7 → quay về 1); nếu bỏ lỡ ≥ 1 ngày hoặc chưa nhận lần nào → về N1.

**Sổ công thức – thành thạo** (`recipeMastery` 0..3): 1 = đã phục vụ ít nhất 1 lần; 2 = từng đạt ≥ 4★; 3 = từng đạt 5★. Lần đầu đạt 3 → `+5 gem`. Không bao giờ giảm.

**Ví dụ kiểm tra** (dùng trong test): cupcakeVanilla 4★ khách thường, decor 0% → payment 30, tip round(30·0.2) = 6, cost 8, net 28, xp 35. cheesecake 5★ VIP decor 28% → payment 88, tip round(80·0.35·2·1.28) = 72, xp round(40·1.5) = 60.

### 2.6 Quảng cáo / IAP / âm thanh (giả lập)
```dart
abstract class AdService {
  bool canShowRewarded();                                   // rewardedToday < 8
  Future<bool> showRewarded(BuildContext context, AdPlacement placement); // true = xem xong; TỰ ghi đếm vào GameState
  bool shouldShowInterstitial(int completedDay);
  Future<void> showInterstitial(BuildContext context, int completedDay); // tự ghi lastInterstitialDay
}
class FakeAdService implements AdService {
  FakeAdService(this.state, {this.duration = const Duration(seconds: 2)});
  // show*: showDialog không đóng được, tiêu đề adSimulatedTitle, nội dung adSimulatedBody,
  // đếm ngược adSimulatedClosing(seconds), xong tự đóng. Rewarded trả true.
}
```
- **Rewarded**: chỉ khi người chơi bấm; tối đa **8/ngày lịch** (gộp mọi placement). `doubleCoins`: 1 lần ở tổng kết, chỉ khi `net > 0`, thưởng = `+net` của ngày. `remake`: chỉ khi đơn có ≤ 2★, 1 lần/đơn. `freeGem`: ở cửa hàng, +1 gem.
- **Interstitial**: chỉ khi bấm "Tiếp tục" ở tổng kết ngày; `shouldShowInterstitial(d)` = `!removeAds && d >= 4 && (lastInterstitialDay == null || d − lastInterstitialDay >= 2)`. **Không bao giờ** giữa lúc làm bánh. Không có banner.
- **Việc trao thưởng do bên gọi làm** (ui): doubleCoins → `state.addCoins(net)`; freeGem → `state.addGems(1)`; remake → `dayController.markRemakeUsed()` rồi mở lại `BakeSessionView`.

```dart
class IapProduct { const IapProduct(this.id, this.displayPrice, {required this.consumable}); final IapProductId id; final String displayPrice; final bool consumable; }
abstract class IapService {
  List<IapProduct> get products;
  bool isOwned(IapProductId id);                 // non-consumable đã mua
  Future<bool> buy(IapProductId id);             // fake: chờ 600ms rồi trao qua GameState.grantIap, trả true
}
```
| IapProductId | Giá hiển thị (chuỗi cố định, không dịch) | Loại | Trao |
|---|---|---|---|
| starterPack | $1.99 | 1 lần | 1000 xu + 30 gem |
| pantryS | $0.99 | tiêu hao | 500 xu |
| pantryM | $2.99 | tiêu hao | 1800 xu |
| pantryL | $6.99 | tiêu hao | 5000 xu |
| decorSetSeaside | $2.99 | 1 lần | sở hữu windowSeaView, plantLemonTree, wallpaperFloral (bỏ qua cấp mở) |
| removeAds | $3.99 | 1 lần | `removeAds = true` (rewarded vẫn dùng được) |

Hộp thoại xác nhận mua (`storeConfirmTitle/Body`) do **ui** hiện trước khi gọi `buy`.

```dart
abstract class AudioService { void tap(); void success(); void fail(); }
class FakeAudioService implements AudioService { FakeAudioService(this.state); } // nếu soundOn: SystemSound.play(SystemSoundType.click); web không kêu cũng được
```

### 2.7 GameState — `lib/core/game_state.dart`
```dart
class GameState extends ChangeNotifier {
  GameState.newGame({DateTime Function()? clock});
  factory GameState.fromJson(Map<String, dynamic> json, {DateTime Function()? clock}); // thiếu trường → mặc định; sai → newGame
  Map<String, dynamic> toJson();
  static Future<GameState> load(SaveRepository repo, {DateTime Function()? clock});
  void attachAutosave(SaveRepository repo);   // mỗi notifyListeners → lưu debounce 300ms, bất đồng bộ
  Future<void> flush();                        // lưu ngay (gọi khi app paused)

  // Đọc
  int get coins; int get gems; int get xp; int get level;
  int get xpIntoLevel; int get xpForNextLevel;  // cấp 15: xpForNextLevel = 0
  int get dayNumber;                            // ngày game sắp chơi (bắt đầu 1)
  int get ovenLevel;                            // 1..5
  int toolLevel(ToolId id);                     // 1..3
  Set<DecorId> get ownedDecor; Map<DecorSlot, DecorId?> get equippedDecor;
  int get decorTipBonusPct;                     // đã áp trần 30
  int recipeMastery(RecipeId id);               // 0..3
  bool isRecipeUnlocked(RecipeId id); bool isToppingUnlocked(ToppingId id);
  List<RecipeId> get unlockedRecipes; List<ToppingId> get unlockedToppings;
  List<QuestProgress> get quests;               // 3 nhiệm vụ hôm nay
  LoginReward? get pendingLoginReward;          // null nếu hôm nay đã nhận
  int get loginStreakDay;                       // 0..7 ngày đã nhận gần nhất
  Set<StorySceneId> get seenScenes; bool get chapter1Complete;
  Set<StationId> get tutorialSeen;
  LanguagePref get language; bool get soundOn;
  bool get removeAds; int get rewardedToday; int? get lastInterstitialDay;
  Set<IapProductId> get ownedIap;
  int get totalServed;
  BakeModifiers get bakeModifiers;              // từ lò + dụng cụ

  // Ghi (mỗi hàm gọi notifyListeners)
  void addCoins(int amount); void addGems(int amount);
  bool trySpendCoins(int amount); bool trySpendGems(int amount);
  List<int> addXp(int amount);                  // trả các cấp vừa lên, đã cộng thưởng lên cấp
  PurchaseResult buyOvenUpgrade();
  PurchaseResult buyToolUpgrade(ToolId id);
  PurchaseResult buyDecor(DecorId id);
  void equipDecor(DecorSlot slot, DecorId? id); // null = mặc định
  void applyOrderResult(Order order, Customer customer, BakeResult result); // xu (net), xp, mastery, quest, thống kê
  void completeDay();                            // dayNumber++
  void refreshDaily();                           // đổi ngày lịch → nhiệm vụ mới, rewardedToday = 0
  QuestProgress? claimQuest(int index);          // null nếu chưa xong/đã nhận
  LoginReward? claimLogin();
  void markSceneSeen(StorySceneId id);           // finale → chapter1Complete = true
  void markTutorialSeen(StationId id);
  void setLanguage(LanguagePref pref); void setSound(bool on);
  void registerRewardedShown(); void registerInterstitialShown(int completedDay);
  void grantIap(IapProductId id);
  Future<void> resetAll();                       // xoá lưu + về newGame
}
```
Ngày lịch dùng `clock()` giờ máy, khoá chuỗi `yyyy-MM-dd`. `refreshDaily()` được gọi khi load và mỗi lần vào menu chính.

**JSON lưu** (khoá shared_preferences `sugarleaf_save_v1`, một chuỗi JSON):
```json
{"v":1,"coins":100,"gems":5,"xp":0,"day":1,"oven":1,
 "tools":{"whisk":1,"pipingBag":1,"tongs":1},
 "decorOwned":[],"decorEquipped":{"wallpaper":null,"floor":null,"counter":null,"window":null,"plant":null},
 "mastery":{"cupcakeVanilla":0},
 "questDate":"2026-10-27","quests":[{"type":"serveCustomers","progress":0,"claimed":false}],
 "loginStreak":0,"loginDate":null,
 "scenes":[],"tutorial":[],
 "lang":"system","sound":true,
 "removeAds":false,"adDate":"2026-10-27","rewardedToday":0,"lastInterstitialDay":null,
 "iap":[],"served":0}
```

```dart
abstract class SaveRepository { Future<String?> read(); Future<void> write(String data); Future<void> clear(); }
class PrefsSaveRepository implements SaveRepository { static const key = 'sugarleaf_save_v1'; }
class MemorySaveRepository implements SaveRepository { MemorySaveRepository([String? initial]); }
```

### 2.8 Sinh đơn + DayController — `order_generator.dart`, `day_controller.dart`
**OrderGenerator** (thuần, `Random` truyền vào):
- Số khách = `Economy.customersPerDay(level)`.
- Mỗi khách: VIP với xác suất `vipChance(level)`, còn lại regular. Từ khi đã xem cảnh đầu của một bạn quen, mỗi ngày tối đa 1 bạn quen ghé ngẫu nhiên với xác suất 20% (món: hoa → eggTart nếu mở, không thì cupcakeVanilla; linh → macaron nếu mở, không thì muffinBlueberry; kenji → món ngẫu nhiên).
- Món: chọn trong `unlockedRecipes`, trọng số món mở **mới nhất** = 3, các món khác = 1.
- Kem: ngẫu nhiên trong `recipe.frostings`.
- Topping: chỉ trong `recipe.toppings ∩ unlockedToppings`. Số loại: cấp < 5 → 1; cấp ≥ 5 → 1 hoặc 2 (50%). Số lượng mỗi loại: cấp < 7 → 1..3; ≥ 7 → 1..4. `candle` luôn 1..3.
- Hộp: `recipe.box`; VIP → `BoxType.gift`.
- Câu gọi: regular → generic1..6 ngẫu nhiên; vip → `vip`; friend → `hoa/linh/kenji`.

**Cảnh truyện**: `Catalog.storyScenes` theo thứ tự; cảnh chờ = cảnh **đầu tiên chưa xem** có `minLevel ≤ level && minDay ≤ dayNumber`; **tối đa 1 cảnh/ngày**, chiếu trước khách đầu tiên. Nếu cảnh có `featuredFriend` → khách đầu tiên của ngày là bạn đó với `featuredRecipe` (và `forcedToppings` nếu có).
```dart
class StoryLine { const StoryLine(this.speaker, this.text); final Speaker speaker; final String Function(AppLocalizations l) text; }
class StoryScene { final StorySceneId id; final int minLevel; final int minDay; final FriendId? featuredFriend; final RecipeId? featuredRecipe; final List<ToppingRequest>? forcedToppings; final List<StoryLine> lines; }
```

```dart
class DayController extends ChangeNotifier {
  DayController({required GameState state, Random? random}); // sinh khách + đơn ngay khi tạo
  int get dayNumber; int get levelAtStart;
  StoryScene? get pendingScene;            // null nếu không có
  void markSceneShown();                    // → state.markSceneSeen
  List<Customer> get customers; List<Order> get orders;
  int get index; int get total;
  Customer get currentCustomer; Order get currentOrder;
  bool get isFinished;                      // index == total
  BakeModifiers get modifiers;              // = state.bakeModifiers
  BakeResult evaluate(BakeOutcome outcome); // THUẦN, chưa đổi state
  bool canRemake(BakeResult r);             // r.stars <= 2 && chưa remake đơn này && ads còn lượt
  void markRemakeUsed();
  void commit(BakeResult r);                // state.applyOrderResult + lưu OrderRecord + index++
  DaySummary finishDay();                   // + dayBonusXp, state.completeDay(), trả tổng kết
}
class OrderRecord { final Order order; final Customer customer; final BakeResult result; }
class Unlock { final UnlockKind kind; final RecipeId? recipe; final ToppingId? topping; }
class DaySummary {
  final int dayNumber; final List<OrderRecord> records;
  final int revenue /*Σpayment*/, tips, costs, net, xpGained /*gồm dayBonusXp*/, dayBonusXp;
  final int levelBefore, levelAfter; final List<Unlock> unlocks; /* gộp unlocksAtLevel(levelBefore+1..levelAfter) */
  double get averageStars;
}
```
Rời ngày giữa chừng: xu/xp của đơn đã commit được giữ; ngày **không** tính hoàn thành (`dayNumber` không tăng).

### 2.9 Điều hướng và khởi động
```dart
abstract final class AppRoutes {
  static const menu = '/';
  static const day = '/day';
  static const summary = '/summary';   // arguments: DaySummaryArgs
  static const upgrades = '/upgrades';
  static const decor = '/decor';
  static const recipes = '/recipes';
  static const store = '/store';
  static const settings = '/settings';
}
class DaySummaryArgs { const DaySummaryArgs(this.summary); final DaySummary summary; }

class AppServices { AppServices({required this.state, required this.saves, required this.ads, required this.iap, required this.audio}); final GameState state; final SaveRepository saves; final AdService ads; final IapService iap; final AudioService audio; }
class AppScope extends InheritedNotifier<GameState> {
  AppScope({super.key, required this.services, required super.child});
  final AppServices services;
  static AppServices of(BuildContext context);   // lắng nghe GameState
  static AppServices read(BuildContext context); // không lắng nghe
}
```
`lib/app.dart`:
```dart
class SugarleafApp extends StatelessWidget {
  const SugarleafApp({super.key, required this.services, required this.onGenerateRoute, this.useGoogleFonts = true});
  // AppScope ở trên MaterialApp; locale theo state.language (system → null);
  // supportedLocales [en, vi]; fallback en; builder → RefFrame; theme AppTheme.build(locale hiện tại)
}
```
`lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized()` → khoá hướng → `GameState.load(PrefsSaveRepository())` → `attachAutosave` → tạo fake services → `runApp(SugarleafApp(...))`; lắng nghe lifecycle `paused` → `state.flush()`.
- **Đợt 1**: `onGenerateRoute` tạm trỏ màn chờ đơn giản trong `main.dart` (chữ `appTitle`).
- **Đợt 3 (dev-core, 1 dòng)**: đổi sang `onGenerateUiRoute` từ `package:sugarleaf_bakery/ui/ui_routes.dart`.

### 2.10 Tra chuỗi theo enum — `lib/core/l10n_lookup.dart`
```dart
extension AppL10nLookup on AppLocalizations {
  String recipeName(RecipeId id); String recipeDesc(RecipeId id);
  String mouldName(MouldType m); String batterName(BatterType b); String frostingName(FrostingId f);
  String toppingName(ToppingId t); String boxName(BoxType b);
  String stationName(StationId s); String feedbackText(FeedbackKey k);
  String orderLineText(OrderLineKind k, String item);
  String customerName(Customer c);   // regular → customerRegular, vip → customerVip, friend → charHoa/charLinh/charKenji
  String speakerName(Speaker s);     // narrator → ''
  String questText(QuestType t, int count);
  String toolName(ToolId t); String toolDesc(ToolId t);
  String decorName(DecorId? id);     // null → decorDefault
  String decorSlotName(DecorSlot s);
  String unlockText(Unlock u);
}
```

---

## 3. Ranh giới game ↔ ui

**Ui chỉ import một file của game: `package:sugarleaf_bakery/game/bake_session_view.dart`.**
```dart
class BakeSessionView extends StatefulWidget {
  const BakeSessionView({super.key, required this.order, required this.modifiers,
    required this.onComplete, this.tutorialFor = const {}, this.onTutorialShown});
  final Order order;
  final BakeModifiers modifiers;               // từ dayController.modifiers
  final ValueChanged<BakeOutcome> onComplete;  // gọi ĐÚNG 1 lần sau trạm hộp (+0.6s hoạt cảnh)
  final Set<StationId> tutorialFor;            // trạm cần hiện thẻ hướng dẫn = StationId.values − state.tutorialSeen
  final ValueChanged<StationId>? onTutorialShown; // ui gọi state.markTutorialSeen
}
```
- Chiếm toàn bộ 1280×720. Bên trong: `GameWidget<BakeryGame>` + overlay Flutter (thanh bước, vé đơn nhỏ, nút Xong, thẻ hướng dẫn) dùng `AppLocalizations.of(context)` và `AppL10nLookup`.
- Game **không** đọc/ghi GameState, không gọi ads, không chấm điểm (chỉ đo số thô → `BakeOutcome`).
- Làm lại (remake): ui dựng `BakeSessionView` mới (đổi `key`).
- Bố cục bake view: thanh trên cao 72 (6 chấm bước + tên trạm + `gameStepProgress`), vé đơn nhỏ góc phải trên (x 960–1260, y 84–284: hình món, kem, topping×số, hộp), vùng chơi x 0–940 y 72–720, nút `commonDone` góc phải dưới (x 1060–1240, y 620–690).

**Hành vi 6 trạm (dev-game, số liệu chốt):**
| Trạm | Thao tác | Kết thúc | Số đo |
|---|---|---|---|
| 1 mould | 4 khuôn (đúng + 3 ngẫu nhiên khác trong `MouldType`) ở cột phải, kéo thả lên khay giữa. Sai: lắc + `gameWrongMould`, khuôn về chỗ | tự chuyển khi thả đúng | `wrongMouldDrops` |
| 2 mix | Tô tròn tâm (470, 400). Kéo trong vành bán kính 60–220 px; cộng |Δgóc|/2π vào số vòng. Đồng hồ ngang 0..2×target, vùng xanh `[1−band, 1+band]×target` | nút Xong (bật khi ≥ 1 vòng) hoặc tự dừng ở 2×target | `mixTurns` |
| 3 bake | Nhấn giữ nút/lò: thanh 0→1 trong **3.0 s**; vẽ vùng vàng đậm (±perfect) và vàng nhạt (±ok) quanh `bakeTarget` | thả tay; giữ tới 1.0 → tự thả | `bakeRelease` |
| 4 frost | Đường gợi ý chấm = xoắn ốc 2.5 vòng trong elip mặt bánh, lấy mẫu **120 điểm**; nét kem bán kính `frostBrushRadius`; điểm được phủ nếu cách điểm nét bất kỳ ≤ bán kính | nút Xong (bật khi có nét) hoặc tự dừng khi ≥ 98% | `frostCoverage` |
| 5 topping | 4 khay: các loại được gọi + loại mồi từ `unlockedToppings` (nếu không đủ thì lấy bất kỳ) cho đủ 4. Kéo lên bánh: hợp lệ nếu điểm thả nằm trong elip mặt bánh nới thêm `toppingSnapRadius`; thả ngoài → bỏ. Chạm topping trên bánh để gỡ | nút Xong (bật khi ≥ 1 topping) | `toppingsPlaced` |
| 6 box | 3 hộp (small/cake/gift); kéo bánh vào một hộp | thả vào hộp | `boxChosen` |

Logic thuần đặt ở `lib/game/logic/` để test: `MixMeter` (cộng góc), `frostCoverage(List<Offset> guide, List<Offset> stroke, double r)`, `isOnCake(Offset p, Rect cakeTop, double snap)`, `spiralGuide(Rect, {int samples = 120, double turns = 2.5})`.

---

## 4. Màn hình (lib/ui) — bố cục 1280×720

`lib/ui/ui_routes.dart`: `Route<dynamic>? onGenerateUiRoute(RouteSettings settings)` (MaterialPageRoute/fade cho 8 route ở 2.9).

| Route / Màn | File | Nội dung |
|---|---|---|
| `/` MainMenu | `ui/menu/main_menu_screen.dart` | Nền `ShopArt` với decor đang đặt. Trái: Mai (`CustomerArt.paintSpeaker(mai)`), tiêu đề `appTitle` + `menuTagline`. Thanh trên (cao 64): `menuShopLevel`, thanh XP (`menuXpProgress`/`menuXpMax`), xu, gem, nút cài đặt. Phải: nút lớn `menuPlay` + `menuDayLabel`; lưới nút `menuRecipeBook`, `menuUpgrades`, `menuDecor`, `menuStore`; nút tròn `menuQuests` (chấm đỏ nếu có nhiệm vụ xong chưa nhận), `menuLoginGift`. Vào màn → `refreshDaily()`; nếu `pendingLoginReward != null` và chưa tự hiện trong phiên → tự mở hộp quà. |
| (dialog) Quà đăng nhập | `ui/menu/login_gift_dialog.dart` | 7 ô (`loginDay`), ô hôm nay sáng, đã nhận có dấu tick; nút `commonClaim` → `claimLogin()`; sau khi nhận `loginComeBack`. |
| (dialog) Nhiệm vụ | `ui/menu/quests_dialog.dart` | 3 dòng: `questText`, thanh tiến trình `questProgress`, thưởng, nút `commonClaim`/`commonClaimed`; chân `questsResetHint`; hết thì `questsAllDone`. |
| `/day` Ngày kinh doanh | `ui/day/day_screen.dart` (+ `order_ticket.dart`, `result_card.dart`, `story_overlay.dart`) | Tạo `DayController`. Pha: (1) cảnh truyện nếu có (`StoryOverlay`: khung thoại dưới, tên người nói, `storyTapToContinue`, `storySkip`, tiêu đề `storyChapter1Title` ở cảnh prologue); (2) intro ngày `dayStartTitle` + `dayCustomersToday`; (3) khách bước vào quầy (x 180–560), bong bóng câu gọi (`orderLineText`) và vé đơn (x 640–1220: hình món `CakeArt`, `dayOrderFrosting`, `dayOrderToppings` icon×số, `dayOrderBox`, nhãn `customerVipBadge`/`customerFriendBadge`), nút `dayStartBaking`; (4) `BakeSessionView`; (5) `ResultCard` 720×440 giữa màn: khách (mood theo sao), 1–5 sao, `feedbackText(praise)`, `feedbackText(complaint)` màu đỏ + `feedbackNeedsWork(stationName)`, `resultPaid`, `resultTip`, `resultXp`; nút `dayNextCustomer` (→ `commit`) và, nếu `canRemake`, `dayRemakeWithAd` (→ rewarded → `markRemakeUsed` → khách nói `dayRemakeLine` → bake lại). Hết khách → `finishDay()` → `pushReplacementNamed(summary)`. HUD trên: `dayCustomerProgress`, xu, nút thoát (dialog `dayExitConfirmTitle/Body`). |
| `/summary` Tổng kết | `ui/summary/day_summary_screen.dart` | `summaryTitle`; trái: danh sách đơn (hình món + sao); phải: `summaryCustomers`, `summaryAvgStars`, `summaryRevenue`, `summaryTips`, `summaryCosts`, `summaryNet`, `summaryXp` + `summaryDayBonusXp`; nếu lên cấp: băng `summaryLevelUp` + `summaryNewUnlocks` (`unlockText`). Nút `summaryDouble` (nếu net > 0 và còn lượt; xong → `summaryDoubled`), `commonContinue` → kiểm interstitial → về menu. |
| `/upgrades` | `ui/upgrades/upgrades_screen.dart` | 4 thẻ ngang: lò (`upgradeOven`, `upgradeOvenDesc`, `upgradeOvenPerfectZone`), whisk, pipingBag, tongs; mỗi thẻ `upgradeLevelOf`, giá, nút `upgradeBuy`/`upgradeMaxed`/`commonUnlockAtLevel`; thiếu xu → snackbar `commonNotEnoughCoins`; thành công `upgradeDone`. |
| `/decor` | `ui/decor/decor_screen.dart` | Trái (760×600): xem trước `ShopArt` theo lựa chọn; phải: 5 tab ô (`decorSlot*`), danh sách món (mặc định `decorDefault` + 2 món): `decorTipBonus`, giá xu/gem, nút `commonBuy` / `decorEquip` / `decorEquipped` / `commonUnlockAtLevel`; dưới: `decorTotalBonus`. |
| `/recipes` | `ui/recipes/recipe_book_screen.dart` | Trái: lưới 10 thẻ (5×2), món khoá hiện bóng + `recipesMissingPage`. Phải: chi tiết món chọn: tên, `recipeDesc`, `recipesPrice`, `recipesIngredients` (khuôn, bột, kem, topping), `recipesMastery` 3 sao + `recipesMasteryHint`. |
| `/store` | `ui/store/store_screen.dart` | Băng `storeSimulatedNotice` luôn hiện. 6 thẻ IAP (tên, mô tả, `displayPrice`, `commonBuy` / `storeOwned`) → dialog `storeConfirmTitle/Body` → `buy` → `storePurchaseSuccess`. Thẻ `storeFreeGem` (rewarded; hết lượt → `adsLimitReached`). |
| `/settings` | `ui/settings/settings_screen.dart` | `settingsLanguage` (3 lựa chọn: `settingsLanguageSystem/En/Vi`), `settingsSound` (`settingsOn/Off`), `settingsResetData` → dialog `settingsResetConfirmTitle/Body` → `resetAll()` → `settingsResetDone` → về menu; chân: `settingsVersion` (đọc chuỗi cố định `0.1.0-alpha`), `settingsAlphaNote`. |

Widget dùng chung ở `lib/ui/common/` (SugarButton, Panel, CurrencyBar, StarRow, dialog chuẩn). Mọi nút chạm ≥ 48×48. Dùng `AppScope.of(context)` để đọc state; không giữ state trùng lặp.

---

## 5. Khoá l10n (toàn bộ — localizer viết đủ vào `app_en.arb` + `app_vi.arb`)

Quy ước: camelCase; `app_en.arb` có `"@@locale": "en"` và metadata `@key` với `placeholders` (kiểu ghi ở cột cuối); `app_vi.arb` có `"@@locale": "vi"`, không cần metadata. Không dịch tên riêng (Sugarleaf, Mai, Linh, Kenji). Kiểu: **int**, **String**. Cột "Plural" = dùng ICU plural ở EN.

### 5.1 Chung
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| appTitle | Sugarleaf Bakery | Sugarleaf Bakery | |
| commonOk | OK | OK | |
| commonCancel | Cancel | Huỷ | |
| commonConfirm | Confirm | Đồng ý | |
| commonClose | Close | Đóng | |
| commonBack | Back | Quay lại | |
| commonContinue | Continue | Tiếp tục | |
| commonDone | Done | Xong | |
| commonBuy | Buy | Mua | |
| commonClaim | Claim | Nhận | |
| commonClaimed | Claimed | Đã nhận | |
| commonLocked | Locked | Chưa mở | |
| commonMax | Max | Tối đa | |
| commonUnlockAtLevel | Unlocks at level {level} | Mở ở cấp {level} | level:int |
| commonLevelShort | Lv. {level} | Cấp {level} | level:int |
| commonCoins | {count, plural, =1{1 coin} other{{count} coins}} | {count} xu | count:int, plural |
| commonGems | {count, plural, =1{1 gem} other{{count} gems}} | {count} kim cương | count:int, plural |
| commonNotEnoughCoins | Not enough coins | Không đủ xu | |
| commonNotEnoughGems | Not enough gems | Không đủ kim cương | |
| commonWatchAd | Watch ad | Xem quảng cáo | |
| rotateDevicePrompt | Please turn your device sideways | Hãy xoay ngang thiết bị nhé | |
| levelUpTitle | Level up! | Lên cấp! | |

### 5.2 Menu chính
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| menuTagline | A cozy little bakery by the sea | Tiệm bánh nhỏ xinh bên bờ biển | |
| menuPlay | Open the bakery | Mở cửa tiệm | |
| menuDayLabel | Day {day} | Ngày {day} | day:int |
| menuRecipeBook | Recipe book | Sổ công thức | |
| menuUpgrades | Upgrades | Nâng cấp | |
| menuDecor | Decor | Trang trí | |
| menuStore | Store | Cửa hàng | |
| menuSettings | Settings | Cài đặt | |
| menuQuests | Daily quests | Nhiệm vụ ngày | |
| menuLoginGift | Daily gift | Quà hằng ngày | |
| menuShopLevel | Bakery level {level} | Tiệm cấp {level} | level:int |
| menuXpProgress | {current}/{target} XP | {current}/{target} XP | current:int, target:int |
| menuXpMax | Max level | Cấp tối đa | |

### 5.3 Ngày kinh doanh, kết quả
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| dayStartTitle | Day {day} | Ngày {day} | day:int |
| dayCustomersToday | {count} customers are coming today | Hôm nay có {count} khách ghé | count:int |
| dayCustomerProgress | Customer {current}/{total} | Khách {current}/{total} | current:int, total:int |
| dayOrderTitle | Order | Đơn hàng | |
| dayOrderFrosting | Frosting | Kem phủ | |
| dayOrderToppings | Toppings | Topping | |
| dayOrderBox | Box | Hộp | |
| dayStartBaking | Start baking | Bắt đầu làm bánh | |
| dayNextCustomer | Next customer | Khách tiếp theo | |
| dayRemakeWithAd | Remake (watch ad) | Làm lại (xem QC) | |
| dayRemakeLine | No rush, I'll wait for a fresh one! | Không sao, mình đợi cái mới nhé! | |
| dayExitConfirmTitle | Leave for now? | Tạm rời tiệm? | |
| dayExitConfirmBody | Coins earned so far are kept, but today won't count as completed. | Xu đã kiếm vẫn được giữ, nhưng hôm nay sẽ không tính là hoàn thành. | |
| customerRegular | Customer | Khách | |
| customerVip | VIP guest | Khách VIP | |
| customerVipBadge | VIP | VIP | |
| customerFriendBadge | Regular | Khách quen | |
| resultPaid | Paid {amount} | Trả {amount} | amount:int |
| resultTip | Tip {amount} | Tip {amount} | amount:int |
| resultXp | +{amount} XP | +{amount} XP | amount:int |
| feedbackNeedsWork | Needs work: {station} | Cần cải thiện: {station} | station:String |

### 5.4 Câu gọi món
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| orderLine1 | Hi! One {item}, please. | Chào bạn! Cho mình một {item} nhé. | item:String |
| orderLine2 | I've been craving {item} all day! | Cả ngày nay mình thèm {item} lắm! | item:String |
| orderLine3 | Could you make me one {item}? | Bạn làm giúp mình một {item} được không? | item:String |
| orderLine4 | One {item} to go, thank you! | Một {item} mang đi, cảm ơn nha! | item:String |
| orderLine5 | Something sweet today... {item}! | Hôm nay muốn ăn gì ngọt ngọt... {item} nhé! | item:String |
| orderLine6 | My friend says your {item} is lovely. | Bạn mình khen {item} ở đây ngon lắm. | item:String |
| orderLineVip | One {item} in your finest gift box, please. | Cho tôi một {item}, gói hộp quà đẹp nhất nhé. | item:String |
| orderLineHoa | The usual for this old man: one {item}. | Như mọi khi nhé cháu: một {item}. | item:String |
| orderLineLinh | Eee, {item}! Make it extra cute, please! | Ui, {item}! Làm thật xinh giúp em nha! | item:String |
| orderLineKenji | Today feels like a day for {item}. | Hôm nay là một ngày hợp với {item}. | item:String |

### 5.5 Phản hồi theo trạm
| Khoá | EN | VI |
|---|---|---|
| fbAllGood | Perfect! Just like I imagined! | Hoàn hảo! Đúng như mình tưởng tượng! |
| fbMouldGood | Such a cute shape! | Hình dáng xinh quá! |
| fbMixGood | So soft and fluffy! | Mềm xốp quá đi! |
| fbBakeGood | Baked to golden perfection! | Nướng vàng ươm hoàn hảo! |
| fbFrostGood | The frosting is so smooth! | Lớp kem mịn màng quá! |
| fbToppingGood | The toppings are just right! | Topping chuẩn y như mình gọi! |
| fbBoxGood | And it's packed so nicely! | Lại còn gói đẹp nữa! |
| fbMouldWrong | Hmm, the shape isn't what I expected. | Ơ, hình dáng không giống mình nghĩ. |
| fbMixUnder | The texture is a bit lumpy. | Bánh hơi lợn cợn, chưa mịn. |
| fbMixOver | It's a little dense and tough. | Bánh hơi chặt và dai. |
| fbBakeUnder | It's still a bit gooey inside! | Bên trong vẫn còn hơi sống! |
| fbBakeBurnt | Oops, it's a little burnt! | Ôi, bánh hơi cháy rồi! |
| fbFrostPatchy | The frosting looks patchy. | Lớp kem phủ bị lem nhem. |
| fbToppingMissing | I think some toppings are missing. | Hình như thiếu topping rồi. |
| fbToppingWrong | Those aren't the toppings I asked for. | Đây không phải topping mình gọi. |
| fbBoxWrong | Hmm, that's not the right box. | Ơ, hộp này không đúng rồi. |

### 5.6 Trạm làm bánh (game)
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| stationMould | Mould | Khuôn | |
| stationMix | Mixing | Trộn bột | |
| stationBake | Baking | Nướng | |
| stationFrost | Frosting | Phủ kem | |
| stationTopping | Toppings | Trang trí | |
| stationBox | Boxing | Đóng hộp | |
| hintMould | Drag the right mould onto the tray | Kéo đúng khuôn vào khay | |
| hintMix | Swirl around the bowl and stop in the green zone | Xoay vòng quanh tô, dừng khi vào vùng xanh | |
| hintBake | Hold to bake, release in the golden zone | Nhấn giữ để nướng, thả tay ở vùng vàng | |
| hintFrost | Trace the dotted line to frost the cake | Vẽ theo nét chấm để phủ kem | |
| hintTopping | Drag the toppings onto the cake | Kéo topping lên bánh | |
| hintBox | Drag the treat into the right box | Kéo bánh vào đúng hộp | |
| gameStepProgress | Step {current}/{total} | Bước {current}/{total} | current:int, total:int |
| gameHold | Hold | Giữ | |
| gameTapToRemove | Tap a topping to remove it | Chạm vào topping để gỡ ra | |
| gameWrongMould | Not this one! | Không phải khuôn này! | |
| gameTutorialGotIt | Got it! | Đã hiểu! | |

### 5.7 Khuôn, bột, kem, topping, hộp
| Khoá | EN | VI |
|---|---|---|
| mouldCupcakeLiner | Cupcake liner | Cốc giấy cupcake |
| mouldMuffinCup | Muffin cup | Cốc muffin |
| mouldTartShell | Tart shell | Đế tart |
| mouldRoundPan | Round pan | Khuôn tròn |
| mouldMacaronMat | Macaron mat | Thảm macaron |
| mouldSpringformPan | Springform pan | Khuôn đáy rời |
| mouldTallPan | Tall layer pan | Khuôn tầng cao |
| batterVanilla | Vanilla batter | Bột vani |
| batterChocolate | Chocolate batter | Bột chocolate |
| batterRedVelvet | Red velvet batter | Bột red velvet |
| batterMatcha | Matcha batter | Bột matcha |
| batterButter | Butter pastry | Bột bơ làm vỏ |
| batterAlmond | Almond meringue | Bột hạnh nhân |
| batterCheese | Cheesecake batter | Bột phô mai |
| frostingVanillaCream | Vanilla cream | Kem vani |
| frostingChocolateGanache | Chocolate ganache | Ganache chocolate |
| frostingStrawberryCream | Strawberry cream | Kem dâu |
| frostingMatchaCream | Matcha cream | Kem matcha |
| frostingCreamCheese | Cream cheese | Kem phô mai |
| frostingCustard | Egg custard | Nhân trứng sữa |
| toppingSprinkles | Sprinkles | Cốm màu |
| toppingStrawberry | Strawberry | Dâu tây |
| toppingCherry | Cherry | Anh đào |
| toppingChocolateChips | Chocolate chips | Chocolate chip |
| toppingBlueberry | Blueberry | Việt quất |
| toppingMintLeaf | Mint leaf | Lá bạc hà |
| toppingSugarPearl | Sugar pearls | Ngọc đường |
| toppingCandle | Candle | Nến |
| boxSmall | Small box | Hộp nhỏ |
| boxCake | Cake box | Hộp bánh kem |
| boxGift | Gift box | Hộp quà |

### 5.8 Món (tên + mô tả)
| Khoá | EN | VI |
|---|---|---|
| recipeCupcakeVanilla | Vanilla cupcake | Cupcake vani |
| recipeCupcakeVanillaDesc | Fluffy vanilla sponge with a cloud of cream. | Cốt vani xốp mềm, phủ một đám mây kem. |
| recipeCupcakeChocolate | Chocolate cupcake | Cupcake chocolate |
| recipeCupcakeChocolateDesc | Rich cocoa crumb and glossy ganache. | Cốt cacao đậm đà, ganache bóng mượt. |
| recipeMuffinBlueberry | Blueberry muffin | Muffin việt quất |
| recipeMuffinBlueberryDesc | A golden muffin bursting with berries. | Muffin vàng ươm, mọng việt quất. |
| recipeEggTart | Egg tart | Tart trứng |
| recipeEggTartDesc | Flaky shell, silky custard. Grandma's favorite. | Vỏ giòn tan, nhân trứng mịn. Món bà thích nhất. |
| recipeStrawberryCake | Strawberry cake | Bánh kem dâu |
| recipeStrawberryCakeDesc | Soft layers with fresh strawberry cream. | Bánh mềm cùng lớp kem dâu tươi. |
| recipeMacaron | Macaron | Macaron |
| recipeMacaronDesc | Crisp almond shells with a sweet filling. | Vỏ hạnh nhân giòn, nhân ngọt dịu. |
| recipeRedVelvetCupcake | Red velvet cupcake | Cupcake red velvet |
| recipeRedVelvetCupcakeDesc | Velvety red crumb with tangy cream cheese. | Cốt đỏ mịn như nhung, kem phô mai chua nhẹ. |
| recipeMatchaCake | Matcha cake | Bánh kem matcha |
| recipeMatchaCakeDesc | A gentle green tea cake, not too sweet. | Bánh trà xanh dịu nhẹ, ngọt vừa phải. |
| recipeCheesecake | Cheesecake | Bánh phô mai |
| recipeCheesecakeDesc | Creamy, rich, and baked low and slow. | Béo mịn, đậm vị, nướng chậm lửa nhỏ. |
| recipeBirthdayCake | Birthday layer cake | Bánh sinh nhật tầng |
| recipeBirthdayCakeDesc | Tall, festive, and made for wishes. | Cao tầng, rực rỡ, dành cho những điều ước. |

### 5.9 Nhân vật và truyện chương 1
| Khoá | EN | VI |
|---|---|---|
| charMai | Mai | Mai |
| charHoa | Mr. Hoa | Ông Hòa |
| charLinh | Linh | Linh |
| charKenji | Kenji | Kenji |
| storyChapter1Title | Chapter 1: The Seaside Bakery | Chương 1: Tiệm bánh bên bờ biển |
| storyTapToContinue | Tap to continue | Chạm để tiếp tục |
| storySkip | Skip | Bỏ qua |

Cảnh (người nói ở cột 2; `Catalog.storyScenes` dùng đúng thứ tự dòng):

| Khoá | Người nói | EN | VI |
|---|---|---|---|
| storyPrologue1 | narrator | A sleepy seaside town. A little bakery with a faded sign: Sugarleaf. | Một thị trấn ven biển yên bình. Một tiệm bánh nhỏ với tấm biển đã bạc màu: Sugarleaf. |
| storyPrologue2 | mai | Grandma, I'm home... I'll take care of your bakery now. | Bà ơi, cháu về rồi... Từ nay cháu sẽ chăm lo tiệm bánh của bà. |
| storyPrologue3 | mai | Her recipe book! But so many pages are missing... | Sổ công thức của bà! Nhưng thiếu nhiều trang quá... |
| storyPrologue4 | mai | Let's start with something simple. Cupcakes! | Bắt đầu từ món đơn giản thôi. Cupcake nào! |
| storyHoa1Line1 | hoa | The lights are on at Sugarleaf again. You must be little Mai. | Tiệm Sugarleaf lại sáng đèn rồi. Cháu là bé Mai phải không? |
| storyHoa1Line2 | mai | Yes! Did you know my grandma? | Dạ! Ông quen bà cháu ạ? |
| storyHoa1Line3 | hoa | Every Sunday for forty years. Her egg tarts... I still miss them. | Chủ nhật nào ông cũng ghé, suốt bốn mươi năm. Tart trứng của bà... ông vẫn nhớ mãi. |
| storyHoa1Line4 | mai | Then I'll learn to make them for you. I promise! | Vậy cháu sẽ học làm cho ông. Cháu hứa đấy ạ! |
| storyLinh1Line1 | linh | Hi! I'm Linh. I study at the art school up the hill. | Chào chị! Em là Linh, học trường mỹ thuật trên đồi. |
| storyLinh1Line2 | linh | I draw every pastry I eat. Your shop is SO cute! | Em vẽ lại mọi chiếc bánh em ăn. Tiệm chị dễ thương xỉu luôn! |
| storyLinh1Line3 | mai | Then I'd better make them pretty for you! | Vậy chị phải làm bánh thật xinh cho em vẽ rồi! |
| storyHoa2Line1 | mai | Mr. Hoa! I found the egg tart page today. | Ông Hòa ơi! Hôm nay cháu tìm được trang tart trứng rồi. |
| storyHoa2Line2 | hoa | Then today is a good day. Let's see if your hands remember her. | Vậy hôm nay là ngày đẹp trời. Để xem tay cháu có nhớ bà không nào. |
| storyHoa2Line3 | mai | I'll do my best! | Cháu sẽ cố hết sức! |
| storyKenji1Line1 | kenji | Hello. I'm Kenji. I travel and photograph small towns. | Xin chào. Tôi là Kenji. Tôi đi khắp nơi chụp ảnh những thị trấn nhỏ. |
| storyKenji1Line2 | kenji | I'm not sure what I want. Something that feels like a sunny morning? | Tôi không chắc mình muốn gì. Món gì đó giống một buổi sáng đầy nắng? |
| storyKenji1Line3 | mai | A sunny morning... Strawberry cake, I think! | Buổi sáng đầy nắng... Chắc là bánh kem dâu! |
| storyLinh2Line1 | linh | Mai, can you make macarons? They're my favorite thing to draw! | Chị Mai ơi, chị làm macaron được không? Em mê vẽ macaron nhất! |
| storyLinh2Line2 | mai | They're tricky... but let's try together. | Món này khó lắm... nhưng mình cùng thử nhé. |
| storyLinh2Line3 | linh | Yay! I'll sketch while you bake! | Yeah! Chị làm bánh, em ngồi ký họa! |
| storyKenji2Line1 | kenji | Tomorrow I'll climb the lighthouse at dawn. I need some courage. | Sáng mai tôi sẽ leo ngọn hải đăng lúc bình minh. Tôi cần chút can đảm. |
| storyKenji2Line2 | mai | Courage tastes bold and a little sweet. Red velvet! | Can đảm thì đậm đà và ngọt nhẹ. Red velvet nhé! |
| storyKenji2Line3 | kenji | You read moods like recipes. | Cô đọc cảm xúc như đọc công thức vậy. |
| storyHoa3Line1 | hoa | I brought something. She gave me this page years ago, for safekeeping. | Ông mang cái này đến. Năm xưa bà nhờ ông giữ hộ trang này. |
| storyHoa3Line2 | mai | Grandma's handwriting... Thank you, Mr. Hoa. | Chữ của bà... Cháu cảm ơn ông. |
| storyHoa3Line3 | hoa | It belongs in this kitchen. Just like you. | Nó thuộc về căn bếp này. Cũng như cháu vậy. |
| storyLinh3Line1 | linh | Look! My drawing of your shop won a prize at school! | Chị xem! Tranh em vẽ tiệm chị được giải ở trường đó! |
| storyLinh3Line2 | mai | It's beautiful, Linh! Can I hang it by the window? | Đẹp quá Linh ơi! Chị treo cạnh cửa sổ nhé? |
| storyLinh3Line3 | linh | Only if we celebrate with a matcha cake! | Với điều kiện mình ăn mừng bằng bánh kem matcha! |
| storyKenji3Line1 | kenji | My photos of this town will be shown in a gallery in Tokyo. | Ảnh tôi chụp thị trấn này sẽ được trưng bày ở Tokyo. |
| storyKenji3Line2 | kenji | I want to remember it with something calm and rich. | Tôi muốn nhớ về nơi này bằng một món dịu dàng mà đậm vị. |
| storyKenji3Line3 | mai | Then cheesecake, with blueberries like the sea. | Vậy là cheesecake, thêm việt quất xanh như biển. |
| storyFinaleLine1 | mai | Mr. Hoa, Linh, Kenji... this bakery feels alive again. | Ông Hòa, Linh, Kenji... tiệm bánh lại rộn ràng như xưa. |
| storyFinaleLine2 | mai | Grandma's book still has empty pages. I'll fill them, one by one. | Sổ của bà vẫn còn những trang trống. Cháu sẽ viết tiếp, từng trang một. |
| storyFinaleLine3 | narrator | Chapter 1 complete. More stories are coming soon! | Hoàn thành chương 1. Câu chuyện sẽ còn tiếp tục! |

**Bảng cảnh** (`Catalog.storyScenes`, đúng thứ tự):

| Scene | minLevel | minDay | featuredFriend | featuredRecipe | Dòng |
|---|---|---|---|---|---|
| prologue | 1 | 1 | — | — | storyPrologue1–4 |
| hoa1 | 1 | 2 | hoa | cupcakeVanilla | storyHoa1Line1–4 |
| linh1 | 2 | 1 | linh | muffinBlueberry | storyLinh1Line1–3 |
| hoa2 | 3 | 1 | hoa | eggTart | storyHoa2Line1–3 |
| kenji1 | 4 | 1 | kenji | strawberryCake | storyKenji1Line1–3 |
| linh2 | 5 | 1 | linh | macaron | storyLinh2Line1–3 |
| kenji2 | 6 | 1 | kenji | redVelvetCupcake | storyKenji2Line1–3 |
| hoa3 | 7 | 1 | hoa | eggTart | storyHoa3Line1–3 |
| linh3 | 8 | 1 | linh | matchaCake | storyLinh3Line1–3 |
| kenji3 | 10 | 1 | kenji | cheesecake (forcedToppings: blueberry×3) | storyKenji3Line1–3 |
| finale | 10 | 1 | — | — | storyFinaleLine1–3 |

### 5.10 Tổng kết ngày, mở khoá
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| summaryTitle | Day {day} complete! | Hoàn thành ngày {day}! | day:int |
| summaryCustomers | Customers served | Khách đã phục vụ | |
| summaryAvgStars | Average rating | Đánh giá trung bình | |
| summaryRevenue | Sales | Doanh thu | |
| summaryTips | Tips | Tiền tip | |
| summaryCosts | Ingredients | Nguyên liệu | |
| summaryNet | Total earned | Tổng thu | |
| summaryXp | XP gained | XP nhận được | |
| summaryDayBonusXp | Day bonus +{xp} XP | Thưởng cuối ngày +{xp} XP | xp:int |
| summaryDouble | Double coins (watch ad) | Nhân đôi xu (xem QC) | |
| summaryDoubled | Coins doubled! | Đã nhân đôi xu! | |
| summaryLevelUp | Level up! Bakery level {level} | Lên cấp! Tiệm cấp {level} | level:int |
| summaryNewUnlocks | New unlocks | Mở khoá mới | |
| unlockRecipe | New recipe: {name} | Công thức mới: {name} | name:String |
| unlockTopping | New topping: {name} | Topping mới: {name} | name:String |
| unlockVipGuests | VIP guests start visiting! | Khách VIP bắt đầu ghé tiệm! | |
| unlockUpgrades | New upgrades available | Có nâng cấp mới | |
| unlockDecor | New decorations available | Có đồ trang trí mới | |
| unlockMoreCustomers | More customers each day | Mỗi ngày có thêm khách | |

### 5.11 Nâng cấp
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| upgradesTitle | Upgrades | Nâng cấp | |
| upgradeOven | Oven | Lò nướng | |
| upgradeOvenDesc | A wider golden zone when baking | Vùng vàng khi nướng rộng hơn | |
| upgradeOvenPerfectZone | Perfect zone ±{percent}% | Vùng hoàn hảo ±{percent}% | percent:int |
| upgradeWhisk | Whisk | Phới lồng | |
| upgradeWhiskDesc | A bigger green zone when mixing | Vùng xanh khi trộn rộng hơn | |
| upgradePipingBag | Piping bag | Túi bắt kem | |
| upgradePipingBagDesc | A thicker frosting stroke | Nét kem to hơn | |
| upgradeTongs | Pastry tongs | Kẹp gắp bánh | |
| upgradeTongsDesc | Toppings land on the cake more easily | Topping dễ đặt lên bánh hơn | |
| upgradeLevelOf | Level {current}/{max} | Cấp {current}/{max} | current:int, max:int |
| upgradeBuy | Upgrade | Nâng cấp | |
| upgradeMaxed | Fully upgraded | Đã nâng tối đa | |
| upgradeDone | Upgraded! | Đã nâng cấp! | |

### 5.12 Trang trí
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| decorTitle | Decorate the bakery | Trang trí tiệm | |
| decorSlotWallpaper | Wallpaper | Giấy dán tường | |
| decorSlotFloor | Floor | Sàn nhà | |
| decorSlotCounter | Counter | Quầy | |
| decorSlotWindow | Window | Cửa sổ | |
| decorSlotPlant | Plants | Cây xanh | |
| decorDefault | Basic | Cơ bản | |
| decorWallpaperStripes | Cream stripes | Sọc kem | |
| decorWallpaperFloral | Floral wallpaper | Giấy hoa nhí | |
| decorFloorCheckered | Checkered tiles | Gạch caro | |
| decorFloorHerringbone | Herringbone wood | Sàn gỗ xương cá | |
| decorCounterFlowers | Flower vase | Bình hoa | |
| decorCounterCakeStand | Tiered cake stand | Kệ bánh nhiều tầng | |
| decorWindowCurtains | Lace curtains | Rèm ren | |
| decorWindowSeaView | Sea view window | Cửa sổ hướng biển | |
| decorPlantFern | Fern | Cây dương xỉ | |
| decorPlantLemonTree | Lemon tree | Cây chanh | |
| decorTipBonus | +{percent}% tips | +{percent}% tip | percent:int |
| decorTotalBonus | Total tip bonus: +{percent}% | Tổng thưởng tip: +{percent}% | percent:int |
| decorEquip | Place | Đặt | |
| decorEquipped | Placed | Đang dùng | |

### 5.13 Sổ công thức
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| recipesTitle | Recipe book | Sổ công thức | |
| recipesPrice | Price: {amount} | Giá: {amount} | amount:int |
| recipesIngredients | Ingredients | Nguyên liệu | |
| recipesMastery | Mastery | Thành thạo | |
| recipesMasteryHint | Serve it once, get 4★, then 5★ to master it | Phục vụ 1 lần, đạt 4★ rồi 5★ để thành thạo | |
| recipesMasteryReward | Mastered! +{gems} gems | Thành thạo! +{gems} kim cương | gems:int |
| recipesMissingPage | Missing page. Unlocks at level {level} | Trang còn thiếu. Mở ở cấp {level} | level:int |

### 5.14 Nhiệm vụ ngày, quà đăng nhập
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| questsTitle | Daily quests | Nhiệm vụ ngày | |
| questServeCustomers | Serve {count} customers | Phục vụ {count} khách | count:int |
| questEarnStars | Earn {count} stars | Đạt {count} sao | count:int |
| questPerfectBakes | Get {count} perfect bakes | Nướng hoàn hảo {count} lần | count:int |
| questFiveStarTreats | Serve {count} five-star treats | Phục vụ {count} bánh 5 sao | count:int |
| questEarnCoins | Earn {count} coins | Kiếm {count} xu | count:int |
| questEarnTips | Collect {count} coins in tips | Nhận {count} xu tiền tip | count:int |
| questProgress | {current}/{target} | {current}/{target} | current:int, target:int |
| questsResetHint | New quests every day | Mỗi ngày có nhiệm vụ mới | |
| questsAllDone | All done for today! | Hôm nay xong hết rồi! | |
| loginTitle | Daily gift | Quà hằng ngày | |
| loginDay | Day {day} | Ngày {day} | day:int |
| loginComeBack | Come back tomorrow for more! | Mai nhớ quay lại nhận tiếp nhé! | |

### 5.15 Cửa hàng, quảng cáo giả lập
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| storeTitle | Store | Cửa hàng | |
| storeSimulatedNotice | Test store: purchases are simulated and no money is charged. | Cửa hàng thử nghiệm: giao dịch là giả lập, không trừ tiền thật. | |
| storeStarterPack | Starter pack | Gói khởi đầu | |
| storeStarterPackDesc | {coins} coins + {gems} gems | {coins} xu + {gems} kim cương | coins:int, gems:int |
| storePantryS | Pantry pack S | Gói nguyên liệu S | |
| storePantryM | Pantry pack M | Gói nguyên liệu M | |
| storePantryL | Pantry pack L | Gói nguyên liệu L | |
| storePantryDesc | {coins} coins for ingredients | {coins} xu mua nguyên liệu | coins:int |
| storeDecorSet | Seaside decor set | Bộ trang trí biển xanh | |
| storeDecorSetDesc | 3 special decorations | 3 món trang trí đặc biệt | |
| storeRemoveAds | Remove ads | Xoá quảng cáo | |
| storeRemoveAdsDesc | No more ads between days. Reward ads stay optional. | Không còn quảng cáo giữa các ngày. Quảng cáo nhận thưởng vẫn tuỳ bạn. | |
| storeFreeGem | Watch an ad for {gems} gem | Xem quảng cáo nhận {gems} kim cương | gems:int |
| storeOwned | Owned | Đã sở hữu | |
| storeConfirmTitle | Simulated purchase | Mua giả lập | |
| storeConfirmBody | Buy {item} for {price}? No real money will be charged. | Mua {item} giá {price}? Không trừ tiền thật. | item:String, price:String |
| storePurchaseSuccess | Thank you! Your items have been added. | Cảm ơn bạn! Đã nhận vật phẩm. | |
| adsLimitReached | No more ad rewards today | Hôm nay đã hết lượt nhận thưởng | |
| adSimulatedTitle | Ad (simulated) | Quảng cáo (giả lập) | |
| adSimulatedBody | A real ad will play here in the release version. | Bản phát hành sẽ hiện quảng cáo thật ở đây. | |
| adSimulatedClosing | Closing in {seconds}s | Đóng sau {seconds} giây | seconds:int |
| adRewardGranted | Reward received! | Đã nhận thưởng! | |

### 5.16 Cài đặt
| Khoá | EN | VI | Placeholder |
|---|---|---|---|
| settingsTitle | Settings | Cài đặt | |
| settingsLanguage | Language | Ngôn ngữ | |
| settingsLanguageSystem | Device language | Theo máy | |
| settingsLanguageEn | English | English | |
| settingsLanguageVi | Tiếng Việt | Tiếng Việt | |
| settingsSound | Sound | Âm thanh | |
| settingsOn | On | Bật | |
| settingsOff | Off | Tắt | |
| settingsResetData | Reset game data | Xoá dữ liệu game | |
| settingsResetConfirmTitle | Reset all progress? | Xoá toàn bộ tiến trình? | |
| settingsResetConfirmBody | Coins, levels, decorations and story progress will be erased. This can't be undone. | Xu, cấp, đồ trang trí và tiến trình truyện sẽ bị xoá. Không thể hoàn tác. | |
| settingsResetDone | Game data reset | Đã xoá dữ liệu game | |
| settingsVersion | Version {version} | Phiên bản {version} | version:String |
| settingsAlphaNote | Alpha build. Thanks for playing! | Bản alpha. Cảm ơn bạn đã chơi thử! | |

**Tổng: 302 khoá** (đếm theo bảng 5.1–5.16). Ai cần khoá mới ngoài danh sách → ghi trong báo cáo, không tự thêm vào .arb.

---

## 6. Nội dung store (aso)
- Thư mục: `store/en-US/` và `store/vi/`, mỗi thư mục: `title.txt` (≤ 30), `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000); `store/release_notes/0.1.0-alpha_en-US.txt`, `..._vi.txt` (≤ 500).
- Chỉ nêu tính năng có trong alpha (mục 0). Không nhắc app/thương hiệu khác, không "Ghibli", không "#1/tốt nhất/miễn phí" trong tên. Nêu rõ đây là bản alpha thử nghiệm trong ghi chú phát hành. Đối tượng 13+.

---

## 7. Giao việc và tiêu chí xong

Lệnh chung: `flutter analyze` **0 error, 0 warning** (info chấp nhận), `flutter test` qua hết, `flutter build web --release` thành công. Không ai commit.

| Đợt | Người | File/khu vực | Việc | Tiêu chí xong | Phụ thuộc |
|---|---|---|---|---|---|
| 1 | dev-core | `pubspec.yaml`, `l10n.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/core/**`, `android/`, `web/`, `test/core/**` | Mục 1, 2 (toàn bộ), màn chờ tạm | analyze/test/build web qua; test ≥: `scoring_test` (từng công thức, ngưỡng sao, khen/chê, 2 ví dụ ở 2.5), `economy_test` (bảng XP, levelForXp, mua nâng cấp ok/notEnough/locked/maxed, trần decor 30%), `save_test` (round-trip JSON, thiếu trường → mặc định, JSON hỏng → newGame, MemorySaveRepository), `day_controller_test` (số khách theo cấp, đơn hợp lệ: món/topping đã mở, VIP → gift, commit cộng xu/xp, finishDay tăng ngày), `daily_test` (đổi ngày → nhiệm vụ mới + rewardedToday 0; streak đăng nhập nối/đứt; rewarded tối đa 8; luật interstitial) | Cần `app_en.arb`/`app_vi.arb` của localizer để `l10n_lookup.dart` biên dịch — viết phần này cuối, chạy kiểm tra sau khi localizer xong |
| 1 | localizer | `lib/l10n/app_en.arb`, `lib/l10n/app_vi.arb` | Viết đủ 302 khoá mục 5 (metadata placeholder trong en) | Đủ khoá ở cả 2 file, placeholder khớp, `flutter gen-l10n` không lỗi (trưởng phòng chạy) | Không |
| 1 | aso | `store/**` | Mục 6 | Đủ file 2 ngôn ngữ, bảng độ dài trong giới hạn | Không |
| 2 | dev-game | `lib/game/**`, `test/game/**` | `BakeSessionView` + `BakeryGame` + 6 trạm (mục 3), logic thuần ở `lib/game/logic/` | analyze/test/build qua; chơi được bằng chuột và chạm; `onComplete` đúng 1 lần; test ≥: `MixMeter` (1 vòng = 1.0, bỏ qua ngoài vành), `frostCoverage` (phủ hết = 1, rỗng = 0), `isOnCake` (snap), `spiralGuide` (đúng 120 điểm); 1 widget test dựng `BakeSessionView` không lỗi | dev-core + localizer đợt 1 |
| 2 | dev-ui | `lib/ui/**`, `test/ui/**` | `ui_routes.dart` + 8 màn + dialog (mục 4) | analyze/test/build qua; test ≥: menu dựng được ở en và vi (`MemorySaveRepository`, `useGoogleFonts: false`), đổi ngôn ngữ ở cài đặt đổi chữ, tổng kết hiện đúng số từ `DaySummary` mẫu, cửa hàng mua giả lập cộng xu | dev-core + localizer đợt 1; import `BakeSessionView` theo chữ ký mục 3 (chạy kiểm tra cuối sau khi dev-game xong) |
| 3 | dev-core | `lib/main.dart` | Nối `onGenerateRoute: onGenerateUiRoute` | build web chạy, mở được menu | dev-game, dev-ui |
| 3 | /quality-gate | toàn dự án | reviewer → tester ∥ design ∥ qa | ĐẠT | Đợt 3 |

Hai người không bao giờ sửa cùng file. Thư mục `lib/l10n/gen/` là file sinh, không ai sửa tay.

---

## 8. Quyết định tạm (PM tự chọn cho alpha, chủ dự án có thể đổi sau)
1. **10 món alpha** như bảng 2.5 (bỏ croissant, pain au chocolat, éclair, madeleine, tart trái cây, pie táo, món mùa).
2. **Mọi món đi đủ 6 trạm**; tart trứng "phủ kem" = rót nhân trứng sữa, macaron = bơm nhân.
3. **Trạm khuôn trọng số 0** (giữ trọng số GDD 30/25/25/10/10); thay vào đó mỗi lần thả sai khuôn trừ 0.05 chất lượng (tối đa 0.10) và có câu chê riêng.
4. **Chấm điểm đặt ở core** (`Scoring`), game chỉ đo số thô → dễ test, ui/game cùng dùng.
5. **Không có kho nguyên liệu**; chi phí nguyên liệu trừ thẳng mỗi đơn. Gói "nguyên liệu S/M/L" của IAP giả lập trao xu. Bỏ "nguyên liệu hiếm" của rewarded.
6. **Không đồng hồ kiên nhẫn** (cozy). Khách không bỏ đi.
7. **Khách thường không có tên riêng** ("Khách"/"Khách VIP"); chỉ bạn quen có tên. Khách VIP chung chung, bà Rosa và mèo Mochi để sau alpha.
8. **Gem** dùng để mua 2 món trang trí (windowSeaView, plantLemonTree); nguồn: quà đăng nhập, lên cấp, thành thạo, nhiệm vụ, quảng cáo, IAP.
9. **Âm thanh**: chưa có file âm thanh; nút bật/tắt chỉ điều khiển tiếng click hệ thống.
10. **Font**: google_fonts tải lúc chạy; tiếng Việt dùng Nunito cho tiêu đề.
11. **Co giãn**: letterbox giữ đúng 1280×720 (không kéo giãn), phần thừa màu kem.
12. **Ngày lịch** (nhiệm vụ, quà, giới hạn quảng cáo) theo giờ máy; chỉnh giờ máy để gian lận chấp nhận ở alpha.
13. **Interstitial** đếm theo **ngày game** đã hoàn thành (từ ngày 4, cách ≥ 2 ngày game); rewarded đếm theo **ngày lịch**.
14. Phiên bản hiển thị `0.1.0-alpha` (chuỗi cố định trong ui; số phiên bản pubspec giữ mặc định của flutter create — đổi là việc của `release`).
15. Rời ngày giữa chừng: giữ xu đã kiếm, ngày không tính hoàn thành.

## 9. Rủi ro
- **Thứ tự phụ thuộc**: core cần .arb để biên dịch `l10n_lookup.dart`; ui cần `BakeSessionView` của game → kiểm tra analyze cuối cùng chỉ có nghĩa sau khi cả đợt xong. Giảm thiểu: chữ ký đã chốt ở đây, dev-game tạo `bake_session_view.dart` đúng chữ ký ngay từ đầu.
- **google_fonts trên web/Android không mạng**: rơi về font mặc định; test phải dùng `useGoogleFonts: false`.
- **Flame + kéo thả trên web**: cần thử cả chuột và cảm ứng; `RefFrame` dùng `FittedBox` nên toạ độ con trỏ phải theo khung 1280×720 (Flame `GameWidget` nằm trong khung nên tự đúng — tester cần kiểm).
- **Mở bản web**: không mở `build/web/index.html` bằng file:// được; cần máy chủ tĩnh (trưởng phòng lo).
- **Khối lượng lớn cho dev-core đợt 1** (core + art). Nếu trễ, dev-game/dev-ui có thể bắt đầu theo chữ ký nhưng chỉ kiểm tra cuối được khi core xong.
- Fredoka có thể thiếu glyph tiếng Việt (đã né bằng quyết định tạm 10).
