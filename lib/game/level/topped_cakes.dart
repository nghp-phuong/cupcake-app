import 'dart:ui' as ui;
import 'dart:ui';

import '../../core/art/cake_art.dart';
import '../../core/models/ids.dart';
import '../components/hand_paint.dart';

/// Bánh của món mang topping KHÁC topping chuẩn (bếp nhanh có hũ nhiễu → người chơi có thể đặt nhầm topping, bánh vẫn
/// vào tủ). Ảnh món (`ArtSprites.cake`) đã vẽ dính topping chuẩn nên không dùng được: ghép lớp đế đã nướng + kem chuẩn
/// của món (`CakeArt`, như trạm topping) + [count] topping thật (ảnh `assets/art/toppings/*`).
///
/// Mỗi cặp (món, topping) ghi thành một `Picture` ở cỡ tham chiếu [unit] MỘT lần, vẽ lại bằng co giãn (tủ ghi lại khi
/// đổi; bánh bay vẽ mỗi khung — không dựng CakeVisual / path mỗi khung). [generation] đổi (có ảnh mới nạp) → ghi lại.
class ToppedCakes {
  ToppedCakes(this.generation);

  /// Đồng hồ ảnh (vd. `LevelGame.artGeneration`): đổi → bỏ hình đã ghi để lần sau ghi lại với ảnh mới.
  final int Function() generation;

  /// Số topping trên mặt bánh (= topping chuẩn của bánh vào tủ: `LevelSession.standardToppingCount`).
  static const count = 3;

  /// Cạnh khung vuông lúc ghi hình.
  static const double unit = 128;

  final Map<int, ui.Picture> _pictures = {};
  int _gen = -1;

  static int _key(RecipeId r, ToppingId t) => r.index * 64 + t.index;

  /// Số hình đang giữ (test).
  int get cachedCount => _pictures.length;

  /// Vẽ bánh [recipe] mang [topping] vào khung vuông [r].
  void paint(Canvas canvas, Rect r, RecipeId recipe, ToppingId topping) {
    final g = generation();
    if (g != _gen) {
      clear();
      _gen = g;
    }
    final picture = _pictures[_key(recipe, topping)] ??= recordArt((c) => CakeArt.paint(
        c, const Rect.fromLTWH(0, 0, unit, unit), CakeVisual.recipe(recipe, toppings: {topping: count})));
    final k = r.shortestSide / unit;
    canvas.save();
    canvas.translate(r.center.dx - unit * k / 2, r.center.dy - unit * k / 2);
    canvas.scale(k);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void clear() {
    for (final p in _pictures.values) {
      p.dispose();
    }
    _pictures.clear();
  }
}
