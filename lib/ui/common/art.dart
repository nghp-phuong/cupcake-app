import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/art/characters/character_sprites.dart';
import '../../core/art/customer_art.dart';
import '../../core/art/item_art.dart';
import '../../core/models/customer.dart';
import '../../core/models/ids.dart';
import '../sugarleaf/sugarleaf.dart';
import 'shop_scene.dart';

/// Hàm vẽ nhận Canvas + kích thước vùng vẽ.
typedef ArtPaint = void Function(Canvas canvas, Size size);

/// Bọc một hàm vẽ của `lib/core/art` thành widget. [repaintKey] khác → vẽ lại (null = luôn vẽ lại).
/// [repaint] báo vẽ lại không cần dựng lại widget (vd. `CustomerArt.repaint` khi ảnh nhân vật nạp xong).
class ArtCanvas extends StatelessWidget {
  const ArtCanvas({super.key, required this.paint, this.repaintKey, this.repaint, this.width, this.height});

  final ArtPaint paint;
  final Object? repaintKey;
  final Listenable? repaint;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _ArtPainter(paint, repaintKey, repaint)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.fn, this.repaintKey, Listenable? repaint) : super(repaint: repaint);

  final ArtPaint fn;
  final Object? repaintKey;

  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size);

  @override
  bool shouldRepaint(_ArtPainter oldDelegate) => repaintKey == null || oldDelegate.repaintKey != repaintKey;
}

/// Khoá vẽ lại cho bộ trang trí đang đặt.
Object decorKey(Map<DecorSlot, DecorId?> equipped) => Object.hashAll([for (final s in DecorSlot.values) equipped[s]]);

/// Vẽ ảnh vẽ tay [art] vào [rect] nếu đã nạp; false = chưa có (người gọi vẽ hình code dự phòng).
bool paintArtRef(
  Canvas canvas,
  Rect rect,
  ArtRef art, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  double opacity = 1,
}) {
  final image = art.image;
  if (image == null) return false;
  paintArt(canvas, rect, image, fit: fit, alignment: alignment, opacity: opacity);
  return true;
}

/// Ảnh vẽ tay [art] trong ô [size]×[size]; chưa nạp xong / thiếu → [fallback] (hình code). Tự vẽ lại khi ảnh
/// nạp xong (`ArtSprites.changes`).
class ArtImage extends StatelessWidget {
  const ArtImage(this.art, {super.key, this.size = 28, this.fallback});

  final ArtRef art;
  final double size;
  final ArtPaint? fallback;

  @override
  Widget build(BuildContext context) => ArtCanvas(
    width: size,
    height: size,
    repaintKey: art,
    repaint: ArtSprites.changes,
    paint: (c, s) {
      if (!paintArtRef(c, Offset.zero & s, art)) fallback?.call(c, s);
    },
  );
}

/// Biểu tượng vẽ tay ([SLArtIcon]): ảnh [art] khi đã nạp; chưa có/thiếu thì icon vẽ bằng code [SLIcon] — id
/// [fallbackId], hoặc đổi từ icon Material [fallback] qua [slIconIdFor] (không còn hiện Material Icons). Cần một
/// trong hai. Màn mới dùng thẳng [SLArtIcon].
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.art, {super.key, this.fallback, this.fallbackId, this.size = 24, this.color, this.dimmed = false})
      : assert(fallback != null || fallbackId != null, 'cần fallbackId hoặc fallback');

  final ArtRef art;

  /// Icon Material cũ (đổi sang id qua [slIconIdFor]); bỏ qua khi có [fallbackId].
  final IconData? fallback;

  /// Id [SLIcon] dự phòng; null → `slIconIdFor(fallback)`.
  final String? fallbackId;
  final double size;
  final Color? color;

  /// Mờ đi (nút bị khoá).
  final bool dimmed;

  @override
  Widget build(BuildContext context) =>
      SLArtIcon(art, fallbackId ?? slIconIdFor(fallback!), size: size, color: color, dimmed: dimmed);
}

/// Nền tiệm (tường, sàn, cửa sổ, quầy) với đồ trang trí đang đặt — co theo kích thước được cấp.
/// Ảnh vẽ tay khi đã nạp (`ShopScene`), hình code `ShopArt` khi chưa có.
class ShopBackdrop extends StatelessWidget {
  const ShopBackdrop({super.key, required this.equipped, this.rainy = false});

  final Map<DecorSlot, DecorId?> equipped;

  /// Ngày mưa: ô kính cửa sổ nhuộm trời mưa xám xanh (lớp mưa động là `RainOverlay` riêng).
  final bool rainy;

  @override
  Widget build(BuildContext context) {
    return ArtCanvas(
      repaintKey: (decorKey(equipped), rainy),
      repaint: ArtSprites.changes,
      paint: (c, s) => ShopScene.paint(c, s, equipped, rainy: rainy),
    );
  }
}

/// Cảnh nền toàn màn vẽ tay (phủ kín, cắt mép thừa); chưa nạp/thiếu → [fallback] (null = trong suốt, thấy lớp dưới).
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, required this.scene, this.fallback, this.tint});

  final ArtScene scene;
  final Widget? fallback;

  /// Lớp màu phủ lên ảnh (vd. kem mờ cho chữ dễ đọc); chỉ phủ khi có ảnh.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final art = ArtSprites.scene(scene);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (fallback != null)
          ListenableBuilder(
            listenable: ArtSprites.changes,
            builder: (context, _) => art.image == null ? fallback! : const SizedBox.shrink(),
          ),
        ArtCanvas(
          repaintKey: Object.hash(scene, tint),
          repaint: ArtSprites.changes,
          paint: (c, s) {
            if (paintArtRef(c, Offset.zero & s, art, fit: BoxFit.cover) && tint != null) {
              c.drawRect(Offset.zero & s, Paint()..color = tint!);
            }
          },
        ),
      ],
    );
  }
}

/// Hình bánh. [recipe] khác null = đây là MÓN ĐÍCH (bánh hoàn chỉnh của công thức/đơn gọi): có ảnh vẽ tay của món
/// thì vẽ ảnh, chưa có thì vẽ [visual]. Bánh người chơi vừa làm (có thể cháy, thiếu kem…) để [recipe] null —
/// luôn vẽ [visual] để thấy lỗi.
class CakeImage extends StatelessWidget {
  const CakeImage({super.key, required this.visual, this.size = 120, this.recipe});

  final CakeVisual visual;
  final double size;
  final RecipeId? recipe;

  @override
  Widget build(BuildContext context) {
    final art = recipe == null ? null : ArtSprites.cake(recipe!);
    // Luôn nghe ArtSprites.changes: bánh người chơi làm ([recipe] null) cũng vẽ bằng ảnh đế nướng/topping nạp
    // bất đồng bộ trong `CakeArt.paint`.
    return ArtCanvas(
      width: size,
      height: size,
      repaint: ArtSprites.changes,
      paint: (c, s) {
        final rect = Offset.zero & s;
        if (art == null || !paintArtRef(c, rect, art)) CakeArt.paint(c, rect, visual);
      },
    );
  }
}

class ToppingImage extends StatelessWidget {
  const ToppingImage(this.topping, {super.key, this.size = 32});

  final ToppingId topping;
  final double size;

  @override
  Widget build(BuildContext context) => ArtImage(
    ArtSprites.topping(topping),
    size: size,
    fallback: (c, s) => ItemArt.paintTopping(c, Offset.zero & s, topping),
  );
}

class MouldImage extends StatelessWidget {
  const MouldImage(this.mould, {super.key, this.size = 32});

  final MouldType mould;
  final double size;

  @override
  Widget build(BuildContext context) => ArtImage(
    ArtSprites.mould(mould),
    size: size,
    fallback: (c, s) => ItemArt.paintMould(c, Offset.zero & s, mould),
  );
}

class BoxImage extends StatelessWidget {
  const BoxImage(this.box, {super.key, this.size = 40});

  final BoxType box;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ArtImage(ArtSprites.box(box), size: size, fallback: (c, s) => ItemArt.paintBox(c, Offset.zero & s, box));
}

class FrostingSwatch extends StatelessWidget {
  const FrostingSwatch(this.frosting, {super.key, this.size = 32});

  final FrostingId frosting;
  final double size;

  @override
  Widget build(BuildContext context) => ArtImage(
    ArtSprites.frosting(frosting),
    size: size,
    fallback: (c, s) => ItemArt.paintFrostingSwatch(c, Offset.zero & s, frosting),
  );
}

/// Bột chưa nướng (ảnh tô bột vẽ tay; chưa có ảnh → ô màu tròn) — dùng trong sổ công thức.
class BatterSwatch extends StatelessWidget {
  const BatterSwatch(this.batter, {super.key, this.size = 32});

  final BatterType batter;
  final double size;

  @override
  Widget build(BuildContext context) => ArtImage(ArtSprites.batter(batter), size: size, fallback: _circle);

  void _circle(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2 - 1;
    canvas.drawCircle(c, r, Paint()..color = ItemArt.batterColor(batter));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ItemArt.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) =>
      ArtImage(ArtSprites.coin, size: size, fallback: (c, s) => ItemArt.coin(c, Offset.zero & s));
}

class GemIcon extends StatelessWidget {
  const GemIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) =>
      ArtImage(ArtSprites.gem, size: size, fallback: (c, s) => ItemArt.gem(c, Offset.zero & s));
}

class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.filled = true, this.size = 28});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => ArtImage(
    ArtSprites.star(filled: filled),
    size: size,
    fallback: (c, s) => ItemArt.star(c, Offset.zero & s, filled: filled),
  );
}

/// Khách với nét mặt theo [mood]. [clipBottom] > 0 → cắt phần dưới (đứng sau quầy).
///
/// Hình code (nửa người) vẽ trong hộp [width]×[height]. Ảnh vẽ tay là toàn thân nên khi đã có ảnh, khung vẽ
/// được phóng [spriteZoom] lần quanh trục giữa và dời xuống [spriteDy] (âm = lên) để đầu to gần bằng hình
/// code; phần thừa bị cắt trong hộp. Khung luôn giữ tỉ lệ của hộp (3:4), không méo.
class CustomerImage extends StatelessWidget {
  const CustomerImage({
    super.key,
    required this.customer,
    this.mood = CustomerMood.neutral,
    required this.width,
    required this.height,
    this.clipBottom = 0,
    this.spriteZoom = 1,
    this.spriteDy = 0,
  });

  final Customer customer;
  final CustomerMood mood;
  final double width;
  final double height;
  final double clipBottom;
  final double spriteZoom;
  final double spriteDy;

  /// Có ảnh vẽ tay để vẽ (kể cả ảnh tạm nét mặt khác) — cùng điều kiện với `CustomerArt.paint`.
  static bool hasSprite(Customer customer, CustomerMood mood) => CharacterSprites.image(
        CustomerArt.spriteId(customer),
        CustomerArt.spriteExpr(CustomerArt.expressionFor(mood)),
      ) !=
      null;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height - clipBottom,
        child: ArtCanvas(
          repaintKey: Object.hash(customer, mood, spriteZoom, spriteDy),
          repaint: CustomerArt.repaint,
          paint: (c, _) {
            final zoomed = (spriteZoom != 1 || spriteDy != 0) && hasSprite(customer, mood);
            final rect = zoomed
                ? Rect.fromLTWH(width * (1 - spriteZoom) / 2, spriteDy, width * spriteZoom, height * spriteZoom)
                : Rect.fromLTWH(0, 0, width, height);
            CustomerArt.paint(c, rect, customer, mood: mood);
          },
        ),
      ),
    );
  }
}

/// Nhân vật trong hội thoại truyện (narrator → cuốn sổ công thức).
class SpeakerImage extends StatelessWidget {
  const SpeakerImage({
    super.key,
    required this.speaker,
    required this.width,
    required this.height,
    this.clipBottom = 0,
  });

  final Speaker speaker;
  final double width;
  final double height;
  final double clipBottom;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height - clipBottom,
        child: ArtCanvas(
          repaintKey: speaker,
          repaint: CustomerArt.repaint,
          paint: (c, _) => CustomerArt.paintSpeaker(c, Rect.fromLTWH(0, 0, width, height), speaker),
        ),
      ),
    );
  }
}

/// Ảnh vẽ tay đóng gói theo đường dẫn ([asset], vd. `assets/art/level/booster_oven.webp`) trong ô [width]×[height]
/// (giữ tỉ lệ), giải mã nhỏ theo cỡ hiện (ResizeImage, không chặn luồng UI). Thiếu file / chưa vẽ → [fallback].
/// Dùng cho ảnh không thuộc danh mục `ArtSprites.ids` (vật phẩm hỗ trợ, gói cửa hàng V2…).
class AssetArt extends StatelessWidget {
  const AssetArt(this.asset, {super.key, required this.width, double? height, required this.fallback})
      : height = height ?? width;

  final String asset;
  final double width;
  final double height;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final px = (width * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 1024);
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: ResizeImage(AssetImage(asset), width: px, policy: ResizeImagePolicy.fit),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => Center(child: fallback),
      ),
    );
  }
}
