# Thành phố V3, Giai đoạn 2: save v3, mở thẳng vào phố, gỡ 50 màn, mở khoá theo cấp

Đặc tả do kiến trúc sư viết, trưởng phòng duyệt ngày 04/11/2026. Ngày làm GĐ1 có bản sao lưu ở `D:\flutter_app\cupcake_v3_backup_gd1_*`.
Mọi người chỉ code theo **chữ ký đã chốt ở §6**; đừng tự đổi API của khu vực người khác.

## 0. Quyết định (mặc định)
- **Save:** save v3 ghi vào khoá mới `sugarleaf_save_v3`. Save v2 (khoá `sugarleaf_save_v1`) **chỉ đọc**, không bao giờ ghi hay xoá.
- **Mang từ v2 sang:** chỉ ngôn ngữ, âm thanh, `introSeen`, `removeAds`, danh sách `iap`. **Không** mang xu và **không** quy đổi tiến trình 50 màn sang XP.
- **`main.dart`:** lần đầu chạy intro 2D rồi vào phố; các lần sau vào thẳng phố. Bỏ intro ngắn.
- **Cài đặt:** là bảng 2D nằm trong `Town3dView`, mở bằng nút bánh răng. GĐ2 không push route đè lên cảnh 3D.
- **Khung 2D:** bỏ `RefFrame`/`SLScope` bọc toàn app; chỉ route 2D tự bọc.
- **Entry:** xoá `main_town3d.dart`, thay bằng `main.dart?save=memory`. Giữ `main_shop3d.dart` và `main_3d_probe.dart`.
- **Gỡ:** GameState, `core/level`, `core/unlock`, `core/monetization`, `core/sim`, `core/staff`, `game/level`, các màn 2D, IAP/cửa hàng, 3 file config JSON.
- **Giữ:** chuỗi làm bánh, Scoring, Catalog, OrderGenerator, Economy, l10n_lookup, order_ticket, result_card, quảng cáo thưởng giả lập, audio giả lập.
- **Ngày:** là ngày lịch của máy, dạng `yyyy-mm-dd`.
- **Xoá dữ liệu:** giữ lại ngôn ngữ, âm thanh và đồ đã mua (`removeAds`, `iap`), vì đồ người chơi đã trả tiền không được mất (trưởng phòng chốt 04/11).

## 1. Hiện trạng
### 1.1 Save v2
- Kho: `PrefsSaveRepository` (`lib/core/save_repository.dart:17-63`), dùng API `SharedPreferences` **kiểu cũ**.
- Các khoá: `sugarleaf_save_v1` (bên trong là JSON v2), `sugarleaf_save_v1_corrupt` (+`_<ms>`), `sugarleaf_save_v1_pre_v2`.
- Schema `v: 2`, xem `game_state.dart:337-402`: coins, gems, xp, day, …, lang, sound, introSeen, removeAds, iap, progress, shop, staff, …
- Cách nạp: `GameState.load` (`:258-308`); đọc từng trường bằng `_readJson` (`:414-550`); autosave ở `:915-946`.

### 1.2 Phụ thuộc
- `main.dart:35-100`: nạp GameState và 3 config, rồi dựng `AppServices(state, saves, FakeAd/Iap/Audio, levels, unlocks, monetization)`, gắn lifecycle, gọi `runApp(SugarleafApp(... onGenerateUiRoute, initialFor(introSeen)))`.
- `app.dart`:
  - `AppScope` là `InheritedNotifier<GameState>`.
  - `_LanguageBuilder` nghe `state.language` (`:105`).
  - `builder` bọc `Theme + SLScope + RefFrame` cho **mọi** route (`:82`).
  - Có `onGenerateInitialRoutes` riêng cho intro (`:77`, `:92-100`).
  - `showSLSimulatedAd` ở `:150`.
- Sau khi gỡ, 4 file được giữ còn trỏ vào phần bị xoá:
  - `core/services/ad_service.dart:8`
  - `core/services/audio_service.dart:4`
  - `ui/intro/intro_screen.dart:6-9` (xong intro → L1, `:175-188`)
  - `ui/sugarleaf/sl_pressable.dart:5,91-92` (`AppScope` → `services.audio.tap()`)

### 1.4 Phần dùng lại
- **6 trạm Flame** giữ nguyên vẹn: `game/{bake_session_view,bakery_game}.dart`, `stations/`, `logic/`, `components/`. Chúng chỉ import core/art, core/models, catalog, economy, l10n_lookup, ref_frame, ui/common/art, ui/sugarleaf.
- Giữ cả `ui/day/order_ticket.dart`, `result_card.dart`, `weather.dart`, `Catalog.loginRewards`, `QuestType`, intro 2D (`intro_screen.dart` + `intro_art.dart`).
- `Recipe.unlockLevel` hiện là số màn của v2; sang GĐ3 sẽ ánh xạ lại theo cấp Mai.

## 2. Save v3
### 2.1 Mô hình
```json
{ "v": 3, "createdAt": 0, "savedAt": 0, "migratedFrom": 2,
  "wallet": {"coins": 1500, "xp": 0},
  "look": {"hair": "ponytail", "hairColor": "chestnut"},
  "day": {"key": "2026-11-04", "n": 1, "eaten": {"fish_soup": 1}, "fullBuff": false},
  "visited": ["n3","n4"],
  "settings": {"lang": "system", "sound": true},
  "flags": {"introSeen": true, "levelSeen": 1},
  "ads": {"removeAds": false, "date": "2026-11-04", "rewarded": 0},
  "iap": ["removeAds"],
  "branches": {}, "staff": [], "district": "bakery_street", "quests": {}, "login": {} }
```
- 5 khoá cuối để dành cho GĐ4–5. GĐ2 giữ nguyên giá trị, không dùng.
- Mọi khoá lạ ở cấp trên cùng cũng được giữ nguyên khi ghi lại (lưu trong `extra`).
- Cấp **không lưu**, luôn tính bằng `PlayerLevel.levelForXp(xp)`.
- Ghi theo thứ tự ổn định: sắp xếp `visited` và các khoá của `eaten`.
- Sang ngày mới: xoá bộ đếm `eaten`, tăng `n`, `fullBuff` giữ nguyên. Kiểm khi nạp và khi app quay lại (onShow).

Giao diện Dart do dev-core viết, người khác chỉ dùng:
```dart
// lib/core/city/city_settings.dart
class CitySettings extends ChangeNotifier { CitySettings({LanguagePref language = LanguagePref.system, bool sound = true});
  LanguagePref get language; bool get sound; void setLanguage(LanguagePref v); void setSound(bool v); } // không đổi thì không notify
// lib/core/city/city_wallet.dart (mở rộng, giữ API cũ)
CityWallet({coins = 1500, xp = 0, look, Set<String> visited = const {}, Map<String,int> eatenToday = const {}, bool fullBuff = false, String dayKey = '', int dayNumber = 1});
Set<String> get visited; Map<String,int> get eatenToday; String get dayKey; int get dayNumber;
bool rollDay(String todayKey);  // dayKey rỗng → chỉ đặt; khác → newDay() + n++
void restore({...});            // reset tại chỗ (không thay object); coins kẹp [0, 2^53−1], xp [0, 2^31−1]
// lib/core/city/city_game.dart
class CityGame extends ChangeNotifier implements AdLedger {
  CityGame({CityWallet? wallet, CitySettings? settings, DateTime Function()? clock});
  final CityWallet wallet; final CitySettings settings;
  bool get introSeen; void markIntroSeen(); int get levelSeen; void markLevelSeen(int level);  // kẹp 1..30
  bool get removeAds; Set<String> get iapOwned; int get rewardedToday; void registerRewardedShown();
  bool refreshDay([DateTime? now]); Map<String,Object?> get extra; CitySave toSave(); void restore(CitySave s); }
// lib/core/save/city_save.dart: CitySave (bất biến, ==), CitySave.fresh(now), toJson(now), CitySave.decode(Object? json) → (save, bad, newer)
// lib/core/save/v2_import.dart: CitySave importV2(Map<String,dynamic> v2, {required DateTime now})
// lib/core/save/city_save_repository.dart
abstract class CitySaveRepository { Future<String?> readV3(); Future<void> writeV3(String d); Future<String?> readV2(); Future<void> backupCorrupt(String d); }
// Prefs: v3Key 'sugarleaf_save_v3', corruptKey 'sugarleaf_save_v3_corrupt' (+_<ms>), v2Key 'sugarleaf_save_v1'. KHÔNG có hàm ghi/xoá v2.
// Memory: v3, v2, backups, writeCount, failRead/failWrite, Completer? writeGate (cho test)
// lib/core/save/city_save_store.dart
enum CitySaveSource { fresh, v3, importedV2, recovered }
class CitySaveStore { static const autosaveDelay = Duration(milliseconds: 300);
  static Future<CitySaveStore> load(CitySaveRepository repo, {DateTime Function()? clock});
  CityGame get game; CitySaveSource get source; bool get locked; List<String> get badFields;
  void attachAutosave(); Future<void> flush(); Future<void> resetAll(); void dispose(); }
// lib/core/city/city_day.dart: String cityDateKey(DateTime d)
// lib/core/debug_params.dart: CityDebugParams (§3)
```

### 2.2 Phiên bản và autosave
- `v = 3`. Thêm trường thì không tăng `v`.
- `v > 3`: đọc được nhưng khoá ghi cả phiên (`locked`) và hiện toast `citySaveReadOnly`.
- Không đọc được bộ nhớ: dùng mặc định và đặt `locked`.
- Autosave nghe `Listenable.merge([wallet, settings, game])`, debounce 300 ms.
  - Mỗi lúc chỉ một lần ghi; có thay đổi trong lúc đang ghi thì ghi thêm một lần sau đó.
  - Ghi lỗi thì chỉ log.
- `flush()`: huỷ timer, chờ lần ghi đang chạy, rồi ghi nếu còn dữ liệu chưa lưu.
- `AppLifecycleListener(onHide/onPause: flush, onShow: refreshDay)`.
- **Bắt buộc dùng `SharedPreferences` kiểu cũ**. `SharedPreferencesAsync` trên Android không thấy dữ liệu v2.

### 2.3 Nạp và migration
1. Đọc v3. Lỗi bộ nhớ → dùng mặc định và `locked`.
2. v3 là Map → decode từng mục; trường hỏng về mặc định; có trường hỏng thì `backupCorrupt(raw)` đúng 1 lần.
3. v3 hỏng (không phải JSON hay object, hoặc rỗng) → `backupCorrupt`, chuyển sang bước 4 với `source = recovered`.
4. Không có v3 → `readV2()`. Nếu là Map thì `importV2`:
   - lấy `lang`, `sound`, `introSeen` (thiếu thì `false`), `removeAds`, `iap` (các chuỗi khác rỗng);
   - phần còn lại để mặc định; `migratedFrom: 2`;
   - ghi v3 ngay, trước `runApp`. Ghi lỗi thì vẫn cho chơi, lần sau nhập lại;
   - v2 hỏng thì bỏ qua, không động vào.
5. Không có gì → `CitySave.fresh`, chưa ghi cho tới lần thay đổi đầu tiên.

Kẹp giá trị:
- `coins`: âm → 0; ±∞ → 2^53−1; NaN → mặc định.
- `xp` ≥ 0.
- `levelSeen` trong 1..30; thiếu thì lấy cấp hiện tại.
- `day.key` sai dạng → `''`.
- `eaten` chỉ nhận số từ 0 đến 999.
- `visited`/`eaten` giữ cả id lạ.
- `district` lạ → `bakery_street`.

### 2.4 Xoá dữ liệu
`store.resetAll()` làm lần lượt:
- huỷ timer;
- `game.restore(fresh)` **tại chỗ**, giữ ngôn ngữ, âm thanh và đồ đã mua (`removeAds`, `iap`, gồm cả id lạ);
- `introSeen=false`, `levelSeen=1`;
- mở khoá ghi;
- ghi bản v3 mặc định. **Không xoá khoá**, vì xoá thì lần sau sẽ nhập lại v2.

Sau đó `Town3dView` đưa Mai về trước cửa tiệm của bà và áp look mặc định, không tạo lại viewer.

### 2.5 Test (`test/core/save/*`, `test/core/city/*`)
1. Người mới: đủ trường mặc định, chưa ghi.
2. Khứ hồi mọi trường; `CitySave ==`.
3. Thiếu trường → mặc định, các trường khác giữ.
4. Từng trường sai kiểu → chỉ trường đó về mặc định; backup đúng 1 lần.
5. JSON hỏng / không phải object / rỗng → backup, rồi nhập v2 hoặc dùng mặc định.
6. `v: 4` → `writeCount == 0` sau khi thay đổi và flush; `resetAll` mở khoá.
7. `readV3` ném lỗi → `locked`.
8. Kẹp NaN, ∞, số âm; số gần 2^53 khứ hồi đúng.
9. Khoá lạ, `branches`, `district` còn nguyên.
10. Nhập v2 (lang vi, sound false, introSeen true, removeAds, coins 99999) → v3 đúng, 1500 xu, `migratedFrom 2`, ghi 1 lần, **chuỗi v2 y nguyên**.
11. Save v1 nằm trong khoá v2 → chỉ nhận settings; v2 hỏng → bỏ qua.
12. Có cả v3 lẫn v2 → dùng v3.
13. Ghi v3 lỗi lúc migration → vẫn chơi được, v2 còn, lần sau nhập lại.
14. Debounce: nhiều thay đổi trong 300 ms chỉ ghi 1 lần; flush ghi ngay; sau dispose không ghi.
15. Ghi tuần tự với repo chậm → bản cuối là trạng thái mới nhất.
16. Đổi ngày: lần ăn thứ 2 được 25%, lưu rồi nạp cùng ngày vẫn 25%, sang ngày sau 100%; `n` tăng; `fullBuff` giữ.
17. Reset giữ settings và đồ đã mua (`removeAds`, `iap`), ghi bản mặc định, lần nạp sau không nhập v2.
18. `xp: 800` → cấp 5.
19. Prefs (`setMockInitialValues`): đúng khoá v3; khoá v2 không đổi.
20. Quảng cáo thưởng: tối đa 12 lần/ngày, đặt lại khi sang ngày.
21. `CityDebugParams`:
    - `level=5` → xp 800 và bật memory;
    - `level=99` kẹp về 30;
    - `coins=abc` → null;
    - `spawn=3,-4.6`, `lang=vi`, `intro=0`.

## 3. Khởi động mới
```
main(): ensureInitialized → font offline + license → khoá ngang + immersive
  debug = CityDebugParams.fromPlatform()          // web: Uri.base.queryParameters; native: query của defaultRouteName
  repo  = debug.memorySave ? MemoryCitySaveRepository() : PrefsCitySaveRepository()
  store = await CitySaveStore.load(repo); debug.applyTo(store.game)   // coins/xp/level chỉ khi memory
  store.game.refreshDay(); store.attachAutosave()
  services = AppServices(game, store, FakeAdService(game, presenter: showSLSimulatedAd), FakeAudioService(game.settings), debug)
  AppLifecycleListener(onHide/onPause: flush, onShow: refreshDay)
  runApp(SugarleafApp(services, onGenerateRoute: cityRouteFactory(town: (_) => Town3dPage(game:…, store:…, debug:…)),
         initialRoute: (debug.intro ?? !game.introSeen) ? AppRoutes.intro : AppRoutes.town, forcedLocale: debug.locale))
```

**Route**
- `/` → `Town3dPage`, không bọc RefFrame/SLScope.
- `/intro` → `IntroScreen` trong `SLScope(RefFrame(page))`; xong thì `markIntroSeen()` và `pushReplacementNamed('/')`.
- `/debug/ui-gallery` chỉ có khi `kDebugMode`. Tên route lạ → `/`.
- `onGenerateInitialRoutes` luôn bỏ qua tên route do nền tảng gửi.
- Bỏ phần nạp sẵn ảnh 2D.

**Cài đặt**
- Nút bánh răng `CityMenuButton` (≥ 48 dp) đặt bên trái minimap.
  - Chỉ hiện ngoài phố.
  - Ẩn khi đang chuyển cảnh.
- Bấm vào mở `_Sheet.settings`:
  - joystick bị chặn; Esc hoặc chạm ra ngoài thì đóng (trừ lúc đang xác nhận xoá);
  - nội dung: Ngôn ngữ (theo máy / English / Tiếng Việt), Âm thanh, Xoá dữ liệu (xác nhận 2 bước), phiên bản và ghi chú alpha.

**Tham số URL** (web dùng query; Android dùng `--es route '/?…'`)
- `save=memory`. Đặt `coins=`, `xp=` hoặc `level=` thì tự bật `save=memory`.
- `intro=0|1`.
- `lang=vi|en`: chỉ áp trong phiên, không lưu.
- `spawn=x,z`, `debug=1|0` (mặc định = `kDebugMode`), `log=1`, `mochi=1`.
- Đồ họa: `quality`, `scale`, `fps`, `shadows`, `smap`, `post`, `aa`, `blob`, `soft`, `ibl`, `tm`, `maxpx`.
- Ánh sáng: `sun`, `amb`, `fill`, `sky`, `ambi`.
- `tex=`.

Build web vẫn cần COOP/COEP.

## 4. Danh sách gỡ
**XOÁ**
- **dev-core**
  - Mã: `lib/core/{level/**, sim/**, unlock/**, monetization/**, staff/**, game_state.dart, save_repository.dart, config_reader.dart, services/iap_service.dart, models/mochi.dart}`, `lib/main_town3d.dart`.
  - Asset: `assets/config/**`, `assets/art/level/**`, `assets/art/map/**`, cùng các dòng tương ứng trong pubspec.
  - Công cụ: `tool/simulate.dart`, `tool/screens/render_screens_test.dart`, `integration_test/levels_1_10_test.dart`.
  - Test: `test/core/{booster_balance, booster_session, daily, level_balance, level_config, level_progress, level_session, monetization_config, monetization, phase8b, progression_sim, progression_sim_test, qa_helpers, qa_level_session, qa_levels_1_10_headless, qa_monetization, qa_offline, qa_save, qa_unlock_staff, save_migration, save, simulate, staff, tutorial, unlock}`.
- **dev-game**
  - Mã: `lib/game/level/**`.
  - Test: `test/game/{level_boosters, level_case_render, level_characters, level_counter_queue, level_play_perf, level_play, level_shop_setup, level_staff, level_tutorial, qa_level_edge, qa_perf_leak}`.
- **dev-ui**
  - Mã: `lib/ui/{level, map, upgrades, decor, recipes, season, store, menu, settings}/**`, `ui/day/{story_overlay, mochi_visit, rain_overlay}.dart`, `ui/intro/short_intro_screen.dart`, `ui/common/{navigation, currency_bar, staff_portrait, sugar_screen}.dart`, `ui/ui_routes.dart`.
  - Test: `test/ui/{level_map, level_screens, menu_settings, navigation_guard, phase6, phase8b, qa_ads, qa_edge_cases, qa_helpers, qa_screens_matrix, qa_smoke, recipe_book_grid, staff_offline, step3_a_handdrawn, step3_c_screens, store, tutorial_level, ui_test_helpers, upgrades_unlocks, wide_layout}`.

**SỬA để vẫn biên dịch**
- **dev-core**
  - Viết lại `core/app_scope.dart`, `core/routes.dart`, `app.dart`, `main.dart`.
  - `ad_service.dart`: chỉ giữ quảng cáo thưởng; `FakeAdService(AdLedger)`.
  - `audio_service.dart`: `FakeAudioService(CitySettings)`.
  - Test viết lại: `app_smoke_test`, `ad_service_test`.
  - Test cắt bớt: `economy_test`, `recipes_gd8_test` (bỏ từ `:349`), `weather_mochi_test` (giữ Weather).
- **dev-ui**
  - `intro_screen.dart`: dùng `AppScope.read(ctx).game.markIntroSeen()`, xong thì vào `/`.
  - Thêm `lib/ui/city_routes.dart` thay `ui_routes.dart`, chuyển `fadeRoute` sang đây.
  - Test: viết lại `intro_test`; `qa_touch_targets_test` chuyển sang các bảng trong phố; `screens_test` chỉ giữ test thẻ kết quả `:107`; `step3_b_…` giữ `:67`, `:82`.
- **dev-game:** `wide_frame_test` chỉ giữ test làm bánh W=1600 (`:215+`).

**GIỮ** (cho GĐ3)
- Chuỗi làm bánh và 7 test của nó: `bake_session_view`, `frost_perf`, `hand_paint`, `logic`, `phase8_recipes`, `qa_bake_session_edge`, `qa_bake_stations`.
- `ui/common/{art, dialogs, format, panel, shop_scene, speech_bubble, star_row, sugar_button, wide_layout}`, `ui/sugarleaf/**`, `assets/characters`.

**Khoá arb** (localizer, đợt 3)
- Xoá các khoá không còn tham chiếu nào trong `lib/**.dart` (không tính `lib/l10n/gen`).
- **Giữ lại:** `settingsAlphaNote, settingsLanguage, settingsOff, settingsVersion, settingsReplayIntro, adRewardGranted, commonClaim, commonContinue, loginTitle, loginComeBack, offlineDuration{Days,Hours,HoursMinutes,Minutes}`, và 39 khoá đã chết từ trước (`summary*`, `day*`, `unlock*`, `item*`, `levelUpTitle`, `townMap`, `townBranchN`).

**Rủi ro**
- `RefFrame` toàn cục làm ảnh 3D mờ và vùng chạm nhỏ dưới 48 dp.
- Route nền tảng của Android ghi đè `initialRoute`.
- Test không được import file có thermion: `main*.dart`, `town3d_view/page`, `town_scene`, `shop3d_view/scene`.
- Đợt 2 làm build hỏng tạm thời.

## 5. Mở khoá theo cấp
- **dev-game**
  - `enum TownBannerNote {none, comingSoon, locked, unlocked}`: lô chi nhánh đã đủ cấp → `unlocked` (`townLotUnlocked`).
  - `static List<LotDef> TownRules.newlyUnlocked(DistrictDef d, int from, int to)`: trả về các lô có `from < requiresLevel ≤ to`, sắp theo cấp.
  - Trong view:
    - `ValueNotifier<int> _level` truyền xuống minimap và bản đồ.
    - Nghe ví: lên cấp thì xếp toast `townLotsUnlockedToast(n)` sau hiệu ứng "Lên cấp" khoảng 1,6 s. Đang ở trong tiệm thì giữ toast, ra phố mới hiện. Hiện xong gọi `onLevelSeen`.
    - Phố vừa hiện mà `level > levelSeen` thì báo bù. Cấp giảm thì đặt lại mốc, không báo.
- **dev-ui**
  - `TownMapPainter(…, int? playerLevel)`: lô còn khoá tô nhạt (alpha ~0,55) và vẽ ổ khoá bằng path.
  - `TownMinimap(…, ValueListenable<int>? playerLevel)`.
  - Bản đồ lớn: lô đã đủ cấp hiện `Icons.lock_open_rounded` và `townLotUnlocked` màu "đúng".
- Thử bằng `?xp=790` rồi ăn một món.

## 6. Chữ ký chốt cho đợt 2
```dart
// core: AppServices({required CityGame game, required CitySaveStore store, required AdService ads, required AudioService audio, CityDebugParams debug = CityDebugParams.none})
//       AppScope extends InheritedWidget { static AppServices of(ctx); static AppServices read(ctx); }
//       AppRoutes { town = '/'; intro = '/intro'; static String initialFor({required bool introSeen}); }
//       SugarleafApp({required services, required RouteFactory onGenerateRoute, String initialRoute = AppRoutes.town, Locale? forcedLocale, bool useGoogleFonts = true}) + giữ static supportedLocales/localeFor/resolveLocale
// ui:   RouteFactory cityRouteFactory({required WidgetBuilder town});
//       CitySettingsSheet({required LanguagePref language, required bool sound, required ValueChanged<LanguagePref> onLanguage, required ValueChanged<bool> onSound, required Future<void> Function() onReset, required VoidCallback onClose, String version = kAppVersionLabel})
//       CityMenuButton({required VoidCallback onPressed, double size = 48})
// game: abstract interface class TownSheetHost { void close(); void respawn(); }
//       Town3dView({required CityWallet wallet, int levelSeen = 1, ValueChanged<int>? onLevelSeen, Widget Function(BuildContext, TownSheetHost)? settingsSheet, bool saveReadOnly = false, quality, graphicsOverrides, bool showDebug = false, verbose, spawn, shopOptions})  // không dispose ví
//       Town3dPage({required CityGame game, required CitySaveStore store, CityDebugParams debug = CityDebugParams.none})  // lib/game/town3d/town3d_page.dart
```

## 7. Các đợt
| Đợt | Mã | Người | Việc |
|---|---|---|---|
| 0 | L1 | localizer | Thêm `townLotUnlocked`, `townLotsUnlockedToast(count)` (plural), `citySaveReadOnly`; sửa `settingsResetConfirmBody` theo thành phố; gen-l10n |
| 1 | C1 | dev-core | Lớp save v3 (§2), `CitySettings`, `CityGame`, `CityWallet` mở rộng, `city_day`, `CityDebugParams`, cùng 21 test. Chưa động vào file cũ |
| 1 | U1 | dev-ui | `CitySettingsSheet`, `CityMenuButton`; minimap và bản đồ vẽ khoá; kèm test |
| 1 | G1 | dev-game | `TownBannerNote.unlocked`, `TownRules.newlyUnlocked`, kèm test |
| 2 | C2/U2/G2 | dev-core, dev-ui, dev-game | Đợt cắt: mỗi người gỡ và sửa trong khu vực của mình theo §4 và §6; G2 làm thêm cài đặt, nghe ví, toast mở lô, `Town3dPage` |
| 3 | L2 | localizer | Xoá khoảng 230 khoá mồ côi |
| 4 | C3 | trưởng phòng / dev-core | analyze, test gói tạm, build web + apk |
| 5 | QA | — | 8 kịch bản trên web |
