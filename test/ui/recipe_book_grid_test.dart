import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/recipes/recipe_book_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

/// Ván đã qua L1..L[cleared] (không thêm xu).
GameState _state({LanguagePref lang = LanguagePref.en, int cleared = 8}) {
  final state = GameState.newGame()
    ..setLanguage(lang)
    ..claimLogin();
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: 0);
  return state;
}

Future<void> _openBook(WidgetTester tester, GameState state, {Size view = const Size(1280, 720)}) async {
  await pumpSugarApp(tester, state);
  tester.view.physicalSize = view;
  navigator(tester).pushNamed(AppRoutes.recipes);
  await tester.pumpAndSettle();
}

Finder _tiles() => find.descendant(of: find.byType(RecipeGrid), matching: find.byType(SLPressable));

Finder _gridLocks() => find.descendant(
      of: find.byType(RecipeGrid),
      matching: find.byWidgetPredicate((w) => w is SLIcon && w.id == 'lock'),
    );

/// Sổ công thức GĐ8A: đủ 18 món trên một trang (6×3), món khoá/mở theo ván, ô đủ lớn để chạm, không tràn.
void main() {
  test('lưới: ≤ 10 món 5 cột, 18 món 6 cột (3 hàng)', () {
    expect(RecipeGrid.columnsFor(10), 5);
    expect(RecipeGrid.columnsFor(18), 6);
    expect(Catalog.recipes.length, 18);
  });

  testWidgets('đủ 18 ô, món mở hiện tên, món khoá hiện ổ khoá (đúng theo ván)', (tester) async {
    final state = _state();
    await _openBook(tester, state);

    expect(_tiles(), findsNWidgets(Catalog.recipes.length));
    final unlocked = state.unlockedRecipes;
    expect(unlocked, isNotEmpty);
    expect(unlocked.length, lessThan(Catalog.recipes.length));
    expect(_gridLocks(), findsNWidgets(Catalog.recipes.length - unlocked.length));

    final l = AppLocalizations.of(tester.element(find.byType(RecipeGrid)));
    for (final r in Catalog.recipes) {
      final name = find.descendant(of: find.byType(RecipeGrid), matching: find.text(l.recipeName(r.id)));
      expect(name, state.isRecipeUnlocked(r.id) ? findsOneWidget : findsNothing, reason: r.id.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('chọn được món mới (khoá) ở hàng cuối: trang chi tiết hiện ổ khoá', (tester) async {
    await _openBook(tester, _state());
    final last = _tiles().at(Catalog.recipes.indexWhere((r) => r.id == RecipeId.bucheDeNoel));
    expect(tester.widget<SLPressable>(last).selected, isFalse);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(tester.widget<SLPressable>(last).selected, isTrue);
    // Ổ khoá trong lưới + một ổ khoá lớn trên trang chi tiết.
    final locks = find.byWidgetPredicate((w) => w is SLIcon && w.id == 'lock');
    expect(locks.evaluate().length, _gridLocks().evaluate().length + 1);
    expect(tester.takeException(), isNull);
  });

  for (final (view, lang) in [
    (const Size(1280, 720), LanguagePref.en),
    (const Size(1280, 720), LanguagePref.vi),
    (const Size(960, 540), LanguagePref.vi),
  ]) {
    testWidgets('không tràn, ô ≥ 48dp, nằm trọn trong khung ở ${view.width.toInt()}×${view.height.toInt()} ${lang.name}', (
      tester,
    ) async {
      await _openBook(tester, _state(lang: lang, cleared: 13), view: view);
      expect(tester.takeException(), isNull);

      final scale = view.width / 1280;
      final grid = tester.getRect(find.byType(RecipeGrid));
      final screen = Offset.zero & view;
      expect(screen.contains(grid.topLeft) && screen.contains(grid.bottomRight - const Offset(0.5, 0.5)), isTrue);

      final rects = [for (final e in _tiles().evaluate()) tester.getRect(find.byWidget(e.widget))];
      expect(rects, hasLength(Catalog.recipes.length));
      for (final (i, r) in rects.indexed) {
        // Cỡ theo khung tham chiếu 1280×720 (RefFrame co cả màn).
        expect(r.width / scale, greaterThanOrEqualTo(48), reason: 'ô $i rộng');
        expect(r.height / scale, greaterThanOrEqualTo(48), reason: 'ô $i cao');
        expect(grid.inflate(0.5).contains(r.topLeft) && grid.inflate(0.5).contains(r.bottomRight), isTrue, reason: 'ô $i');
        for (final o in rects.skip(i + 1)) {
          expect(r.intersect(o).isEmpty || r.intersect(o).width <= 0 || r.intersect(o).height <= 0, isTrue, reason: 'ô $i chồng');
        }
      }
    });
  }
}
