import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/shop3d/action_cluster.dart';

/// Cụm nút thao tác cảnh 3D (đặc tả docs/v3/interaction-spec.md 2.2): nút B phân biệt chạm nhanh / nhấn giữ nạp lực,
/// huỷ ngón thì không ném; nút A mờ khi không có việc; hồi chiêu của nút Vẫy; vùng chạm ≥ 48.

class _Log {
  int primary = 0, throwTap = 0, wave = 0, done = 0, cancel = 0;
  final charged = <double>[];
}

const _throw = ValueKey('shop3d-throw');
const _primary = ValueKey('shop3d-primary');
const _wave = ValueKey('shop3d-wave');
const _done = ValueKey('shop3d-done');

Future<_Log> _pump(
  WidgetTester tester, {
  bool primaryEnabled = true,
  bool showThrow = true,
  ValueListenable<double>? cooldown,
  bool visible = true,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = _Log();
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          Shop3dActionCluster(
            primaryLabel: 'Pick up',
            primaryIcon: Icons.back_hand_rounded,
            onPrimary: primaryEnabled ? () => log.primary++ : null,
            showThrow: showThrow,
            throwLabel: 'Throw',
            onThrowTap: () => log.throwTap++,
            onThrowCharged: log.charged.add,
            onThrowCancel: () => log.cancel++,
            waveLabel: 'Wave',
            onWave: () => log.wave++,
            waveCooldown: cooldown,
            doneLabel: 'Done',
            onDone: () => log.done++,
            visible: visible,
          ),
        ],
      ),
    ),
  );
  return log;
}

void main() {
  test(
    'lực ném theo thời gian giữ: < 0,2 s = chạm nhanh; 0,2–0,8 s → 0..1; quá 0,8 s → 1',
    () {
      expect(Shop3dThrowButton.powerFor(Duration.zero), isNull);
      expect(
        Shop3dThrowButton.powerFor(const Duration(milliseconds: 199)),
        isNull,
      );
      expect(Shop3dThrowButton.powerFor(const Duration(milliseconds: 200)), 0);
      expect(
        Shop3dThrowButton.powerFor(const Duration(milliseconds: 500)),
        closeTo(0.5, 1e-9),
      );
      expect(Shop3dThrowButton.powerFor(const Duration(milliseconds: 800)), 1);
      expect(Shop3dThrowButton.powerFor(const Duration(seconds: 3)), 1);
    },
  );

  testWidgets('vị trí theo khung 1280×720 (s = 1)', (tester) async {
    await _pump(tester);
    expect(
      tester.getCenter(find.byKey(_primary)),
      const Offset(1280 - 128, 720 - 128),
    );
    expect(
      tester.getCenter(find.byKey(_throw)),
      const Offset(1280 - 236, 720 - 200),
    );
    expect(
      tester.getCenter(find.byKey(_wave)),
      const Offset(1280 - 252, 720 - 92),
    );
    expect(
      tester.getCenter(find.byKey(_done)),
      const Offset(1280 - 128, 720 - 250),
    );
  });

  testWidgets('nút B: chạm nhanh → onThrowTap, không nạp lực', (tester) async {
    final log = await _pump(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(_throw)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
    expect(log.throwTap, 1);
    expect(log.charged, isEmpty);
    expect(log.cancel, 0);
  });

  testWidgets('nút B: giữ 0,5 s → onThrowCharged ≈ 0,5; giữ lâu → 1', (
    tester,
  ) async {
    final log = await _pump(tester);
    var g = await tester.startGesture(tester.getCenter(find.byKey(_throw)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pump();
    expect(log.throwTap, 0);
    expect(log.charged, hasLength(1));
    expect(log.charged.single, closeTo(0.5, 0.05));

    g = await tester.startGesture(tester.getCenter(find.byKey(_throw)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await g.up();
    await tester.pump();
    expect(log.charged, [closeTo(0.5, 0.05), 1.0]);
    expect(log.throwTap, 0);
  });

  testWidgets('nút B: dùng mốc thời gian của sự kiện chạm khi có', (
    tester,
  ) async {
    final log = await _pump(tester);
    final g = await tester.createGesture();
    await g.down(
      tester.getCenter(find.byKey(_throw)),
      timeStamp: const Duration(seconds: 10),
    );
    await g.up(timeStamp: const Duration(seconds: 10, milliseconds: 650));
    await tester.pump();
    expect(log.charged.single, closeTo(0.75, 1e-6));
  });

  testWidgets('nút B: ngón bị huỷ khi đang nạp → không ném', (tester) async {
    final log = await _pump(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(_throw)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await g.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(log.throwTap, 0);
    expect(log.charged, isEmpty);
    expect(log.cancel, 1);
  });

  testWidgets('nút B ẩn khi không cầm đồ ném được', (tester) async {
    await _pump(tester, showThrow: false);
    expect(find.byKey(_throw), findsNothing);
  });

  testWidgets('nút A: có việc thì gọi; mờ thì không gọi', (tester) async {
    var log = await _pump(tester);
    await tester.tap(find.byKey(_primary));
    expect(log.primary, 1);

    log = await _pump(tester, primaryEnabled: false);
    await tester.tap(find.byKey(_primary), warnIfMissed: false);
    expect(log.primary, 0);
  });

  testWidgets('nút Vẫy: đang hồi chiêu thì bỏ qua chạm', (tester) async {
    final cd = ValueNotifier<double>(0.6);
    addTearDown(cd.dispose);
    final log = await _pump(tester, cooldown: cd);
    await tester.tap(find.byKey(_wave));
    expect(log.wave, 0);
    cd.value = 0;
    await tester.pump();
    await tester.tap(find.byKey(_wave));
    expect(log.wave, 1);
  });

  testWidgets('nút Xong gọi onDone; vùng chạm mọi nút ≥ 48', (tester) async {
    final log = await _pump(tester);
    await tester.tap(find.byKey(_done));
    expect(log.done, 1);
    for (final k in [_primary, _throw, _wave, _done]) {
      final s = tester.getSize(find.byKey(k));
      expect(s.width, greaterThanOrEqualTo(48), reason: '$k');
      expect(s.height, greaterThanOrEqualTo(48), reason: '$k');
    }
  });

  testWidgets('ẩn cụm nút → không nhận chạm', (tester) async {
    final log = await _pump(tester, visible: false);
    await tester.tap(find.byKey(_done), warnIfMissed: false);
    await tester.tap(find.byKey(_primary), warnIfMissed: false);
    expect(log.done, 0);
    expect(log.primary, 0);
    await tester.pump(const Duration(milliseconds: 200));
  });
}
