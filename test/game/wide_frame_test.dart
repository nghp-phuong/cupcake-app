import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/bakery_game.dart';
import 'package:sugarleaf_bakery/game/stations/mix_station.dart';
import 'package:sugarleaf_bakery/game/stations/mould_station.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

// Khung rộng (máy 20:9, W = 1600): thế giới 1280×720 nằm giữa, lệch inset = 160. Chạm ở màn x + inset trúng cùng điểm
// thế giới như khung 1280.

const _order = Order(
  id: 0,
  recipe: RecipeId.cupcakeVanilla,
  frosting: FrostingId.vanillaCream,
  toppings: [ToppingRequest(ToppingId.strawberry, 2)],
  box: BoxType.small,
  line: OrderLineKind.generic1,
);

Widget _host(Widget child, {double width = 1600}) => MaterialApp(
      theme: AppTheme.build(locale: const Locale('en'), useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: RefScope(metrics: RefMetrics(width: width), child: child)),
    );

/// Toạ độ thế giới 1280×720 → toạ độ màn test, qua lớp nhận con trỏ [key] (khung W×720 bị FittedBox thu nhỏ).
Offset Function(Offset) _mapper(WidgetTester tester, String key, double width) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  final k = rect.width / width;
  final inset = (width - 1280) / 2;
  return (p) => rect.topLeft + Offset(p.dx + inset, p.dy) * k;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('làm bánh W = 1600: kéo khuôn đúng (màn x + 160) qua trạm; thanh bước chạm mép phải khung', (tester) async {
    await tester.pumpWidget(_host(BakeSessionView(order: _order, modifiers: BakeModifiers.base, onComplete: (_) {})));
    await tester.pump();
    final game = tester.widget<GameWidget<BakeryGame>>(find.byType(GameWidget<BakeryGame>)).game!;
    for (var i = 0; i < 60 && game.currentStation == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.inset, 160);
    final rect = tester.getRect(find.byKey(const ValueKey('bake-session-input')));
    final k = rect.width / 1600;
    // Chữ "Step 1/6" ở mép phải thanh bước: nằm trong dải mở rộng bên phải (sau vùng 1280 giữa).
    final step = tester.getRect(find.text('Step 1/6'));
    expect(step.right, greaterThan(rect.left + (160 + 1280) * k));
    expect(step.right, lessThanOrEqualTo(rect.right));
    // Dải thanh bước lộ tới y 72 (khung): nút thoát bếp đơn đặc biệt của ui (top 84, bám mép trái) không đè lên.
    final bar = tester.getRect(find.ancestor(of: find.text('Step 1/6'), matching: find.byType(IgnorePointer)).first);
    expect(bar.left, lessThan(rect.left));
    expect(bar.right, greaterThan(rect.right));
    expect(bar.bottom, lessThanOrEqualTo(rect.top + 72 * k + 0.01));
    expect(bar.bottom, lessThan(rect.top + 84 * k));

    final g = _mapper(tester, 'bake-session-input', 1600);
    final mould = game.currentStation! as MouldStation;
    final correct = mould.choices.indexOf(MouldType.cupcakeLiner);
    final gesture = await tester.startGesture(g(MouldStation.slotCenter(correct)));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(g(Offset.lerp(MouldStation.slotCenter(correct), MouldStation.trayRect.center, i / steps)!));
    }
    await gesture.up();
    for (var i = 0; i < 32; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.record.wrongMouldDrops, 0);
    expect(game.currentStation, isA<MixStation>());
    // Nút Xong (trạm trộn) nằm trong vùng 1280 giữa: x 1060..1240 thế giới.
    final done = tester.getRect(find.text('Done'));
    expect(done.center.dx, inInclusiveRange(rect.left + (160 + 1060) * k, rect.left + (160 + 1240) * k));
  });
}
