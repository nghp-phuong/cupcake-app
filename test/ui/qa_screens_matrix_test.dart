import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/day/story_overlay.dart';
import 'package:sugarleaf_bakery/ui/menu/login_gift_dialog.dart';
import 'package:sugarleaf_bakery/ui/menu/quests_dialog.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';
import 'package:sugarleaf_bakery/ui/upgrades/upgrades_screen.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// QA: mọi màn chính × (en, vi) × các cỡ ngang (kể cả tai thỏ). Kiểm: không FlutterError (RenderFlex overflowed…),
/// không khoá thô / chuỗi en khi đang vi, không còn glyph ★/☆, không widget Material lệch phong cách.

/// Một màn cần thử: dựng ván + đi tới màn. [live] = màn chạy liên tục (không pumpAndSettle).
class _Screen {
  const _Screen(this.name, this.state, this.open, {this.live = false});

  final String name;
  final GameState Function(LanguagePref lang) state;
  final Future<void> Function(WidgetTester tester) open;
  final bool live;
}

AppLocalizations _l(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first));

Future<void> _push(WidgetTester tester, String route, [Object? args]) async {
  navigator(tester).pushNamed(route, arguments: args);
  await tester.pumpAndSettle();
}

Future<void> _openLevel(WidgetTester tester, int id) async {
  navigator(tester).pushNamed(AppRoutes.level, arguments: LevelArgs(id));
  await qaFrames(tester, 12);
}

final _screens = <_Screen>[
  _Screen('bản đồ', (lang) => qaState(lang, cleared: 12), (tester) async {}),
  _Screen('bản đồ (chương cuối)', (lang) => qaState(lang, cleared: 49), (tester) async {}),
  _Screen('quà đăng nhập', (lang) => qaState(lang, claimLogin: false), (tester) async {
    expect(find.byType(LoginGiftDialog), findsOneWidget);
  }),
  _Screen('hộp vắng nhà', qaStateWithOffline, (tester) async {
    expect(find.byKey(const ValueKey('offline-dialog')), findsOneWidget);
  }),
  _Screen('thẻ Sẵn sàng L2', (lang) => qaState(lang), (tester) async {
    await _openLevel(tester, 2);
    expect(find.text(_l(tester).levelStart), findsOneWidget);
  }, live: true),
  _Screen('màn chơi L2', (lang) => qaState(lang), (tester) async {
    await _openLevel(tester, 2);
    await tester.tap(find.text(_l(tester).levelStart));
    await qaFrames(tester, 20);
    expect(find.byTooltip(_l(tester).levelPause), findsOneWidget);
  }, live: true),
  _Screen('hội thoại truyện (prologue L1)', (lang) => qaState(lang, cleared: 0, prologueSeen: false), (tester) async {
    await _openLevel(tester, 1);
    expect(find.byType(StoryOverlay), findsOneWidget);
  }, live: true),
  _Screen('kết quả thắng', (lang) => qaState(lang, cleared: 3), (tester) async {
    await _push(tester, AppRoutes.levelResult, LevelResultArgs(fakeLevelResult(3, won: true, stars: 3, coins: 999999)));
  }),
  _Screen('kết quả thua', (lang) => qaState(lang, cleared: 3), (tester) async {
    await _push(tester, AppRoutes.levelResult, LevelResultArgs(fakeLevelResult(4, won: false)));
  }),
  _Screen('nâng cấp: mở rộng', (lang) => qaState(lang, cleared: 20), (tester) async {
    await _push(tester, AppRoutes.upgrades, const UpgradesArgs(tab: UpgradesTab.expansion));
  }),
  _Screen('nâng cấp: thiết bị', (lang) => qaState(lang, cleared: 20), (tester) async {
    await _push(tester, AppRoutes.upgrades, const UpgradesArgs(tab: UpgradesTab.equipment));
  }),
  _Screen('nâng cấp: nhân viên', (lang) => qaState(lang, cleared: 40), (tester) async {
    await _push(tester, AppRoutes.upgrades, const UpgradesArgs(tab: UpgradesTab.staff));
  }),
  _Screen('trang trí', (lang) => qaState(lang, cleared: 20), (tester) => _push(tester, AppRoutes.decor)),
  _Screen('sổ công thức', (lang) => qaState(lang, cleared: 10), (tester) => _push(tester, AppRoutes.recipes)),
  _Screen('sổ công thức + bí quyết', (lang) => qaState(lang, cleared: 45, coins: 5000), (tester) async {
    await _push(tester, AppRoutes.recipes);
    expect(find.byKey(const ValueKey('recipe-secret-bonus')), findsOneWidget);
  }),
  _Screen('nhiệm vụ ngày', (lang) => qaState(lang, cleared: 5), (tester) async {
    await tester.tap(find.byTooltip(_l(tester).menuQuests));
    await tester.pumpAndSettle();
    expect(find.byType(QuestsDialog), findsOneWidget);
  }),
  _Screen('cửa hàng', (lang) => qaState(lang, cleared: 5), (tester) => _push(tester, AppRoutes.store)),
  _Screen('vé mùa', (lang) => qaState(lang, cleared: 8), (tester) => _push(tester, UiRoutes.season)),
  _Screen('cài đặt', (lang) => qaState(lang), (tester) => _push(tester, AppRoutes.settings)),
];

void main() {
  setUp(() => qaNow = DateTime(2026, 10, 28, 10));

  testWidgets('tự kiểm bộ dò: bắt được khoá thô, chuỗi en khi vi, glyph ★', (tester) async {
    expect(qaEnglishOnly, contains('Start'));
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [Text('Start'), Text('levelStart'), Text('3 ★')]),
    ));
    expect(qaTextProblems(tester, vi: true), hasLength(3));
    expect(qaTextProblems(tester, vi: false), hasLength(2));
  });

  for (final screen in _screens) {
    for (final lang in [LanguagePref.en, LanguagePref.vi]) {
      testWidgets('ma trận: ${screen.name} [${lang.name}] — các cỡ ngang, không tràn / chưa dịch / ★', (tester) async {
        final problems = <String>[];
        final errors = await qaCatchErrors(() async {
          final state = screen.state(lang);
          await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
          await screen.open(tester);
          for (final vp in qaViewports) {
            vp.apply(tester);
            if (screen.live) {
              await qaFrames(tester, 4);
            } else {
              await tester.pumpAndSettle();
            }
            for (final p in qaTextProblems(tester, vi: lang == LanguagePref.vi)) {
              problems.add('[$vp] $p');
            }
          }
          final material = qaMaterialLeftovers();
          if (material.isNotEmpty) problems.add('widget Material: ${material.join(', ')}');
          if (screen.live) {
            // Tháo cây (dừng vòng lặp Flame / bộ hẹn giờ) trước khi test kết thúc.
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 5));
          } else {
            await tester.pump(const Duration(seconds: 4)); // toast tự ẩn
          }
        });
        expect(errors, isEmpty, reason: 'FlutterError ở ${screen.name}');
        expect(problems.toSet().toList(), isEmpty, reason: 'nội dung ở ${screen.name}');
      });
    }
  }
}
