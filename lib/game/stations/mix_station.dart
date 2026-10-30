import 'dart:math' as math;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../bakery_game.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import '../logic/cake_geometry.dart';
import '../logic/mix_meter.dart';
import 'station.dart';

/// Trạm 2 — trộn bột: kéo vòng quanh tâm mặt bột [center]. Tô nhìn nghiêng 3/4 nên vùng chạm là vành elip
/// (khoảng cách dọc chia [ringYScale]: 60–320 px ngang, 30–160 px dọc); xoay tròn hay xoay theo elip đều
/// tính 1 vòng mỗi vòng. Đồng hồ ngang 0..2×mục tiêu, vùng xanh `[1−band, 1+band]×mục tiêu`. Xong khi bấm
/// nút (≥ 1 vòng) hoặc tự dừng ở 2×mục tiêu.
///
/// Hình: ảnh tô gốm `ArtSprites.bowl` làm thân tô; mặt bột là elip trong miệng tô, tô bằng mặt bột cắt từ
/// ảnh `ArtSprites.batter` của món (bỏ chiếc thìa có sẵn trong ảnh). Vòng xoáy, nguyên liệu chưa tan, bọt
/// khí vẽ bằng code trên elip đó (toạ độ tròn → elip) và quay theo tay; bột chuyển dần từ màu bột mì sang
/// màu bột của món. Thiếu ảnh → tô vẽ code (nhìn nghiêng bằng cách ép dọc hình tô nhìn từ trên).
class MixStation extends Station {
  MixStation(BakeryGame game)
      : meter = MixMeter(center: center, innerRadius: 60, outerRadius: 320, yScale: ringYScale),
        super(game, StationId.mix);

  /// Tâm mặt bột (tâm vòng trộn).
  static const Offset center = Offset(470, 350);

  /// Hệ số ép dọc của vùng chạm (tô nhìn nghiêng).
  static const double ringYScale = 0.5;
  static const Rect meterRect = Rect.fromLTWH(170, 104, 600, 28);

  // ------------------------------------------------------------------ Số đo ảnh (px ảnh 512×512)

  /// Ảnh `bowl`: tâm mặt bột (mức bột ~2/3 tô), bán trục mặt bột, miệng tô (mép trong của vành).
  static const Offset _bowlSurfaceCenter = Offset(255, 186);
  static const double _bowlSurfaceA = 196;
  static const double _bowlSurfaceB = 60;
  static const Rect _bowlOpening = Rect.fromLTRB(40, 82, 470, 242);
  static const double _bowlFootY = 447;

  /// Cỡ vẽ ảnh tô (đơn vị khung trên một px ảnh).
  static const double _bowlScale = 1.1;

  /// Ảnh tô đặt sao cho tâm mặt bột trùng [center].
  static final Rect bowlRect = Rect.fromLTWH(
    center.dx - _bowlSurfaceCenter.dx * _bowlScale,
    center.dy - _bowlSurfaceCenter.dy * _bowlScale,
    512 * _bowlScale,
    512 * _bowlScale,
  );

  /// Mặt bột (elip) trên khung khi có ảnh tô.
  static final Rect artSurface =
      Rect.fromCenter(center: center, width: 2 * _bowlSurfaceA * _bowlScale, height: 2 * _bowlSurfaceB * _bowlScale);
  static final Rect _artOpening = Rect.fromLTRB(
    bowlRect.left + _bowlOpening.left * _bowlScale,
    bowlRect.top + _bowlOpening.top * _bowlScale,
    bowlRect.left + _bowlOpening.right * _bowlScale,
    bowlRect.top + _bowlOpening.bottom * _bowlScale,
  );

  /// Mặt bột phải nằm trong miệng tô (phần sát vành trước bị vành che).
  static final Path _artClip = Path.combine(
    PathOperation.intersect,
    Path()..addOval(artSurface.inflate(4)),
    Path()..addOval(_artOpening.deflate(2)),
  );

  /// Ảnh `batter/<bột>`: elip mặt bột; chiếc thìa gỗ cắm ở nửa phải được che bằng ảnh lật gương quanh
  /// [_spoonMirrorX] trong vùng [_spoonPatch] (mờ mép 14 px). Mọi ảnh bột cùng khung hình.
  static const Rect _batterSurface = Rect.fromLTRB(55, 168, 407, 294);
  static const double _spoonMirrorX = 262;
  static const Rect _spoonPatch = Rect.fromLTRB(262, 140, 430, 270);

  // ------------------------------------------------------------------ Hình code dự phòng

  /// Tô vẽ code: vành [_rim], lòng [_inner], ép dọc [_codeYScale] quanh [center].
  static const double _rim = 238;
  static const double _inner = 214;
  static const double _codeYScale = 0.62;
  static final Rect _codeSurface =
      Rect.fromCenter(center: center, width: 2 * (_inner - 18), height: 2 * (_inner - 18) * _codeYScale);

  /// Bán kính tham chiếu của hình mặt bột (vòng xoáy, nguyên liệu): vẽ trong vòng tròn này rồi co về elip.
  static const double _ref = 196;

  final MixMeter meter;
  Offset? _whisk;
  double _puffClock = 0;
  double _wobble = 0;

  /// Màu bột và elip mặt bột hiện tại (tính khi vẽ mặt bột, dùng lại cho chỗ phới nhúng).
  Color _color = const Color(0xFFFFF6E4);
  Rect _surfaceRect = Rect.zero;

  /// Mặt bột cắt từ ảnh bột (đã bỏ thìa), dựng một lần theo ảnh nguồn.
  Image? _texture;
  Image? _textureSource;

  int get target => game.recipe.mixTurns;
  double get maxTurns => target * 2.0;
  double get turns => math.min(meter.turns, maxTurns);

  bool get _hasBowlArt => ArtSprites.bowl.image != null;

  /// Mặt bột trên khung (theo hình đang vẽ).
  Rect get surface => _hasBowlArt ? artSurface : _codeSurface;

  /// Đầu phới: bám ngón tay nhưng luôn nằm trong mặt bột.
  Offset _tipFor(Offset p) => clampIntoEllipse(p, surface, inset: 0.86);

  @override
  bool get usesDone => true;

  @override
  bool get canDone => meter.turns >= 1;

  @override
  void pointerDown(Offset p) {
    meter.start(p);
    _whisk = p;
  }

  @override
  void pointerMove(Offset p) {
    _whisk = p;
    final add = meter.move(p);
    if (add > 0) {
      _wobble = math.min(1, _wobble + add * 6);
      _puffClock += add;
      if (_puffClock > 0.12 && turns < target * 0.7) {
        _puffClock = 0;
        game.effects.puff(_tipFor(p), const Color(0xFFFFFFFF), count: 2, size: 12);
      }
    }
    if (meter.turns >= maxTurns) _complete();
  }

  @override
  void pointerUp(Offset p) {
    meter.end();
    _whisk = null;
  }

  @override
  void pointerCancel() => pointerUp(Offset.zero);

  @override
  void done() => _complete();

  void _complete() {
    if (isDone) return;
    meter.end();
    _whisk = null;
    game.record.mixTurns = turns;
    final d = (turns / target - 1).abs();
    if (d <= game.modifiers.mixPerfectBand) {
      game.effects.sparkle(center, count: 20);
    } else {
      game.effects.puff(center, const Color(0xFFFFFFFF), count: 4, size: 26);
    }
    finish(delay: 0.9);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _wobble = approach(_wobble, 0, dt, speed: 3);
  }

  @override
  void onRemove() {
    _texture?.dispose();
    _texture = null;
    _textureSource = null;
    super.onRemove();
  }

  @override
  void paintStation(Canvas canvas) {
    _paintMeter(canvas);
    final w = _whisk;
    final tip = w == null ? null : _tipFor(w);
    final bowl = ArtSprites.bowl.image;
    if (bowl != null) {
      paintShadow(canvas, Offset(center.dx, bowlRect.top + _bowlFootY * _bowlScale), 330 * _bowlScale, 46, alpha: 0.24);
      drawArt(canvas, bowl, bowlRect);
      canvas.save();
      canvas.clipPath(_artClip);
      _paintBatter(canvas, artSurface, tip);
      canvas.restore();
    } else {
      // Tô vẽ code nhìn từ trên, ép dọc thành nhìn nghiêng.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, _codeYScale);
      canvas.translate(-center.dx, -center.dy);
      paintBowl(canvas, center, _rim, _inner);
      canvas.restore();
      _paintBatter(canvas, _codeSurface, tip);
    }
    // Vòng chỉ dẫn (chấm + mũi tên quay) khi mới bắt đầu.
    final guideAlpha = (1 - meter.turns / 0.6).clamp(0.0, 1.0);
    if (guideAlpha > 0) _paintGuide(canvas, guideAlpha);
    if (tip != null) {
      // Cán nghiêng về phía tay cầm (phải), nghiêng thêm theo vị trí ngang trong tô.
      final dx = ((tip.dx - center.dx) / (surface.width / 2)).clamp(-1.0, 1.0);
      _paintWhisk(canvas, tip, -math.pi / 2 + 0.55 + 0.3 * dx, 0.9);
      _paintDip(canvas, tip);
    } else {
      // Chờ: phới tựa trong tô, cán gác lên vành phải.
      final s = surface;
      _paintWhisk(canvas, Offset(s.center.dx + s.width * 0.3, s.center.dy - s.height * 0.05), -math.pi / 2 + 0.95, 0.9);
    }
  }

  /// Đầu phới nhúng trong bột: vẽ lại một mẩu mặt bột (cùng nền) phủ lên mút lồng phới + vệt sáng mép run tay.
  void _paintDip(Canvas canvas, Offset tip) {
    final k = surface.height / surface.width;
    final dip = Rect.fromCenter(center: tip.translate(2, 4), width: 46, height: 46 * k * 1.3);
    canvas.save();
    canvas.clipRRect(RRect.fromRectXY(dip, dip.width / 2, dip.height / 2));
    _paintBatterBase(canvas, _surfaceRect, dip);
    canvas.restore();
    canvas.save();
    canvas.translate(dip.center.dx, dip.center.dy);
    canvas.drawPath(_MixShapes.around(k).dipShine, softStroke(lightOf(_color, 0.5).withValues(alpha: 0.7), 2));
    canvas.restore();
  }

  /// Đầu lồng phới và đầu cán trong ảnh `tool_whisk` 512×512.
  static const Offset _whiskTip = Offset(50, 476);
  static const Offset _whiskEnd = Offset(472, 28);

  /// Phới: ảnh vẽ tay, đầu lồng tại [tip], cán hướng [angle] (như `paintWhisk`); chưa có ảnh → hình code.
  void _paintWhisk(Canvas canvas, Offset tip, double angle, double scale) {
    final image = ArtSprites.tool(ToolId.whisk).image;
    if (image == null) {
      paintWhisk(canvas, tip, angle, scale: scale);
      return;
    }
    final axis = _whiskEnd - _whiskTip;
    const length = 230.0;
    drawArtRotated(canvas, image, tip, _whiskTip, angle - axis.direction, length * scale / axis.distance);
  }

  /// Thanh đo vẽ tay: ống giấy (cache) + phần đã trộn (động) + vùng xanh màu nước và vạch từng vòng (cache).
  void _paintMeter(Canvas canvas) {
    final band = game.modifiers.mixPerfectBand;
    final max = maxTurns;
    final goal = target;
    double xOf(double turnsValue) => meterRect.left + meterRect.width * (turnsValue / maxTurns).clamp(0.0, 1.0);
    paintSketchMeter(
      canvas,
      meterRect,
      ('mix', goal, band),
      level: turns / max,
      fillColor: const Color(0xFFFFE2B0),
      front: (c, r) {
        double x(double v) => r.left + r.width * (v / max).clamp(0.0, 1.0);
        paintWashBand(c, Rect.fromLTRB(x((1 - band) * goal), r.top - 4, x((1 + band) * goal), r.bottom + 4), AppColors.good, 0x313, alpha: 0.85);
        // Vạch từng vòng: nét bút chì ngắn run tay, hơi nghiêng khác nhau.
        for (var k = 1; k < max; k++) {
          final tx = x(k.toDouble());
          final tick = Path()
            ..moveTo(tx + (k.isEven ? 0.6 : -0.4), r.bottom - 10)
            ..lineTo(tx, r.bottom - 1.5);
          c.drawPath(wobblePath(tick, seed: 0x7C0 + k, amplitude: 0.6, step: 2), softStroke(const Color(0x735A3E36), 2));
        }
      },
    );
    paintSketchMarker(canvas, meterRect, xOf(turns));
  }

  // Paint tái sử dụng cho bột (màu đổi theo tiến độ → chỉ gán lại màu, không tạo mới mỗi khung). Hình (viền mặt
  // bột, vệt xoáy, nguyên liệu, bọt, gợn) là path run tay dựng sẵn một lần trong [_MixShapes].
  final Paint _batterEdge = _roundStroke(3);
  final Paint _swirl = _roundStroke(7);
  final Paint _swirlDark = _roundStroke(5);
  final Paint _ripple = _roundStroke(3);
  final Paint _spot = Paint()..isAntiAlias = true;
  final Paint _line = _roundStroke(1.4);
  final Paint _texturePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  static Paint _roundStroke(double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Mặt bột cắt từ ảnh bột của món (null khi chưa nạp / thiếu ảnh). Dựng lại khi ảnh nguồn đổi.
  Image? _batterTexture() {
    final src = ArtSprites.batter(game.recipe.batter).image;
    if (src == null) return null;
    if (!identical(src, _textureSource)) {
      _texture?.dispose();
      _texture = _buildTexture(src);
      _textureSource = src;
    }
    return _texture;
  }

  /// Cắt elip mặt bột khỏi ảnh bột; vùng có thìa thay bằng ảnh lật gương (mờ mép) để mặt bột liền.
  static Image _buildTexture(Image src) {
    const s = _batterSurface;
    final rec = PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..filterQuality = FilterQuality.medium;
    c.translate(-s.left, -s.top);
    c.clipRRect(RRect.fromRectXY(s, s.width / 2, s.height / 2));
    c.drawImage(src, Offset.zero, p);
    c.saveLayer(_spoonPatch, Paint());
    c.save();
    c.translate(2 * _spoonMirrorX, 0);
    c.scale(-1, 1);
    c.drawImage(src, Offset.zero, p);
    c.restore();
    const clear = Color(0x00000000);
    const solid = Color(0xFF000000);
    c.drawRect(
      _spoonPatch,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = Gradient.linear(const Offset(_spoonMirrorX, 0), const Offset(_spoonMirrorX + 14, 0), const [clear, solid]),
    );
    c.drawRect(
      _spoonPatch,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = Gradient.linear(Offset(0, _spoonPatch.bottom - 16), Offset(0, _spoonPatch.bottom - 2), const [solid, clear]),
    );
    c.restore();
    final picture = rec.endRecording();
    final image = picture.toImageSync(s.width.ceil(), s.height.ceil());
    picture.dispose();
    return image;
  }

  /// Mặt bột trong elip [oval]: nền (ảnh mặt bột hoặc màu bột) → phủ màu bột mì nhạt dần theo tiến độ →
  /// vòng xoáy, nguyên liệu chưa tan, bọt khí (vẽ trong vòng tròn bán kính [_ref] rồi co về elip) → gợn
  /// quanh đầu phới [tip].
  void _paintBatter(Canvas canvas, Rect oval, Offset? tip) {
    final progress = (turns / target).clamp(0.0, 2.0);
    final smooth = math.min(1.0, progress);
    final base = ItemArt.batterColor(game.recipe.batter);
    // Bột trộn đều dần từ màu bột mì; trộn quá tay thì sẫm và chặt lại.
    final raw = 0.65 * (1 - smooth);
    var color = Color.lerp(const Color(0xFFFFF6E4), base, 1 - raw)!;
    final over = (progress - 1 - game.modifiers.mixPerfectBand).clamp(0.0, 1.0);
    if (over > 0) color = Color.lerp(color, const Color(0xFF5A3E36), over * 0.25)!;
    _color = color;
    final wobble = 1 + 0.015 * _wobble * math.sin(time * 30);
    final r = Rect.fromCenter(center: oval.center, width: oval.width * wobble, height: oval.height * wobble);
    _surfaceRect = r;
    final shapes = _MixShapes.around(oval.height / oval.width);

    // Mặt bột (elip [oval] co giãn [wobble] quanh tâm): cắt theo viền run tay, nét viền đậm màu bột.
    final edge = _MixShapes.edge(oval);
    canvas.save();
    canvas.translate(oval.center.dx, oval.center.dy);
    canvas.scale(wobble);
    canvas.translate(-oval.center.dx, -oval.center.dy);
    canvas.clipPath(edge);
    final texture = _paintBatterBase(canvas, oval, oval.inflate(4));
    _batterEdge.color = Color.lerp(color, const Color(0xFF5A3E36), 0.3)!;
    canvas.drawPath(edge, _batterEdge);

    // Toạ độ tròn (bán kính _ref quanh gốc) → elip.
    canvas.save();
    canvas.translate(oval.center.dx, oval.center.dy);
    canvas.scale(oval.width / 2 / _ref, oval.height / 2 / _ref);
    final rot = meter.signedAngle;
    // Vệt xoáy quay theo tay (ảnh mặt bột đã có xoáy → vệt code nhạt hơn): 3 nét run tay dựng sẵn, xoay [rot].
    final k0 = texture != null ? 0.6 : 1.0;
    _swirl.color = Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!.withValues(alpha: (0.35 + 0.5 * smooth) * k0);
    _swirlDark.color = Color.lerp(color, const Color(0xFF5A3E36), 0.18)!.withValues(alpha: (0.2 + 0.4 * smooth) * k0);
    canvas.save();
    canvas.rotate(rot);
    for (var k = 0; k < 3; k++) {
      canvas.drawPath(_MixShapes.swirls[k], k.isEven ? _swirl : _swirlDark);
    }
    canvas.restore();
    // Nguyên liệu chưa tan: đống bột mì / bột hương vị, trứng, bơ, đường — mờ dần và trôi theo vòng xoáy.
    // Là vật nổi trên mặt bột nên chỉ ép dọc một phần (nhìn ra khối), không dẹt hẳn theo elip.
    final left = (1 - progress * 1.25).clamp(0.0, 1.0);
    if (left > 0) {
      final lift = math.min(2.2, 0.6 / (oval.height / oval.width));
      final flavor = _flavorPowder(game.recipe.batter);
      for (final (a0, rr, kind) in _undissolved) {
        final a = a0 + rot * 0.9;
        canvas.save();
        canvas.translate(math.cos(a) * rr, math.sin(a) * rr);
        canvas.scale(1, lift);
        _paintIngredient(canvas, kind == 4 && flavor == null ? 0 : kind, left, flavor);
        canvas.restore();
      }
    }
    // Bọt khí nhỏ run tay: bột mịn thì bóng hơn.
    final bubbleA = 0.18 + 0.25 * smooth;
    for (var i = 0; i < 7; i++) {
      final a = rot * 0.6 + i * 0.9;
      final rr = 40.0 + (i * 23) % 130;
      final b = _MixShapes.bubbles[i % 3];
      canvas.save();
      canvas.translate(math.cos(a) * rr, math.sin(a) * rr);
      _spot.color = Color.fromRGBO(255, 255, 255, bubbleA);
      canvas.drawPath(b, _spot);
      _line.color = Color.fromRGBO(255, 255, 255, math.min(1, bubbleA * 2));
      canvas.drawPath(b, _line);
      canvas.restore();
    }
    canvas.restore();

    // Gợn bột run tay quanh đầu phới (đổi về toạ độ trước khi co giãn).
    if (tip != null) {
      final t = oval.center + (tip - oval.center) / wobble;
      canvas.save();
      canvas.translate(t.dx, t.dy);
      _ripple.color = Color.lerp(color, const Color(0xFF5A3E36), 0.25)!.withValues(alpha: 0.45);
      canvas.drawPath(shapes.rippleInner, _ripple);
      canvas.translate(0, -2);
      _ripple.color = Color.lerp(color, const Color(0xFFFFFFFF), 0.5)!.withValues(alpha: 0.6);
      canvas.drawPath(shapes.rippleOuter, _ripple);
      canvas.restore();
    }
    canvas.restore();
  }

  /// Nền mặt bột trong [area] (mặt bột đầy đủ là [r]): ảnh mặt bột (hoặc màu bột) + lớp màu bột mì nhạt dần
  /// theo tiến độ + lớp sẫm khi trộn quá tay. Trả về ảnh mặt bột đã dùng (null = tô màu phẳng).
  Image? _paintBatterBase(Canvas canvas, Rect r, Rect area) {
    final texture = _batterTexture();
    if (texture == null) {
      canvas.drawRect(area, fill(_color));
      return null;
    }
    final progress = (turns / target).clamp(0.0, 2.0);
    final raw = 0.65 * (1 - math.min(1.0, progress));
    final over = (progress - 1 - game.modifiers.mixPerfectBand).clamp(0.0, 1.0);
    canvas.drawImageRect(texture, Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()), r, _texturePaint);
    if (raw > 0) canvas.drawRect(area, fill(const Color(0xFFFFF6E4).withValues(alpha: raw)));
    if (over > 0) canvas.drawRect(area, fill(const Color(0xFF5A3E36).withValues(alpha: over * 0.25)));
    return texture;
  }

  /// (góc ban đầu, bán kính, loại) của nguyên liệu chưa tan (toạ độ tròn bán kính [_ref]).
  /// Loại: 0 bột mì, 1 trứng, 2 bơ, 3 đường, 4 bột hương vị (cacao / matcha / màu đỏ; món không có → bột mì).
  static const List<(double, double, int)> _undissolved = [
    (0.3, 112, 0), (2.1, 96, 1), (3.9, 124, 2), (5.0, 62, 3), (1.25, 150, 3), (4.55, 150, 4), (2.95, 40, 1),
  ];

  /// Màu bột hương vị rắc trên mặt (null = món không có).
  static Color? _flavorPowder(BatterType b) => switch (b) {
        BatterType.chocolate => const Color(0xFF6E4330),
        BatterType.matcha => const Color(0xFF7FAE5A),
        BatterType.redVelvet => const Color(0xFFB8303F),
        BatterType.laminated => const Color(0xFFF3D98E), // vàng bơ nhạt (bột ngàn lớp)
        BatterType.choux => const Color(0xFFF1DDA6), // vàng kem (bột su)
        BatterType.mooncake => const Color(0xFFB98A4E), // nâu vàng (vỏ bánh Trung thu)
        _ => null,
      };

  /// Một nguyên liệu chưa tan tại gốc toạ độ (đơn vị bán kính tham chiếu), độ đậm [alpha]: hình run tay dựng sẵn
  /// ([_MixShapes]) tô màu nước + vệt sáng mềm + nét mực mảnh nhạt; mỗi khung chỉ gán màu rồi vẽ path.
  void _paintIngredient(Canvas canvas, int kind, double alpha, Color? flavor) {
    void wash(Path p, Color c, [double a = 1]) {
      _spot.color = c.withValues(alpha: c.a * alpha * a);
      canvas.drawPath(p, _spot);
    }

    void ink(Path p, Color c, [double a = 1]) {
      _line.color = c.withValues(alpha: alpha * a);
      canvas.drawPath(p, _line);
    }

    switch (kind) {
      case 0 || 4:
        // Đống bột: đáy bóng mờ + vòm + bóng sườn phải + chấm sáng đỉnh.
        final c = kind == 4 ? flavor! : const Color(0xFFFFFDF8);
        wash(_MixShapes.heapShadow, shadeOf(c, 0.3), 0.5);
        wash(_MixShapes.heap, c);
        wash(_MixShapes.heapShade, shadeOf(c, 0.18), 0.65);
        wash(_MixShapes.heapLight, lightOf(c, 0.6), 0.85);
        ink(_MixShapes.heap, Color.lerp(c, const Color(0xFF6B4532), 0.55)!, 0.45);
      case 1:
        // Trứng: lòng trắng loang (mép run nhiều) + lòng đỏ bóng.
        wash(_MixShapes.eggWhite, const Color(0xFFFFFDF5), 0.9);
        ink(_MixShapes.eggWhite, const Color(0xFFD9C7A8), 0.5);
        wash(_MixShapes.yolk, const Color(0xFFF7B733));
        wash(_MixShapes.yolkShade, const Color(0xFFE59A1E), 0.75);
        wash(_MixShapes.yolkLight, const Color(0xFFFFFFFF), 0.85);
        ink(_MixShapes.yolk, const Color(0xFFB8741A), 0.55);
      case 2:
        // Miếng bơ: mặt trước đậm + mặt trên sáng + vệt sáng.
        wash(_MixShapes.butterFront, const Color(0xFFF2CC5E));
        wash(_MixShapes.butterTop, const Color(0xFFFFE699));
        wash(_MixShapes.butterLight, const Color(0xFFFFFAE1), 0.85);
        ink(_MixShapes.butterFront, const Color(0xFFB48A2E), 0.5);
        ink(_MixShapes.butterTop, const Color(0xFFB48A2E), 0.45);
      default:
        // Đường: hạt lấp lánh.
        wash(_MixShapes.sugar, const Color(0xFFFFFFFF));
        wash(_MixShapes.sugarWarm, const Color(0xFFFFF4D6));
    }
  }

  /// Vòng chấm chỉ dẫn theo elip mặt bột (tỉ lệ bán kính tham chiếu 140 / [_ref]): chấm mực run tay dựng sẵn thành
  /// một hình + mũi tên nét bút chạy vòng. Mờ dần theo [alpha] (một lớp vẽ, chỉ lúc mới bắt đầu trộn).
  void _paintGuide(Canvas canvas, double alpha) {
    final s = surface;
    final rx = s.width / 2 * 140 / _ref;
    final ry = s.height / 2 * 140 / _ref;
    final fade = alpha < 0.999;
    if (fade) {
      canvas.saveLayer(Rect.fromCenter(center: center, width: rx * 2 + 120, height: ry * 2 + 120), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    final ring = cachedArt(('mixGuide', rx, ry), () {
      const m = 10.0;
      final dots = [
        for (var v = 0; v < kGuideDotVariants; v++) buildInkDotArt(4, const Color(0x595A3E36), v),
      ];
      final picture = recordArt((c) {
        for (var i = 0; i < 32; i++) {
          final a = i * 2 * math.pi / 32;
          final dot = dots[i % kGuideDotVariants];
          drawPictureAt(c, dot.picture, Offset(m + rx + math.cos(a) * rx, m + ry + math.sin(a) * ry) - dot.origin);
        }
      });
      return GameArt(picture, Size(rx * 2, ry * 2), origin: Offset(m + rx, m + ry), parts: dots);
    });
    drawPictureAt(canvas, ring.picture, center - ring.origin);
    // Mũi tên chạy theo vòng: mũi tên nét bút vẽ tay (chĩa sang trái) xoay theo tiếp tuyến.
    final a = time * 2.2;
    final p = center + Offset(math.cos(a) * rx, math.sin(a) * ry);
    final dir = Offset(-math.sin(a) * rx, math.cos(a) * ry);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(dir.direction + math.pi);
    canvas.scale(0.62);
    paintHintArrow(canvas, const Offset(-22, 0));
    canvas.restore();
    if (fade) canvas.restore();
  }
}

/// Hình run tay của mặt bột trạm trộn, dựng một lần (lười) rồi giữ: mỗi khung chỉ gán màu cho Paint và vẽ path.
/// Toạ độ: nguyên liệu, bọt, vệt xoáy trong vòng tròn bán kính tham chiếu (gốc = tâm); gợn quanh gốc.
abstract final class _MixShapes {
  static Path _w(Path p, int seed, {double amp = 1.2, double step = 3}) => wobblePath(p, seed: seed, amplitude: amp, step: step);
  static Path _oval(Rect r, int seed, {double amp = 1.2}) => _w(Path()..addOval(r), seed, amp: amp, step: 2.5);

  static final heapShadow = _oval(Rect.fromCenter(center: const Offset(0, 6), width: 66, height: 26), 0x101, amp: 2.4);
  static final heap = _w(
    Path.combine(
      PathOperation.union,
      Path()..addOval(const Rect.fromLTRB(-30, -16, 30, 10)),
      Path()..addOval(const Rect.fromLTRB(-18, -26, 16, 0)),
    ),
    0x102,
    amp: 1.8,
    step: 2.5,
  );
  static final heapLight = _oval(const Rect.fromLTRB(-10, -24, 4, -14), 0x103, amp: 0.8);
  static final heapShade = _oval(const Rect.fromLTRB(4, -8, 26, 6), 0x104, amp: 1.2);

  static final eggWhite = _oval(Rect.fromCenter(center: Offset.zero, width: 70, height: 46), 0x111, amp: 3.2);
  static final yolk = _oval(Rect.fromCircle(center: const Offset(3, -3), radius: 15), 0x112, amp: 0.9);
  static final yolkShade = _oval(const Rect.fromLTRB(-6, 2, 16, 12), 0x113, amp: 0.8);
  static final yolkLight = _oval(Rect.fromCircle(center: const Offset(-3, -9), radius: 4.5), 0x114, amp: 0.5);

  static Path _rrect(Rect r, double radius, int seed, double amp) =>
      _w(Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))), seed, amp: amp, step: 2.5);
  static final butterFront = _rrect(const Rect.fromLTRB(-22, -6, 22, 14), 5, 0x121, 1.2);
  static final butterTop = _rrect(const Rect.fromLTRB(-22, -20, 22, 2), 6, 0x122, 1.2);
  static final butterLight = _rrect(const Rect.fromLTRB(-16, -17, 4, -11), 3, 0x123, 0.6);

  static Path _grains(int n, double r, double Function(int i) x, double Function(int i) y, int seed) {
    final out = Path();
    for (var i = 0; i < n; i++) {
      out.addPath(_oval(Rect.fromCircle(center: Offset(x(i), y(i)), radius: r), seed + i, amp: 0.5), Offset.zero);
    }
    return out;
  }

  static final sugar = _grains(9, 3.2, (i) => math.cos(i * 1.7) * 16, (i) => math.sin(i * 2.3) * 11, 0x130);
  static final sugarWarm = _grains(5, 2.4, (i) => math.cos(i * 2.9 + 1) * 11, (i) => math.sin(i * 1.3 + 2) * 8, 0x140);

  /// Bọt khí 3 cỡ (bán kính 4, 6, 8).
  static final bubbles = [for (var i = 0; i < 3; i++) _oval(Rect.fromCircle(center: Offset.zero, radius: 4 + i * 2.0), 0x150 + i, amp: 0.7)];

  /// 3 vệt xoáy ở góc quay 0 (xoay canvas theo tay khi vẽ).
  static final swirls = [for (var k = 0; k < 3; k++) _w(_spiral(k), 0x160 + k, amp: 2.4, step: 6)];

  static Path _spiral(int k) {
    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final a = k * 2 * math.pi / 3 + t * 4.2;
      final rr = 26 + t * (MixStation._ref - 40);
      if (i == 0) {
        path.moveTo(math.cos(a) * rr, math.sin(a) * rr);
      } else {
        path.lineTo(math.cos(a) * rr, math.sin(a) * rr);
      }
    }
    return path;
  }

  static final Map<Rect, Path> _edges = {};

  /// Viền run tay của mặt bột [oval] (dùng để cắt + nét viền).
  static Path edge(Rect oval) => _edges[oval] ??= _oval(oval.deflate(1), 0x170, amp: 1.6);

  static final Map<double, _AroundTip> _around = {};

  /// Gợn quanh đầu phới + vệt sáng mẩu bột nhúng theo tỉ lệ dẹt [k] của mặt bột.
  static _AroundTip around(double k) => _around[k] ??= _AroundTip(
        rippleInner: _oval(Rect.fromCenter(center: Offset.zero, width: 56, height: 56 * k * 1.4), 0x180, amp: 1.4),
        rippleOuter: _oval(Rect.fromCenter(center: Offset.zero, width: 84, height: 84 * k * 1.4), 0x181, amp: 1.8),
        dipShine: extractFraction(_oval(Rect.fromCenter(center: Offset.zero, width: 46, height: 46 * k * 1.3), 0x182, amp: 0.8), 0.53, 0.97),
      );
}

class _AroundTip {
  const _AroundTip({required this.rippleInner, required this.rippleOuter, required this.dipShine});

  final Path rippleInner;
  final Path rippleOuter;
  final Path dipShine;
}
