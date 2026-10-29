import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../core/theme.dart';
import '../sl_theme.dart';
import 'hand_drawn.dart';
import 'sl_cache.dart';
import 'sl_random.dart';

/// Mọi id icon của bộ SL* (tên file ảnh vẽ tay tương lai: `assets/art/icons/<id>.webp`).
const kSLIconIds = <String>[
  'settings', 'close', 'back', 'forward', 'arrow_up', 'arrow_down', 'skip', 'exit', //
  'check', 'lock', 'info', 'warning', 'error', 'medal_max', //
  'sound_on', 'sound_off', 'language', 'phone', 'trash', 'reset', //
  'play_video', 'no_ads', 'shop_bag', 'basket', 'quest_board', //
  'decor_chair', 'slot_wallpaper', 'slot_floor', 'slot_counter', 'slot_window', 'slot_plant', //
  'heart', 'vip', 'customer', 'sun', 'umbrella', 'raindrop', 'paw', 'moon', 'flame', 'sparkle', //
  'trophy', 'confetti', 'clock', 'tip_jar', 'bulb', 'leaf_logo', 'pin', 'plus', 'cake_slice', //
  // Thêm ở Bước 3 (ánh xạ Material Icons → SL, xem `sl_icon_map.dart`).
  'book', 'star', 'oven', 'gift', 'tap', 'storefront', 'coin', 'ticket',
];

/// Icon đã có hình vẽ riêng bằng code. Mọi id trong [kSLIconIds] đều có (test kiểm); id lạ mới rơi về hình dự
/// phòng chung (vòng tròn + chữ cái đầu).
bool slIconHasDrawing(String id) => _drawings.containsKey(id);

/// Icon vẽ sẵn trong cache.
class SLIconArt implements SLCachedArt {
  SLIconArt(this.size, this.picture);

  final double size;
  final ui.Picture picture;

  @override
  void dispose() => picture.dispose();
}

/// Icon vẽ bằng code (nét mực run tay + tô màu nước) cỡ [size], lấy từ cache (khoá: id, cỡ làm tròn 0,5px,
/// màu mực, mờ).
SLIconArt slIconArt(String id, double size, {Color ink = SLColors.ink, bool dimmed = false}) {
  final s = math.max(4.0, (size * 2).round() / 2);
  return SLPaintCache.icons.obtain((id, s, ink, dimmed), () => _build(id, s, ink, dimmed)) as SLIconArt;
}

SLIconArt _build(String id, double s, Color ink, bool dimmed) {
  final recorder = ui.PictureRecorder();
  final pen = _Pen(Canvas(recorder), s, dimmed ? SLColors.disabledInk : ink, SLRandom(SLRandom.mix(SLRandom.hashString(id), 3)), dimmed);
  final draw = _drawings[id];
  if (draw != null) {
    draw(pen);
  } else {
    pen.both(pen.circle(.5, .5, .4), SLColors.paperShade);
    pen.letter(id.isEmpty ? '•' : id[0].toUpperCase());
  }
  return SLIconArt(s, recorder.endRecording());
}

/// Bút vẽ icon trong hệ toạ độ đơn vị 0..1 (nhân với cỡ [s]).
class _Pen {
  _Pen(this.canvas, this.s, this.ink, this.rnd, this.dimmed)
      : amp = (s * 0.018).clamp(0.35, 1.1),
        weight = math.max(1.4, s * 0.072);

  final Canvas canvas;
  final double s;
  final Color ink;
  final SLRandom rnd;
  final bool dimmed;
  final double amp;
  final double weight;

  Offset o(double x, double y) => Offset(x * s, y * s);

  Path poly(List<double> xy, {bool close = true}) {
    final p = Path()..moveTo(xy[0] * s, xy[1] * s);
    for (var i = 2; i < xy.length; i += 2) {
      p.lineTo(xy[i] * s, xy[i + 1] * s);
    }
    if (close) p.close();
    return p;
  }

  Path seg(double x1, double y1, double x2, double y2) => poly([x1, y1, x2, y2], close: false);

  Path circle(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: o(cx, cy), radius: r * s));

  Path oval(double cx, double cy, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(center: o(cx, cy), width: rx * 2 * s, height: ry * 2 * s));

  /// Chữ nhật bo góc [r] (đơn vị 0..1).
  Path rrect(double l, double t, double r2, double b, double r) =>
      Path()..addRRect(RRect.fromLTRBR(l * s, t * s, r2 * s, b * s, Radius.circular(r * s)));

  Path arc(double cx, double cy, double r, double start, double sweep) =>
      Path()..addArc(Rect.fromCircle(center: o(cx, cy), radius: r * s), start, sweep);

  Path _hand(Path p) => wobblePath(p, seed: rnd.nextInt32(), amplitude: amp, step: math.max(1.5, s / 16));

  /// Tô màu nước: lệch nét mực một chút, mép đọng màu đậm hơn. Icon cỡ lớn (≥ 40px, làm hình minh hoạ) thêm mép
  /// đọng loang rộng, vùng sáng như giấy lộ ra và vệt loang đậm — để không thành mảng màu phẳng.
  void wash(Path ideal, Color color) {
    final c = dimmed ? Color.lerp(color, SLColors.disabledFill, 0.6)! : color;
    final shifted = ideal.shift(Offset(rnd.range(-0.6, 0.6), rnd.range(-0.3, 0.7)) * (s / 32));
    final p = _hand(shifted);
    final edge = Color.lerp(c, const Color(0xFF6B4532), 0.35)!;
    canvas.drawPath(p, Paint()..color = c.withValues(alpha: 0.92));
    if (s >= 40) {
      final b = p.getBounds();
      canvas
        ..save()
        ..clipPath(p);
      for (final (k, a) in const [(0.14, 0.1), (0.07, 0.12)]) {
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * k
            ..color = edge.withValues(alpha: a),
        );
      }
      Path blob(double cx, double cy, double rx, double ry) => wobblePath(
            Path()..addOval(Rect.fromCenter(center: Offset(b.left + b.width * cx, b.top + b.height * cy), width: b.width * rx, height: b.height * ry)),
            seed: rnd.nextInt32(),
            amplitude: math.max(0.8, b.shortestSide * 0.05),
            step: 3,
          );
      canvas.drawPath(blob(rnd.range(0.32, 0.45), rnd.range(0.26, 0.36), 0.5, 0.34), Paint()..color = const Color(0x40FFFFFF));
      canvas.drawPath(blob(rnd.range(0.55, 0.7), rnd.range(0.66, 0.78), 0.34, 0.26), Paint()..color = edge.withValues(alpha: 0.1));
      canvas.restore();
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.04)
        ..color = edge.withValues(alpha: 0.35),
    );
  }

  /// Nét mực run tay; [k] = hệ số độ đậm.
  void line(Path ideal, {double k = 1}) {
    canvas.drawPath(
      _hand(ideal),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = weight * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  void both(Path ideal, Color color, {double k = 1}) {
    wash(ideal, color);
    line(ideal, k: k);
  }

  void dot(double cx, double cy, double r) => canvas.drawPath(_hand(circle(cx, cy, r)), Paint()..color = ink);

  void letter(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: ink, fontFamily: AppTheme.nunito, fontSize: s * 0.44, fontWeight: FontWeight.w800, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o(.5, .5) - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }
}

// ---------------------------------------------------------------------------------------------------- Hình icon

const _paper = SLColors.paper;
const _butter = SLColors.butter;
const _mint = SLColors.mint;
const _berry = SLColors.strawberry;

final Map<String, void Function(_Pen p)> _drawings = {
  'settings': (p) {
    final pts = <double>[];
    for (var i = 0; i < 32; i++) {
      final a = i / 32 * 2 * math.pi - math.pi / 32, r = i % 4 < 2 ? .44 : .32;
      pts..add(.5 + math.cos(a) * r)..add(.5 + math.sin(a) * r);
    }
    p.both(p.poly(pts), _butter);
    p.both(p.circle(.5, .5, .12), _paper);
  },
  'close': (p) {
    p.line(p.seg(.26, .26, .74, .74), k: 1.4);
    p.line(p.seg(.74, .26, .26, .74), k: 1.4);
  },
  'back': (p) {
    p.line(p.seg(.8, .5, .22, .5), k: 1.3);
    p.line(p.poly([.46, .25, .21, .5, .46, .75], close: false), k: 1.3);
  },
  'forward': (p) {
    p.line(p.seg(.2, .5, .78, .5), k: 1.3);
    p.line(p.poly([.54, .25, .79, .5, .54, .75], close: false), k: 1.3);
  },
  'arrow_up': (p) {
    p.line(p.seg(.5, .8, .5, .22), k: 1.3);
    p.line(p.poly([.25, .46, .5, .21, .75, .46], close: false), k: 1.3);
  },
  'arrow_down': (p) {
    p.line(p.seg(.5, .2, .5, .78), k: 1.3);
    p.line(p.poly([.25, .54, .5, .79, .75, .54], close: false), k: 1.3);
  },
  'skip': (p) {
    p.both(p.poly([.16, .26, .5, .5, .16, .74]), _butter);
    p.both(p.poly([.48, .26, .82, .5, .48, .74]), _butter);
  },
  'exit': (p) {
    p.both(p.poly([.18, .12, .58, .12, .58, .88, .18, .88]), SLColors.woodLight);
    p.dot(.48, .52, .035);
    p.line(p.seg(.5, .5, .9, .5), k: 1.2);
    p.line(p.poly([.77, .37, .9, .5, .77, .63], close: false), k: 1.2);
  },
  'check': (p) => p.line(p.poly([.18, .52, .42, .76, .84, .26], close: false), k: 1.6),
  'lock': (p) {
    final shackle = Path()
      ..moveTo(.33 * p.s, .46 * p.s)
      ..lineTo(.33 * p.s, .33 * p.s)
      ..arcToPoint(p.o(.67, .33), radius: Radius.circular(.17 * p.s))
      ..lineTo(.67 * p.s, .46 * p.s);
    p.line(shackle, k: 1.1);
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.2 * p.s, .44 * p.s, .8 * p.s, .88 * p.s), Radius.circular(.08 * p.s))), _butter);
    p.dot(.5, .61, .055);
    p.line(p.seg(.5, .63, .5, .74));
  },
  'info': (p) {
    p.both(p.circle(.5, .5, .4), _mint);
    p.dot(.5, .31, .05);
    p.line(p.seg(.5, .45, .5, .72), k: 1.3);
  },
  'warning': (p) {
    p.both(p.poly([.5, .12, .9, .84, .1, .84]), _butter);
    p.line(p.seg(.5, .38, .5, .6), k: 1.3);
    p.dot(.5, .72, .05);
  },
  'error': (p) {
    p.both(p.circle(.5, .5, .4), _berry);
    p.line(p.seg(.36, .36, .64, .64), k: 1.3);
    p.line(p.seg(.64, .36, .36, .64), k: 1.3);
  },
  'sound_on': (p) {
    p.both(p.poly([.12, .4, .28, .4, .48, .22, .48, .78, .28, .6, .12, .6]), _butter);
    p.line(p.arc(.48, .5, .17, -.85, 1.7));
    p.line(p.arc(.48, .5, .31, -.85, 1.7));
  },
  'sound_off': (p) {
    p.both(p.poly([.12, .4, .28, .4, .48, .22, .48, .78, .28, .6, .12, .6]), _butter);
    p.line(p.seg(.62, .38, .86, .62), k: 1.2);
    p.line(p.seg(.86, .38, .62, .62), k: 1.2);
  },
  'language': (p) {
    p.both(p.circle(.5, .5, .4), _mint);
    p.line(p.oval(.5, .5, .17, .4), k: .8);
    p.line(p.seg(.1, .5, .9, .5), k: .8);
    p.line(p.seg(.16, .3, .84, .3), k: .7);
    p.line(p.seg(.16, .7, .84, .7), k: .7);
  },
  'phone': (p) {
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.3 * p.s, .1 * p.s, .7 * p.s, .9 * p.s), Radius.circular(.08 * p.s))), _mint);
    p.both(p.poly([.36, .2, .64, .2, .64, .72, .36, .72]), _paper, k: .7);
    p.dot(.5, .81, .035);
  },
  'trash': (p) {
    p.both(p.poly([.26, .32, .74, .32, .69, .86, .31, .86]), _mint);
    p.line(p.seg(.17, .28, .83, .28), k: 1.1);
    p.line(p.poly([.4, .27, .42, .16, .58, .16, .6, .27], close: false));
    p.line(p.seg(.42, .44, .43, .75), k: .8);
    p.line(p.seg(.58, .44, .57, .75), k: .8);
  },
  'reset': (p) {
    p.line(p.arc(.5, .52, .3, -1.2, 5.1), k: 1.2);
    p.line(p.poly([.5, .1, .62, .22, .48, .3], close: false), k: 1.2);
  },
  'play_video': (p) {
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.1 * p.s, .2 * p.s, .9 * p.s, .8 * p.s), Radius.circular(.12 * p.s))), _berry);
    p.both(p.poly([.42, .35, .67, .5, .42, .65]), _paper, k: .8);
  },
  'heart': (p) {
    final h = Path()
      ..moveTo(.5 * p.s, .84 * p.s)
      ..cubicTo(.18 * p.s, .62 * p.s, .05 * p.s, .42 * p.s, .17 * p.s, .26 * p.s)
      ..cubicTo(.29 * p.s, .11 * p.s, .46 * p.s, .17 * p.s, .5 * p.s, .32 * p.s)
      ..cubicTo(.54 * p.s, .17 * p.s, .71 * p.s, .11 * p.s, .83 * p.s, .26 * p.s)
      ..cubicTo(.95 * p.s, .42 * p.s, .82 * p.s, .62 * p.s, .5 * p.s, .84 * p.s)
      ..close();
    p.both(h, _berry);
  },
  'plus': (p) {
    p.line(p.seg(.5, .2, .5, .8), k: 1.5);
    p.line(p.seg(.2, .5, .8, .5), k: 1.5);
  },
  'sun': (p) {
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi;
      p.line(p.seg(.5 + math.cos(a) * .3, .5 + math.sin(a) * .3, .5 + math.cos(a) * .44, .5 + math.sin(a) * .44));
    }
    p.both(p.circle(.5, .5, .21), _butter);
  },
  'umbrella': (p) {
    final canopy = Path()
      ..moveTo(.08 * p.s, .52 * p.s)
      ..arcToPoint(p.o(.92, .52), radius: Radius.circular(.42 * p.s))
      ..arcToPoint(p.o(.64, .52), radius: Radius.circular(.17 * p.s), clockwise: false)
      ..arcToPoint(p.o(.36, .52), radius: Radius.circular(.17 * p.s), clockwise: false)
      ..arcToPoint(p.o(.08, .52), radius: Radius.circular(.17 * p.s), clockwise: false)
      ..close();
    final handle = Path()
      ..moveTo(.5 * p.s, .5 * p.s)
      ..lineTo(.5 * p.s, .8 * p.s)
      ..arcToPoint(p.o(.36, .8), radius: Radius.circular(.07 * p.s));
    p.line(handle, k: 1.1);
    p.both(canopy, _berry);
  },
  'raindrop': (p) {
    final d = Path()
      ..moveTo(.5 * p.s, .1 * p.s)
      ..quadraticBezierTo(.78 * p.s, .46 * p.s, .78 * p.s, .62 * p.s)
      ..arcToPoint(p.o(.22, .62), radius: Radius.circular(.28 * p.s))
      ..quadraticBezierTo(.22 * p.s, .46 * p.s, .5 * p.s, .1 * p.s)
      ..close();
    p.both(d, _mint);
    p.line(p.arc(.5, .62, .16, 1.9, 0.9), k: .7);
  },
  'paw': (p) {
    p.both(p.oval(.5, .66, .2, .16), SLColors.strawberryLight);
    for (final (x, y) in const [(.25, .42), (.41, .26), (.59, .26), (.75, .42)]) {
      p.both(p.oval(x, y, .075, .095), SLColors.strawberryLight);
    }
  },
  'moon': (p) => p.both(Path.combine(PathOperation.difference, p.circle(.48, .52, .36), p.circle(.66, .4, .3)), _butter),
  'sparkle': (p) {
    Path star(double cx, double cy, double r) {
      final q = r * .2;
      return Path()
        ..moveTo(cx * p.s, (cy - r) * p.s)
        ..quadraticBezierTo((cx + q) * p.s, (cy - q) * p.s, (cx + r) * p.s, cy * p.s)
        ..quadraticBezierTo((cx + q) * p.s, (cy + q) * p.s, cx * p.s, (cy + r) * p.s)
        ..quadraticBezierTo((cx - q) * p.s, (cy + q) * p.s, (cx - r) * p.s, cy * p.s)
        ..quadraticBezierTo((cx - q) * p.s, (cy - q) * p.s, cx * p.s, (cy - r) * p.s)
        ..close();
    }

    p.both(star(.44, .56, .38), _butter);
    p.both(star(.8, .2, .14), _butter, k: .7);
  },
  'clock': (p) {
    p.both(p.circle(.5, .5, .4), _paper);
    for (final (x, y) in const [(.5, .17), (.83, .5), (.5, .83), (.17, .5)]) {
      p.dot(x, y, .028);
    }
    p.line(p.seg(.5, .5, .5, .27), k: 1.1);
    p.line(p.seg(.5, .5, .67, .6), k: 1.1);
  },
  'pin': (p) {
    p.line(p.seg(.5, .55, .5, .9), k: 1.1);
    p.both(p.circle(.5, .34, .22), _berry);
  },
  'vip': (p) {
    p.both(p.poly([.14, .76, .14, .36, .33, .56, .5, .24, .67, .56, .86, .36, .86, .76]), _butter);
    for (final (x, y) in const [(.14, .3), (.5, .18), (.86, .3)]) {
      p.dot(x, y, .045);
    }
  },
  'customer': (p) {
    final body = Path()
      ..moveTo(.16 * p.s, .9 * p.s)
      ..quadraticBezierTo(.18 * p.s, .58 * p.s, .5 * p.s, .58 * p.s)
      ..quadraticBezierTo(.82 * p.s, .58 * p.s, .84 * p.s, .9 * p.s)
      ..close();
    p.both(body, _mint);
    p.both(p.circle(.5, .34, .18), const Color(0xFFF6D7C3));
  },
  'flame': (p) {
    final f = Path()
      ..moveTo(.5 * p.s, .08 * p.s)
      ..quadraticBezierTo(.86 * p.s, .44 * p.s, .76 * p.s, .7 * p.s)
      ..quadraticBezierTo(.66 * p.s, .92 * p.s, .5 * p.s, .92 * p.s)
      ..quadraticBezierTo(.3 * p.s, .92 * p.s, .24 * p.s, .7 * p.s)
      ..quadraticBezierTo(.2 * p.s, .5 * p.s, .37 * p.s, .34 * p.s)
      ..quadraticBezierTo(.4 * p.s, .5 * p.s, .46 * p.s, .52 * p.s)
      ..quadraticBezierTo(.42 * p.s, .3 * p.s, .5 * p.s, .08 * p.s)
      ..close();
    p.both(f, _berry);
    p.wash(p.oval(.52, .74, .12, .14), _butter);
  },
  'bulb': (p) {
    p.both(p.circle(.5, .4, .27), _butter);
    p.line(p.poly([.4, .64, .4, .78, .6, .78, .6, .64], close: false));
    p.line(p.seg(.43, .87, .57, .87));
  },
  'leaf_logo': (p) {
    final leaf = Path()
      ..moveTo(.18 * p.s, .82 * p.s)
      ..quadraticBezierTo(.12 * p.s, .24 * p.s, .84 * p.s, .16 * p.s)
      ..quadraticBezierTo(.86 * p.s, .76 * p.s, .18 * p.s, .82 * p.s)
      ..close();
    p.both(leaf, _mint);
    p.line(p.seg(.24, .76, .66, .34), k: .8);
  },
  'shop_bag': (p) {
    p.line(p.arc(.5, .34, .14, 3.14159, 3.14159), k: 1.1);
    p.both(p.poly([.18, .34, .82, .34, .78, .88, .22, .88]), _berry);
    p.dot(.4, .48, .03);
    p.dot(.6, .48, .03);
  },
  'basket': (p) {
    p.line(p.arc(.5, .46, .26, 3.14159, 3.14159), k: 1.1);
    p.both(p.poly([.1, .46, .9, .46, .78, .86, .22, .86]), SLColors.woodLight);
    p.line(p.seg(.18, .6, .82, .6), k: .7);
    p.line(p.seg(.21, .73, .79, .73), k: .7);
  },
  'quest_board': (p) {
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.12 * p.s, .14 * p.s, .88 * p.s, .86 * p.s), Radius.circular(.08 * p.s))), SLColors.woodLight);
    p.both(p.poly([.24, .26, .62, .26, .62, .5, .24, .5]), _paper, k: .7);
    p.both(p.poly([.4, .58, .76, .58, .76, .76, .4, .76]), SLColors.butterLight, k: .7);
    p.dot(.43, .26, .04);
  },
  'decor_chair': (p) {
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.24 * p.s, .1 * p.s, .76 * p.s, .52 * p.s), Radius.circular(.14 * p.s))), _mint);
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.16 * p.s, .5 * p.s, .84 * p.s, .66 * p.s), Radius.circular(.06 * p.s))), _mint);
    p.line(p.seg(.24, .66, .22, .9));
    p.line(p.seg(.76, .66, .78, .9));
  },
  'trophy': (p) {
    p.line(p.arc(.24, .34, .1, 1.57, 3.14159));
    p.line(p.arc(.76, .34, .1, -1.57, 3.14159));
    p.both(Path()
      ..moveTo(.26 * p.s, .16 * p.s)
      ..lineTo(.74 * p.s, .16 * p.s)
      ..quadraticBezierTo(.74 * p.s, .6 * p.s, .5 * p.s, .62 * p.s)
      ..quadraticBezierTo(.26 * p.s, .6 * p.s, .26 * p.s, .16 * p.s)
      ..close(), _butter);
    p.line(p.seg(.5, .62, .5, .76));
    p.both(p.poly([.32, .76, .68, .76, .68, .88, .32, .88]), SLColors.woodLight, k: .9);
  },
  'medal_max': (p) {
    p.both(p.poly([.3, .08, .44, .08, .54, .4, .4, .4]), _berry, k: .8);
    p.both(p.poly([.56, .08, .7, .08, .6, .4, .46, .4]), _mint, k: .8);
    p.both(p.circle(.5, .64, .24), _butter);
    p.line(p.poly([.4, .64, .48, .72, .62, .56], close: false), k: 1.1);
  },
  'no_ads': (p) {
    p.both(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(.12 * p.s, .22 * p.s, .88 * p.s, .78 * p.s), Radius.circular(.12 * p.s))), SLColors.paperShade);
    p.both(p.poly([.42, .37, .62, .5, .42, .63]), _paper, k: .7);
    p.line(p.seg(.14, .14, .86, .86), k: 1.4);
  },
  'cake_slice': (p) {
    p.both(p.poly([.12, .58, .84, .3, .84, .78, .12, .84]), SLColors.butterLight);
    p.both(Path()
      ..moveTo(.12 * p.s, .58 * p.s)
      ..lineTo(.84 * p.s, .3 * p.s)
      ..lineTo(.84 * p.s, .44 * p.s)
      ..quadraticBezierTo(.5 * p.s, .52 * p.s, .12 * p.s, .66 * p.s)
      ..close(), _berry, k: .8);
    p.both(p.circle(.7, .24, .08), SLColors.bad, k: .8);
  },
  'slot_wallpaper': (p) {
    // Tấm giấy dán tường sọc + hoa nhỏ, góc dưới bóc ra.
    p.both(p.poly([.16, .14, .84, .14, .84, .66, .62, .88, .16, .88]), SLColors.strawberryLight);
    for (final x in const [.34, .5, .66]) {
      p.line(p.seg(x, .16, x, .84), k: .55);
    }
    for (final (x, y) in const [(.25, .3), (.42, .52), (.58, .32), (.25, .72), (.75, .46)]) {
      p.dot(x, y, .035);
    }
    p.both(p.poly([.84, .66, .62, .88, .66, .7]), _paper, k: .8);
  },
  'slot_floor': (p) {
    // Mặt sàn gạch nhìn phối cảnh.
    p.both(p.poly([.26, .3, .74, .3, .9, .84, .1, .84]), SLColors.woodLight);
    p.line(p.seg(.42, .3, .37, .84), k: .6);
    p.line(p.seg(.58, .3, .63, .84), k: .6);
    p.line(p.seg(.21, .47, .79, .47), k: .6);
    p.line(p.seg(.16, .64, .84, .64), k: .6);
  },
  'slot_counter': (p) {
    // Quầy gỗ có chiếc bánh nhỏ trên mặt.
    p.both(p.rrect(.18, .62, .82, .9, .03), SLColors.wood);
    p.both(p.rrect(.08, .54, .92, .64, .03), SLColors.woodLight);
    p.both(p.rrect(.34, .32, .66, .54, .05), _berry, k: .9);
    p.wash(p.rrect(.34, .32, .66, .4, .05), _paper);
    p.both(p.circle(.5, .25, .06), SLColors.bad, k: .8);
    p.line(p.seg(.36, .76, .64, .76), k: .6);
  },
  'slot_window': (p) {
    // Khung cửa sổ gỗ, kính bạc hà, rèm hồng hai bên.
    p.both(p.rrect(.16, .12, .84, .86, .06), SLColors.woodLight);
    p.both(p.rrect(.24, .2, .76, .78, .03), SLColors.mintLight, k: .8);
    p.line(p.seg(.5, .2, .5, .78), k: .8);
    p.line(p.seg(.24, .49, .76, .49), k: .8);
    p.both(p.poly([.1, .1, .3, .1, .22, .5, .26, .9, .1, .9]), _berry, k: .8);
    p.both(p.poly([.9, .1, .7, .1, .78, .5, .74, .9, .9, .9]), _berry, k: .8);
  },
  'slot_plant': (p) {
    // Chậu cây ba lá.
    Path leaf(double x0, double y0, double x1, double y1, double bend) {
      final mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
      final nx = -(y1 - y0) * bend, ny = (x1 - x0) * bend;
      return Path()
        ..moveTo(x0 * p.s, y0 * p.s)
        ..quadraticBezierTo((mx + nx) * p.s, (my + ny) * p.s, x1 * p.s, y1 * p.s)
        ..quadraticBezierTo((mx - nx) * p.s, (my - ny) * p.s, x0 * p.s, y0 * p.s)
        ..close();
    }

    p.both(leaf(.5, .6, .2, .22, .35), _mint, k: .9);
    p.both(leaf(.5, .6, .8, .2, .35), _mint, k: .9);
    p.both(leaf(.5, .62, .52, .1, .3), _mint, k: .9);
    p.both(p.poly([.28, .58, .72, .58, .65, .9, .35, .9]), SLColors.caramel);
    p.line(p.seg(.3, .66, .7, .66), k: .7);
  },
  'confetti': (p) {
    // Pháo giấy: ống loe + giấy màu bay ra.
    p.both(p.poly([.1, .9, .28, .44, .56, .72]), _butter);
    p.line(p.seg(.2, .66, .38, .8), k: .6);
    p.both(p.poly([.5, .2, .6, .16, .62, .26, .52, .3]), _berry, k: .7);
    p.both(p.poly([.72, .44, .82, .4, .84, .5, .74, .54]), _mint, k: .7);
    p.both(p.circle(.78, .2, .05), _butter, k: .7);
    p.both(p.circle(.4, .14, .04), _mint, k: .7);
    p.line(p.poly([.56, .48, .64, .4, .7, .46, .78, .36], close: false), k: .8);
    p.dot(.9, .7, .035);
    p.dot(.62, .62, .03);
  },
  'tip_jar': (p) {
    // Hũ tiền tip: hũ thuỷ tinh, nắp gỗ có khe, đồng xu bên trong, nhãn giấy.
    p.both(p.rrect(.22, .3, .78, .9, .12), SLColors.mintLight);
    p.both(p.circle(.38, .78, .09), _butter, k: .7);
    p.both(p.circle(.6, .8, .09), _butter, k: .7);
    p.both(p.circle(.5, .68, .09), _butter, k: .7);
    p.both(p.rrect(.26, .16, .74, .3, .04), SLColors.woodLight);
    p.line(p.seg(.42, .23, .58, .23), k: 1.1);
    p.both(p.rrect(.32, .4, .68, .54, .03), _paper, k: .6);
    p.dot(.5, .47, .03);
  },
  'book': (p) {
    // Sổ công thức bìa hồng, gáy đậm, mép giấy bên phải, lá trên bìa.
    p.both(p.rrect(.18, .12, .8, .88, .05), _berry);
    p.both(p.poly([.8, .16, .86, .2, .86, .88, .8, .86]), _paper, k: .7);
    p.line(p.seg(.3, .14, .3, .86), k: .9);
    final leaf = Path()
      ..moveTo(.42 * p.s, .62 * p.s)
      ..quadraticBezierTo(.42 * p.s, .34 * p.s, .7 * p.s, .32 * p.s)
      ..quadraticBezierTo(.7 * p.s, .6 * p.s, .42 * p.s, .62 * p.s)
      ..close();
    p.both(leaf, _mint, k: .8);
    p.line(p.seg(.45, .59, .6, .44), k: .6);
  },
  'star': (p) {
    final pts = <double>[];
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? .42 : .19;
      pts..add(.5 + math.cos(a) * r)..add(.54 + math.sin(a) * r);
    }
    p.both(p.poly(pts), _butter);
  },
  'oven': (p) {
    // Lò nướng: thân hồng nhạt, hàng núm, cửa kính vàng bơ, tay cầm, chân.
    p.both(p.rrect(.12, .14, .88, .84, .08), SLColors.strawberryLight);
    for (final x in const [.26, .4, .54]) {
      p.dot(x, .25, .035);
    }
    p.both(p.rrect(.66, .21, .78, .29, .03), _butter, k: .6);
    p.both(p.rrect(.22, .4, .78, .76, .05), SLColors.butterLight, k: .9);
    p.line(p.seg(.32, .46, .68, .46), k: .8);
    p.wash(p.oval(.5, .64, .17, .06), _butter);
    p.line(p.seg(.2, .84, .2, .9));
    p.line(p.seg(.8, .84, .8, .9));
  },
  'gift': (p) {
    p.both(p.rrect(.16, .44, .84, .88, .04), _berry);
    p.both(p.rrect(.1, .3, .9, .46, .04), _berry);
    p.both(p.poly([.44, .3, .56, .3, .56, .88, .44, .88]), _butter, k: .8);
    final bowL = Path()
      ..moveTo(.5 * p.s, .3 * p.s)
      ..cubicTo(.34 * p.s, .06 * p.s, .16 * p.s, .2 * p.s, .5 * p.s, .3 * p.s)
      ..close();
    final bowR = Path()
      ..moveTo(.5 * p.s, .3 * p.s)
      ..cubicTo(.66 * p.s, .06 * p.s, .84 * p.s, .2 * p.s, .5 * p.s, .3 * p.s)
      ..close();
    p.both(bowL, _butter, k: .8);
    p.both(bowR, _butter, k: .8);
  },
  'tap': (p) {
    // Ngón tay chạm + gợn chạm.
    p.line(p.arc(.44, .2, .12, 3.5, 2.4), k: .7);
    p.line(p.arc(.44, .2, .2, 3.6, 2.2), k: .6);
    final hand = Path()
      ..moveTo(.36 * p.s, .62 * p.s)
      ..lineTo(.36 * p.s, .24 * p.s)
      ..quadraticBezierTo(.36 * p.s, .16 * p.s, .44 * p.s, .16 * p.s)
      ..quadraticBezierTo(.52 * p.s, .16 * p.s, .52 * p.s, .24 * p.s)
      ..lineTo(.52 * p.s, .46 * p.s)
      ..quadraticBezierTo(.76 * p.s, .44 * p.s, .78 * p.s, .58 * p.s)
      ..lineTo(.76 * p.s, .74 * p.s)
      ..quadraticBezierTo(.72 * p.s, .9 * p.s, .54 * p.s, .9 * p.s)
      ..quadraticBezierTo(.36 * p.s, .9 * p.s, .26 * p.s, .74 * p.s)
      ..lineTo(.2 * p.s, .62 * p.s)
      ..quadraticBezierTo(.24 * p.s, .54 * p.s, .36 * p.s, .62 * p.s)
      ..close();
    p.both(hand, const Color(0xFFF6D7C3));
    p.line(p.seg(.6, .5, .6, .6), k: .5);
    p.line(p.seg(.68, .5, .68, .6), k: .5);
  },
  'storefront': (p) {
    // Mặt tiền tiệm: mái hiên sọc, tường giấy, cửa gỗ, ô kính.
    p.both(p.rrect(.16, .36, .84, .88, .03), _paper);
    p.both(p.rrect(.42, .56, .62, .88, .04), SLColors.woodLight, k: .9);
    p.dot(.58, .73, .025);
    p.both(p.rrect(.22, .48, .36, .66, .02), SLColors.mintLight, k: .8);
    p.both(p.rrect(.68, .48, .78, .66, .02), SLColors.mintLight, k: .8);
    final awning = <double>[.1, .14, .9, .14, .9, .34];
    for (var i = 4; i >= 0; i--) {
      awning
        ..add(.1 + .16 * i + .08)
        ..add(.42)
        ..add(.1 + .16 * i)
        ..add(.34);
    }
    p.both(p.poly(awning), _berry);
    for (final x in const [.26, .42, .58, .74]) {
      p.line(p.seg(x, .15, x, .34), k: .6);
    }
  },
  'coin': (p) {
    p.both(p.circle(.5, .5, .38), _butter);
    p.line(p.circle(.5, .5, .27), k: .6);
    p.line(p.seg(.5, .36, .5, .64), k: 1.1);
    p.line(p.arc(.5, .5, .12, -2.6, 2.2), k: .8);
  },
  'ticket': (p) {
    // Vé đơn giấy, mép dưới răng cưa, vài dòng chữ, ghim đỏ.
    final pts = <double>[.2, .14, .8, .14, .8, .8];
    for (var i = 0; i < 4; i++) {
      pts
        ..add(.8 - .15 * i - .075)
        ..add(.88)
        ..add(.8 - .15 * (i + 1))
        ..add(.8);
    }
    p.both(p.poly(pts), _paper);
    p.line(p.seg(.3, .36, .7, .36), k: .7);
    p.line(p.seg(.3, .5, .64, .5), k: .7);
    p.line(p.seg(.3, .64, .56, .64), k: .7);
    p.both(p.circle(.5, .16, .07), _berry, k: .8);
  },
};
