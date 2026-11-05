import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/shop3d/joystick.dart';

/// Joystick cảnh 3D (đặc tả docs/v3/interaction-spec.md 2.1): vùng chết, chạy có trễ, ngón thứ hai bị bỏ qua,
/// pointer cancel về 0, chỉ vùng tròn 120·s nhận chạm.

const _travel = 52.0;

Offset _at(double m) => Offset(m * _travel, 0);

Future<int Function()> _pump(
  WidgetTester tester,
  Shop3dJoystickController c, {
  bool visible = true,
}) async {
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
          Shop3dJoystick(controller: c, visible: visible),
        ],
      ),
    ),
  );
  return () => below;
}

void main() {
  group('Shop3dJoystickController', () {
    test(
      'vùng chết: độ lớn < 0,15 → 0; ngoài vùng chết giữ nguyên độ lớn; kẹp vào hình tròn đơn vị',
      () {
        final c = Shop3dJoystickController();
        addTearDown(c.dispose);
        expect(c.begin(1, _at(0.1), _travel), isTrue);
        expect(c.value.value, Offset.zero);
        expect(c.knob.value.dx, closeTo(0.1, 1e-9));
        expect(c.active.value, isTrue);

        c.move(1, _at(0.14), _travel);
        expect(c.value.value, Offset.zero);
        c.move(1, _at(0.2), _travel);
        expect(c.value.value.dx, closeTo(0.2, 1e-9));

        c.move(1, const Offset(300, 400), _travel);
        expect(c.value.value.distance, closeTo(1, 1e-9));
        expect(c.value.value.dx, closeTo(0.6, 1e-9));
        expect(c.value.value.dy, closeTo(0.8, 1e-9));
      },
    );

    test('chạy: vào khi ≥ 0,8, chỉ thôi khi < 0,75', () {
      final c = Shop3dJoystickController();
      addTearDown(c.dispose);
      c.begin(1, _at(0.79), _travel);
      expect(c.running.value, isFalse);
      c.move(1, _at(0.8), _travel);
      expect(c.running.value, isTrue);
      c.move(1, _at(0.77), _travel);
      expect(
        c.running.value,
        isTrue,
        reason: 'trong khoảng trễ 0,75–0,8 vẫn chạy',
      );
      c.move(1, _at(0.75), _travel);
      expect(c.running.value, isTrue);
      c.move(1, _at(0.74), _travel);
      expect(c.running.value, isFalse);
      c.move(1, _at(0.78), _travel);
      expect(
        c.running.value,
        isFalse,
        reason: 'chưa tới 0,8 thì chưa chạy lại',
      );
      c.move(1, _at(1), _travel);
      expect(c.running.value, isTrue);
    });

    test('ngón thứ hai bị bỏ qua; nhấc ngón đang giữ → về 0', () {
      final c = Shop3dJoystickController();
      addTearDown(c.dispose);
      c.begin(1, _at(0.5), _travel);
      expect(c.begin(2, _at(-0.9), _travel), isFalse);
      c.move(2, _at(-1), _travel);
      expect(c.value.value.dx, closeTo(0.5, 1e-9));
      c.end(2);
      expect(c.pointer, 1);
      expect(c.value.value.dx, closeTo(0.5, 1e-9));
      c.end(1);
      expect(c.pointer, isNull);
      expect(c.value.value, Offset.zero);
      expect(c.running.value, isFalse);
      expect(c.active.value, isFalse);
      expect(
        c.begin(2, _at(0.3), _travel),
        isTrue,
        reason: 'thả rồi thì ngón mới bắt được',
      );
    });

    test('reset: về 0, thôi chạy; drive chỉ khi không có ngón', () {
      final c = Shop3dJoystickController();
      addTearDown(c.dispose);
      c.begin(1, _at(1), _travel);
      expect(c.running.value, isTrue);
      c.drive(const Offset(-1, 0));
      expect(
        c.value.value.dx,
        closeTo(1, 1e-9),
        reason: 'đang có ngón giữ thì bàn phím không đè',
      );
      c.reset();
      expect(c.value.value, Offset.zero);
      expect(c.running.value, isFalse);
      c.drive(const Offset(0, -1));
      expect(c.value.value, const Offset(0, -1));
      expect(c.running.value, isTrue);
      expect(c.active.value, isTrue);
      c.drive(Offset.zero);
      expect(c.active.value, isFalse);
      expect(c.value.value, Offset.zero);
    });
  });

  group('Shop3dJoystickGeometry', () {
    test(
      'khung 1280×720: tâm (150, 570), s = 1; mép đế ≥ 80 dp; cộng phần lấn mép',
      () {
        final g = Shop3dJoystickGeometry.of(const Size(1280, 720));
        expect(g.scale, 1);
        expect(g.center, const Offset(150, 570));
        expect(g.travel, 52);
        expect(g.hitRadius, 120);

        final small = Shop3dJoystickGeometry.of(const Size(800, 360));
        expect(small.scale, 0.85);
        expect(
          small.center.dx - small.baseRadius,
          greaterThanOrEqualTo(80 - 1e-9),
        );

        final inset = Shop3dJoystickGeometry.of(
          const Size(1280, 720),
          padding: const EdgeInsets.only(left: 40, bottom: 10),
          gestureInsets: const EdgeInsets.only(left: 30, bottom: 24),
        );
        expect(inset.center, const Offset(190, 546));
        expect(inset.contains(const Offset(29, 546)), isFalse);
        expect(inset.contains(const Offset(190, 546)), isTrue);
        expect(inset.contains(const Offset(190 + 121, 546)), isFalse);
      },
    );
  });

  group('Shop3dJoystick (widget)', () {
    testWidgets(
      'ngón trong vùng nhận điều khiển; ngón thứ hai bị bỏ qua; pointer cancel về 0',
      (tester) async {
        final c = Shop3dJoystickController();
        addTearDown(c.dispose);
        final below = await _pump(tester, c);
        const center = Offset(150, 570);

        final g1 = await tester.startGesture(
          center + const Offset(26, 0),
          pointer: 1,
        );
        expect(c.pointer, 1);
        expect(c.value.value.dx, closeTo(0.5, 1e-6));
        expect(below(), 0, reason: 'ngón joystick không xuống lớp camera');

        await g1.moveTo(center + const Offset(0, -80));
        expect(c.value.value.dy, closeTo(-1, 1e-6));
        expect(c.running.value, isTrue);

        final g2 = await tester.startGesture(
          center + const Offset(-30, 10),
          pointer: 2,
        );
        await g2.moveTo(center + const Offset(-60, 40));
        expect(c.pointer, 1);
        expect(c.value.value.dy, closeTo(-1, 1e-6));
        await g2.up();
        expect(c.pointer, 1);

        await g1.cancel();
        expect(c.pointer, isNull);
        expect(c.value.value, Offset.zero);
        expect(c.running.value, isFalse);
        await tester.pump();
      },
    );

    testWidgets('nhấc ngón → về 0; chạm ngoài bán kính 120 đi xuống cảnh', (
      tester,
    ) async {
      final c = Shop3dJoystickController();
      addTearDown(c.dispose);
      final below = await _pump(tester, c);
      const center = Offset(150, 570);

      final g = await tester.startGesture(center + const Offset(6, 0));
      expect(
        c.value.value,
        Offset.zero,
        reason: '6/52 ≈ 0,115 < 0,15 → vùng chết',
      );
      expect(c.pointer, isNotNull);
      await g.moveTo(center + const Offset(40, 0));
      expect(c.value.value.dx, closeTo(40 / 52, 1e-6));
      await g.up();
      expect(c.value.value, Offset.zero);

      final out = await tester.startGesture(
        center + const Offset(100, 100),
        pointer: 5,
      );
      expect(c.pointer, isNull);
      expect(below(), 1);
      await out.up();
      await tester.pump();
    });

    testWidgets('ẩn → không nhận chạm và controller được thả', (tester) async {
      final c = Shop3dJoystickController();
      addTearDown(c.dispose);
      await _pump(tester, c);
      const center = Offset(150, 570);
      final g = await tester.startGesture(center + const Offset(52, 0));
      expect(c.running.value, isTrue);

      await _pump(tester, c, visible: false);
      expect(c.pointer, isNull);
      expect(c.value.value, Offset.zero);
      await g.moveTo(center + const Offset(0, 52));
      expect(c.value.value, Offset.zero);
      await g.up();

      final g2 = await tester.startGesture(center);
      expect(c.pointer, isNull);
      await g2.up();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
