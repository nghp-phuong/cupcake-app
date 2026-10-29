import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../core/constants.dart';
import '../sugarleaf/sugarleaf.dart';

/// Màu "trắng" cũ của thẻ/nhãn → giấy ngà của bộ SL*.
Color _paper(Color c) => c == Colors.white ? SLColors.paper : c;

/// Khung thẻ chuẩn — tờ giấy vẽ tay ([SLPanel]: viền mực run tay, mép ngả nâu, bóng nâu mềm). [color] là màu
/// giấy (`Colors.white` = giấy ngà); [width]/[height] tuỳ chọn. Nét run tay theo [seed]; null → [seedFor] (tất
/// định theo màu + bo góc, giống nhau giữa các lần chạy và trên mọi nền tảng).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.width,
    this.height,
    this.seed,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final double? height;
  final int? seed;

  /// Seed mặc định: băm ổn định ([slSeed] → djb2) của chuỗi `"<ARGB>|<bo góc 1 số lẻ>"` — không dùng `hashCode`/
  /// `Object.hash` (đổi theo mỗi lần chạy).
  static int seedFor(Color color, double radius) => slSeed(content: '${color.toARGB32()}|${radius.toStringAsFixed(1)}');

  @override
  Widget build(BuildContext context) {
    final panel = SLPanel(
      color: _paper(color),
      padding: padding,
      radius: radius,
      seed: seed ?? (key is ValueKey ? null : seedFor(color, radius)),
      child: child,
    );
    return width == null && height == null ? panel : SizedBox(width: width, height: height, child: panel);
  }
}

/// Băng tiêu đề — dải vải vẽ tay ([SLNameTag]: đuôi cắt chữ V, chỉ khâu dọc mép). [icon] (Material) đổi sang icon
/// vẽ tay qua [slIconIdFor]; có [art] thì dùng ảnh vẽ tay (chưa nạp → icon vẽ bằng code).
class TitleRibbon extends StatelessWidget {
  const TitleRibbon(this.text, {super.key, this.color = AppColors.strawberry, this.fontSize = 26, this.icon, this.iconId, this.art});

  final String text;
  final Color color;
  final double fontSize;
  final IconData? icon;

  /// Id icon vẽ tay; ưu tiên hơn [icon].
  final String? iconId;

  /// Ảnh vẽ tay thay cho icon (chỉ dùng khi có [icon] hoặc [iconId]).
  final ArtRef? art;

  @override
  Widget build(BuildContext context) {
    final id = iconId ?? (icon == null ? null : slIconIdFor(icon!));
    final height = (fontSize * 2).clamp(44.0, 88.0);
    return SLNameTag(
      text,
      color: _paper(color),
      fontSize: fontSize,
      height: height,
      maxWidth: 640,
      icon: id,
      leading: id != null && art != null
          ? SLArtIcon(art!, id, size: fontSize * 1.2, color: SLColors.ink)
          : null,
    );
  }
}

/// Nhãn nhỏ (VIP, khách quen, đang dùng…) — viên kẹo màu nước tĩnh ([SLChip] không bấm được).
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.color = AppColors.mint, this.icon, this.iconId});

  final String text;
  final Color color;
  final IconData? icon;

  /// Id icon vẽ tay; ưu tiên hơn [icon].
  final String? iconId;

  @override
  Widget build(BuildContext context) => SLChip(
        label: text,
        selected: true,
        color: _paper(color),
        icon: iconId ?? (icon == null ? null : slIconIdFor(icon!)),
      );
}

/// Thanh tiến trình có chữ ở giữa — ống giấy, màu nước chảy bên trong ([SLProgressBar]). Chiếm hết bề ngang được
/// cấp (nếu có giới hạn).
class SugarProgressBar extends StatelessWidget {
  const SugarProgressBar({super.key, required this.value, this.label, this.height = 24, this.color = AppColors.good});

  /// 0..1.
  final double value;
  final String? label;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SLProgressBar(
          value: value,
          label: label,
          height: height,
          color: color,
          width: c.hasBoundedWidth ? c.maxWidth : null,
        ),
      );
}

/// Nền kem có chấm bi nhạt (hồng dâu, bạc hà, vàng bơ) — dùng cho các màn không có cảnh tiệm.
class CozyBackground extends StatelessWidget {
  const CozyBackground({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _CozyPainter(), size: Size.infinite);
}

class _CozyPainter extends CustomPainter {
  const _CozyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.cream);
    const colors = [AppColors.strawberry, AppColors.mint, AppColors.butter];
    const step = 64.0;
    var row = 0;
    for (var y = 24.0; y < size.height; y += step * 0.75, row++) {
      var i = row;
      for (var x = row.isEven ? 24.0 : 24.0 + step / 2; x < size.width; x += step, i++) {
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = colors[i % 3].withValues(alpha: 0.28));
      }
    }
  }

  @override
  bool shouldRepaint(_CozyPainter oldDelegate) => false;
}

/// Mái hiên sọc hồng–kem với mép vỏ sò (thanh trên các màn phụ).
class AwningPainter extends CustomPainter {
  const AwningPainter({this.scallop = 16});

  final double scallop;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyH = size.height - scallop;
    const stripe = 64.0;
    final stripes = (size.width / stripe).ceil();
    for (var i = 0; i < stripes; i++) {
      final color = i.isEven ? AppColors.strawberry : const Color(0xFFFFE9EF);
      final rect = Rect.fromLTWH(i * stripe, 0, stripe, bodyH);
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawArc(
        Rect.fromLTWH(i * stripe, bodyH - scallop, stripe, scallop * 2),
        0,
        math.pi,
        true,
        Paint()..color = color,
      );
    }
    final edge = Paint()
      ..color = AppColors.caramel
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < stripes; i++) {
      canvas.drawArc(Rect.fromLTWH(i * stripe, bodyH - scallop, stripe, scallop * 2), 0, math.pi, false, edge);
    }
  }

  @override
  bool shouldRepaint(AwningPainter oldDelegate) => oldDelegate.scallop != scallop;
}
