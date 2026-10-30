import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';

import 'ui_test_helpers.dart';

/// Cửa hàng V2 (giả lập). Các gói V2 / gói khởi đầu / ẩn gói V1: xem `phase6_test.dart`.
GameState _englishState() => GameState.newGame()
  ..setLanguage(LanguagePref.en)
  ..claimLogin();

Finder _buyOn(IapProductId id) =>
    find.descendant(of: find.byKey(ValueKey('store-product-${id.name}')), matching: find.text('Buy'));

void main() {
  testWidgets('cửa hàng: thông báo thử nghiệm, xác nhận mua giả lập, huỷ thì không mua', (tester) async {
    final state = _englishState();
    await pumpSugarApp(tester, state);
    navigator(tester).pushNamed(AppRoutes.store);
    await tester.pumpAndSettle();

    expect(find.text('Test store: purchases are simulated and no money is charged.'), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
    final gemsBefore = state.gems;

    // Huỷ xác nhận → không mua.
    await tester.tap(_buyOn(IapProductId.gemsM));
    await tester.pumpAndSettle();
    expect(find.text('Simulated purchase'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.gems, gemsBefore);

    // Mua gói kim cương M: +450, mua lại được (tiêu hao).
    for (var i = 1; i <= 2; i++) {
      await tester.tap(_buyOn(IapProductId.gemsM));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy').last);
      await tester.pumpAndSettle();
      expect(state.gems, gemsBefore + 450 * i);
      expect(find.text('Thank you! Your items have been added.'), findsOneWidget);
      await settleToasts(tester);
    }

    // Bỏ quảng cáo (một lần) → "Owned".
    await tester.tap(_buyOn(IapProductId.removeAds));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy').last);
    await tester.pumpAndSettle();
    expect(state.removeAds, isTrue);
    expect(find.text('Owned'), findsOneWidget);
    await settleToasts(tester);
    expect(tester.takeException(), isNull);
  });
}
