import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show BoxFit;

import '../../core/art/art_sprites.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/paint/hand_drawn.dart';
import '../../ui/sugarleaf/paint/sl_surface.dart';
import 'game_paint.dart';
import 'hand_paint.dart';

/// Nền bếp của trạm đang chơi: ảnh vẽ tay `station_<trạm>` (1280×720, `ArtSprites.station`), chuyển trạm thì
/// hoà dần sang ảnh mới. Ảnh chưa nạp / thiếu → hình vẽ bằng code bên dưới (dự phòng).
///
/// Hình code: tường vữa kem + gạch ốp, cửa sổ nắng chiều nhìn ra đồi và biển (có chậu thảo mộc trên bậu),
/// kệ gỗ có lọ bột/đường/mứt, dây cờ vải, bàn gỗ vân có khăn kẻ ô và vết bột. Chỉ ghi vào Picture khi cần
/// (lần đầu thiếu ảnh) rồi tái dùng (không cấp phát mỗi khung hình).
class KitchenBackdrop extends Component {
  /// [station] = trạm đang chơi (null → luôn vẽ hình code). [loading] true = đang chờ ảnh của trạm đầu: vẽ tờ giấy
  /// kem vẽ tay (không thoáng hiện cảnh code), xong thì ảnh nền hoà dần lên trên giấy.
  KitchenBackdrop({StationId Function()? station, bool Function()? loading})
      : _stationOf = station,
        _loading = loading,
        super(priority: 0);

  final StationId Function()? _stationOf;
  final bool Function()? _loading;
  Picture? _picture;
  StationId? _current;
  StationId? _previous;
  double _fade = 1;

  /// Vừa hết chờ ảnh: ảnh nền đầu tiên hoà dần lên tờ giấy (thay vì lên ảnh của trạm trước).
  bool _fromPaper = false;
  bool _waited = false;

  static const double counterTop = 300;

  /// Thời gian hoà ảnh nền khi chuyển trạm (≈ thời gian trạm mới trượt vào).
  static const double fadeSeconds = 0.45;

  /// Ảnh nền trạm nướng có sẵn lò âm tường ở giữa ảnh → dời ảnh để lò nằm đúng chỗ lò của trạm
  /// (`BakeStation.ovenRect`); dải phải còn hở được lấp bằng ảnh lật gương (nằm dưới cột vé đơn / gợi ý).
  static const Rect bakeArtRect = Rect.fromLTWH(-280, 64, 1280, 720);

  /// Ảnh nền trạm phủ kem có sẵn bàn xoay ở giữa ảnh → phóng ×[frostArtScale] và dời để tâm mặt bàn xoay
  /// (≈ (640, 353) trong ảnh) nằm ngay dưới bánh của trạm, tại [frostTurntable].
  static const double frostArtScale = 1.53;
  static const Offset frostTurntable = Offset(450, 612);
  static const Rect frostArtRect = Rect.fromLTWH(450 - 640 * frostArtScale, 612 - 353 * frostArtScale, 1280 * frostArtScale, 720 * frostArtScale);

  /// Vị trí vẽ ảnh nền của [station] (toạ độ khung 1280×720).
  static Rect artRect(StationId station) => switch (station) {
        StationId.bake => bakeArtRect,
        StationId.frost => frostArtRect,
        _ => _frameRect,
      };

  static const Rect _frameRect = Rect.fromLTWH(0, 0, 1280, 720);

  /// Khung cửa sổ (ngoài) và ô kính bên trong.
  static const Rect _frame = Rect.fromLTRB(598, 84, 882, 244);
  static const Rect _glass = Rect.fromLTRB(614, 100, 866, 232);

  /// Song cửa: dọc ở giữa, ngang ở 55% chiều cao kính.
  static const double _mullionX = 740;
  static const double _mullionY = 172;

  bool get _isLoading => _loading?.call() ?? false;

  @override
  void update(double dt) {
    if (_isLoading) {
      _waited = true;
      return;
    }
    final s = _stationOf?.call();
    if (_waited) {
      _waited = false;
      _fromPaper = true;
      _previous = null;
      _current = s;
      _fade = 0;
    } else if (s != _current) {
      _fromPaper = false;
      _previous = _current;
      _current = s;
      _fade = _previous == null ? 1 : 0;
    } else if (_fade < 1) {
      _fade = (_fade + dt / fadeSeconds).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isLoading) {
      _paintPaper(canvas);
      _paintColumn(canvas);
      return;
    }
    final cur = _current ?? _stationOf?.call();
    final image = cur == null ? null : ArtSprites.station(cur).image;
    if (cur == null || image == null) {
      _paintCode(canvas);
      _paintColumn(canvas);
      return;
    }
    final prev = _previous;
    if (_fade < 1 && (prev != null || _fromPaper)) {
      if (prev == null) {
        _paintPaper(canvas);
      } else {
        final prevImage = ArtSprites.station(prev).image;
        if (prevImage == null) {
          _paintCode(canvas);
        } else {
          _paintArt(canvas, prevImage, artRect(prev), 1);
        }
      }
      _paintArt(canvas, image, artRect(cur), easeInOut(_fade));
    } else {
      _paintArt(canvas, image, artRect(cur), 1);
    }
    _paintColumn(canvas);
  }

  /// Cột phải (vé đơn + gợi ý): tờ giấy kem vẽ tay toàn chiều cao, mép trái xé nhẹ — tách khỏi vùng chơi và làm
  /// dịu chi tiết ảnh. Dựng một lần.
  void _paintColumn(Canvas canvas) => canvas.drawPicture(cachedArt('columnSheet', buildColumnSheetArt).picture);

  /// Tờ giấy kem vẽ tay phủ cả khung (lúc chờ ảnh nền của trạm đầu). Dựng một lần.
  void _paintPaper(Canvas canvas) => canvas.drawPicture(cachedArt('loadingPaper', _buildPaper).picture);

  static GameArt _buildPaper() {
    final art = buildSurfaceArt(
      const SLSurfaceSpec(shape: SLRoundRect(0), color: AppColors.cream, outline: false, seed: 0xCA9E),
      const Size(1280, 720),
    );
    final picture = recordArt((c) {
      c.drawPicture(art.picture);
      // Gợi ý mặt bàn: dải màu nước caramel nhạt loang ở nửa dưới.
      paintWashBand(c, const Rect.fromLTRB(-20, 430, 1300, 760), const Color(0xFFF1D9BC), 0xCA9F, alpha: 0.4, highlight: false);
    });
    return GameArt(picture, const Size(1280, 720), parts: [art]);
  }

  void _paintCode(Canvas canvas) => canvas.drawPicture(_picture ??= _record());

  /// Ảnh nền vẽ vào [dst]; phần hở bên phải khung (nếu có) lấp bằng ảnh lật gương.
  void _paintArt(Canvas canvas, Image image, Rect dst, double opacity) {
    drawArt(canvas, image, dst, fit: BoxFit.cover, opacity: opacity);
    if (dst.right < 1280) {
      final seam = dst.right;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(seam, 0, 1280, 720));
      canvas.translate(seam * 2, 0);
      canvas.scale(-1, 1);
      drawArt(canvas, image, dst, fit: BoxFit.cover, opacity: opacity);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  Picture _record() {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    _paint(c);
    return rec.endRecording();
  }

  void _paint(Canvas c) {
    _wall(c);
    _window(c);
    _shelf(c);
    _bunting(c);
    _counter(c);
    _sunlight(c);
    _flour(c);
    _towel(c, const Offset(66, 398), -0.13);
    _vignette(c);
  }

  // ------------------------------------------------------------------ Tường

  void _wall(Canvas c) {
    // Vữa kem: trên sẫm nhẹ (bóng trần), dưới sáng dần.
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1280, counterTop),
      Paint()
        ..shader = Gradient.linear(const Offset(0, 72), const Offset(0, counterTop), const [
          Color(0xFFF4DFC3),
          Color(0xFFFBEBD6),
          Color(0xFFFFF3E2),
        ], const [
          0,
          0.45,
          1,
        ]),
    );
    // Vệt vữa loang nhẹ như vẽ màu nước.
    final rnd = math.Random(11);
    for (var i = 0; i < 30; i++) {
      final p = Offset(rnd.nextDouble() * 900, 84 + rnd.nextDouble() * 140);
      c.drawOval(
        Rect.fromCenter(center: p, width: 50 + rnd.nextDouble() * 110, height: 14 + rnd.nextDouble() * 22),
        fill(i.isEven ? const Color(0x0CB9805A) : const Color(0x14FFFFFF)),
      );
    }

    // Gạch ốp chân tường xếp so le, vài viên bạc hà điểm xuyết.
    const tilesTop = 236.0;
    c.drawRect(const Rect.fromLTRB(0, tilesTop, 1280, counterTop), fill(const Color(0xFFE6D2BA)));
    const tw = 46.0;
    const th = 20.0;
    var row = 0;
    for (var y = tilesTop + 4; y < counterTop; y += th + 4, row++) {
      var col = 0;
      for (var x = row.isOdd ? -tw / 2 : 2.0; x < 1280; x += tw + 4, col++) {
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tw, th), const Radius.circular(5));
        final accent = (col * 7 + row * 3) % 11 == 0;
        final base = accent ? const Color(0xFFCDE8DA) : ((col + row).isEven ? const Color(0xFFFFF8EE) : const Color(0xFFFBEFE0));
        c.drawRRect(r, fill(shadeOf(base, 0.12)));
        c.drawRRect(r.shift(const Offset(1.5, -1.5)).deflate(0.5), fill(base));
        c.drawLine(Offset(x + 6, y + 4), Offset(x + tw * 0.5, y + 4), softStroke(const Color(0xB3FFFFFF), 2));
      }
    }
    // Nẹp gỗ trên dải gạch.
    const rail = Rect.fromLTRB(0, tilesTop - 6, 1280, tilesTop + 4);
    c.drawRect(rail, fill(const Color(0xFFD5A272)));
    c.drawRect(const Rect.fromLTRB(0, tilesTop - 6, 1280, tilesTop - 3), fill(const Color(0xFFE8BE8E)));
    c.drawLine(rail.topLeft, rail.topRight, stroke(kInk.withValues(alpha: 0.55), 1.5));
    c.drawLine(rail.bottomLeft, rail.bottomRight, stroke(kInk.withValues(alpha: 0.55), 1.5));
  }

  // ------------------------------------------------------------------ Cửa sổ

  static Path _archPath(Rect r, double radius) => Path()
    ..addRRect(RRect.fromRectAndCorners(r, topLeft: Radius.circular(radius), topRight: Radius.circular(radius)));

  void _window(Canvas c) {
    final glassPath = _archPath(_glass, 56);
    final framePath = _archPath(_frame, 70);

    // Rèm sau khung (phần buông xuống hai bên) vẽ sau; trước hết là khung + cảnh.
    paintShadow(c, _frame.bottomCenter.translate(-8, 6), _frame.width * 1.05, 18, alpha: 0.18);
    c.drawPath(framePath.shift(const Offset(-5, 5)), fill(const Color(0x226A4334)));
    c.drawPath(framePath, fill(const Color(0xFFFFF7EA)));
    paintInnerShade(c, framePath, const Offset(5, -5), const Color(0xFFEAD7BE));
    c.drawPath(framePath, stroke(kInk, 3));

    c.save();
    c.clipPath(glassPath);
    _scenery(c);
    c.restore();
    // Bóng khung đổ vào mép kính (trên-trái).
    c.save();
    c.clipPath(glassPath);
    c.drawPath(Path.combine(PathOperation.difference, glassPath, glassPath.shift(const Offset(6, 6))), fill(const Color(0x336A4334)));
    c.restore();

    // Song cửa.
    final mv = RRect.fromRectAndRadius(Rect.fromLTRB(_mullionX - 6, _glass.top - 2, _mullionX + 6, _glass.bottom), const Radius.circular(3));
    final mh = RRect.fromRectAndRadius(Rect.fromLTRB(_glass.left, _mullionY - 5, _glass.right, _mullionY + 5), const Radius.circular(3));
    for (final m in [mh, mv]) {
      c.drawRRect(m.shift(const Offset(-3, 3)), fill(const Color(0x336A4334)));
      c.drawRRect(m, fill(const Color(0xFFFFF7EA)));
      c.drawRRect(m, stroke(kInk, 2));
    }
    // Phản chiếu kính: hai vệt chéo mờ.
    c.save();
    c.clipPath(glassPath);
    for (final (x, w) in [(660.0, 16.0), (686.0, 7.0), (800.0, 12.0)]) {
      final p = Path()
        ..moveTo(x, _glass.top)
        ..lineTo(x + w, _glass.top)
        ..lineTo(x + w - 70, _glass.bottom)
        ..lineTo(x - 70, _glass.bottom)
        ..close();
      c.drawPath(p, fill(const Color(0x30FFFFFF)));
    }
    c.restore();
    c.drawPath(glassPath, stroke(kInk, 2.5));

    _curtains(c);

    // Bậu cửa gỗ + chậu thảo mộc.
    const sill = Rect.fromLTRB(584, 240, 896, 256);
    paintShadow(c, sill.bottomCenter.translate(-10, 6), sill.width, 14, alpha: 0.2);
    final sillR = RRect.fromRectAndRadius(sill, const Radius.circular(4));
    c.drawRRect(sillR, fill(const Color(0xFFC98F5E)));
    c.drawRect(Rect.fromLTRB(sill.left + 2, sill.top + 1, sill.right - 2, sill.top + 6), fill(const Color(0xFFE2AE79)));
    c.drawLine(Offset(sill.left + 30, sill.top + 10), Offset(sill.left + 140, sill.top + 10), softStroke(const Color(0x40804A2E), 1.5));
    c.drawLine(Offset(sill.left + 180, sill.top + 11), Offset(sill.right - 20, sill.top + 9), softStroke(const Color(0x40804A2E), 1.5));
    c.drawRRect(sillR, stroke(kInk, 2.5));
    _herbPot(c, const Offset(650, 241), _Herb.basil);
    _herbPot(c, const Offset(764, 241), _Herb.rosemary, small: true);
    _herbPot(c, const Offset(842, 241), _Herb.daisy);
  }

  /// Cảnh ngoài cửa sổ: trời chiều, mây, biển xa, đồi, cây, mái nhà.
  void _scenery(Canvas c) {
    final g = _glass;
    c.drawRect(
      g,
      Paint()
        ..shader = Gradient.linear(g.topCenter, g.bottomCenter, const [
          Color(0xFF8FCBE6),
          Color(0xFFBFE3EE),
          Color(0xFFFCE6C9),
        ], const [
          0,
          0.5,
          0.82,
        ]),
    );
    // Quầng nắng ở góc trên phải.
    c.drawCircle(
      const Offset(870, 104),
      150,
      Paint()
        ..shader = Gradient.radial(const Offset(870, 104), 150, const [
          Color(0xE6FFF6D6),
          Color(0x66FFE9B8),
          Color(0x00FFE9B8),
        ], const [
          0,
          0.35,
          1,
        ]),
    );
    _cloud(c, const Offset(676, 128), 1.0);
    _cloud(c, const Offset(808, 150), 0.72);
    _cloud(c, const Offset(626, 172), 0.5);

    // Biển xa lấp lánh.
    const seaTop = 190.0;
    c.drawRect(Rect.fromLTRB(g.left, seaTop, g.right, g.bottom), fill(const Color(0xFF86C9DB)));
    c.drawRect(Rect.fromLTRB(g.left, seaTop, g.right, seaTop + 3), fill(const Color(0xFFB9E2EA)));
    for (final (x, y, w) in [(640.0, 196.0, 14.0), (700.0, 200.0, 10.0), (780.0, 195.0, 18.0), (830.0, 201.0, 9.0), (850.0, 194.0, 12.0)]) {
      c.drawLine(Offset(x, y), Offset(x + w, y), softStroke(const Color(0xCCFFFFFF), 2));
    }
    // Đồi xa và đồi gần.
    final far = Path()
      ..moveTo(g.left, 206)
      ..quadraticBezierTo(670, 182, 730, 198)
      ..quadraticBezierTo(780, 210, 820, 204)
      ..quadraticBezierTo(850, 200, g.right, 206)
      ..lineTo(g.right, g.bottom)
      ..lineTo(g.left, g.bottom)
      ..close();
    c.drawPath(far, fill(const Color(0xFF9DCBA2)));
    paintInnerShade(c, far, const Offset(0, 4), const Color(0xFFBEDFAE));
    // Mái nhà nhỏ trên đồi.
    final house = Rect.fromLTWH(782, 196, 18, 12);
    c.drawRect(house, fill(const Color(0xFFFFF4E4)));
    final roof = Path()
      ..moveTo(house.left - 4, house.top + 1)
      ..lineTo(house.center.dx, house.top - 9)
      ..lineTo(house.right + 4, house.top + 1)
      ..close();
    c.drawPath(roof, fill(const Color(0xFFD9786A)));
    c.drawRect(Rect.fromLTWH(house.left + 6, house.top + 4, 5, 5), fill(const Color(0xFF8FB3C9)));
    final near = Path()
      ..moveTo(g.left, 214)
      ..quadraticBezierTo(700, 204, 760, 216)
      ..quadraticBezierTo(820, 228, g.right, 212)
      ..lineTo(g.right, g.bottom)
      ..lineTo(g.left, g.bottom)
      ..close();
    c.drawPath(near, fill(const Color(0xFF7DB874)));
    paintInnerShade(c, near, const Offset(0, 4), const Color(0xFFA6D38A));
    // Cây tán tròn bên trái.
    _tree(c, const Offset(652, 218));
    // Bụi cây nhỏ bên phải.
    for (final (p, r) in [(const Offset(846, 222), 12.0), (const Offset(860, 216), 10.0), (const Offset(832, 226), 8.0)]) {
      c.drawCircle(p, r, fill(const Color(0xFF5E9E62)));
      c.drawCircle(p.translate(2, -3), r * 0.62, fill(const Color(0xFF8CC47A)));
    }
  }

  void _cloud(Canvas c, Offset o, double s) {
    final blobs = [
      (const Offset(-30, 6), 14.0),
      (const Offset(-12, -6), 18.0),
      (const Offset(10, -10), 20.0),
      (const Offset(30, 0), 15.0),
      (const Offset(0, 8), 16.0),
    ];
    final path = Path();
    for (final (d, r) in blobs) {
      path.addOval(Rect.fromCircle(center: o + d * s, radius: r * s));
    }
    c.drawPath(path, fill(const Color(0xFFDCDDF0)));
    c.save();
    c.clipPath(path);
    final lit = Path();
    for (final (d, r) in blobs) {
      lit.addOval(Rect.fromCircle(center: o + d * s + Offset(3 * s, -5 * s), radius: r * s));
    }
    c.drawPath(lit, fill(const Color(0xFFFFFDF6)));
    c.restore();
  }

  void _tree(Canvas c, Offset base) {
    final trunk = Path()
      ..moveTo(base.dx - 4, base.dy + 6)
      ..lineTo(base.dx - 2, base.dy - 26)
      ..lineTo(base.dx + 3, base.dy - 26)
      ..lineTo(base.dx + 5, base.dy + 6)
      ..close();
    c.drawPath(trunk, fill(const Color(0xFF8A5A42)));
    final crown = Path();
    for (final (d, r) in [
      (const Offset(-14, -34), 15.0),
      (const Offset(0, -46), 18.0),
      (const Offset(15, -34), 15.0),
      (const Offset(2, -28), 14.0),
    ]) {
      crown.addOval(Rect.fromCircle(center: base + d, radius: r));
    }
    c.drawPath(crown, fill(const Color(0xFF4F8D5A)));
    c.save();
    c.clipPath(crown);
    for (final (d, r) in [(const Offset(-10, -40), 13.0), (const Offset(5, -52), 15.0), (const Offset(18, -40), 12.0)]) {
      c.drawCircle(base + d + const Offset(3, -2), r, fill(const Color(0xFF6FAE68)));
    }
    for (final (d, r) in [(const Offset(8, -56), 7.0), (const Offset(20, -44), 5.0)]) {
      c.drawCircle(base + d, r, fill(const Color(0xFFA2D184)));
    }
    c.restore();
  }

  void _curtains(Canvas c) {
    // Thanh treo rèm gỗ.
    const rodY = 80.0;
    final rod = RRect.fromRectAndRadius(const Rect.fromLTRB(566, rodY - 4, 914, rodY + 4), const Radius.circular(4));
    c.drawRRect(rod, fill(const Color(0xFFC98F5E)));
    c.drawLine(const Offset(572, rodY - 2), const Offset(908, rodY - 2), softStroke(const Color(0x80FFE7C4), 1.5));
    c.drawRRect(rod, stroke(kInk, 2));
    for (final x in [566.0, 914.0]) {
      c.drawCircle(Offset(x, rodY), 7, fill(const Color(0xFFD9A06A)));
      c.drawCircle(Offset(x + 1.5, rodY - 2), 2.5, fill(const Color(0x99FFF1DA)));
      c.drawCircle(Offset(x, rodY), 7, stroke(kInk, 2));
    }
    // Rèm vải kem viền dâu, buộc gọn hai bên.
    for (final side in [-1.0, 1.0]) {
      final edge = side < 0 ? 576.0 : 904.0; // mép ngoài
      final inner = side < 0 ? 636.0 : 844.0; // mép trong ở thanh treo
      final tieY = 176.0;
      final tieX = side < 0 ? 600.0 : 880.0;
      final path = Path()
        ..moveTo(edge, rodY + 2)
        ..lineTo(inner, rodY + 2)
        ..quadraticBezierTo(inner - side * 8, 140, tieX + side * 4, tieY)
        ..quadraticBezierTo(tieX - side * 18, 210, tieX - side * 2, 238)
        ..lineTo(edge - side * 2, 238)
        ..quadraticBezierTo(edge + side * 2, 200, tieX + side * 14, tieY + 2)
        ..quadraticBezierTo(edge - side * 4, 130, edge, rodY + 2)
        ..close();
      c.drawPath(path, fill(const Color(0xFFFFF1E2)));
      paintInnerShade(c, path, Offset(side * -6, -2), const Color(0xFFF0D9C4));
      // Nếp gấp.
      for (final k in [0.3, 0.62]) {
        final x0 = edge + (inner - edge) * k;
        c.drawPath(
          Path()
            ..moveTo(x0, rodY + 6)
            ..quadraticBezierTo(x0 - side * 4, 130, tieX + side * (10 - 8 * k), tieY - 4),
          softStroke(const Color(0x66C9A688), 1.5),
        );
      }
      // Viền dâu dưới gấu.
      c.save();
      c.clipPath(path);
      c.drawRect(const Rect.fromLTRB(560, 230, 920, 240), fill(const Color(0xFFF2A9B9)));
      c.restore();
      c.drawPath(path, stroke(kInk, 2));
      // Dây buộc.
      final tie = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(tieX + side * 6, tieY + 1), width: 30, height: 9), const Radius.circular(4));
      c.drawRRect(tie, fill(AppColors.strawberry));
      c.drawRRect(tie, stroke(kInk, 1.8));
    }
  }

  void _herbPot(Canvas c, Offset base, _Herb herb, {bool small = false}) {
    final w = small ? 30.0 : 36.0;
    final h = small ? 24.0 : 28.0;
    // Lá trước, chậu đè lên chân lá.
    switch (herb) {
      case _Herb.basil:
        for (final (d, a, s) in [
          (const Offset(-12, -34), -0.7, 1.0),
          (const Offset(12, -36), 0.6, 1.0),
          (const Offset(-4, -48), -0.2, 1.1),
          (const Offset(8, -52), 0.3, 0.9),
          (const Offset(-16, -46), -1.0, 0.8),
          (const Offset(0, -38), 0.0, 0.9),
        ]) {
          _leaf(c, base + d, a, 13 * s, 9 * s);
        }
      case _Herb.rosemary:
        for (final (dx, top, lean) in [(-6.0, -64.0, -0.25), (0.0, -72.0, 0.0), (7.0, -60.0, 0.3), (-11.0, -50.0, -0.5)]) {
          final p0 = base + Offset(dx * 0.4, -h + 2);
          final p1 = base + Offset(dx + lean * 30, top);
          c.drawLine(p0, p1, softStroke(const Color(0xFF6B8A52), 2));
          for (var i = 1; i < 7; i++) {
            final p = Offset.lerp(p0, p1, i / 7)!;
            c.drawLine(p, p + Offset(-5, -3), softStroke(const Color(0xFF5E9466), 2.2));
            c.drawLine(p, p + Offset(5, -3), softStroke(const Color(0xFF7DB47A), 2.2));
          }
        }
      case _Herb.daisy:
        for (final (d, a) in [(const Offset(-10, -34), -0.9), (const Offset(10, -34), 0.9), (const Offset(0, -40), 0.1)]) {
          _leaf(c, base + d, a, 12, 6);
        }
        for (final (d, r) in [(const Offset(-8, -58), 7.0), (const Offset(9, -64), 8.0), (const Offset(2, -48), 6.0)]) {
          final f = base + d;
          c.drawLine(base + Offset(d.dx * 0.3, -h), f, softStroke(const Color(0xFF6B8A52), 1.6));
          for (var i = 0; i < 7; i++) {
            final a = i * math.pi * 2 / 7;
            c.drawOval(
              Rect.fromCenter(center: f + Offset(math.cos(a), math.sin(a)) * r * 0.75, width: r * 0.9, height: r * 0.9),
              fill(const Color(0xFFFFFDF6)),
            );
          }
          c.drawCircle(f, r * 0.42, fill(AppColors.butter));
          c.drawCircle(f, r * 0.42, stroke(const Color(0xFFD9A441), 1));
        }
    }
    final pot = Path()
      ..moveTo(base.dx - w / 2, base.dy - h)
      ..lineTo(base.dx + w / 2, base.dy - h)
      ..lineTo(base.dx + w * 0.36, base.dy)
      ..lineTo(base.dx - w * 0.36, base.dy)
      ..close();
    c.drawPath(pot, fill(const Color(0xFFE39A73)));
    paintInnerShade(c, pot, const Offset(5, 0), const Color(0xFFC97B58));
    c.drawLine(Offset(base.dx + w * 0.22, base.dy - h + 9), Offset(base.dx + w * 0.16, base.dy - 4), softStroke(const Color(0x80FFD9BE), 2));
    c.drawPath(pot, stroke(kInk, 2));
    final rim = RRect.fromRectAndRadius(Rect.fromLTRB(base.dx - w / 2 - 3, base.dy - h - 4, base.dx + w / 2 + 3, base.dy - h + 5), const Radius.circular(3));
    c.drawRRect(rim, fill(const Color(0xFFEDAA84)));
    c.drawRRect(rim, stroke(kInk, 2));
  }

  /// Lá thảo mộc hình giọt, gân giữa, nửa dưới-trái sẫm hơn.
  void _leaf(Canvas c, Offset at, double angle, double len, double wid) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    final leaf = Path()
      ..moveTo(0, len * 0.5)
      ..quadraticBezierTo(wid, 0, 0, -len * 0.5)
      ..quadraticBezierTo(-wid, 0, 0, len * 0.5)
      ..close();
    c.drawPath(leaf, fill(const Color(0xFF7CBB6E)));
    c.save();
    c.clipPath(leaf);
    c.drawRect(Rect.fromLTRB(-wid, -len, 0, len), fill(const Color(0xFF5E9E62)));
    c.restore();
    c.drawLine(Offset(0, len * 0.4), Offset(0, -len * 0.35), softStroke(const Color(0x66E9F5D8), 1));
    c.drawPath(leaf, stroke(const Color(0xFF3F6B45), 1.4));
    c.restore();
  }

  // ------------------------------------------------------------------ Kệ gỗ

  void _shelf(Canvas c) {
    const y = 204.0;
    const board = Rect.fromLTRB(24, y, 566, y + 16);
    // Giá đỡ uốn.
    for (final x in [78.0, 512.0]) {
      final b = Path()
        ..moveTo(x - 8, board.bottom)
        ..lineTo(x + 8, board.bottom)
        ..lineTo(x + 8, board.bottom + 8)
        ..quadraticBezierTo(x + 6, board.bottom + 16, x - 8, board.bottom + 20)
        ..close();
      c.drawPath(b, fill(const Color(0xFFB87E52)));
      c.drawPath(b, stroke(kInk, 2));
    }
    paintShadow(c, Offset(board.center.dx - 8, board.bottom + 8), board.width, 14, alpha: 0.18);

    _jar(c, const Offset(66, y), 56, 78, _JarFill.flour);
    _jar(c, const Offset(128, y), 46, 60, _JarFill.sugar);
    _crock(c, const Offset(190, y));
    _jar(c, const Offset(250, y), 44, 52, _JarFill.strawberryJam);
    _jar(c, const Offset(302, y), 40, 46, _JarFill.apricotJam);
    _books(c, const Offset(382, y));
    _ivy(c, const Offset(456, y));
    _jar(c, const Offset(528, y), 36, 40, _JarFill.honey);

    // Mặt kệ: mặt trên sáng, cạnh trước có vân.
    final r = RRect.fromRectAndRadius(board, const Radius.circular(4));
    c.drawRRect(r, fill(const Color(0xFFC08552)));
    c.drawRect(Rect.fromLTRB(board.left + 1, board.top + 1, board.right - 1, board.top + 6), fill(const Color(0xFFE2AE79)));
    for (final (x0, x1, dy) in [(40.0, 170.0, 10.0), (210.0, 330.0, 12.0), (360.0, 540.0, 10.5)]) {
      c.drawPath(
        Path()
          ..moveTo(x0, board.top + dy)
          ..quadraticBezierTo((x0 + x1) / 2, board.top + dy + 2.5, x1, board.top + dy - 0.5),
        softStroke(const Color(0x55804A2E), 1.4),
      );
    }
    c.drawRRect(r, stroke(kInk, 2.5));
    // Lá thường xuân buông qua mép kệ.
    for (final (d, a) in [(const Offset(-10, 22), 0.4), (const Offset(-16, 38), -0.3), (const Offset(-12, 54), 0.5), (const Offset(6, 20), -0.4), (const Offset(10, 36), 0.3)]) {
      _leaf(c, Offset(456, y) + d, a, 14, 11);
    }
    c.drawPath(
      Path()
        ..moveTo(450, y + 2)
        ..quadraticBezierTo(436, y + 30, 444, y + 60),
      softStroke(const Color(0xFF5E7A44), 1.6),
    );
  }

  void _jar(Canvas c, Offset base, double w, double h, _JarFill kind) {
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h),
      topLeft: const Radius.circular(9),
      topRight: const Radius.circular(9),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );
    final glass = Path()..addRRect(body);
    c.drawRRect(body, fill(const Color(0xB3F4FBF8)));
    // Phần đựng bên trong.
    final fillTop = base.dy - h * switch (kind) {
      _JarFill.flour => 0.7,
      _JarFill.sugar => 0.72,
      _JarFill.honey => 0.66,
      _ => 0.78,
    };
    final content = switch (kind) {
      _JarFill.flour => const Color(0xFFFFFCF4),
      _JarFill.sugar => const Color(0xFFFFFFFF),
      _JarFill.strawberryJam => const Color(0xFFD9475A),
      _JarFill.apricotJam => const Color(0xFFF2A541),
      _JarFill.honey => const Color(0xFFF2B640),
    };
    c.save();
    c.clipPath(glass);
    final inside = Path()
      ..moveTo(base.dx - w / 2, fillTop + 3)
      ..quadraticBezierTo(base.dx - w * 0.2, fillTop - 4, base.dx, fillTop + 1)
      ..quadraticBezierTo(base.dx + w * 0.25, fillTop + 5, base.dx + w / 2, fillTop - 1)
      ..lineTo(base.dx + w / 2, base.dy)
      ..lineTo(base.dx - w / 2, base.dy)
      ..close();
    c.drawPath(inside, fill(content));
    c.drawRect(Rect.fromLTRB(base.dx - w / 2, fillTop - 6, base.dx - w / 2 + 7, base.dy), fill(shadeOf(content, 0.16)));
    if (kind == _JarFill.sugar) {
      for (var i = 0; i < 6; i++) {
        final cube = Rect.fromLTWH(base.dx - w / 2 + 4 + (i % 3) * 13, fillTop + 2 + (i ~/ 3) * 13, 11, 11);
        c.drawRRect(RRect.fromRectAndRadius(cube, const Radius.circular(2)), stroke(const Color(0x66B9A08A), 1.2));
      }
    } else if (kind == _JarFill.strawberryJam) {
      for (var i = 0; i < 7; i++) {
        c.drawCircle(Offset(base.dx - w / 2 + 7 + (i * 11) % (w - 10), fillTop + 8 + (i * 7) % (h * 0.6)), 1.4, fill(const Color(0xFFFFD27A)));
      }
    }
    // Vệt sáng kính bên phải.
    c.drawLine(Offset(base.dx + w / 2 - 8, base.dy - h + 12), Offset(base.dx + w / 2 - 8, base.dy - 10), softStroke(const Color(0xCCFFFFFF), 3.5));
    c.drawLine(Offset(base.dx + w / 2 - 15, base.dy - h + 14), Offset(base.dx + w / 2 - 15, base.dy - h + 24), softStroke(const Color(0x99FFFFFF), 2));
    c.restore();
    c.drawRRect(body, stroke(kInk, 2.2));

    // Nhãn giấy vẽ tay (không chữ: hình minh hoạ nhỏ).
    final label = Rect.fromCenter(center: Offset(base.dx, base.dy - h * 0.42), width: w * 0.66, height: math.min(22, h * 0.36));
    final lp = Path()
      ..moveTo(label.left, label.top + 1)
      ..quadraticBezierTo(label.center.dx, label.top - 2, label.right, label.top + 1)
      ..lineTo(label.right - 1, label.bottom)
      ..quadraticBezierTo(label.center.dx, label.bottom + 2, label.left + 1, label.bottom)
      ..close();
    c.drawPath(lp, fill(const Color(0xFFFFF6E6)));
    c.drawPath(lp, stroke(kInk.withValues(alpha: 0.8), 1.3));
    final lc = label.center;
    final s = label.height;
    switch (kind) {
      case _JarFill.flour:
        // Bông lúa mì.
        c.drawLine(lc.translate(0, s * 0.35), lc.translate(0, -s * 0.38), softStroke(const Color(0xFFC9964F), 1.4));
        for (var i = 0; i < 3; i++) {
          final y = -s * 0.25 + i * s * 0.2;
          c.drawOval(Rect.fromCenter(center: lc.translate(-2.5, y), width: 4, height: 6), fill(const Color(0xFFE2B865)));
          c.drawOval(Rect.fromCenter(center: lc.translate(2.5, y), width: 4, height: 6), fill(const Color(0xFFE2B865)));
        }
      case _JarFill.sugar:
        final cube = Rect.fromCenter(center: lc, width: s * 0.5, height: s * 0.5);
        c.drawRRect(RRect.fromRectAndRadius(cube, const Radius.circular(2)), fill(const Color(0xFFFFFFFF)));
        c.drawRRect(RRect.fromRectAndRadius(cube, const Radius.circular(2)), stroke(const Color(0xFF8FB3C9), 1.3));
      case _JarFill.strawberryJam:
        paintHeart(c, lc.translate(0, 1), s * 0.62, AppColors.strawberry);
      case _JarFill.apricotJam:
        c.drawCircle(lc.translate(0, 1), s * 0.24, fill(const Color(0xFFF2A541)));
        _leafTiny(c, lc.translate(3, -s * 0.24));
      case _JarFill.honey:
        c.drawCircle(lc, s * 0.2, fill(AppColors.butter));
        for (final d in [const Offset(-1, 0), const Offset(1, 0)]) {
          c.drawOval(Rect.fromCenter(center: lc + Offset(d.dx * s * 0.22, -s * 0.12), width: s * 0.28, height: s * 0.18), fill(const Color(0xCCFFFFFF)));
        }
    }

    // Nắp: nút bần cho bột, nắp thiếc cho đường/mật ong, vải kẻ ô buộc dây cho mứt.
    final lidRect = Rect.fromLTRB(base.dx - w / 2 - 2, base.dy - h - 9, base.dx + w / 2 + 2, base.dy - h + 3);
    switch (kind) {
      case _JarFill.flour:
        final cork = RRect.fromRectAndRadius(Rect.fromLTRB(base.dx - w * 0.36, base.dy - h - 12, base.dx + w * 0.36, base.dy - h + 3), const Radius.circular(4));
        c.drawRRect(cork, fill(const Color(0xFFD9B38A)));
        for (var i = 0; i < 5; i++) {
          c.drawCircle(Offset(cork.left + 6 + i * (cork.width - 12) / 4, cork.top + 5 + (i % 2) * 4), 1.2, fill(const Color(0xFFB58A60)));
        }
        c.drawRRect(cork, stroke(kInk, 2));
      case _JarFill.sugar || _JarFill.honey:
        final lid = RRect.fromRectAndRadius(lidRect, const Radius.circular(4));
        c.drawRRect(lid, fill(const Color(0xFFC9CFD6)));
        c.drawRect(Rect.fromLTRB(lidRect.left + 2, lidRect.bottom - 4, lidRect.right - 2, lidRect.bottom - 1), fill(const Color(0xFFA3AAB4)));
        c.drawLine(Offset(lidRect.right - 10, lidRect.top + 3), Offset(lidRect.right - 5, lidRect.top + 3), softStroke(const Color(0xFFFFFFFF), 2));
        c.drawRRect(lid, stroke(kInk, 2));
      case _JarFill.strawberryJam || _JarFill.apricotJam:
        final cloth = kind == _JarFill.strawberryJam ? AppColors.strawberry : AppColors.mint;
        final cap = Path()
          ..moveTo(base.dx - w / 2 - 5, base.dy - h + 8)
          ..quadraticBezierTo(base.dx - w / 2 - 2, base.dy - h - 12, base.dx, base.dy - h - 13)
          ..quadraticBezierTo(base.dx + w / 2 + 2, base.dy - h - 12, base.dx + w / 2 + 5, base.dy - h + 8)
          ..lineTo(base.dx + w / 2 - 4, base.dy - h + 3)
          ..lineTo(base.dx + w / 4, base.dy - h + 9)
          ..lineTo(base.dx, base.dy - h + 3)
          ..lineTo(base.dx - w / 4, base.dy - h + 9)
          ..lineTo(base.dx - w / 2 + 4, base.dy - h + 3)
          ..close();
        c.drawPath(cap, fill(const Color(0xFFFFF8EE)));
        c.save();
        c.clipPath(cap);
        final bandPaint = fill(cloth.withValues(alpha: 0.55));
        for (var x = base.dx - w / 2 - 6; x < base.dx + w / 2 + 6; x += 8) {
          c.drawRect(Rect.fromLTWH(x, base.dy - h - 14, 4, 24), bandPaint);
        }
        for (var yy = base.dy - h - 14; yy < base.dy - h + 10; yy += 8) {
          c.drawRect(Rect.fromLTWH(base.dx - w / 2 - 6, yy, w + 12, 4), bandPaint);
        }
        c.restore();
        c.drawPath(cap, stroke(kInk, 1.8));
        c.drawLine(Offset(base.dx - w / 2 - 1, base.dy - h + 1), Offset(base.dx + w / 2 + 1, base.dy - h + 1), softStroke(const Color(0xFFB9805A), 2.2));
    }
  }

  void _leafTiny(Canvas c, Offset at) {
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..quadraticBezierTo(at.dx + 5, at.dy - 4, at.dx + 7, at.dy - 1)
      ..quadraticBezierTo(at.dx + 4, at.dy + 2, at.dx, at.dy)
      ..close();
    c.drawPath(p, fill(const Color(0xFF6FAE68)));
  }

  /// Hũ gốm cắm muỗng gỗ và phới dẹt.
  void _crock(Canvas c, Offset base) {
    // Muỗng gỗ.
    c.drawLine(base.translate(-6, -40), base.translate(-16, -86), softStroke(kInk, 7));
    c.drawLine(base.translate(-6, -40), base.translate(-16, -86), softStroke(const Color(0xFFD9A86C), 4));
    final spoon = Rect.fromCenter(center: base.translate(-17, -92), width: 13, height: 18);
    c.drawOval(spoon, fill(const Color(0xFFD9A86C)));
    c.drawOval(spoon, stroke(kInk, 1.8));
    // Phới dẹt bạc hà.
    c.drawLine(base.translate(6, -40), base.translate(14, -80), softStroke(kInk, 7));
    c.drawLine(base.translate(6, -40), base.translate(14, -80), softStroke(const Color(0xFFF2F2EE), 4));
    final spat = RRect.fromRectAndRadius(Rect.fromCenter(center: base.translate(16, -88), width: 16, height: 18), const Radius.circular(5));
    c.drawRRect(spat, fill(AppColors.mint));
    c.drawRRect(spat, stroke(kInk, 1.8));
    // Hũ.
    final crock = Path()
      ..moveTo(base.dx - 20, base.dy - 46)
      ..quadraticBezierTo(base.dx - 26, base.dy - 20, base.dx - 18, base.dy)
      ..lineTo(base.dx + 18, base.dy)
      ..quadraticBezierTo(base.dx + 26, base.dy - 20, base.dx + 20, base.dy - 46)
      ..close();
    c.drawPath(crock, fill(const Color(0xFFF6EBDA)));
    paintInnerShade(c, crock, const Offset(6, -2), const Color(0xFFE2D0B8));
    c.save();
    c.clipPath(crock);
    c.drawRect(Rect.fromLTRB(base.dx - 30, base.dy - 34, base.dx + 30, base.dy - 29), fill(const Color(0xFF8FB3C9)));
    c.drawRect(Rect.fromLTRB(base.dx - 30, base.dy - 25, base.dx + 30, base.dy - 23), fill(const Color(0xFF8FB3C9)));
    c.restore();
    c.drawLine(base.translate(12, -40), base.translate(14, -10), softStroke(const Color(0xB3FFFFFF), 2.5));
    c.drawPath(crock, stroke(kInk, 2));
  }

  /// Chồng sách công thức nằm (gáy không chữ).
  void _books(Canvas c, Offset base) {
    for (final (rect, color) in [
      (Rect.fromLTRB(base.dx - 44, base.dy - 18, base.dx + 42, base.dy), const Color(0xFF9DBFA5)),
      (Rect.fromLTRB(base.dx - 38, base.dy - 34, base.dx + 36, base.dy - 18), const Color(0xFFE7A7A2)),
      (Rect.fromLTRB(base.dx - 30, base.dy - 46, base.dx + 32, base.dy - 34), const Color(0xFFF2D49A)),
    ]) {
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      c.drawRRect(r, fill(color));
      // Mép giấy bên phải.
      c.drawRect(Rect.fromLTRB(rect.right - 7, rect.top + 3, rect.right - 2, rect.bottom - 3), fill(const Color(0xFFFFF8EC)));
      c.drawRect(Rect.fromLTRB(rect.left, rect.bottom - 4, rect.right - 7, rect.bottom), fill(shadeOf(color, 0.2)));
      // Dải trang trí trên gáy.
      c.drawLine(Offset(rect.left + 10, rect.top + 2), Offset(rect.left + 10, rect.bottom - 2), softStroke(lightOf(color, 0.5), 2));
      c.drawLine(Offset(rect.left + 16, rect.top + 2), Offset(rect.left + 16, rect.bottom - 2), softStroke(lightOf(color, 0.5), 2));
      c.drawRRect(r, stroke(kInk, 2));
    }
    // Tách trà nhỏ trên chồng sách.
    final cup = Path()
      ..moveTo(base.dx - 10, base.dy - 60)
      ..lineTo(base.dx + 10, base.dy - 60)
      ..quadraticBezierTo(base.dx + 9, base.dy - 46, base.dx, base.dy - 46)
      ..quadraticBezierTo(base.dx - 9, base.dy - 46, base.dx - 10, base.dy - 60)
      ..close();
    c.drawCircle(Offset(base.dx + 12, base.dy - 54), 4.5, stroke(kInk, 2));
    c.drawPath(cup, fill(const Color(0xFFFFFBF2)));
    c.drawRect(Rect.fromLTRB(base.dx - 10, base.dy - 56, base.dx + 10, base.dy - 53), fill(AppColors.strawberry));
    c.drawPath(cup, stroke(kInk, 2));
    // Hơi trà.
    c.drawPath(
      Path()
        ..moveTo(base.dx - 2, base.dy - 64)
        ..quadraticBezierTo(base.dx - 7, base.dy - 72, base.dx - 1, base.dy - 78)
        ..quadraticBezierTo(base.dx + 5, base.dy - 84, base.dx, base.dy - 90),
      softStroke(const Color(0x99FFFFFF), 2.5),
    );
  }

  /// Chậu thường xuân (lá buông vẽ sau mặt kệ).
  void _ivy(Canvas c, Offset base) {
    for (final (d, a) in [(const Offset(-12, -34), -0.8), (const Offset(10, -36), 0.7), (const Offset(0, -44), 0.0), (const Offset(-4, -30), -0.2)]) {
      _leaf(c, base + d, a, 15, 12);
    }
    final pot = Path()
      ..moveTo(base.dx - 17, base.dy - 26)
      ..lineTo(base.dx + 17, base.dy - 26)
      ..lineTo(base.dx + 13, base.dy)
      ..lineTo(base.dx - 13, base.dy)
      ..close();
    c.drawPath(pot, fill(const Color(0xFFF7F0E4)));
    paintInnerShade(c, pot, const Offset(5, 0), const Color(0xFFE3D5C0));
    c.drawLine(Offset(base.dx - 14, base.dy - 14), Offset(base.dx + 14, base.dy - 14), softStroke(AppColors.strawberry, 3));
    c.drawPath(pot, stroke(kInk, 2));
  }

  // ------------------------------------------------------------------ Dây cờ vải

  void _bunting(Canvas c) {
    const x0 = 14.0;
    const x1 = 560.0;
    const y0 = 78.0;
    const sag = 18.0;
    double yAt(double t) => y0 + 4 * sag * t * (1 - t);
    final string = Path()..moveTo(x0, y0);
    for (var i = 1; i <= 24; i++) {
      final t = i / 24;
      string.lineTo(x0 + (x1 - x0) * t, yAt(t));
    }
    c.drawPath(string, softStroke(const Color(0xFF9C7A62), 1.8));
    for (final x in [x0, x1]) {
      c.drawCircle(Offset(x, y0), 3.5, fill(const Color(0xFFC98F5E)));
      c.drawCircle(Offset(x, y0), 3.5, stroke(kInk, 1.5));
    }
    const colors = [AppColors.strawberry, AppColors.mint, AppColors.butter, Color(0xFFFFF4E6), Color(0xFFC9B8E0)];
    const n = 12;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final x = x0 + (x1 - x0) * t;
      final y = yAt(t);
      final slope = math.atan2(4 * sag * (1 - 2 * t), x1 - x0);
      final color = colors[i % colors.length];
      c.save();
      c.translate(x, y);
      c.rotate(slope + math.sin(i * 1.7) * 0.06);
      const w = 13.0;
      const h = 26.0;
      final flag = Path()
        ..moveTo(-w, 0)
        ..lineTo(w, 0)
        ..quadraticBezierTo(w * 0.4, h * 0.55, 0, h)
        ..quadraticBezierTo(-w * 0.5, h * 0.5, -w, 0)
        ..close();
      c.drawPath(flag, fill(color));
      // Bóng mềm nửa trái + hoạ tiết vải.
      c.save();
      c.clipPath(flag);
      c.drawRect(const Rect.fromLTRB(-w, 0, -w * 0.2, h), fill(shadeOf(color, 0.14)));
      switch (i % 3) {
        case 0:
          for (final d in const [Offset(-6, 6), Offset(5, 7), Offset(0, 15), Offset(-1, 23)]) {
            c.drawCircle(d, 2, fill(const Color(0xB3FFFFFF)));
          }
        case 1:
          c.drawLine(const Offset(-w, 9), const Offset(w, 9), softStroke(const Color(0x99FFFFFF), 3));
        default:
          c.drawCircle(const Offset(0, 10), 4, fill(color == const Color(0xFFFFF4E6) ? AppColors.strawberry : const Color(0xB3FFFFFF)));
      }
      c.restore();
      // Đường may.
      final stitch = softStroke(kInk.withValues(alpha: 0.45), 1);
      for (var k = 0; k < 5; k++) {
        final a = Offset.lerp(const Offset(-w + 4, 3), const Offset(0, h - 6), k / 5 + 0.04)!;
        final b = Offset.lerp(const Offset(-w + 4, 3), const Offset(0, h - 6), k / 5 + 0.12)!;
        c.drawLine(a, b, stitch);
        final a2 = Offset.lerp(const Offset(w - 4, 3), const Offset(0, h - 6), k / 5 + 0.04)!;
        final b2 = Offset.lerp(const Offset(w - 4, 3), const Offset(0, h - 6), k / 5 + 0.12)!;
        c.drawLine(a2, b2, stitch);
      }
      c.drawPath(flag, stroke(kInk, 1.6));
      c.restore();
    }
  }

  // ------------------------------------------------------------------ Mặt bàn gỗ

  void _counter(Canvas c) {
    const top = Rect.fromLTWH(0, counterTop, 1280, 720 - counterTop);
    c.drawRect(
      top,
      Paint()
        ..shader = Gradient.linear(top.topCenter, top.bottomCenter, const [
          Color(0xFFE8C190),
          Color(0xFFF0CFA2),
          Color(0xFFEDCA9A),
        ], const [
          0,
          0.35,
          1,
        ]),
    );
    final rnd = math.Random(3);
    // Ván gỗ ngang, mỗi tấm hơi khác tông; mạch ván có mép sáng.
    const plank = 68.0;
    var row = 0;
    for (var y = counterTop + 14; y < 720; y += plank, row++) {
      final tone = row % 3;
      if (tone != 1) {
        c.drawRect(Rect.fromLTWH(0, y, 1280, plank), fill(tone == 0 ? const Color(0x12FFF4DA) : const Color(0x14A86A3C)));
      }
      c.drawLine(Offset(0, y), Offset(1280, y), stroke(const Color(0x547A4A34), 2));
      c.drawLine(Offset(0, y + 2), Offset(1280, y + 2), stroke(const Color(0x40FFF1D6), 1.5));
      // Mối nối đầu ván.
      for (var j = 0; j < 2; j++) {
        final x = 160.0 + rnd.nextDouble() * 960 + j * 120;
        c.drawLine(Offset(x, y + 2), Offset(x, y + plank), stroke(const Color(0x4D7A4A34), 2));
      }
      // Vân gỗ lượn sóng.
      for (var k = 0; k < 9; k++) {
        final x = rnd.nextDouble() * 1240 - 40;
        final yy = y + 10 + rnd.nextDouble() * (plank - 20);
        final len = 120 + rnd.nextDouble() * 180;
        final amp = 2 + rnd.nextDouble() * 3;
        final path = Path()..moveTo(x, yy);
        for (var s = 1; s <= 4; s++) {
          final up = (s + k).isEven ? -amp : amp;
          path.quadraticBezierTo(x + len * (s - 0.5) / 4, yy + up, x + len * s / 4, yy + up * 0.2);
        }
        c.drawPath(path, softStroke(k.isEven ? const Color(0x33A0663E) : const Color(0x22A0663E), k.isEven ? 1.6 : 1.2));
      }
      // Mắt gỗ.
      if (row % 2 == 0) {
        final kc = Offset(80 + rnd.nextDouble() * 1100, y + plank * 0.5);
        for (var ring = 0; ring < 3; ring++) {
          c.drawOval(Rect.fromCenter(center: kc, width: 14.0 + ring * 12, height: 6.0 + ring * 5), stroke(Color.fromRGBO(160, 102, 62, 0.28 - ring * 0.07), 1.4));
        }
      }
    }
    // Mép bàn sát tường: dải gỗ sẫm + bóng tường đổ xuống.
    c.drawRect(const Rect.fromLTWH(0, counterTop, 1280, 14), fill(const Color(0xFFD7A776)));
    c.drawRect(const Rect.fromLTWH(0, counterTop + 10, 1280, 4), fill(const Color(0xFFC79563)));
    c.drawRect(
      const Rect.fromLTWH(0, counterTop + 14, 1280, 26),
      Paint()
        ..shader = Gradient.linear(const Offset(0, counterTop + 14), const Offset(0, counterTop + 40), const [
          Color(0x2E7A4A34),
          Color(0x007A4A34),
        ]),
    );
    c.drawLine(const Offset(0, counterTop), const Offset(1280, counterTop), stroke(kInk, 2.5));
  }

  // ------------------------------------------------------------------ Nắng chiều

  void _sunlight(Canvas c) {
    // Dải nắng xiên từ cửa sổ xuống trái, mờ dần.
    const shift = 300.0;
    const drop = 470.0;
    // Gộp hai dải vào một path để chỉ có một lần làm mờ.
    final beams = Path();
    for (final (l, r) in [(_glass.left + 6, _mullionX - 6), (_mullionX + 6, _glass.right - 6)]) {
      beams
        ..moveTo(l, _glass.top + 30)
        ..lineTo(r, _glass.top + 30)
        ..lineTo(r - shift, _glass.top + drop)
        ..lineTo(l - shift - 40, _glass.top + drop)
        ..close();
    }
    c.drawPath(
      beams,
      Paint()
        ..shader = Gradient.linear(Offset(_glass.right, _glass.top), Offset(_glass.right - shift * 0.9, _glass.top + drop), const [
          Color(0x66FFF1C4),
          Color(0x2BFFF1C4),
          Color(0x00FFF1C4),
        ], const [
          0,
          0.5,
          1,
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Vệt nắng hình ô cửa in trên mặt bàn.
    final patches = Path();
    const skew = 0.7;
    for (final (x0, x1, y0, y1) in [
      (520.0, 620.0, 330.0, 392.0),
      (640.0, 740.0, 330.0, 392.0),
      (476.0, 576.0, 404.0, 466.0),
      (596.0, 696.0, 404.0, 466.0),
    ]) {
      patches
        ..moveTo(x0, y0)
        ..lineTo(x1, y0)
        ..lineTo(x1 - (y1 - y0) * skew, y1)
        ..lineTo(x0 - (y1 - y0) * skew, y1)
        ..close();
    }
    c.drawPath(
      patches,
      Paint()
        ..color = const Color(0x45FFF3C8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Ấm nắng tổng thể góc trên phải.
    c.drawRect(
      const Rect.fromLTWH(0, 72, 1280, 648),
      Paint()
        ..shader = Gradient.radial(const Offset(900, 120), 760, const [
          Color(0x1FFFE2A8),
          Color(0x00FFE2A8),
        ]),
    );
  }

  // ------------------------------------------------------------------ Vết bột, khăn

  void _flour(Canvas c) {
    final soft = Paint()
      ..color = const Color(0x8CFFFDF6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final dust = Path();
    for (final (p, w, h) in [
      (const Offset(118, 652), 120.0, 46.0),
      (const Offset(176, 684), 80.0, 30.0),
      (const Offset(70, 690), 60.0, 26.0),
      (const Offset(872, 674), 90.0, 34.0),
      (const Offset(906, 646), 46.0, 20.0),
    ]) {
      dust.addOval(Rect.fromCenter(center: p, width: w, height: h));
    }
    c.drawPath(dust, soft);
    final rnd = math.Random(21);
    final speck = fill(const Color(0xCCFFFFFF));
    for (var i = 0; i < 60; i++) {
      final left = i < 38;
      final cx = left ? 120.0 : 880.0;
      final cy = left ? 666.0 : 662.0;
      final p = Offset(cx + (rnd.nextDouble() - 0.5) * (left ? 220 : 130), cy + (rnd.nextDouble() - 0.5) * 70);
      c.drawCircle(p, 0.8 + rnd.nextDouble() * 1.8, speck);
    }
    // Vệt quệt ngón tay qua bột.
    c.drawPath(
      Path()
        ..moveTo(78, 646)
        ..quadraticBezierTo(120, 636, 168, 650),
      softStroke(const Color(0x1AB9805A), 6),
    );
  }

  /// Khăn kẻ ô dâu-kem gấp đôi, nằm chéo trên bàn.
  void _towel(Canvas c, Offset center, double angle) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    const r = Rect.fromLTWH(-54, -66, 108, 132);
    paintShadow(c, const Offset(-6, 6), r.width + 14, r.height + 8, alpha: 0.16);
    final cloth = Path()
      ..moveTo(r.left, r.top + 2)
      ..quadraticBezierTo(r.center.dx, r.top - 3, r.right, r.top + 1)
      ..lineTo(r.right + 2, r.bottom - 1)
      ..quadraticBezierTo(r.center.dx, r.bottom + 3, r.left - 1, r.bottom)
      ..close();
    c.drawPath(cloth, fill(const Color(0xFFFFF6EC)));
    c.save();
    c.clipPath(cloth);
    final band = fill(const Color(0x66E98AA2));
    for (var x = r.left - 2; x < r.right; x += 18) {
      c.drawRect(Rect.fromLTWH(x, r.top - 4, 9, r.height + 8), band);
    }
    for (var y = r.top - 2; y < r.bottom; y += 18) {
      c.drawRect(Rect.fromLTWH(r.left - 4, y, r.width + 8, 9), band);
    }
    // Nếp gấp: nửa trên là mép gấp, có bóng mềm dưới nếp.
    c.drawRect(Rect.fromLTRB(r.left - 4, -8, r.right + 4, 2), fill(const Color(0x22804A3A)));
    c.drawLine(Offset(r.left, -9), Offset(r.right, -9), softStroke(const Color(0x80FFFFFF), 2));
    // Bóng mềm cạnh trái + sáng cạnh phải.
    c.drawRect(Rect.fromLTRB(r.left - 4, r.top - 4, r.left + 10, r.bottom + 4), fill(const Color(0x1F804A3A)));
    c.drawRect(Rect.fromLTRB(r.right - 8, r.top - 4, r.right + 4, r.bottom + 4), fill(const Color(0x26FFFFFF)));
    c.restore();
    // Đường may viền.
    final stitch = softStroke(const Color(0x99C2687E), 1.2);
    for (var x = r.left + 6; x < r.right - 6; x += 9) {
      c.drawLine(Offset(x, r.top + 5), Offset(x + 4, r.top + 5), stitch);
    }
    c.drawPath(cloth, stroke(kInk, 2.2));
    // Tua vải ở mép dưới.
    for (var x = r.left + 4; x < r.right - 2; x += 6) {
      c.drawLine(Offset(x, r.bottom + 1), Offset(x - 1, r.bottom + 8), softStroke(const Color(0xFFE7B3BF), 2));
    }
    c.restore();
  }

  void _vignette(Canvas c) {
    c.drawRect(
      const Rect.fromLTWH(0, 72, 1280, 648),
      Paint()
        ..shader = Gradient.radial(const Offset(560, 380), 820, const [
          Color(0x007A4A34),
          Color(0x007A4A34),
          Color(0x267A4A34),
        ], const [
          0,
          0.6,
          1,
        ]),
    );
  }
}

enum _JarFill { flour, sugar, strawberryJam, apricotJam, honey }

enum _Herb { basil, rosemary, daisy }
