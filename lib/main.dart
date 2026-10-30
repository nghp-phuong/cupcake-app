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
import 'core/level/level_config_loader.dart';
import 'core/routes.dart';
import 'core/save_repository.dart';
import 'core/services/ad_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/iap_service.dart';
import 'core/unlock/unlock_config_loader.dart';
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
  // Bản lưu, dữ liệu level, mở khoá và kiếm tiền nạp song song (đều bất đồng bộ). levels.json / unlocks.json /
  // monetization.json lỗi → cấu hình rỗng / dự phòng, app vẫn chạy.
  final (state, levels, unlocks, monetization) = await (
    GameState.load(saves),
    LevelConfigLoader.loadOrEmpty(rootBundle),
    UnlockConfigLoader.loadOrEmpty(rootBundle),
    MonetizationConfigLoader.loadOrEmpty(rootBundle),
  ).wait;
  // Quy tắc mở level/chương, món mở khoá theo levels.json; mở rộng tiệm + thiết bị theo unlocks.json (cấu hình rỗng
  // vẫn chạy được).
  state.attachLevelConfig(levels);
  state.attachUnlockConfig(unlocks);
  // Vật phẩm hỗ trợ, thẻ mùa (hết / đổi mùa → tự nhận thưởng chờ, `state.seasonAutoClaim`), gói IAP giả lập.
  state.attachMonetizationConfig(monetization);
  state.attachAutosave(saves);
  // Thu nhập khi vắng nhà (quản lý): tính sau khi đã gắn config; UI đọc `state.pendingOffline`.
  state.refreshOffline(DateTime.now());
  // Đang ở foreground: ghi mốc hoạt động mỗi phút (app bị tắt lúc đang mở → thời gian đang chơi không tính là vắng).
  state.startActiveHeartbeat();

  final services = AppServices(
    state: state,
    saves: saves,
    ads: FakeAdService(state, presenter: showSLSimulatedAd),
    iap: FakeIapService(state),
    audio: FakeAudioService(state),
    levels: levels,
    unlocks: unlocks,
    monetization: monetization,
  );

  // Inactive/ẩn/tạm dừng: ghi mốc hoạt động (ẩn/tạm dừng thì lưu ngay — không chặn UI: flush chạy bất đồng bộ) và tắt
  // nhịp ghi mốc. Quay lại: tính thu nhập khi vắng nhà (bản đồ hiện hộp "Khi bạn vắng nhà" khi
  // `pendingOffline != null`) rồi bật lại nhịp.
  // onHide/onShow chỉ chạy khi thật sự vào/ra nền (kéo thanh thông báo chỉ qua `inactive`, không tính là vắng).
  AppLifecycleListener(
    onInactive: state.markActive,
    onHide: () {
      state.stopActiveHeartbeat();
      state.markActive();
      unawaited(state.flush());
    },
    onPause: () {
      state.markActive();
      unawaited(state.flush());
    },
    onShow: () {
      state.refreshOffline(DateTime.now());
      state.startActiveHeartbeat();
    },
  );

  runApp(SugarleafApp(
    services: services,
    onGenerateRoute: onGenerateUiRoute,
    // Lần đầu: cảnh mở đầu → L1 (hướng dẫn); các lần sau: intro ngắn → bản đồ.
    initialRoute: AppRoutes.initialFor(introSeen: state.introSeen),
  ));

  // Nạp sẵn ảnh dàn nhân vật cố định sau khi app đã chạy (bất đồng bộ, không chặn khung hình đầu).
  unawaited(CustomerArt.preloadCast());
  // Đồ hoạ dùng nhiều (nền menu, vật phẩm, bánh) rồi icon giao diện vẽ tay: nạp nối tiếp sau frame đầu;
  // cảnh/trạm bếp nạp khi cần.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(ArtSprites.preloadStartup().then((_) => ArtSprites.preloadIcons())),
  );
}
