import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../common/shop_scene.dart';
import '../sugarleaf/sugarleaf.dart';

/// Lớp mưa phủ lên cảnh tiệm ở quầy gọi món ngày mưa. Trong nhà thì mưa không rơi, nên mưa chỉ thấy **qua ô kính
/// cửa sổ** (`ShopScene.windowGlass`, đã nhuộm xám xanh ở `ShopBackdrop(rainy: true)`):
/// - ~140 vệt mưa xiên nhẹ, dài, xanh xám đậm xen vài vệt sáng, rơi lặp;
/// - giọt nước đọng trên kính vẽ tay (viền sáng, thân xanh xám run tay, vệt sáng cong; vài biến thể dựng sẵn, ghi
///   một lần thành Picture) và vài giọt chảy chậm (Picture dựng sẵn, chỉ dời vị trí) để lại vệt — ảnh tĩnh vẫn đọc
///   ra "mưa";
/// - rèm cửa (nếu đang đặt) vẽ lại đè lên mưa vì treo trước kính;
/// - "hơi mưa" trong phòng: ~44 vệt rất nhạt, mép mềm, dài và chậm, cùng hướng xiên, chỉ ở nửa trên khung (trên
///   mặt quầy) + quầng xanh xám rất nhạt ở hai góc trên — để bước gọi món (vé đơn che cửa sổ) vẫn đọc ra ngày mưa.
///   Lớp này nằm dưới khách/vé đơn/bong bóng/nút nên không đè lên mặt nhân vật hay chữ;
/// - cả khung tối đi ~8%, hơi lạnh.
///
/// Toạ độ theo khung 1280×720, co theo kích thước được cấp giống `ShopScene.paint`. Vị trí vệt/giọt xác định theo
/// [seed] (tính một lần); `Paint` tĩnh; toạ độ mỗi frame ghi đè vào `Float32List` cấp sẵn rồi vẽ bằng
/// `drawRawPoints` (không tạo object mỗi frame). Một `AnimationController` lặp, vẽ lại qua `repaint` trong
/// `RepaintBoundary`. Không nhận chạm. Bật "giảm chuyển động" → mưa đứng yên.
class RainOverlay extends StatefulWidget {
  const RainOverlay({super.key, required this.equipped, this.seed = 5, this.drops = 140});

  /// Đồ trang trí đang đặt (để biết cảnh ảnh hay hình code, và có rèm che kính không).
  final Map<DecorSlot, DecorId?> equipped;
  final int seed;

  /// Số vệt mưa trong khung bao vùng kính.
  final int drops;

  @override
  State<RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<RainOverlay> with SingleTickerProviderStateMixin {
  /// Một vòng lặp; mọi chuyển động đi số nguyên lần mỗi vòng → vòng nối liền không giật.
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 6400));
  late _RainPainter _painter = _RainPainter(_loop, widget.seed, widget.drops);

  @override
  void initState() {
    super.initState();
    _syncScene();
    // Ảnh nền / rèm nạp xong → đổi vùng kính, ảnh rèm (painter cũng nghe `changes` để vẽ lại).
    ArtSprites.changes.addListener(_syncScene);
  }

  void _syncScene() {
    _painter
      ..art = ShopScene.usesArt(widget.equipped)
      ..front = ShopScene.windowFrontImage(widget.equipped);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _loop.stop();
      _loop.value = 0.37;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(RainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed || oldWidget.drops != widget.drops) {
      _painter = _RainPainter(_loop, widget.seed, widget.drops);
    }
    _syncScene();
  }

  @override
  void dispose() {
    ArtSprites.changes.removeListener(_syncScene);
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _painter, size: Size.infinite),
      ),
    );
  }
}

/// Một vệt mưa: [x] 0..1 theo bề ngang dải, [phase] 0..1 lệch thời gian, [laps] số lần rơi hết vùng mỗi vòng.
class _Streak {
  const _Streak({required this.x, required this.phase, required this.length, required this.laps});

  final double x;
  final double phase;
  final double length;
  final int laps;
}

/// Một giọt chảy trên kính: từ ([x], [y0]) trượt xuống [length] px, mỗi vòng một lần, lệch [phase].
class _Drip {
  const _Drip({required this.x, required this.y0, required this.length, required this.phase});

  final double x;
  final double y0;
  final double length;
  final double phase;
}

/// Bố cục cố định trên một vùng kính (cảnh ảnh hoặc hình code): giọt đọng (ghi sẵn một lần thành [droplets]) và
/// giọt chảy.
class _GlassLayout {
  _GlassLayout({required this.droplets, required this.drips}) : dripTrails = Float32List(drips.length * 4);

  /// Mọi giọt đọng tĩnh trên kính, vẽ tay (viền sáng + thân run + vệt sáng), toạ độ khung 1280×720.
  final ui.Picture droplets;
  final List<_Drip> drips;

  /// Vệt nước sau giọt chảy (ghi đè tại chỗ mỗi frame).
  final Float32List dripTrails;
}

/// Một giọt nước vẽ tay tâm (0,0): viền sáng, thân xanh xám run tay, mảng tối nhỏ phía dưới, vệt sáng cong +
/// chấm phản chiếu trên trái. [d] = đường kính thân; [drip] = giọt đang chảy (thon nhọn phía trên).
class _DropShape {
  _DropShape(double d, int seed, {bool drip = false}) {
    final rnd = SLRandom(seed);
    final r = d / 2;
    final Path ideal;
    if (drip) {
      ideal = Path()
        ..moveTo(0, -r * 1.9)
        ..quadraticBezierTo(r * 1.05, -r * 0.35, r * 0.98, r * 0.2)
        ..arcToPoint(Offset(-r * 0.98, r * 0.2), radius: Radius.circular(r))
        ..quadraticBezierTo(-r * 1.05, -r * 0.35, 0, -r * 1.9)
        ..close();
    } else {
      ideal = Path()
        ..addOval(Rect.fromCenter(center: Offset(0, r * 0.06), width: d * rnd.range(0.92, 1.08), height: d * rnd.range(1.0, 1.16)));
    }
    final amp = math.max(0.25, r * 0.16);
    final step = math.max(1.0, r * 0.6);
    final grow = 1 + 1.7 / d;
    body = wobblePath(ideal, seed: rnd.nextInt32(), amplitude: amp, step: step);
    rim = wobblePath(ideal.transform(Matrix4.diagonal3Values(grow, grow, 1).storage), seed: rnd.nextInt32(), amplitude: amp, step: step);
    shade = wobblePath(
      Path()..addArc(Rect.fromCircle(center: Offset(0, r * 0.1), radius: r * 0.62), math.pi * 0.15, math.pi * 0.6),
      seed: rnd.nextInt32(),
      amplitude: amp * 0.4,
      step: 1,
    );
    shine = wobblePath(
      Path()..addArc(Rect.fromCircle(center: Offset(0, drip ? -r * 0.1 : 0), radius: r * 0.55), math.pi * 1.05, math.pi * 0.45),
      seed: rnd.nextInt32(),
      amplitude: amp * 0.3,
      step: 1,
    );
    glint = Offset(-r * 0.12 + rnd.range(-0.3, 0.3), -r * 0.62 + rnd.range(-0.3, 0.3));
  }

  late final Path rim;
  late final Path body;
  late final Path shade;
  late final Path shine;
  late final Offset glint;

  static final _rim = Paint()..color = const Color(0xE6F4F8FB);
  static final _body = Paint()..color = const Color(0xD98497AC);
  static final _shade = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1
    ..color = const Color(0x8C55687E);
  static final _shine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.1
    ..color = const Color(0xF2FFFFFF);
  static final _glint = Paint()..color = const Color(0xFFFFFFFF);

  void paint(Canvas c) {
    c
      ..drawPath(rim, _rim)
      ..drawPath(body, _body)
      ..drawPath(shade, _shade)
      ..drawPath(shine, _shine)
      ..drawCircle(glint, 0.65, _glint);
  }

  ui.Picture record() {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    return recorder.endRecording();
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.t, int seed, int drops)
    : _streaks = _makeStreaks(seed, drops),
      _haze = _makeHaze(seed),
      _seed = seed,
      super(repaint: Listenable.merge([t, ArtSprites.changes])) {
    _darkLines = Float32List(_streaks.where((s) => !_isLight(s)).length * 4);
    _lightLines = Float32List(_streaks.where(_isLight).length * 4);
    _hazeLines = Float32List(_haze.length * 4);
  }

  final Animation<double> t;
  final List<_Streak> _streaks;
  final int _seed;
  late final Float32List _darkLines;
  late final Float32List _lightLines;

  /// Vệt "hơi mưa" trong phòng (toạ độ ghi đè mỗi frame vào [_hazeLines]).
  final List<_Streak> _haze;
  late final Float32List _hazeLines;

  /// Cảnh ảnh (vùng kính đo trên `shop_base`) hay hình code; đặt bởi State.
  bool art = true;

  /// Ảnh rèm treo trước kính (vẽ lại đè lên mưa); null = không có.
  ui.Image? front;

  final _layouts = <bool, _GlassLayout>{};
  ui.Image? _frontFor;
  Rect _frontSrc = Rect.zero;
  Size? _dimFor;
  Rect _dimRect = Rect.zero;

  /// Độ xiên: lệch ngang / rơi dọc (gió nhẹ từ phải sang trái).
  static const _slant = -0.18;

  static const _dripCount = 7;
  static const _dropletCount = 30;
  static const _smallDrop = 3.4;
  static const _bigDrop = 5.6;
  static const _dripDrop = 4.6;

  static final _dim = Paint()..color = const Color(0x14223040); // tối ~8%, hơi lạnh.
  static final _rainDark = Paint()
    ..color = const Color(0xB3566B82)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  static final _rainLight = Paint()
    ..color = const Color(0xCCF2F6FA)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;

  static Paint _round(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// Giọt đọng / giọt chảy vẽ tay: vài biến thể dựng sẵn một lần (dùng chung mọi painter).
  static final _smallShapes = [for (var i = 0; i < 4; i++) _DropShape(_smallDrop, 0xD20 + i)];
  static final _bigShapes = [for (var i = 0; i < 3; i++) _DropShape(_bigDrop, 0xD30 + i)];
  static final _dripPictures = [for (var i = 0; i < 2; i++) _DropShape(_dripDrop, 0xD40 + i, drip: true).record()];
  static final _trail = _round(const Color(0x66E6EDF3), 2.0);
  static final _frontPaint = Paint()..filterQuality = FilterQuality.medium;

  /// Hơi mưa trong phòng: chỉ phía trên mặt quầy (y < [_hazeBottom]).
  static const _hazeBottom = 480.0;
  static const _hazeCount = 44;
  static const _hazeArea = Rect.fromLTRB(0, 0, 1280, _hazeBottom);

  /// Vẽ hai lần cho mép mềm: nét rộng alpha ~0,1 rồi nét mảnh alpha ~0,22, xanh xám; cả hai nhạt dần về phía
  /// mặt quầy (gradient dọc theo khung) → đọc như hơi mưa phủ không khí, không như mưa rơi trong nhà.
  static Paint _hazePaint(int topAlpha, double width) => _round(const Color(0xFF000000), width)
    ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _hazeBottom), [
      Color.fromARGB(topAlpha, 0x6E, 0x86, 0xA2),
      Color.fromARGB(topAlpha, 0x6E, 0x86, 0xA2),
      Color.fromARGB(topAlpha * 3 ~/ 5, 0x6E, 0x86, 0xA2),
      Color.fromARGB(0, 0x6E, 0x86, 0xA2),
    ], const [0, 0.45, 0.75, 1]);
  static final _hazeSoft = _hazePaint(0x1A, 7);
  static final _hazeThin = _hazePaint(0x38, 1.6);

  /// Quầng xanh xám rất nhạt ở hai góc trên (~13% ở góc, tắt dần trong bán kính 520).
  static Paint _corner(Offset c) => Paint()
    ..shader = ui.Gradient.radial(c, 520, const [Color(0x227F8FA3), Color(0x007F8FA3)]);
  static final _cornerLeft = _corner(Offset.zero);
  static final _cornerRight = _corner(const Offset(1280, 0));
  static const _cornerLeftRect = Rect.fromLTWH(0, 0, 520, 520);
  static const _cornerRightRect = Rect.fromLTWH(760, 0, 520, 520);

  static bool _isLight(_Streak s) => s.laps == 5;

  static List<_Streak> _makeStreaks(int seed, int drops) {
    final rnd = math.Random(seed);
    return [
      for (var i = 0; i < drops; i++)
        _Streak(
          x: rnd.nextDouble(),
          phase: rnd.nextDouble(),
          length: 26 + rnd.nextDouble() * 22,
          // 4–6 lần rơi hết khung kính mỗi vòng 6,4 s (~250–420 px/s); vệt sáng (5 lần) chiếm ~1/3.
          laps: 4 + rnd.nextInt(3),
        ),
    ];
  }

  static List<_Streak> _makeHaze(int seed) {
    final rnd = math.Random(seed + 7);
    return [
      for (var i = 0; i < _hazeCount; i++)
        _Streak(
          x: rnd.nextDouble(),
          phase: rnd.nextDouble(),
          length: 80 + rnd.nextDouble() * 70,
          // 1–2 lần rơi hết nửa trên khung mỗi vòng 6,4 s (~90–180 px/s): chậm hơn hẳn mưa ngoài kính.
          laps: 1 + rnd.nextInt(2),
        ),
    ];
  }

  _GlassLayout _layout(bool art) => _layouts[art] ??= _makeLayout(art);

  _GlassLayout _makeLayout(bool art) {
    final glass = ShopScene.windowGlass(art: art);
    final b = ShopScene.windowGlassBounds(art: art);
    final rnd = math.Random(_seed + 101);
    Offset pick(Rect r) {
      for (var tries = 0; tries < 200; tries++) {
        final p = Offset(r.left + rnd.nextDouble() * r.width, r.top + rnd.nextDouble() * r.height);
        // Lùi khỏi mép kính để giọt không bị cắt nửa.
        if (glass.contains(p) && glass.contains(p.translate(-4, -4)) && glass.contains(p.translate(4, 4))) return p;
      }
      return r.center;
    }

    // Giọt đọng chia theo từng ô kính: 4 giọt + 1 giọt mỗi ~3000 px² → ô hẹp (dải cửa ra vào, ô góc phải — phần
    // còn lộ ra cạnh vé đơn) vẫn có đủ giọt để đọc ra "mưa".
    final areas = art
        ? [for (final pane in ShopScene.windowPanes) _bounds(pane)]
        : [b];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    var n = 0;
    for (final r in areas) {
      final count = art ? 4 + (r.width * r.height / 3000).round() : _dropletCount;
      for (var i = 0; i < count; i++, n++) {
        final p = pick(r);
        final isBig = n % 3 == 0;
        final shapes = isBig ? _bigShapes : _smallShapes;
        final k = 0.85 + rnd.nextDouble() * 0.35;
        canvas
          ..save()
          ..translate(p.dx, p.dy)
          ..scale(k);
        shapes[n % shapes.length].paint(canvas);
        canvas.restore();
      }
    }
    final drips = <_Drip>[];
    for (var i = 0; i < _dripCount; i++) {
      var start = pick(b);
      var length = 40 + rnd.nextDouble() * 70;
      for (var tries = 0; tries < 20 && !glass.contains(start.translate(0, length + 4)); tries++) {
        start = pick(b);
        length = 40 + rnd.nextDouble() * 70;
      }
      drips.add(_Drip(x: start.dx, y0: start.dy, length: length, phase: rnd.nextDouble()));
    }
    return _GlassLayout(droplets: recorder.endRecording(), drips: drips);
  }

  static Rect _bounds(List<Offset> pane) {
    var r = Rect.fromPoints(pane.first, pane.first);
    for (final p in pane) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final glass = ShopScene.windowGlass(art: art);
    final b = ShopScene.windowGlassBounds(art: art);
    final layout = _layout(art);
    final v = t.value;

    // Vệt mưa trong khung bao vùng kính; dải rộng hơn theo độ xiên để vệt trôi ra mép này thì vào lại mép kia.
    final span = b.width + b.height * -_slant;
    var dark = 0, light = 0;
    for (var k = 0; k < _streaks.length; k++) {
      final s = _streaks[k];
      final fall = (s.phase + v * s.laps) % 1.0;
      final dy = fall * (b.height + s.length) - s.length;
      final x = b.left + (s.x * span + dy * _slant) % span;
      final y = b.top + dy;
      final lines = _isLight(s) ? _lightLines : _darkLines;
      final i = _isLight(s) ? (light++) * 4 : (dark++) * 4;
      lines[i] = x;
      lines[i + 1] = y;
      lines[i + 2] = x + s.length * _slant;
      lines[i + 3] = y + s.length;
    }

    // Hơi mưa trong phòng: cùng cách tính, trên cả bề ngang khung, phía trên mặt quầy.
    const hazeSpan = 1280 + _hazeBottom * -_slant;
    for (var k = 0; k < _haze.length; k++) {
      final s = _haze[k];
      final fall = (s.phase + v * s.laps) % 1.0;
      final y = fall * (_hazeBottom + s.length) - s.length;
      final x = (s.x * hazeSpan + y * _slant) % hazeSpan;
      _hazeLines[k * 4] = x;
      _hazeLines[k * 4 + 1] = y;
      _hazeLines[k * 4 + 2] = x + s.length * _slant;
      _hazeLines[k * 4 + 3] = y + s.length;
    }

    // Vệt nước sau giọt chảy (giọt trượt chậm, nhanh dần p²; vị trí giọt tính lại lúc vẽ).
    for (var i = 0; i < layout.drips.length; i++) {
      final d = layout.drips[i];
      final p = (d.phase + v) % 1.0;
      final y = d.y0 + p * p * d.length;
      layout.dripTrails[i * 4] = d.x;
      layout.dripTrails[i * 4 + 1] = d.y0;
      layout.dripTrails[i * 4 + 2] = d.x;
      layout.dripTrails[i * 4 + 3] = math.max(d.y0, y - 2);
    }

    canvas.save();
    canvas.scale(size.width / kRefSize.width, size.height / kRefSize.height);
    canvas.drawRect(_cornerLeftRect, _cornerLeft);
    canvas.drawRect(_cornerRightRect, _cornerRight);
    canvas.save();
    canvas.clipRect(_hazeArea);
    canvas.drawRawPoints(ui.PointMode.lines, _hazeLines, _hazeSoft);
    canvas.drawRawPoints(ui.PointMode.lines, _hazeLines, _hazeThin);
    canvas.restore();
    canvas.clipPath(glass);
    canvas.drawRawPoints(ui.PointMode.lines, _darkLines, _rainDark);
    canvas.drawRawPoints(ui.PointMode.lines, _lightLines, _rainLight);
    canvas.drawRawPoints(ui.PointMode.lines, layout.dripTrails, _trail);
    canvas.drawPicture(layout.droplets);
    for (var i = 0; i < layout.drips.length; i++) {
      final d = layout.drips[i];
      final p = (d.phase + v) % 1.0;
      canvas
        ..save()
        ..translate(d.x, d.y0 + p * p * d.length)
        ..drawPicture(_dripPictures[i % _dripPictures.length])
        ..restore();
    }
    final image = front;
    if (image != null && art) {
      if (!identical(image, _frontFor)) {
        _frontFor = image;
        _frontSrc = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      }
      // Rèm treo trước kính: vẽ lại đúng như ở ShopScene (ảnh vuông vào khung vuông) đè lên mưa.
      canvas.drawImageRect(image, _frontSrc, ShopScene.curtainRect, _frontPaint);
    }
    canvas.restore();

    if (size != _dimFor) {
      _dimFor = size;
      _dimRect = Offset.zero & size;
    }
    canvas.drawRect(_dimRect, _dim);
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => oldDelegate._streaks != _streaks || oldDelegate.t != t;
}
