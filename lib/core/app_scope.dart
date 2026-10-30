import 'package:flutter/widgets.dart';

import 'game_state.dart';
import 'level/level_data.dart';
import 'save_repository.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';

/// Gói các dịch vụ dùng chung của app.
class AppServices {
  AppServices({
    required this.state,
    required this.saves,
    required this.ads,
    required this.iap,
    required this.audio,
    required this.levels,
    UnlockConfig? unlocks,
    MonetizationConfig? monetization,
  })  : unlocks = unlocks ?? state.unlockConfig,
        monetization = monetization ?? state.monetizationConfig {
    // Một nguồn dữ liệu level / mở khoá: GameState tính tiến trình theo đúng cấu hình app đang dùng (main.dart đã gắn
    // sẵn → không làm gì; test dựng AppServices thì tự gắn).
    state.attachLevelConfig(levels);
    state.attachUnlockConfig(this.unlocks);
    state.attachMonetizationConfig(this.monetization);
  }

  final GameState state;
  final SaveRepository saves;
  final AdService ads;
  final IapService iap;
  final AudioService audio;

  /// Dữ liệu level (assets/config/levels.json), nạp một lần lúc khởi động.
  final LevelConfig levels;

  /// Mở rộng tiệm + thiết bị (assets/config/unlocks.json), nạp cùng lúc với [levels]. Không truyền → cấu hình
  /// GameState đang gắn (mặc định rỗng: không có mở rộng, lò/dụng cụ V1 theo bảng dự phòng).
  final UnlockConfig unlocks;

  /// Vật phẩm hỗ trợ, thẻ mùa, gói IAP (assets/config/monetization.json). Không truyền → cấu hình GameState đang gắn
  /// (mặc định: giá vật phẩm dự phòng, không có thẻ mùa, cửa hàng theo `IapCatalog.v2`).
  final MonetizationConfig monetization;
}

/// Đưa `AppServices` xuống cây widget; widget dùng `of` sẽ dựng lại khi GameState đổi.
class AppScope extends InheritedNotifier<GameState> {
  AppScope({super.key, required this.services, required super.child}) : super(notifier: services.state);

  final AppServices services;

  /// Lắng nghe GameState.
  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Không tìm thấy AppScope phía trên context');
    return scope!.services;
  }

  /// Không lắng nghe.
  static AppServices read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Không tìm thấy AppScope phía trên context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) => oldWidget.services != services || super.updateShouldNotify(oldWidget);
}
