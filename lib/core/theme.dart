import 'package:flutter/material.dart';

import 'constants.dart';

/// Theme chung. Tiêu đề: Fredoka (en) / Baloo 2 (vi — Fredoka thiếu dấu tiếng Việt); nội dung: Nunito.
///
/// Font đóng gói sẵn ở `assets/fonts/` (khai báo `fonts:` trong pubspec), không tải qua mạng lúc chạy.
/// Màn hình lấy font từ `Theme.of(context).textTheme` (titleLarge / headline* / display* = tiêu đề, còn lại = nội
/// dung); canvas/painter dùng [titleFontFamily] / [bodyFontFamily].
abstract final class AppTheme {
  /// Bo góc nút (đặc tả 16–20px).
  static const double buttonRadius = 18;

  /// Viền nâu 2px.
  static const BorderSide border = BorderSide(color: AppColors.caramel, width: 2);

  /// Bóng mềm: blur 8, offset (0,3), alpha 0.15.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x265A3E36), blurRadius: 8, offset: Offset(0, 3)),
  ];

  /// Khung nút/thẻ chuẩn (nền tuỳ chọn) — dùng cho widget tự vẽ.
  static BoxDecoration panelDecoration({Color color = Colors.white, double radius = buttonRadius}) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(border),
        boxShadow: softShadow,
      );

  /// Họ font đóng gói (tên `family` trong pubspec). Có sẵn các độ đậm: Fredoka 500/600/700,
  /// Baloo 2 600/700/800, Nunito 400/600/700/800 — độ đậm khác sẽ lấy file gần nhất.
  static const fredoka = 'Fredoka';
  static const baloo2 = 'Baloo2';
  static const nunito = 'Nunito';

  /// Độ đậm mặc định của tiêu đề trong textTheme.
  static const FontWeight titleWeight = FontWeight.w600;

  /// Họ font tiêu đề theo ngôn ngữ (vi → Baloo 2, còn lại → Fredoka); null khi [useGoogleFonts] = false (test).
  static String? titleFontFamily(Locale locale, {bool useGoogleFonts = true}) =>
      useGoogleFonts ? (locale.languageCode == 'vi' ? baloo2 : fredoka) : null;

  /// Họ font nội dung (Nunito, đủ dấu tiếng Việt); null khi [useGoogleFonts] = false (test).
  static String? bodyFontFamily({bool useGoogleFonts = true}) => useGoogleFonts ? nunito : null;

  /// Font dự phòng theo từng ký tự cho tiêu đề: Fredoka thiếu dấu tiếng Việt (vd. tên "Hòa" trong bản en).
  static List<String>? titleFontFallback(Locale locale, {bool useGoogleFonts = true}) =>
      useGoogleFonts ? (locale.languageCode == 'vi' ? const [nunito] : const [baloo2, nunito]) : null;

  static final Map<String, ThemeData> _cache = {};

  /// [useGoogleFonts] = true: dùng font đóng gói (tên giữ để tương thích); test truyền false → font mặc định.
  static ThemeData build({required Locale locale, bool useGoogleFonts = true}) {
    final vi = locale.languageCode == 'vi';
    return _cache.putIfAbsent('${vi ? 'vi' : 'en'}|$useGoogleFonts', () => _build(vi: vi, useGoogleFonts: useGoogleFonts));
  }

  static ThemeData _build({required bool vi, required bool useGoogleFonts}) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.strawberry,
      onPrimary: AppColors.chocolate,
      secondary: AppColors.mint,
      onSecondary: AppColors.chocolate,
      tertiary: AppColors.butter,
      onTertiary: AppColors.chocolate,
      error: AppColors.bad,
      onError: Colors.white,
      surface: AppColors.cream,
      onSurface: AppColors.chocolate,
      outline: AppColors.caramel,
    );

    var text = Typography.material2021().black.apply(
          bodyColor: AppColors.chocolate,
          displayColor: AppColors.chocolate,
        );
    if (useGoogleFonts) {
      final locale = Locale(vi ? 'vi' : 'en');
      final title = titleFontFamily(locale)!;
      final fallback = titleFontFallback(locale);
      text = text.apply(fontFamily: nunito);
      TextStyle? heading(TextStyle? s) => s?.copyWith(fontFamily: title, fontFamilyFallback: fallback, fontWeight: titleWeight);
      // Nunito không có w500 (mặc định của title/label M3) → dùng w600 cho rõ ràng.
      TextStyle? semi(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w600);
      text = text.copyWith(
        displayLarge: heading(text.displayLarge),
        displayMedium: heading(text.displayMedium),
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
        titleMedium: semi(text.titleMedium),
        titleSmall: semi(text.titleSmall),
        labelMedium: semi(text.labelMedium),
        labelSmall: semi(text.labelSmall),
      );
    } else {
      const w = FontWeight.w800;
      text = text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontWeight: w),
        displayMedium: text.displayMedium?.copyWith(fontWeight: w),
        displaySmall: text.displaySmall?.copyWith(fontWeight: w),
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: w),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: w),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: w),
        titleLarge: text.titleLarge?.copyWith(fontWeight: w),
      );
    }
    text = text.copyWith(
      labelLarge: text.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 16),
    );

    // Giao diện vẽ tay (lib/ui/sugarleaf): không gợn sóng mực, không lớp phủ khi nhấn/rê — nút SL* tự lún xuống.
    // Không còn theme cho nút / SnackBar / Divider / Dialog / Card Material: mọi màn đã dùng bộ SL* tự vẽ.
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: const IconThemeData(color: AppColors.chocolate),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.good,
        linearTrackColor: Color(0xFFEADBC8),
      ),
    );
  }
}
