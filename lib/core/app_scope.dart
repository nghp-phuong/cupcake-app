import 'package:flutter/widgets.dart';

import 'game_state.dart';
import 'save_repository.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';

/// Gói các dịch vụ dùng chung của app.
class AppServices {
  AppServices({required this.state, required this.saves, required this.ads, required this.iap, required this.audio});

  final GameState state;
  final SaveRepository saves;
  final AdService ads;
  final IapService iap;
  final AudioService audio;
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
