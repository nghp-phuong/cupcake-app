import 'dart:math' as math;
import 'dart:ui';

import '../constants.dart';
import '../models/ids.dart';
import 'item_art.dart';

/// Nền tiệm + đồ trang trí đang đặt (null = "Cơ bản"). Vẽ theo khung 1280×720 rồi co về [size].
///
/// Bố cục tham chiếu: tường y 0–540, cửa sổ x 760–1100 y 80–330, kệ x 120–520 y 150–260,
/// quầy x 40–1240 y 500–640 (khách đứng sau quầy), sàn y 540–720, cây ở góc phải x 1140–1270.
///
/// Phong cách anime vẽ tay ấm áp: nắng chiều xiên qua cửa sổ, đèn treo toả quầng, bóng đổ mềm bằng gradient
/// (không dùng blur lớn để vẽ lại rẻ). Mỗi bộ trang trí được ghi một lần thành `Picture` rồi dùng lại.
abstract final class ShopArt {
  static const _outline = ItemArt.outline;
  static const wallBottom = 540.0;
  static const counterRect = Rect.fromLTRB(40, 500, 1240, 640);

  static const _cacheLimit = 12;
  static final _cache = <Object, Picture>{}; // LinkedHashMap: giữ thứ tự dùng gần nhất.

  static void paint(Canvas canvas, Size size, Map<DecorSlot, DecorId?> equipped) {
    final key = (
      equipped[DecorSlot.wallpaper],
      equipped[DecorSlot.floor],
      equipped[DecorSlot.window],
      equipped[DecorSlot.counter],
      equipped[DecorSlot.plant],
    );
    var picture = _cache.remove(key);
    picture ??= _record(equipped);
    _cache[key] = picture;
    if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / kRefSize.width, size.height / kRefSize.height);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  static Picture _record(Map<DecorSlot, DecorId?> equipped) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.clipRect(Offset.zero & kRefSize);
    _wall(canvas, equipped[DecorSlot.wallpaper]);
    _floor(canvas, equipped[DecorSlot.floor]);
    _window(canvas, equipped[DecorSlot.window]);
    _hangingPlant(canvas);
    _shelf(canvas);
    _sunbeams(canvas);
    _lamp(canvas);
    _counter(canvas, equipped[DecorSlot.counter]);
    _plant(canvas, equipped[DecorSlot.plant]);
    return recorder.endRecording();
  }

  static Paint _f(Color c) => ItemArt.fill(c);
  static Paint _s(Color c, double w) => ItemArt.stroke(c, w);

  static Paint _linear(Offset a, Offset b, List<Color> colors, [List<double>? stops]) =>
      Paint()..shader = Gradient.linear(a, b, colors, stops);

  static Paint _radial(Offset c, double r, List<Color> colors, [List<double>? stops]) =>
      Paint()..shader = Gradient.radial(c, r, colors, stops);

  /// Bóng đổ mềm hình elip (gradient toả tròn, không blur).
  static void _softShadow(Canvas canvas, Rect r, {double alpha = 0.28}) {
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.scale(1, r.height / r.width);
    canvas.drawCircle(
      Offset.zero,
      r.width / 2,
      _radial(Offset.zero, r.width / 2, [_outline.withValues(alpha: alpha), _outline.withValues(alpha: alpha * 0.6), _outline.withValues(alpha: 0)], const [0, 0.5, 1]),
    );
    canvas.restore();
  }

  /// Lá nhỏ hình thấu kính tại [at], hướng [angle].
  static void _leaf(Canvas canvas, Offset at, double size, double angle, Color color) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size * 0.5, -size * 0.45, size, 0)
      ..quadraticBezierTo(size * 0.5, size * 0.45, 0, 0)
      ..close();
    canvas.drawPath(p, _f(color));
    canvas.save();
    canvas.clipPath(p);
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), _f(Color.lerp(color, const Color(0xFF2F5E45), 0.25)!));
    canvas.restore();
    canvas.drawLine(Offset(size * 0.1, 0), Offset(size * 0.8, 0), _s(Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!, 1));
    canvas.drawPath(p, _s(Color.lerp(color, _outline, 0.6)!, 1.4));
    canvas.restore();
  }

  // ------------------------------------------------------------------ Tường

  static void _wall(Canvas canvas, DecorId? id) {
    const wall = Rect.fromLTRB(0, 0, 1280, wallBottom);
    switch (id) {
      case DecorId.wallpaperStripes:
        canvas.drawRect(wall, _f(AppColors.cream));
        for (var x = 0.0; x < 1280; x += 80) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 36, wallBottom), _f(const Color(0xFFFBE0E6)));
          canvas.drawLine(Offset(x + 18, 0), Offset(x + 18, wallBottom), _s(const Color(0x33FFFFFF), 2));
        }
      case DecorId.wallpaperFloral:
        canvas.drawRect(wall, _f(const Color(0xFFE6F4EC)));
        final rnd = math.Random(7);
        for (var y = 30.0; y < wallBottom - 60; y += 70) {
          for (var x = 20.0 + ((y ~/ 70).isOdd ? 35 : 0); x < 1280; x += 70) {
            final c = Offset(x + rnd.nextDouble() * 10, y + rnd.nextDouble() * 10);
            _leaf(canvas, c + const Offset(4, 6), 12, 0.7 + rnd.nextDouble() * 0.4, const Color(0xFFA8D5B5));
            for (var k = 0; k < 5; k++) {
              final a = k * math.pi * 2 / 5;
              canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 6, 5, _f(const Color(0xFFF7B6C6)));
            }
            canvas.drawCircle(c, 3.5, _f(AppColors.butter));
          }
        }
      default:
        canvas.drawRect(wall, _linear(Offset.zero, const Offset(0, wallBottom), const [Color(0xFFFFF0DC), Color(0xFFF8DCBD)]));
        _bricks(canvas, const Rect.fromLTRB(16, 300, 210, 440));
        _bricks(canvas, const Rect.fromLTRB(1120, 230, 1270, 370));
        _bricks(canvas, const Rect.fromLTRB(560, 20, 720, 110));
    }
    // Vân giấy/vữa nhẹ cho mọi loại tường.
    final rnd = math.Random(3);
    for (var i = 0; i < 700; i++) {
      final p = Offset(rnd.nextDouble() * 1280, rnd.nextDouble() * (wallBottom - 70));
      final r = 0.6 + rnd.nextDouble() * 1.4;
      canvas.drawCircle(p, r, _f((rnd.nextBool() ? const Color(0xFFB9805A) : const Color(0xFFFFFFFF)).withValues(alpha: 0.07 + rnd.nextDouble() * 0.06)));
    }
    for (var i = 0; i < 60; i++) {
      final p = Offset(rnd.nextDouble() * 1280, rnd.nextDouble() * (wallBottom - 80));
      final len = 10 + rnd.nextDouble() * 24;
      canvas.drawLine(p, p + Offset(len, rnd.nextDouble() * 4 - 2), _s(const Color(0xFFB9805A).withValues(alpha: 0.06), 1.4));
    }
    // Hơi ấm hắt từ cửa sổ.
    canvas.drawRect(wall, _radial(const Offset(930, 200), 700, const [Color(0x40FFF6D8), Color(0x00FFF6D8)]));
    // Góc trên tối nhẹ cho có chiều sâu.
    canvas.drawRect(const Rect.fromLTRB(0, 0, 1280, 60), _linear(Offset.zero, const Offset(0, 60), const [Color(0x22B9805A), Color(0x00B9805A)]));
    _wainscot(canvas);
  }

  /// Mảng gạch lộ ra sau lớp vữa (mép lởm chởm theo hình elip).
  static void _bricks(Canvas canvas, Rect area) {
    final rnd = math.Random(area.left.toInt() + area.top.toInt());
    const bw = 34.0, bh = 16.0;
    final c = area.center;
    final rx = area.width / 2, ry = area.height / 2;
    for (var y = area.top; y < area.bottom; y += bh + 3) {
      final row = ((y - area.top) / (bh + 3)).round();
      for (var x = area.left - (row.isOdd ? bw / 2 : 0); x < area.right; x += bw + 3) {
        final m = Offset(x + bw / 2, y + bh / 2);
        final d = math.pow((m.dx - c.dx) / rx, 2) + math.pow((m.dy - c.dy) / ry, 2);
        if (d > 0.85 + rnd.nextDouble() * 0.3) continue;
        final brick = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), const Radius.circular(4));
        final tone = Color.lerp(const Color(0xFFEDC3A5), const Color(0xFFDDA383), rnd.nextDouble())!;
        canvas.drawRRect(brick, _f(tone.withValues(alpha: 0.8)));
        canvas.drawLine(Offset(x + 4, y + 3), Offset(x + bw - 6, y + 3), _s(const Color(0x44FFFFFF), 1.6));
        canvas.drawRRect(brick, _s(const Color(0x40B9805A), 1.2));
      }
    }
  }

  static void _wainscot(Canvas canvas) {
    const top = wallBottom - 76;
    canvas.drawRect(const Rect.fromLTRB(0, top, 1280, wallBottom), _linear(const Offset(0, top), const Offset(0, wallBottom), const [Color(0xFFEBC7A2), Color(0xFFDDB38B)]));
    for (var x = 12.0; x < 1280; x += 128) {
      final panel = RRect.fromRectAndRadius(Rect.fromLTWH(x, top + 16, 104, 46), const Radius.circular(6));
      canvas.drawRRect(panel, _f(const Color(0xFFE4BD96)));
      canvas.drawLine(Offset(x + 4, top + 17), Offset(x + 100, top + 17), _s(const Color(0xFFC79A70), 2.4));
      canvas.drawLine(Offset(x + 4, top + 61), Offset(x + 100, top + 61), _s(const Color(0xFFF6D9B8), 2));
      canvas.drawRRect(panel, _s(const Color(0xFFC79A70), 1.4));
    }
    // Thanh nẹp trên.
    canvas.drawRect(const Rect.fromLTRB(0, top - 8, 1280, top + 4), _f(const Color(0xFFC99467)));
    canvas.drawLine(const Offset(0, top - 6), const Offset(1280, top - 6), _s(const Color(0xFFE9BE93), 2));
    canvas.drawLine(const Offset(0, top - 8), const Offset(1280, top - 8), _s(AppColors.caramel, 2.5));
    canvas.drawRect(const Rect.fromLTRB(0, top + 4, 1280, top + 12), _linear(const Offset(0, top + 4), const Offset(0, top + 12), const [Color(0x33B9805A), Color(0x00B9805A)]));
  }

  // ------------------------------------------------------------------ Sàn

  static void _floor(Canvas canvas, DecorId? id) {
    const floor = Rect.fromLTRB(0, wallBottom, 1280, 720);
    switch (id) {
      case DecorId.floorCheckered:
        const tile = 60.0;
        for (var y = wallBottom; y < 720; y += tile) {
          for (var x = 0.0; x < 1280; x += tile) {
            final dark = ((x / tile).floor() + ((y - wallBottom) / tile).floor()).isEven;
            canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), _f(dark ? const Color(0xFFF7C7D3) : const Color(0xFFFFF8EE)));
            canvas.drawLine(Offset(x + 6, y + 5), Offset(x + 24, y + 5), _s(const Color(0x55FFFFFF), 2));
          }
        }
      case DecorId.floorHerringbone:
        canvas.drawRect(floor, _f(const Color(0xFFC99467)));
        const w = 24.0, l = 72.0;
        canvas.save();
        canvas.clipRect(floor);
        for (var y = wallBottom - l; y < 720 + l; y += w * 2) {
          for (var x = -l; x < 1280 + l; x += l) {
            final a = Path()
              ..moveTo(x, y)
              ..lineTo(x + l / 2, y + l / 2)
              ..lineTo(x + l / 2, y + l / 2 + w)
              ..lineTo(x, y + w)
              ..close();
            final b = Path()
              ..moveTo(x + l / 2, y + l / 2)
              ..lineTo(x + l, y)
              ..lineTo(x + l, y + w)
              ..lineTo(x + l / 2, y + l / 2 + w)
              ..close();
            canvas.drawPath(a, _f(const Color(0xFFD4A276)));
            canvas.drawPath(a, _s(const Color(0xFFA9774F), 1.5));
            canvas.drawPath(b, _f(const Color(0xFFC08A5E)));
            canvas.drawPath(b, _s(const Color(0xFFA9774F), 1.5));
          }
        }
        canvas.restore();
      default:
        // Ván gỗ có vân, mỗi tấm một tông.
        final rnd = math.Random(21);
        const tones = [Color(0xFFDDB48A), Color(0xFFD6AB80), Color(0xFFE2BC93), Color(0xFFD9B086)];
        for (var y = wallBottom; y < 720; y += 30) {
          var x = -rnd.nextDouble() * 160;
          while (x < 1280) {
            final len = 160 + rnd.nextDouble() * 140;
            final plank = Rect.fromLTWH(x, y, len, 30);
            canvas.drawRect(plank, _f(tones[rnd.nextInt(tones.length)]));
            for (var g = 0; g < 2; g++) {
              final gy = y + 8 + g * 12 + rnd.nextDouble() * 4;
              final grain = Path()
                ..moveTo(x + 10, gy)
                ..cubicTo(x + len * 0.3, gy - 3, x + len * 0.6, gy + 3, x + len - 10, gy);
              canvas.drawPath(grain, _s(const Color(0x22A0704A), 1.2));
            }
            canvas.drawLine(Offset(x, y + 2), Offset(x, y + 28), _s(const Color(0xFFC49A70), 2));
            x += len;
          }
          canvas.drawLine(Offset(0, y), Offset(1280, y), _s(const Color(0xFFC49A70), 2));
          canvas.drawLine(Offset(0, y + 2), Offset(1280, y + 2), _s(const Color(0x33FFF4E6), 1.2));
        }
    }
    // Sàn tối dần về phía trước, sáng gần chân tường.
    canvas.drawRect(floor, _linear(const Offset(0, wallBottom), const Offset(0, 720), const [Color(0x00000000), Color(0x2A5A3E36)]));
    canvas.drawRect(const Rect.fromLTRB(0, wallBottom, 1280, wallBottom + 14), _linear(const Offset(0, wallBottom), const Offset(0, wallBottom + 14), const [Color(0x405A3E36), Color(0x005A3E36)]));
    canvas.drawLine(const Offset(0, wallBottom), const Offset(1280, wallBottom), _s(_outline, 3));
  }

  // ------------------------------------------------------------------ Cửa sổ

  static void _window(Canvas canvas, DecorId? id) {
    const frame = Rect.fromLTRB(760, 80, 1100, 330);
    final seaView = id == DecorId.windowSeaView;
    final glass = seaView
        ? (Path()
          ..moveTo(frame.left, frame.bottom)
          ..lineTo(frame.left, frame.top + 90)
          ..arcToPoint(Offset(frame.right, frame.top + 90), radius: const Radius.circular(170))
          ..lineTo(frame.right, frame.bottom)
          ..close())
        : (Path()..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(12))));
    // Bóng khung cửa đổ lên tường.
    canvas.drawPath(glass.shift(const Offset(-10, 10)), _f(const Color(0x1F8A5A42)));
    canvas.save();
    canvas.clipPath(glass);
    // Trời.
    final sky = frame.inflate(40);
    canvas.drawRect(sky, _linear(sky.topCenter, Offset(sky.center.dx, frame.top + 180), const [Color(0xFF8CCBEA), Color(0xFFDDF1F7)]));
    canvas.drawCircle(Offset(frame.right - 60, frame.top + 66), 90, _radial(Offset(frame.right - 60, frame.top + 66), 90, const [Color(0x88FFF3C4), Color(0x00FFF3C4)]));
    canvas.drawCircle(Offset(frame.right - 60, frame.top + 66), 24, _f(const Color(0xFFFFF0B5)));
    _cloud(canvas, Offset(frame.left + 80, frame.top + (seaView ? 110 : 64)), 1.0);
    _cloud(canvas, Offset(frame.left + 230, frame.top + (seaView ? 70 : 104)), 0.7);
    if (seaView) {
      _cloud(canvas, Offset(frame.left + 150, frame.top + 40), 0.55);
      _seaView(canvas, frame);
    } else {
      _townView(canvas, frame);
    }
    // Phản chiếu trên kính.
    for (final (x, w) in const [(820.0, 18.0), (850.0, 7.0), (1000.0, 12.0)]) {
      final p = Path()
        ..moveTo(x, frame.top)
        ..lineTo(x + w, frame.top)
        ..lineTo(x + w - 120, frame.bottom)
        ..lineTo(x - 120, frame.bottom)
        ..close();
      canvas.drawPath(p, _f(const Color(0x22FFFFFF)));
    }
    // Viền trong khung tối nhẹ.
    canvas.drawPath(glass, _s(const Color(0x405A3E36), 10));
    canvas.restore();
    // Khung gỗ sơn kem.
    canvas.drawPath(glass, _s(const Color(0xFFFFF8EE), 16));
    canvas.drawPath(glass.shift(const Offset(3, 3)), _s(const Color(0x22B9805A), 4));
    canvas.drawPath(glass, _s(_outline, 3));
    canvas.drawPath(glass, _s(_outline.withValues(alpha: 0.5), 1.4)..strokeWidth = 1.4);
    final midY = frame.center.dy + 20;
    for (final (a, b) in [(Offset(frame.center.dx, seaView ? frame.top - 4 : frame.top), Offset(frame.center.dx, frame.bottom)), (Offset(frame.left, midY), Offset(frame.right, midY))]) {
      canvas.drawLine(a, b, _s(_outline, 11));
      canvas.drawLine(a, b, _s(const Color(0xFFFFF8EE), 7));
    }
    // Bậu cửa.
    final sill = RRect.fromRectAndRadius(Rect.fromLTRB(frame.left - 22, frame.bottom, frame.right + 22, frame.bottom + 16), const Radius.circular(6));
    canvas.drawRect(Rect.fromLTRB(frame.left - 14, frame.bottom + 16, frame.right + 14, frame.bottom + 30), _linear(Offset(0, frame.bottom + 16), Offset(0, frame.bottom + 30), const [Color(0x40B9805A), Color(0x00B9805A)]));
    canvas.drawRRect(sill, _f(const Color(0xFFE7C3A0)));
    canvas.drawLine(Offset(frame.left - 18, frame.bottom + 3), Offset(frame.right + 18, frame.bottom + 3), _s(const Color(0xFFF6DDBF), 2.4));
    canvas.drawRRect(sill, _s(_outline, 2.5));
    _sillPots(canvas, frame);
    if (id == DecorId.windowCurtains) {
      for (final left in [true, false]) {
        final x0 = left ? frame.left - 30 : frame.right + 30;
        final x1 = left ? frame.left + 80 : frame.right - 80;
        final curtain = Path()
          ..moveTo(x0, frame.top - 20)
          ..lineTo(x1, frame.top - 20)
          ..quadraticBezierTo((x0 + x1) / 2, frame.center.dy, x0 + (left ? 30 : -30), frame.bottom - 10)
          ..lineTo(x0, frame.bottom - 10)
          ..close();
        canvas.drawPath(curtain, _f(const Color(0xF2FFFFFF)));
        canvas.save();
        canvas.clipPath(curtain);
        for (var i = 0; i < 4; i++) {
          final x = x0 + (x1 - x0) * (i + 0.5) / 5;
          final fold = Path()
            ..moveTo(x, frame.top - 14)
            ..lineTo(x0 + (x - x0) * 0.6 + (left ? 6 : -6), frame.bottom - 16);
          canvas.drawPath(fold, _s(const Color(0x55F2C8D3), 9));
          canvas.drawPath(fold, _s(const Color(0xFFF2D8DF), 3));
        }
        // Ren chấm hồng ở mép.
        for (var y = frame.top; y < frame.bottom - 10; y += 14) {
          canvas.drawCircle(Offset(x0 + (left ? 6 : -6), y), 2.4, _f(const Color(0xFFF7B6C6)));
        }
        canvas.restore();
        canvas.drawPath(curtain, _s(_outline, 2.5));
        // Dây buộc rèm.
        final tie = Offset(x0 + (left ? 22 : -22), frame.center.dy + 40);
        canvas.drawOval(Rect.fromCenter(center: tie, width: 30, height: 12), _f(AppColors.strawberry));
        canvas.drawOval(Rect.fromCenter(center: tie, width: 30, height: 12), _s(_outline, 2));
      }
      canvas.drawLine(Offset(frame.left - 40, frame.top - 22), Offset(frame.right + 40, frame.top - 22), _s(_outline, 11));
      canvas.drawLine(Offset(frame.left - 40, frame.top - 22), Offset(frame.right + 40, frame.top - 22), _s(AppColors.caramel, 7));
      for (final x in [frame.left - 44, frame.right + 44]) {
        canvas.drawCircle(Offset(x, frame.top - 22), 9, _f(AppColors.caramel));
        canvas.drawCircle(Offset(x, frame.top - 22), 9, _s(_outline, 2));
      }
    }
    _ivy(canvas, frame, arched: seaView);
  }

  static void _cloud(Canvas canvas, Offset at, double k) {
    const puffs = [Offset(-40, 6), Offset(-18, -10), Offset(10, -18), Offset(36, -4), Offset(52, 8), Offset(0, 8), Offset(-30, 12), Offset(28, 12)];
    const radii = [18.0, 22.0, 26.0, 20.0, 14.0, 20.0, 14.0, 16.0];
    for (var i = 0; i < puffs.length; i++) {
      canvas.drawCircle(at + puffs[i] * k + Offset(0, 5 * k), radii[i] * k, _f(const Color(0xFFDCE8F2)));
    }
    for (var i = 0; i < puffs.length; i++) {
      canvas.drawCircle(at + puffs[i] * k, radii[i] * k, _f(const Color(0xFFFFFFFF)));
    }
  }

  static void _townView(Canvas canvas, Rect frame) {
    // Biển xa.
    final horizon = frame.top + 112;
    canvas.drawRect(Rect.fromLTRB(frame.left, horizon, frame.right, frame.bottom), _linear(Offset(0, horizon), Offset(0, horizon + 50), const [Color(0xFF79BFDB), Color(0xFF5FA6C9)]));
    for (var i = 0; i < 8; i++) {
      final x = frame.left + 20 + i * 42.0;
      canvas.drawLine(Offset(x, horizon + 8 + (i % 3) * 6), Offset(x + 14, horizon + 8 + (i % 3) * 6), _s(const Color(0xCCFFFFFF), 1.6));
    }
    // Đồi xanh + mái nhà ven biển.
    final hill = Path()
      ..moveTo(frame.left - 10, frame.bottom)
      ..lineTo(frame.left - 10, horizon + 44)
      ..quadraticBezierTo(frame.left + 120, horizon + 22, frame.left + 230, horizon + 40)
      ..quadraticBezierTo(frame.right - 40, horizon + 52, frame.right + 10, horizon + 40)
      ..lineTo(frame.right + 10, frame.bottom)
      ..close();
    canvas.drawPath(hill, _linear(Offset(0, horizon), Offset(0, frame.bottom), const [Color(0xFFA9D79A), Color(0xFF86C07E)]));
    const houses = [(784.0, 246.0, 0xFFE07A5F), (842.0, 236.0, 0xFF6FB3B8), (912.0, 248.0, 0xFFE9A15E), (982.0, 240.0, 0xFFE07A5F), (1040.0, 252.0, 0xFF8A9FD1)];
    for (final (x, y, roof) in houses) {
      final wall = Rect.fromLTWH(x, y, 44, 34);
      canvas.drawRect(wall, _f(const Color(0xFFFFF8EE)));
      canvas.drawRect(Rect.fromLTWH(x + 26, y, 18, 34), _f(const Color(0xFFEFE2D2)));
      canvas.drawRect(Rect.fromLTWH(x + 8, y + 12, 9, 10), _f(const Color(0xFF7FB3D0)));
      canvas.drawRect(Rect.fromLTWH(x + 28, y + 16, 8, 18), _f(const Color(0xFFB9805A)));
      final r = Path()
        ..moveTo(x - 6, y + 2)
        ..lineTo(x + 22, y - 22)
        ..lineTo(x + 50, y + 2)
        ..close();
      canvas.drawPath(r, _f(Color(roof)));
      canvas.drawLine(Offset(x - 4, y + 1), Offset(x + 22, y - 20), _s(const Color(0x55FFFFFF), 2));
      canvas.drawPath(r, _s(_outline.withValues(alpha: 0.5), 1.4));
      canvas.drawRect(wall, _s(_outline.withValues(alpha: 0.4), 1.2));
    }
    // Cây tròn phía trước.
    for (final (o, r) in const [(Offset(770, 304), 26.0), (Offset(830, 314), 22.0), (Offset(1086, 300), 28.0), (Offset(1030, 318), 20.0), (Offset(950, 320), 24.0), (Offset(892, 326), 18.0)]) {
      canvas.drawCircle(o, r, _f(const Color(0xFF5E9E68)));
      canvas.drawCircle(o.translate(-r * 0.25, -r * 0.25), r * 0.6, _f(const Color(0xFF7DBB77)));
    }
  }

  static void _seaView(Canvas canvas, Rect frame) {
    final horizon = frame.top + 160;
    canvas.drawRect(Rect.fromLTRB(frame.left, horizon, frame.right, frame.bottom), _linear(Offset(0, horizon), Offset(0, frame.bottom), const [Color(0xFF7CC3DD), Color(0xFF4F98C0)]));
    // Đảo xa.
    final island = Path()
      ..moveTo(frame.right - 150, horizon + 1)
      ..quadraticBezierTo(frame.right - 110, horizon - 22, frame.right - 60, horizon + 1)
      ..close();
    canvas.drawPath(island, _f(const Color(0xFF9CC3B0)));
    for (var y = horizon + 18; y < frame.bottom; y += 22) {
      for (var x = frame.left + 10 + (y % 44 == 0 ? 24 : 0); x < frame.right; x += 58) {
        canvas.drawArc(Rect.fromLTWH(x, y, 26, 9), math.pi, math.pi, false, _s(const Color(0xCCE6F6FB), 2.4));
      }
    }
    // Vệt nắng lấp lánh trên mặt nước.
    for (var i = 0; i < 6; i++) {
      final y = horizon + 10 + i * 14.0;
      canvas.drawLine(Offset(frame.right - 80 - i * 6, y), Offset(frame.right - 50 + i * 4, y), _s(const Color(0xDDFFF6D0), 2.4));
    }
    // Mỏm đá + hải đăng.
    final rock = Path()
      ..moveTo(frame.left - 10, frame.bottom)
      ..lineTo(frame.left - 10, horizon + 20)
      ..quadraticBezierTo(frame.left + 70, horizon + 6, frame.left + 120, horizon + 40)
      ..quadraticBezierTo(frame.left + 150, frame.bottom - 20, frame.left + 160, frame.bottom)
      ..close();
    canvas.drawPath(rock, _f(const Color(0xFF9DBF8C)));
    canvas.drawPath(rock, _s(_outline.withValues(alpha: 0.4), 1.6));
    final lh = Path()
      ..moveTo(frame.left + 52, horizon + 16)
      ..lineTo(frame.left + 60, horizon - 46)
      ..lineTo(frame.left + 76, horizon - 46)
      ..lineTo(frame.left + 84, horizon + 16)
      ..close();
    canvas.drawPath(lh, _f(const Color(0xFFFFFFFF)));
    canvas.save();
    canvas.clipPath(lh);
    for (final y in [horizon - 30, horizon - 6]) {
      canvas.drawRect(Rect.fromLTWH(frame.left + 40, y, 60, 10), _f(AppColors.bad));
    }
    canvas.restore();
    canvas.drawPath(lh, _s(_outline, 2));
    canvas.drawRect(Rect.fromLTWH(frame.left + 58, horizon - 62, 20, 16), _f(const Color(0xFFFFE9A0)));
    canvas.drawRect(Rect.fromLTWH(frame.left + 58, horizon - 62, 20, 16), _s(_outline, 2));
    final cap = Path()
      ..moveTo(frame.left + 54, horizon - 62)
      ..lineTo(frame.left + 68, horizon - 76)
      ..lineTo(frame.left + 82, horizon - 62)
      ..close();
    canvas.drawPath(cap, _f(AppColors.bad));
    canvas.drawPath(cap, _s(_outline, 2));
    // Thuyền buồm.
    final hull = Path()
      ..moveTo(frame.left + 190, horizon + 36)
      ..lineTo(frame.left + 236, horizon + 36)
      ..lineTo(frame.left + 228, horizon + 46)
      ..lineTo(frame.left + 198, horizon + 46)
      ..close();
    final sail = Path()
      ..moveTo(frame.left + 214, horizon - 6)
      ..lineTo(frame.left + 214, horizon + 33)
      ..lineTo(frame.left + 236, horizon + 33)
      ..close();
    canvas.drawPath(sail, _f(const Color(0xFFFFF8EE)));
    canvas.drawPath(sail, _s(_outline, 1.6));
    canvas.drawPath(hull, _f(AppColors.caramel));
    canvas.drawPath(hull, _s(_outline, 1.6));
    // Hải âu.
    for (final o in [Offset(frame.left + 170, frame.top + 70), Offset(frame.left + 196, frame.top + 84)]) {
      final gull = Path()
        ..moveTo(o.dx - 9, o.dy)
        ..quadraticBezierTo(o.dx - 4, o.dy - 6, o.dx, o.dy)
        ..quadraticBezierTo(o.dx + 4, o.dy - 6, o.dx + 9, o.dy);
      canvas.drawPath(gull, _s(const Color(0xFF6B7A8A), 1.8));
    }
  }

  /// Hai chậu cây nhỏ trên bậu cửa.
  static void _sillPots(Canvas canvas, Rect frame) {
    for (final (x, flower) in [(frame.left + 30, AppColors.strawberry), (frame.right - 54, AppColors.butter)]) {
      _softShadow(canvas, Rect.fromCenter(center: Offset(x + 12, frame.bottom + 2), width: 44, height: 8));
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.45;
        _leaf(canvas, Offset(x + 12, frame.bottom - 18), 16, a, const Color(0xFF6DB57A));
      }
      for (final o in const [Offset(4, -36), Offset(16, -40), Offset(24, -30)]) {
        for (var k = 0; k < 5; k++) {
          final b = k * math.pi * 2 / 5;
          canvas.drawCircle(Offset(x, frame.bottom) + o + Offset(math.cos(b), math.sin(b)) * 3.5, 3.2, _f(flower));
        }
        canvas.drawCircle(Offset(x, frame.bottom) + o, 2, _f(const Color(0xFFFFFFFF)));
      }
      final pot = Path()
        ..moveTo(x - 2, frame.bottom - 20)
        ..lineTo(x + 26, frame.bottom - 20)
        ..lineTo(x + 22, frame.bottom)
        ..lineTo(x + 2, frame.bottom)
        ..close();
      canvas.drawPath(pot, _f(const Color(0xFFD98C6A)));
      canvas.drawRect(Rect.fromLTWH(x - 3, frame.bottom - 22, 30, 6), _f(const Color(0xFFE6A07F)));
      canvas.drawPath(pot, _s(_outline, 2));
      canvas.drawRect(Rect.fromLTWH(x - 3, frame.bottom - 22, 30, 6), _s(_outline, 2));
    }
  }

  /// Dây thường xuân bò dọc mép trên và trái khung cửa.
  static void _ivy(Canvas canvas, Rect frame, {bool arched = false}) {
    final vine = arched
        ? (Path()
          ..moveTo(frame.left + 90, frame.top - 66)
          ..quadraticBezierTo(frame.left - 14, frame.top - 30, frame.left - 10, frame.top + 90)
          ..quadraticBezierTo(frame.left - 16, frame.top + 130, frame.left - 10, frame.top + 170))
        : (Path()
          ..moveTo(frame.left + 140, frame.top - 14)
          ..quadraticBezierTo(frame.left + 60, frame.top - 2, frame.left - 8, frame.top + 6)
          ..quadraticBezierTo(frame.left - 22, frame.top + 70, frame.left - 12, frame.top + 150));
    canvas.drawPath(vine, _s(const Color(0xFF6C8C4E), 2.6));
    final rnd = math.Random(5);
    for (final m in vine.computeMetrics()) {
      for (var d = 6.0; d < m.length; d += 15) {
        final t = m.getTangentForOffset(d)!;
        final side = (d ~/ 15).isEven ? 1.0 : -1.0;
        final a = t.angle + side * (0.9 + rnd.nextDouble() * 0.4);
        _leaf(canvas, t.position, 13 + rnd.nextDouble() * 5, -a + (side > 0 ? 0 : math.pi), (d ~/ 15) % 3 == 0 ? const Color(0xFF7DBB77) : const Color(0xFF5E9E68));
      }
    }
  }

  /// Chậu dây leo treo trần góc phải.
  static void _hangingPlant(Canvas canvas) {
    const at = Offset(1196, 166);
    for (final dx in const [-26.0, 0.0, 26.0]) {
      canvas.drawLine(const Offset(1196, 0), at + Offset(dx, -12), _s(const Color(0xFFB9805A), 1.6));
    }
    for (final (start, len) in const [(Offset(1176, 176), 90.0), (Offset(1196, 180), 130.0), (Offset(1218, 176), 70.0)]) {
      final strand = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(start.dx + 10, start.dy + len * 0.5, start.dx - 4, start.dy + len);
      canvas.drawPath(strand, _s(const Color(0xFF6C8C4E), 2));
      for (final m in strand.computeMetrics()) {
        for (var d = 8.0; d < m.length; d += 14) {
          final t = m.getTangentForOffset(d)!;
          final side = (d ~/ 14).isEven ? 1.0 : -1.0;
          _leaf(canvas, t.position, 12, side > 0 ? 0.4 : math.pi - 0.4, (d ~/ 14) % 3 == 0 ? const Color(0xFF7DBB77) : const Color(0xFF5E9E68));
        }
      }
    }
    for (var i = 0; i < 6; i++) {
      _leaf(canvas, at + const Offset(0, -12), 22, -math.pi / 2 + (i - 2.5) * 0.5, const Color(0xFF6DB57A));
    }
    final pot = Path()
      ..moveTo(at.dx - 30, at.dy - 14)
      ..lineTo(at.dx + 30, at.dy - 14)
      ..quadraticBezierTo(at.dx + 26, at.dy + 16, at.dx, at.dy + 18)
      ..quadraticBezierTo(at.dx - 26, at.dy + 16, at.dx - 30, at.dy - 14)
      ..close();
    canvas.drawPath(pot, _f(const Color(0xFFF2DCC2)));
    canvas.drawPath(Path()..addRect(Rect.fromLTWH(at.dx - 30, at.dy - 4, 60, 7)), _f(AppColors.mint));
    canvas.drawPath(pot, _s(_outline, 2.5));
  }

  // ------------------------------------------------------------------ Nắng chiều

  static void _sunbeams(Canvas canvas) {
    // Ba dải nắng xiên từ cửa sổ xuống sàn bên trái, mép mờ dần.
    const dir = Offset(-0.62, 1);
    for (final (x, w, a) in const [(790.0, 90.0, 0.34), (905.0, 60.0, 0.26), (990.0, 80.0, 0.3)]) {
      for (var layer = 0; layer < 3; layer++) {
        final grow = layer * 10.0;
        final top = Offset(x - grow, 90);
        const len = 600.0;
        final p = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(top.dx + w + grow * 2, top.dy)
          ..lineTo(top.dx + w + grow * 2 + dir.dx * len, top.dy + dir.dy * len)
          ..lineTo(top.dx + dir.dx * len, top.dy + dir.dy * len)
          ..close();
        final alpha = a / (layer + 1.5);
        canvas.drawPath(
          p,
          _linear(top, top + dir * len, [const Color(0xFFFFF4CF).withValues(alpha: alpha), const Color(0xFFFFF4CF).withValues(alpha: alpha * 0.6), const Color(0x00FFF4CF)], const [0, 0.55, 1]),
        );
      }
    }
    // Vệt nắng đọng trên sàn.
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, wallBottom, 1280, 720));
    for (final (x, w) in const [(450.0, 90.0), (565.0, 60.0), (650.0, 80.0)]) {
      final p = Path()
        ..moveTo(x, wallBottom)
        ..lineTo(x + w, wallBottom)
        ..lineTo(x + w - 110, 720)
        ..lineTo(x - 110, 720)
        ..close();
      canvas.drawPath(p, _f(const Color(0x30FFF4CF)));
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------ Kệ + đèn

  static void _shelf(Canvas canvas) {
    const board = Rect.fromLTRB(120, 250, 520, 266);
    // Bóng kệ trên tường.
    canvas.drawRect(const Rect.fromLTRB(126, 266, 520, 296), _linear(const Offset(0, 266), const Offset(0, 296), const [Color(0x38B9805A), Color(0x00B9805A)]));
    // Ke đỡ.
    for (final x in const [160.0, 470.0]) {
      final bracket = Path()
        ..moveTo(x, 266)
        ..lineTo(x + 26, 266)
        ..quadraticBezierTo(x + 6, 272, x + 4, 300)
        ..lineTo(x, 300)
        ..close();
      canvas.drawPath(bracket, _f(const Color(0xFFB9805A)));
      canvas.drawPath(bracket, _s(_outline, 2));
    }
    // Đồ trên kệ: bóng mềm trước.
    for (var i = 0; i < 4; i++) {
      _softShadow(canvas, Rect.fromCenter(center: Offset(165 + i * 66.0, 250), width: 62, height: 10));
    }
    _softShadow(canvas, Rect.fromCenter(center: const Offset(455, 250), width: 84, height: 10));
    // Hũ thuỷ tinh có nguyên liệu.
    const contents = [Color(0xFFFFF8EC), Color(0xFFFFFFFF), Color(0xFFD9A055), Color(0xFFF7C7D3)];
    const lids = [Color(0xFFB9805A), Color(0xFFF49AB0), Color(0xFFA8DCC8), Color(0xFFB9805A)];
    for (var i = 0; i < 4; i++) {
      final r = Rect.fromLTWH(140 + i * 66.0, 186, 50, 64);
      final jar = RRect.fromRectAndRadius(r, const Radius.circular(10));
      canvas.drawRRect(jar, _f(const Color(0x66FFFFFF)));
      canvas.save();
      canvas.clipRRect(jar);
      final fill = Rect.fromLTRB(r.left, r.top + 22, r.right, r.bottom);
      canvas.drawRect(fill, _f(contents[i]));
      switch (i) {
        case 1:
          for (var y = fill.top + 4; y < fill.bottom; y += 11) {
            for (var x = fill.left + 3 + ((y ~/ 11).isOdd ? 5 : 0); x < fill.right; x += 12) {
              canvas.drawRect(Rect.fromLTWH(x, y, 9, 9), _f(const Color(0xFFFFFFFF)));
              canvas.drawRect(Rect.fromLTWH(x, y, 9, 9), _s(const Color(0x33B9805A), 1));
            }
          }
        case 2:
          for (final o in const [Offset(12, 34), Offset(34, 30), Offset(22, 48), Offset(40, 52), Offset(8, 54)]) {
            canvas.drawCircle(r.topLeft + o, 9, _f(const Color(0xFFD9A055)));
            canvas.drawCircle(r.topLeft + o, 9, _s(const Color(0xFFB07A3E), 1.2));
            canvas.drawCircle(r.topLeft + o + const Offset(-2, -2), 1.8, _f(const Color(0xFF5A3E36)));
          }
        case 3:
          final rnd = math.Random(9);
          for (var k = 0; k < 26; k++) {
            final p = Offset(fill.left + rnd.nextDouble() * fill.width, fill.top + rnd.nextDouble() * fill.height);
            canvas.drawLine(p, p + const Offset(4, -2), _s([AppColors.mint, AppColors.butter, const Color(0xFF9FC5E8), AppColors.bad][k % 4], 2.2));
          }
        default:
          canvas.drawLine(Offset(fill.left, fill.top + 2), Offset(fill.right, fill.top + 6), _s(const Color(0x22B9805A), 2));
      }
      canvas.drawLine(Offset(r.left + 9, r.top + 10), Offset(r.left + 9, r.bottom - 10), _s(const Color(0xAAFFFFFF), 4));
      canvas.restore();
      canvas.drawRRect(jar, _s(_outline, 2.5));
      // Nhãn.
      final label = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 12, r.top + 32, 26, 16), const Radius.circular(3));
      canvas.drawRRect(label, _f(const Color(0xFFFFF4E6)));
      canvas.drawLine(Offset(r.left + 16, r.top + 40), Offset(r.left + 34, r.top + 40), _s(AppColors.caramel, 1.6));
      canvas.drawRRect(label, _s(_outline, 1.4));
      // Nắp.
      final lid = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 4, r.top - 10, r.width - 8, 13), const Radius.circular(4));
      canvas.drawRRect(lid, _f(lids[i]));
      canvas.drawLine(Offset(r.left + 8, r.top - 7), Offset(r.right - 10, r.top - 7), _s(const Color(0x55FFFFFF), 2));
      canvas.drawRRect(lid, _s(_outline, 2));
    }
    // Cuốn sổ công thức của bà (dựng nghiêng) + chồng sách nhỏ.
    final small = RRect.fromRectAndRadius(const Rect.fromLTWH(492, 214, 18, 36), const Radius.circular(3));
    canvas.drawRRect(small, _f(const Color(0xFF9FC5E8)));
    canvas.drawRRect(small, _s(_outline, 2));
    final book = RRect.fromRectAndRadius(const Rect.fromLTWH(418, 196, 70, 54), const Radius.circular(6));
    canvas.drawRect(const Rect.fromLTWH(424, 244, 62, 6), _f(const Color(0xFFFFF8EC)));
    canvas.drawRRect(book, _f(AppColors.strawberry));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(418, 196, 14, 54), const Radius.circular(6)), _f(const Color(0xFFE07F98)));
    canvas.drawLine(const Offset(436, 202), const Offset(484, 202), _s(const Color(0x55FFFFFF), 2));
    canvas.drawRRect(book, _s(_outline, 2.5));
    canvas.drawLine(const Offset(432, 196), const Offset(432, 250), _s(_outline, 2));
    ItemArt.paintTopping(canvas, const Rect.fromLTWH(444, 206, 34, 34), ToppingId.mintLeaf);
    // Tấm kệ gỗ có vân.
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(4)), _f(const Color(0xFFC99467)));
    for (final y in const [255.0, 260.0]) {
      final grain = Path()
        ..moveTo(board.left + 8, y)
        ..cubicTo(220, y - 2, 330, y + 2, board.right - 8, y);
      canvas.drawPath(grain, _s(const Color(0x33805A3C), 1.2));
    }
    canvas.drawLine(Offset(board.left + 4, board.top + 2), Offset(board.right - 4, board.top + 2), _s(const Color(0xFFE6B98C), 2));
    canvas.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(4)), _s(_outline, 2.5));
    // Dây thường xuân rủ từ đầu kệ.
    final vine = Path()
      ..moveTo(130, 262)
      ..quadraticBezierTo(116, 300, 128, 350);
    canvas.drawPath(vine, _s(const Color(0xFF6C8C4E), 2));
    for (final m in vine.computeMetrics()) {
      for (var d = 4.0; d < m.length; d += 13) {
        final t = m.getTangentForOffset(d)!;
        final side = (d ~/ 13).isEven ? 1.0 : -1.0;
        _leaf(canvas, t.position, 12, side > 0 ? 0.3 : math.pi - 0.3, (d ~/ 13) % 3 == 0 ? const Color(0xFF7DBB77) : const Color(0xFF5E9E68));
      }
    }
  }

  static void _lamp(Canvas canvas) {
    for (final x in const [360.0, 640.0]) {
      // Quầng sáng ấm.
      canvas.drawCircle(Offset(x, 118), 190, _radial(Offset(x, 118), 190, const [Color(0x88FFE6A0), Color(0x33FFE6A0), Color(0x00FFE6A0)], const [0, 0.4, 1]));
      canvas.drawLine(Offset(x, 0), Offset(x, 64), _s(_outline, 2.5));
      canvas.drawRect(Rect.fromCenter(center: Offset(x, 66), width: 12, height: 10), _f(AppColors.caramel));
      canvas.drawRect(Rect.fromCenter(center: Offset(x, 66), width: 12, height: 10), _s(_outline, 2));
      final shade = Path()
        ..moveTo(x - 42, 110)
        ..quadraticBezierTo(x - 30, 66, x, 66)
        ..quadraticBezierTo(x + 30, 66, x + 42, 110)
        ..close();
      canvas.drawCircle(Offset(x, 112), 16, _radial(Offset(x, 112), 16, const [Color(0xFFFFFFFF), Color(0xFFFFF0B8)]));
      canvas.drawPath(shade, _f(AppColors.mint));
      canvas.save();
      canvas.clipPath(shade);
      canvas.drawRect(Rect.fromLTRB(x - 42, 66, x - 18, 112), _f(const Color(0x22000000)));
      canvas.drawLine(Offset(x + 14, 74), Offset(x + 30, 104), _s(const Color(0x88FFFFFF), 4));
      canvas.restore();
      canvas.drawPath(shade, _s(_outline, 2.5));
      canvas.drawLine(Offset(x - 42, 110), Offset(x + 42, 110), _s(const Color(0xFF7FC2A8), 3));
      // Nón sáng mờ phía dưới.
      final cone = Path()
        ..moveTo(x - 34, 112)
        ..lineTo(x + 34, 112)
        ..lineTo(x + 110, 300)
        ..lineTo(x - 110, 300)
        ..close();
      canvas.drawPath(cone, _linear(Offset(x, 112), Offset(x, 300), const [Color(0x30FFF0B8), Color(0x00FFF0B8)]));
    }
  }

  // ------------------------------------------------------------------ Quầy

  static void _counter(Canvas canvas, DecorId? id) {
    const top = Rect.fromLTRB(20, 486, 1260, 512);
    final front = Rect.fromLTRB(counterRect.left, top.bottom, counterRect.right, counterRect.bottom);
    // Bóng quầy trên sàn.
    canvas.drawRect(Rect.fromLTRB(counterRect.left - 10, counterRect.bottom, counterRect.right + 10, counterRect.bottom + 34),
        _linear(Offset(0, counterRect.bottom), Offset(0, counterRect.bottom + 34), const [Color(0x445A3E36), Color(0x005A3E36)]));
    canvas.drawRect(front, _linear(front.topCenter, front.bottomCenter, const [Color(0xFFF6E3CC), Color(0xFFEBCFAF)]));
    final panels = ((front.width + 30) / 100).floor();
    final x0 = front.left + (front.width - (panels * 100 - 30)) / 2;
    for (var x = x0; x + 70 <= front.right; x += 100) {
      final panel = RRect.fromRectAndRadius(Rect.fromLTWH(x, front.top + 24, 70, front.height - 52), const Radius.circular(10));
      canvas.drawRRect(panel, _f(const Color(0xFFF3DCC0)));
      canvas.drawLine(Offset(x + 6, front.top + 25), Offset(x + 64, front.top + 25), _s(const Color(0xFFCFAA82), 3));
      canvas.drawLine(Offset(x + 6, front.bottom - 29), Offset(x + 64, front.bottom - 29), _s(const Color(0xFFFFF4E6), 2.4));
      canvas.drawRRect(panel, _s(const Color(0xFFD9B894), 2));
    }
    // Chân quầy.
    canvas.drawRect(Rect.fromLTRB(front.left, front.bottom - 12, front.right, front.bottom), _f(const Color(0xFFD9B48C)));
    // Bóng mép mặt quầy.
    canvas.drawRect(Rect.fromLTRB(front.left, front.top, front.right, front.top + 18), _linear(front.topLeft, Offset(front.left, front.top + 18), const [Color(0x445A3E36), Color(0x005A3E36)]));
    canvas.drawRect(front, _s(_outline, 3));
    // Mặt quầy gỗ có vân.
    canvas.drawRRect(RRect.fromRectAndRadius(top, const Radius.circular(8)), _f(const Color(0xFFC99467)));
    final rnd = math.Random(17);
    for (var i = 0; i < 9; i++) {
      final y = top.top + 6 + rnd.nextDouble() * 14;
      final x0 = top.left + rnd.nextDouble() * 1100;
      final grain = Path()
        ..moveTo(x0, y)
        ..cubicTo(x0 + 60, y - 3, x0 + 120, y + 3, x0 + 180, y);
      canvas.drawPath(grain, _s(const Color(0x33805A3C), 1.4));
    }
    canvas.drawLine(Offset(top.left + 8, top.top + 3), Offset(top.right - 8, top.top + 3), _s(const Color(0xFFE6B98C), 2.4));
    canvas.drawRRect(RRect.fromRectAndRadius(top, const Radius.circular(8)), _s(_outline, 3));
    _register(canvas);

    switch (id) {
      case DecorId.counterFlowers:
        _softShadow(canvas, Rect.fromCenter(center: const Offset(1020, 487), width: 90, height: 12));
        final vase = Path()
          ..moveTo(1000, 486)
          ..quadraticBezierTo(980, 450, 1000, 420)
          ..lineTo(1040, 420)
          ..quadraticBezierTo(1060, 450, 1040, 486)
          ..close();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + (i - 2) * 0.35;
          final tip = Offset(1020 + math.cos(a) * 70, 420 + math.sin(a) * 70);
          canvas.drawLine(const Offset(1020, 425), tip, _s(const Color(0xFF5DB37E), 3));
          _leaf(canvas, Offset.lerp(const Offset(1020, 425), tip, 0.5)!, 14, a + (i.isEven ? 0.8 : -0.8), const Color(0xFF6DB57A));
          for (var k = 0; k < 5; k++) {
            final b = k * math.pi * 2 / 5;
            canvas.drawCircle(tip + Offset(math.cos(b), math.sin(b)) * 8, 7, _f(i.isEven ? AppColors.strawberry : AppColors.butter));
            canvas.drawCircle(tip + Offset(math.cos(b), math.sin(b)) * 8, 7, _s(_outline.withValues(alpha: 0.35), 1));
          }
          canvas.drawCircle(tip, 5, _f(const Color(0xFFFFFFFF)));
        }
        canvas.drawPath(vase, _f(const Color(0xFF9FC5E8)));
        canvas.save();
        canvas.clipPath(vase);
        canvas.drawRect(const Rect.fromLTRB(1028, 420, 1060, 486), _f(const Color(0x33000000)));
        canvas.drawLine(const Offset(1004, 430), const Offset(1000, 474), _s(const Color(0xAAFFFFFF), 4));
        canvas.restore();
        canvas.drawPath(vase, _s(_outline, 2.5));
      case DecorId.counterCakeStand:
        _softShadow(canvas, Rect.fromCenter(center: const Offset(1020, 487), width: 170, height: 14));
        canvas.drawLine(const Offset(1020, 486), const Offset(1020, 390), _s(_outline, 4));
        canvas.drawLine(const Offset(1020, 486), const Offset(1020, 390), _s(const Color(0xFFE6C9A8), 2));
        for (var tier = 0; tier < 3; tier++) {
          final y = 480.0 - tier * 40;
          final w = 150.0 - tier * 40;
          final plate = Rect.fromCenter(center: Offset(1020, y), width: w, height: 14);
          canvas.drawOval(plate, _f(const Color(0xFFFFFFFF)));
          canvas.drawArc(plate, 0, math.pi, false, _s(const Color(0xFFE3D6CC), 3));
          canvas.drawOval(plate, _s(_outline, 2));
          for (var k = 0; k < 3 - tier; k++) {
            final x = 1020 - (2 - tier) * 22.0 + k * 44;
            ItemArt.paintTopping(canvas, Rect.fromCenter(center: Offset(x, y - 14), width: 26, height: 26),
                tier == 0 ? ToppingId.strawberry : (tier == 1 ? ToppingId.sugarPearl : ToppingId.cherry));
          }
        }
      default:
        // Cơ bản: lọ bánh quy thuỷ tinh.
        _softShadow(canvas, Rect.fromCenter(center: const Offset(1022, 487), width: 84, height: 12));
        final jarRect = const Rect.fromLTWH(990, 436, 64, 50);
        final jar = RRect.fromRectAndRadius(jarRect, const Radius.circular(12));
        canvas.drawRRect(jar, _f(const Color(0x88FFFFFF)));
        canvas.save();
        canvas.clipRRect(jar);
        for (final c in const [Offset(1008, 470), Offset(1034, 472), Offset(1020, 456), Offset(1044, 456), Offset(1000, 452)]) {
          canvas.drawCircle(c, 10, _f(const Color(0xFFD9A055)));
          canvas.drawCircle(c, 10, _s(const Color(0xFFB07A3E), 1.2));
          canvas.drawCircle(c + const Offset(-3, -2), 1.8, _f(_outline));
          canvas.drawCircle(c + const Offset(3, 2), 1.6, _f(_outline));
        }
        canvas.drawLine(const Offset(998, 444), const Offset(998, 478), _s(const Color(0xBBFFFFFF), 4));
        canvas.restore();
        canvas.drawRRect(jar, _s(_outline, 2.5));
        final lid = RRect.fromRectAndRadius(const Rect.fromLTWH(986, 426, 72, 12), const Radius.circular(5));
        canvas.drawRRect(lid, _f(AppColors.strawberry));
        canvas.drawRRect(lid, _s(_outline, 2.2));
        canvas.drawCircle(const Offset(1022, 422), 6, _f(AppColors.strawberry));
        canvas.drawCircle(const Offset(1022, 422), 6, _s(_outline, 2));
    }
  }

  static void _register(Canvas canvas) {
    _softShadow(canvas, Rect.fromCenter(center: const Offset(116, 487), width: 120, height: 12));
    // Cuộn giấy hoá đơn.
    canvas.drawRect(const Rect.fromLTWH(128, 412, 22, 20), _f(const Color(0xFFFFFDF8)));
    canvas.drawRect(const Rect.fromLTWH(128, 412, 22, 20), _s(_outline, 2));
    final body = Path()
      ..moveTo(70, 486)
      ..lineTo(76, 440)
      ..quadraticBezierTo(78, 430, 90, 430)
      ..lineTo(146, 430)
      ..quadraticBezierTo(158, 430, 160, 440)
      ..lineTo(164, 486)
      ..close();
    canvas.drawPath(body, _f(AppColors.mint));
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(const Rect.fromLTRB(60, 470, 170, 490), _f(const Color(0x22000000)));
    canvas.drawLine(const Offset(80, 436), const Offset(150, 436), _s(const Color(0x88FFFFFF), 3));
    canvas.restore();
    canvas.drawPath(body, _s(_outline, 2.5));
    final screen = RRect.fromRectAndRadius(const Rect.fromLTWH(86, 440, 58, 14), const Radius.circular(3));
    canvas.drawRRect(screen, _f(const Color(0xFFEAF7EF)));
    canvas.drawRRect(screen, _s(_outline, 1.6));
    for (var r = 0; r < 2; r++) {
      for (var k = 0; k < 4; k++) {
        final key = RRect.fromRectAndRadius(Rect.fromLTWH(88 + k * 14.0, 460 + r * 10.0, 10, 7), const Radius.circular(2));
        canvas.drawRRect(key, _f(k == 3 && r == 1 ? AppColors.strawberry : const Color(0xFFFFF8EE)));
        canvas.drawRRect(key, _s(_outline, 1.2));
      }
    }
  }

  // ------------------------------------------------------------------ Cây

  static void _plant(Canvas canvas, DecorId? id) {
    if (id == null) return;
    _softShadow(canvas, Rect.fromCenter(center: const Offset(1205, 712), width: 120, height: 16), alpha: 0.32);
    final pot = Path()
      ..moveTo(1160, 640)
      ..lineTo(1250, 640)
      ..lineTo(1236, 710)
      ..lineTo(1174, 710)
      ..close();
    if (id == DecorId.plantFern) {
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2 + (i - 3) * 0.4;
        final end = Offset(1205 + math.cos(a) * 110, 640 + math.sin(a) * 100);
        final frond = Path()
          ..moveTo(1205, 640)
          ..quadraticBezierTo((1205 + end.dx) / 2 + 20, (640 + end.dy) / 2 - 20, end.dx, end.dy);
        canvas.drawPath(frond, _s(const Color(0xFF4E9E6A), 3));
        for (final m in frond.computeMetrics()) {
          for (var d = 10.0; d < m.length; d += 9) {
            final t = m.getTangentForOffset(d)!;
            final size = 16 * (1 - d / m.length) + 6;
            _leaf(canvas, t.position, size, -t.angle - 1.1, i.isEven ? const Color(0xFF6DB57A) : const Color(0xFF7BC47F));
            _leaf(canvas, t.position, size, -t.angle + 1.1 + math.pi * 0, i.isEven ? const Color(0xFF5E9E68) : const Color(0xFF6DB57A));
          }
        }
      }
    } else {
      canvas.drawLine(const Offset(1205, 640), const Offset(1205, 520), _s(_outline, 12));
      canvas.drawLine(const Offset(1205, 640), const Offset(1205, 520), _s(const Color(0xFF8A5A42), 8));
      canvas.drawCircle(const Offset(1205, 480), 70, _f(const Color(0xFF5E9E68)));
      canvas.drawCircle(const Offset(1192, 466), 52, _f(const Color(0xFF6DB57A)));
      canvas.drawCircle(const Offset(1180, 452), 28, _f(const Color(0xFF86C885)));
      canvas.drawCircle(const Offset(1205, 480), 70, _s(_outline, 2.5));
      for (var i = 0; i < 14; i++) {
        final a = i * 2.4;
        _leaf(canvas, const Offset(1205, 480) + Offset(math.cos(a), math.sin(a)) * 62, 16, a, const Color(0xFF5E9E68));
      }
      for (final c in const [Offset(1170, 460), Offset(1230, 450), Offset(1200, 510), Offset(1240, 500), Offset(1160, 505)]) {
        canvas.drawOval(Rect.fromCenter(center: c, width: 20, height: 24), _f(const Color(0xFFFFE066)));
        canvas.drawOval(Rect.fromCenter(center: c.translate(3, 3), width: 10, height: 14), _f(const Color(0x33B9805A)));
        canvas.drawCircle(c.translate(-4, -5), 2.4, _f(const Color(0xCCFFFFFF)));
        canvas.drawOval(Rect.fromCenter(center: c, width: 20, height: 24), _s(_outline, 1.5));
      }
    }
    canvas.drawPath(pot, _f(AppColors.caramel));
    canvas.save();
    canvas.clipPath(pot);
    canvas.drawRect(const Rect.fromLTRB(1150, 640, 1186, 712), _f(const Color(0x22000000)));
    canvas.drawLine(const Offset(1236, 650), const Offset(1228, 700), _s(const Color(0x55FFFFFF), 4));
    canvas.restore();
    canvas.drawPath(pot, _s(_outline, 3));
    canvas.drawRect(const Rect.fromLTRB(1154, 632, 1256, 646), _f(const Color(0xFFC99467)));
    canvas.drawRect(const Rect.fromLTRB(1154, 632, 1256, 646), _s(_outline, 2.5));
  }
}
