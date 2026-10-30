import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/cake_art.dart';
import 'package:sugarleaf_bakery/core/art/item_art.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

/// Bundle rỗng: không có ảnh nào → CakeArt vẽ hình code dự phòng.
class _EmptyBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    throw StateError('Unable to load asset: "$key".');
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async => parser(await loadString(key));
}

const _n = 400;
const _rect = Rect.fromLTWH(0, 0, 400, 400);

/// Khung alpha (> 20) của hình vẽ.
Future<Rect> _alphaBox(void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_n, _n);
  final data = (await image.toByteData())!;
  image.dispose();
  var l = _n, r = -1, t = _n, b = -1;
  for (var y = 0; y < _n; y++) {
    for (var x = 0; x < _n; x++) {
      if (data.getUint8((y * _n + x) * 4 + 3) > 20) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  return r < 0 ? Rect.zero : Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0);
}

double _luma(List<double> m, Color c) {
  double ch(int i) => (m[i * 5] * c.r * 255 + m[i * 5 + 1] * c.g * 255 + m[i * 5 + 2] * c.b * 255 + m[i * 5 + 4]).clamp(0, 255);
  return 0.299 * ch(0) + 0.587 * ch(1) + 0.114 * ch(2);
}

/// Bột/khuôn đại diện cho mỗi khuôn (cùng khung hình cho mọi biến thể ảnh).
const _batters = {
  MouldType.cupcakeLiner: BatterType.vanilla,
  MouldType.muffinCup: BatterType.vanilla,
  MouldType.tartShell: BatterType.butter,
  MouldType.roundPan: BatterType.vanilla,
  MouldType.macaronMat: BatterType.almond,
  MouldType.springformPan: BatterType.cheese,
  MouldType.tallPan: BatterType.vanilla,
  MouldType.pastryTray: BatterType.laminated,
  MouldType.shellMould: BatterType.butter,
  MouldType.eclairTray: BatterType.choux,
  MouldType.piePan: BatterType.butter,
  MouldType.mooncakeMould: BatterType.mooncake,
  MouldType.logPan: BatterType.chocolate,
};

/// Khuôn có ảnh đế gốc (`baked/<khuôn>`). Khuôn GĐ8 chỉ có ảnh theo món (xem recipes_gd8_test).
final _artMoulds = [
  for (final m in MouldType.values)
    if (ArtSprites.ids[ArtGroup.baked]!.contains(m.name)) m,
];

void main() {
  tearDown(ArtSprites.debugReset);

  test('mặt bánh nằm trong vùng ảnh và trong khung, co giãn theo khung', () {
    for (final m in MouldType.values) {
      for (final rect in const [Rect.fromLTWH(0, 0, 400, 400), Rect.fromLTWH(220, 190, 460, 460), Rect.fromLTWH(10, 20, 130, 90)]) {
        final top = CakeArt.topSurface(rect, m);
        final body = CakeArt.artBodyRect(rect, m);
        expect(body.inflate(0.5).contains(top.topLeft) && body.inflate(0.5).contains(top.bottomRight), isTrue, reason: '$m $rect');
        expect(rect.inflate(0.5).contains(body.topLeft) && rect.inflate(0.5).contains(body.bottomRight), isTrue, reason: '$m $rect');
        // Elip mặt bánh nằm ngang, không suy biến.
        expect(top.width, greaterThan(top.height));
        expect(top.height, greaterThan(rect.shortestSide * 0.05));
      }
      final a = CakeArt.topSurface(const Rect.fromLTWH(0, 0, 100, 100), m);
      final b = CakeArt.topSurface(const Rect.fromLTWH(0, 0, 200, 200), m);
      expect(b.width, closeTo(a.width * 2, 1e-6));
      expect(b.center.dy, closeTo(a.center.dy * 2, 1e-6));
    }
  });

  test('ColorFilter theo độ chín: sống sáng hơn → chín = nguyên ảnh → cháy sẫm dần', () {
    for (final b in BatterType.values) {
      final identity = CakeArt.bakeMatrix(b, 1);
      expect(identity, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
      // Mẫu: màu bánh chín của chính loại bột + vài màu trung tính/sẫm có trên ảnh.
      for (final sample in [ItemArt.bakedColor(b, 1), const Color(0xFF5A3A2A), const Color(0xFF9A8070)]) {
        var prev = double.infinity;
        for (var i = 0; i <= 20; i++) {
          final l = _luma(CakeArt.bakeMatrix(b, i / 10), sample);
          expect(l, lessThanOrEqualTo(prev + 1e-6), reason: '$b baked=${i / 10} $sample');
          prev = l;
        }
        // Cháy sẫm rõ so với chín.
        expect(_luma(CakeArt.bakeMatrix(b, 2), sample), lessThan(_luma(identity, sample) * 0.6));
      }
      // Ngoài thang thì kẹp lại.
      expect(CakeArt.bakeMatrix(b, -1), CakeArt.bakeMatrix(b, 0));
      expect(CakeArt.bakeMatrix(b, 3), CakeArt.bakeMatrix(b, 2));
    }
  });

  testWidgets('thiếu ảnh: vẽ hình code dự phòng, không lỗi', (tester) async {
    ArtSprites.debugReset(bundle: _EmptyBundle());
    await tester.runAsync(() async {
      for (final m in MouldType.values) {
        final v = CakeVisual(mould: m, batter: _batters[m]!, frosting: FrostingId.vanillaCream, toppings: const {ToppingId.cherry: 2});
        CakeArt.paint(Canvas(ui.PictureRecorder()), _rect, v); // xếp hàng nạp → xác định thiếu
        await ArtSprites.preload([ArtSprites.baked(m, v.batter), ArtSprites.topping(ToppingId.cherry)]);
        expect(ArtSprites.baked(m, v.batter).isMissing, isTrue);
        final box = await _alphaBox((c) => CakeArt.paint(c, _rect, v));
        expect(box.width, greaterThan(_n * 0.5), reason: '$m');
      }
    }).timeout(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('bánh ảnh chiếm cùng bề rộng và đáy như hình code', (tester) async {
    final code = <MouldType, Rect>{};
    await tester.runAsync(() async {
      ArtSprites.debugReset(bundle: _EmptyBundle());
      await ArtSprites.preload([for (final m in _artMoulds) ArtSprites.baked(m, _batters[m]!)]);
      for (final m in _artMoulds) {
        code[m] = await _alphaBox((c) => CakeArt.paint(c, _rect, CakeVisual(mould: m, batter: _batters[m]!)));
      }
      ArtSprites.debugReset();
      await ArtSprites.preload([for (final m in _artMoulds) ArtSprites.baked(m, _batters[m]!)]);
      for (final m in _artMoulds) {
        expect(ArtSprites.baked(m, _batters[m]!).image, isNotNull, reason: '$m');
        final art = await _alphaBox((c) => CakeArt.paint(c, _rect, CakeVisual(mould: m, batter: _batters[m]!)));
        const tol = _n * 0.02;
        expect(art.left, closeTo(code[m]!.left, tol), reason: '$m trái');
        expect(art.right, closeTo(code[m]!.right, tol), reason: '$m phải');
        expect(art.bottom, closeTo(code[m]!.bottom, tol), reason: '$m đáy');
        // Ảnh không tràn khỏi khung.
        expect(art.top, greaterThanOrEqualTo(0));
        // Khung ảnh tính sẵn (artBodyRect) khớp hình thật.
        final body = CakeArt.artBodyRect(_rect, m);
        expect(art.left, closeTo(body.left, tol));
        expect(art.bottom, closeTo(body.bottom, tol));

        // Kem + topping vẽ trên ảnh không làm bánh lệch đáy, và nằm trong khung.
        final full = await _alphaBox((c) => CakeArt.paint(
              c,
              _rect,
              CakeVisual(mould: m, batter: _batters[m]!, frosting: FrostingId.strawberryCream, toppings: const {ToppingId.strawberry: 2}),
            ));
        expect(full.bottom, closeTo(art.bottom, tol), reason: '$m kem');
        expect(full.top, greaterThanOrEqualTo(0));
      }
    }).timeout(const Duration(seconds: 60));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('độ chín đổi màu ảnh: cháy tối hơn chín, sống sáng hơn chín', (tester) async {
    double lumaAt(ByteData d, int x, int y) {
      final i = (y * _n + x) * 4;
      return 0.299 * d.getUint8(i) + 0.587 * d.getUint8(i + 1) + 0.114 * d.getUint8(i + 2);
    }

    await tester.runAsync(() async {
      ArtSprites.debugReset();
      const m = MouldType.roundPan;
      await ArtSprites.preload([ArtSprites.baked(m, BatterType.vanilla)]);
      final top = CakeArt.topSurface(_rect, m).center;
      final values = <double>[];
      for (final baked in const [0.0, 1.0, 2.0]) {
        final recorder = ui.PictureRecorder();
        CakeArt.paint(Canvas(recorder), _rect, CakeVisual(mould: m, batter: BatterType.vanilla, baked: baked));
        final image = await recorder.endRecording().toImage(_n, _n);
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
        image.dispose();
        values.add(lumaAt(data, top.dx.round(), top.dy.round()));
      }
      expect(values[0], greaterThan(values[1]));
      expect(values[1], greaterThan(values[2]));
    }).timeout(const Duration(seconds: 30));
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('lớp kem: ghi sẵn một lần (cache theo khuôn/kem/độ phủ lượng tử/mức cháy), vẽ lại không dựng lại', (tester) async {
    await tester.runAsync(() async {
      ArtSprites.debugReset();
      await ArtSprites.preload([for (final m in _artMoulds) ArtSprites.baked(m, _batters[m]!)]);
      CakeArt.debugClearFrostCache();
      for (final m in _artMoulds) {
        for (final f in const [FrostingId.vanillaCream, FrostingId.chocolateGanache]) {
          for (final cover in const [0.4, 1.0]) {
            for (final baked in const [1.0, 2.0]) {
              CakeArt.paint(Canvas(ui.PictureRecorder()), _rect, CakeVisual(mould: m, batter: _batters[m]!, frosting: f, frostCoverage: cover, baked: baked));
            }
          }
        }
      }
      // Macaron không có lớp kem riêng (nhuộm màu ảnh): 6 khuôn × 2 kem × 2 độ phủ × 2 mức cháy.
      final cold = CakeArt.debugFrostCache;
      expect(cold.misses, 6 * 2 * 2 * 2);
      // Vẽ lại cùng trạng thái (kể cả độ phủ lệch dưới một bước 0.05): chỉ trúng cache.
      for (var i = 0; i < 50; i++) {
        CakeArt.paint(Canvas(ui.PictureRecorder()), _rect,
            CakeVisual(mould: MouldType.roundPan, batter: BatterType.vanilla, frosting: FrostingId.vanillaCream, frostCoverage: 0.41));
      }
      final hot = CakeArt.debugFrostCache;
      expect(hot.misses, cold.misses);
      expect(hot.hits, cold.hits + 50);
      // Quét độ phủ 0..1 khi đang phủ kem: tối đa 21 bước cho một loại kem.
      for (var i = 0; i <= 200; i++) {
        CakeArt.paint(Canvas(ui.PictureRecorder()), _rect,
            CakeVisual(mould: MouldType.cupcakeLiner, batter: BatterType.vanilla, frosting: FrostingId.matchaCream, frostCoverage: i / 200));
      }
      expect(CakeArt.debugFrostCache.misses - hot.misses, 21);

      // Phủ chưa kín để lộ mặt bánh: tâm mặt bánh khác nhau giữa phủ 40% và 100%, cùng trạng thái thì ảnh giống hệt.
      Future<List<int>> pixels(double cover) async {
        final recorder = ui.PictureRecorder();
        CakeArt.paint(Canvas(recorder), _rect, CakeVisual(mould: MouldType.roundPan, batter: BatterType.vanilla, frosting: FrostingId.chocolateGanache, frostCoverage: cover));
        final image = await recorder.endRecording().toImage(_n, _n);
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
        image.dispose();
        return data.buffer.asUint8List().toList();
      }

      final full = await pixels(1), fullAgain = await pixels(1), partial = await pixels(0.4);
      expect(fullAgain, full);
      var diff = 0;
      for (var i = 0; i < full.length; i += 4) {
        if ((full[i] - partial[i]).abs() > 40) diff++;
      }
      expect(diff, greaterThan(_n * _n * 0.01));
    }).timeout(const Duration(seconds: 60));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
