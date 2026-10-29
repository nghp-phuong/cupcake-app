import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/hand_drawn.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_cache.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_icon_art.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_random.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/paint/sl_surface.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sl_theme.dart';

/// Lấy mẫu 64 điểm trên mỗi contour (so sánh hai Path theo hình học).
List<Offset> _samples(Path p) => [
      for (final m in p.computeMetrics())
        for (var i = 0; i < 64; i++) m.getTangentForOffset(m.length * i / 64)!.position,
    ];

bool _same(Path a, Path b) {
  final sa = _samples(a), sb = _samples(b);
  if (sa.length != sb.length) return false;
  for (var i = 0; i < sa.length; i++) {
    if ((sa[i] - sb[i]).distance > 1e-6) return false;
  }
  return true;
}

void main() {
  setUp(SLPaintCache.debugClear);

  group('SLRandom', () {
    test('cùng seed → cùng dãy, khác seed → khác dãy', () {
      final a = SLRandom(42), b = SLRandom(42), c = SLRandom(43);
      final xa = [for (var i = 0; i < 20; i++) a.nextInt32()];
      final xb = [for (var i = 0; i < 20; i++) b.nextInt32()];
      final xc = [for (var i = 0; i < 20; i++) c.nextInt32()];
      expect(xa, xb);
      expect(xa, isNot(xc));
      expect(xa.every((v) => v >= 0 && v <= 0xFFFFFFFF), isTrue);
    });

    test('nextDouble trong [0,1), seed 0 vẫn chạy', () {
      final r = SLRandom(0);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextDouble();
        expect(v >= 0 && v < 1, isTrue);
      }
    });

    test('hashString ổn định giữa các lần chạy (giá trị cố định)', () {
      expect(SLRandom.hashString(''), 5381);
      expect(SLRandom.hashString('Settings'), SLRandom.hashString('Settings'));
      expect(SLRandom.hashString('a'), (5381 * 33) ^ 97);
    });
  });

  group('wobblePath', () {
    final ideal = Path()..addRRect(RRect.fromLTRBR(0, 0, 240, 64, const Radius.circular(18)));

    test('tất định: cùng seed → cùng Path', () {
      expect(_same(wobblePath(ideal, seed: 7, amplitude: 1.5), wobblePath(ideal, seed: 7, amplitude: 1.5)), isTrue);
    });

    test('khác seed → khác Path', () {
      expect(_same(wobblePath(ideal, seed: 7, amplitude: 1.5), wobblePath(ideal, seed: 8, amplitude: 1.5)), isFalse);
    });

    test('độ run nằm trong biên độ (không méo hình)', () {
      final w = wobblePath(ideal, seed: 3, amplitude: 1.5).getBounds();
      expect(w.left, closeTo(0, 3));
      expect(w.top, closeTo(0, 3));
      expect(w.right, closeTo(240, 3));
      expect(w.bottom, closeTo(64, 3));
    });

    test('mọi hình dựng được và khép kín', () {
      const rect = Rect.fromLTWH(0, 0, 300, 160);
      for (final shape in const <SLShape>[
        SLRoundRect(18),
        SLRoundRect(14, topOnly: true),
        SLCircle(),
        SLRibbon(),
        SLTicket(),
        SLBubble(),
        SLBubble(tail: SLTail.left, tailAt: 0.7),
        SLBubble(tail: SLTail.top),
        SLBubble(tail: SLTail.right),
        SLTapeShape(),
      ]) {
        final p = wobblePath(shape.ideal(rect), seed: 1, amplitude: 1.5);
        final metrics = p.computeMetrics().toList();
        expect(metrics, isNotEmpty, reason: '$shape');
        expect(metrics.first.isClosed, isTrue, reason: '$shape');
      }
    });
  });

  group('nét lố', () {
    test('gốc nét lố luôn nằm trên đường viền đã run (không thành vạch rời), dài ≤ kSLOvershootMax', () {
      const rects = [Rect.fromLTWH(0, 0, 240, 64), Rect.fromLTWH(0, 0, 580, 300), Rect.fromLTWH(0, 0, 120, 120)];
      const shapes = <SLShape>[SLRoundRect(18), SLRoundRect(26), SLRoundRect(14, topOnly: true), SLCircle()];
      var checked = 0;
      for (final rect in rects) {
        for (final shape in shapes) {
          for (var seed = 0; seed < 40; seed++) {
            final outline = wobblePath(shape.ideal(rect), seed: seed, amplitude: 1.8);
            final anchors = shape.overshootAnchors(rect, SLRandom(seed));
            final strokes = overshootStrokes(outline, anchors, SLRandom(seed + 1));
            final m = outline.computeMetrics().first;
            for (final s in strokes.computeMetrics()) {
              checked++;
              expect(s.length, lessThanOrEqualTo(kSLOvershootMax + 0.7));
              // Điểm cách gốc 0,6px (tâm nét viền) phải nằm trên đường viền.
              final root = s.getTangentForOffset(0.6)!.position;
              var best = double.infinity;
              for (var d = 0.0; d < m.length; d += 0.5) {
                best = math.min(best, (m.getTangentForOffset(d)!.position - root).distance);
              }
              expect(best, lessThan(0.6), reason: '$shape $rect seed $seed');
            }
          }
        }
      }
      expect(checked, greaterThan(100));
    });
  });

  group('cache', () {
    const spec = SLSurfaceSpec(shape: SLRoundRect(18), material: SLMaterial.wash, color: SLColors.strawberry, sticker: true, seed: 5);

    test('lần hai lấy từ cache, không dựng lại', () {
      final a = slSurfaceArt(spec, const Size(240, 64));
      final b = slSurfaceArt(spec, const Size(240.3, 63.8)); // làm tròn 1px → cùng khoá.
      expect(identical(a, b), isTrue);
      expect(SLPaintCache.surfaces.misses, 1);
      expect(SLPaintCache.surfaces.hits, 1);
    });

    test('khác seed / màu / cỡ → mục khác', () {
      slSurfaceArt(spec, const Size(240, 64));
      slSurfaceArt(spec.copyWith(seed: 6), const Size(240, 64));
      slSurfaceArt(spec.copyWith(color: SLColors.mint), const Size(240, 64));
      slSurfaceArt(spec, const Size(200, 64));
      expect(SLPaintCache.surfaces.misses, 4);
      expect(SLPaintCache.surfaces.length, 4);
    });

    test('LRU giới hạn ${SLPaintCache.maxEntries} mục, đẩy mục cũ nhất', () {
      final first = slSurfaceArt(spec, const Size(10, 10));
      for (var i = 0; i < SLPaintCache.maxEntries + 10; i++) {
        slSurfaceArt(spec.copyWith(seed: 1000 + i), const Size(40, 20));
      }
      expect(SLPaintCache.surfaces.length, SLPaintCache.maxEntries);
      final again = slSurfaceArt(spec, const Size(10, 10));
      expect(identical(first, again), isFalse); // đã bị đẩy ra → dựng lại.
    });

    test('icon: cache theo id/cỡ/màu', () {
      final a = slIconArt('settings', 32);
      final b = slIconArt('settings', 32);
      final c = slIconArt('settings', 32, dimmed: true);
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
      expect(SLPaintCache.icons.misses, 2);
      for (final id in kSLIconIds) {
        expect(() => slIconArt(id, 40), returnsNormally, reason: id);
      }
    });
  });

  test('hiệu năng: dựng (cache lạnh) và vẽ lại (cache nóng)', () {
    const sizes = [Size(240, 64), Size(56, 56), Size(420, 260)];
    final specs = [
      for (var i = 0; i < 20; i++) ...[
        SLSurfaceSpec(shape: const SLRoundRect(18), material: SLMaterial.wash, color: SLColors.strawberry, sticker: true, seed: i),
        SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: SLColors.paper, sticker: true, seed: i),
        SLSurfaceSpec(shape: const SLRoundRect(26), color: SLColors.paper, seed: i),
      ],
    ];
    // Hâm nóng JIT.
    for (var i = 0; i < 5; i++) {
      buildSurfaceArt(specs[i % 3], sizes[i % 3]).dispose();
    }
    SLPaintCache.debugClear();

    final cold = Stopwatch()..start();
    for (var i = 0; i < specs.length; i++) {
      slSurfaceArt(specs[i], sizes[i % 3]);
    }
    cold.stop();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const frames = 50;
    final hot = Stopwatch()..start();
    for (var f = 0; f < frames; f++) {
      for (var i = 0; i < specs.length; i++) {
        SLSurfacePainter(spec: specs[i], lift: 4).paint(canvas, sizes[i % 3]);
      }
    }
    hot.stop();
    recorder.endRecording().dispose();

    final coldMs = cold.elapsedMicroseconds / specs.length / 1000;
    final hotMs = hot.elapsedMicroseconds / (frames * specs.length) / 1000;
    final frameMs = hot.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print('SL paint: dựng lạnh ${coldMs.toStringAsFixed(3)} ms/hình · vẽ từ cache ${hotMs.toStringAsFixed(4)} ms/hình · '
        '${specs.length} hình/khung ${frameMs.toStringAsFixed(3)} ms/khung (debug JIT)');
    expect(SLPaintCache.surfaces.misses, specs.length);
    expect(hotMs, lessThan(coldMs / 5));
    // 60 khung hình trên giây = 16,7 ms/khung; 60 bề mặt từ cache phải tốn rất ít.
    expect(frameMs, lessThan(4));
  });
}
