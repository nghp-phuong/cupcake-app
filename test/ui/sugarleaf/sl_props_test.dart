import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_cache.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'sl_test_helpers.dart';

/// Toạ độ các điểm cuối của từng đoạn (so sánh hai Path theo hình học).
List<Offset> _samples(Path p) => [
      for (final m in p.computeMetrics())
        for (var i = 0; i < 48; i++) m.getTangentForOffset(m.length * i / 48)!.position,
    ];

void main() {
  setUp(SLPaintCache.debugClear);

  group('vé răng cưa xé tay', () {
    const rect = Rect.fromLTWH(0, 0, 580, 420);

    test('cùng seed → cùng hình; khác seed → răng cưa / lỗ đục khác; luôn nằm trong khung', () {
      final a = const SLTicket(stub: 60, seed: 1).ideal(rect);
      final b = const SLTicket(stub: 60, seed: 1).ideal(rect);
      final c = const SLTicket(stub: 60, seed: 2).ideal(rect);
      expect(_samples(a), _samples(b));
      expect(_samples(a), isNot(_samples(c)));
      final bounds = c.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(rect.left - 0.01));
      expect(bounds.right, lessThanOrEqualTo(rect.right + 0.01));
      expect(bounds.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
      expect(const SLTicket(seed: 1), isNot(const SLTicket(seed: 2)));
    });
  });

  testWidgets('đĩa, bao bột, bóng mềm, khung cắt run tay, icon trên đĩa: dựng được, Picture dùng lại từ cache', (tester) async {
    await pumpSL(
      tester,
      (_) => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 196, height: 44, child: SLPlate()),
            const SizedBox(width: 120, height: 30, child: SLGroundShadow()),
            SizedBox.square(
              dimension: 90,
              child: CustomPaint(painter: _SackPainter()),
            ),
            const SizedBox.square(dimension: 80, child: SLHandClip(seed: 3, child: ColoredBox(color: SLColors.mint))),
            const SLIconDisc('warning', size: 84),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final misses = SLPaintCache.surfaces.misses;
    await tester.pumpWidget(const SizedBox());
    await pumpSL(
      tester,
      (_) => const Center(child: SizedBox(width: 196, height: 44, child: SLPlate())),
    );
    expect(SLPaintCache.surfaces.misses, misses, reason: 'đĩa cùng cỡ/seed lấy lại từ cache');
  });

  test('bao bột: hình ghi một lần theo (cỡ, seed)', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintSLSack(canvas, const Rect.fromLTWH(0, 0, 80, 80), seed: 4);
    final misses = SLPaintCache.surfaces.misses;
    paintSLSack(canvas, const Rect.fromLTWH(30, 10, 80, 80), seed: 4);
    expect(SLPaintCache.surfaces.misses, misses);
    paintSLSack(canvas, const Rect.fromLTWH(0, 0, 60, 60), seed: 4, patch: false);
    expect(SLPaintCache.surfaces.misses, misses + 1);
    recorder.endRecording().dispose();
  });
}

class _SackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintSLSack(canvas, Offset.zero & size, seed: 1);

  @override
  bool shouldRepaint(_SackPainter oldDelegate) => false;
}
