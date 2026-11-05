import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/town/city_settings_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/restaurant_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/salon_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/town_map_sheet.dart';

/// QA: vùng chạm (≥ 48 dp) của các bảng 2D nằm trên cảnh 3D của phố.

/// Cỡ màn hình ngang cần thử: vật lý, mật độ điểm ảnh (logic = vật lý / dpr).
class _Viewport {
  const _Viewport(this.name, this.physical, this.dpr);

  final String name;
  final Size physical;
  final double dpr;

  @override
  String toString() => name;
}

const _viewports = [
  _Viewport('1280x720', Size(1280, 720), 1),
  // 1080×2400 @2.625 → ngang ~914×411 dp (máy 20:9 tầm trung phổ biến): bảng co lại, nút dễ nhỏ hơn 48 dp.
  _Viewport('2400x1080@2.625', Size(2400, 1080), 2.625),
];

final _district = CityConfig.alpha.district('bakery_street');

/// Bảng → hàm dựng (con của `Stack` phủ màn, như lớp phủ cảnh 3D).
final _sheets = <String, Widget Function()>{
  'nhà hàng': () => RestaurantSheet(
    wallet: CityWallet(coins: 1500),
    onOrder: (_) {},
    onClose: () {},
  ),
  'tiệm tóc': () => SalonSheet(
    current: MaiLook.defaults,
    coins: 1500,
    onPreview: (_) {},
    onConfirm: (_) {},
    onCancel: () {},
  ),
  'cài đặt': () => CitySettingsSheet(
    language: LanguagePref.system,
    sound: true,
    onLanguage: (_) {},
    onSound: (_) {},
    onReset: () async {},
    onClose: () {},
  ),
  'bản đồ': () => TownMapSheet(
    district: _district,
    maiPos: ValueNotifier<Offset>(Offset.zero),
    playerLevel: 5,
    onClose: () {},
  ),
};

Future<void> _open(
  WidgetTester tester,
  Widget sheet,
  _Viewport vp, {
  String locale = 'vi',
}) async {
  tester.view.physicalSize = vp.physical;
  tester.view.devicePixelRatio = vp.dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Stack(children: [sheet])),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('vùng chạm: mọi nút ≥ 48×48 dp', () {
    for (final vp in _viewports) {
      for (final e in _sheets.entries) {
        testWidgets('${e.key} @ $vp (vi)', (tester) async {
          final handle = tester.ensureSemantics();
          await _open(tester, e.value(), vp);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          handle.dispose();
        });
      }
    }
  });
}
