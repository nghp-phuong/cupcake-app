import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

GameState _state(Map<String, dynamic> json, {LanguagePref lang = LanguagePref.en}) => GameState.fromJson(json)
  ..setLanguage(lang)
  ..claimLogin();

/// Màn nâng cấp / trang trí / sổ công thức vẽ tay (Bước 3, đợt 2): không còn ripple Material, trạng thái vẫn phân
/// biệt được, vùng chạm ≥ 48.
void main() {
  testWidgets('nâng cấp: mục tối đa thành huy hiệu (không phải nút), mục thiếu xu vẫn bấm được', (tester) async {
    final state = _state({
      'coins': 0,
      'xp': 1400,
      'oven': 5,
      'tools': {'whisk': 2, 'pipingBag': 1, 'tongs': 3},
    });
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.upgrades);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Fully upgraded'), findsNWidgets(2)); // lò + kẹp
    expect(find.widgetWithText(SLButton, 'Fully upgraded'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'medal_max'), findsWidgets);
    expect(find.widgetWithText(SLButton, 'Upgrade'), findsNWidgets(2));
    for (final e in find.widgetWithText(SLButton, 'Upgrade').evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.text('Upgrade').first);
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.toolLevel(ToolId.whisk), 2);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang trí: tab ô là thẻ đánh dấu trang (selected, ≥48), 5 nút ô có tooltip, chọn món không ripple', (
    tester,
  ) async {
    final state = _state({
      'coins': 600,
      'xp': 300,
      'decorOwned': ['wallpaperStripes', 'counterFlowers'],
      'decorEquipped': {'wallpaper': 'wallpaperStripes', 'counter': 'counterFlowers'},
    });
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.decor);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    for (final label in ['Wallpaper', 'Floor', 'Counter', 'Window', 'Plants']) {
      final tab = find.ancestor(of: find.text(label), matching: find.byType(SLPressable)).first;
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(48), reason: label);
    }
    expect(find.byTooltip('Wallpaper: Cream stripes'), findsOneWidget);
    expect(find.byTooltip('Floor: Basic'), findsOneWidget);
    expect(find.byTooltip('Counter: Flower vase'), findsOneWidget);

    // Đang đặt → nhãn tĩnh "Placed" (không phải nút); Cơ bản → nút "Place".
    expect(find.widgetWithText(SLChip, 'Placed'), findsOneWidget);
    expect(find.widgetWithText(SLButton, 'Place'), findsOneWidget);

    await tester.tap(find.text('Floral wallpaper'));
    await tester.pumpAndSettle();
    final selected = tester.widget<SLPressable>(
      find.ancestor(of: find.text('Floral wallpaper'), matching: find.byType(SLPressable)).first,
    );
    expect(selected.selected, isTrue);
    expect(state.equippedDecor[DecorSlot.wallpaper], DecorId.wallpaperStripes); // chỉ xem thử.

    await tester.tap(find.text('Window'));
    await tester.pumpAndSettle();
    expect(find.text('Lace curtains'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sổ công thức: ô món chọn được (không ripple), món khoá có ổ khoá vẽ tay, 3★ có nhãn thưởng', (
    tester,
  ) async {
    await pumpSugarApp(tester, _state({'xp': 1400, 'mastery': {'cupcakeVanilla': 3}}));
    navigator(tester).pushNamed(AppRoutes.recipes);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Mastered! +5 gems'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'lock'), findsNWidgets(2)); // cấp 10, 12

    final tile = find.ancestor(of: find.text('Missing page. Unlocks at level 12'), matching: find.byType(SLPressable));
    expect(tester.widget<SLPressable>(tile).selected, isFalse);
    await tester.tap(find.text('Missing page. Unlocks at level 12'));
    await tester.pumpAndSettle();
    expect(tester.widget<SLPressable>(tile.first).selected, isTrue);
    expect(find.text('Missing page. Unlocks at level 12'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ba màn dựng được ở tiếng Việt, mọi tab trang trí không tràn', (tester) async {
    final state = _state({'xp': 1400, 'coins': 50}, lang: LanguagePref.vi);
    await pumpSugarApp(tester, state);
    for (final route in [AppRoutes.upgrades, AppRoutes.recipes, AppRoutes.decor]) {
      navigator(tester).pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      if (route != AppRoutes.decor) navigator(tester).pop();
      await tester.pumpAndSettle();
    }
    for (final slot in ['Giấy dán tường', 'Sàn nhà', 'Quầy', 'Cửa sổ', 'Cây xanh']) {
      await tester.tap(find.text(slot));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: slot);
    }
  });
}
