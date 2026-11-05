import 'package:flutter/widgets.dart';

import 'city/city_game.dart';
import 'debug_params.dart';
import 'save/city_save_store.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';

/// Gói các dịch vụ dùng chung của app.
class AppServices {
  AppServices({
    required this.game,
    required this.store,
    required this.ads,
    required this.audio,
    this.debug = CityDebugParams.none,
  });

  /// Trạng thái thành phố (ví, cài đặt, cờ); `store` tự lưu khi nó đổi.
  final CityGame game;
  final CitySaveStore store;
  final AdService ads;
  final AudioService audio;

  /// Tham số chạy thử của phiên (URL / route ban đầu).
  final CityDebugParams debug;
}

/// Đưa [AppServices] xuống cây widget. Không nghe [CityGame]: màn cần dựng lại theo ví / cài đặt thì tự nghe
/// (`ListenableBuilder`).
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  /// Dựng lại khi [services] đổi (thực tế không đổi trong phiên).
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
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
