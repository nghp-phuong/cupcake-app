import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/shop3d/staff_menu.dart';

/// Menu khi chạm nhân viên (đặc tả docs/v3/interaction-spec.md 2.3): 2 nút 168×48 trên đầu nhân vật, tự đóng sau
/// 5 s, chạm ra ngoài thì đóng (và chạm vẫn tới cảnh).

class _Log {
  int control = 0, talk = 0, dismiss = 0, below = 0;
}

const _control = ValueKey('shop3d-staff-control');
const _talk = ValueKey('shop3d-staff-talk');

Future<_Log> _pump(
  WidgetTester tester, {
  Offset anchor = const Offset(640, 300),
  _Log? log,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final l = log ?? _Log();
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => l.below++,
            ),
          ),
          Shop3dStaffMenu(
            anchor: anchor,
            controlLabel: 'Control',
            talkLabel: 'Talk to guests',
            onControl: () => l.control++,
            onTalk: () => l.talk++,
            onDismiss: () => l.dismiss++,
          ),
        ],
      ),
    ),
  );
  return l;
}

void main() {
  testWidgets('2 nút 168×48 xếp chồng, đáy menu ngay trên điểm neo', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    final a = tester.getRect(find.byKey(_control));
    final b = tester.getRect(find.byKey(_talk));
    expect(a.size, const Size(168, 48));
    expect(b.size, const Size(168, 48));
    expect(b.top, greaterThan(a.bottom - 1e-6));
    expect(a.center.dx, closeTo(640, 1e-6));
    expect(b.bottom, lessThanOrEqualTo(300));
  });

  testWidgets('tự đóng sau 5 s, chỉ gọi onDismiss một lần', (tester) async {
    final log = await _pump(tester);
    await tester.pump(const Duration(milliseconds: 4900));
    expect(log.dismiss, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(log.dismiss, 1);
    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(const Offset(20, 20));
    expect(log.dismiss, 1);
  });

  testWidgets('chạm ra ngoài → đóng, chạm vẫn tới cảnh bên dưới', (
    tester,
  ) async {
    final log = await _pump(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 600));
    expect(log.dismiss, 1);
    expect(log.below, 1);
  });

  testWidgets(
    'chọn Điều khiển / Nói chuyện gọi đúng callback, không tự đóng sau đó',
    (tester) async {
      var log = await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_control));
      expect(log.control, 1);
      expect(log.below, 0, reason: 'chạm nút menu không xuống cảnh');
      await tester.pump(const Duration(seconds: 6));
      expect(log.dismiss, 0);

      // Đổi key → menu mới (bộ hẹn giờ mới).
      log = _Log();
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, log: log);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_talk));
      expect(log.talk, 1);
      expect(log.dismiss, 0);
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('neo sát mép trên trái → menu kẹp trong màn', (tester) async {
    await _pump(tester, anchor: const Offset(10, 20));
    await tester.pumpAndSettle();
    final a = tester.getRect(find.byKey(_control));
    expect(a.left, greaterThanOrEqualTo(8));
    expect(a.top, greaterThanOrEqualTo(8));
    await tester.pump(const Duration(seconds: 6));
  });
}
