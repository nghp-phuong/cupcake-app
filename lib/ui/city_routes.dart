import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ref_frame.dart';
import '../core/routes.dart';
import 'intro/intro_screen.dart';
import 'sugarleaf/gallery/ui_gallery_screen.dart';
import 'sugarleaf/sugarleaf.dart';

/// Route chỉ có trong bản debug.
abstract final class UiDebugRoutes {
  /// Màn trình bày bộ design system SL* (`UiGalleryScreen`).
  static const gallery = '/debug/ui-gallery';
}

/// Bảng route của app (nối vào `SugarleafApp.onGenerateRoute`).
///
/// - [AppRoutes.town] → [town] (phố 3D), không bọc [RefFrame] / [SLScope]: cảnh 3D chiếm cả màn, bảng 2D trong phố
///   tự lo khung của mình.
/// - [AppRoutes.intro] → cảnh mở đầu 2D trong [SLScope] + [RefFrame] (xong → phố).
/// - [UiDebugRoutes.gallery] chỉ khi `kDebugMode`.
/// - Tên lạ (liên kết sâu trên web, route do nền tảng gửi) → phố.
RouteFactory cityRouteFactory({required WidgetBuilder town}) {
  return (RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.intro:
        return fadeRoute(
          settings,
          const RefFrame(child: IntroScreen()),
          wide: true,
        );
      case UiDebugRoutes.gallery when kDebugMode:
        return fadeRoute(
          settings,
          const RefFrame(child: RefCenter(child: UiGalleryScreen())),
          wide: true,
        );
    }
    // Phố giữ tên `/` kể cả khi vào bằng tên lạ, để Navigator không dựng hai phố chồng nhau.
    return PageRouteBuilder<void>(
      settings: settings.name == AppRoutes.town
          ? settings
          : const RouteSettings(name: AppRoutes.town),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => town(context),
      transitionsBuilder: _fade,
    );
  };
}

Widget _fade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(
  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
  child: child,
);

/// Route mờ dần 280ms. Trang được bọc [SLScope] (chữ mực nâu + font nội dung) để màn không còn `Scaffold`/`Material`
/// vẫn đúng kiểu chữ.
///
/// Khung rộng (máy 20:9, W > 1280): [wide] = true → trang nhận cả khung W×720 (màn đã tự trải nền tới mép, bám mép
/// theo `MediaQuery.padding`, đặt nội dung giữa); false → trang đặt trong vùng 1280×720 giữa ([RefCenter]), hai bên
/// nền kem. Khung 1280 → hai cách như nhau.
PageRoute<void> fadeRoute(
  RouteSettings settings,
  Widget page, {
  bool wide = false,
}) => PageRouteBuilder<void>(
  settings: settings,
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, animation, secondaryAnimation) =>
      SLScope(child: wide ? page : RefCenter(child: page)),
  transitionsBuilder: _fade,
);
