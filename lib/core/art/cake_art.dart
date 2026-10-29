import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/paint/sl_cache.dart';
import '../../ui/sugarleaf/paint/sl_random.dart';
import '../catalog.dart';
import '../models/ids.dart';
import '../models/order.dart';
import 'art_sprites.dart';
import 'item_art.dart';

/// Mô tả hình một chiếc bánh ở bất kỳ giai đoạn nào (khuôn rỗng → bột → nướng → kem → topping).
class CakeVisual {
  const CakeVisual({
    required this.mould,
    required this.batter,
    this.batterFill = 1,
    this.baked = 1,
    this.frosting,
    this.frostCoverage = 1,
    this.toppings = const {},
  });

  /// Bánh hoàn chỉnh của một món (kem mặc định, không topping nếu không truyền).
  factory CakeVisual.recipe(RecipeId id, {FrostingId? frosting, Map<ToppingId, int> toppings = const {}}) {
    final r = Catalog.recipe(id);
    return CakeVisual(mould: r.mould, batter: r.batter, frosting: frosting ?? r.frostings.first, toppings: toppings);
  }

  /// Bánh hoàn chỉnh đúng như đơn gọi.
  factory CakeVisual.order(Order order) => CakeVisual.recipe(
        order.recipe,
        frosting: order.frosting,
        toppings: {for (final t in order.toppings) t.topping: t.count},
      );

  final MouldType mould;
  final BatterType batter;

  /// 0 = khuôn rỗng, 1 = đầy bột.
  final double batterFill;

  /// 0 = bột sống, 1 = vàng đẹp, 2 = cháy.
  final double baked;

  /// null = chưa phủ kem.
  final FrostingId? frosting;

  /// 0..1 độ phủ kem (vẽ bằng độ đậm).
  final double frostCoverage;

  /// Topping trên mặt bánh.
  final Map<ToppingId, int> toppings;

  CakeVisual copyWith({
    double? batterFill,
    double? baked,
    FrostingId? frosting,
    double? frostCoverage,
    Map<ToppingId, int>? toppings,
  }) =>
      CakeVisual(
        mould: mould,
        batter: batter,
        batterFill: batterFill ?? this.batterFill,
        baked: baked ?? this.baked,
        frosting: frosting ?? this.frosting,
        frostCoverage: frostCoverage ?? this.frostCoverage,
        toppings: toppings ?? this.toppings,
      );
}

/// Vẽ bánh vào [Rect] bất kỳ (giữ tỉ lệ vuông, căn giữa).
///
/// Có ảnh vẽ tay đế đã nướng (`ArtSprites.baked`) thì vẽ ảnh: đặt sao cho bề rộng và đáy trùng hình code cũ
/// (bố cục trạm/thẻ không đổi), độ chín = ColorFilter trên ảnh, kem vẽ bằng code kiểu màu nước trên mặt bánh
/// của ảnh, topping là ảnh. Chưa nạp xong / thiếu ảnh → hình code (dự phòng).
abstract final class CakeArt {
  static const _outline = ItemArt.outline;

  /// Vùng mặt bánh (elip) trong [rect] — game dùng để đặt topping/vẽ kem trùng với hình. Đo trên ảnh đế đã
  /// nướng (không phụ thuộc ảnh đã nạp hay chưa).
  static Rect topSurface(Rect rect, MouldType mould) {
    final r = ItemArt.square(rect);
    final fit = _fits[mould]!;
    final k = fit.scale(r.width);
    final o = fit.origin(r);
    return Rect.fromLTRB(
      o.dx + (fit.top.left - fit.body.center.dx) * k,
      o.dy + (fit.top.top - fit.body.bottom) * k,
      o.dx + (fit.top.right - fit.body.center.dx) * k,
      o.dy + (fit.top.bottom - fit.body.bottom) * k,
    );
  }

  /// Khung vật thể trong ảnh (alpha) quy ra [rect] — trùng bề rộng/đáy hình code.
  @visibleForTesting
  static Rect artBodyRect(Rect rect, MouldType mould) {
    final r = ItemArt.square(rect);
    final fit = _fits[mould]!;
    final k = fit.scale(r.width);
    final o = fit.origin(r);
    return Rect.fromLTRB(o.dx - fit.body.width / 2 * k, o.dy - fit.body.height * k, o.dx + fit.body.width / 2 * k, o.dy);
  }

  static void paint(Canvas canvas, Rect rect, CakeVisual v) {
    final r = ItemArt.square(rect);
    final image = v.batterFill > 0 ? ArtSprites.baked(v.mould, v.batter).image : null;
    if (image != null) {
      _paintArt(canvas, r, v, image);
      return;
    }
    canvas.save();
    switch (v.mould) {
      case MouldType.cupcakeLiner:
      case MouldType.muffinCup:
        _cupcake(canvas, r, v);
      case MouldType.tartShell:
        _tart(canvas, r, v);
      case MouldType.roundPan:
      case MouldType.springformPan:
        _roundCake(canvas, r, v);
      case MouldType.tallPan:
        _tallCake(canvas, r, v);
      case MouldType.macaronMat:
        _macaron(canvas, r, v);
    }
    if (v.batterFill > 0) _toppings(canvas, _codeTop(r, v.mould), v.toppings);
    canvas.restore();
  }

  // ================================================================== Ảnh vẽ tay

  /// Số đo ảnh `assets/art/baked/<khuôn>.webp` (px ảnh 512×512; biến thể theo bột cùng khung hình) + vùng
  /// hình code tương ứng (đo bằng cách render hình code, ×cạnh khung, tính từ tâm).
  static const _fits = <MouldType, _BakedFit>{
    MouldType.cupcakeLiner: _BakedFit(
      body: Rect.fromLTRB(17, 14, 495, 497),
      top: Rect.fromLTRB(56, 40, 456, 230),
      halfWidth: 0.323,
      bottom: 0.413,
    ),
    MouldType.muffinCup: _BakedFit(
      body: Rect.fromLTRB(14, 15, 498, 497),
      top: Rect.fromLTRB(87, 56, 417, 240),
      halfWidth: 0.373,
      bottom: 0.413,
    ),
    MouldType.tartShell: _BakedFit(
      body: Rect.fromLTRB(14, 57, 497, 454),
      top: Rect.fromLTRB(58, 95, 454, 349),
      halfWidth: 0.443,
      bottom: 0.393,
    ),
    MouldType.roundPan: _BakedFit(
      body: Rect.fromLTRB(14, 54, 497, 458),
      top: Rect.fromLTRB(19, 57, 491, 329),
      halfWidth: 0.413,
      bottom: 0.343,
    ),
    MouldType.springformPan: _BakedFit(
      body: Rect.fromLTRB(14, 75, 498, 437),
      top: Rect.fromLTRB(17, 82, 493, 290),
      halfWidth: 0.413,
      bottom: 0.263,
    ),
    MouldType.tallPan: _BakedFit(
      body: Rect.fromLTRB(14, 74, 498, 438),
      top: Rect.fromLTRB(41, 80, 469, 228),
      halfWidth: 0.413,
      bottom: 0.473,
    ),
    // Ảnh là khay 6 chiếc: lấy chiếc trắng góc phải dưới (cắt theo [_macaronClip]), nhuộm theo màu nhân.
    MouldType.macaronMat: _BakedFit(
      src: Rect.fromLTRB(318, 246, 448, 366),
      body: Rect.fromLTRB(326, 254, 439, 357),
      top: Rect.fromLTRB(330, 257, 434, 311),
      halfWidth: 0.323,
      bottom: 0.303,
    ),
  };

  /// Viền một chiếc macaron trên ảnh khay (px ảnh).
  static final Path _macaronClip = Path()
    ..addRRect(RRect.fromLTRBAndCorners(
      326, 254, 439, 357,
      topLeft: const Radius.elliptical(56, 38),
      topRight: const Radius.elliptical(56, 38),
      bottomLeft: const Radius.elliptical(54, 26),
      bottomRight: const Radius.elliptical(54, 26),
    ));

  static final Paint _imagePaintBase = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;
  static final Map<int, Paint> _imagePaints = {};
  static final Paint _fillP = Paint()..isAntiAlias = true;
  static final Paint _strokeP = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _layerP = Paint();
  static final Paint _toppingP = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  static Paint _fillC(Color c) => _fillP..color = c;
  static Paint _strokeC(Color c, double w) => _strokeP
    ..color = c
    ..strokeWidth = w;

  /// Độ chín lượng tử hoá (bước 0.05, 0..2) → chỉ số cache.
  static int _bakeLevel(double baked) => (baked.clamp(0.0, 2.0) * 20).round();

  /// Ma trận màu theo độ chín [baked] (0 sống, 1 vàng đẹp = nguyên ảnh, 2 cháy) cho `ColorFilter.matrix`.
  /// Sống: nhạt, hơi xám vàng theo màu bột; cháy: sẫm nâu.
  @visibleForTesting
  static List<double> bakeMatrix(BatterType batter, double baked) {
    final b = baked.clamp(0.0, 2.0);
    if (b < 1) {
      // Pha về "bột sống": màu bột (pha trắng) × độ sáng của ảnh — vẫn giữ nét vẽ, mất màu nướng vàng.
      final a = 0.72 * (1 - b);
      final p = Color.lerp(ItemArt.batterColor(batter), const Color(0xFFFFFFFF), 0.4)!;
      List<double> row(double pc, int ch) {
        final g = a * pc * 0.6;
        return [
          (ch == 0 ? 1 - a : 0) + g * 0.299,
          (ch == 1 ? 1 - a : 0) + g * 0.587,
          (ch == 2 ? 1 - a : 0) + g * 0.114,
          0,
          a * pc * 0.55 * 255,
        ];
      }

      return [...row(p.r, 0), ...row(p.g, 1), ...row(p.b, 2), 0, 0, 0, 1, 0];
    }
    final k = b - 1;
    const burn = [0.55, 0.42, 0.33];
    return [
      1 - k * (1 - burn[0]), 0, 0, 0, 0, //
      0, 1 - k * (1 - burn[1]), 0, 0, 0,
      0, 0, 1 - k * (1 - burn[2]), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Paint vẽ ảnh đế (ColorFilter theo độ chín, macaron nhuộm thêm màu nhân). Giữ trong cache, không tạo mỗi khung.
  static Paint _imagePaint(CakeVisual v) {
    final level = _bakeLevel(v.baked);
    final tinted = v.mould == MouldType.macaronMat && v.frosting != null;
    final frost = tinted ? v.frosting!.index + 1 : 0;
    final cov = tinted ? (v.frostCoverage.clamp(0.0, 1.0) * 10).round() : 0;
    final key = ((v.batter.index * 41 + level) * 8 + frost) * 11 + cov;
    return _imagePaints[key] ??= () {
      final m = bakeMatrix(v.batter, level / 20);
      if (tinted) {
        final strength = 0.7 * (0.35 + 0.65 * cov / 10);
        final t = Color.lerp(const Color(0xFFFFFFFF), ItemArt.frostingColor(v.frosting!), strength)!;
        final mul = [t.r, t.g, t.b];
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 5; j++) {
            m[i * 5 + j] *= mul[i];
          }
        }
      }
      if (level == 20 && !tinted) return _imagePaintBase;
      return Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true
        ..colorFilter = ColorFilter.matrix(m);
    }();
  }

  /// Vẽ trong hệ toạ độ px ảnh: mọi Path (viền kem, khung macaron) dựng một lần theo khuôn, không theo cỡ khung.
  static void _paintArt(Canvas canvas, Rect r, CakeVisual v, Image image) {
    final fit = _fits[v.mould]!;
    final k = fit.scale(r.width);
    final o = fit.origin(r);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    // Đang đổ bột / nở: co dọc từ đáy.
    if (v.batterFill < 1) canvas.scale(1, 0.6 + 0.4 * v.batterFill.clamp(0.0, 1.0));
    canvas.scale(k);
    canvas.translate(-fit.body.center.dx, -fit.body.bottom);
    final macaron = v.mould == MouldType.macaronMat;
    if (macaron) {
      canvas.save();
      canvas.clipPath(_macaronClip);
    }
    canvas.drawImageRect(image, fit.src, fit.src, _imagePaint(v));
    if (macaron) {
      canvas.restore();
      // Viền nâu ấm che mép giấy khay sau khi cắt.
      canvas.drawPath(_macaronClip, _strokeC(const Color(0xB38A5A40), 1.2));
    } else if (v.frosting != null) {
      _paintFrosting(canvas, v, fit);
    }
    _toppings(canvas, fit.top, v.toppings);
    canvas.restore();
  }

  // ------------------------------------------------------------------ Kem kiểu màu nước vẽ tay

  /// Lớp kem đã ghi sẵn thành Picture (px ảnh) theo (khuôn, kem, độ phủ lượng tử, mức cháy, đốm cháy tart):
  /// vẽ lại mỗi frame chỉ là một `drawPicture`. Đang phủ kem độ phủ đổi liên tục → tối đa 21 bước/loại kem.
  static final _frostArts = SLLru<Object, _FrostArt>(64);

  /// Hình học lớp kem (viền run tay, vệt loang, vệt sáng, mảng hở theo độ phủ) theo khuôn, dựng một lần.
  static final Map<MouldType, _FrostGeom> _frostGeoms = {};

  /// Độ phủ lượng tử hoá (bước 0.05).
  static int _coverStep(double cover) => (cover.clamp(0.0, 1.0) * 20).round();

  /// Mức cháy của bánh dưới kem: 0 = không, 1 = hơi quá lửa, 2 = cháy.
  static int _burnStep(double baked) => baked <= 1.1 ? 0 : (baked < 1.55 ? 1 : 2);

  /// Số mục / trúng / trượt / tổng µs dựng của cache lớp kem (đo hiệu năng).
  @visibleForTesting
  static ({int length, int hits, int misses, int buildMicros}) get debugFrostCache =>
      (length: _frostArts.length, hits: _frostArts.hits, misses: _frostArts.misses, buildMicros: _frostArts.buildMicros);

  @visibleForTesting
  static void debugClearFrostCache() {
    _frostArts.clear();
    _frostGeoms.clear();
  }

  /// Dựng sẵn lớp kem của [v] (hình học theo khuôn + Picture theo trạng thái) để lần vẽ đầu không tốn vài ms —
  /// vd. gọi khi vào trạm phủ kem với `bakedCake.copyWith(frosting: order.frosting)`. Không vẽ gì; macaron/không
  /// kem thì bỏ qua.
  static void warmFrosting(CakeVisual v) {
    if (v.frosting == null || v.mould == MouldType.macaronMat) return;
    final recorder = PictureRecorder();
    _paintFrosting(Canvas(recorder), v, _fits[v.mould]!);
    recorder.endRecording().dispose();
  }

  static void _paintFrosting(Canvas canvas, CakeVisual v, _BakedFit fit) {
    final frosting = v.frosting!;
    final step = _coverStep(v.frostCoverage);
    final burn = _burnStep(v.baked);
    final spots = v.mould == MouldType.tartShell && frosting == FrostingId.custard && v.baked >= 0.8;
    final art = _frostArts.obtain((v.mould, frosting, step, burn, spots), () {
      final geom = _frostGeoms[v.mould] ??= _FrostGeom.build(v.mould, fit.top);
      return _FrostArt(_recordFrosting(geom, _FrostColors(frosting, burn), step, spots));
    });
    canvas.drawPicture(art.picture);
  }

  /// Ghi lớp kem: từng mảng tô màu nước (sáng trên → đậm dần ở mép, vệt loang) + nét mực run tay; phủ chưa kín
  /// thì lớp kem mỏng hơn và hở vài mảng lộ mặt bánh (mép mảng hở đọng màu như vệt màu nước).
  static Picture _recordFrosting(_FrostGeom g, _FrostColors col, int step, bool spots) {
    final recorder = PictureRecorder();
    final c = Canvas(recorder);
    final alpha = 0.8 + 0.2 * step / 20;
    final layered = alpha < 0.99;
    if (layered) c.saveLayer(g.bounds.inflate(24), _layerP..color = Color.fromRGBO(0, 0, 0, alpha));
    final holes = g.holes(step);
    if (holes != null) {
      c.save();
      c.clipPath(g.keep(step)!);
    }
    for (final layer in g.layers) {
      _wash(c, layer, col);
    }
    for (final puff in g.puffs) {
      _puff(c, puff, col);
    }
    if (spots) {
      // Đốm cháy cạnh đặc trưng của tart trứng.
      for (final s in g.spots) {
        c.drawPath(s, _fillC(const Color(0x389A5A1E)));
      }
    }
    if (holes != null) {
      c.drawPath(holes, _strokeC(col.pool.withValues(alpha: 0.5), 3.2));
      c.restore();
    }
    if (layered) c.restore();
    return recorder.endRecording();
  }

  /// Một mảng kem: tô chuyển sáng (trên) → màu kem → bóng (mép dưới), quầng sáng mềm, vệt loang, màu đọng đậm
  /// dần ở mép, vệt sáng run tay; rồi nét mực: nét phụ caramel lệch, nét chính, đoạn đè đậm, nét tô lại mảnh.
  static void _wash(Canvas c, _FrostLayer l, _FrostColors col) {
    final b = l.bounds;
    c.drawPath(
      l.outline,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.linear(Offset(b.center.dx, b.top), Offset(b.center.dx, b.bottom), [col.light, col.base, col.base, col.shade],
            const [0, 0.3, 0.6, 1]),
    );
    c.save();
    c.clipPath(l.outline);
    for (final g in l.glow) {
      c.drawPath(g, _fillC(col.glow));
    }
    for (final (blob, dark) in l.blooms) {
      c.drawPath(blob, _fillC(dark ? col.bloomDark : col.bloomLight));
    }
    for (final (w, a) in const [(18.0, 0.07), (10.0, 0.09), (5.0, 0.13)]) {
      c.drawPath(l.outline, _strokeC(col.pool.withValues(alpha: a * col.poolK), w));
    }
    c.drawPath(l.outline, _strokeC(col.pool.withValues(alpha: 0.3 * col.poolK), 1.6));
    if (l.shine != null) {
      c.drawPath(l.shine!, _strokeC(col.shine.withValues(alpha: col.shine.a * 0.75), 2.4));
      c.drawPath(l.shineCore!, _strokeC(col.shine, 4.4));
    }
    c.restore();
    c.save();
    c.translate(1.6, 2);
    c.drawPath(l.ink, _strokeC(col.second, 1.3));
    c.restore();
    c.drawPath(l.ink, _strokeC(col.ink, 2));
    c.drawPath(l.pressure, _strokeC(col.ink, 3));
    c.drawPath(l.retrace, _strokeC(col.inkSoft, 1));
    for (final d in l.details) {
      c.drawPath(d, _strokeC(col.inkSoft, 1.6));
    }
  }

  /// Bông kem nhỏ (viền bắt bông): tô tròn sáng góc trên trái, viền mực mảnh run tay, chấm sáng méo.
  static void _puff(Canvas c, _FrostPuff p, _FrostColors col) {
    final b = p.bounds;
    c.drawPath(
      p.outline,
      Paint()
        ..isAntiAlias = true
        ..shader = Gradient.radial(b.center.translate(-b.width * 0.18, -b.height * 0.22), b.width * 0.62, [col.light, col.base, col.shade],
            const [0, 0.5, 1]),
    );
    c.drawPath(p.outline, _strokeC(col.softInk, 1.4));
    c.drawPath(p.shine, _fillC(col.shine));
  }

  // ================================================================== Hình code (dự phòng)

  /// Mặt bánh của hình code (chỉ dùng khi vẽ dự phòng).
  static Rect _codeTop(Rect rect, MouldType mould) {
    final r = ItemArt.square(rect);
    final s = r.width;
    final c = r.center;
    return switch (mould) {
      MouldType.cupcakeLiner || MouldType.muffinCup =>
        Rect.fromCenter(center: c.translate(0, -s * 0.14), width: s * 0.6, height: s * 0.26),
      MouldType.tartShell => Rect.fromCenter(center: c.translate(0, s * 0.02), width: s * 0.7, height: s * 0.28),
      MouldType.roundPan || MouldType.springformPan =>
        Rect.fromCenter(center: c.translate(0, -s * 0.12), width: s * 0.8, height: s * 0.3),
      MouldType.tallPan => Rect.fromCenter(center: c.translate(0, -s * 0.26), width: s * 0.56, height: s * 0.2),
      MouldType.macaronMat => Rect.fromCenter(center: c.translate(0, -s * 0.12), width: s * 0.6, height: s * 0.22),
    };
  }

  static Paint _fill(Color c) => ItemArt.fill(c);
  static Paint _stroke(Color c, double w) => ItemArt.stroke(c, w);

  static Color _frost(CakeVisual v) {
    final c = ItemArt.frostingColor(v.frosting!);
    return c.withValues(alpha: (0.35 + 0.65 * v.frostCoverage.clamp(0.0, 1.0)));
  }

  static void _cupcake(Canvas canvas, Rect r, CakeVisual v) {
    final s = r.width;
    final c = r.center;
    final line = s * 0.025;
    final muffin = v.mould == MouldType.muffinCup;
    final linerColor = muffin ? const Color(0xFFC99467) : const Color(0xFFF49AB0);
    final top = c.dy + s * 0.02;
    final bottom = c.dy + s * 0.4;
    final liner = Path()
      ..moveTo(c.dx - s * 0.3, top)
      ..lineTo(c.dx + s * 0.3, top)
      ..lineTo(c.dx + s * 0.22, bottom)
      ..lineTo(c.dx - s * 0.22, bottom)
      ..close();

    // Bột/bánh (vòm) nằm sau mép cốc.
    if (v.batterFill > 0) {
      final rise = v.baked <= 0 ? 0.0 : math.min(1.0, v.baked);
      final domeH = s * (0.04 + 0.18 * rise) * v.batterFill + (muffin ? s * 0.05 * rise : 0);
      final dome = Path()
        ..moveTo(c.dx - s * (muffin ? 0.36 : 0.31), top + s * 0.02)
        ..cubicTo(c.dx - s * 0.32, top - domeH * 1.3, c.dx + s * 0.32, top - domeH * 1.3, c.dx + s * (muffin ? 0.36 : 0.31), top + s * 0.02)
        ..close();
      canvas.drawPath(dome, _fill(ItemArt.bakedColor(v.batter, v.baked)));
      canvas.drawPath(dome, _stroke(_outline, line));
    }

    canvas.drawPath(liner, _fill(linerColor));
    for (var i = 1; i < 6; i++) {
      final t = i / 6;
      canvas.drawLine(
        Offset(c.dx - s * 0.3 + s * 0.6 * t, top),
        Offset(c.dx - s * 0.22 + s * 0.44 * t, bottom),
        _stroke(Color.lerp(linerColor, _outline, 0.3)!, line * 0.8),
      );
    }
    canvas.drawPath(liner, _stroke(_outline, line));

    if (v.frosting != null && v.batterFill > 0) {
      final color = _frost(v);
      final edge = Color.lerp(ItemArt.frostingColor(v.frosting!), _outline, 0.4)!;
      if (muffin) {
        // Muffin: kem rưới mỏng trên mặt.
        final glaze = Rect.fromCenter(center: Offset(c.dx, top - s * 0.12), width: s * 0.5, height: s * 0.16);
        canvas.drawOval(glaze, _fill(color));
        canvas.drawOval(glaze, _stroke(edge, line));
      } else {
        // Cupcake: kem xoắn 3 tầng.
        final layers = [
          Rect.fromCenter(center: Offset(c.dx, top - s * 0.06), width: s * 0.64, height: s * 0.18),
          Rect.fromCenter(center: Offset(c.dx, top - s * 0.16), width: s * 0.5, height: s * 0.16),
          Rect.fromCenter(center: Offset(c.dx, top - s * 0.25), width: s * 0.32, height: s * 0.13),
        ];
        for (final l in layers) {
          canvas.drawOval(l, _fill(color));
          canvas.drawOval(l, _stroke(edge, line));
        }
        canvas.drawCircle(Offset(c.dx - s * 0.1, top - s * 0.18), s * 0.025, _fill(const Color(0x88FFFFFF)));
      }
    }
  }

  static void _tart(Canvas canvas, Rect r, CakeVisual v) {
    final s = r.width;
    final c = r.center;
    final line = s * 0.025;
    final shell = Rect.fromCenter(center: c.translate(0, s * 0.06), width: s * 0.86, height: s * 0.36);
    final crust = ItemArt.bakedColor(BatterType.butter, v.batterFill > 0 ? v.baked : 0.4);
    final side = Rect.fromLTRB(shell.left, shell.center.dy, shell.right, shell.center.dy + s * 0.14);
    canvas.drawRect(side, _fill(Color.lerp(crust, _outline, 0.15)!));
    canvas.drawOval(shell.translate(0, s * 0.14), _fill(Color.lerp(crust, _outline, 0.15)!));
    canvas.drawOval(shell.translate(0, s * 0.14), _stroke(_outline, line));
    canvas.drawLine(side.topLeft, side.bottomLeft, _stroke(_outline, line));
    canvas.drawLine(side.topRight, side.bottomRight, _stroke(_outline, line));
    canvas.drawOval(shell, _fill(crust));
    canvas.drawOval(shell, _stroke(_outline, line));
    final inner = shell.deflate(s * 0.06);
    final hasFilling = v.frosting != null && v.batterFill > 0;
    final fillingColor = hasFilling
        ? Color.lerp(_frost(v), const Color(0xFF8B4A1C), (v.baked - 1).clamp(0.0, 1.0) * 0.6)!
        : Color.lerp(crust, _outline, 0.25)!;
    canvas.drawOval(inner, _fill(fillingColor));
    canvas.drawOval(inner, _stroke(Color.lerp(crust, _outline, 0.5)!, line));
    if (hasFilling && v.frosting == FrostingId.custard && v.baked >= 0.8) {
      // Đốm cháy cạnh đặc trưng của tart trứng.
      for (final o in const [Offset(-0.15, -0.02), Offset(0.12, 0.03), Offset(0.02, -0.05)]) {
        canvas.drawOval(Rect.fromCenter(center: inner.center + o * s, width: s * 0.08, height: s * 0.04), _fill(const Color(0x669A5A1E)));
      }
    }
  }

  static void _cylinder(Canvas canvas, Rect top, double height, Color side, Color face, double line) {
    final bottom = top.translate(0, height);
    final body = Path()
      ..moveTo(top.left, top.center.dy)
      ..lineTo(bottom.left, bottom.center.dy)
      ..arcTo(bottom, math.pi, -math.pi, false)
      ..lineTo(top.right, top.center.dy)
      ..close();
    canvas.drawPath(body, _fill(side));
    canvas.drawPath(body, _stroke(_outline, line));
    canvas.drawOval(top, _fill(face));
    canvas.drawOval(top, _stroke(_outline, line));
  }

  static void _drips(Canvas canvas, Rect top, double depth, Color color, Color edge, double line) {
    final path = Path()..moveTo(top.left, top.center.dy);
    const n = 7;
    for (var i = 0; i < n; i++) {
      final a0 = math.pi - math.pi * i / n;
      final a1 = math.pi - math.pi * (i + 0.5) / n;
      final a2 = math.pi - math.pi * (i + 1) / n;
      final p1 = Offset(top.center.dx + math.cos(a1) * top.width / 2, top.center.dy + math.sin(a1) * top.height / 2);
      final p2 = Offset(top.center.dx + math.cos(a2) * top.width / 2, top.center.dy + math.sin(a2) * top.height / 2);
      final d = depth * (i.isEven ? 1.0 : 0.6);
      final p0 = Offset(top.center.dx + math.cos(a0) * top.width / 2, top.center.dy + math.sin(a0) * top.height / 2);
      path.quadraticBezierTo((p0.dx + p1.dx) / 2, p1.dy + d * 1.4, p2.dx, p2.dy);
    }
    path.arcTo(top, 0, -math.pi, false);
    path.close();
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _stroke(edge, line));
  }

  static void _roundCake(Canvas canvas, Rect r, CakeVisual v) {
    final s = r.width;
    final line = s * 0.025;
    final cheese = v.mould == MouldType.springformPan;
    final top = _codeTop(r, v.mould);
    if (v.batterFill <= 0) {
      ItemArt.paintMould(canvas, r, v.mould);
      return;
    }
    final height = s * (cheese ? 0.22 : 0.3);
    final crumb = ItemArt.bakedColor(v.batter, v.baked);
    final face = v.baked < 0.3 ? ItemArt.batterColor(v.batter) : Color.lerp(crumb, const Color(0xFFFFFFFF), 0.1)!;
    final shiftedTop = top;
    _cylinder(canvas, shiftedTop, height, crumb, face, line);
    if (cheese) {
      // Đế bánh quy.
      final base = Rect.fromLTRB(shiftedTop.left, shiftedTop.center.dy + height - s * 0.05, shiftedTop.right, shiftedTop.center.dy + height);
      canvas.drawRect(base, _fill(const Color(0xFFB9805A)));
      canvas.drawLine(base.topLeft, base.topRight, _stroke(_outline, line * 0.6));
    } else if (v.frosting == null) {
      // Lớp giữa thấy được ở cạnh.
      canvas.drawLine(
        Offset(shiftedTop.left + s * 0.01, shiftedTop.center.dy + height * 0.55),
        Offset(shiftedTop.right - s * 0.01, shiftedTop.center.dy + height * 0.55),
        _stroke(const Color(0xAAFFF8E7), s * 0.03),
      );
    }
    if (v.frosting != null) {
      final color = _frost(v);
      final edge = Color.lerp(ItemArt.frostingColor(v.frosting!), _outline, 0.4)!;
      _drips(canvas, shiftedTop, s * 0.06, color, edge, line);
      canvas.drawOval(shiftedTop.deflate(s * 0.005), _fill(color));
      canvas.drawOval(shiftedTop, _stroke(edge, line));
      // Viền kem bắt bông quanh mặt.
      for (var i = 0; i < 10; i++) {
        final a = math.pi * 2 * i / 10;
        final p = Offset(shiftedTop.center.dx + math.cos(a) * shiftedTop.width * 0.44, shiftedTop.center.dy + math.sin(a) * shiftedTop.height * 0.4);
        canvas.drawCircle(p, s * 0.028, _fill(color));
        canvas.drawCircle(p, s * 0.028, _stroke(edge, line * 0.6));
      }
    }
  }

  static void _tallCake(Canvas canvas, Rect r, CakeVisual v) {
    final s = r.width;
    final line = s * 0.025;
    if (v.batterFill <= 0) {
      ItemArt.paintMould(canvas, r, v.mould);
      return;
    }
    final crumb = ItemArt.bakedColor(v.batter, v.baked);
    final frosted = v.frosting != null;
    final sideColor = frosted ? _frost(v) : crumb;
    final faceColor = frosted ? _frost(v) : Color.lerp(crumb, const Color(0xFFFFFFFF), 0.1)!;
    final bottomTop = Rect.fromCenter(center: r.center.translate(0, s * 0.05), width: s * 0.8, height: s * 0.26);
    _cylinder(canvas, bottomTop, s * 0.28, sideColor, faceColor, line);
    final upperTop = _codeTop(r, v.mould);
    _cylinder(canvas, upperTop, s * 0.26, sideColor, faceColor, line);
    if (frosted) {
      final edge = Color.lerp(ItemArt.frostingColor(v.frosting!), _outline, 0.4)!;
      for (final t in [bottomTop, upperTop]) {
        for (var i = 0; i < 9; i++) {
          final x = t.left + t.width * (i + 0.5) / 9;
          final y = t.center.dy + (t == bottomTop ? s * 0.28 : s * 0.26) + t.height * 0.42 * math.sin(math.pi * (i + 0.5) / 9);
          canvas.drawCircle(Offset(x, y - s * 0.01), s * 0.025, _fill(const Color(0xFFFFFFFF)));
          canvas.drawCircle(Offset(x, y - s * 0.01), s * 0.025, _stroke(edge, line * 0.5));
        }
      }
    }
  }

  static void _macaron(Canvas canvas, Rect r, CakeVisual v) {
    final s = r.width;
    final c = r.center;
    final line = s * 0.025;
    if (v.batterFill <= 0) {
      ItemArt.paintMould(canvas, r, v.mould);
      return;
    }
    // Vỏ macaron nhuộm theo màu nhân (nếu có), nướng làm sẫm nhẹ.
    final tint = v.frosting == null ? ItemArt.batterColor(v.batter) : ItemArt.frostingColor(v.frosting!);
    final shellBase = Color.lerp(ItemArt.batterColor(v.batter), tint, 0.6)!;
    final shell = v.baked > 1 ? Color.lerp(shellBase, const Color(0xFF6B4A2E), (v.baked - 1) * 0.8)! : shellBase;
    final edge = Color.lerp(shell, _outline, 0.5)!;
    final bottom = Rect.fromCenter(center: c.translate(0, s * 0.16), width: s * 0.62, height: s * 0.26);
    final top = Rect.fromCenter(center: c.translate(0, -s * 0.06), width: s * 0.62, height: s * 0.3);
    canvas.drawOval(bottom, _fill(shell));
    canvas.drawOval(bottom, _stroke(_outline, line));
    // "Chân" macaron.
    canvas.drawRect(Rect.fromLTWH(bottom.left + s * 0.03, bottom.top + s * 0.02, bottom.width - s * 0.06, s * 0.04), _fill(Color.lerp(shell, const Color(0xFFFFFFFF), 0.3)!));
    if (v.frosting != null) {
      final filling = Rect.fromCenter(center: c.translate(0, s * 0.05), width: s * 0.58, height: s * 0.1);
      canvas.drawRRect(RRect.fromRectAndRadius(filling, Radius.circular(s * 0.05)), _fill(_frost(v)));
      canvas.drawRRect(RRect.fromRectAndRadius(filling, Radius.circular(s * 0.05)), _stroke(edge, line * 0.7));
    }
    canvas.drawOval(top, _fill(shell));
    canvas.drawOval(top, _stroke(_outline, line));
    canvas.drawOval(Rect.fromCenter(center: top.center.translate(-s * 0.1, -s * 0.05), width: s * 0.16, height: s * 0.06), _fill(const Color(0x66FFFFFF)));
  }

  /// Vị trí cố định (hệ toạ độ chuẩn hoá trong elip mặt bánh) cho topping thứ i.
  static Offset toppingSlot(Rect top, int i, int total) {
    if (total <= 1) return top.center;
    const golden = 2.399963229728653; // góc vàng
    final rr = math.sqrt((i + 0.5) / total) * 0.78;
    final a = i * golden + 0.6;
    return Offset(top.center.dx + math.cos(a) * rr * top.width / 2, top.center.dy + math.sin(a) * rr * top.height / 2);
  }

  /// Topping trên mặt bánh [top] (ảnh vẽ tay; chưa có ảnh → hình code), vẽ từ sau ra trước.
  static void _toppings(Canvas canvas, Rect top, Map<ToppingId, int> toppings) {
    final items = <ToppingId>[
      for (final t in ToppingId.values)
        for (var k = 0; k < (toppings[t] ?? 0); k++) t,
    ];
    if (items.isEmpty) return;
    final size = math.min(top.height * 0.55, top.width * 0.24) * (items.length > 6 ? 0.78 : 1);
    final placed = [for (var i = 0; i < items.length; i++) (items[i], toppingSlot(top, i, items.length))]
      ..sort((a, b) => a.$2.dy.compareTo(b.$2.dy));
    for (final (t, p) in placed) {
      final h = t == ToppingId.candle ? size * 1.6 : size;
      final dst = Rect.fromCenter(center: p.translate(0, -h * 0.3), width: h, height: h);
      final image = ArtSprites.topping(t).image;
      if (image != null) {
        canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), dst, _toppingP);
      } else {
        ItemArt.paintTopping(canvas, dst, t);
      }
    }
  }
}

/// Số đo một ảnh đế đã nướng (px ảnh) và vùng hình code cần trùng (×cạnh khung vuông, tính từ tâm).
class _BakedFit {
  const _BakedFit({
    this.src = const Rect.fromLTWH(0, 0, 512, 512),
    required this.body,
    required this.top,
    required this.halfWidth,
    required this.bottom,
  });

  /// Vùng ảnh được vẽ (cả ảnh; macaron: một chiếc trên khay).
  final Rect src;

  /// Khung vật thể (alpha > 20).
  final Rect body;

  /// Elip mặt bánh.
  final Rect top;

  /// Nửa bề rộng và đáy của hình code.
  final double halfWidth;
  final double bottom;

  /// Đơn vị canvas trên một px ảnh khi khung vuông cạnh [s].
  double scale(double s) => 2 * halfWidth * s / body.width;

  /// Điểm canvas ứng với giữa-đáy của [body].
  Offset origin(Rect square) => Offset(square.center.dx, square.center.dy + bottom * square.width);
}

/// Bảng màu một loại kem (theo `ItemArt.frostingColor`) — bánh cháy dưới kem ([burn] 1–2) làm kem hơi sẫm và
/// loang đậm hơn ở mép, vẫn giữ màu kem.
class _FrostColors {
  factory _FrostColors(FrostingId f, int burn) {
    final dark = f == FrostingId.chocolateGanache;
    final pure = ItemArt.frostingColor(f);
    final base = Color.lerp(pure, dark ? const Color(0xFF3A2018) : const Color(0xFFB98A5E), 0.07 * burn)!;
    final pool = Color.lerp(base, dark ? const Color(0xFF2A160F) : const Color(0xFF9A6A4A), dark ? 0.45 : 0.55)!;
    final ink = Color.lerp(base, dark ? const Color(0xFF2A160F) : const Color(0xFF7A4A34), dark ? 0.6 : 0.68)!;
    return _FrostColors._(
      base: base,
      light: Color.lerp(base, const Color(0xFFFFFFFF), dark ? 0.16 : 0.42)!,
      shade: Color.lerp(base, dark ? const Color(0xFF2E1912) : const Color(0xFFB9805A), dark ? 0.3 : 0.3 + 0.04 * burn)!,
      pool: pool,
      poolK: 1 + 0.4 * burn,
      ink: ink.withValues(alpha: 0.9),
      inkSoft: ink.withValues(alpha: 0.45),
      softInk: ink.withValues(alpha: 0.6),
      second: const Color(0xFFB9805A).withValues(alpha: dark ? 0.35 : 0.5),
      shine: Color.fromRGBO(255, 255, 255, dark ? 0.4 : 0.72),
      glow: Color.fromRGBO(255, 255, 255, dark ? 0.06 : 0.16),
      bloomDark: pool.withValues(alpha: 0.1 + 0.05 * burn),
      bloomLight: Color.fromRGBO(255, 255, 255, dark ? 0.07 : 0.15),
    );
  }

  const _FrostColors._({
    required this.base,
    required this.light,
    required this.shade,
    required this.pool,
    required this.poolK,
    required this.ink,
    required this.inkSoft,
    required this.softInk,
    required this.second,
    required this.shine,
    required this.glow,
    required this.bloomDark,
    required this.bloomLight,
  });

  final Color base, light, shade, pool, ink, inkSoft, softInk, second, shine, glow, bloomDark, bloomLight;

  /// Hệ số độ đậm màu đọng ở mép.
  final double poolK;
}

/// Một lớp kem đã ghi (mục cache của `CakeArt._frostArts`).
class _FrostArt implements SLCachedArt {
  _FrostArt(this.picture);

  final Picture picture;

  @override
  void dispose() => picture.dispose();
}

/// Một mảng kem đã run tay (px ảnh).
class _FrostLayer {
  _FrostLayer({
    required this.outline,
    required this.ink,
    required this.bounds,
    required this.retrace,
    required this.pressure,
    required this.glow,
    required this.blooms,
    this.shine,
    this.shineCore,
    this.details = const [],
  });

  /// Dựng từ đường viền lý tưởng [ideal]: run tay, nét tô lại, đoạn đè đậm, quầng sáng, vệt loang, vệt sáng
  /// (theo cung [shineArc]) và nét gợi khối [details] — tất định theo [seed]. [inkTo] < 1: chỉ đi mực phần đầu
  /// đường viền (phần cuối hoà vào lớp kem bên dưới, không có nét mực ngăn cách).
  factory _FrostLayer.build(Path ideal, int seed, {Path? shineArc, List<Path> details = const [], double inkTo = 1}) {
    final rnd = SLRandom(seed);
    final outline = wobblePath(ideal, seed: seed, amplitude: _FrostGeom.wobble, step: 4);
    final ink = inkTo >= 1 ? outline : extractFraction(outline, 0, inkTo);
    final b = outline.getBounds();
    final from = rnd.nextDouble() * inkTo;
    final retrace = extractFraction(
      wobblePath(ideal, seed: SLRandom.mix(seed, 41), amplitude: _FrostGeom.wobble * 0.8, step: 4),
      from,
      math.min(inkTo, from + 0.4),
    );
    final pressure = Path();
    for (var i = 0; i < 2; i++) {
      final f = rnd.nextDouble();
      pressure.addPath(extractFraction(ink, f, math.min(1, f + rnd.range(0.08, 0.18))), Offset.zero);
    }
    Path blob(Offset o, double rx, double ry) => wobblePath(Path()..addOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2)),
        seed: rnd.nextInt32(), amplitude: math.min(rx, ry) * 0.22, step: 5);
    // Quầng sáng mềm phía trên trái: hai vệt méo lồng nhau (sáng dần vào giữa).
    final go = Offset(b.left + b.width * rnd.range(0.3, 0.45), b.top + b.height * rnd.range(0.22, 0.34));
    final glow = [blob(go, b.width * 0.3, b.height * 0.24), blob(go.translate(-b.width * 0.03, -b.height * 0.02), b.width * 0.17, b.height * 0.13)];
    final blooms = <(Path, bool)>[
      for (var i = 0; i < 3; i++)
        () {
          final r = b.shortestSide * rnd.range(0.14, 0.3);
          final o = Offset(b.left + b.width * rnd.range(0.15, 0.85), b.top + b.height * rnd.range(0.3, 0.85));
          return (blob(o, r * 1.4, r), i < 2);
        }(),
    ];
    Path? shine, core;
    if (shineArc != null) {
      shine = wobblePath(shineArc, seed: SLRandom.mix(seed, 7), amplitude: 1.4, step: 4);
      core = extractFraction(shine, rnd.range(0.12, 0.25), rnd.range(0.5, 0.65));
    }
    return _FrostLayer(
      outline: outline,
      ink: ink,
      bounds: b,
      retrace: retrace,
      pressure: pressure,
      glow: glow,
      blooms: blooms,
      shine: shine,
      shineCore: core,
      details: [for (final (i, d) in details.indexed) wobblePath(d, seed: SLRandom.mix(seed, 60 + i), amplitude: 1.2, step: 4)],
    );
  }

  final Path outline;

  /// Phần đường viền đi nét mực (= [outline] trừ khi dựng với `inkTo` < 1).
  final Path ink;
  final Rect bounds;
  final Path retrace;
  final Path pressure;
  final List<Path> glow;
  final List<(Path, bool)> blooms;
  final Path? shine;
  final Path? shineCore;
  final List<Path> details;
}

/// Một bông kem (viền bắt bông) đã run tay.
class _FrostPuff {
  _FrostPuff(Offset c, double r, int seed)
      : outline = wobblePath(Path()..addOval(Rect.fromCircle(center: c, radius: r)), seed: seed, amplitude: r * 0.08, step: 3),
        bounds = Rect.fromCircle(center: c, radius: r),
        shine = wobblePath(
          Path()..addOval(Rect.fromCenter(center: c.translate(-r * 0.34, -r * 0.38), width: r * 0.5, height: r * 0.3)),
          seed: SLRandom.mix(seed, 3),
          amplitude: r * 0.05,
          step: 2,
        );

  final Path outline;
  final Rect bounds;
  final Path shine;
}

/// Một vệt hở (phủ chưa kín) = khoảng giữa hai nét quệt kem bị sót: dải cong theo elip mặt bánh ở bán kính chuẩn
/// hoá [rho], từ góc [from] dài [span] rad, dày [thick] (chuẩn hoá), thon hai đầu như nét cọ; [threshold] = độ phủ
/// dưới ngưỡng thì hở (càng thấp càng dài/dày).
typedef _Hole = ({double rho, double from, double span, double thick, double threshold, int seed});

/// Hình lớp kem của một khuôn (px ảnh), dựng một lần rồi giữ trong cache: các mảng kem, bông kem, đốm cháy tart,
/// mảng hở theo độ phủ.
class _FrostGeom {
  _FrostGeom(this.layers, this.puffs, this.spots, this._top, this._holeSpecs)
      : bounds = [for (final l in layers) l.bounds, for (final p in puffs) p.bounds]
                .fold<Rect?>(null, (a, b) => a?.expandToInclude(b) ?? b) ??
            Rect.zero;

  final List<_FrostLayer> layers;
  final List<_FrostPuff> puffs;
  final List<Path> spots;

  /// Elip mặt bánh (vệt hở nằm trong đó → luôn lộ mặt bánh của ảnh, không lộ nền).
  final Rect _top;
  final List<_Hole> _holeSpecs;

  /// Khung bao lớp kem (saveLayer, vùng cắt).
  final Rect bounds;

  /// Biên độ run tay của viền kem (px ảnh 512): ~1,2 px trên màn ở trạm 460 px.
  static const wobble = 2.0;

  final _holes = <int, Path?>{};
  final _keeps = <int, Path?>{};

  /// Các vệt hở ở độ phủ [step]/20 (null = phủ kín).
  Path? holes(int step) => _holes.putIfAbsent(step, () {
        final c = step / 20;
        Path? out;
        for (final h in _holeSpecs) {
          if (c >= h.threshold) continue;
          final k = 0.35 + 0.65 * ((h.threshold - c) / 0.3).clamp(0.0, 1.0);
          final p = wobblePath(_band(h.rho, h.from, h.span * k, h.thick * (0.5 + 0.5 * k)), seed: h.seed, amplitude: 1.6, step: 4);
          out = out == null ? p : Path.combine(PathOperation.union, out, p);
        }
        return out;
      });

  /// Dải cong dọc elip [_top] (toạ độ chuẩn hoá), thon hai đầu như nét cọ.
  Path _band(double rho, double from, double span, double thick) {
    const n = 18;
    final c = _top.center, rx = _top.width / 2, ry = _top.height / 2;
    Offset at(double a, double r) => Offset(c.dx + math.cos(a) * r * rx, c.dy + math.sin(a) * r * ry);
    final outer = <Offset>[], inner = <Offset>[];
    for (var j = 0; j <= n; j++) {
      final a = from + span * j / n;
      final w = thick * math.pow(math.sin(math.pi * j / n), 0.6);
      outer.add(at(a, rho + w));
      inner.add(at(a, rho - w));
    }
    return _smooth([...outer, ...inner.reversed]);
  }

  /// Vùng được tô ở độ phủ [step]/20 = khung bao trừ mảng hở (null = phủ kín, không cần cắt).
  Path? keep(int step) => _keeps.putIfAbsent(step, () {
        final h = holes(step);
        if (h == null) return null;
        return Path.combine(PathOperation.difference, Path()..addRect(bounds.inflate(40)), h);
      });

  static _FrostGeom build(MouldType mould, Rect t) {
    final seed = 0xF057 + mould.index * 97;
    final c = t.center;
    _FrostLayer layer(Path p, int i, {Path? shine, List<Path> details = const [], double inkTo = 1}) =>
        _FrostLayer.build(p, SLRandom.mix(seed, i), shineArc: shine, details: details, inkTo: inkTo);
    Path arc(Rect r, double from, double sweep) => Path()..addArc(r, from, sweep);
    final holes = _holeSpecsFor(seed, cupcake: mould == MouldType.cupcakeLiner);
    switch (mould) {
      case MouldType.cupcakeLiner:
        // Kem xoắn 3 tầng (mép dưới mỗi tầng lượn bông) + chóp xoáy tròn mềm liền khối, đáy chóp cong theo tầng.
        final tiers = [
          Rect.fromCenter(center: c.translate(0, t.height * 0.16), width: t.width * 1.2, height: t.height * 0.86),
          Rect.fromCenter(center: c.translate(0, -t.height * 0.2), width: t.width * 0.88, height: t.height * 0.62),
          Rect.fromCenter(center: c.translate(0, -t.height * 0.52), width: t.width * 0.56, height: t.height * 0.5),
        ];
        final by = tiers[2].center.dy + t.height * 0.02;
        double x(double k) => c.dx + t.width * k;
        double y(double k) => by - t.height * k;
        // Chóp: đỉnh cuộn nghiêng sang phải như kem bắt túi; đáy cong tròn lẫn vào tầng dưới, không đi nét mực
        // (liền khối với tầng kem, không có cạnh cắt).
        final tipTop = Path()
          ..moveTo(x(-0.15), y(0))
          ..cubicTo(x(-0.17), y(0.22), x(-0.09), y(0.34), x(-0.02), y(0.42))
          ..cubicTo(x(0.03), y(0.48), x(0.04), y(0.56), x(0.11), y(0.58))
          ..cubicTo(x(0.08), y(0.5), x(0.1), y(0.43), x(0.09), y(0.38))
          ..cubicTo(x(0.16), y(0.3), x(0.18), y(0.14), x(0.15), y(0));
        final tip = Path.from(tipTop)
          ..cubicTo(x(0.1), y(-0.1), x(-0.1), y(-0.1), x(-0.15), y(0))
          ..close();
        double length(Path p) => p.computeMetrics().fold(0.0, (s, m) => s + m.length);
        final tipInk = length(tipTop) / length(tip);
        // Nếp xoáy trên chóp.
        final crease = Path()
          ..moveTo(x(-0.1), y(0.12))
          ..quadraticBezierTo(x(0.0), y(0.04), x(0.11), y(0.2));
        return _FrostGeom(
          [
            for (final (i, (box, n, amp)) in [(tiers[0], 10, 0.11), (tiers[1], 8, 0.12), (tiers[2], 6, 0.13)].indexed)
              layer(_tier(box, n, amp), i, shine: arc(_scaled(box, 0.72), math.pi * 1.12, math.pi * 0.32)),
            layer(
              tip,
              3,
              shine: arc(Rect.fromCenter(center: Offset(x(-0.02), y(0.2)), width: t.width * 0.2, height: t.height * 0.34), math.pi * 1.05,
                  math.pi * 0.4),
              details: [crease],
              inkTo: tipInk,
            ),
          ],
          const [],
          const [],
          t,
          holes,
        );
      case MouldType.muffinCup:
        // Kem rưới mỏng, vài giọt chảy phía trước.
        final e = _scaled(t, 1.04);
        return _FrostGeom(
          [
            layer(_drip(e, const [(0.3, 0.1, 30.0), (0.55, 0.09, 22.0), (0.78, 0.1, 34.0)], sag: 6, wobble: 0.025, waves: 7), 0,
                shine: arc(_scaled(t, 0.68), math.pi * 1.1, math.pi * 0.3)),
          ],
          const [],
          const [],
          t,
          holes,
        );
      case MouldType.tartShell:
        // Nhân phủ kín lòng vỏ.
        return _FrostGeom(
          [
            layer(_drip(_scaled(t, 0.98), const [], sag: 0, wobble: 0.012, waves: 9), 0,
                shine: arc(_scaled(t, 0.7), math.pi * 1.1, math.pi * 0.28)),
          ],
          const [],
          [
            for (final (i, o) in const [Offset(-0.32, -0.05), Offset(0.26, 0.12), Offset(0.04, -0.2), Offset(-0.1, 0.3)].indexed)
              wobblePath(
                Path()..addOval(Rect.fromCenter(center: c + Offset(o.dx * t.width, o.dy * t.height), width: t.width * 0.12, height: t.height * 0.1)),
                seed: SLRandom.mix(seed, 80 + i),
                amplitude: t.height * 0.012,
                step: 3,
              ),
          ],
          t,
          holes,
        );
      case MouldType.roundPan:
        // Phủ mặt + chảy xuống cạnh + viền bắt bông.
        return _FrostGeom(
          [
            layer(_drip(_scaled(t, 1.015), _drips(7, 42, 24, 0.065), sag: 10, wobble: 0.01, waves: 11), 0,
                shine: arc(_scaled(t, 0.62), math.pi * 1.12, math.pi * 0.26)),
          ],
          [
            for (final (i, (o, r)) in _ring(_scaled(t, 0.86), 12, t.height * 0.085, 0, math.pi * 2).indexed)
              _FrostPuff(o, r, SLRandom.mix(seed, 100 + i)),
          ],
          const [],
          t,
          holes,
        );
      case MouldType.springformPan:
        return _FrostGeom(
          [
            layer(_drip(_scaled(t, 1.012), _drips(5, 24, 14, 0.06), sag: 6, wobble: 0.008, waves: 11), 0,
                shine: arc(_scaled(t, 0.62), math.pi * 1.12, math.pi * 0.26)),
          ],
          const [],
          const [],
          t,
          holes,
        );
      case MouldType.tallPan:
        // Tầng trên phủ mặt + chảy; bắt bông ở chân tầng trên (nửa trước).
        final junction = Rect.fromCenter(center: Offset(c.dx, t.center.dy + 66), width: t.width * 1.0, height: t.height);
        return _FrostGeom(
          [
            layer(_drip(_scaled(t, 1.015), _drips(7, 30, 18, 0.065), sag: 6, wobble: 0.01, waves: 11), 0,
                shine: arc(_scaled(t, 0.62), math.pi * 1.12, math.pi * 0.26)),
          ],
          [
            for (final (i, (o, r)) in _ring(junction, 9, 17, math.pi * 0.05, math.pi * 0.95).indexed)
              _FrostPuff(o, r, SLRandom.mix(seed, 100 + i)),
          ],
          const [],
          t,
          holes,
        );
      case MouldType.macaronMat:
        // Macaron: nhân = nhuộm màu ảnh (xem CakeArt._imagePaint).
        return _FrostGeom(const [], const [], const [], t, const []);
    }
  }

  /// Vệt hở rải trong elip mặt bánh: mỗi vệt ở một "vòng" quệt kem riêng (bán kính tăng dần, xen kẽ), góc ngẫu
  /// nhiên theo seed. Ngưỡng giảm dần 0,97 → 0,35: phủ gần kín chỉ hở 1–2 vệt ngắn, phủ 40% hở gần nửa mặt bánh.
  /// Cupcake: chỉ nửa trước (phía sau là các tầng kem cao, hở ở đó trông như thủng).
  static List<_Hole> _holeSpecsFor(int seed, {required bool cupcake}) {
    final rnd = SLRandom(SLRandom.mix(seed, 200));
    const n = 8;
    final turn = rnd.range(0, 2 * math.pi);
    return [
      for (var i = 0; i < n; i++)
        () {
          final thick = rnd.range(0.08, 0.12) * (cupcake ? 1.1 : 1);
          final rho = (cupcake ? 0.5 : 0.42) + (cupcake ? 0.32 : 0.42) * ((i * 5 + 2) % n) / (n - 1);
          // Vòng trong ngắn hơn vòng ngoài (cùng độ dài nét quệt); góc rải đều theo góc vàng.
          final span = rnd.range(0.9, 1.6) * (cupcake ? 0.8 : 0.6 + 0.5 * rho);
          final from = cupcake
              ? 0.1 * math.pi + (0.8 * math.pi - span) * ((i * 0.618034) % 1)
              : turn + i * 2.399963 + rnd.range(-0.5, 0.5);
          return (
            rho: math.min(rho, 0.9 - thick),
            from: from,
            span: span,
            thick: thick,
            threshold: 0.97 - 0.62 * i / (n - 1),
            seed: rnd.nextInt32(),
          );
        }(),
    ];
  }

  static Rect _scaled(Rect r, double k) => Rect.fromCenter(center: r.center, width: r.width * k, height: r.height * k);

  /// [n] giọt chảy rải đều nửa trước, sâu xen kẽ [deep]/[shallow] px, rộng [width]·π rad.
  static List<(double, double, double)> _drips(int n, double deep, double shallow, double width) => [
        for (var i = 0; i < n; i++) ((i + 0.5) / n * 0.86 + 0.07, width, i.isEven ? deep : shallow),
      ];

  /// Bông kem dọc elip [e] từ góc [from] tới [to] (rad), sắp xếp sau → trước.
  static List<(Offset, double)> _ring(Rect e, int n, double r, double from, double to) {
    final full = (to - from) >= math.pi * 2 - 1e-6;
    final list = [
      for (var i = 0; i < n; i++)
        () {
          final a = from + (to - from) * (full ? i / n : i / (n - 1));
          return (Offset(e.center.dx + math.cos(a) * e.width / 2, e.center.dy + math.sin(a) * e.height / 2), r);
        }(),
    ]..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    return list;
  }

  /// Đường cong kín mượt qua các điểm (bezier bậc 2 qua trung điểm).
  static Path _smooth(List<Offset> p) {
    final path = Path();
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    path.moveTo(mid(p.last, p.first).dx, mid(p.last, p.first).dy);
    for (var i = 0; i < p.length; i++) {
      final m = mid(p[i], p[(i + 1) % p.length]);
      path.quadraticBezierTo(p[i].dx, p[i].dy, m.dx, m.dy);
    }
    return path..close();
  }

  /// Elip [e] mép lượn nhẹ ([wobble], [waves] sóng); nửa trước võng [sag] px và có giọt chảy
  /// (vị trí 0..1 dọc nửa trước từ phải sang trái, bề rộng ·π rad, sâu px).
  static Path _drip(Rect e, List<(double, double, double)> drips, {required double sag, required double wobble, required int waves}) {
    const n = 144;
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = math.pi * 2 * i / n;
      final w = 1 + wobble * math.sin(waves * a + 0.7);
      var y = e.center.dy + math.sin(a) * e.height / 2 * w;
      final x = e.center.dx + math.cos(a) * e.width / 2 * w;
      if (a > 0 && a < math.pi) {
        y += sag * math.sin(a);
        for (final (at, width, depth) in drips) {
          final d = (a / math.pi - at) / width;
          if (d.abs() < 1) y += depth * 0.5 * (1 + math.cos(math.pi * d));
        }
      }
      pts.add(Offset(x, y));
    }
    return _smooth(pts);
  }

  /// Một tầng kem xoắn: nửa trên elip, mép dưới thành [scallops] bông lượn (sâu [amp]·cao).
  static Path _tier(Rect box, int scallops, double amp) {
    const n = 96;
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = math.pi * 2 * i / n;
      var y = box.center.dy + math.sin(a) * box.height / 2;
      if (a > 0 && a < math.pi) y += amp * box.height * (math.sin(scallops * a).abs() - 0.3);
      pts.add(Offset(box.center.dx + math.cos(a) * box.width / 2, y));
    }
    return _smooth(pts);
  }
}
