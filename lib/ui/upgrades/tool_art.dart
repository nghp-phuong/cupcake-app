import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/art/art_sprites.dart';
import '../../core/art/item_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';

/// Hình lò nướng / dụng cụ cho thẻ nâng cấp. null = lò. Ảnh vẽ tay ở [art]; [paint] là hình code dự phòng
/// (theo bảng màu) khi ảnh chưa nạp/thiếu.
abstract final class ToolArt {
  /// Ảnh vẽ tay: lò theo cấp [level] (1..5), dụng cụ theo [tool].
  static ArtRef art(ToolId? tool, {int level = 1}) => tool == null ? ArtSprites.oven(level) : ArtSprites.tool(tool);

  static void paint(Canvas canvas, Rect rect, ToolId? tool, {int level = 1}) {
    final r = ItemArt.square(rect);
    switch (tool) {
      case null:
        _oven(canvas, r, level);
      case ToolId.whisk:
        _whisk(canvas, r);
      case ToolId.pipingBag:
        _pipingBag(canvas, r);
      case ToolId.tongs:
        _tongs(canvas, r);
    }
  }

  static void _oven(Canvas canvas, Rect r, int level) {
    final s = r.width;
    final line = s * 0.03;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left + s * 0.1, r.top + s * 0.14, s * 0.8, s * 0.74),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(body, ItemArt.fill(const Color(0xFFF7B9A6)));
    canvas.drawRRect(body, ItemArt.stroke(ItemArt.outline, line));
    // Bảng núm vặn.
    final panel = Rect.fromLTWH(body.left, body.top, body.width, s * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndCorners(panel, topLeft: Radius.circular(s * 0.08), topRight: Radius.circular(s * 0.08)),
      ItemArt.fill(AppColors.cream),
    );
    canvas.drawLine(
      Offset(panel.left, panel.bottom),
      Offset(panel.right, panel.bottom),
      ItemArt.stroke(ItemArt.outline, line),
    );
    for (var i = 0; i < 5; i++) {
      final c = Offset(panel.left + panel.width * (0.18 + i * 0.16), panel.center.dy);
      final lit = i < level;
      canvas.drawCircle(c, s * 0.035, ItemArt.fill(lit ? AppColors.butter : const Color(0xFFEADBC8)));
      canvas.drawCircle(c, s * 0.035, ItemArt.stroke(ItemArt.outline, line * 0.6));
    }
    // Cửa kính với ánh lửa.
    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(body.left + s * 0.1, panel.bottom + s * 0.08, body.width - s * 0.2, s * 0.42),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(door, ItemArt.fill(const Color(0xFFFFE2A8)));
    canvas.drawRRect(door, ItemArt.stroke(ItemArt.outline, line));
    final glow = Rect.fromCenter(center: door.center.translate(0, s * 0.06), width: door.width * 0.6, height: s * 0.14);
    canvas.drawOval(glow, ItemArt.fill(const Color(0xFFFFB061)));
    canvas.drawLine(
      Offset(door.left + s * 0.06, door.top + s * 0.06),
      Offset(door.right - s * 0.06, door.top + s * 0.06),
      ItemArt.stroke(ItemArt.outline, line * 1.4),
    );
    // Chân.
    for (final x in [body.left + s * 0.12, body.right - s * 0.12]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, body.bottom + s * 0.03), width: s * 0.1, height: s * 0.06),
          Radius.circular(s * 0.02),
        ),
        ItemArt.fill(AppColors.caramel),
      );
    }
  }

  static void _whisk(Canvas canvas, Rect r) {
    final s = r.width;
    final line = s * 0.03;
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(-math.pi / 5);
    // Cán.
    final handle = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, s * 0.3), width: s * 0.13, height: s * 0.34),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(handle, ItemArt.fill(AppColors.strawberry));
    canvas.drawRRect(handle, ItemArt.stroke(ItemArt.outline, line));
    // Các nan lồng.
    final wire = ItemArt.stroke(const Color(0xFF9AA5AE), s * 0.025);
    for (final w in [0.08, 0.16, 0.24]) {
      final path = Path()
        ..moveTo(-s * 0.04, s * 0.13)
        ..cubicTo(-s * w * 1.6, -s * 0.05, -s * w * 1.2, -s * 0.38, 0, -s * 0.4)
        ..cubicTo(s * w * 1.2, -s * 0.38, s * w * 1.6, -s * 0.05, s * 0.04, s * 0.13);
      canvas.drawPath(path, wire);
    }
    canvas.drawLine(Offset(0, s * 0.13), Offset(0, -s * 0.4), wire);
    canvas.restore();
  }

  static void _pipingBag(Canvas canvas, Rect r) {
    final s = r.width;
    final line = s * 0.03;
    final c = r.center;
    final bag = Path()
      ..moveTo(c.dx - s * 0.3, c.dy - s * 0.3)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.42, c.dx + s * 0.3, c.dy - s * 0.3)
      ..lineTo(c.dx + s * 0.06, c.dy + s * 0.24)
      ..lineTo(c.dx - s * 0.06, c.dy + s * 0.24)
      ..close();
    canvas.drawPath(bag, ItemArt.fill(const Color(0xFFDDF2EA)));
    canvas.drawPath(bag, ItemArt.stroke(ItemArt.outline, line));
    // Kem bên trong.
    final cream = Path()
      ..moveTo(c.dx - s * 0.22, c.dy - s * 0.18)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.24, c.dx + s * 0.22, c.dy - s * 0.18)
      ..lineTo(c.dx + s * 0.06, c.dy + s * 0.2)
      ..lineTo(c.dx - s * 0.06, c.dy + s * 0.2)
      ..close();
    canvas.drawPath(cream, ItemArt.fill(AppColors.strawberry.withValues(alpha: 0.8)));
    // Đầu bắt kem.
    final tip = Path()
      ..moveTo(c.dx - s * 0.07, c.dy + s * 0.24)
      ..lineTo(c.dx + s * 0.07, c.dy + s * 0.24)
      ..lineTo(c.dx, c.dy + s * 0.38)
      ..close();
    canvas.drawPath(tip, ItemArt.fill(const Color(0xFFC9D1D8)));
    canvas.drawPath(tip, ItemArt.stroke(ItemArt.outline, line));
    // Nơ buộc.
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.36), s * 0.05, ItemArt.fill(AppColors.butter));
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.36), s * 0.05, ItemArt.stroke(ItemArt.outline, line * 0.8));
  }

  static void _tongs(Canvas canvas, Rect r) {
    final s = r.width;
    final c = r.center;
    final metal = ItemArt.stroke(const Color(0xFF9AA5AE), s * 0.07);
    final edge = ItemArt.stroke(ItemArt.outline, s * 0.025);
    for (final dir in [-1.0, 1.0]) {
      final arm = Path()
        ..moveTo(c.dx, c.dy - s * 0.38)
        ..quadraticBezierTo(c.dx + dir * s * 0.2, c.dy - s * 0.05, c.dx + dir * s * 0.14, c.dy + s * 0.36);
      canvas.drawPath(arm, edge..strokeWidth = s * 0.1);
      canvas.drawPath(arm, metal);
      // Đầu gắp hình vỏ sò.
      final tip = Offset(c.dx + dir * s * 0.14, c.dy + s * 0.36);
      canvas.drawOval(Rect.fromCenter(center: tip, width: s * 0.14, height: s * 0.09), ItemArt.fill(AppColors.mint));
      canvas.drawOval(
        Rect.fromCenter(center: tip, width: s * 0.14, height: s * 0.09),
        ItemArt.stroke(ItemArt.outline, s * 0.025),
      );
    }
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.38), s * 0.06, ItemArt.fill(AppColors.strawberry));
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.38), s * 0.06, ItemArt.stroke(ItemArt.outline, s * 0.025));
  }
}
