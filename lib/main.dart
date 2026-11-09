// Sugarleaf Bakery V3 — thành phố (docs/v3/city-gd2-spec.md §3): lần đầu chạy cảnh mở đầu 2D rồi vào phố 3D; các lần
// sau vào thẳng phố. Save v3 (`sugarleaf_save_v3`), lần đầu nhập cài đặt từ save v2 (khoá v2 chỉ đọc).
//
// Chạy: flutter run -d chrome --cross-origin-isolation          (máy chủ tĩnh của bản web phải gửi COOP / COEP)
//       flutter build web --release / flutter build apk --debug
// Tham số URL (web) / route ban đầu (Android, `--es route '/?…'`), xem `CityDebugParams`:
//   save=memory (không đụng save thật; có coins= / xp= / level= / day= / branches= / staff= / till= / away= thì tự
//   bật); chi nhánh branches=s1:3,s3:1, staff=ami@s1, till=full, away=<giờ>; intro=0|1; lang=vi|en (chỉ trong phiên);
//   spawn=<x>,<z>; debug=1|0; log=1; mochi=1; đồ hoạ quality, scale, fps, shadows, smap, post, aa, blob, soft, ibl, tm,
//   maxpx; ánh sáng sun / amb / fill / sky=<RRGGBB>, ambi=<n>; tex=producer (Android).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thermion_flutter/thermion_flutter.dart'
    hide Material, Texture, View;

import 'app.dart';
import 'core/app_scope.dart';
import 'core/debug_params.dart';
import 'core/routes.dart';
import 'core/save/city_save_repository.dart';
import 'core/save/city_save_store.dart';
import 'core/services/ad_service.dart';
import 'core/services/audio_service.dart';
import 'game/town3d/town3d_page.dart';
import 'ui/city_routes.dart';
import 'ui/intro/intro_screen.dart';
import 'ui/intro/intro_stage3d.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Font đóng gói sẵn ở assets/fonts/ (pubspec `fonts:`); cấm google_fonts tải qua mạng — kể cả bản debug, để
  // thiếu file là thấy lỗi ngay thay vì âm thầm tải về.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const [
      'Fredoka',
      'Baloo 2',
      'Nunito',
    ], license);
  });
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Game toàn màn: ẩn thanh trạng thái + điều hướng; vuốt mép màn hiện tạm rồi tự ẩn.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final debug = CityDebugParams.fromPlatform();
  if (debug.raw['tex'] case final tex?) {
    ThermionFlutterPlugin.instance.setOptions(
      ThermionFlutterOptions(
        nativeOptions: NativeOptions(
          androidTextureSource: tex == 'producer'
              ? AndroidTextureSource.surfaceProducer
              : AndroidTextureSource.surfaceTexture,
        ),
      ),
    );
  }

  // Nạp save (bất đồng bộ; nhập từ v2 thì ghi v3 xong ở đây, trước runApp). Tham số xu / XP chỉ áp khi lưu trong bộ
  // nhớ, không bao giờ vào save thật.
  final CitySaveRepository repo = debug.memorySave
      ? MemoryCitySaveRepository()
      : PrefsCitySaveRepository();
  final store = await CitySaveStore.load(repo);
  final game = store.game;
  debug.applyTo(game);
  game.resume();
  store.attachAutosave();

  final services = AppServices(
    game: game,
    store: store,
    ads: FakeAdService(game, presenter: showSLSimulatedAd),
    audio: FakeAudioService(game.settings),
    debug: debug,
  );

  // Ẩn / tạm dừng: lưu ngay (bất đồng bộ, không chặn UI). Quay lại: kiểm ngày lịch (sang ngày mới → bộ đếm ăn, quảng
  // cáo thưởng đặt lại) và bù két chi nhánh theo giờ máy (phố lấy kết quả qua `branches.takeAway()`).
  AppLifecycleListener(
    onHide: () => unawaited(store.flush()),
    onPause: () => unawaited(store.flush()),
    onShow: game.resume,
  );

  // Intro: cảnh 3D (Mai + phố) do lớp thermion dựng; không gắn thì intro chạy trên nền giấy.
  IntroScreen.stageBuilder = IntroStage3d.new;

  runApp(
    SugarleafApp(
      services: services,
      onGenerateRoute: cityRouteFactory(
        town: (_) => Town3dPage(game: game, store: store, debug: debug),
      ),
      initialRoute: (debug.intro ?? !game.introSeen)
          ? AppRoutes.intro
          : AppRoutes.town,
      forcedLocale: debug.locale,
    ),
  );
}
