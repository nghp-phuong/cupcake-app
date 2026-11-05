/// Tên route của app thành phố (docs/v3/city-gd2-spec.md §3). Bảng route: `cityRouteFactory` (lib/ui/city_routes.dart).
abstract final class AppRoutes {
  /// Phố 3D (màn chính).
  static const town = '/';

  /// Cảnh mở đầu 2D (lần đầu mở app) → phố.
  static const intro = '/intro';

  /// Route khi mở app: chưa xem cảnh mở đầu → [intro], đã xem → [town].
  static String initialFor({required bool introSeen}) =>
      introSeen ? town : intro;
}
