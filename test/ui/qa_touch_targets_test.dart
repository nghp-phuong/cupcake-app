import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/routes.dart';
import 'package:sugarleaf_bakery/ui/ui_routes.dart';

import 'qa_helpers.dart';
import 'ui_test_helpers.dart';

/// QA: vùng chạm (≥ 48 dp sau khi khung 1280×720 đã co giãn) + tương phản chữ, tai thỏ.

final _routes = <String, (int, String?, Object?)>{
  'bản đồ': (12, null, null),
  'kết quả': (3, AppRoutes.levelResult, LevelResultArgs(fakeLevelResult(3, won: true, stars: 2))),
  'nâng cấp': (40, AppRoutes.upgrades, null),
  'trang trí': (20, AppRoutes.decor, null),
  'sổ công thức': (45, AppRoutes.recipes, null),
  'cửa hàng': (5, AppRoutes.store, null),
  'vé mùa': (8, UiRoutes.season, null),
  'cài đặt': (1, AppRoutes.settings, null),
};

Future<void> _open(WidgetTester tester, (int, String?, Object?) spec) async {
  final state = qaState(LanguagePref.vi, cleared: spec.$1);
  await pumpSugarApp(tester, state, services: testServices(state, levels: qaLevels));
  if (spec.$2 != null) {
    navigator(tester).pushNamed(spec.$2!, arguments: spec.$3);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => qaNow = DateTime(2026, 10, 28, 10));

  group('vùng chạm theo khung tham chiếu (1280×720, dpr 1)', () {
    for (final e in _routes.entries) {
      testWidgets('${e.key}: mọi nút ≥ 48×48', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester, e.value);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
        await tester.pump(const Duration(seconds: 4));
      });
    }
  });

  // Khung 1280×720 bị FittedBox co theo cỡ logic của máy: điện thoại ngang ~800–915 dp → hệ số 0,5–0,57; tablet
  // 1024×768 dp → 0,8. Nút 54 px tham chiếu còn 27–43 dp → SLTapTarget nới vùng chạm (semantics + hit test) ≥ 48 dp
  // mà không đổi hình nút (UI-01).
  group('vùng chạm trên máy thật (khung co lại theo dp)', () {
    for (final vp in qaRealDevices) {
      testWidgets('$vp: mọi nút ≥ 48×48 dp trên mọi màn chính', (tester) async {
        final failures = <String>[];
        for (final e in _routes.entries) {
          final handle = tester.ensureSemantics();
          await _open(tester, e.value);
          vp.apply(tester);
          await tester.pumpAndSettle();
          final result = await androidTapTargetGuideline.evaluate(tester);
          handle.dispose();
          if (!result.passed) failures.add('${e.key}: ${result.reason}');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 4));
        }
        expect(failures, isEmpty);
      });
    }
  });

  group('tương phản chữ', () {
    for (final e in _routes.entries) {
      testWidgets('${e.key}: textContrastGuideline', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester, e.value);
        final result = await textContrastGuideline.evaluate(tester);
        handle.dispose();
        await tester.pump(const Duration(seconds: 4));
        expect(result.passed, isTrue, reason: result.reason);
      });
    }
  });

  group('tai thỏ', () {
    Future<List<String>> underNotch(WidgetTester tester, QaViewport vp) async {
      final bad = <String>[];
      for (final e in _routes.entries) {
        await _open(tester, e.value);
        vp.apply(tester);
        await tester.pumpAndSettle();
        final w = vp.logical.width;
        // Khung 1280×720 sau co giãn (phần ngoài khung bị ClipRect cắt, không chạm được).
        final scale = math.min(w / 1280, vp.logical.height / 720);
        final frame = Rect.fromCenter(
            center: vp.logical.center(Offset.zero), width: 1280 * scale, height: 720 * scale);
        for (final el in find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null).evaluate()) {
          final box = el.renderObject;
          if (box is! RenderBox || !box.hasSize || !box.attached) continue;
          final r = (box.localToGlobal(Offset.zero) & (box.size * scale)).intersect(frame);
          if (r.width <= 0 || r.height <= 0) continue;
          if (r.left < vp.notch || r.right > w - vp.notch) {
            bad.add('${e.key}: nút ở x=${r.left.round()}..${r.right.round()}');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 4));
      }
      return bad;
    }

    testWidgets('máy 19,5:9 (2340×1080 @2.75) tai thỏ 48 dp: viền kem che tai thỏ, không nút nào nằm dưới', (tester) async {
      expect(await underNotch(tester, const QaViewport('2340x1080@2.75', Size(2340, 1080), dpr: 2.75, notch: 48)),
          isEmpty);
    });

    testWidgets('máy 16:9 (1280×720) tai thỏ 48: không nút nào nằm dưới vùng tai thỏ', (tester) async {
      expect(await underNotch(tester, const QaViewport('1280x720+notch48', Size(1280, 720), notch: 48)), isEmpty);
    });
  });
}
