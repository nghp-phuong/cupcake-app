import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/ui/town/location_banner.dart';
import 'package:sugarleaf_bakery/ui/town/minimap.dart';
import 'package:sugarleaf_bakery/ui/town/town_fade.dart';
import 'package:sugarleaf_bakery/ui/town/town_l10n.dart';
import 'package:sugarleaf_bakery/ui/town/town_map_sheet.dart';

import 'town_test_helpers.dart';

final _district = CityConfig.alpha.district('bakery_street');

void main() {
  group('cityText', () {
    test('mọi nameKey của quận 1 và món/tóc có chuỗi en + vi', () async {
      for (final code in ['en', 'vi']) {
        final l = await l10n(code);
        final keys = <String>{
          for (final d in CityConfig.alpha.districts) ...[
            d.nameKey,
            for (final lot in d.lots) lot.nameKey,
          ],
          'dishFishSoup',
          'dishOmeletteRice',
          'dishVeggieCurry',
          'dishSeafoodNoodles',
          'townComingSoon',
          'townOpening',
        };
        for (final k in keys) {
          expect(cityText(l, k), isNot(k), reason: '$code/$k');
        }
        expect(cityText(l, 'khongCo'), 'khongCo');
      }
      final vi = await l10n('vi');
      expect(cityText(vi, 'cityRestaurantName'), vi.cityRestaurantName);
      expect(hairText(vi, MaiHair.bob), vi.hairBob);
      expect(hairColorText(vi, MaiHairColor.black), vi.hairColorBlack);
    });
  });

  group('TownMinimap', () {
    testWidgets(
      'chạm gọi onTap; cập nhật vị trí nhiều lần không lỗi, timer dọn sạch',
      (tester) async {
        final pos = ValueNotifier<Offset>(const Offset(-6, -4.4));
        final yaw = ValueNotifier<double>(0);
        addTearDown(pos.dispose);
        addTearDown(yaw.dispose);
        var taps = 0;
        await pumpTown(tester, [
          Positioned(
            left: 10,
            top: 10,
            child: TownMinimap(
              district: _district,
              maiPos: pos,
              maiYaw: yaw,
              onTap: () => taps++,
            ),
          ),
        ]);
        expect(tester.getSize(find.byType(TownMinimap)).width, 168);
        for (var i = 0; i < 30; i++) {
          pos.value = Offset(-6 + i * 0.5, -4.4);
          yaw.value = i * 0.1;
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.tap(find.byType(TownMinimap));
        expect(taps, 1);
        // Gỡ widget: timer throttle đang chờ phải bị huỷ (không còn timer treo).
        pos.value = const Offset(0, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('nhãn đọc màn hình theo ngôn ngữ', (tester) async {
      final pos = ValueNotifier<Offset>(Offset.zero);
      addTearDown(pos.dispose);
      final h = tester.ensureSemantics();
      await pumpTown(tester, [
        TownMinimap(district: _district, maiPos: pos, onTap: () {}),
      ], locale: 'vi');
      final vi = await l10n('vi');
      expect(find.bySemanticsLabel(vi.townOpenMap), findsOneWidget);
      h.dispose();
    });
  });

  group('TownMapSheet', () {
    testWidgets(
      'tên lô, lô khoá ghi cấp, "Bạn ở đây", đóng bằng nút và chạm ngoài (en)',
      (tester) async {
        final pos = ValueNotifier<Offset>(const Offset(-6, -4.4));
        addTearDown(pos.dispose);
        var closed = 0;
        await pumpTown(tester, [
          TownMapSheet(
            district: _district,
            maiPos: pos,
            playerLevel: 7,
            onClose: () => closed++,
          ),
        ]);
        final l = await l10n('en');
        expect(find.text(l.townStreetName), findsOneWidget);
        expect(find.text(l.townHomeShop), findsOneWidget);
        expect(find.text(l.cityRestaurantName), findsOneWidget);
        expect(find.text(l.citySalonName), findsOneWidget);
        expect(find.text(l.cityParkName), findsOneWidget);
        expect(find.text(l.townYouAreHere), findsOneWidget);
        // Cấp 7: s1 (cấp 5) mở; s3 (10) và s4 (15) khoá.
        expect(find.text(l.townLotLocked(10)), findsOneWidget);
        expect(find.text(l.townLotLocked(15)), findsOneWidget);
        expect(find.text(l.townLotLocked(5)), findsNothing);

        await tester.tap(find.text(l.commonClose));
        expect(closed, 1);
        await tester.tapAt(const Offset(20, 20)); // ngoài thẻ
        expect(closed, 2);
        await tester.tap(find.text(l.townStreetName)); // trong thẻ: không đóng
        expect(closed, 2);
      },
    );

    testWidgets('tiếng Việt', (tester) async {
      final pos = ValueNotifier<Offset>(Offset.zero);
      addTearDown(pos.dispose);
      await pumpTown(tester, [
        TownMapSheet(
          district: _district,
          maiPos: pos,
          playerLevel: 1,
          onClose: () {},
        ),
      ], locale: 'vi');
      final vi = await l10n('vi');
      expect(find.text(vi.townYouAreHere), findsOneWidget);
      expect(find.text(vi.townLotLocked(5)), findsOneWidget);
      expect(find.text(vi.cityRestaurantName), findsOneWidget);
    });
  });

  group('TownFadeController', () {
    testWidgets(
      'fadeOut/fadeIn 0,4 s; chữ mở cửa sau 1 s tối; lớp chặn chạm khi tối',
      (tester) async {
        final c = TownFadeController();
        addTearDown(c.dispose);
        var below = 0;
        await pumpTown(tester, [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => below++,
            ),
          ),
          TownFadeLayer(controller: c),
        ]);
        final l = await l10n('en');
        await tester.tap(find.byType(Scaffold));
        expect(below, 1); // trong suốt: không chặn

        var out = false;
        c.fadeOut().then((_) => out = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.opacity.value, closeTo(0.5, 0.05));
        expect(out, isFalse);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(c.opacity.value, 1);
        expect(out, isTrue);
        await tester.tap(find.byType(Scaffold));
        expect(below, 1); // tối: nuốt chạm

        expect(find.text(l.townOpening), findsNothing);
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text(l.townOpening), findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.showOpening.value, isTrue);
        expect(find.text(l.townOpening), findsOneWidget);

        var inDone = false;
        c.fadeIn().then((_) => inDone = true);
        await tester.pump();
        expect(c.showOpening.value, isFalse);
        await tester.pump(const Duration(milliseconds: 200));
        expect(c.opacity.value, closeTo(0.5, 0.05));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(c.opacity.value, 0);
        expect(inDone, isTrue);
        expect(find.text(l.townOpening), findsNothing);
      },
    );

    testWidgets('fadeIn trước khi đủ 1 s thì không hiện chữ', (tester) async {
      final c = TownFadeController();
      addTearDown(c.dispose);
      await pumpTown(tester, [TownFadeLayer(controller: c)]);
      c.fadeOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      c.fadeIn();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(seconds: 2));
      expect(c.showOpening.value, isFalse);
    });
  });

  group('LocationBanner', () {
    testWidgets('trượt xuống, ~2 s sau tự ẩn; dạng "Sắp mở" có dòng phụ', (
      tester,
    ) async {
      final c = LocationBannerController();
      addTearDown(c.dispose);
      await pumpTown(tester, [LocationBanner(controller: c)]);
      final l = await l10n('en');
      expect(find.text(l.cityRestaurantName), findsNothing);

      c.show(l.cityRestaurantName);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.cityRestaurantName), findsOneWidget);
      expect(find.text(l.townComingSoon), findsNothing);

      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.cityRestaurantName), findsNothing);

      c.show(l.cityRealtyName, subtitle: l.townComingSoon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.cityRealtyName), findsOneWidget);
      expect(find.text(l.townComingSoon), findsOneWidget);

      // Gọi lại giữa chừng: thay băng, tính giờ lại.
      await tester.pump(const Duration(milliseconds: 1500));
      c.show(l.citySalonName);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l.citySalonName), findsOneWidget);
      expect(find.text(l.cityRealtyName), findsNothing);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.citySalonName), findsNothing);
    });
  });
}
