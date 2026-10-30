// Công cụ chụp "mô phỏng game": dựng các màn hình THẬT của lib/ui ở khung 1280×720 với dữ liệu giả lập,
// chờ ảnh nhân vật vẽ tay nạp xong rồi xuất PNG vào docs/design/screens/.
//
// Không thuộc `flutter test` mặc định. Chạy lại (vd. khi có thêm ảnh nhân vật):
//   flutter test tool/screens/render_screens_test.dart
//
// Font: nạp font đóng gói của app từ assets/fonts (Fredoka, Baloo 2, Nunito). Thư mục xuất đổi được bằng
// --dart-define=SHOTS_OUT=<thư mục>. Chạy riêng từng cảnh bằng --plain-name "<số cảnh>" (vd. "11–16").
// V2 GĐ2: bỏ các cảnh của chế độ "ngày" V1 (màn ngày, quầy, trạm, tổng kết ngày); màn chính là bản đồ chương.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/characters/character_sprites.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/customer.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/scoring.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/services/audio_service.dart';
import 'package:sugarleaf_bakery/core/services/iap_service.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/decor/decor_screen.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_art.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';
import 'package:sugarleaf_bakery/ui/intro/short_intro_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/menu/quests_dialog.dart';
import 'package:sugarleaf_bakery/ui/recipes/recipe_book_screen.dart';
import 'package:sugarleaf_bakery/ui/season/season_pass_screen.dart';
import 'package:sugarleaf_bakery/ui/settings/settings_screen.dart';
import 'package:sugarleaf_bakery/ui/store/store_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/unlock_notice.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

/// Thư mục xuất ảnh; đổi bằng `--dart-define=SHOTS_OUT=<thư mục>` (vd. docs/design/ui-after).
const _outDir = String.fromEnvironment('SHOTS_OUT', defaultValue: 'docs/design/screens');
const _vi = Locale('vi');
const _en = Locale('en');

/// Font đóng gói trong assets/fonts (khai báo ở mục `fonts:` của pubspec) — nạp dưới đúng tên họ font của app.
const _fontFiles = <(String, List<String>)>[
  ('Nunito', ['Nunito-Regular', 'Nunito-SemiBold', 'Nunito-Bold', 'Nunito-ExtraBold']),
  ('Fredoka', ['Fredoka-Medium', 'Fredoka-SemiBold', 'Fredoka-Bold']),
  ('Baloo2', ['Baloo2-SemiBold', 'Baloo2-Bold', 'Baloo2-ExtraBold']),
];

/// Giờ "hôm nay" cố định → nhiệm vụ ngày, quà đăng nhập ra giống nhau mỗi lần chạy.
DateTime _now = DateTime(2026, 10, 28, 10);
DateTime _clock() => _now;

final _notes = <String>[];
final _written = <String>[];

/// levels.json thật (đọc thẳng file).
final _levels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

/// levels.json thật + chương thử 3 gồm L21–L40 (chép L20) — để chụp các mốc nhân viên L25–L32 khi levels.json mới
/// có 20 màn. GĐ8: levels.json đã có tới L50 → dùng bản thật.
final _levelsExt = () {
  final json = jsonDecode(File(LevelConfigLoader.assetPath).readAsStringSync()) as Map<String, dynamic>;
  final levels = (json['levels'] as List).cast<Map<String, dynamic>>();
  final last = levels.last;
  if ((last['id'] as int) >= 40) return _levels;
  (json['chapters'] as List).add({
    'id': 3,
    'title': {'en': 'Seaside Festival', 'vi': 'Lễ hội biển'},
    'starsToUnlock': 0,
    'mapArt': 'chapter_3',
  });
  final from = last['id'] as int;
  const n = 20;
  for (var k = 0; k < n; k++) {
    levels.add({
      ...last,
      'id': from + 1 + k,
      'chapter': 3,
      'special': false,
      'introScene': null,
      'outroScene': null,
      'mapPos': [0.08 + 0.84 * k / (n - 1), k.isEven ? 0.74 : 0.48],
    });
  }
  return LevelConfigLoader.parse(jsonEncode(json), strict: true);
}();

/// unlocks.json thật (đọc thẳng file).
final _unlocks = UnlockConfigLoader.parse(File(UnlockConfigLoader.assetPath).readAsStringSync());

/// monetization.json thật (đọc thẳng file): vật phẩm, thẻ mùa (đồng hồ giả nằm giữa mùa), gói IAP V2.
final _monetization = MonetizationConfigLoader.parse(File(MonetizationConfigLoader.assetPath).readAsStringSync());

final _shotKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== Đã xuất ${_written.length} ảnh vào $_outDir ===\n${_written.map((n) => '  $n.png').join('\n')}');
    if (_notes.isNotEmpty) {
      // ignore: avoid_print
      print('Ghi chú:\n${_notes.map((n) => '  - $n').join('\n')}');
    }
  });

  testWidgets('01 bản đồ chương (vi + en)', (tester) async {
    await _art(tester, _artMenu);
    for (final locale in [_vi, _en]) {
      final state = _midGame(locale);
      LevelMapScreen.giftShownThisSession = true;
      await _pump(tester, state, const LevelMapScreen(), locale);
      await _settle(tester);
      await _shot(tester, locale == _vi ? '01_map' : '01_map_en');
      await _dispose(tester);
    }
  });

  testWidgets('01b bản đồ: chương 2 còn khoá (thiếu sao)', (tester) async {
    await _art(tester, _artMenu);
    final state = _midGame(_vi, levelsDone: [for (final l in _levels.levelsInChapter(1)) l.id], stars: 1);
    LevelMapScreen.giftShownThisSession = true;
    await _pump(tester, state, const LevelMapScreen(), _vi);
    await _settle(tester);
    if (_levels.chapters.length > 1) {
      await tester.tap(find.byKey(const ValueKey('map-next')));
      await _settle(tester);
    }
    await _shot(tester, '01_map_locked_chapter');
    await _dispose(tester);
  });

  testWidgets('02 quà đăng nhập (ngày 4 của chuỗi 7 ngày)', (tester) async {
    await _art(tester, _artMenu);
    final state = _midGame(_vi, claimLogin: false);
    // Đã nhận 3 ngày liền trước hôm nay → hôm nay là quà ngày 4.
    final today = _now;
    for (var d = 3; d >= 1; d--) {
      _now = today.subtract(Duration(days: d));
      state.claimLogin();
    }
    _now = today;
    LevelMapScreen.giftShownThisSession = false; // bản đồ tự mở hộp quà sau khung hình đầu.
    await _pump(tester, state, const LevelMapScreen(), _vi);
    await _settle(tester);
    expect(find.byType(SLDialog), findsOneWidget);
    await _shot(tester, '02_login_reward');
    await _dispose(tester);
  });

  testWidgets('03 hội thoại truyện: mở đầu (Mai nói) + ông Hòa', (tester) async {
    await _art(tester, _artStory);
    await _sprites(tester, [('mai', 'smile'), ('hoa', 'smile')]);
    // Dòng 1 của cảnh mở đầu là người kể (cuốn sổ) → chạm một lần sang lời Mai.
    final state = GameState.newGame(clock: _clock)
      ..setLanguage(LanguagePref.vi)
      ..claimLogin();
    await _pump(tester, state, StoryOverlay(scene: Catalog.storyScene(StorySceneId.prologue), onFinished: () {}), _vi);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tapAt(const Offset(640, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, '03_story_mai');
    await _dispose(tester);

    await _pump(tester, state, StoryOverlay(scene: Catalog.storyScene(StorySceneId.hoa1), onFinished: () {}), _vi);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '03_story_hoa');
    await _dispose(tester);
  });

  testWidgets('8B2 cảnh truyện bà Rosa', (tester) async {
    // Cảnh truyện rosa1 (bà Rosa nói dòng đầu).
    await _art(tester, _artStory);
    await _sprites(tester, [('vip_00', 'smile'), ('mai', 'smile')]);
    final story = GameState.newGame(clock: _clock)
      ..setLanguage(LanguagePref.vi)
      ..claimLogin();
    await _pump(tester, story, StoryOverlay(scene: Catalog.storyScene(StorySceneId.rosa1), onFinished: () {}), _vi);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '8b_story_rosa');
    await _dispose(tester);
    await _drainArt(tester);
  });

  for (final chapter in [4, 5]) {
    testWidgets('8F bản đồ chương $chapter (ảnh thật)', (tester) async {
      // Đang tới màn thứ 3 của chương: thấy đường đã qua (lõi nâu đậm), màn đang tới (vòng sáng), màn khoá (mờ).
      await _art(tester, _artMenu);
      LevelMapScreen.giftShownThisSession = true;
      final first = _levels.levelsInChapter(chapter).first.id;
      final state = _midGame(_vi, levelsDone: [for (var id = 1; id < first + 2; id++) id], stars: 3);
      await _pump(tester, state, const LevelMapScreen(), _vi);
      await _settle(tester);
      await _settle(tester);
      await _shot(tester, '8f_map_chapter$chapter');
      await _dispose(tester);
      await _drainArt(tester);
    });
  }

  testWidgets('8B3 bản đồ chương 3', (tester) async {
    // Bản đồ chương 3 (ảnh chapter_3.webp chưa có → nền giấy dự phòng): đã qua L1–L22, đang tới L23.
    await _art(tester, _artMenu);
    LevelMapScreen.giftShownThisSession = true;
    final map = _midGame(_vi, levelsDone: [for (var id = 1; id <= 22; id++) id], stars: 3);
    await _pump(tester, map, const LevelMapScreen(), _vi);
    await _settle(tester);
    await _shot(tester, '8b_map_chapter3');
    await _dispose(tester);
    await _drainArt(tester);
  });

  testWidgets('11–16 nâng cấp, trang trí, sổ công thức, nhiệm vụ, cửa hàng, cài đặt', (tester) async {
    await _art(tester, _artMeta);
    final pages = <String, Widget>{
      '11_upgrades': const UpgradesScreen(),
      '12_decor': const DecorScreen(),
      '13_recipe_book': const RecipeBookScreen(),
      '15_shop': const StoreScreen(),
      '16_settings': const SettingsScreen(),
    };
    for (final MapEntry(key: name, value: page) in pages.entries) {
      await _pump(tester, _midGame(_vi), page, _vi);
      await tester.pumpAndSettle();
      await _shot(tester, name);
      await _dispose(tester);
    }

    // Nhiệm vụ ngày: hộp thoại mở trên bản đồ.
    LevelMapScreen.giftShownThisSession = true;
    await _pump(tester, _midGame(_vi), const LevelMapScreen(), _vi);
    await _settle(tester);
    showQuestsDialog(tester.element(find.byType(LevelMapScreen)));
    await _settle(tester);
    await _shot(tester, '14_quests');
    await _dispose(tester);
  });

  testWidgets('21–23 nâng cấp 2 tab (mở rộng tiệm, thiết bị) + thông báo mở khoá', (tester) async {
    await _art(tester, _artMeta);
    // Qua L1–13: kệ bánh tầng đã mua, lò thứ 2 mua được, bàn ghế còn khoá; vài thiết bị đã nâng.
    GameState shop() {
      final state = _midGame(_vi, levelsDone: [for (final l in _levels.levels) if (l.id <= 13) l.id])..addCoins(9000);
      state.buyUnlock('case_stand');
      state.buyEquipment('fastOven');
      state.buyEquipment('goldenOven');
      state.buyEquipment('goldenOven');
      state.buyEquipment('tongs');
      return state;
    }

    await _pump(tester, shop(), const UpgradesScreen(focus: 'oven_2'), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '21_upgrades_expansion');
    await _dispose(tester);

    await _pump(tester, shop(), const UpgradesScreen(initialTab: UpgradesTab.equipment), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '22_upgrades_equipment');
    await _dispose(tester);

    // Thông báo trên bản đồ: một mục (kệ bánh tầng, vừa qua L5) và nhiều mục.
    for (final (name, ids) in [
      ('23_unlock_notice', ['case_stand']),
      ('23b_unlock_notice_multi', ['oven_2', 'eq:fastOven:3', 'eq:bigTray:2', 'eq:whisk:2']),
    ]) {
      LevelMapScreen.giftShownThisSession = true;
      await _pump(tester, _midGame(_vi), const LevelMapScreen(), _vi);
      await _settle(tester);
      showUnlockNotice(tester.element(find.byType(LevelMapScreen)), ids);
      await _settle(tester);
      await _shot(tester, name);
      await _dispose(tester);
    }
  });

  testWidgets('31–33 nhân viên: tab Nhân viên, hộp "Khi bạn vắng nhà", thẻ Sẵn sàng có nhân viên', (tester) async {
    await _art(tester, _artMeta);
    await tester.runAsync(() async {
      // Ảnh nhân viên (Flutter Image) giải mã trước để ảnh chụp có chân dung.
      for (final s in _unlocks.staff) {
        await precacheImage(AssetImage(CharacterSprites.assetPath(s.character, 'smile')), tester.binding.rootElement!);
      }
    });
    // Qua L1–30 (chương thử 3): đã thuê thu ngân (nâng tốc độ 2 lần, tay nghề 1 lần) + thợ bánh; bàn ghế chưa mua →
    // phục vụ "Cần có Bàn ghế quán trước"; Ami thuê được; quản lý còn khoá (L32).
    GameState team({int upTo = 30}) {
      final state = _midGame(_vi, levels: _levelsExt, levelsDone: [for (var id = 1; id <= upTo; id++) id])
        ..addCoins(60000);
      state.buyUnlock(StaffIds.cashier);
      state.buyUnlock(StaffIds.baker);
      state.upgradeStaff(StaffIds.cashier, StaffStat.speed);
      state.upgradeStaff(StaffIds.cashier, StaffStat.speed);
      state.upgradeStaff(StaffIds.cashier, StaffStat.skill);
      state.upgradeStaff(StaffIds.baker, StaffStat.skill);
      return state;
    }

    await _pump(tester, team(), const UpgradesScreen(initialTab: UpgradesTab.staff), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '31_staff_tab');
    await _dispose(tester);

    // Cuộn xuống hàng cuối (Ami + cô Hạnh).
    await _pump(tester, team(), const UpgradesScreen(initialTab: UpgradesTab.staff, focus: StaffIds.manager), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '31b_staff_tab_bottom');
    await _dispose(tester);

    // Vắng 6 giờ 20 phút, quản lý cấp 1 (trần 4 giờ) → ghi rõ đã cắt theo trần.
    final start = _now;
    final away = team(upTo: 32)..buyUnlock(StaffIds.manager);
    // Thu nhập một màn ở chương 3 thật ~6000 xu (lượt giả của _midGame chỉ 300): chơi lại L28–32 → xu TB một level
    // ~6000 → 4 giờ × 0,20 × 6000 ≈ 4800 xu như thật.
    for (var id = 28; id <= 32; id++) {
      away.applyLevelResult(
        LevelResult(
          levelId: id,
          won: true,
          stars: 3,
          coins: 6000,
          served: 8,
          lost: 0,
          specialsDone: 0,
          bestCombo: 3,
          perfectBakes: 1,
          recipeStars: const {},
          goalValue: 9,
          fiveStarTreats: 1,
        ),
      );
    }
    away.refreshOffline(_now);
    _now = _now.add(const Duration(hours: 6, minutes: 20));
    away.refreshOffline(_now);
    if (away.pendingOffline == null) _notes.add('32: không có pendingOffline');
    LevelMapScreen.giftShownThisSession = true;
    await _pump(tester, away, const LevelMapScreen(), _vi);
    await _settle(tester);
    await _shot(tester, '32_offline_dialog');
    await _dispose(tester);
    _now = start;

    // Thẻ Sẵn sàng của L33: đã mua bàn ghế, thuê đủ 4 người làm trong màn (+ quản lý, không hiện).
    final ready = team(upTo: 32)
      ..buyUnlock('cafe_tables')
      ..buyUnlock(StaffIds.waiter)
      ..buyUnlock(StaffIds.baker2)
      ..buyUnlock(StaffIds.manager);
    await _pump(tester, ready, const LevelScreen(levelId: 33), _vi);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    await _shot(tester, '33_ready_card_staff');
    await _dispose(tester);
  });

  testWidgets('51–54 GĐ6: thẻ Sẵn sàng có vật phẩm, ×2 xu, cửa hàng V2, Thẻ mùa', (tester) async {
    await _art(tester, _artMeta);
    // Ảnh vật phẩm / gói / vé (Image.asset, ResizeImage): cho vòng lặp thật giải mã rồi vẽ lại.
    Future<void> images() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // 51: L7 (lần đầu có vật phẩm → chú thích giới thiệu), đã chọn "Khách kiên nhẫn" (trong kho).
    for (final locale in [_vi, _en]) {
      final ready = _midGame(locale);
      await _pump(tester, ready, const LevelScreen(levelId: 7), locale);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.byKey(ValueKey('level-booster-${BoosterId.patience.name}')));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await images();
      await _shot(tester, locale == _vi ? '51_ready_boosters' : '51_ready_boosters_en');
      await _dispose(tester);
    }

    // 52: kết quả thắng L7 lần đầu 3 sao (điểm mùa + kim cương) có nút ×2 xu.
    final done = _midGame(_vi);
    final result = LevelResult(
      levelId: 7,
      won: true,
      stars: 3,
      coins: 420,
      served: 9,
      lost: 1,
      specialsDone: 1,
      bestCombo: 5,
      perfectBakes: 2,
      recipeStars: const {},
      goalValue: 2140,
      fiveStarTreats: 2,
    );
    final delta = done.applyLevelResult(result);
    if (delta.seasonPoints <= 0 && delta.gems <= 0) _notes.add('52: không có kim cương / điểm mùa');
    await _pump(tester, done, LevelResultScreen(result: result, progress: delta), _vi);
    await tester.pump(const Duration(seconds: 3));
    await images();
    await _shot(tester, '52_result_double');
    await _dispose(tester);

    // 55: hộp tạm dừng sau khi dùng vật phẩm, chưa bán (dòng "vật phẩm sẽ được trả lại").
    final paused = _midGame(_vi)..markBoosterIntroSeen();
    await _pump(tester, paused, const LevelScreen(levelId: 7), _vi);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byKey(ValueKey('level-booster-${BoosterId.patience.name}')));
    await tester.pump(const Duration(milliseconds: 50));
    final pl = AppLocalizations.of(tester.element(find.byType(LevelScreen)));
    await tester.tap(find.text(pl.levelStart));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip(pl.levelPause));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await images();
    await _shot(tester, '55_pause_booster_refund');
    await _dispose(tester);

    // 53: cửa hàng V2 (đã qua L3 → gói khởi đầu nổi bật).
    for (final locale in [_vi, _en]) {
      final shop = _midGame(locale);
      await _pump(tester, shop, const StoreScreen(), locale);
      await images();
      await _settle(tester);
      await _shot(tester, locale == _vi ? '53_store_v2' : '53_store_v2_en');
      await _dispose(tester);
    }

    // 54: Thẻ mùa — đã nhận bậc 1, còn thưởng chờ.
    final season = _midGame(_vi);
    season.claimSeason(1, premium: false);
    if (season.seasonClaimable.isEmpty) _notes.add('54: không có thưởng chờ');
    await _pump(tester, season, const SeasonPassScreen(), _vi);
    await images();
    await _settle(tester);
    await _shot(tester, '54_season_pass');
    await _dispose(tester);
  });

  testWidgets('41–45 cảnh mở đầu (4 cảnh) + intro ngắn', (tester) async {
    // Giây trong cảnh mở đầu (sau khi bắt đầu chạy) cho từng ảnh chụp.
    const shots = <(String, double, Locale)>[
      ('41_intro_kitchen', 3.2, _vi),
      ('42_intro_case', 10.6, _vi),
      ('43c_intro_walk', 13.3, _vi),
      ('43d_intro_walk_b', 13.55, _vi),
      ('43e_intro_arrive', 14.45, _vi),
      ('43f_intro_reach_flip', 14.8, _vi),
      ('43_intro_door_sign', 15.3, _vi),
      ('43g_intro_joy', 16.3, _vi),
      ('43b_intro_door_sign_en', 15.3, _en),
      ('44_intro_logo', 20.6, _vi),
    ];
    for (final (name, at, locale) in shots) {
      final state = GameState.newGame(clock: _clock)..setLanguage(locale == _vi ? LanguagePref.vi : LanguagePref.en);
      state.attachLevelConfig(_levels);
      await _pump(tester, state, const IntroScreen(), locale);
      await _introImages(tester, tester.element(find.byType(IntroScreen)), logoWidth: 460);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(Duration(milliseconds: (at * 1000).round()));
      await tester.pump(const Duration(milliseconds: 16));
      await _shot(tester, name);
      await _dispose(tester);
    }

    final state = _midGame(_vi)..markIntroSeen();
    await _pump(tester, state, const ShortIntroScreen(), _vi);
    await _introImages(tester, tester.element(find.byType(ShortIntroScreen)), logoWidth: ShortIntroScreen.logoWidth);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2400));
    await _shot(tester, '45_short_intro');
    await _dispose(tester);
  });

  testWidgets('8B1 sổ công thức có Bí quyết của bà', (tester) async {
    // Sổ công thức: đã qua L41 (mở Bí quyết), đủ xu; vani đã học 1 bậc → thấy sao vàng, % giá và nút học bậc 2.
    await _art(tester, _artMeta);
    final rich = _midGame(_vi, levelsDone: [for (var id = 1; id <= 41; id++) id], stars: 3)..addCoins(60000);
    rich.buyRecipeSecret(RecipeId.cupcakeVanilla);
    await _pump(tester, rich, const RecipeBookScreen(), _vi);
    await tester.pumpAndSettle();
    await _shot(tester, '8b_recipe_secrets');
    await _dispose(tester);
    await _drainArt(tester);
  });
}

// ------------------------------------------------------------------ Dữ liệu giả lập

/// Ván giữa game: đã qua [levelsDone] (mặc định L1–6, sao 3/2/1 xen kẽ khi [stars] null), đã xem hết truyện, đã
/// qua hướng dẫn, có trang trí, vài món đã thành thạo và nhiệm vụ đang làm dở.
GameState _midGame(Locale locale, {bool claimLogin = true, List<int>? levelsDone, int? stars, LevelConfig? levels}) {
  final state = GameState.newGame(clock: _clock)
    ..setLanguage(locale == _vi ? LanguagePref.vi : LanguagePref.en)
    ..addCoins(2400)
    ..addGems(30);
  state.attachLevelConfig(levels ?? _levels);
  state.attachUnlockConfig(_unlocks);
  state.attachMonetizationConfig(_monetization);
  if (claimLogin) state.claimLogin();
  for (final s in StorySceneId.values) {
    state.markSceneSeen(s);
  }
  for (final s in StationId.values) {
    state.markTutorialSeen(s);
  }
  final done = levelsDone ?? [for (final l in _levels.levels) if (l.id <= 6) l.id];
  for (final id in done) {
    state.applyLevelResult(
      LevelResult(
        levelId: id,
        won: true,
        stars: stars ?? 3 - id % 3,
        coins: 300,
        served: 8,
        lost: 1,
        specialsDone: 0,
        bestCombo: 3,
        perfectBakes: 1,
        recipeStars: const {},
        goalValue: 9,
        fiveStarTreats: 1,
      ),
    );
  }
  for (final d in [DecorId.wallpaperStripes, DecorId.counterFlowers, DecorId.windowCurtains, DecorId.plantFern]) {
    if (state.buyDecor(d) == PurchaseResult.ok) state.equipDecor(Catalog.decorItem(d).slot, d);
  }
  // Phục vụ vài đơn: thành thạo món + tiến độ nhiệm vụ (một nhiệm vụ xong, chưa nhận).
  final served = <(RecipeId, BakeOutcome Function(Order))>[
    (RecipeId.cupcakeVanilla, _perfect),
    (RecipeId.cupcakeChocolate, _perfect),
    (RecipeId.muffinBlueberry, _good),
    (RecipeId.eggTart, _perfect),
    (RecipeId.strawberryCake, _okay),
  ];
  for (final (recipe, outcome) in served) {
    final data = Catalog.recipe(recipe);
    final order = Order(
      id: 0,
      recipe: recipe,
      frosting: data.frostings.first,
      toppings: [ToppingRequest(data.toppings.first, 2)],
      box: data.box,
      line: OrderLineKind.generic1,
    );
    const customer = Customer(kind: CustomerKind.regular, appearanceSeed: 1);
    state.applyOrderResult(
      order,
      customer,
      Scoring.evaluate(
        order: order,
        customer: customer,
        outcome: outcome(order),
        modifiers: state.bakeModifiers,
        decorTipBonusPct: 0,
      ),
    );
  }
  return state;
}

BakeOutcome _perfect(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: o.recipeData.bakeTarget,
      frostCoverage: 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// 5★ chưa tròn trịa: hơi lệch vùng nướng, trộn hơi thiếu (mọi trạm vẫn đạt → khách khen, không chê).
BakeOutcome _good(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns * 0.88,
      bakeRelease: o.recipeData.bakeTarget + 0.06,
      frostCoverage: 0.93,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// ~3★: trộn thiếu, kem loang.
BakeOutcome _okay(Order o) => BakeOutcome(
      wrongMouldDrops: 1,
      mixTurns: o.recipeData.mixTurns * 0.7,
      bakeRelease: o.recipeData.bakeTarget + 0.06,
      frostCoverage: 0.7,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

// ------------------------------------------------------------------ Dựng + chụp

AppServices _services(GameState state) => AppServices(
      state: state,
      saves: MemorySaveRepository(),
      ads: FakeAdService(state),
      iap: FakeIapService(state, delay: Duration.zero),
      audio: FakeAudioService(state),
      levels: state.levelConfig,
      unlocks: _unlocks,
      monetization: _monetization,
    );

/// Theme y như app thật: font đóng gói đã nạp sẵn ở [_loadFonts].
ThemeData _theme(Locale locale) => AppTheme.build(locale: locale);

/// Dựng [home] như `SugarleafApp` (AppScope → MaterialApp → RefFrame → Theme), bọc RepaintBoundary để chụp.
Future<void> _pump(WidgetTester tester, GameState state, Widget home, Locale locale) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = _theme(locale);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: AppScope(
        services: _services(state),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: SugarleafApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: theme,
          home: home,
          onGenerateRoute: onGenerateUiRoute,
          builder: (ctx, child) => RefFrame(child: Theme(data: theme, child: child ?? const SizedBox.shrink())),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _sprites(WidgetTester tester, List<(String, String)> sprites) async {
  await tester.runAsync(() => CharacterSprites.preload(sprites));
  for (final (id, expr) in sprites) {
    if (CharacterSprites.isMissing(id, expr)) _notes.add('thiếu ảnh ${CharacterSprites.assetPath(id, expr)} (vẽ hình code)');
  }
}

/// Chờ bản đồ ổn định (nhịp nút đang tới chạy vài giây rồi dừng; ảnh nền nạp xong).
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

/// Xuất ảnh hiện tại ra `$_outDir/<name>.png` (1280×720).
Future<void> _shot(WidgetTester tester, String name) async {
  // Ảnh nhân vật nạp xong muộn (nếu có) → cho vòng lặp thật chạy một chút rồi vẽ lại.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  final error = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    return null;
  });
  expect(error, isNull);
  expect(tester.takeException(), isNull, reason: name);
  _written.add(name);
}

/// Bỏ cây widget (huỷ timer/game), chờ toast tắt.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

/// Cho các lượt nạp ảnh màn vừa yêu cầu trong vùng giờ giả của test chạy xong (đọc file thật + bước tiếp theo trong
/// giờ giả, xen kẽ) — gọi cuối test: lượt nạp bỏ dở giữ chỗ hàng nạp của `ArtSprites`, `_art` của test sau chờ mãi.
Future<void> _drainArt(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

// ------------------------------------------------------------------ Ảnh đồ hoạ vẽ tay

/// Giải mã trước ảnh của cảnh mở đầu (đúng provider mà màn dùng) để ảnh chụp có đủ hình.
Future<void> _introImages(WidgetTester tester, BuildContext context, {required double logoWidth}) async {
  final images = [
    introSceneImage(context, IntroAssets.kitchen),
    introSceneImage(context, IntroAssets.shop),
    introSceneImage(context, IntroAssets.door),
    introObjectImage(context, IntroAssets.openSign, IntroLayout.signSize.width),
    introObjectImage(context, IntroAssets.doorBell, IntroLayout.bellSize.width),
    for (final pose in [...IntroAssets.maiPoses, IntroAssets.maiWalkB, IntroAssets.maiSmile])
      introObjectImage(context, pose, IntroLayout.maiSize.width),
    introObjectImage(context, IntroAssets.emblem, logoWidth),
  ];
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image, context, onError: (e, _) => _notes.add('ảnh cảnh mở đầu lỗi: $e'));
    }
  });
}

/// Nạp trước ảnh vẽ tay (bánh, đồ vật, nền…) để ảnh chụp giống app thật. Bộ nhớ đệm ảnh nhỏ có hạn (48 MB)
/// nên mỗi cảnh chỉ nạp nhóm cần dùng.
Future<void> _art(WidgetTester tester, List<ArtRef> refs) async {
  await tester.runAsync(() => ArtSprites.preload(refs));
}

final _artMenu = [ArtSprites.scene(ArtScene.menu), ...ArtSprites.group(ArtGroup.items), ...ArtSprites.group(ArtGroup.cakes)];
final _artStory = [
  ArtSprites.scene(ArtScene.storyTown),
  ArtSprites.scene(ArtScene.storyGrandmaKitchen),
  ArtSprites.shopBase,
  ...ArtSprites.group(ArtGroup.items),
  ...ArtSprites.group(ArtGroup.decor),
  ...ArtSprites.group(ArtGroup.tiles),
];
final _artMeta = [
  ArtSprites.shopBase,
  ...ArtSprites.group(ArtGroup.items),
  ...ArtSprites.group(ArtGroup.cakes),
  ...ArtSprites.group(ArtGroup.decor),
  ...ArtSprites.group(ArtGroup.tiles),
];

// ------------------------------------------------------------------ Font

/// Nạp font đóng gói (assets/fonts) dưới đúng tên họ font của app.
Future<void> _loadFonts() async {
  for (final (family, files) in _fontFiles) {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('assets/fonts/$name.ttf');
      if (!file.existsSync()) {
        _notes.add('thiếu ${file.path}');
        continue;
      }
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      any = true;
    }
    if (any) await loader.load();
  }
}
