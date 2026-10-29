import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../bakery_game.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/bake_record.dart';
import '../logic/cake_geometry.dart';
import '../logic/station_setup.dart';
import 'station.dart';

class _Falling {
  _Falling(this.topping, this.pos);

  final ToppingId topping;
  Offset pos;
  double vy = 0;
  double age = 0;
}

/// Trạm 5 — topping: 4 khay ở cột phải; kéo topping lên bánh. Hợp lệ nếu điểm thả nằm trong elip mặt
/// bánh nới thêm `toppingSnapRadius`; thả ngoài → rơi mất. Chạm topping trên bánh để gỡ.
class ToppingStation extends Station {
  ToppingStation(BakeryGame game)
      : trays = toppingTrays(game.order, seededRandom(game.order, 2)),
        cakeBox = cakeRectFor(game.recipe.mould),
        super(game, StationId.topping) {
    top = CakeArt.topSurface(cakeBox, game.recipe.mould);
  }

  /// Khung bánh chuẩn (cạnh 460, đúng với cupcake). Khung thật của bánh đang làm là [cakeBox] / [cakeRectFor].
  static const Rect cakeRect = Rect.fromLTWH(190, 200, 460, 460);

  /// Đĩa bánh (elip) — bánh ngồi ở tâm đĩa.
  static const Rect plateRect = Rect.fromLTWH(220, 580, 400, 80);

  /// Khung bánh theo khuôn: đáy thân bánh ngồi trên đĩa.
  static Rect cakeRectFor(MouldType mould) => seatedCakeRect(mould, plateRect.center.dx, plateRect.center.dy, cakeRect.width);

  /// Khung bánh đang làm (theo khuôn).
  final Rect cakeBox;
  static const double trayRadius = 54;
  static const int maxPlaced = 16;

  static Offset trayCenter(int i) => Offset(820, 160 + i * 140.0);

  final List<ToppingId> trays;
  late final Rect top;

  ToppingId? _dragging;
  Offset _dragPos = Offset.zero;
  int? _pressed; // chỉ số topping trên bánh đang được nhấn (chạm để gỡ / kéo để dời)
  Offset _pressStart = Offset.zero;
  final List<_Falling> _falling = [];

  List<PlacedTopping> get placed => game.record.toppings;

  @override
  bool get usesDone => true;

  @override
  bool get canDone => placed.isNotEmpty;

  double get _size => toppingSize(top);

  bool _onCake(Offset p) => isOnCake(p, top, game.modifiers.toppingSnapRadius);

  @override
  void pointerDown(Offset p) {
    // Topping trên bánh (trên cùng trước).
    final size = _size;
    for (var i = placed.length - 1; i >= 0; i--) {
      final c = fromEllipseUnit(placed[i].unit, top).translate(0, -size * 0.3);
      if ((p - c).distance <= size * 0.6) {
        _pressed = i;
        _pressStart = p;
        return;
      }
    }
    for (var i = 0; i < trays.length; i++) {
      if ((p - trayCenter(i)).distance <= trayRadius + 10) {
        if (placed.length >= maxPlaced) return;
        _dragging = trays[i];
        _dragPos = p;
        return;
      }
    }
  }

  @override
  void pointerMove(Offset p) {
    final i = _pressed;
    if (i != null && (p - _pressStart).distance > 12) {
      // Nhấc topping đang có lên để dời chỗ.
      _dragging = placed.removeAt(i).topping;
      _pressed = null;
    }
    if (_dragging != null) _dragPos = p;
  }

  @override
  void pointerUp(Offset p) {
    final i = _pressed;
    _pressed = null;
    if (i != null) {
      // Chạm để gỡ.
      final t = placed.removeAt(i);
      game.effects.puff(fromEllipseUnit(t.unit, top), const Color(0xFFFFFFFF), count: 3, size: 14);
      return;
    }
    final t = _dragging;
    _dragging = null;
    if (t == null) return;
    if (_onCake(p)) {
      final at = clampIntoEllipse(p, top, inset: 0.9);
      placed.add(PlacedTopping(t, toEllipseUnit(at, top)));
      game.effects.bits(at, [ItemArt.toppingColor(t), AppColors.butter, const Color(0xFFFFFFFF)], count: t == ToppingId.sprinkles ? 14 : 7);
    } else {
      _falling.add(_Falling(t, p));
    }
  }

  @override
  void pointerCancel() {
    _pressed = null;
    final t = _dragging;
    _dragging = null;
    if (t != null) _falling.add(_Falling(t, _dragPos));
  }

  @override
  void done() {
    if (isDone) return;
    _dragging = null;
    game.effects.sparkle(top.center, count: 20);
    finish(delay: 0.9);
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final t in placed) {
      t.age += dt;
    }
    for (final f in _falling) {
      f.age += dt;
      f.vy += 1400 * dt;
      f.pos = f.pos.translate(0, f.vy * dt);
    }
    _falling.removeWhere((f) => f.age > 0.6);
  }

  @override
  void paintStation(Canvas canvas) {
    // Đĩa bánh (vẽ tay, có sẵn bóng mềm dưới đĩa).
    paintServingPlate(canvas, plateRect);

    final hover = _dragging != null && _onCake(_dragPos);
    if (hover) paintGlow(canvas, top.inflate(18), 0.8);
    paintCakeWithToppings(canvas, cakeBox, game.frostedCake, placed);

    for (var i = 0; i < trays.length; i++) {
      final c = trayCenter(i);
      paintPlate(canvas, c, trayRadius);
      // Một nhúm topping trên khay.
      final t = trays[i];
      const spots = [Offset(-16, 8), Offset(16, 10), Offset(0, -10)];
      for (final o in spots) {
        paintToppingAt(canvas, c + o + const Offset(0, 10), t, t == ToppingId.candle ? 26 : 34);
      }
      game.text.draw(canvas, game.labels.topping(t), c.translate(0, trayRadius + 13), size: 14, maxWidth: 190, backing: CanvasText.labelBacking);
    }

    for (final f in _falling) {
      final a = (1 - f.age / 0.6).clamp(0.0, 1.0);
      canvas.saveLayer(Rect.fromCircle(center: f.pos, radius: 60), Paint()..color = Color.fromRGBO(0, 0, 0, a));
      paintToppingAt(canvas, f.pos, f.topping, _size);
      canvas.restore();
    }

    final d = _dragging;
    if (d != null) {
      paintShadow(canvas, _dragPos.translate(0, 18), _size * 0.9, _size * 0.3, alpha: 0.2);
      final at = _dragPos.translate(0, -6 + math.sin(time * 12) * 1.5);
      paintToppingAt(canvas, at, d, _size * 1.15);
      _paintTongs(canvas, at.translate(0, -_size * 0.35));
    }
  }

  /// Đầu gắp và đầu vòng cầm trong ảnh `tool_tongs` 512×512.
  static const Offset _tongsTip = Offset(40, 70);
  static const Offset _tongsEnd = Offset(470, 440);

  /// Kẹp gắp đang giữ topping: đầu kẹp tại [tip], tay cầm chĩa xuống phải (ra phía khay). Chỉ vẽ khi có ảnh.
  void _paintTongs(Canvas canvas, Offset tip) {
    final image = ArtSprites.tool(ToolId.tongs).image;
    if (image == null) return;
    final axis = _tongsEnd - _tongsTip;
    drawArtRotated(canvas, image, tip, _tongsTip, 0.75 - axis.direction, 170 / axis.distance);
  }
}
