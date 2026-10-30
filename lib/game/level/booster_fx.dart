import 'dart:math' as math;
import 'dart:ui';

import '../../core/constants.dart';
import '../../core/monetization/booster.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import '../components/hand_paint.dart';
import 'level_art.dart';
import 'level_game.dart';
import 'level_layout.dart';

/// Vật phẩm hỗ trợ đang dùng trong lượt chơi — phần hình của màn (GĐ6). Hiệu ứng logic (tủ đầy, kiên nhẫn ×1.3,
/// lò ×0.5) nằm ở `LevelSession`; ở đây chỉ là cờ để vẽ. Bất biến, so sánh theo giá trị.
class LevelBoosts {
  const LevelBoosts({this.fullCase = false, this.patience = false, this.ovenBoost = false});

  static const none = LevelBoosts();

  /// Cờ vẽ của tập vật phẩm [ids] (`LevelSession.boosters`).
  factory LevelBoosts.of(Set<BoosterId> ids) => ids.isEmpty
      ? none
      : LevelBoosts(
          fullCase: ids.contains(BoosterId.fullCase),
          patience: ids.contains(BoosterId.patience),
          ovenBoost: ids.contains(BoosterId.ovenBoost),
        );

  /// Bắt đầu với tủ đầy bánh → lấp lánh trên tủ [BoosterFx.caseSparkleSec] giây đầu.
  final bool fullCase;

  /// Khách vãng lai kiên nhẫn hơn → vòng kiên nhẫn có viền vàng nhạt.
  final bool patience;

  /// Lò ở bếp nhanh ×2 → tia lửa + vòng sáng vàng nhỏ quanh lò đang nướng.
  final bool ovenBoost;

  bool get any => fullCase || patience || ovenBoost;

  /// Số biểu tượng ở hàng vật phẩm.
  int get count => (fullCase ? 1 : 0) + (patience ? 1 : 0) + (ovenBoost ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is LevelBoosts && other.fullCase == fullCase && other.patience == patience && other.ovenBoost == ovenBoost;

  @override
  int get hashCode => Object.hash(fullCase, patience, ovenBoost);

  @override
  String toString() => 'LevelBoosts(fullCase: $fullCase, patience: $patience, ovenBoost: $ovenBoost)';
}

/// Vẽ hiệu ứng của vật phẩm hỗ trợ: lấp lánh trên tủ lúc bắt đầu ([paintCase]), tia lửa quanh lò ([paintOven]), viền
/// vàng vòng kiên nhẫn ([paintPatienceHalo]) và hàng biểu tượng vật phẩm đang dùng ([paintIcons], góc dưới trái sân
/// tiệm, trên dải bếp — dưới mặt quầy trái nên không che khách / tủ). Nhẹ, không rối mắt: vài sao nhỏ, không hạt mới,
/// không cấp phát mỗi khung (vị trí tính sẵn, hình nhãn dán dựng một lần).
class BoosterFx {
  BoosterFx(this.game);

  final LevelGame game;

  /// Thời gian lấp lánh trên tủ khi bắt đầu với tủ đầy (giây chơi của lượt).
  static const double caseSparkleSec = 1.5;

  /// Hàng biểu tượng: đĩa nhãn dán bán kính [iconRadius], từ trái sang, đáy hàng ở [iconsBottom].
  static const double iconRadius = 19;
  static const double iconGap = 8;
  static const double iconsLeft = 12;
  static const double iconsBottom = LevelLayout.kitchenTop - 6;

  /// Viền vàng nhạt của vòng kiên nhẫn (vật phẩm `patience`).
  static const Color haloColor = Color(0xFFFFE6A6);
  static const Color _haloInk = Color(0xFFE9B84A);

  /// Tia lửa quanh lò (vật phẩm `ovenBoost`).
  static const Color _sparkColor = Color(0xFFFFC23D);

  /// Tâm biểu tượng thứ [k] của hàng.
  static Offset iconCenter(int k) =>
      Offset(iconsLeft + iconRadius + k * (iconRadius * 2 + iconGap), iconsBottom - iconRadius);

  /// Khung hàng biểu tượng khi có [n] cái (test: không chồng khách / tủ / bếp).
  static Rect iconsRect(int n) => n <= 0
      ? Rect.zero
      : Rect.fromLTRB(iconsLeft, iconsBottom - iconRadius * 2, iconCenter(n - 1).dx + iconRadius, iconsBottom);

  /// Vị trí sao lấp lánh trên tủ (tỉ lệ trong lòng kính) + pha nhịp nhấp nháy, tính sẵn.
  static final List<(Offset, double)> _caseStars = () {
    const g = LevelLayout.caseGlass;
    const spots = [
      (0.08, 0.22), (0.27, 0.10), (0.46, 0.30), (0.66, 0.12), (0.88, 0.26), //
      (0.16, 0.62), (0.38, 0.72), (0.58, 0.58), (0.78, 0.70), (0.95, 0.55),
    ];
    return [
      for (var i = 0; i < spots.length; i++)
        (Offset(g.left + g.width * spots[i].$1, g.top + g.height * spots[i].$2), i * 2.399),
    ];
  }();

  /// Vòng sáng quanh lò: màu đổi mỗi khung → Paint riêng (không làm phình bộ đệm `softStroke` theo màu).
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..isAntiAlias = true;

  GameArt? _iconBack;
  final List<GameArt?> _fallbacks = List<GameArt?>.filled(3, null);

  void dispose() {
    _iconBack?.dispose();
    _iconBack = null;
    for (var i = 0; i < _fallbacks.length; i++) {
      _fallbacks[i]?.dispose();
      _fallbacks[i] = null;
    }
  }

  /// Độ đậm lấp lánh trên tủ ở khung này (0 = tắt): hiện nhanh 0.15 s, giữ, mờ dần 0.6 s cuối của [caseSparkleSec].
  double get caseSparkle {
    if (!game.boosts.fullCase) return 0;
    final t = game.session.elapsed;
    if (t >= caseSparkleSec) return 0;
    final rise = (game.time / 0.15).clamp(0.0, 1.0);
    final fall = ((caseSparkleSec - t) / 0.6).clamp(0.0, 1.0);
    return math.min(rise, fall);
  }

  /// Lấp lánh nhẹ trên tủ kính (vẽ sau bánh trong tủ, trước bong bóng gọi món).
  void paintCase(Canvas canvas) {
    final k = caseSparkle;
    if (k <= 0) return;
    paintGlow(canvas, LevelLayout.caseGlass.deflate(24), 0.35 * k);
    final fx = game.effects;
    for (var i = 0; i < _caseStars.length; i++) {
      final (at, phase) = _caseStars[i];
      final tw = 0.5 + 0.5 * math.sin(game.time * 7 + phase);
      if (tw < 0.15) continue;
      final color = (i % 3 == 0 ? const Color(0xFFFFFFFF) : AppColors.butter).withValues(alpha: k * (0.55 + 0.45 * tw));
      fx.twinkleAt(canvas, at, 7 + 8 * tw, color, variant: i % 3, angle: (i % 3 - 1) * 0.12);
    }
  }

  /// Vòng sáng vàng nhỏ + ba tia lửa xoay quanh lò [r] đang nướng (vẽ sau ảnh lò). [oven]: chỉ số lò (lệch pha).
  void paintOven(Canvas canvas, Rect r, int oven) {
    if (!game.boosts.ovenBoost) return;
    final c = r.center;
    final rad = r.shortestSide * 0.55;
    final pulse = 0.5 + 0.5 * math.sin(game.time * 5 + oven * 1.7);
    _ringPaint.color = _sparkColor.withValues(alpha: 0.45 + 0.3 * pulse);
    canvas.drawCircle(c, rad, _ringPaint);
    final fx = game.effects;
    for (var i = 0; i < 3; i++) {
      final a = game.time * 1.6 + oven * 0.9 + i * math.pi * 2 / 3;
      final at = Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad * 0.9);
      final tw = 0.5 + 0.5 * math.sin(game.time * 9 + i * 2.1);
      fx.twinkleAt(canvas, at, 5 + 4 * tw, (i == 1 ? const Color(0xFFFFF3C4) : _sparkColor).withValues(alpha: 0.6 + 0.4 * tw), variant: i);
    }
  }

  /// Viền vàng nhạt ngoài rãnh vòng kiên nhẫn (tâm [center], bán kính [r]) của khách vãng lai.
  void paintPatienceHalo(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r + 4.5, softStroke(haloColor, 3.2));
    canvas.drawCircle(center, r + 6.4, stroke(_haloInk.withValues(alpha: 0.55), 1));
  }

  /// Hàng biểu tượng vật phẩm đang dùng (fullCase · patience · ovenBoost theo thứ tự này).
  void paintIcons(Canvas canvas) {
    final b = game.boosts;
    if (!b.any) return;
    var k = 0;
    if (b.fullCase) _paintIcon(canvas, k++, 0, LevelArtId.boosterFullCase);
    if (b.patience) _paintIcon(canvas, k++, 1, LevelArtId.boosterPatience);
    if (b.ovenBoost) _paintIcon(canvas, k++, 2, LevelArtId.boosterOven);
  }

  static const List<String> _fallbackIcons = ['cake_slice', 'clock', 'oven'];
  static const List<Color> _fallbackColors = [AppColors.strawberry, AppColors.mint, AppColors.butter];

  void _paintIcon(Canvas canvas, int slot, int kind, LevelArtId art) {
    final c = iconCenter(slot);
    paintShadow(canvas, c.translate(0, iconRadius - 2), iconRadius * 1.6, 6, alpha: 0.2);
    final img = LevelArt.image(art);
    if (img != null) {
      final back = _iconBack ??= buildStickerDisc(iconRadius, SLColors.paper, seed: 0xB005, inkWidth: 2);
      drawPictureAt(canvas, back.picture, c - back.origin);
      drawArt(canvas, img, Rect.fromCircle(center: c, radius: iconRadius - 3));
      return;
    }
    final fb = _fallbacks[kind] ??= buildStickerDisc(iconRadius, _fallbackColors[kind],
        seed: 0xB010 + kind, inkWidth: 2, content: (cv, o) => paintSLIcon(cv, _fallbackIcons[kind], o, iconRadius * 1.2));
    drawPictureAt(canvas, fb.picture, c - fb.origin);
  }
}
