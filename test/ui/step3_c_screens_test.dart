import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'ui_test_helpers.dart';

/// Ván từ JSON + đã qua L1..L[cleared] (không thêm xu) — mở khoá / thiết bị / trang trí khoá theo màn đã qua.
GameState _state(Map<String, dynamic> json, {LanguagePref lang = LanguagePref.en, int cleared = 0}) {
  final state = GameState.fromJson(json)
    ..setLanguage(lang)
    ..claimLogin();
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: 0);
  return state;
}

/// Màn nâng cấp / trang trí / sổ công thức vẽ tay (Bước 3, đợt 2): không còn ripple Material, trạng thái vẫn phân
/// biệt được, vùng chạm ≥ 48.
void main() {
  testWidgets('nâng cấp: mục tối đa thành huy hiệu (không phải nút), mục thiếu xu vẫn bấm được', (tester) async {
    final state = _state({
      'coins': 0,
      'oven': 5,
      'tools': {'whisk': 2, 'pipingBag': 1, 'tongs': 3},
    }, cleared: 13); // qua L13: mọi cấp kế của 5 thiết bị còn lại đã tới mốc
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.upgrades);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Fully upgraded'), findsNWidgets(2)); // lò vùng vàng + kẹp (cấp cũ trong bản lưu V1)
    expect(find.widgetWithText(SLButton, 'Fully upgraded'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'medal_max'), findsWidgets);
    expect(find.widgetWithText(SLButton, 'Upgrade'), findsNWidgets(5)); // lò nhanh, khay, tủ, phới, túi kem
    for (final e in find.widgetWithText(SLButton, 'Upgrade').evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byKey(const ValueKey('upg-buy-whisk')));
    await tester.pumpAndSettle();
    expect(find.text('Not enough coins'), findsOneWidget);
    expect(state.equipmentTier(ToolId.whisk.name), 2);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang trí: tab ô là thẻ đánh dấu trang (selected, ≥48), 5 nút ô có tooltip, chọn món không ripple', (
    tester,
  ) async {
    final state = _state({
      'coins': 600,
      'decorOwned': ['wallpaperStripes', 'counterFlowers'],
      'decorEquipped': {'wallpaper': 'wallpaperStripes', 'counter': 'counterFlowers'},
    }, cleared: 3);
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
    // Qua L1–8 → mở tới L9: còn khoá bánh phô mai (L10) và bánh sinh nhật (L12).
    await pumpSugarApp(tester, _state({'mastery': {'cupcakeVanilla': 3}}, cleared: 8));
    navigator(tester).pushNamed(AppRoutes.recipes);
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Mastered! +${Economy.masteryGemReward} gems'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SLIcon && w.id == 'lock'), findsNWidgets(11)); // L10, L12 + 8 món GĐ8A (chương 3–5) + khoá Bí quyết của bà (GĐ8B) trên trang chi tiết

    // Ô món khoá ghi ngắn "Level 12"; trang chi tiết ghi câu đầy đủ.
    final tile = find.ancestor(of: find.text('Level 12'), matching: find.byType(SLPressable));
    expect(tester.widget<SLPressable>(tile).selected, isFalse);
    await tester.tap(find.text('Level 12'));
    await tester.pumpAndSettle();
    expect(tester.widget<SLPressable>(tile.first).selected, isTrue);
    expect(find.text('Missing page. Reach level 12 to find it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ba màn dựng được ở tiếng Việt, mọi tab trang trí không tràn', (tester) async {
    final state = _state({'coins': 50}, lang: LanguagePref.vi, cleared: 13);
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
