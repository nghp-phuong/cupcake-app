import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/game_state.dart';
import 'core/models/ids.dart';
import 'core/ref_frame.dart';
import 'core/routes.dart';
import 'core/services/ad_service.dart';
import 'core/theme.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/sugarleaf/sugarleaf.dart';

/// Gốc app: AppScope ở trên MaterialApp; locale theo `state.language` (system → theo máy, fallback en);
/// mọi màn/dialog nằm trong `RefFrame` 1280×720, dưới `SLScope` (chữ mặc định: mực nâu + font nội dung).
class SugarleafApp extends StatelessWidget {
  const SugarleafApp({
    super.key,
    required this.services,
    required this.onGenerateRoute,
    this.useGoogleFonts = true,
    this.initialRoute = AppRoutes.menu,
  });

  final AppServices services;
  final RouteFactory onGenerateRoute;

  /// Route đầu tiên (main.dart: `AppRoutes.initialFor(introSeen: …)`). Cảnh mở đầu / intro ngắn là route DUY NHẤT trong
  /// ngăn xếp (bản đồ không dựng sẵn bên dưới — hộp lời chào / vắng nhà chỉ chạy khi vào bản đồ); liên kết sâu trên web
  /// (tên khác) → bản đồ + route đó. [initialRoute] khác intro: cách dựng mặc định của Navigator.
  final String initialRoute;

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
      // Chỉ dựng lại MaterialApp khi đổi ngôn ngữ, không phải ở mọi thay đổi của GameState.
      child: _LanguageBuilder(
        state: services.state,
        builder: (context, pref) {
          final locale = localeFor(pref);
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
            localeResolutionCallback: (device, supported) => resolveLocale(device, supported),
            theme: AppTheme.build(locale: locale ?? const Locale('en'), useGoogleFonts: useGoogleFonts),
            initialRoute: initialRoute,
            onGenerateRoute: onGenerateRoute,
            onGenerateInitialRoutes: AppRoutes.isIntro(initialRoute) ? _singleInitialRoute : null,
            // Theme theo locale thật đã phân giải (kể cả "theo máy") — builder nằm dưới Localizations.
            // SLScope dưới Theme để chữ không có Material phía trên (lời nhắc xoay máy, route trần) vẫn đúng kiểu.
            builder: (ctx, child) => Theme(
              data: AppTheme.build(locale: Localizations.localeOf(ctx), useGoogleFonts: useGoogleFonts),
              child: SLScope(child: RefFrame(child: child ?? const SizedBox.shrink())),
            ),
          );
        },
      ),
    );
  }
}

extension on SugarleafApp {
  /// Ngăn xếp khởi đầu khi app mở bằng cảnh mở đầu / intro ngắn. `/`, [AppRoutes.intro], [AppRoutes.shortIntro]: một
  /// route duy nhất (không chồng bản đồ bên dưới). Tên khác (liên kết sâu trên web, vd. `/settings` — trình duyệt thắng
  /// [initialRoute]): `[bản đồ, route đó]` để Back có chỗ về.
  List<Route<dynamic>> _singleInitialRoute(String name) {
    final route = onGenerateRoute(RouteSettings(name: name));
    if (name == AppRoutes.menu || AppRoutes.isIntro(name)) return [if (route != null) route];
    final menu = onGenerateRoute(const RouteSettings(name: AppRoutes.menu));
    return [if (menu != null) menu, if (route != null) route];
  }
}

/// Gọi [builder] lại chỉ khi `state.language` đổi.
class _LanguageBuilder extends StatefulWidget {
  const _LanguageBuilder({required this.state, required this.builder});

  final GameState state;
  final Widget Function(BuildContext context, LanguagePref pref) builder;

  @override
  State<_LanguageBuilder> createState() => _LanguageBuilderState();
}

class _LanguageBuilderState extends State<_LanguageBuilder> {
  late LanguagePref _pref = widget.state.language;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(_LanguageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onState);
      widget.state.addListener(_onState);
      _pref = widget.state.language;
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    final pref = widget.state.language;
    if (pref != _pref) setState(() => _pref = pref);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _pref);
}

/// Quảng cáo giả lập kiểu vẽ tay (tiêm vào `FakeAdService(presenter: …)` ở main.dart): `showSLDialog` không đóng
/// được + [SLDialog]; đếm ngược/tự đóng/chặn Back vẫn do [SimulatedAdDialog] ở core.
Future<void> showSLSimulatedAd(BuildContext context, Duration duration) => showSLDialog<void>(
      context,
      dismissible: false,
      builder: (_) => SimulatedAdDialog(duration: duration, builder: _slSimulatedAdView),
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
          child: const SizedBox(width: 420, height: 150, child: Center(child: SLIcon('play_video', size: 88))),
        ),
        const SizedBox(height: 16),
        Text(l.adSimulatedBody, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(l.adSimulatedClosing(secondsLeft), style: styles.label.copyWith(color: SLColors.inkSoft, fontSize: 18)),
      ],
    ),
  );
}
