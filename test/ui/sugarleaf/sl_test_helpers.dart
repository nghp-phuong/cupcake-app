import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/app.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

const kEn = Locale('en');
const kVi = Locale('vi');

/// Dựng [child] (nhận context có AppLocalizations) trong MaterialApp 1280×720, nền kem, có SLScope.
/// Font test của Flutter rộng hơn font thật (mỗi ký tự = một ô vuông cỡ chữ) → kiểm tràn khắt khe hơn thật.
Future<void> pumpSL(
  WidgetTester tester,
  WidgetBuilder child, {
  Locale locale = kEn,
  bool reduceMotion = false,
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: SugarleafApp.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(locale: locale, useGoogleFonts: false),
      builder: (ctx, c) => MediaQuery(data: MediaQuery.of(ctx).copyWith(disableAnimations: reduceMotion), child: c!),
      home: Builder(builder: (ctx) => SLScope(child: ColoredBox(color: SLColors.cream, child: child(ctx)))),
    ),
  );
  await tester.pump();
}
