import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/art/art_sprites.dart';
import '../../core/art/shop_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';

/// Cảnh tiệm vẽ tay: ảnh nền `shop_base` (tường kem, kệ, tủ bánh, quầy gỗ, cửa sổ lớn bên phải) + đồ trang trí
/// đang đặt chồng lên theo ô. Vẽ theo khung 1280×720 của ảnh nền rồi co về kích thước được cấp.
///
/// Vị trí từng ô (toạ độ ảnh nền) chọn sao cho ở màn gọi món — vé đơn che x 640–1220, y 84–504 — đồ trên quầy,
/// cửa sổ hướng biển, cây và sàn vẫn lộ ra:
/// - giấy dán tường: hoạ tiết lặp phủ vùng tường kiểu "darken" (chỉ nhuộm phần tường sáng, kệ/đồ gỗ tối hơn
///   giữ nguyên);
/// - sàn: hoạ tiết lặp ép dẹt (giả phối cảnh) trên dải sàn dưới quầy;
/// - cửa sổ: rèm treo trên cửa sổ lớn; cửa sổ hướng biển treo trên tường sau (thay chỗ bảng đen);
/// - quầy: đặt trên mặt quầy nhỏ ngoài cùng bên trái; cây: góc dưới bên phải.
///
/// Chưa nạp ảnh nền, hoặc ảnh của một món đang đặt bị thiếu hẳn → vẽ `ShopArt` (hình code) để đồ trang trí người
/// chơi đã mua (+% tip) luôn nhìn thấy. Ảnh món đang nạp dở thì tạm bỏ qua, vẽ lại khi `ArtSprites.changes` báo.
abstract final class ShopScene {
  /// Vùng tường lộ ra trên ảnh nền (trừ khung cửa sổ lớn, tủ bánh và quầng đèn).
  static final Path _wall = Path.combine(
    ui.PathOperation.difference,
    Path()..addRect(const Rect.fromLTRB(0, 0, 1010, 432)),
    Path()
      ..addRect(const Rect.fromLTRB(438, 378, 850, 432))
      ..addOval(Rect.fromCenter(center: const Offset(306, 128), width: 96, height: 70))
      ..addOval(Rect.fromCenter(center: const Offset(838, 128), width: 96, height: 70))
      ..addOval(Rect.fromCenter(center: const Offset(1020, 176), width: 80, height: 60)),
  );

  /// Dải sàn dưới các quầy.
  static final Path _floor = Path()
    ..addRect(const Rect.fromLTRB(0, 657, 1280, 720))
    ..addRect(const Rect.fromLTRB(80, 586, 182, 657));

  static const _wallTile = 220.0;

  /// Cạnh một tile hoạ tiết sàn (ảnh 512 chứa ~8×8 ô gạch) theo đơn vị mặt sàn; ở độ sâu z = 1 rộng
  /// [_floorTile] × [_floorFocal] px.
  static const _floorTile = 0.9;
  static const _floorHorizon = 330.0;
  static const _floorFocal = 390.0;

  /// Ma trận chiếu mặt sàn (x, z) → màn hình (cột trước): w = z.
  static final Float64List _floorProjection = Float64List.fromList([
    _floorFocal, 0, 0, 0, //
    kRefSize.width / 2, _floorHorizon, 0, 1,
    0, 0, 1, 0,
    0, _floorFocal, 0, 0,
  ]);

  /// Khung vẽ ảnh 512×512 của từng món (đã tính lề trong suốt của ảnh).
  static const curtainRect = Rect.fromLTWH(912, 26, 420, 420);
  static const seaWindowRect = Rect.fromLTWH(402, 112, 250, 250);
  static const counterItemRect = Rect.fromLTWH(8, 306, 166, 166);
  static const plantRect = Rect.fromLTWH(1036, 446, 270, 270);

  /// Các ô kính cửa sổ lớn bên phải trên ảnh nền (toạ độ khung 1280×720, đo trên `shop_base.webp`): khung vẽ theo
  /// phối cảnh nên mỗi ô là tứ giác (trên trái, trên phải, dưới phải, dưới trái). Ô lớn nhìn ra phố; ba ô nhỏ hàng
  /// trên; ô trên cùng bên phải và ô kính cửa ra vào ở mép phải (chỉ lộ một dải).
  static const windowPanes = <List<Offset>>[
    [Offset(1032, 222), Offset(1221, 183), Offset(1221, 453), Offset(1032, 420)],
    [Offset(1032, 125), Offset(1075, 112), Offset(1075, 193), Offset(1032, 200)],
    [Offset(1089, 105), Offset(1145, 93), Offset(1145, 180), Offset(1089, 188)],
    [Offset(1160, 81), Offset(1222, 65), Offset(1222, 164), Offset(1160, 177)],
    [Offset(1253, 52), Offset(1280, 49), Offset(1280, 150), Offset(1253, 155)],
    [Offset(1260, 192), Offset(1280, 188), Offset(1280, 452), Offset(1260, 452)],
  ];

  /// Hai chao đèn treo phía trước hàng ô kính trên (trừ khỏi vùng kính để không bị nhuộm/mưa đè lên).
  static const _lampShades = <List<Offset>>[
    [Offset(1015, 147), Offset(1029, 147), Offset(1031, 160), Offset(1041, 169), Offset(1048, 182), Offset(1050, 196),
      Offset(1036, 200), Offset(1010, 200)],
    [Offset(1132, 112), Offset(1151, 112), Offset(1153, 127), Offset(1161, 134), Offset(1171, 150), Offset(1177, 172),
      Offset(1160, 178), Offset(1120, 178), Offset(1107, 173), Offset(1113, 150), Offset(1123, 134), Offset(1130, 127)],
  ];

  static final Path _artGlass = Path.combine(
    ui.PathOperation.difference,
    _polygons(windowPanes),
    _polygons(_lampShades),
  );

  static Path _polygons(List<List<Offset>> polygons) {
    final path = Path();
    for (final p in polygons) {
      path.addPolygon(p, true);
    }
    return path;
  }

  /// Ô kính của cửa sổ hình code (`ShopArt._window`, khung 760,80–1100,330) — chỉ dùng khi chưa có ảnh nền.
  static final Path _plainGlass = Path()
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(760, 80, 1100, 330), const Radius.circular(12)));

  static final Rect _artGlassBounds = _artGlass.getBounds();
  static final Rect _plainGlassBounds = _plainGlass.getBounds();

  /// Vùng kính cửa sổ (toạ độ khung 1280×720) của cảnh ảnh ([art] = [usesArt]) hoặc cảnh hình code. Dùng chung
  /// cho lớp nhuộm trời mưa ở đây và lớp mưa `RainOverlay`. Path tạo sẵn một lần — người gọi không được sửa.
  ///
  /// Đồ trang trí ô cửa sổ không đổi khung: rèm treo đè lên một phần kính (vẽ lại bằng [windowFrontImage]);
  /// cửa sổ hướng biển treo trên tường sau, ngoài vùng này (không nhuộm, không mưa).
  static Path windowGlass({required bool art}) => art ? _artGlass : _plainGlass;

  /// Khung bao của [windowGlass].
  static Rect windowGlassBounds({required bool art}) => art ? _artGlassBounds : _plainGlassBounds;

  /// Ảnh đồ trang trí treo trước ô kính (rèm, vẽ ở [curtainRect]) để lớp mưa vẽ lại đè lên mưa; null = không có
  /// hoặc chưa nạp.
  static ui.Image? windowFrontImage(Map<DecorSlot, DecorId?> equipped) =>
      equipped[DecorSlot.window] == DecorId.windowCurtains ? _image(DecorId.windowCurtains) : null;

  /// Nhuộm ô kính ngày mưa: bỏ bớt độ bão hoà (giữ 30%) rồi nhân với xanh xám `#7F8FA3` ~60%, đẩy nhẹ sang lạnh —
  /// trời nắng vàng của ảnh nền thành trời mưa xám xanh, phố bên ngoài vẫn đọc ra hình.
  static final ColorFilter _rainGlassFilter = ColorFilter.matrix(_rainGlassMatrix());

  static List<double> _rainGlassMatrix() {
    const keep = 0.3, mix = 0.6;
    const tint = [0x7F / 255, 0x8F / 255, 0xA3 / 255];
    const luma = [0.2126, 0.7152, 0.0722];
    const shift = [-6.0, 0.0, 10.0];
    return [
      for (var i = 0; i < 3; i++) ...[
        for (var j = 0; j < 3; j++) ((1 - mix) + mix * tint[i]) * ((1 - keep) * luma[j] + (i == j ? keep : 0)),
        0,
        shift[i],
      ],
      0, 0, 0, 1, 0,
    ];
  }

  static final Paint _plainRainTint = Paint()..color = const Color(0x737F8FA3);

  /// Vùng nhìn rõ từng ô trên cảnh ảnh (dùng cho hình thu nhỏ "Cơ bản").
  static Rect focus(DecorSlot slot) => switch (slot) {
    DecorSlot.wallpaper => const Rect.fromLTWH(150, 40, 600, 480),
    DecorSlot.floor => const Rect.fromLTWH(480, 652, 85, 68),
    DecorSlot.counter => const Rect.fromLTWH(0, 290, 250, 200),
    DecorSlot.window => const Rect.fromLTWH(940, 40, 340, 272),
    DecorSlot.plant => const Rect.fromLTWH(1000, 430, 280, 224),
  };

  /// Vẽ được bằng ảnh: đã có ảnh nền và không món đang đặt nào bị thiếu ảnh hẳn.
  static bool usesArt(Map<DecorSlot, DecorId?> equipped) {
    if (ArtSprites.shopBase.image == null) return false;
    for (final id in equipped.values) {
      if (id != null && ArtSprites.decor(id).isMissing) return false;
    }
    return true;
  }

  /// [rainy]: nhuộm ô kính cửa sổ thành trời mưa (dưới đồ trang trí, nên rèm vẫn giữ màu).
  static void paint(Canvas canvas, Size size, Map<DecorSlot, DecorId?> equipped, {bool rainy = false}) {
    final art = usesArt(equipped);
    if (!art) ShopArt.paint(canvas, size, equipped);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / kRefSize.width, size.height / kRefSize.height);
    if (art) {
      paintRef(canvas, equipped, rainy: rainy);
    } else if (rainy) {
      canvas.drawPath(_plainGlass, _plainRainTint);
    }
    canvas.restore();
  }

  /// Vẽ ở toạ độ khung 1280×720 (người gọi tự co/cắt). Chỉ gọi khi [usesArt] đúng.
  static void paintRef(Canvas canvas, Map<DecorSlot, DecorId?> equipped, {bool rainy = false}) {
    final base = ArtSprites.shopBase.image;
    if (base == null) return;
    paintArt(canvas, Offset.zero & kRefSize, base, fit: BoxFit.cover);
    if (rainy) {
      // Vẽ lại phần kính của ảnh nền qua bộ lọc màu (không dùng blend mode lên lớp dưới → đúng trên mọi renderer).
      canvas.save();
      canvas.clipPath(_artGlass);
      paintArt(canvas, Offset.zero & kRefSize, base, fit: BoxFit.cover, colorFilter: _rainGlassFilter);
      canvas.restore();
    }

    final wall = _image(equipped[DecorSlot.wallpaper]);
    if (wall != null) {
      canvas.save();
      canvas.clipPath(_wall);
      _tiled(canvas, _wall.getBounds(), wall, _wallTile, _wallTile, blend: BlendMode.darken, opacity: 0.9);
      canvas.restore();
    }

    final floor = _image(equipped[DecorSlot.floor]);
    if (floor != null) {
      canvas.save();
      canvas.clipPath(_floor);
      final r = _floor.getBounds();
      // Mặt sàn trong phối cảnh: điểm (x, z) của sàn (z = độ sâu) chiếu lên màn hình
      // X = cx + f·x/z, Y = horizon + f/z — ô sàn nhỏ dần và hội tụ về điểm tụ như trong ảnh nền.
      canvas.save();
      canvas.transform(_floorProjection);
      _tiled(canvas, const Rect.fromLTRB(-4, 0.9, 4, 1.8), floor, _floorTile, _floorTile, opacity: 0.92);
      canvas.restore();
      // Tối dần về phía chân quầy.
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, Offset(r.center.dx, r.top + 40), const [
            Color(0x665A3E36),
            Color(0x005A3E36),
          ]),
      );
      canvas.restore();
    }

    final window = equipped[DecorSlot.window];
    final windowImage = _image(window);
    if (windowImage != null) {
      paintArt(canvas, window == DecorId.windowSeaView ? seaWindowRect : curtainRect, windowImage);
    }

    final counter = _image(equipped[DecorSlot.counter]);
    if (counter != null) {
      _groundShadow(canvas, Offset(counterItemRect.center.dx, counterItemRect.bottom - 6), counterItemRect.width * 0.7);
      paintArt(canvas, counterItemRect, counter);
    }

    final plant = _image(equipped[DecorSlot.plant]);
    if (plant != null) {
      _groundShadow(canvas, Offset(plantRect.center.dx, plantRect.bottom - 8), plantRect.width * 0.6);
      paintArt(canvas, plantRect, plant);
    }
  }

  static ui.Image? _image(DecorId? id) => id == null ? null : ArtSprites.decor(id).image;

  /// Bóng mềm hình elip dưới chân đồ vật.
  static void _groundShadow(Canvas canvas, Offset center, double width) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, 0.14);
    canvas.drawCircle(
      Offset.zero,
      width / 2,
      Paint()..shader = ui.Gradient.radial(Offset.zero, width / 2, const [Color(0x555A3E36), Color(0x005A3E36)]),
    );
    canvas.restore();
  }

  /// Phủ [rect] bằng hoạ tiết lặp [image], mỗi ô [tileW]×[tileH], gốc lặp ở góc trên trái của [rect].
  static void _tiled(
    Canvas canvas,
    Rect rect,
    ui.Image image,
    double tileW,
    double tileH, {
    BlendMode blend = BlendMode.srcOver,
    double opacity = 1,
  }) {
    final matrix = Float64List(16)
      ..[0] = tileW / image.width
      ..[5] = tileH / image.height
      ..[10] = 1
      ..[12] = rect.left
      ..[13] = rect.top
      ..[15] = 1;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(image, TileMode.repeated, TileMode.repeated, matrix, filterQuality: FilterQuality.medium)
        ..color = Color.fromRGBO(0, 0, 0, opacity)
        ..blendMode = blend,
    );
  }
}
