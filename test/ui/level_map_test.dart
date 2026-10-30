import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/common/art.dart';
import 'package:sugarleaf_bakery/ui/common/navigation.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';
import 'package:sugarleaf_bakery/ui/map/map_art.dart';
import 'package:sugarleaf_bakery/ui/map/map_node.dart';
import 'package:sugarleaf_bakery/ui/menu/login_gift_dialog.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

/// Ván mới (en) đã nhận quà hôm nay, đã gắn levels.json thật; cảnh mở màn L1 đã xem.
GameState _state() {
  final state = GameState.newGame()
    ..setLanguage(LanguagePref.en)
    ..claimLogin()
    ..markSceneSeen(StorySceneId.prologue);
  state.attachLevelConfig(_config);
  return state;
}

final _config = testLevelConfig();

/// Bản lưu V1 (ngày 4, chưa có `progress`) → GameState.load quy đổi + quà chào mừng.
Map<String, dynamic> _v1Save() => GameState.newGame().toJson()
  ..remove('progress')
  ..['v'] = 1
  ..['day'] = 4;

/// Kho lưu không chép được bản pre_v2 → phiên khoá ghi.
class _NoPreV2Repo extends MemorySaveRepository {
  _NoPreV2Repo(super.initial);

  @override
  Future<void> backupPreV2(String data) async => throw StateError('pre_v2 không ghi được');
}

Finder _node(int id) => find.byKey(ValueKey('map-level-$id'));

MapLevelNode _nodeWidget(WidgetTester tester, int id) => tester.widget<MapLevelNode>(_node(id));

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(LevelMapScreen)));

/// Số sao đã tô trong nút [id].
int _filledStars(WidgetTester tester, int id) => tester
    .widgetList<StarIcon>(find.descendant(of: _node(id), matching: find.byType(StarIcon)))
    .where((s) => s.filled && s.size < 40) // bỏ sao lớn đính góc level đặc biệt
    .length;

/// Cảnh chơi (Flame) chạy liên tục: không dùng pumpAndSettle khi LevelScreen đang mở.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpMap(WidgetTester tester, GameState state) =>
    pumpSugarApp(tester, state, services: testServices(state, levels: _config));

void main() {
  testWidgets('nút + sao theo tiến trình: đã qua (sao), đang tới (cờ), khoá; level ★ to hơn', (tester) async {
    final state = _state();
    winLevels(state, [1], stars: 3);
    winLevels(state, [2], stars: 1);
    winLevels(state, [3], stars: 2);
    await _pumpMap(tester, state);

    final chapter1 = _config.levelsInChapter(1);
    expect(find.byType(MapLevelNode), findsNWidgets(chapter1.length));
    for (final (id, stars) in [(1, 3), (2, 1), (3, 2)]) {
      expect(_nodeWidget(tester, id).state, MapNodeState.completed, reason: 'L$id');
      expect(_nodeWidget(tester, id).stars, stars, reason: 'L$id');
      expect(_filledStars(tester, id), stars, reason: 'L$id');
    }
    final current = _nodeWidget(tester, 4);
    expect(state.currentLevelId, 4);
    expect(current.state, MapNodeState.open);
    expect(current.current, isTrue);
    expect(find.descendant(of: _node(4), matching: find.byType(MapFlag)), findsOneWidget);
    expect(find.byType(MapFlag), findsOneWidget);
    for (final level in chapter1.where((lv) => lv.id > 4)) {
      expect(_nodeWidget(tester, level.id).state, MapNodeState.locked, reason: 'L${level.id}');
      expect(_filledStars(tester, level.id), 0);
    }
    // Level đặc biệt (★) to hơn level thường.
    final special = chapter1.where((lv) => lv.isSpecial);
    if (special.isNotEmpty) {
      expect(tester.getSize(_node(special.first.id)).width, greaterThan(tester.getSize(_node(1)).width));
    }
    // Không hiện cấp tiệm / XP; ô tổng sao = 6.
    expect(find.text('Bakery level 1'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('map-total-stars')), matching: find.text('6')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level khoá không mở được (toast); level mở → thẻ Sẵn sàng', (tester) async {
    final state = _state();
    await _pumpMap(tester, state);
    final l = _l(tester);

    await tester.tap(_node(3));
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsNothing);
    expect(find.text(l.mapLevelLocked), findsOneWidget);
    await settleToasts(tester);

    await tester.tap(_node(1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(find.text(l.levelStart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chương khoá: phủ mờ + "Cần X ★ — bạn có Y ★" + gợi ý chơi lại level ít sao', (tester) async {
    expect(_config.chapters.length, greaterThanOrEqualTo(2), reason: 'levels.json cần chương 2');
    final state = _state();
    final chapter1 = [for (final lv in _config.levelsInChapter(1)) lv.id];
    winLevels(state, chapter1, stars: 1);
    final chapter2 = _config.chapters[1];
    expect(state.isChapterUnlocked(chapter2.id), isFalse);
    await _pumpMap(tester, state);
    final l = _l(tester);

    // Mở sẵn ở chương 1 (chứa level đang tới); nút › sang chương 2.
    expect(find.text("Chapter 1 · Grandma's Kitchen"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-chapter-locked')), findsOneWidget);
    expect(find.text(l.mapChapterLockedTitle(chapter2.id)), findsOneWidget);
    expect(find.text(l.mapChapterNeedStars(chapter2.starsToUnlock, state.totalStars)), findsOneWidget);
    expect(find.text(l.mapChapterReplayHint), findsOneWidget);
    expect(find.byKey(ValueKey('map-replay-${chapter1.first}')), findsOneWidget);

    // Nút level của chương khoá không bấm được (bị phủ).
    final first2 = _config.levelsInChapter(chapter2.id).first.id;
    await tester.tap(_node(first2), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsNothing);

    // Nút gợi ý → mở level ít sao.
    await tester.tap(find.byKey(ValueKey('map-replay-${chapter1.first}')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quà đăng nhập tự bật lần đầu vào bản đồ trong phiên, quay lại không bật nữa', (tester) async {
    final state = GameState.newGame()..setLanguage(LanguagePref.en);
    await _pumpMap(tester, state);
    expect(find.byType(LoginGiftDialog), findsOneWidget);
    expect(LevelMapScreen.giftShownThisSession, isTrue);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginGiftDialog), findsNothing);
    expect(state.pendingLoginReward, isNotNull); // chưa nhận vẫn không tự bật lại trong phiên
    expect(tester.takeException(), isNull);
  });

  testWidgets('sau kết quả thắng: sao bay vào nút, ổ khoá level kế rơi, trạng thái cuối đúng', (tester) async {
    final state = _state();
    winLevels(state, [1], stars: 3);
    await _pumpMap(tester, state);

    // Thắng L2 (2★) như LevelScreen: cộng vào ván, sang màn kết quả kèm delta.
    final result = fakeLevelResult(2, won: true, stars: 2);
    final delta = state.applyLevelResult(result);
    expect(delta.unlockedLevel, 3);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(result, progress: delta));
    await tester.pumpAndSettle();
    expect(find.byType(LevelResultScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level-result-map')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Giữa hoạt cảnh: L2 còn hiện số sao cũ, L3 còn khoá dù ván đã mở.
    expect(state.isLevelUnlocked(3), isTrue);
    expect(_nodeWidget(tester, 2).stars, 0);
    expect(_nodeWidget(tester, 3).state, MapNodeState.locked);

    await tester.pumpAndSettle();
    expect(_nodeWidget(tester, 2).state, MapNodeState.completed);
    expect(_nodeWidget(tester, 2).stars, 2);
    expect(_filledStars(tester, 2), 2);
    expect(_nodeWidget(tester, 3).state, MapNodeState.open);
    expect(_nodeWidget(tester, 3).current, isTrue);
    expect(find.descendant(of: _node(3), matching: find.byType(MapFlag)), findsOneWidget);
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thắng level cuối chương đủ sao: cuộn tới chương mới + hộp thoại "Chương 2 đã mở!"', (tester) async {
    expect(_config.chapters.length, greaterThanOrEqualTo(2), reason: 'levels.json cần chương 2');
    final state = _state();
    final chapter1 = [for (final lv in _config.levelsInChapter(1)) lv.id];
    winLevels(state, chapter1.sublist(0, chapter1.length - 1), stars: 3);
    await _pumpMap(tester, state);

    final result = fakeLevelResult(chapter1.last, won: true, stars: 3);
    final delta = state.applyLevelResult(result);
    final chapter2 = _config.chapters[1];
    expect(delta.unlockedChapter, chapter2.id);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(result, progress: delta));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-result-map')));
    await tester.pumpAndSettle();

    final l = _l(tester);
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsOneWidget);
    expect(find.text(l.mapChapterUnlockedTitle(chapter2.id)), findsOneWidget);
    await tester.tap(find.text(l.mapChapterUnlockedGo));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsNothing);
    // Đang xem chương 2, không còn phủ khoá; level đầu chương 2 mở và là level đang tới.
    expect(find.text('${l.levelChapterLabel(chapter2.id)} · ${chapter2.titleFor('en')}'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-chapter-locked')), findsNothing);
    final first2 = _config.levelsInChapter(chapter2.id).first.id;
    expect(_nodeWidget(tester, first2).state, MapNodeState.open);
    expect(_nodeWidget(tester, first2).current, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thắng level cuối chương → "Màn tiếp" → thoát về bản đồ: vẫn hiện hộp "Chương 2 đã mở!"', (tester) async {
    final state = _state();
    final chapter1 = [for (final lv in _config.levelsInChapter(1)) lv.id];
    winLevels(state, chapter1.sublist(0, chapter1.length - 1), stars: 3);
    await _pumpMap(tester, state);

    final result = fakeLevelResult(chapter1.last, won: true, stars: 3);
    final delta = state.applyLevelResult(result);
    final chapter2 = _config.chapters[1];
    expect(delta.unlockedChapter, chapter2.id);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(result, progress: delta));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizations.of(tester.element(find.byType(LevelResultScreen))).levelNext));
    await _pumpFrames(tester);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(hasMapReveal, isTrue);

    // Thoát màn chơi (nút back hệ thống) → goToMenu() không kèm delta: hàng chờ không bị xoá.
    await navigator(tester).maybePop();
    await _pumpFrames(tester);
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsNothing);
    final l = _l(tester);
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsOneWidget);
    expect(find.text(l.mapChapterUnlockedTitle(chapter2.id)), findsOneWidget);
    expect(hasMapReveal, isFalse);
    await tester.tap(find.text(l.mapChapterUnlockedGo));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-chapter-locked')), findsNothing);
    expect(_nodeWidget(tester, _config.levelsInChapter(chapter2.id).first.id).state, MapNodeState.open);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Chơi lại" gộp hoạt cảnh: sao từ mức thấp nhất → cao nhất, level mở giữ nguyên', (tester) async {
    final state = _state();
    winLevels(state, [1], stars: 3);
    await _pumpMap(tester, state);

    // L2 lần đầu 2★ (mở L3) → Chơi lại → 3★ → Bản đồ.
    final first = fakeLevelResult(2, won: true, stars: 2);
    final d1 = state.applyLevelResult(first);
    expect(d1.unlockedLevel, 3);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(first, progress: d1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.of(tester.element(find.byType(LevelResultScreen))).levelReplay));
    await _pumpFrames(tester);
    expect(find.byType(LevelScreen), findsOneWidget);

    final second = fakeLevelResult(2, won: true, stars: 3);
    final d2 = state.applyLevelResult(second);
    expect(d2.unlockedLevel, isNull);
    navigator(tester).pushReplacementNamed(AppRoutes.levelResult, arguments: LevelResultArgs(second, progress: d2));
    await _pumpFrames(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-result-map')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Giữa hoạt cảnh: L2 còn 0★ (mức trước cả hai lượt), L3 còn khoá.
    expect(_nodeWidget(tester, 2).stars, 0);
    expect(_nodeWidget(tester, 3).state, MapNodeState.locked);

    await tester.pumpAndSettle();
    expect(_nodeWidget(tester, 2).stars, 3);
    expect(_filledStars(tester, 2), 3);
    expect(_nodeWidget(tester, 3).state, MapNodeState.open);
    expect(hasMapReveal, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bản đồ chưa ở trên cùng khi được gọi về: hoạt cảnh nằm chờ, quay lại mới chạy', (tester) async {
    final state = _state();
    final chapter1 = [for (final lv in _config.levelsInChapter(1)) lv.id];
    winLevels(state, chapter1.sublist(0, chapter1.length - 1), stars: 3);
    await _pumpMap(tester, state);

    final store = tester.widget<SLButton>(find.byWidgetPredicate((w) => w is SLButton && w.tooltip == 'Store'));
    store.onPressed!();
    await tester.pumpAndSettle();
    queueMapReveal(state.applyLevelResult(fakeLevelResult(chapter1.last, won: true, stars: 3)));
    menuReturns.value++; // như goToMenu nhưng cửa hàng vẫn che bản đồ
    await tester.pumpAndSettle();
    expect(hasMapReveal, isTrue);
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsNothing);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(hasMapReveal, isFalse);
    expect(find.byKey(const ValueKey('map-chapter-unlocked')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tuyến lạ (vd. /day của V1) → về bản đồ có sẵn, không chồng thêm bản đồ', (tester) async {
    await _pumpMap(tester, _state());
    navigator(tester).pushNamed('/day');
    await tester.pumpAndSettle();
    expect(find.byType(LevelMapScreen, skipOffstage: false), findsOneWidget);
    expect(navigator(tester).canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('người chơi V1 vừa quy đổi: hộp "Chào mừng trở lại" một lần, trước quà đăng nhập', (tester) async {
    final repo = MemorySaveRepository(jsonEncode(_v1Save()));
    final state = (await tester.runAsync(() => GameState.load(repo)))!..setLanguage(LanguagePref.en);
    expect(state.welcomeGiftPending, isTrue);
    expect(state.pendingLoginReward, isNotNull);
    await _pumpMap(tester, state);

    final l = _l(tester);
    expect(find.byKey(const ValueKey('map-welcome-back')), findsOneWidget);
    expect(find.text(l.mapWelcomeTitle), findsOneWidget);
    expect(find.text(l.mapWelcomeBody(GameState.welcomeGiftCoins, GameState.welcomeGiftGems)), findsOneWidget);
    expect(find.byType(LoginGiftDialog), findsNothing, reason: 'lời chào trước quà đăng nhập');

    await tester.tap(find.text(l.mapChapterUnlockedGo));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-welcome-back')), findsNothing);
    expect(state.welcomeGiftPending, isFalse);
    expect(find.byType(LoginGiftDialog), findsOneWidget);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();
    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-welcome-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quy đổi V1 nhưng phiên khoá ghi: không hiện lời chào', (tester) async {
    final repo = _NoPreV2Repo(jsonEncode(_v1Save()));
    final state = (await tester.runAsync(() => GameState.load(repo)))!
      ..setLanguage(LanguagePref.en)
      ..claimLogin();
    expect(state.savesLocked, isTrue);
    expect(state.welcomeGiftPending, isTrue);
    await _pumpMap(tester, state);
    expect(find.byKey(const ValueKey('map-welcome-back')), findsNothing);
    expect(state.welcomeGiftPending, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiệu năng: nhịp nút đang tới không dựng lại trang bản đồ / đường đi', (tester) async {
    final state = _state();
    await _pumpMap(tester, state);
    // Vào lại bản đồ (mở cửa hàng rồi quay về) → nút đang tới nhịp lại; lấy mẫu giữa chừng.
    await tester.tap(find.byTooltip('Store'));
    await tester.pumpAndSettle();
    navigator(tester).pop();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final page = tester.widget(find.byKey(const ValueKey('map-chapter-1')));
    final trail = tester.widget(find.byType(MapTrail));
    final node = tester.widget(_node(1));
    double scale() => tester
        .widgetList<Transform>(find.descendant(of: _node(1), matching: find.byType(Transform)))
        .map((t) => t.transform.getMaxScaleOnAxis())
        .fold(1.0, (a, b) => a > b ? a : b);
    final scales = <double>{};
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'nhịp còn chạy');
      scales.add(scale());
    }
    expect(scales.length, greaterThan(1), reason: 'nút đang tới thực sự nhịp');
    // Trang, đường đi, nút: cùng một đối tượng widget → bản đồ không bị dựng lại mỗi khung.
    expect(identical(tester.widget(find.byKey(const ValueKey('map-chapter-1'))), page), isTrue);
    expect(identical(tester.widget(find.byType(MapTrail)), trail), isTrue);
    expect(identical(tester.widget(_node(1)), node), isTrue);
    // Nhịp có hạn: chờ xong thì không còn khung hình nào được lên lịch.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiếng Việt: thanh trên + bản đồ dựng không tràn', (tester) async {
    final state = _state()..setLanguage(LanguagePref.vi);
    winLevels(state, [1, 2], stars: 2);
    await _pumpMap(tester, state);
    expect(find.text('Chương 1 · Căn bếp của bà'), findsOneWidget);
    expect(find.text('Sổ công thức'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
