import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/common/art.dart';
import 'package:sugarleaf_bakery/ui/day/order_ticket.dart';
import 'package:sugarleaf_bakery/ui/day/result_card.dart';
import 'package:sugarleaf_bakery/ui/shift/shift_news_card.dart';
import 'package:sugarleaf_bakery/ui/shift/shift_summary_card.dart';

import 'shift_ui_helpers.dart';

/// Lớp 2D của ca bán (docs/v3/city-gd3-spec.md §5, §7 ui 1–7).

const _close = ValueKey('shift-close');
const _start = ValueKey('shift-start-baking');
const _confirmClose = ValueKey('shift-confirm-close');
const _confirmCancel = ValueKey('shift-confirm-cancel');
const _double = ValueKey('shift-summary-double');
const _done = ValueKey('shift-summary-done');

/// Chạy hết toast gắn vào Overlay của app (sau khi đóng ca) để không còn Timer treo.
Future<void> _drainToasts(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

/// Gỡ lớp (và [BakeSessionView] nếu có) rồi chạy hết hẹn giờ còn lại của game làm bánh.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('§7-1 các pha hiện đúng widget, vùng chạm ≥ 48 dp', () {
    for (final size in const [Size(1280, 720), Size(800, 360)]) {
      testWidgets('arriving → ordering → result → finished @ ${size.width.toInt()}×${size.height.toInt()}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final l = await shiftL10n('en');
        final game = shiftGame();
        final session = openShift(game);
        final below = ValueNotifier(0);
        await pumpShiftLayer(
          tester,
          session: session,
          game: game,
          host: FakeShiftHost(),
          ads: AdLog().service(game),
          size: size,
          below: below,
        );

        // arriving: chip tiến độ + "Khách đang tới…", chưa có vé.
        expect(find.text(l.dayCustomerProgress(1, session.total)), findsOneWidget);
        expect(find.text(l.shiftCustomerComing), findsOneWidget);
        expect(find.byType(OrderTicket), findsNothing);
        expect(find.byKey(_start), findsNothing);
        expect(find.byKey(_close), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

        // ordering: vé đơn + "Làm bánh" bên phải; giữa màn không bị che.
        session.customerArrived();
        await tester.pump();
        expect(find.text(l.shiftCustomerComing), findsNothing);
        expect(find.byType(OrderTicket), findsOneWidget);
        expect(find.byKey(_start), findsOneWidget);
        expect(tester.getRect(find.byType(OrderTicket)).left, greaterThan(size.width / 2));
        await tester.tapAt(size.center(Offset.zero));
        expect(below.value, 1);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

        // result.
        session.startBaking();
        session.completeBake(outcomeFor(session.current.order, 4));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ResultCard), findsOneWidget);
        expect(find.byType(OrderTicket), findsNothing);
        expect(tester.getRect(find.byType(ResultCard)).center.dx, greaterThan(size.width / 2));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

        // "Khách tiếp" → khách 2 đang tới.
        await tester.tap(find.text(l.dayNextCustomer));
        await tester.pump();
        expect(session.phase, ShiftPhase.arriving);
        expect(find.text(l.dayCustomerProgress(2, session.total)), findsOneWidget);

        // finished: thẻ tổng kết, không còn nút X.
        serveAll(session, 4);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ShiftSummaryCard), findsOneWidget);
        expect(find.text(l.shiftSummaryTitle), findsOneWidget);
        expect(find.byKey(_close), findsNothing);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('thẻ "Mở mới!" trước khách đầu: món + topping từ mốc recipeSeen; đóng thẻ → acknowledge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l = await shiftL10n('en');
      final game = shiftGame(level: 5, recipeSeen: 1);
      final session = openShift(game);
      expect(session.recipeNews, isNotEmpty);
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));

      expect(find.byType(ShiftNewsCard), findsOneWidget);
      final card = tester.widget<ShiftNewsCard>(find.byType(ShiftNewsCard));
      expect(card.recipes, contains(RecipeId.macaron));
      expect(card.toppings, contains(ToppingId.sugarPearl));
      expect(find.text(l.recipeName(RecipeId.macaron)), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tap(find.byKey(const ValueKey('shift-news-close')));
      await tester.pump();
      expect(find.byType(ShiftNewsCard), findsNothing);
      expect(session.recipeNews, isEmpty);
      expect(game.recipeSeen, 5);
      handle.dispose();
    });

    testWidgets('lên cấp giữa ca → toast cityLevelUp', (tester) async {
      final l = await shiftL10n('en');
      // Thiếu 1 XP nữa là lên cấp 2.
      final game = shiftGame(xp: _xpToLevel2 - 1);
      final session = openShift(game);
      serve(session, 4);
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      await tester.tap(find.text(l.dayNextCustomer));
      await tester.pump();
      expect(find.text(l.cityLevelUp), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('§7-2 "Làm bánh" → setBaking(true), RefFrame + BakeSessionView mờ đục; xong → setBaking(false), ResultCard', (
    tester,
  ) async {
    final game = shiftGame();
    final session = openShift(game);
    final host = FakeShiftHost();
    final below = ValueNotifier(0);
    session.customerArrived();
    await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game), below: below);

    await tester.tap(find.byKey(_start));
    await tester.pump();
    expect(session.phase, ShiftPhase.baking);
    expect(host.baking, [true]);
    expect(find.byType(RefFrame), findsOneWidget);
    expect(find.byType(BakeSessionView), findsOneWidget);
    expect(find.byType(OrderTicket), findsNothing);
    // Mờ đục: chạm giữa màn và góc màn đều không tới cảnh.
    for (final p in const [Offset(640, 360), Offset(4, 4), Offset(1276, 716)]) {
      await tester.tapAt(p);
    }
    expect(below.value, 0);
    // X ở góc trái dưới khi làm bánh.
    final x = tester.getRect(find.byKey(_close));
    expect(x.left, lessThan(100));
    expect(x.bottom, greaterThan(620));

    final view = tester.widget<BakeSessionView>(find.byType(BakeSessionView));
    expect(view.order, session.current.order);
    view.onComplete(outcomeFor(session.current.order, 4));
    await tester.pump();
    expect(session.phase, ShiftPhase.result);
    expect(host.baking, [true, false]);
    expect(find.byType(BakeSessionView), findsNothing);
    expect(find.byType(ResultCard), findsOneWidget);
    expect(tester.widget<ResultCard>(find.byType(ResultCard)).showPortrait, isFalse);
    await _teardown(tester);
  });

  testWidgets('§7-3 có lời chê → feedbackNeedsWork; showPortrait:false không có CustomerImage', (tester) async {
    final l = await shiftL10n('en');
    final game = shiftGame();
    final session = openShift(game);
    final served = serve(session, 2);
    expect(served.result.complaint, isNotNull);
    await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(l.feedbackNeedsWork(l.stationName(served.result.weakest))), findsOneWidget);
    expect(find.text(l.feedbackText(served.result.complaint!)), findsOneWidget);
    expect(find.byType(CustomerImage), findsNothing);
    expect(find.text(l.dayRemakeWithAd), findsOneWidget);

    // Đối chứng: thẻ mặc định vẫn có chân dung.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: ResultCard(
            order: served.order.order,
            customer: served.order.customer,
            outcome: served.outcome,
            result: served.result,
            canRemake: false,
            onNext: () {},
            onRemake: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomerImage), findsOneWidget);
  });

  group('§7-4 làm lại', () {
    testWidgets('quảng cáo xem xong → về baking, setBaking(true), bếp mới', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      final ads = AdLog();
      serve(session, 1);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: ads.service(game));

      await tester.tap(find.text(l.dayRemakeWithAd));
      await tester.pump();
      await tester.pump();
      expect(ads.shown, 1);
      expect(game.rewardedToday, 1);
      expect(session.phase, ShiftPhase.baking);
      expect(host.baking, [true]);
      expect(find.byType(BakeSessionView), findsOneWidget);
      expect(find.byType(ResultCard), findsNothing);
      await _teardown(tester);
    });

    testWidgets('quảng cáo không xem hết → toast, vẫn ở kết quả', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      serve(session, 2);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: DecliningAds(game));

      await tester.tap(find.text(l.dayRemakeWithAd));
      await tester.pump();
      await tester.pump();
      expect(session.phase, ShiftPhase.result);
      expect(host.baking, isEmpty);
      expect(find.text(l.adNotCompleted), findsOneWidget);
      expect(find.byType(ResultCard), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('đơn ≥3★ không có nút làm lại', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      serve(session, 3);
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      expect(find.text(l.dayRemakeWithAd), findsNothing);
    });
  });

  group('§7-5 tổng kết', () {
    testWidgets('x2 → summaryDoubled; "Xong" ngày 4 → interstitial, ghi mốc, close', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame(day: 4);
      final session = openShift(game);
      final host = FakeShiftHost();
      final ads = AdLog();
      serveAll(session, 4);
      final net = session.summary!.net;
      expect(net, greaterThan(0));
      expect(game.interstitialDue, isTrue);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: ads.service(game));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(_double), findsOneWidget);
      final coins = game.wallet.coins;
      await tester.tap(find.byKey(_double));
      await tester.pump();
      await tester.pump();
      expect(ads.shown, 1);
      expect(game.wallet.coins, coins + net);
      expect(session.summary!.doubledCoins, net);
      expect(find.byKey(_double), findsNothing);
      expect(find.text(l.summaryDoubled), findsOneWidget);

      await tester.tap(find.byKey(_done));
      await tester.pump();
      await tester.pump();
      expect(ads.shown, 2);
      expect(game.bakery.adDay, 4);
      expect(game.interstitialDue, isFalse);
      expect(host.closed, 1);
    });

    testWidgets('"Xong" chưa tới hạn (ngày 1) → không interstitial, close', (tester) async {
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      final ads = AdLog();
      serveAll(session, 4);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: ads.service(game));
      await tester.tap(find.byKey(_done));
      await tester.pump();
      await tester.pump();
      expect(ads.shown, 0);
      expect(host.closed, 1);
    });

    testWidgets('hết lượt quảng cáo thưởng → không có nút x2', (tester) async {
      final game = shiftGame();
      for (var i = 0; i < CityGame.maxRewardedPerDay; i++) {
        game.registerRewardedShown();
      }
      final session = openShift(game);
      serveAll(session, 4);
      expect(session.canDouble, isFalse);
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      expect(find.byType(ShiftSummaryCard), findsOneWidget);
      expect(find.byKey(_double), findsNothing);
      expect(find.byKey(_done), findsOneWidget);
    });

    testWidgets('dòng buff "No bụng" và lên cấp + mở mới', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame(xp: _xpToLevel2 - 1, fullBuff: true);
      final session = openShift(game);
      serveAll(session, 4);
      final s = session.summary!;
      expect(s.buffTips, greaterThan(0));
      expect(s.leveledUp, isTrue);
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.shiftBuffTip(s.buffTips)), findsOneWidget);
      expect(find.text(l.summaryLevelUp(s.levelAfter)), findsOneWidget);
      expect(find.text(l.summaryDayBonusXp(30)), findsOneWidget);
      for (final r in s.newRecipes) {
        expect(find.text(l.unlockRecipe(l.recipeName(r))), findsOneWidget);
      }
    });
  });

  group('§7-6 đóng ca sớm: X / Esc / Back → xác nhận → abort, toast, close', () {
    testWidgets('X lúc gọi món; Huỷ thì không đóng', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      session.customerArrived();
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));

      await tester.tap(find.byKey(_close));
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      expect(find.text(l.dayExitConfirmBody), findsOneWidget);
      await tester.tap(find.byKey(_confirmCancel));
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsNothing);
      expect(session.phase, ShiftPhase.ordering);
      expect(host.closed, 0);

      await tester.tap(find.byKey(_close));
      await tester.pump();
      await tester.tap(find.byKey(_confirmClose));
      await tester.pump();
      expect(session.phase, ShiftPhase.aborted);
      expect(host.closed, 1);
      expect(host.baking, isEmpty);
      expect(find.text(l.shiftClosedToast(0)), findsOneWidget);
      await _drainToasts(tester);
      expect(find.text(l.shiftClosedToast(0)), findsNothing);
    });

    testWidgets('đơn 1★ lỗ rồi đóng ca sớm → toast "+0", không "+-N"', (tester) async {
      final l = await shiftL10n('en');
      // Bảng giá hiện tại: 1★ trả 50% giá > chi phí (~27% giá) nên chưa lỗ thật; giả lập tổng kết lỗ.
      final game = shiftGame();
      final session = _LossSession(game);
      serve(session, 1);
      final host = FakeShiftHost();
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));

      await tester.tap(find.byKey(_close));
      await tester.pump();
      await tester.tap(find.byKey(_confirmClose));
      await tester.pump();
      expect(session.summary!.totalCoins, lessThan(0));
      expect(host.closed, 1);
      expect(find.text(l.shiftClosedToast(0)), findsOneWidget);
      expect(find.textContaining('+-'), findsNothing);
      await _drainToasts(tester);
    });

    testWidgets('Esc ở kết quả (Esc lần hai huỷ); đơn đang ở kết quả vẫn được tính', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      final served = serve(session, 4);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(_confirmClose));
      await tester.pump();
      expect(session.phase, ShiftPhase.aborted);
      expect(session.summary!.served, 1);
      expect(host.closed, 1);
      expect(find.text(l.shiftClosedToast(served.result.net)), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('Back lúc làm bánh → setBaking(false) trước khi đóng', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      session.customerArrived();
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));
      await tester.tap(find.byKey(_start));
      await tester.pump();
      expect(host.baking, [true]);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      await tester.tap(find.byKey(_confirmClose));
      await tester.pump();
      expect(session.phase, ShiftPhase.aborted);
      expect(session.summary!.served, 0);
      expect(host.baking, [true, false]);
      expect(host.closed, 1);
      expect(find.text(l.shiftClosedToast(0)), findsOneWidget);
      await _drainToasts(tester);
      await _teardown(tester);
    });

    testWidgets('Esc lúc làm bánh (GameWidget giữ focus) vẫn hỏi đóng ca; X góc trái dưới cũng vậy', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      session.customerArrived();
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));
      await tester.tap(find.byKey(_start));
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsNothing);

      await tester.tap(find.byKey(_close));
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      await tester.tap(find.byKey(_confirmClose));
      await tester.pump();
      expect(host.baking, [true, false]);
      expect(host.closed, 1);
      await _drainToasts(tester);
      await _teardown(tester);
    });

    testWidgets('Esc sau khi làm bánh xong vẫn tới lớp (lấy lại focus)', (tester) async {
      final l = await shiftL10n('en');
      final game = shiftGame();
      final session = openShift(game);
      session.customerArrived();
      await pumpShiftLayer(tester, session: session, game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      await tester.tap(find.byKey(_start));
      await tester.pump();
      tester.widget<BakeSessionView>(find.byType(BakeSessionView)).onComplete(outcomeFor(session.current.order, 4));
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('đổi sang ca mới (cùng State) → không giữ panel xác nhận của ca trước', (tester) async {
      final l = await shiftL10n('en');
      var game = shiftGame();
      await pumpShiftLayer(tester, session: openShift(game), game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      await tester.tap(find.byKey(_close));
      await tester.pump();
      expect(find.text(l.dayExitConfirmTitle), findsOneWidget);

      game = shiftGame();
      await pumpShiftLayer(tester, session: openShift(game), game: game, host: FakeShiftHost(), ads: AdLog().service(game));
      expect(find.text(l.dayExitConfirmTitle), findsNothing);
      expect(find.byKey(_close), findsOneWidget);
    });

    testWidgets('Back ở tổng kết = "Xong"', (tester) async {
      final game = shiftGame();
      final session = openShift(game);
      final host = FakeShiftHost();
      serveAll(session, 4);
      await pumpShiftLayer(tester, session: session, game: game, host: host, ads: AdLog().service(game));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(host.closed, 1);
      expect(session.phase, ShiftPhase.finished);
    });
  });

  group('§7-7 không tràn chữ', () {
    for (final locale in const ['en', 'vi']) {
      for (final size in const [Size(1280, 720), Size(1600, 720), Size(800, 360)]) {
        testWidgets('$locale @ ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
          Future<void> check(String what, ShiftSession session, CityGame game, {bool confirm = false}) async {
            await pumpShiftLayer(
              tester,
              session: session,
              game: game,
              host: FakeShiftHost(),
              ads: AdLog().service(game),
              locale: locale,
              size: size,
            );
            if (confirm) {
              await tester.tap(find.byKey(_close));
              await tester.pump();
            }
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: what);
            // Thẻ nằm trọn trong màn.
            for (final t in [ResultCard, ShiftSummaryCard, ShiftNewsCard, OrderTicket]) {
              for (final e in find.byType(t).evaluate()) {
                final r = tester.getRect(find.byWidget(e.widget));
                expect(r.left >= -0.5 && r.top >= -0.5 && r.right <= size.width + 0.5 && r.bottom <= size.height + 0.5,
                    isTrue,
                    reason: '$what: $t $r');
              }
            }
          }

          // Mở mới (nhiều món + topping) đè lên khách đầu đang tới.
          var game = shiftGame(level: 9, recipeSeen: 1);
          await check('news', openShift(game), game);

          // Gọi món (vé đơn + nút) — vài seed cho vé khác nhau.
          for (var seed = 0; seed < 3; seed++) {
            game = shiftGame(level: 12);
            final s = openShift(game, seed)..customerArrived();
            await check('ordering $seed', s, game);
          }

          // Kết quả 2★: lời chê + nút làm lại.
          game = shiftGame(level: 12);
          var s = openShift(game);
          serve(s, 2);
          await check('result', s, game);

          // Tổng kết: buff, lên cấp + mở mới.
          game = shiftGame(xp: _xpToLevel2 - 1, fullBuff: true);
          s = openShift(game);
          serveAll(s, 4);
          await check('summary', s, game);

          // Panel xác nhận đóng ca.
          game = shiftGame();
          s = openShift(game)..customerArrived();
          await check('confirm', s, game, confirm: true);
        });
      }
    }
  });
}

/// XP cần để lên cấp 2.
final _xpToLevel2 = PlayerLevel.xpToReach(2);

/// Ca có tổng kết lỗ 40 xu (đơn 1★ lỗ) để kiểm toast đóng ca.
class _LossSession extends ShiftSession {
  _LossSession(CityGame game) : super(game: game, random: math.Random(1));

  @override
  ShiftSummary? get summary {
    final s = super.summary;
    if (s == null) return null;
    return ShiftSummary(
      completed: s.completed,
      served: s.served,
      total: s.total,
      revenue: 0,
      tips: 0,
      costs: 40,
      net: -40,
      buffTips: 0,
      doubledCoins: 0,
      xp: s.xp,
      bonusXp: s.bonusXp,
      levelBefore: s.levelBefore,
      levelAfter: s.levelAfter,
      averageStars: s.averageStars,
      newRecipes: s.newRecipes,
      newToppings: s.newToppings,
      moreCustomers: s.moreCustomers,
      vipGuests: s.vipGuests,
      records: s.records,
    );
  }
}
