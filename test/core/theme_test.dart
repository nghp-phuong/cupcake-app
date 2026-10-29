import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/theme.dart';

void main() {
  const en = Locale('en');
  const vi = Locale('vi');

  test('tiêu đề theo ngôn ngữ (Fredoka / Baloo 2), nội dung Nunito', () {
    for (final (locale, title) in [(en, AppTheme.fredoka), (vi, AppTheme.baloo2)]) {
      final t = AppTheme.build(locale: locale).textTheme;
      for (final s in [t.displayLarge, t.displayMedium, t.displaySmall, t.headlineLarge, t.headlineMedium, t.headlineSmall, t.titleLarge]) {
        expect(s!.fontFamily, title, reason: '$locale');
        expect(s.fontWeight, AppTheme.titleWeight);
        expect(s.fontFamilyFallback, AppTheme.titleFontFallback(locale));
      }
      for (final s in [t.titleMedium, t.titleSmall, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall]) {
        expect(s!.fontFamily, AppTheme.nunito, reason: '$locale');
      }
      expect(AppTheme.titleFontFamily(locale), title);
    }
    expect(AppTheme.titleFontFallback(en), contains(AppTheme.baloo2)); // Fredoka thiếu dấu tiếng Việt.
    expect(AppTheme.bodyFontFamily(), AppTheme.nunito);
  });

  test('useGoogleFonts=false (test): không đặt họ font đóng gói', () {
    expect(AppTheme.titleFontFamily(vi, useGoogleFonts: false), isNull);
    expect(AppTheme.bodyFontFamily(useGoogleFonts: false), isNull);
    expect(AppTheme.titleFontFallback(en, useGoogleFonts: false), isNull);
    final t = AppTheme.build(locale: vi, useGoogleFonts: false).textTheme;
    for (final s in [t.titleLarge, t.bodyMedium]) {
      expect([AppTheme.fredoka, AppTheme.baloo2, AppTheme.nunito], isNot(contains(s!.fontFamily)));
    }
  });

  test('file font đóng gói: có trên đĩa, khai báo trong pubspec, có giấy phép OFL', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/fonts/\n'));
    const files = {
      AppTheme.fredoka: ['Medium', 'SemiBold', 'Bold'],
      AppTheme.baloo2: ['SemiBold', 'Bold', 'ExtraBold'],
      AppTheme.nunito: ['Regular', 'SemiBold', 'Bold', 'ExtraBold'],
    };
    for (final MapEntry(key: family, value: weights) in files.entries) {
      expect(pubspec, contains('- family: $family\n'));
      for (final w in weights) {
        final path = 'assets/fonts/$family-$w.ttf';
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(pubspec, contains('- asset: $path\n'), reason: path);
      }
    }
    final ofl = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(ofl, contains('SIL Open Font License'));
    for (final project in ['Fredoka', 'Baloo 2', 'Nunito']) {
      expect(ofl, contains('The $project Project Authors'));
    }
  });
}
