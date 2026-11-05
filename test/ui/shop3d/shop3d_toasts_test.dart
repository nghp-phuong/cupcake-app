import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/shop3d/shop3d_toasts.dart';

/// Lớp phủ nhỏ cảnh 3D: toast tự ẩn, banner sự kiện 2 nút, bong bóng trên đầu không chặn chạm, chip tên chọn khách,
/// mũi tên đích.

Future<int Function()> _pump(WidgetTester tester, List<Widget> overlays) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var below = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => below++,
            ),
          ),
          ...overlays,
        ],
      ),
    ),
  );
  return () => below;
}

void main() {
  test('hệ số s = H/720 kẹp 0,85–1,4', () {
    expect(Shop3dStyle.scaleOf(const Size(1280, 720)), 1);
    expect(Shop3dStyle.scaleOf(const Size(800, 360)), 0.85);
    expect(Shop3dStyle.scaleOf(const Size(2400, 1080)), 1.4);
    expect(Shop3dStyle.scaleOf(const Size(1600, 864)), closeTo(1.2, 1e-9));
  });

  testWidgets('toast hiện rồi tự ẩn; toast mới thay toast cũ', (tester) async {
    final c = Shop3dToastController();
    addTearDown(c.dispose);
    await _pump(tester, [Shop3dToastHost(controller: c)]);
    c.show('+2 hearts · +5 coins');
    await tester.pump();
    expect(find.text('+2 hearts · +5 coins'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    c.show('Pick a guest to chat with');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Pick a guest to chat with'), findsOneWidget);
    expect(find.text('+2 hearts · +5 coins'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pick a guest to chat with'), findsNothing);
    expect(c.current.value, isNull);
  });

  testWidgets(
    'banner sự kiện: 2 nút gọi đúng callback; ngoài banner chạm tới cảnh',
    (tester) async {
      var watch = 0, go = 0;
      final below = await _pump(tester, [
        Shop3dEventBanner(
          message: 'Something noisy is happening outside!',
          primaryLabel: 'Look',
          onPrimary: () => watch++,
          secondaryLabel: 'Mai goes out',
          onSecondary: () => go++,
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look'));
      await tester.tap(find.text('Mai goes out'));
      expect(watch, 1);
      expect(go, 1);
      expect(below(), 0);
      await tester.tapAt(const Offset(640, 400));
      expect(below(), 1);
    },
  );

  testWidgets(
    'bong bóng trên đầu: đáy đuôi ngay trên điểm neo, không chặn chạm',
    (tester) async {
      final below = await _pump(tester, [
        const Shop3dHeadBubble(anchor: Offset(400, 300), text: 'Thank you!'),
        const Shop3dHeadBubble(
          anchor: Offset(700, 300),
          text: '!',
          kind: Shop3dBubbleKind.puff,
        ),
        const Shop3dHeadBubble(
          anchor: Offset(900, 300),
          text: 'Oh!',
          kind: Shop3dBubbleKind.exclaim,
        ),
        const Shop3dHeadBubble(
          anchor: Offset(1100, 300),
          text: '…',
          kind: Shop3dBubbleKind.thinking,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final r = tester.getRect(find.text('Thank you!'));
      expect(r.bottom, lessThan(300));
      expect(r.center.dx, closeTo(400, 1));
      await tester.tapAt(r.center);
      expect(below(), 1);
    },
  );

  testWidgets('chip tên: chạm gọi onTap, vùng chạm cao ≥ 48', (tester) async {
    var picked = 0;
    final below = await _pump(tester, [
      Shop3dNameChip(
        key: const ValueKey('chip'),
        anchor: const Offset(500, 260),
        label: 'Linh',
        onTap: () => picked++,
      ),
    ]);
    await tester.pumpAndSettle();
    // Hộp nhận chạm (đã dịch lên trên điểm neo).
    final r = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('chip')),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(r.height, greaterThanOrEqualTo(48));
    expect(r.bottom, closeTo(260, 1));
    await tester.tap(find.text('Linh'));
    expect(picked, 1);
    expect(below(), 0);
  });

  testWidgets('mũi tên đích nhấp nhô (không chặn chạm, không lỗi)', (
    tester,
  ) async {
    final below = await _pump(tester, [
      const Shop3dTargetArrow(anchor: Offset(600, 200)),
    ]);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(600, 190));
    expect(below(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
