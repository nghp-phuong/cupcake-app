import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

/// Dựng [children] trong `Stack` phủ màn 1280×720 (như lớp phủ cảnh 3D), ngôn ngữ [locale].
Future<void> pumpTown(
  WidgetTester tester,
  List<Widget> children, {
  String locale = 'en',
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Stack(children: children)),
    ),
  );
}

/// Chuỗi l10n của [locale] (để so với chữ trên màn hình).
Future<AppLocalizations> l10n(String locale) =>
    AppLocalizations.delegate.load(Locale(locale));
