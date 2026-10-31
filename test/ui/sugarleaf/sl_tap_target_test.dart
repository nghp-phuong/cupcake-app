import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'sl_test_helpers.dart';

/// SLTapTarget (UI-01): nút nhỏ (do khung co) được nới VÙNG CHẠM tới ≥ 48 dp, hình giữ nguyên; hai vùng nới chồng nhau
/// → nút gần điểm chạm thắng; vùng SLNoTapExpand (sân chơi) không bị nới chạm.

Widget _box(String key, List<String> log, {bool enabled = true}) => SLPressable(
      key: ValueKey(key),
      semanticLabel: key,
      onPressed: enabled ? () => log.add(key) : null,
      builder: (context, press) => const SizedBox(width: 40, height: 40, child: ColoredBox(color: SLColors.mint)),
    );

/// Hai nút 40×40 cách nhau 10 px, co 0,5 (giống khung 1280×720 trên điện thoại 360 dp cao) → 20×20 dp, khe 5 dp.
Future<List<String>> _pumpPair(WidgetTester tester, {bool bEnabled = true}) async {
  final log = <String>[];
  await pumpSL(
    tester,
    (_) => Center(
      child: Transform.scale(
        scale: 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_box('a', log), const SizedBox(width: 10), _box('b', log, enabled: bEnabled)],
        ),
      ),
    ),
  );
  return log;
}

void main() {
  testWidgets('hình nút giữ nguyên cỡ, vùng chạm (semantics) ≥ 48 dp', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPair(tester);
    expect(tester.getSize(find.byKey(const ValueKey('a'))), const Size(40, 40));
    expect(tester.getRect(find.byKey(const ValueKey('a'))).width, closeTo(20, 0.01));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('chạm ngoài hình nút nhưng trong vùng nới → nút nhận chạm', (tester) async {
    final log = await _pumpPair(tester);
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    await tester.tapAt(a.centerLeft - const Offset(10, 0));
    await tester.tapAt(a.topCenter - const Offset(0, 12));
    await tester.tapAt(a.bottomCenter + const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 500));
    expect(log, ['a', 'a', 'a']);
  });

  testWidgets('ngoài vùng nới → không nút nào', (tester) async {
    final log = await _pumpPair(tester);
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    await tester.tapAt(a.centerLeft - const Offset(20, 0));
    await tester.tapAt(a.topCenter - const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 500));
    expect(log, isEmpty);
  });

  testWidgets('hai vùng nới chồng nhau → nút gần điểm chạm thắng, mỗi chạm một nút', (tester) async {
    final log = await _pumpPair(tester);
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    final b = tester.getRect(find.byKey(const ValueKey('b')));
    expect(b.left - a.right, closeTo(5, 0.01));
    await tester.tapAt(Offset(a.right + 1, a.center.dy));
    await tester.tapAt(Offset(b.left - 1, b.center.dy));
    // Chạm thẳng vào hình nút luôn là nút đó.
    await tester.tapAt(b.center);
    await tester.tapAt(Offset(a.right - 1, a.center.dy));
    await tester.pump(const Duration(milliseconds: 500));
    expect(log, ['a', 'b', 'b', 'a']);
  });

  testWidgets('nút tắt không giành chạm nới của nút bên cạnh', (tester) async {
    final log = await _pumpPair(tester, bEnabled: false);
    final b = tester.getRect(find.byKey(const ValueKey('b')));
    await tester.tapAt(Offset(b.left - 1, b.center.dy));
    await tester.pump(const Duration(milliseconds: 500));
    expect(log, ['a']);
  });

  testWidgets('SLNoTapExpand: chạm ở sân chơi cạnh nút không thành bấm nút', (tester) async {
    final log = <String>[];
    var field = 0;
    await pumpSL(
      tester,
      (_) => Stack(
        children: [
          Positioned.fill(
            child: SLNoTapExpand(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => field++),
            ),
          ),
          Center(child: Transform.scale(scale: 0.5, child: _box('a', log))),
        ],
      ),
    );
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    await tester.tapAt(a.centerLeft - const Offset(10, 0));
    await tester.tapAt(a.center);
    await tester.pump(const Duration(milliseconds: 500));
    expect(field, 1);
    expect(log, ['a']);
  });
}
