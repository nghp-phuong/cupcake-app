import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/core/city/restaurant_menu.dart';
import 'package:sugarleaf_bakery/ui/town/city_hud.dart';
import 'package:sugarleaf_bakery/ui/town/restaurant_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/salon_sheet.dart';

import 'town_test_helpers.dart';

void main() {
  group('CityHud', () {
    testWidgets('xu + cấp; +XP và lên cấp hiện hiệu ứng rồi tự tắt', (
      tester,
    ) async {
      final w = CityWallet(coins: 1500);
      addTearDown(w.dispose);
      await pumpTown(tester, [
        Positioned(left: 10, top: 10, child: CityHud(w)),
      ]);
      final l = await l10n('en');
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text(l.cityMaiLevel(1)), findsOneWidget);
      expect(find.text(l.cityXpGain(40)), findsNothing);

      w.addXp(40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l.cityXpGain(40)), findsOneWidget);
      expect(find.text(l.cityLevelUp), findsNothing);

      final up = w.addXp(200); // vượt cấp 2 (100 XP) và 3 (283 XP)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(up, isNotNull);
      expect(find.text(l.cityLevelUp), findsOneWidget);
      expect(find.text(l.cityMaiLevel(w.level)), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.cityLevelUp), findsNothing);
      expect(find.text(l.cityXpGain(200)), findsNothing);
    });

    testWidgets('đổi xu không gây hiệu ứng XP; tiếng Việt', (tester) async {
      final w = CityWallet(coins: 500);
      addTearDown(w.dispose);
      await pumpTown(tester, [
        Positioned(left: 10, top: 10, child: CityHud(w)),
      ], locale: 'vi');
      final vi = await l10n('vi');
      expect(find.text(vi.cityMaiLevel(1)), findsOneWidget);
      w.buyLook(const MaiLook(hair: MaiHair.bob)); // trừ 300 xu
      await tester.pump();
      expect(find.text('200'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
    });
  });

  group('RestaurantSheet', () {
    testWidgets(
      'đủ 4 món: tên, giá, XP; chạm Gọi món → onOrder đúng món (en)',
      (tester) async {
        final w = CityWallet(coins: 1500);
        addTearDown(w.dispose);
        final ordered = <String>[];
        var closed = 0;
        await pumpTown(tester, [
          RestaurantSheet(
            wallet: w,
            onOrder: (d) => ordered.add(d.id),
            onClose: () => closed++,
          ),
        ]);
        final l = await l10n('en');
        expect(find.text(l.cityMenuTitle), findsOneWidget);
        for (final d in RestaurantMenu.dishes) {
          expect(find.text(l.cityPrice(d.price)), findsOneWidget);
          expect(find.text(l.cityXpGain(d.xp)), findsOneWidget);
        }
        expect(find.text(l.dishFishSoup), findsOneWidget);
        expect(find.text(l.cityNotEnoughCoins), findsNothing);
        expect(find.text(l.cityAteToday), findsNothing);

        await tester.tap(find.text(l.cityOrderFood).at(1));
        expect(ordered, ['omelette_rice']);
        await tester.tap(find.byIcon(Icons.close_rounded));
        expect(closed, 1);
      },
    );

    testWidgets(
      'thiếu xu: nút mờ, không gọi onOrder, hiện "Không đủ xu"; xu đủ lại thì gọi được',
      (tester) async {
        final w = CityWallet(coins: 150); // chỉ đủ món 120
        addTearDown(w.dispose);
        final ordered = <String>[];
        await pumpTown(tester, [
          RestaurantSheet(
            wallet: w,
            onOrder: (d) => ordered.add(d.id),
            onClose: () {},
          ),
        ]);
        final l = await l10n('en');
        expect(find.text(l.cityNotEnoughCoins), findsNWidgets(3));
        await tester.tap(find.text(l.cityOrderFood).at(3));
        await tester.tap(find.text(l.cityOrderFood).at(2));
        expect(ordered, isEmpty);
        await tester.tap(find.text(l.cityOrderFood).at(0));
        expect(ordered, ['fish_soup']);
      },
    );

    testWidgets('món đã ăn hôm nay: chỉ món đó hiện "đã ăn" + XP giảm (vi)', (
      tester,
    ) async {
      final w = CityWallet(coins: 1500);
      addTearDown(w.dispose);
      await pumpTown(tester, [
        RestaurantSheet(wallet: w, onOrder: (_) {}, onClose: () {}),
      ], locale: 'vi');
      final vi = await l10n('vi');
      expect(find.text(vi.cityMenuTitle), findsOneWidget);
      expect(find.text(vi.cityAteToday), findsNothing);

      final fish = RestaurantMenu.dishes.first;
      w.eat(fish);
      await tester.pump();
      expect(find.text(vi.cityAteToday), findsOneWidget);
      expect(
        find.text(vi.cityXpGain(RestaurantMenu.xpFor(fish, 1))),
        findsOneWidget,
      );
      expect(find.text(vi.cityXpGain(fish.xp)), findsNothing);
      expect(
        find.text(vi.cityXpGain(RestaurantMenu.dishes[1].xp)),
        findsOneWidget,
      );
    });
  });

  group('SalonSheet', () {
    Future<List<Object>> pumpSalon(
      WidgetTester tester, {
      MaiLook current = MaiLook.defaults,
      int coins = 1000,
      String locale = 'en',
    }) async {
      final previews = <MaiLook>[];
      final confirms = <MaiLook>[];
      final cancels = <int>[];
      await pumpTown(tester, [
        SalonSheet(
          current: current,
          coins: coins,
          onPreview: previews.add,
          onConfirm: confirms.add,
          onCancel: () => cancels.add(1),
        ),
      ], locale: locale);
      return [previews, confirms, cancels];
    }

    testWidgets('giá theo lựa chọn: 0 → 300; mỗi lần chọn gọi onPreview (en)', (
      tester,
    ) async {
      final r = await pumpSalon(tester);
      final previews = r[0] as List<MaiLook>;
      final l = await l10n('en');
      expect(find.text(l.citySalonTitle), findsOneWidget);
      expect(find.text(l.cityPrice(0)), findsOneWidget);

      await tester.tap(find.text(l.hairBob));
      await tester.pump();
      expect(previews.last, const MaiLook(hair: MaiHair.bob));
      expect(find.text(l.cityPrice(300)), findsOneWidget);
    });

    testWidgets('chọn màu bằng ô tròn: giá 500 khi đổi cả kiểu lẫn màu', (
      tester,
    ) async {
      final r = await pumpSalon(tester);
      final previews = r[0] as List<MaiLook>;
      final l = await l10n('en');
      await tester.tap(find.text(l.hairBun));
      await tester.pump();
      final swatches = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration! as BoxDecoration).color ==
                salonSwatch(MaiHairColor.strawberry),
      );
      expect(swatches, findsOneWidget);
      await tester.tap(swatches);
      await tester.pump();
      expect(
        previews.last,
        const MaiLook(hair: MaiHair.bun, hairColor: MaiHairColor.strawberry),
      );
      expect(find.text(l.cityPrice(500)), findsOneWidget);
      // Chọn lại kiểu cũ → giá còn 200.
      await tester.tap(find.text(l.hairPonytail));
      await tester.pump();
      expect(find.text(l.cityPrice(200)), findsOneWidget);
    });

    testWidgets('xác nhận gọi onConfirm với kiểu chọn; huỷ gọi onCancel', (
      tester,
    ) async {
      final r = await pumpSalon(tester);
      final confirms = r[1] as List<MaiLook>;
      final cancels = r[2] as List<int>;
      final l = await l10n('en');
      await tester.tap(find.text(l.hairTwinTails));
      await tester.pump();
      await tester.tap(find.text(l.cityConfirm));
      expect(confirms, [const MaiLook(hair: MaiHair.twinTails)]);
      await tester.tap(find.text(l.cityCancel));
      expect(cancels, [1]);
    });

    testWidgets(
      'thiếu xu: Xác nhận mờ, hiện "Không đủ xu"; Huỷ vẫn dùng được (vi)',
      (tester) async {
        final r = await pumpSalon(tester, coins: 100, locale: 'vi');
        final confirms = r[1] as List<MaiLook>;
        final cancels = r[2] as List<int>;
        final vi = await l10n('vi');
        expect(
          find.text(vi.cityNotEnoughCoins),
          findsNothing,
        ); // chưa chọn gì: giá 0
        await tester.tap(find.text(vi.hairBob));
        await tester.pump();
        expect(find.text(vi.cityNotEnoughCoins), findsOneWidget);
        expect(find.text(vi.cityPrice(300)), findsOneWidget);
        await tester.tap(find.text(vi.cityConfirm));
        expect(confirms, isEmpty);
        await tester.tap(find.text(vi.cityCancel));
        expect(cancels, [1]);
      },
    );

    testWidgets(
      'bắt đầu từ kiểu hiện tại: giữ nguyên → giá 0, tính giá theo current',
      (tester) async {
        await pumpSalon(
          tester,
          current: const MaiLook(
            hair: MaiHair.bob,
            hairColor: MaiHairColor.black,
          ),
        );
        final l = await l10n('en');
        expect(find.text(l.cityPrice(0)), findsOneWidget);
        await tester.tap(
          find.text(l.hairBob),
        ); // chọn lại cái đang có: không đổi
        await tester.pump();
        expect(find.text(l.cityPrice(0)), findsOneWidget);
        await tester.tap(find.text(l.hairPonytail));
        await tester.pump();
        expect(find.text(l.cityPrice(SalonPrices.hairStyle)), findsOneWidget);
      },
    );
  });
}
