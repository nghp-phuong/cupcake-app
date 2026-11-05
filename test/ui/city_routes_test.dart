import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/ui/city_routes.dart';
import 'package:sugarleaf_bakery/ui/intro/intro_screen.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/gallery/ui_gallery_screen.dart';

import 'city_test_helpers.dart';

/// Route của phố 2D/3D (`cityRouteFactory`) với phố giả: `/` không khung, `/intro` trong RefFrame, tên lạ → phố.

Future<void> _pump(WidgetTester tester, String route) async {
  await pumpCityApp(tester, await cityServices(), initialRoute: route);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('"/" → phố, không bọc RefFrame', (tester) async {
    await _pump(tester, AppRoutes.town);
    expect(find.byKey(kTownStubKey), findsOneWidget);
    expect(find.byType(RefFrame), findsNothing);
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('"/intro" → cảnh mở đầu trong RefFrame', (tester) async {
    await _pump(tester, AppRoutes.intro);
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(IntroScreen),
        matching: find.byType(RefFrame),
      ),
      findsOneWidget,
    );
    expect(find.byKey(kTownStubKey), findsNothing);
    await tester.tap(find.byKey(const ValueKey('intro-skip')));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tên lạ (vd. "/level", "/day") → phố, tên route thành "/"', (
    tester,
  ) async {
    for (final name in ['/level', '/day', '/settings', '/store']) {
      await _pump(tester, name);
      expect(find.byKey(kTownStubKey), findsOneWidget, reason: name);
      expect(find.byType(IntroScreen), findsNothing, reason: name);
      final route = ModalRoute.of(tester.element(find.byKey(kTownStubKey)));
      expect(route?.settings.name, AppRoutes.town, reason: name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('"/debug/ui-gallery" chỉ có khi kDebugMode', (tester) async {
    await _pump(tester, UiDebugRoutes.gallery);
    if (kDebugMode) {
      expect(find.byType(UiGalleryScreen), findsOneWidget);
    } else {
      expect(find.byType(UiGalleryScreen), findsNothing);
      expect(find.byKey(kTownStubKey), findsOneWidget);
    }
  });
}
