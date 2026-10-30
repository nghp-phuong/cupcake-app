import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/art/art_sprites.dart';
import '../core/routes.dart';
import 'decor/decor_screen.dart';
import 'intro/intro_screen.dart';
import 'intro/short_intro_screen.dart';
import 'level/level_common.dart';
import 'level/level_result_screen.dart';
import 'level/level_screen.dart';
import 'map/level_map_screen.dart';
import 'recipes/recipe_book_screen.dart';
import 'season/season_pass_screen.dart';
import 'settings/settings_screen.dart';
import 'store/store_screen.dart';
import 'sugarleaf/gallery/ui_gallery_screen.dart';
import 'sugarleaf/sugarleaf.dart';
import 'upgrades/upgrades_screen.dart';

/// Route riêng của tầng giao diện (không cần ở `AppRoutes` của core).
abstract final class UiRoutes {
  /// Màn Thẻ mùa (`SeasonPassScreen`), mở từ nút trên thanh bản đồ.
  static const season = '/season';
}

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
    AppRoutes.menu => const LevelMapScreen(),
    // Cảnh mở đầu: route đầu tiên khi chưa xem (xong → L1) hoặc mở lại từ Cài đặt (xong → quay về).
    AppRoutes.intro => const IntroScreen(),
    // Intro ngắn: route đầu tiên các lần mở sau (xong → bản đồ).
    AppRoutes.shortIntro => const ShortIntroScreen(),
    // Danh sách level tạm của GĐ1 (đã bỏ): đường dẫn cũ chuyển về bản đồ.
    AppRoutes.levels => const LevelRedirect(),
    AppRoutes.level => switch (settings.arguments) {
      LevelArgs(:final levelId) => LevelScreen(levelId: levelId),
      _ => const LevelRedirect(),
    },
    AppRoutes.levelResult => switch (settings.arguments) {
      LevelResultArgs(:final result, :final progress) => LevelResultScreen(result: result, progress: progress),
      // Thiếu kết quả (vd. mở thẳng đường dẫn trên web) → bản đồ.
      _ => const LevelRedirect(),
    },
    AppRoutes.upgrades => switch (settings.arguments) {
      UpgradesArgs(:final tab, :final focus) => UpgradesScreen(initialTab: tab, focus: focus),
      _ => const UpgradesScreen(),
    },
    AppRoutes.decor => const DecorScreen(),
    AppRoutes.recipes => const RecipeBookScreen(),
    AppRoutes.store => const StoreScreen(),
    AppRoutes.settings => const SettingsScreen(),
    UiRoutes.season => const SeasonPassScreen(),
    UiDebugRoutes.gallery when kDebugMode => const UiGalleryScreen(),
    // Tuyến lạ (vd. `/day` của V1, đường dẫn gõ tay trên web) → về bản đồ có sẵn, không dựng thêm bản đồ chồng lên.
    _ => const LevelRedirect(),
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
