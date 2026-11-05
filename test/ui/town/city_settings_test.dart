import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/ui/town/city_menu_button.dart';
import 'package:sugarleaf_bakery/ui/town/city_settings_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/minimap.dart';
import 'package:sugarleaf_bakery/ui/town/town_map_sheet.dart';

import 'town_test_helpers.dart';

final _district = CityConfig.alpha.district('bakery_street');

Widget _sheet({
  LanguagePref language = LanguagePref.system,
  bool sound = true,
  ValueChanged<LanguagePref>? onLanguage,
  ValueChanged<bool>? onSound,
  Future<void> Function()? onReset,
  VoidCallback? onClose,
}) => CitySettingsSheet(
  language: language,
  sound: sound,
  onLanguage: onLanguage ?? (_) {},
  onSound: onSound ?? (_) {},
  onReset: onReset ?? () async {},
  onClose: onClose ?? () {},
);

RenderObject _paintOf(WidgetTester tester, Finder within) =>
    tester.renderObject(
      find.descendant(of: within, matching: find.byType(CustomPaint)).first,
    );

/// Đúng [n] path trong lần vẽ (mỗi ổ khoá một path cho quai; thân là RRect).
void _expectPaths(RenderObject rb, int n) {
  if (n == 0) {
    expect(rb, isNot(paints..path()));
    return;
  }
  final exact = paints;
  for (var i = 0; i < n; i++) {
    exact.path();
  }
  expect(rb, exact);
  final more = paints;
  for (var i = 0; i <= n; i++) {
    more.path();
  }
  expect(rb, isNot(more), reason: 'không quá $n path');
}

void main() {
  group('CitySettingsSheet', () {
    testWidgets('chọn ngôn ngữ và bật/tắt âm thanh gọi đúng callback', (
      tester,
    ) async {
      final langs = <LanguagePref>[];
      final sounds = <bool>[];
      await pumpTown(tester, [
        _sheet(onLanguage: langs.add, onSound: sounds.add),
      ]);
      final l = await l10n('en');
      expect(find.text(l.settingsLanguageSystem), findsOneWidget);
      expect(find.text(l.settingsLanguageEn), findsOneWidget);
      expect(find.text(l.settingsLanguageVi), findsOneWidget);
      expect(find.text(l.settingsVersion('0.1.0-alpha')), findsOneWidget);
      expect(find.text(l.settingsAlphaNote), findsOneWidget);

      await tester.tap(find.text(l.settingsLanguageVi));
      await tester.tap(find.text(l.settingsLanguageEn));
      expect(langs, [LanguagePref.vi, LanguagePref.en]);

      await tester.tap(find.text(l.settingsOn));
      expect(sounds, [false]);
    });

    testWidgets('âm thanh tắt: bấm bật lại', (tester) async {
      final sounds = <bool>[];
      await pumpTown(tester, [_sheet(sound: false, onSound: sounds.add)]);
      final l = await l10n('en');
      await tester.tap(find.text(l.settingsOff));
      expect(sounds, [true]);
    });

    testWidgets('xoá dữ liệu 2 bước: bước 1 chưa gọi onReset', (tester) async {
      var resets = 0;
      var closed = 0;
      await pumpTown(tester, [
        _sheet(onReset: () async => resets++, onClose: () => closed++),
      ]);
      final l = await l10n('en');
      await tester.tap(find.text(l.settingsResetData));
      await tester.pump();
      expect(resets, 0);
      expect(find.text(l.settingsResetConfirmTitle), findsOneWidget);
      expect(find.text(l.settingsResetConfirmBody), findsOneWidget);

      // Đang xác nhận: chạm ngoài thẻ không đóng; Huỷ quay về bước 1.
      await tester.tapAt(const Offset(10, 10));
      expect(closed, 0);
      await tester.tap(find.text(l.commonCancel));
      await tester.pump();
      expect(find.text(l.settingsResetConfirmTitle), findsNothing);
      expect(resets, 0);

      await tester.tap(find.text(l.settingsResetData));
      await tester.pump();
      await tester.tap(find.text(l.commonConfirm));
      await tester.pump();
      expect(resets, 1);
      expect(find.text(l.settingsResetConfirmTitle), findsNothing);
    });

    testWidgets('chạm ngoài thẻ và nút Đóng gọi onClose', (tester) async {
      var closed = 0;
      await pumpTown(tester, [_sheet(onClose: () => closed++)]);
      final l = await l10n('en');
      await tester.tapAt(const Offset(10, 10));
      expect(closed, 1);
      await tester.tap(find.text(l.commonClose));
      expect(closed, 2);
    });

    testWidgets('vùng chạm >= 48 dp (nút bánh răng và mọi nút trong bảng)', (
      tester,
    ) async {
      await pumpTown(tester, [
        Positioned(
          left: 10,
          top: 10,
          child: CityMenuButton(onPressed: () {}, size: 30),
        ),
      ]);
      final l = await l10n('en');
      final gear = tester.getSize(find.byType(CityMenuButton));
      expect(gear.width, greaterThanOrEqualTo(48));
      expect(gear.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(l.settingsTitle), findsOneWidget);

      await pumpTown(tester, [_sheet()]);
      for (final k in [
        'lang-system',
        'lang-en',
        'lang-vi',
        'sound-toggle',
        'reset-start',
        'settings-close',
      ]) {
        final r = tester.getRect(find.byKey(ValueKey(k)));
        expect(r.height, greaterThanOrEqualTo(48), reason: k);
        expect(r.width, greaterThanOrEqualTo(48), reason: k);
      }
    });

    for (final code in ['en', 'vi']) {
      for (final size in [const Size(1280, 720), const Size(960, 540)]) {
        testWidgets(
          'không tràn chữ ($code, ${size.width.toInt()}x${size.height.toInt()}), '
          'cả khi đang xác nhận xoá',
          (tester) async {
            await pumpTown(
              tester,
              [_sheet(language: LanguagePref.vi)],
              locale: code,
              size: size,
            );
            expect(tester.takeException(), isNull);
            final l = await l10n(code);
            await tester.tap(find.text(l.settingsResetData));
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(find.text(l.settingsResetConfirmBody), findsOneWidget);
          },
        );
      }
    }
  });

  group('Ổ khoá theo cấp', () {
    // s1 cấp 5, s3 cấp 10, s4 cấp 15 (đều là lô chi nhánh).
    for (final (level, locks) in [(1, 3), (7, 2), (15, 0)]) {
      testWidgets('TownMinimap cấp $level: $locks ổ khoá', (tester) async {
        final pos = ValueNotifier<Offset>(Offset.zero);
        final lv = ValueNotifier<int>(level);
        addTearDown(pos.dispose);
        addTearDown(lv.dispose);
        await pumpTown(tester, [
          Positioned(
            left: 0,
            top: 0,
            child: TownMinimap(
              district: _district,
              maiPos: pos,
              playerLevel: lv,
              onTap: () {},
            ),
          ),
        ]);
        _expectPaths(_paintOf(tester, find.byType(TownMinimap)), locks);
      });
    }

    testWidgets('TownMinimap vẽ lại khi cấp đổi', (tester) async {
      final pos = ValueNotifier<Offset>(Offset.zero);
      final lv = ValueNotifier<int>(1);
      addTearDown(pos.dispose);
      addTearDown(lv.dispose);
      await pumpTown(tester, [
        TownMinimap(
          district: _district,
          maiPos: pos,
          playerLevel: lv,
          onTap: () {},
        ),
      ]);
      _expectPaths(_paintOf(tester, find.byType(TownMinimap)), 3);
      lv.value = 15;
      await tester.pump();
      _expectPaths(_paintOf(tester, find.byType(TownMinimap)), 0);
    });

    testWidgets('playerLevel null: không vẽ khoá (hành vi cũ)', (tester) async {
      final pos = ValueNotifier<Offset>(Offset.zero);
      addTearDown(pos.dispose);
      await pumpTown(tester, [
        TownMinimap(district: _district, maiPos: pos, onTap: () {}),
      ]);
      _expectPaths(_paintOf(tester, find.byType(TownMinimap)), 0);
    });

    for (final (level, unlocked) in [(1, 0), (7, 1), (15, 3)]) {
      testWidgets('TownMapSheet cấp $level: $unlocked lô "đã mở khoá"', (
        tester,
      ) async {
        final pos = ValueNotifier<Offset>(Offset.zero);
        addTearDown(pos.dispose);
        await pumpTown(tester, [
          TownMapSheet(
            district: _district,
            maiPos: pos,
            playerLevel: level,
            onClose: () {},
          ),
        ]);
        final l = await l10n('en');
        expect(find.text(l.townLotUnlocked), findsNWidgets(unlocked));
        expect(find.byIcon(Icons.lock_open_rounded), findsNWidgets(unlocked));
        expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3 - unlocked));
        _expectPaths(_paintOf(tester, find.byType(TownMapSheet)), 3 - unlocked);
      });
    }

    testWidgets('TownMapSheet: ổ khoá không đè chữ của lô', (tester) async {
      final pos = ValueNotifier<Offset>(Offset.zero);
      addTearDown(pos.dispose);
      await pumpTown(tester, [
        TownMapSheet(
          district: _district,
          maiPos: pos,
          playerLevel: 1,
          onClose: () {},
        ),
      ]);
      final l = await l10n('en');
      final paint = find
          .descendant(
            of: find.byType(TownMapSheet),
            matching: find.byType(CustomPaint),
          )
          .first;
      final origin = tester.getTopLeft(paint);
      final size = tester.getSize(paint);
      var checked = 0;
      for (final lot in _district.lots.where((x) => x.requiresLevel > 1)) {
        final lotR = TownMapPainter.lotRect(_district, lot, size);
        final lock = TownMapPainter.lockBounds(lotR, corner: true).shift(origin);
        expect(lock.shortestSide, lessThan(lotR.shortestSide * 0.3));
        final text = find.text(l.townLotLocked(lot.requiresLevel));
        expect(text, findsOneWidget);
        final tr = tester.getRect(text);
        expect(lock.overlaps(tr), isFalse, reason: 'khoá đè chữ ${lot.id}');
        checked++;
      }
      expect(checked, 3);
    });
  });
}
