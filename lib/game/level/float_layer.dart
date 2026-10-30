import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter;

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import 'level_paint.dart';
import 'topped_cakes.dart';

enum _Kind { coins, label, banner, cake, stars, coinFly }

class _Float {
  _Kind kind = _Kind.label;
  double x = 0, y = 0;

  /// Điểm đích (bánh bay vào tủ).
  double x2 = 0, y2 = 0;
  double age = 0, life = 1, delay = 0;
  String text = '';
  Color color = SLColors.paper;
  int n = 0;
  RecipeId recipe = RecipeId.cupcakeVanilla;

  /// Topping khác topping chuẩn của bánh bay (null = chuẩn).
  ToppingId? topping;
  bool live = false;
}

/// Chữ / hình bay trên cùng: "+xu" bay lên, nhãn ("Tủ đầy!", "Combo ×N"), băng rôn "Giờ cao điểm!", bánh bay từ trạm
/// Hộp (hoặc từ thợ bánh) vào tủ, sao của mẻ, đồng xu bay từ nhân viên lên ô xu HUD. Bể cố định [capacity] phần tử (không cấp phát khi chạy); hiện / ẩn bằng co giãn (không
/// saveLayer).
class FloatLayer {
  FloatLayer(this.text, {this.topped});

  final CanvasText text;

  /// Bánh ghép mang topping khác topping chuẩn (null → luôn vẽ ảnh món).
  final ToppedCakes? topped;

  static const capacity = 32;
  final List<_Float> _items = [for (var i = 0; i < capacity; i++) _Float()];

  /// Bộ đệm chữ số "+N" (giá trị xu khác nhau → giới hạn số mục).
  final Map<int, TextPainter> _numbers = {};

  final Map<RecipeId, CakeVisual> _visuals = {};

  _Float? _obtain() {
    _Float? oldest;
    for (final f in _items) {
      if (!f.live) return f..live = true;
      if (oldest == null || f.age - f.delay > oldest.age - oldest.delay) oldest = f;
    }
    return oldest; // đầy: dùng lại cái cũ nhất
  }

  void _start(_Float f, _Kind kind, double x, double y, double life, {double delay = 0}) {
    f
      ..kind = kind
      ..x = x
      ..y = y
      ..age = 0
      ..life = life
      ..delay = delay;
  }

  /// "+N" kèm đồng xu bay lên từ [at].
  void coins(Offset at, int coins, {double delay = 0}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.coins, at.dx, at.dy, 1.3, delay: delay);
    f.n = coins;
  }

  /// Nhãn giấy nhỏ bay lên chậm.
  void label(Offset at, String s, {Color color = SLColors.paper, double life = 1.4, double delay = 0}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.label, at.dx, at.dy, life, delay: delay);
    f
      ..text = s
      ..color = color;
  }

  /// Băng rôn lớn giữa sân tiệm.
  void banner(String s, {Color color = SLColors.strawberryLight}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.banner, 640, 210, 2.2);
    f
      ..text = s
      ..color = color;
  }

  /// Bánh bay theo đường cong từ [from] tới [to] trong [life] giây.
  /// [topping]: topping thật nếu khác topping chuẩn của món (vẽ bánh ghép như trong tủ).
  void cake(Offset from, Offset to, RecipeId recipe, {double life = 0.6, ToppingId? topping}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.cake, from.dx, from.dy, life);
    f
      ..x2 = to.dx
      ..y2 = to.dy
      ..recipe = recipe
      ..topping = topping;
  }

  /// Một đồng xu bay vòng cung từ [from] (nhân viên vừa bán) tới [to] (ô xu trên HUD).
  void coinFly(Offset from, Offset to, {double life = 0.75, double delay = 0}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.coinFly, from.dx, from.dy, life, delay: delay);
    f
      ..x2 = to.dx
      ..y2 = to.dy;
  }

  /// [stars] ngôi sao nhỏ bay lên ở [at].
  void stars(Offset at, int stars, {double delay = 0}) {
    final f = _obtain();
    if (f == null) return;
    _start(f, _Kind.stars, at.dx, at.dy, 1.2, delay: delay);
    f.n = stars;
  }

  int get liveCount => _items.where((f) => f.live).length;

  void update(double dt) {
    for (final f in _items) {
      if (!f.live) continue;
      if (f.delay > 0) {
        f.delay = math.max(0, f.delay - dt);
        continue;
      }
      f.age += dt;
      if (f.age >= f.life) f.live = false;
    }
  }

  /// Hệ số co giãn hiện / ẩn: nảy lên lúc đầu, thu nhỏ ở 20% cuối.
  static double _pop(double t) {
    if (t < 0.15) return easeOutBack(t / 0.15);
    if (t > 0.8) return math.max(0, 1 - (t - 0.8) / 0.2);
    return 1;
  }

  void paint(Canvas canvas) {
    for (final f in _items) {
      if (!f.live || f.delay > 0) continue;
      final t = (f.age / f.life).clamp(0.0, 1.0);
      switch (f.kind) {
        case _Kind.coins:
          _paintCoins(canvas, f, t);
        case _Kind.label:
          _scaled(canvas, Offset(f.x, f.y - 40 * easeOutCubic(t)), _pop(t), () {
            text.draw(canvas, f.text, Offset.zero, size: 18, weight: FontWeight.w800, maxWidth: 240, backing: f.color);
          });
        case _Kind.banner:
          final k = t < 0.12 ? easeOutBack(t / 0.12) : (t > 0.85 ? math.max(0, 1 - (t - 0.85) / 0.15) : 1.0);
          _scaled(canvas, Offset(f.x, f.y), k * 1.6, () {
            text.draw(canvas, f.text, Offset.zero, size: 26, weight: FontWeight.w800, maxWidth: 420, backing: f.color);
          });
        case _Kind.cake:
          final e = easeInOut(t);
          final x = f.x + (f.x2 - f.x) * e;
          final y = f.y + (f.y2 - f.y) * e - math.sin(t * math.pi) * 90;
          final s = 64 - 18 * e;
          _paintCake(canvas, Rect.fromCenter(center: Offset(x, y), width: s, height: s), f.recipe, f.topping);
        case _Kind.coinFly:
          _paintCoinFly(canvas, f, t);
        case _Kind.stars:
          final image = ArtSprites.starOn.image;
          final k = _pop(t);
          if (k <= 0) continue;
          final y = f.y - 34 * easeOutCubic(t);
          final s = 26 * k;
          for (var i = 0; i < f.n; i++) {
            final c = Offset(f.x + (i - (f.n - 1) / 2) * 24, y - (i.isEven ? 0 : 6));
            if (image != null) {
              drawArt(canvas, image, Rect.fromCenter(center: c, width: s, height: s));
            } else {
              canvas.drawCircle(c, s * 0.4, fill(AppColors.butter));
              canvas.drawCircle(c, s * 0.4, stroke(SLColors.ink, 2));
            }
          }
      }
    }
  }

  void _scaled(Canvas canvas, Offset at, double k, void Function() draw) {
    if (k <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    draw();
    canvas.restore();
  }

  void _paintCake(Canvas canvas, Rect r, RecipeId recipe, ToppingId? topping) {
    final t = topped;
    if (topping != null && t != null) {
      t.paint(canvas, r, recipe, topping);
      return;
    }
    final image = ArtSprites.cake(recipe).image;
    if (image != null) {
      drawArt(canvas, image, r);
    } else {
      CakeArt.paint(canvas, r, _visuals[recipe] ??= CakeVisual.recipe(recipe));
    }
  }

  /// Đồng xu bay: nảy ra, cong lên rồi rơi vào ô xu, nhỏ dần ở cuối.
  void _paintCoinFly(Canvas canvas, _Float f, double t) {
    final e = easeInOut(t);
    final x = f.x + (f.x2 - f.x) * e;
    final y = f.y + (f.y2 - f.y) * e - math.sin(t * math.pi) * 60;
    final k = t < 0.15 ? easeOutBack(t / 0.15) : 1 - 0.45 * ((t - 0.15) / 0.85);
    if (k <= 0) return;
    final c = Offset(x, y);
    final coin = ArtSprites.coin.image;
    if (coin != null) {
      drawArt(canvas, coin, Rect.fromCenter(center: c, width: 28 * k, height: 28 * k));
    } else {
      canvas.drawCircle(c, 11 * k, fill(AppColors.butter));
      canvas.drawCircle(c, 11 * k, stroke(SLColors.ink, 2));
    }
  }

  void _paintCoins(Canvas canvas, _Float f, double t) {
    final k = _pop(t);
    if (k <= 0) return;
    final y = f.y - 48 * easeOutCubic(t);
    if (_numbers.length > 96) {
      for (final p in _numbers.values) {
        p.dispose();
      }
      _numbers.clear();
    }
    final p = _numbers[f.n] ??= text.layout('+${f.n}', size: 22, weight: FontWeight.w800, maxWidth: 120, title: true);
    // Nhãn giấy bơ (dựng một lần theo số chữ số) + đồng xu + chữ.
    final w = 46 + p.width;
    final tagW = (w / 8).ceil() * 8.0; // dựng theo bậc 8 px → ít hình trong cache
    final art = cachedArt(('lvCoinTag', tagW), () => buildTagArt(Size(tagW, 36), SLColors.butterLight, seed: 0xC014 + tagW.toInt()));
    canvas.save();
    canvas.translate(f.x, y);
    canvas.scale(k);
    drawPictureAt(canvas, art.picture, Offset(-tagW / 2, -18) - art.origin);
    final coin = ArtSprites.coin.image;
    final cx = -tagW / 2 + 18;
    if (coin != null) {
      drawArt(canvas, coin, Rect.fromCenter(center: Offset(cx, 0), width: 26, height: 26));
    } else {
      canvas.drawCircle(Offset(cx, 0), 10, fill(AppColors.butter));
      canvas.drawCircle(Offset(cx, 0), 10, stroke(SLColors.ink, 2));
    }
    p.paint(canvas, Offset(cx + 14, -p.height / 2));
    canvas.restore();
  }

  void dispose() {
    for (final p in _numbers.values) {
      p.dispose();
    }
    _numbers.clear();
  }
}
