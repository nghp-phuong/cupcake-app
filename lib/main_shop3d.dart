// Bản chạy thử V3: mở thẳng cảnh tiệm bánh 3D (Thermion) với camera 360°, nhân vật 3D chibi dựng bằng code đi lại
// theo kịch bản (khách Linh / ông Hòa / Kenji / bà Rosa đi vòng cửa → hàng chờ → quầy → bàn → ra cửa; Nora đứng quầy
// thu ngân; Mai và Bao làm bánh trong bếp; Theo bưng trà ra bàn), chạm chọn vật / nhân vật và lớp debug (FPS, bật /
// tắt cờ mở rộng). Tương tác V3 (docs/v3/interaction-spec.md): chạm nhân viên → "Điều khiển" (joystick + cụm nút A /
// Ném / Vẫy / Xong) / "Nói chuyện với khách" (8 truyện + chuyện phiếm), vật nhặt / ném được, sự kiện khách cãi nhau
// trước quán. Không phải app chính: không lưu game (♥ / xu chỉ trong phiên); chuỗi qua AppLocalizations (en / vi).
//
// Chạy: flutter run -d chrome --cross-origin-isolation -t lib/main_shop3d.dart
//       flutter build apk --debug -t lib/main_shop3d.dart
// Web: tham số URL (để chụp màn hình các góc cố định), ví dụ `?yaw=3.5&pitch=0.6&dist=7&owned=oven_2,cafe_tables`.
//       yaw / pitch theo rad, dist theo m; owned = danh sách id `Shop3dRequires` (bỏ trống = không có gì; thiếu tham
//       số = mặc định của Shop3dView); tm=0 / soft=0 / ibl=0: tắt tone mapper PBR Neutral / bóng mềm DPCF / IBL;
//       actors=0: không nhân vật; actors=billboard: ảnh 2D billboard cũ (so sánh); chibiHz=30: cập nhật nhân vật
//       30 Hz (mặc định 60 = mỗi khung); mochi=1: thêm mèo Mochi vào cảnh mặc định; follow=<id>: camera bám nhân vật
//       (linh, hoa, staff_nora, mai, staff_bao, staff_theo, kenji, vip_00…), kèm orbit=<rad>: giữ góc camera so với
//       hướng mặt nhân vật (0 = trước mặt, 1.57 = nhìn ngang); mind=<m>: khoảng cách camera tối thiểu (chụp cận);
//       log=1: in tiến độ dựng cảnh; sun / amb / fill / sky=<RRGGBB>: ghi đè màu nắng / môi trường / đèn phụ / nền;
//       ambi=<n>: cường độ ánh sáng môi trường (chỉnh ánh sáng không cần build lại; mặc định ở Shop3dScene); tx / ty /
//       tz=<m>: điểm camera nhìn vào (mặc định 0; 0,9; 0) để chụp cận mặt tiền, ví dụ
//       `?tx=3&tz=5&yaw=0.5&pitch=0.3&dist=6&mind=3`.
//       Tương tác: play=0: tắt hết tương tác (chế độ xem kịch bản cũ, để chụp ảnh; màn xếp hàng / billboard / actors=0
//       luôn tắt); lang=vi|en: ngôn ngữ (mặc định theo máy, không có thì en); pilot=<id>: điều khiển ngay nhân viên này
//       (mai, staff_nora, staff_bao, staff_theo); events=0: sự kiện cãi nhau không tự chạy theo lịch; event=lastCake |
//       first | tart | now (now = sự kiện kế tiếp; quarrel=now cũng được): ép chạy sự kiện ~3 s sau khi cảnh sẵn sàng.
//       Bàn phím (web, khi điều khiển): WASD / mũi tên đi, Shift chạy, E / Space = nút A, giữ Q rồi thả = ném, Esc = Xong.
//       Đồ họa: quality=auto|low|high (mặc định auto: đo FPS vài giây rồi tự hạ mức — native và web; shop3d_quality.dart);
//       ghi đè từng mục lên bộ của mức: scale=<0.25..1> (độ phân giải ảnh 3D), fps=<n> (giới hạn FPS, 0 = vsync),
//       shadows=0|1 (bóng động), smap=<n> (cạnh shadow map), post=0|1 (hậu kỳ), aa=0|1 (FXAA), blob=0|1 (bóng tròn
//       dưới chân), maxpx=<n> (trần số điểm ảnh của ảnh 3D; web mặc định 2100000 ≈ màn 1080p, 0 = bỏ trần).
//       Lớp debug: `<fps> · <mức> · <entity trong scene>/<đã tạo> ent (static <lưới tĩnh>) · … · dart <ms Dart mỗi
//       khung> · chibi <setTransform đã gửi>/<bộ phận> xf <ms>` (docs/v3/thermion-api-notes.md mục 9.27).
// Android: cùng các tham số trên, truyền qua route ban đầu của FlutterActivity, ví dụ
//       adb shell am start -n com.sugarleafbakery.sugarleaf_bakery/.MainActivity --es route '/?yaw=3.5\&tex=producer'
//       (`\&` để shell của máy không cắt chuỗi); tex=producer | texture: nguồn texture Android của thermion
//       (SurfaceProducer / SurfaceTexture, mặc định SurfaceTexture).
//       Màn xếp hàng (duyệt nhân vật): lineup=1 | all | staff | vip | friends | regulars | mochi | vip|friends |
//       <id>,<id>… — các nhân vật đứng thành hàng trên sàn trống (mặc định không bàn ghế), mặt hướng camera, nhãn id
//       dưới chân (labels=0 để tắt); camera tự đặt vừa khung, tham số yaw / pitch / dist / mind vẫn ghi đè được.
// Ghi chú API: docs/v3/thermion-api-notes.md.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Material, Texture, View;

import 'game/shop3d/chibi/chibi_regulars.dart';
import 'game/shop3d/chibi/chibi_roster.dart';
import 'game/shop3d/chibi/chibi_sizes.dart';
import 'game/shop3d/shop3d_quality.dart';
import 'game/shop3d/shop3d_scene.dart';
import 'game/shop3d/shop3d_view.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  // Toàn màn: ẩn thanh trạng thái + điều hướng; vuốt mép màn hiện tạm rồi tự ẩn.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // CHỖ NỐI danh sách đăng ký: thư viện nhân vật khác (ví dụ khách thường) đăng ký vào màn xếp hàng tại đây, trước khi
  // dựng cảnh — `ChibiRoster.register([ChibiRosterEntry(id, ChibiRoster.regulars, () => build(id)), …])`.
  ChibiRoster.register([
    for (final id in ChibiRegulars.ids) ChibiRosterEntry(id, ChibiRoster.regulars, () => ChibiRegulars.build(id)),
  ]);

  // Web: tham số trên URL. Native: route ban đầu (`--es route '/?…'`), null / '/' = không có tham số.
  final q = kIsWeb
      ? Uri.base.queryParameters
      : (Uri.tryParse(WidgetsBinding.instance.platformDispatcher.defaultRouteName)?.queryParameters ?? const {});
  double? num(String k) => double.tryParse(q[k] ?? '');
  int? hex(String k) => switch (int.tryParse(q[k] ?? '', radix: 16)) {
        final v? => 0xFF000000 | v,
        _ => null,
      };
  if (q['tex'] case final tex?) {
    ThermionFlutterPlugin.instance.setOptions(
      ThermionFlutterOptions(
        nativeOptions: NativeOptions(
          androidTextureSource:
              tex == 'producer' ? AndroidTextureSource.surfaceProducer : AndroidTextureSource.surfaceTexture,
        ),
      ),
    );
  }
  final quality = Shop3dQualityMode.parse(q['quality']);
  final graphics = Shop3dGraphicsOverrides.fromParams(q);
  final owned = q['owned'];
  final ownedSet = owned == null
      ? null
      : {
          for (final id in owned.split(','))
            if (id.trim().isNotEmpty) id.trim(),
        };
  final lineup = q['lineup'];
  final interactive = q['play'] != '0';
  final events = q['events'] != '0';
  final forceEvent = q['event'] ?? q['quarrel'];
  final pilot = q['pilot'];
  final lang = q['lang'];
  final options = Shop3dSceneOptions(
    actorMode: switch (q['actors']) {
      '0' => Shop3dActorMode.none,
      'billboard' => Shop3dActorMode.billboard,
      _ => Shop3dActorMode.chibi,
    },
    chibiHz: int.tryParse(q['chibiHz'] ?? '') ?? 60,
    verbose: q['log'] == '1',
    lineup: lineup,
    mochi: q['mochi'] == '1',
    sunArgb: hex('sun'),
    ambientArgb: hex('amb'),
    fillArgb: hex('fill'),
    skyArgb: hex('sky'),
    ambientIntensity: num('ambi'),
  );

  // tx / ty / tz: điểm camera nhìn vào (mặc định giữa tiệm) — chụp mặt tiền / vỉa hè từ ngoài vào, kèm yaw / pitch / dist.
  final tx = num('tx'), ty = num('ty'), tz = num('tz');
  final target = tx == null && ty == null && tz == null ? null : (x: tx ?? 0.0, y: ty ?? 0.9, z: tz ?? 0.0);

  final Widget view;
  if (lineup != null) {
    // Màn xếp hàng: camera vừa khung theo số nhân vật; một nhân vật nhỏ (mèo) thì nhìn cận, camera hạ thấp.
    final entries = ChibiRoster.select(lineup);
    final small = entries.length == 1 && ChibiSizes.fit(entries.first.build()).height < 0.6;
    final cam = ChibiLineup.camera(entries.length, small: small);
    final dist = num('dist') ?? cam.distance;
    view = Shop3dView(
      initialYaw: num('yaw') ?? 0,
      initialPitch: num('pitch') ?? cam.pitch,
      initialDistance: dist,
      minDistance: num('mind') ?? math.min(1.0, dist * 0.8),
      minEyeHeight: small ? 0.35 : 0.8,
      initialTarget: (x: cam.x, y: cam.y, z: cam.z),
      followActorId: q['follow'],
      followOrbit: num('orbit'),
      sceneOptions: options,
      initialOwned: ownedSet ?? const {},
      showActorLabels: q['labels'] != '0',
      quality: quality,
      graphicsOverrides: graphics,
      interactive: false,
    );
  } else if (ownedSet == null) {
    view = Shop3dView(
      initialTarget: target,
      initialYaw: num('yaw'),
      initialPitch: num('pitch'),
      initialDistance: num('dist'),
      minDistance: num('mind'),
      followActorId: q['follow'],
      followOrbit: num('orbit'),
      sceneOptions: options,
      quality: quality,
      graphicsOverrides: graphics,
      interactive: interactive,
      events: events,
      forceEvent: forceEvent,
      initialPilot: pilot,
    );
  } else {
    view = Shop3dView(
      initialTarget: target,
      initialYaw: num('yaw'),
      initialPitch: num('pitch'),
      initialDistance: num('dist'),
      minDistance: num('mind'),
      followActorId: q['follow'],
      followOrbit: num('orbit'),
      sceneOptions: options,
      initialOwned: ownedSet,
      quality: quality,
      graphicsOverrides: graphics,
      interactive: interactive,
      events: events,
      forceEvent: forceEvent,
      initialPilot: pilot,
    );
  }
  // initialRoute '/': route ban đầu của native chỉ chở tham số, không phải tên trang.
  // Chuỗi người chơi thấy đi qua AppLocalizations (en nguồn, vi); ?lang= ép ngôn ngữ, không có thì theo máy → en.
  final locale = switch (lang) {
    'vi' => const Locale('vi'),
    'en' => const Locale('en'),
    _ => null,
  };
  runApp(
    MaterialApp(
      title: 'Sugarleaf 3D',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) {
        for (final s in supported) {
          if (s.languageCode == device?.languageCode) return s;
        }
        return const Locale('en');
      },
      home: Scaffold(body: view),
    ),
  );
}
