import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/art/art_sprites.dart';
import 'core/art/customer_art.dart';
import 'core/game_state.dart';
import 'core/save_repository.dart';
import 'core/services/ad_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/iap_service.dart';
import 'ui/ui_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Font đóng gói sẵn ở assets/fonts/ (pubspec `fonts:`); cấm google_fonts tải qua mạng — kể cả bản debug, để
  // thiếu file là thấy lỗi ngay thay vì âm thầm tải về.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Fredoka', 'Baloo 2', 'Nunito'], license);
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  final saves = PrefsSaveRepository();
  final state = await GameState.load(saves);
  state.attachAutosave(saves);

  final services = AppServices(
    state: state,
    saves: saves,
    ads: FakeAdService(state, presenter: showSLSimulatedAd),
    iap: FakeIapService(state),
    audio: FakeAudioService(state),
  );

  // Lưu ngay khi app bị ẩn/tạm dừng (không chặn UI: flush chạy bất đồng bộ).
  AppLifecycleListener(
    onStateChange: (s) {
      if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) unawaited(state.flush());
    },
  );

  runApp(SugarleafApp(services: services, onGenerateRoute: onGenerateUiRoute));

  // Nạp sẵn ảnh dàn nhân vật cố định sau khi app đã chạy (bất đồng bộ, không chặn khung hình đầu).
  unawaited(CustomerArt.preloadCast());
  // Đồ hoạ dùng nhiều (nền menu, vật phẩm, bánh) rồi icon giao diện vẽ tay: nạp nối tiếp sau frame đầu;
  // cảnh/trạm bếp nạp khi cần.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(ArtSprites.preloadStartup().then((_) => ArtSprites.preloadIcons())),
  );
}
