import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_paint.dart';
import 'package:sugarleaf_bakery/core/art/shop_art.dart';
import 'package:sugarleaf_bakery/core/constants.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/ref_frame.dart';

/// Inset trái/phải đối xứng (tai thỏ khi máy nằm ngang).
EdgeInsets _notch(double px) => EdgeInsets.only(left: px, right: px);

MediaQueryData? _innerMq;
RefMetrics? _innerMetrics;

/// Ghi lại MediaQuery + RefMetrics bên trong khung và phủ kín chỗ của nó (để đo vị trí trên màn).
Widget _probe() => Builder(
      builder: (context) {
        _innerMq = MediaQuery.of(context);
        _innerMetrics = RefMetrics.of(context);
        return const SizedBox.expand(key: ValueKey('probe'));
      },
    );

/// Dựng [child] trên màn cỡ logic [screen] (dp) với vùng không an toàn [safe] (dp). Lưu ý: như bản cũ, `RefFrame`
/// chỉ co nhỏ khung (Center + FittedBox), không phóng to — muốn đo vị trí thì dùng màn nhỏ hơn khung (máy thật).
Future<void> _pump(WidgetTester tester, Size screen, Widget child, {EdgeInsets safe = EdgeInsets.zero, double dpr = 1}) async {
  tester.view.physicalSize = screen * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  _innerMq = null;
  _innerMetrics = null;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: screen, padding: safe, viewPadding: safe),
        child: child,
      ),
    ),
  );
}

Future<ui.Image> _render(Size size, void Function(Canvas canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  return picture.toImage(size.width.round(), size.height.round()).whenComplete(picture.dispose);
}

/// Màu RGBA tại (x, y) của ảnh đã đọc [bytes] rộng [width].
List<int> _px(ByteData bytes, int width, int x, int y) {
  final o = (y * width + x) * 4;
  return [bytes.getUint8(o), bytes.getUint8(o + 1), bytes.getUint8(o + 2), bytes.getUint8(o + 3)];
}

void main() {
  group('RefFrame.widthFor', () {
    test('16:9 → 1280, 4:3 → 1280', () {
      expect(RefFrame.widthFor(const Size(1280, 720), EdgeInsets.zero), kRefMinWidth);
      expect(RefFrame.widthFor(const Size(1920, 1080), EdgeInsets.zero), kRefMinWidth);
      expect(RefFrame.widthFor(const Size(2048, 1536), EdgeInsets.zero), kRefMinWidth);
    });

    test('20:9, 2412×1080, 21:9 → 1600; 19,5:9 ≈ 1560', () {
      expect(RefFrame.widthFor(const Size(2400, 1080), EdgeInsets.zero), 1600);
      expect(RefFrame.widthFor(const Size(2000, 900), EdgeInsets.zero), 1600);
      expect(RefFrame.widthFor(const Size(2412, 1080), EdgeInsets.zero), kRefMaxWidth);
      expect(RefFrame.widthFor(const Size(2520, 1080), EdgeInsets.zero), kRefMaxWidth);
      expect(RefFrame.widthFor(const Size(2340, 1080), EdgeInsets.zero), closeTo(1560, 1e-9));
      // Cỡ logic thật của OnePlus 2412×1080 ở dpr 2,625.
      expect(RefFrame.widthFor(const Size(2412 / 2.625, 1080 / 2.625), EdgeInsets.zero), kRefMaxWidth);
    });

    test('16:9 có tai thỏ → 1280 và frameRect như cũ', () {
      const screen = Size(1280, 720);
      expect(RefFrame.widthFor(screen, _notch(48)), kRefMinWidth);
      expect(RefFrame.frameRect(screen, _notch(48)), const Rect.fromLTWH(48, 27, 1184, 666));
      expect(RefFrame.frameRect(screen, EdgeInsets.zero), Offset.zero & screen);
    });

    test('20:9 tai thỏ 100 px mỗi bên → 1600, padding quy ra ref', () {
      const screen = Size(2400, 1080);
      expect(RefFrame.widthFor(screen, _notch(100)), 1600);
      final pad = RefFrame.safeInsetsFor(screen, _notch(100), 1600);
      expect(pad.left, closeTo(100 / 1.5, 1e-9));
      expect(pad.right, closeTo(100 / 1.5, 1e-9));
      expect(pad.top, 0);
      expect(pad.bottom, 0);
    });

    test('tai thỏ lấn vùng nội dung 1280 → 1280; inset trên/dưới vẫn khung rộng (vào padding)', () {
      const screen = Size(2400, 1080);
      // 300 px / 1,5 = 200 ref > (1600 − 1280) / 2 = 160.
      expect(RefFrame.widthFor(screen, _notch(300)), kRefMinWidth);
      // Vừa khít 160 ref vẫn khung rộng.
      expect(RefFrame.widthFor(screen, _notch(240)), 1600);
      expect(RefFrame.widthFor(screen, const EdgeInsets.only(bottom: 24)), 1600);
      expect(RefFrame.widthFor(screen, const EdgeInsets.only(top: 24)), 1600);
    });

    test('21:9: inset trừ phần letterbox ngoài khung 1600', () {
      // 2520×1080: khung 1600×720 × 1,5 = 2400 rộng → letterbox 60 px mỗi bên.
      final pad = RefFrame.safeInsetsFor(const Size(2520, 1080), _notch(90), 1600);
      expect(pad.left, closeTo(20, 1e-9));
      expect(RefFrame.widthFor(const Size(2520, 1080), _notch(40)), kRefMaxWidth);
    });

    test('màn dọc → 1280', () {
      expect(RefFrame.widthFor(const Size(1080, 2400), EdgeInsets.zero), kRefMinWidth);
      expect(RefFrame.widthFor(const Size(720, 1280), _notch(48)), kRefMinWidth);
      expect(RefFrame.widthFor(Size.zero, EdgeInsets.zero), kRefMinWidth);
    });
  });

  group('RefFrame', () {
    testWidgets('16:9: bên trong 1280×720, không RefScope, padding 0', (tester) async {
      // Máy 1920×1080 dpr 2 → 960×540 dp.
      await _pump(tester, const Size(960, 540), RefFrame(child: _probe()), dpr: 2);
      expect(_innerMq!.size, kRefSize);
      expect(_innerMq!.padding, EdgeInsets.zero);
      expect(_innerMetrics, RefMetrics.standard);
      expect(find.byType(RefScope), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('probe'))), const Rect.fromLTWH(0, 0, 960, 540));
    });

    testWidgets('16:9 có tai thỏ: khung trong vùng an toàn như cũ', (tester) async {
      await _pump(tester, const Size(1280, 720), RefFrame(child: _probe()), safe: _notch(48));
      expect(_innerMq!.size, kRefSize);
      expect(_innerMq!.viewPadding, EdgeInsets.zero);
      expect(find.byType(RefScope), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('probe'))), const Rect.fromLTWH(48, 27, 1184, 666));
    });

    testWidgets('2400×1080: bên trong 1600×720, khung lấp cả màn', (tester) async {
      await _pump(tester, const Size(2400, 1080), RefFrame(child: _probe()));
      expect(_innerMq!.size, const Size(1600, 720));
      expect(_innerMq!.padding, EdgeInsets.zero);
      expect(_innerMetrics!.width, 1600);
      expect(_innerMetrics!.inset, 160);
      expect(_innerMetrics!.content, const Rect.fromLTWH(160, 0, 1280, 720));
    });

    testWidgets('máy 2400×1080 dpr 3 (800×360 dp): khung 1600×720 lấp cả màn', (tester) async {
      await _pump(tester, const Size(800, 360), RefFrame(child: _probe()), dpr: 3);
      expect(_innerMq!.size, const Size(1600, 720));
      expect(tester.getRect(find.byKey(const ValueKey('probe'))), const Rect.fromLTWH(0, 0, 800, 360));
    });

    testWidgets('2400×1080 tai thỏ 100 px: nền tràn dưới tai thỏ, padding ref bên trong', (tester) async {
      await _pump(tester, const Size(2400, 1080), RefFrame(child: _probe()), safe: _notch(100));
      expect(_innerMq!.size, const Size(1600, 720));
      expect(_innerMq!.padding.left, closeTo(100 / 1.5, 1e-9));
      expect(_innerMq!.viewPadding.right, closeTo(100 / 1.5, 1e-9));
      expect(_innerMetrics!.safe.left, closeTo(100 / 1.5, 1e-9));
      // Cùng máy ở dpr 3: tai thỏ 50 dp = 100 ref; khung vẫn phủ kín cả màn, kể cả dưới tai thỏ.
      await _pump(tester, const Size(800, 360), RefFrame(child: _probe()), safe: _notch(50), dpr: 3);
      expect(_innerMq!.padding, const EdgeInsets.only(left: 100, right: 100));
      expect(tester.getRect(find.byKey(const ValueKey('probe'))), const Rect.fromLTWH(0, 0, 800, 360));
    });

    testWidgets('2340×1080 (19,5:9): khung 1560×720', (tester) async {
      await _pump(tester, const Size(2340, 1080), RefFrame(child: _probe()));
      expect(_innerMq!.size.width, closeTo(1560, 1e-6));
      expect(_innerMq!.size.height, 720);
      expect(_innerMetrics!.inset, closeTo(140, 1e-6));
    });
  });

  group('RefCenter', () {
    testWidgets('khung rộng: con ở vùng 1280×720 giữa, MediaQuery 1280×720, metrics chuẩn', (tester) async {
      await _pump(tester, const Size(800, 360), RefFrame(child: RefCenter(child: _probe())), safe: _notch(50), dpr: 3);
      expect(_innerMq!.size, kRefSize);
      expect(_innerMq!.padding, EdgeInsets.zero);
      expect(_innerMq!.viewPadding, EdgeInsets.zero);
      expect(_innerMetrics, RefMetrics.standard);
      // 160 ref × 0,5 = 80 dp mỗi bên.
      expect(tester.getRect(find.byKey(const ValueKey('probe'))), const Rect.fromLTWH(80, 0, 640, 360));
    });

    testWidgets('khung 1280: trả thẳng con, không thêm lớp', (tester) async {
      await _pump(tester, const Size(1280, 720), RefFrame(child: RefCenter(child: _probe())));
      expect(_innerMq!.size, kRefSize);
      expect(find.descendant(of: find.byType(RefCenter), matching: find.byType(ClipRect)), findsNothing);
      expect(find.descendant(of: find.byType(RefCenter), matching: find.byType(MediaQuery)), findsNothing);
    });

    testWidgets('không có RefScope (test widget lẻ): metrics mặc định', (tester) async {
      await _pump(tester, const Size(1280, 720), RefCenter(child: _probe()));
      expect(_innerMetrics, RefMetrics.standard);
      expect(RefMetrics.standard.width, 1280);
      expect(RefMetrics.standard.inset, 0);
    });
  });

  group('paintWideBackdrop', () {
    testWidgets('soi gương dải mép, tối nhẹ ra ngoài; full == center vẽ như thường', (tester) async {
      await tester.runAsync(() async {
        // Ảnh 128×72: nửa trái đỏ, nửa phải xanh dương.
        final src = await _render(const Size(128, 72), (c) {
          c.drawRect(const Rect.fromLTWH(0, 0, 64, 72), Paint()..color = const Color(0xFFFF0000));
          c.drawRect(const Rect.fromLTWH(64, 0, 64, 72), Paint()..color = const Color(0xFF0000FF));
        });
        const full = Rect.fromLTWH(0, 0, 1600, 720);
        const center = Rect.fromLTWH(160, 0, 1280, 720);
        expect(wideCenterRect(full.size), center);
        final out = await _render(full.size, (c) => paintWideBackdrop(c, src, center1280: center, full: full));
        final bytes = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final seamL = _px(bytes, 1600, 150, 360), edgeL = _px(bytes, 1600, 2, 360);
        final seamR = _px(bytes, 1600, 1450, 360), edgeR = _px(bytes, 1600, 1597, 360);
        // Dải trái = mép trái ảnh (đỏ), dải phải = mép phải (xanh); kín, không trong suốt.
        expect(seamL[0], greaterThan(200));
        expect(seamL[2], lessThan(40));
        expect(seamR[2], greaterThan(200));
        expect(seamR[0], lessThan(40));
        expect(edgeL[3], 255);
        expect(edgeR[3], 255);
        // Tối dần ra mép ngoài (~8–12%).
        expect(edgeL[0], lessThan(seamL[0]));
        expect(edgeL[0], inInclusiveRange(220, 240));
        expect(edgeR[2], lessThan(seamR[2]));

        // full == center: chỉ vẽ ảnh.
        final plain = await _render(const Size(1280, 720),
            (c) => paintWideBackdrop(c, src, center1280: Offset.zero & kRefSize, full: Offset.zero & kRefSize));
        final pb = (await plain.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        expect(_px(pb, 1280, 2, 360), [255, 0, 0, 255]);
        expect(_px(pb, 1280, 1277, 360), [0, 0, 255, 255]);
        expect(wideCenterRect(kRefSize), Offset.zero & kRefSize);
        for (final i in [src, out, plain]) {
          i.dispose();
        }
      });
    });
  });

  group('ShopArt khung rộng', () {
    testWidgets('1600×720 và 3200×1440: tường/sàn phủ tới hai mép', (tester) async {
      final decorSets = <Map<DecorSlot, DecorId?>>[
        {for (final s in DecorSlot.values) s: null},
        {
          DecorSlot.wallpaper: DecorId.wallpaperStripes,
          DecorSlot.floor: DecorId.floorCheckered,
          DecorSlot.counter: DecorId.counterFlowers,
          DecorSlot.window: DecorId.windowCurtains,
          DecorSlot.plant: DecorId.plantFern,
        },
        {
          DecorSlot.wallpaper: DecorId.wallpaperFloral,
          DecorSlot.floor: DecorId.floorHerringbone,
          DecorSlot.counter: DecorId.counterCakeStand,
          DecorSlot.window: DecorId.windowSeaView,
          DecorSlot.plant: DecorId.plantLemonTree,
        },
      ];
      await tester.runAsync(() async {
        for (final set in decorSets) {
          final img = await _render(const Size(1600, 720), (c) => ShopArt.paint(c, const Size(1600, 720), set));
          final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          for (final (x, y) in const [(1, 100), (1598, 100), (1, 700), (1598, 700), (80, 500), (1520, 600)]) {
            expect(_px(bytes, 1600, x, y)[3], 255, reason: '($x, $y) phải được tô');
          }
          img.dispose();
        }
      });
      // Vẽ ở cỡ lớn / cỡ chuẩn / cỡ nhỏ không lỗi.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      ShopArt.paint(canvas, const Size(3200, 1440), decorSets[0]);
      ShopArt.paint(canvas, const Size(1560, 720), decorSets[1]);
      ShopArt.paint(canvas, kRefSize, decorSets[2]);
      ShopArt.paint(canvas, const Size(640, 360), decorSets[0]);
      recorder.endRecording().dispose();
    });
  });
}
