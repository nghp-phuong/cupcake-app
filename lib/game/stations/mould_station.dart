import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/models/ids.dart';
import '../bakery_game.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/station_setup.dart';
import 'station.dart';

class _Mould {
  _Mould(this.type, this.home) : pos = home;

  final MouldType type;
  final Offset home;
  Offset pos;
  double scale = 1;
  double shake = 0;
  bool dragging = false;
}

/// Trạm 1 — chọn khuôn: kéo đúng khuôn từ cột phải lên khay nướng. Thả sai: lắc + nhắc, khuôn về chỗ.
class MouldStation extends Station {
  MouldStation(BakeryGame game) : super(game, StationId.mould) {
    final choices = mouldChoices(game.recipe.mould, seededRandom(game.order, 1));
    for (var i = 0; i < choices.length; i++) {
      _moulds.add(_Mould(choices[i], slotCenter(i)));
    }
  }

  static const Rect trayRect = Rect.fromLTWH(150, 300, 460, 270);
  static const double slotRadius = 58;
  static const double mouldSize = 104;

  static Offset slotCenter(int i) => Offset(800, 160 + i * 140.0);

  final List<_Mould> _moulds = [];
  _Mould? _drag;
  Offset _grab = Offset.zero;
  _Mould? _placed;
  double _placedT = 0;

  /// Các khuôn theo thứ tự ô (để test biết khuôn nào ở đâu).
  List<MouldType> get choices => [for (final m in _moulds) m.type];

  bool _overTray(Offset p) => trayRect.inflate(40).contains(p);

  @override
  void pointerDown(Offset p) {
    for (final m in _moulds.reversed) {
      if (m == _placed) continue;
      if ((p - m.pos).distance <= slotRadius + 8) {
        _drag = m..dragging = true;
        _grab = m.pos - p;
        return;
      }
    }
  }

  @override
  void pointerMove(Offset p) {
    final m = _drag;
    if (m == null) return;
    m.pos = p + _grab;
  }

  @override
  void pointerUp(Offset p) {
    final m = _drag;
    _drag = null;
    if (m == null) return;
    m.dragging = false;
    if (!_overTray(m.pos)) return; // tự trượt về chỗ
    if (m.type == game.recipe.mould) {
      _placed = m;
      _placedT = 0;
      game.effects.sparkle(trayRect.center, count: 18);
      finish(delay: 1.0);
    } else {
      game.record.wrongMouldDrops++;
      m.shake = 0.5;
      game.showToast(GameToast.wrongMould);
    }
  }

  @override
  void pointerCancel() {
    _drag?.dragging = false;
    _drag = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final m in _moulds) {
      if (m.shake > 0) {
        m.shake = math.max(0, m.shake - dt);
        continue; // lắc tại chỗ rồi mới về
      }
      if (m == _placed) {
        m.pos = approachOffset(m.pos, trayRect.center.translate(0, -6), dt, speed: 14);
      } else if (!m.dragging) {
        m.pos = approachOffset(m.pos, m.home, dt, speed: 10);
      }
      final target = m == _placed ? 1.75 : (m.dragging ? 1.18 : 1.0);
      m.scale = approach(m.scale, target, dt, speed: 12);
    }
    if (_placed != null) _placedT += dt;
  }

  @override
  void paintStation(Canvas canvas) {
    final hovering = _drag != null && _overTray(_drag!.pos);
    paintBakingTray(canvas, trayRect, glow: hovering ? 1 : 0);

    // Ô khuôn ở cột phải + nhãn tên.
    for (var i = 0; i < _moulds.length; i++) {
      final c = slotCenter(i);
      paintPlate(canvas, c, slotRadius);
      game.text.draw(canvas, game.labels.mould(_moulds[i].type), c.translate(0, slotRadius + 12), size: 14, maxWidth: 190, backing: CanvasText.labelBacking);
    }

    // Khuôn: khuôn đang kéo vẽ sau cùng (nổi lên trên).
    final order = [..._moulds]..sort((a, b) => (a.dragging ? 1 : 0).compareTo(b.dragging ? 1 : 0));
    for (final m in order) {
      var pos = m.pos;
      if (m.shake > 0) pos = pos.translate(math.sin(m.shake * 48) * 12 * (m.shake / 0.5), 0);
      // Nhún nhẹ mời kéo khi chưa chọn.
      if (_placed == null && !m.dragging && m.shake <= 0) {
        pos = pos.translate(0, math.sin(time * 2.4 + m.home.dy * 0.05) * 2.5);
      }
      final s = mouldSize * m.scale;
      if (m.dragging) paintShadow(canvas, pos.translate(0, s * 0.45), s * 0.9, s * 0.22, alpha: 0.22);
      if (m == _placed) {
        final pop = _placedT < 0.35 ? 1 + 0.08 * math.sin(_placedT / 0.35 * math.pi) : 1.0;
        _paintMould(canvas, Rect.fromCenter(center: pos, width: s * pop, height: s * pop), m.type);
      } else {
        _paintMould(canvas, Rect.fromCenter(center: pos, width: s, height: s), m.type);
      }
      if (m.shake > 0) paintWrongMark(canvas, pos.translate(s * 0.38, -s * 0.38));
    }

    // Mũi tên gợi ý nhẹ (nét bút vẽ tay) từ cột khuôn về khay khi chưa kéo gì.
    if (_placed == null && _drag == null) {
      final a = (math.sin(time * 3) + 1) / 2;
      paintHintArrow(canvas, Offset(660 + a * 14, trayRect.center.dy));
    }
  }

  /// Khuôn: ảnh vẽ tay (vật thể giữa ảnh vuông, lề ~3%) vào đúng ô vuông của hình code; chưa có ảnh → hình code.
  static void _paintMould(Canvas canvas, Rect rect, MouldType type) {
    final image = ArtSprites.mould(type).image;
    if (image != null) {
      drawArt(canvas, image, rect);
    } else {
      ItemArt.paintMould(canvas, rect, type);
    }
  }
}
