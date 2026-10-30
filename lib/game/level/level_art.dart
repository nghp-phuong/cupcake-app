import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/art/art_sprites.dart';

/// Ảnh vẽ tay riêng của màn chơi level trong `assets/art/level/` (nền trong suốt).
enum LevelArtId {
  /// Bong bóng ý nghĩ trống (320×270), đuôi chấm ở dưới-trái.
  thoughtBubble('thought_bubble'),

  /// Huy hiệu tròn sao vàng của khách đặc biệt (160×160).
  specialBadge('special_badge'),

  /// Hũ thuỷ tinh nắp bần, nơ hồng (267×320) — topping vẽ bên trong.
  toppingJar('topping_jar'),

  /// Kệ bánh gỗ hai tầng có giấy lót ren (264×360), đặt trên quầy cạnh tủ kính (mở rộng `case_stand`).
  caseStand('case_stand'),

  /// Bàn tròn + 2 ghế gỗ (420×309), trên sàn tiệm sau quầy (mở rộng `cafe_tables`).
  cafeTable('cafe_table'),

  /// Bàn tay chỉ hoạt hình, ngón trỏ hướng lên, cổ tay áo kem (lớp hướng dẫn L1–L3, GĐ5). Thiếu → tay vẽ code.
  tutorialHand('tutorial_hand'),

  /// Biểu tượng vật phẩm hỗ trợ đang dùng (GĐ6, góc dưới trái sân tiệm, vẽ ~36 px): khay bánh đầy / đồng hồ cát có
  /// trái tim / lò nhỏ có tia lửa. Giải mã nhỏ ([decodeWidth]). Thiếu → biểu tượng vẽ code.
  boosterFullCase('booster_fullcase', decodeWidth: 128),
  boosterPatience('booster_patience', decodeWidth: 128),
  boosterOven('booster_oven', decodeWidth: 128);

  const LevelArtId(this.file, {this.decodeWidth});

  final String file;

  /// Bề ngang giải mã tối đa (px; null = cỡ gốc). Ảnh nhỏ hơn giữ nguyên.
  final int? decodeWidth;

  String get assetPath => 'assets/art/level/$file.webp';
}

/// Nạp ảnh [LevelArtId] một lần (bất đồng bộ, không chặn), giữ suốt phiên app (~1,7 MB đã giải mã cho 5 ảnh đầu + tay chỉ hướng dẫn; biểu tượng vật phẩm giải mã nhỏ).
/// Chưa nạp xong / thiếu file → [image] trả null, nơi vẽ dùng hình vẽ code dự phòng. Gọi [image] mỗi khung chỉ là
/// tra mảng (không tạo đối tượng); lần đầu thấy thiếu thì tự xếp nạp.
///
/// Nền sân tiệm không nằm ở đây mà đi qua `ArtSprites` ([shopBase], cache ảnh nền lớn dùng chung).
abstract final class LevelArt {
  /// Nền tiệm có tủ kính TRỐNG (1280×720) — bánh trong tủ do game vẽ lên các tầng kệ.
  static const shopBase = ArtRef(ArtGroup.shop, 'shop_base_empty');

  static AssetBundle _bundle = rootBundle;
  static final List<ui.Image?> _images = List<ui.Image?>.filled(LevelArtId.values.length, null);
  static final List<Future<void>?> _loading = List<Future<void>?>.filled(LevelArtId.values.length, null);
  static final List<bool> _missing = List<bool>.filled(LevelArtId.values.length, false);
  static var _generation = 0;

  /// Ảnh đã giải mã (null nếu chưa nạp xong / thiếu; lần đầu thì xếp nạp).
  static ui.Image? image(LevelArtId id) {
    final img = _images[id.index];
    if (img == null && !_missing[id.index] && _loading[id.index] == null) _request(id);
    return img;
  }

  static bool isMissing(LevelArtId id) => _missing[id.index];

  /// Nạp sẵn mọi ảnh. Future xong khi mọi ảnh đã nạp hoặc được xác định là thiếu; không bao giờ báo lỗi, không cần
  /// `await`.
  static Future<void> preload() => Future.wait([
        for (final id in LevelArtId.values)
          if (_images[id.index] == null && !_missing[id.index]) _loading[id.index] ?? _request(id),
      ]);

  static Future<void> _request(LevelArtId id) => _loading[id.index] = _load(id, _generation);

  static Future<void> _load(LevelArtId id, int generation) async {
    ui.Image? image;
    try {
      final width = id.decodeWidth;
      final buffer = await _bundle.loadBuffer(id.assetPath);
      final codec = width == null
          ? await ui.instantiateImageCodecFromBuffer(buffer)
          : await ui.instantiateImageCodecWithSize(buffer,
              getTargetSize: (w, h) => w <= width ? const ui.TargetImageSize() : ui.TargetImageSize(width: width, height: (h * width / w).round()));
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LevelArt: bỏ qua ${id.assetPath} ($e)');
    }
    if (generation != _generation) {
      image?.dispose(); // Đã reset trong lúc nạp.
      return;
    }
    _loading[id.index] = null;
    if (image == null) {
      _missing[id.index] = true;
    } else {
      _images[id.index]?.dispose();
      _images[id.index] = image;
    }
  }

  @visibleForTesting
  static int get debugCachedCount => _images.where((i) => i != null).length;

  /// Xoá cache; [bundle] thay cho rootBundle (test).
  @visibleForTesting
  static void debugReset({AssetBundle? bundle}) {
    _generation++;
    for (var i = 0; i < _images.length; i++) {
      _images[i]?.dispose();
      _images[i] = null;
      _loading[i] = null;
      _missing[i] = false;
    }
    _bundle = bundle ?? rootBundle;
  }
}
