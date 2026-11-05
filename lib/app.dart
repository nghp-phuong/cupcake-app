import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/city/city_settings.dart';
import 'core/routes.dart';
import 'core/services/ad_service.dart';
import 'core/theme.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/sugarleaf/sugarleaf.dart';

/// Gốc app thành phố (docs/v3/city-gd2-spec.md §3): AppScope ở trên MaterialApp; locale = [forcedLocale] (tham số
/// `lang=`, chỉ trong phiên) hoặc theo `game.settings.language` (system → theo máy, fallback en).
///
/// Không bọc `RefFrame` / `SLScope` toàn app: cảnh 3D chiếm cả màn (khung tham chiếu làm ảnh mờ và vùng chạm nhỏ);
/// route 2D (cảnh mở đầu, gallery) tự bọc trong bảng route.
class SugarleafApp extends StatelessWidget {
  const SugarleafApp({
    super.key,
    required this.services,
    required this.onGenerateRoute,
    this.initialRoute = AppRoutes.town,
    this.forcedLocale,
    this.useGoogleFonts = true,
  });

  final AppServices services;
  final RouteFactory onGenerateRoute;

  /// Route đầu tiên (main.dart: cảnh mở đầu hoặc phố). Luôn là route DUY NHẤT của ngăn xếp khởi đầu: tên route do nền
  /// tảng gửi (đường dẫn trình duyệt, `--es route '/?…'` trên Android) bị bỏ qua.
  final String initialRoute;

  /// Ép ngôn ngữ trong phiên (không lưu); null = theo cài đặt.
  final Locale? forcedLocale;

  /// true: font đóng gói (Fredoka/Baloo 2/Nunito, xem AppTheme); test truyền false → font mặc định.
  final bool useGoogleFonts;

  static const supportedLocales = [Locale('en'), Locale('vi')];

  static Locale? localeFor(LanguagePref pref) => switch (pref) {
    LanguagePref.system => null,
    LanguagePref.en => const Locale('en'),
    LanguagePref.vi => const Locale('vi'),
  };

  static Locale resolveLocale(Locale? locale, Iterable<Locale> supported) {
    if (locale != null) {
      for (final s in supported) {
        if (s.languageCode == locale.languageCode) return s;
      }
    }
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      // Chỉ dựng lại MaterialApp khi đổi ngôn ngữ, không phải ở mọi thay đổi của cài đặt / ví.
      child: _LanguageBuilder(
        settings: services.game.settings,
        builder: (context, pref) {
          final locale = forcedLocale ?? localeFor(pref);
          return MaterialApp(
            onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (device, supported) =>
                resolveLocale(device, supported),
            theme: AppTheme.build(
              locale: locale ?? const Locale('en'),
              useGoogleFonts: useGoogleFonts,
            ),
            initialRoute: initialRoute,
            onGenerateRoute: onGenerateRoute,
            onGenerateInitialRoutes: _initialRoutes,
            // Theme theo locale thật đã phân giải (kể cả "theo máy") — builder nằm dưới Localizations.
            builder: (ctx, child) => Theme(
              data: AppTheme.build(
                locale: Localizations.localeOf(ctx),
                useGoogleFonts: useGoogleFonts,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }

  /// Ngăn xếp khởi đầu: chỉ [initialRoute], bỏ qua tên route nền tảng gửi.
  List<Route<dynamic>> _initialRoutes(String _) {
    final route = onGenerateRoute(RouteSettings(name: initialRoute));
    return [if (route != null) route];
  }
}

/// Gọi [builder] lại chỉ khi `settings.language` đổi.
class _LanguageBuilder extends StatefulWidget {
  const _LanguageBuilder({required this.settings, required this.builder});

  final CitySettings settings;
  final Widget Function(BuildContext context, LanguagePref pref) builder;

  @override
  State<_LanguageBuilder> createState() => _LanguageBuilderState();
}

class _LanguageBuilderState extends State<_LanguageBuilder> {
  late LanguagePref _pref = widget.settings.language;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
  }

  @override
  void didUpdateWidget(_LanguageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.removeListener(_onSettings);
      widget.settings.addListener(_onSettings);
      _pref = widget.settings.language;
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    final pref = widget.settings.language;
    if (pref != _pref) setState(() => _pref = pref);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _pref);
}

/// Quảng cáo giả lập kiểu vẽ tay (tiêm vào `FakeAdService(presenter: …)` ở main.dart): `showSLDialog` không đóng
/// được + [SLDialog]; đếm ngược/tự đóng/chặn Back vẫn do [SimulatedAdDialog] ở core.
Future<void> showSLSimulatedAd(BuildContext context, Duration duration) =>
    showSLDialog<void>(
      context,
      dismissible: false,
      builder: (_) =>
          SimulatedAdDialog(duration: duration, builder: _slSimulatedAdView),
    );

Widget _slSimulatedAdView(BuildContext context, int secondsLeft) {
  final l = AppLocalizations.of(context);
  final styles = SLTextStyles.of(context);
  return SLDialog(
    title: l.adSimulatedTitle,
    titleIcon: 'play_video',
    titleColor: SLColors.mint,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Màn hình" quảng cáo: tờ giấy bạc hà nhạt, nút phát vẽ tay ở giữa.
        SLPanel(
          color: SLColors.mintLight,
          radius: SLMetrics.radiusButton,
          padding: EdgeInsets.zero,
          seed: 0xAD,
          child: const SizedBox(
            width: 420,
            height: 150,
            child: Center(child: SLIcon('play_video', size: 88)),
          ),
        ),
        const SizedBox(height: 16),
        Text(l.adSimulatedBody, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          l.adSimulatedClosing(secondsLeft),
          style: styles.label.copyWith(color: SLColors.inkSoft, fontSize: 18),
        ),
      ],
    ),
  );
}
