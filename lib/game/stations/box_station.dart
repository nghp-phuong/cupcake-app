import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/models/ids.dart';
import '../bakery_game.dart';
import '../components/game_paint.dart';
import '../logic/station_setup.dart';
import 'station.dart';

/// Trạm 6 — đóng hộp: kéo bánh vào một trong 3 hộp (nhỏ / bánh kem / quà). Thả vào hộp là xong
/// (+0.6 s hoạt cảnh đóng nắp) → game trả `BakeOutcome`.
class BoxStation extends Station {
  BoxStation(BakeryGame game) : super(game, StationId.box);

  static const Offset cakeHome = Offset(470, 250);
  static const double cakeSize = 250;
  static const double boxSize = 210;
  static const double closeSeconds = 0.6;

  static Offset boxCenter(int i) => Offset(190 + i * 280.0, 520);
  static Rect boxRect(int i) => Rect.fromCenter(center: boxCenter(i), width: boxSize, height: boxSize);

  /// Dời hình bánh so với [_cakePos] (ở cỡ gốc) để đáy thân bánh ngồi trên đĩa chờ, bất kể khuôn.
  late final double _seatDy =
      seatedCakeRect(game.recipe.mould, cakeHome.dx, cakeHome.dy + _plateDy, cakeSize).center.dy - cakeHome.dy;

  /// Tâm đĩa chờ dưới bánh, tính từ [cakeHome].
  static const double _plateDy = 96;

  // Ảnh `boxes/cake_open` (512×512, đo PIL): mặt trước (x 65..330 từ mép trên y 234), ô cửa sổ khoét ở mặt trước
  // (x 118..283, đáy y 420), mặt hông phải, và chỗ bánh ngồi trên sàn hộp (giữa ô cửa sổ, y 405).
  static const Rect _cakeBoxFront = Rect.fromLTRB(65, 234, 330, 500);
  static const Rect _cakeBoxWindow = Rect.fromLTRB(118, 234, 283, 420);
  static const Rect _cakeBoxSide = Rect.fromLTRB(330, 234, 452, 495);
  static const Offset _cakeBoxSeat = Offset(200, 405);

  /// Đang vẽ hộp bánh kem bằng ảnh (vị trí thả + phần che bánh theo ảnh).
  static bool get _cakeBoxArt => ArtSprites.box(BoxType.cake, open: true).image != null;

  /// Điểm ảnh [p] của hộp bánh kem (toạ độ ảnh 512) trên ô hộp [i].
  static Offset _onCakeBox(int i, Offset p) => boxRect(i).topLeft + p * (boxSize / 512);

  Offset _cakePos = cakeHome;
  double _cakeScale = 1;
  bool _dragging = false;
  Offset _grab = Offset.zero;
  int? _chosen;
  double _closeT = 0;
  bool _burst = false;
  final List<double> _hover = List<double>.filled(boxChoices.length, 0);

  int? _boxAt(Offset p) {
    for (var i = 0; i < boxChoices.length; i++) {
      if (boxRect(i).inflate(16).contains(p)) return i;
    }
    return null;
  }

  @override
  void pointerDown(Offset p) {
    if (_chosen != null) return;
    final r = Rect.fromCenter(center: _cakePos.translate(0, _seatDy), width: cakeSize * 0.8, height: cakeSize * 0.85);
    if (r.contains(p)) {
      _dragging = true;
      _grab = _cakePos - p;
    }
  }

  @override
  void pointerMove(Offset p) {
    if (_dragging) _cakePos = p + _grab;
  }

  @override
  void pointerUp(Offset p) {
    if (!_dragging) return;
    _dragging = false;
    final i = _boxAt(p) ?? _boxAt(_cakePos);
    if (i == null) return; // trượt về chỗ
    _chosen = i;
    _closeT = 0;
    game.record.boxChosen = boxChoices[i];
    finish(delay: closeSeconds);
  }

  @override
  void pointerCancel() => _dragging = false;

  @override
  void update(double dt) {
    super.update(dt);
    final hoverIdx = _dragging ? _boxAt(_cakePos) : null;
    for (var i = 0; i < _hover.length; i++) {
      _hover[i] = approach(_hover[i], i == hoverIdx ? 1 : 0, dt, speed: 12);
    }
    final c = _chosen;
    if (c != null) {
      _closeT += dt;
      // Hộp bánh kem (ảnh): đáy bánh ngồi trên sàn hộp, giữa ô cửa sổ. Mặt đỡ bánh = [_cakePos] + [_plateDy]×cỡ.
      final target = boxChoices[c] == BoxType.cake && _cakeBoxArt
          ? _onCakeBox(c, _cakeBoxSeat).translate(0, -_plateDy * _cakeScale)
          : boxCenter(c).translate(0, -10);
      _cakePos = approachOffset(_cakePos, target, dt, speed: 16);
      _cakeScale = approach(_cakeScale, 0.5, dt, speed: 14);
      if (!_burst && _closeT >= closeSeconds * 0.5) {
        _burst = true;
        game.effects.sparkle(boxCenter(c), count: 22);
        game.effects.hearts(boxCenter(c).translate(0, -80));
      }
    } else if (!_dragging) {
      _cakePos = approachOffset(_cakePos, cakeHome, dt, speed: 10);
      _cakeScale = approach(_cakeScale, 1, dt, speed: 10);
    } else {
      _cakeScale = approach(_cakeScale, 0.85, dt, speed: 10);
    }
  }

  @override
  void paintStation(Canvas canvas) {
    final closed = _chosen != null && _closeT >= closeSeconds * 0.5;
    // Đĩa chờ dưới bánh: đĩa vẽ tay có bóng mềm + bóng tiếp xúc → ngồi trên mặt bàn.
    paintServingPlate(canvas, Rect.fromCenter(center: cakeHome.translate(0, _plateDy), width: 280, height: 56));

    for (var i = 0; i < boxChoices.length; i++) {
      final c = boxCenter(i);
      final isChosen = _chosen == i;
      final h = _hover[i];
      var s = boxSize * (1 + 0.07 * h);
      if (isChosen && closed) {
        // Nắp đóng "bụp" một cái.
        final t = (_closeT - closeSeconds * 0.5) / (closeSeconds * 0.5);
        s *= 1 + 0.08 * math.sin(t.clamp(0.0, 1.0) * math.pi);
      }
      paintShadow(canvas, c.translate(0, s * 0.42), s * 0.95, 30, alpha: 0.18);
      paintGlow(canvas, Rect.fromCenter(center: c.translate(0, 20), width: s * 1.05, height: s * 0.8), h);
      final rect = Rect.fromCenter(center: c, width: s, height: s);
      _paintBox(canvas, rect, boxChoices[i], open: !(isChosen && closed));
      game.text.draw(canvas, game.labels.box(boxChoices[i]), c.translate(0, boxSize / 2 + 16), size: 16, maxWidth: 200, backing: CanvasText.labelBacking);
    }

    // Bánh (ẩn khi nắp đã đóng).
    if (!closed) {
      final s = cakeSize * _cakeScale;
      final bob = _chosen == null && !_dragging ? math.sin(time * 2.2) * 3 : 0.0;
      final rect = Rect.fromCenter(center: _cakePos.translate(0, bob + _seatDy * _cakeScale), width: s, height: s);
      if (_dragging) paintShadow(canvas, _cakePos.translate(0, s * 0.45), s * 0.7, s * 0.14, alpha: 0.2);
      final c = _chosen;
      final inCakeBox = c != null && boxChoices[c] == BoxType.cake && _cakeBoxArt;
      if (inCakeBox) {
        // Bánh vào hộp bánh kem: mặt trước (trừ ô cửa sổ) và mặt hông che phần bánh nằm trong hộp.
        Rect on(Rect r) => Rect.fromPoints(_onCakeBox(c, r.topLeft), _onCakeBox(c, r.bottomRight));
        canvas.save();
        canvas.clipPath(Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(const Rect.fromLTWH(0, 0, 1280, 720))
          ..addRect(on(_cakeBoxFront))
          ..addRect(on(_cakeBoxWindow))
          ..addRect(on(_cakeBoxSide)));
      }
      paintCakeWithToppings(canvas, rect, game.frostedCake, game.record.toppings);
      if (inCakeBox) canvas.restore();
    }
  }

  /// Hộp: ảnh vẽ tay (mở / đã đóng) vào đúng ô vuông của hình code; chưa có ảnh → hình code.
  static void _paintBox(Canvas canvas, Rect rect, BoxType box, {required bool open}) {
    final image = ArtSprites.box(box, open: open).image;
    if (image != null) {
      drawArt(canvas, image, rect);
    } else {
      ItemArt.paintBox(canvas, rect, box, open: open);
    }
  }
}
