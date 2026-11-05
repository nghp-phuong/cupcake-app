import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_quality.dart';

/// Mức chất lượng đồ họa (shop3d_quality.dart): trần điểm ảnh của web, ghi đè từ tham số, đo FPS tự động.
void main() {
  group('renderScaleFor', () {
    test('không trần: giữ renderScale', () {
      expect(Shop3dGraphics.high.renderScaleFor(1280, 720, 2), 1);
      expect(Shop3dGraphics.low.renderScaleFor(1280, 720, 2), 0.6);
    });

    test('web: màn 1080p giữ nguyên, màn mật độ cao hạ xuống ≈ trần điểm ảnh', () {
      final web = Shop3dGraphics.high.forWeb();
      expect(web.maxRenderPixels, Shop3dGraphics.webMaxRenderPixels);
      expect(web.renderScaleFor(1920, 1080, 1), 1); // 2,07 MP
      expect(web.renderScaleFor(1536, 864, 1.25), 1); // laptop 1080p, Windows 125 %
      for (final (w, h, dpr) in [(1440.0, 900.0, 2.0), (2560.0, 1440.0, 1.0), (1280.0, 720.0, 3.0)]) {
        final s = web.renderScaleFor(w, h, dpr);
        final px = w * h * dpr * dpr * s * s;
        expect(px, closeTo(Shop3dGraphics.webMaxRenderPixels, 1000), reason: '$w×$h@$dpr');
        expect(s, lessThan(1));
      }
      // Mức thấp: 0,6 rồi mới xét trần.
      final low = Shop3dGraphics.low.forWeb();
      expect(low.renderScaleFor(1920, 1080, 1), 0.6);
      expect(low.renderScaleFor(2560, 1600, 2), lessThan(0.6));
      expect(low.renderScaleFor(8000, 8000, 3), 0.25);
    });

    test('forWeb giữ trần đã có; maxpx ghi đè (0 = bỏ trần)', () {
      final custom = Shop3dGraphics.high.copyWith(maxRenderPixels: 1000000);
      expect(custom.forWeb().maxRenderPixels, 1000000);
      final off = Shop3dGraphicsOverrides.fromParams(const {'maxpx': '0'}).apply(Shop3dGraphics.high.forWeb());
      expect(off.maxRenderPixels, 0);
      expect(off.renderScaleFor(2560, 1440, 2), 1);
      final none = Shop3dGraphicsOverrides.fromParams(const {}).apply(Shop3dGraphics.high.forWeb());
      expect(none.maxRenderPixels, Shop3dGraphics.webMaxRenderPixels);
    });
  });

  group('Shop3dQualityProbe', () {
    test('bỏ 2 s đầu, đo 3 s: < 45 fps → low; FPS trung bình', () {
      final p = Shop3dQualityProbe();
      for (final f in [5, 10, 30, 31]) {
        expect(p.addSecond(f), isNull);
      }
      expect(p.addSecond(32), Shop3dQuality.low);
      expect(p.averageFps, closeTo(31, 1e-9));
      expect(p.highRefreshCap(), isNull);
    });

    test('màn 144 Hz: high + giới hạn nửa tần số; màn 60 / 90 Hz không giới hạn', () {
      Shop3dQualityProbe run(int fps) {
        final p = Shop3dQualityProbe();
        for (var i = 0; i < 5; i++) {
          p.addSecond(fps);
        }
        return p;
      }

      final p144 = run(144);
      expect(p144.averageFps, 144);
      expect(p144.highRefreshCap(), 72);
      expect(run(120).highRefreshCap(), 60);
      expect(run(60).highRefreshCap(), isNull);
      expect(run(90).highRefreshCap(), isNull);
    });
  });
}
