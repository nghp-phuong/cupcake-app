import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/art/art_sprites.dart';
import '../core/routes.dart';
import 'day/day_screen.dart';
import 'decor/decor_screen.dart';
import 'menu/main_menu_screen.dart';
import 'recipes/recipe_book_screen.dart';
import 'settings/settings_screen.dart';
import 'store/store_screen.dart';
import 'sugarleaf/gallery/ui_gallery_screen.dart';
import 'sugarleaf/sugarleaf.dart';
import 'summary/day_summary_screen.dart';
import 'upgrades/upgrades_screen.dart';

/// Route chỉ có trong bản debug.
abstract final class UiDebugRoutes {
  /// Màn trình bày bộ design system SL* (`UiGalleryScreen`).
  static const gallery = '/debug/ui-gallery';
}

/// Đã xin nạp icon giao diện vẽ tay chưa (một lần cho cả phiên).
bool _iconsRequested = false;

/// Bảng route của app (nối vào `SugarleafApp.onGenerateRoute`). Chuyển màn bằng hiệu ứng mờ dần.
Route<dynamic>? onGenerateUiRoute(RouteSettings settings) {
  if (!_iconsRequested) {
    _iconsRequested = true;
    // Màn đầu tiên dùng icon vẽ tay: nạp nền (không chờ, không chặn UI); nhóm chưa có ảnh → xong ngay.
    ArtSprites.preloadIcons();
  }
  final Widget page = switch (settings.name) {
    AppRoutes.day => const DayScreen(),
    AppRoutes.summary => switch (settings.arguments) {
      DaySummaryArgs(:final summary) => DaySummaryScreen(summary: summary),
      // Thiếu tổng kết (vd. mở thẳng đường dẫn trên web) → về menu.
      _ => const MainMenuScreen(),
    },
    AppRoutes.upgrades => const UpgradesScreen(),
    AppRoutes.decor => const DecorScreen(),
    AppRoutes.recipes => const RecipeBookScreen(),
    AppRoutes.store => const StoreScreen(),
    AppRoutes.settings => const SettingsScreen(),
    UiDebugRoutes.gallery when kDebugMode => const UiGalleryScreen(),
    _ => const MainMenuScreen(),
  };
  return fadeRoute(settings, page);
}

/// Route mờ dần 280ms (dùng chung cho mọi màn). Trang được bọc [SLScope] (chữ mực nâu + font nội dung) để màn
/// không còn `Scaffold`/`Material` vẫn đúng kiểu chữ.
PageRoute<void> fadeRoute(RouteSettings settings, Widget page) => PageRouteBuilder<void>(
  settings: settings,
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, animation, secondaryAnimation) => SLScope(child: page),
  transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);
