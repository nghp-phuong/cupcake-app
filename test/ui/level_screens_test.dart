import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/app_scope.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/day/order_ticket.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/level/level_result_screen.dart';
import 'package:sugarleaf_bakery/ui/level/level_screen.dart';
import 'package:sugarleaf_bakery/ui/map/level_map_screen.dart';

import 'ui_test_helpers.dart';

GameState _state() => GameState.newGame()
  ..setLanguage(LanguagePref.en)
  ..claimLogin();

LevelResult _result({required int levelId, required bool won, int stars = 0}) => LevelResult(
      levelId: levelId,
      won: won,
      stars: stars,
      coins: 320,
      served: 7,
      lost: 2,
      specialsDone: 1,
      bestCombo: 4,
      perfectBakes: 1,
      recipeStars: const {RecipeId.cupcakeVanilla: 4},
      goalValue: won ? 9 : 3,
      fiveStarTreats: 1,
    );

AppLocalizations _l(WidgetTester tester, Type screen) =>
    AppLocalizations.of(tester.element(find.byType(screen).first));

/// Nút level trên bản đồ (key `map-level-<id>`).
final _nodes =
    find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('map-level-'));

/// Cảnh chơi (Flame) chạy liên tục: không dùng pumpAndSettle khi LevelScreen đang mở.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// levels.json thật nhưng chỉ giữ chương 1 + level đầu tiên (cấu hình hợp lệ, 1 level).
LevelConfig _oneLevelConfig() {
  final m = jsonDecode(File(LevelConfigLoader.assetPath).readAsStringSync()) as Map<String, dynamic>;
  m['chapters'] = [(m['chapters'] as List<dynamic>).first];
  m['levels'] = [(m['levels'] as List<dynamic>).first];
  return LevelConfigLoader.parse(jsonEncode(m));
}

/// Như khi levels.json nạp lỗi: không chương, không level.
LevelConfig _emptyConfig() => LevelConfig(version: 1, defaults: const LevelDefaults(), chapters: const [], levels: const []);

void main() {
  testWidgets('kết quả thắng (level sau đã mở): Màn tiếp + Chơi lại + Bản đồ', (tester) async {
    final state = _state();
    winLevels(state, [1], stars: 2);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(_result(levelId: 1, won: true, stars: 2)));
    await tester.pumpAndSettle();

    final l = _l(tester, LevelResultScreen);
    expect(find.text(l.levelResultWinTitle), findsOneWidget);
    expect(find.text(l.levelNext), findsOneWidget);
    expect(find.text(l.levelReplay), findsOneWidget);
    expect(find.text(l.mapBackToMap), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kết quả thắng nhưng level sau còn khoá: không có Màn tiếp', (tester) async {
    await pumpSugarApp(tester, _state()); // ván mới: chỉ L1 mở → L11 chắc chắn khoá
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(_result(levelId: 10, won: true, stars: 3)));
    await tester.pumpAndSettle();

    final l = _l(tester, LevelResultScreen);
    expect(find.text(l.levelNext), findsNothing);
    expect(find.text(l.levelReplay), findsOneWidget);
    expect(find.text(l.mapBackToMap), findsOneWidget);
  });

  testWidgets('kết quả thua: tiêu đề an ủi + Chơi lại + Bản đồ; Bản đồ → màn chính', (tester) async {
    await pumpSugarApp(tester, _state());
    navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(_result(levelId: 3, won: false)));
    await tester.pumpAndSettle();

    final l = _l(tester, LevelResultScreen);
    expect(find.text(l.levelResultLoseTitle), findsOneWidget);
    expect(find.text(l.levelNext), findsNothing);
    expect(find.text(l.levelReplay), findsOneWidget);

    await tester.tap(find.text(l.mapBackToMap));
    await tester.pumpAndSettle();
    expect(find.byType(LevelResultScreen), findsNothing);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(_nodes, findsWidgets);
  });

  testWidgets('thiếu args kết quả / route /levels cũ / level chưa mở → bản đồ', (tester) async {
    await pumpSugarApp(tester, _state());
    for (final (route, args) in [
      (AppRoutes.levelResult, null),
      ('/levels', null),
      (AppRoutes.level, const LevelArgs(5)),
    ]) {
      navigator(tester).pushNamed(route, arguments: args);
      await tester.pumpAndSettle();
      expect(find.byType(LevelResultScreen), findsNothing, reason: route);
      expect(find.byType(LevelScreen), findsNothing, reason: route);
      expect(find.byType(LevelMapScreen), findsOneWidget, reason: route);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('LevelScreen: thẻ Sẵn sàng → chơi (HUD) → tạm dừng → Thoát không cộng kết quả', (tester) async {
    final state = _state();
    winLevels(state, [1]);
    await pumpSugarApp(tester, state);
    final coins = state.coins;
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2)); // L2: không có cảnh mở màn
    await _pumpFrames(tester);

    final l = _l(tester, LevelScreen);
    expect(find.text(l.levelStart), findsOneWidget);
    expect(find.text('A Familiar Face'), findsOneWidget);

    await tester.tap(find.text(l.levelStart));
    await _pumpFrames(tester);
    expect(find.byTooltip(l.levelPause), findsOneWidget);

    await tester.tap(find.byTooltip(l.levelPause));
    await _pumpFrames(tester);
    expect(find.text(l.levelPauseTitle), findsOneWidget);

    await tester.tap(find.text(l.levelQuit));
    await _pumpFrames(tester);
    expect(find.byType(LevelScreen), findsNothing);
    expect(find.byType(LevelMapScreen), findsOneWidget);
    expect(state.coins, coins);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đơn đặc biệt: chạm khách → cảnh truyện → vé đơn → Để sau (khách vẫn đợi, giờ chạy tiếp)', (tester) async {
    final state = _state();
    winLevels(state, [1]);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2));
    await _pumpFrames(tester);
    final l = _l(tester, LevelScreen);
    await tester.tap(find.text(l.levelStart));
    await _pumpFrames(tester, 2);

    final view = tester.widget<LevelPlayView>(find.byType(LevelPlayView));
    final session = view.session;
    final visit = session.level.specials.first;
    while (session.specialCustomer == null && !session.isOver) {
      session.advance(LevelSession.maxFrameDt);
    }
    final id = session.specialCustomer!.id;
    view.onSpecialTap(id);
    await _pumpFrames(tester, 4);
    expect(session.paused, isTrue);

    if (visit.scene != null && !state.seenScenes.contains(visit.scene)) {
      expect(find.byType(StoryOverlay), findsOneWidget);
      // Chạm hết các câu thoại.
      for (var i = 0; i < 12 && find.byType(StoryOverlay).evaluate().isNotEmpty; i++) {
        await tester.tapAt(const Offset(640, 300));
        await _pumpFrames(tester, 2);
      }
      expect(state.seenScenes, contains(visit.scene));
    }
    expect(find.byType(OrderTicket), findsOneWidget);
    await tester.tap(find.text(l.levelSpecialLater));
    await _pumpFrames(tester, 2);
    expect(find.byType(OrderTicket), findsNothing);
    expect(session.paused, isFalse);
    expect(session.specialCustomer?.id, id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hết giờ chưa đạt 1★: hỏi +30 giây → Thôi → kết quả, cộng xu đúng một lần', (tester) async {
    final state = _state();
    winLevels(state, [1]);
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(2));
    await _pumpFrames(tester);
    final l = _l(tester, LevelScreen);
    await tester.tap(find.text(l.levelStart));
    await _pumpFrames(tester, 2);

    final session = tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;
    final coinsBefore = state.coins;
    // Không bán gì: tới hết giờ (khách đặc biệt cứ để đó).
    while (!session.isOver) {
      session.advance(LevelSession.maxFrameDt);
    }
    await _pumpFrames(tester, 6);
    expect(session.starsNow, 0);
    expect(find.text(l.levelExtraTimeTitle(LevelScreen.extraTimeSec)), findsOneWidget);

    await tester.tap(find.text(l.levelExtraTimeNo));
    await tester.pumpAndSettle();
    expect(find.byType(LevelResultScreen), findsOneWidget);
    final rl = _l(tester, LevelResultScreen);
    expect(find.text(rl.levelResultLoseTitle), findsOneWidget);
    expect(state.coins, coinsBefore + session.finish().coins);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LevelScreen level 1: chiếu cảnh mở màn (prologue) trước thẻ Sẵn sàng', (tester) async {
    final state = _state();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(1));
    await _pumpFrames(tester);

    if (state.seenScenes.contains(StorySceneId.prologue)) {
      expect(find.text(_l(tester, LevelScreen).levelStart), findsOneWidget);
    } else {
      expect(find.byType(StoryOverlay), findsOneWidget);
    }
  });

  testWidgets('HUD: nhãn điều kiện khách đặc biệt (đủ khách trước giờ hạn); quá hạn → toast "không ghé được"', (tester) async {
    final state = _state();
    // Level đầu tiên có lượt ghé cần phục vụ đủ khách trước một mốc giờ (chương 1: L10); mở tới level đó.
    final config = testLevelConfig();
    bool conditional(SpecialVisit v) => v.afterServed > 0 && v.bySec != null;
    final level = config.levels.firstWhere((lv) => lv.specials.any(conditional));
    final services = testServices(state, levels: config);
    winLevels(state, [for (final lv in config.levels) if (lv.id < level.id) lv.id]);
    await pumpSugarApp(tester, state, services: services);
    navigator(tester).pushNamed(AppRoutes.level, arguments: LevelArgs(level.id));
    await _pumpFrames(tester);
    final l = _l(tester, LevelScreen);
    // Bỏ qua cảnh mở màn (nếu có) tới thẻ Sẵn sàng.
    for (var i = 0; i < 12 && find.byType(StoryOverlay).evaluate().isNotEmpty; i++) {
      await tester.tapAt(const Offset(640, 300));
      await _pumpFrames(tester, 2);
    }
    await tester.tap(find.text(l.levelStart));
    await _pumpFrames(tester, 2);

    final session = tester.widget<LevelPlayView>(find.byType(LevelPlayView)).session;
    final visit = session.level.specials.firstWhere(conditional);
    // Tới khi lượt ghé có điều kiện là lượt sắp tới (các lượt trước đã ghé), không bán gì.
    while (!identical(session.nextSpecialVisit, visit) && !session.isOver) {
      session.advance(LevelSession.maxFrameDt);
    }
    await _pumpFrames(tester, 2);
    final who = specialWhoName(l, visit.who);
    final remain = (session.duration - visit.bySec!).ceil();
    final time = '${remain ~/ 60}:${(remain % 60).toString().padLeft(2, '0')}';
    expect(find.text(l.levelSpecialCondition(who, session.served, visit.afterServed, time)), findsOneWidget);

    // Quá hạn mà chưa đủ khách → lượt bị bỏ, toast nhẹ, nhãn đổi sang lượt sau (hoặc biến mất).
    final skipped = session.specialsSkipped;
    while (session.elapsed <= visit.bySec! + 0.1) {
      session.advance(LevelSession.maxFrameDt);
    }
    expect(session.specialsSkipped, greaterThan(skipped));
    await _pumpFrames(tester, 2);
    expect(find.text(l.levelSpecialSkipped(who)), findsOneWidget);
    expect(find.text(l.levelSpecialCondition(who, session.served, visit.afterServed, time)), findsNothing);
    // Cho toast tự ẩn (không để timer treo).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
  });

  group('cấu hình 1 level', () {
    testWidgets('bản đồ 1 nút; level không tồn tại → về bản đồ; thắng level cuối không có Màn tiếp', (tester) async {
      final state = _state();
      await pumpSugarApp(tester, state, services: testServices(state, levels: _oneLevelConfig()));
      expect(_nodes, findsOneWidget);

      navigator(tester).pushNamed(AppRoutes.level, arguments: const LevelArgs(99));
      await tester.pumpAndSettle();
      expect(find.byType(LevelScreen), findsNothing);
      expect(find.byType(LevelMapScreen), findsOneWidget);

      navigator(tester).pushNamed(AppRoutes.levelResult, arguments: LevelResultArgs(_result(levelId: 1, won: true, stars: 3)));
      await tester.pumpAndSettle();
      final l = _l(tester, LevelResultScreen);
      expect(find.text(l.levelNext), findsNothing);
      expect(find.text(l.levelReplay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('cấu hình rỗng (levels.json nạp lỗi)', () {
    Future<AppLocalizations> pumpEmpty(WidgetTester tester) async {
      final state = _state();
      final AppServices services = testServices(state, levels: _emptyConfig());
      await pumpSugarApp(tester, state, services: services);
      return AppLocalizations.of(tester.element(find.byType(LevelMapScreen)));
    }

    testWidgets('bản đồ: không có nút level, hiện lời nhắn; thanh trên vẫn dùng được', (tester) async {
      final l = await pumpEmpty(tester);
      expect(_nodes, findsNothing);
      expect(find.text(l.mapLoadError), findsOneWidget);
      expect(find.byTooltip(l.menuSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, route, args) in [
      ('/levels', '/levels', null),
      ('/level', AppRoutes.level, const LevelArgs(1)),
      ('/level/result', AppRoutes.levelResult, LevelResultArgs(_result(levelId: 1, won: true, stars: 1))),
    ]) {
      testWidgets('$name → về bản đồ, không lỗi', (tester) async {
        await pumpEmpty(tester);
        navigator(tester).pushNamed(route, arguments: args);
        await tester.pumpAndSettle();
        expect(find.byType(LevelScreen), findsNothing);
        expect(find.byType(LevelResultScreen), findsNothing);
        expect(find.byType(LevelMapScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
