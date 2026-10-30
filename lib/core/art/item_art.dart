import 'dart:math' as math;
import 'dart:ui';

import '../constants.dart';
import '../models/ids.dart';

/// Hình vật phẩm vẽ bằng code (alpha chưa có sprite). Mọi hàm nhận `Canvas` + `Rect` đích nên dùng
/// được cả trong `CustomPainter` lẫn `Component.render` của Flame.
abstract final class ItemArt {
  static const outline = AppColors.chocolate;

  static Paint fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  static Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Hình vuông lớn nhất đặt giữa [r].
  static Rect square(Rect r) {
    final s = math.min(r.width, r.height);
    return Rect.fromCenter(center: r.center, width: s, height: s);
  }

  // ------------------------------------------------------------------ Bảng màu vật liệu

  static Color frostingColor(FrostingId f) => switch (f) {
        FrostingId.vanillaCream => const Color(0xFFFFF8E7),
        FrostingId.chocolateGanache => const Color(0xFF6B3A2A),
        FrostingId.strawberryCream => const Color(0xFFF7B6C6),
        FrostingId.matchaCream => const Color(0xFFBFE0A4),
        FrostingId.creamCheese => const Color(0xFFFFFDF5),
        FrostingId.custard => const Color(0xFFFFD966),
        FrostingId.butterGlaze => const Color(0xFFF2B54A),
        FrostingId.appleFilling => const Color(0xFFD9963F),
        FrostingId.lotusPaste => const Color(0xFFC48A5C),
      };

  /// Màu bột sống.
  static Color batterColor(BatterType b) => switch (b) {
        BatterType.vanilla => const Color(0xFFF8E3AE),
        BatterType.chocolate => const Color(0xFF8A5A42),
        BatterType.redVelvet => const Color(0xFFC0394A),
        BatterType.matcha => const Color(0xFFA9CB86),
        BatterType.butter => const Color(0xFFF1D08E),
        BatterType.almond => const Color(0xFFF6DCC6),
        BatterType.cheese => const Color(0xFFFCEFC4),
        BatterType.laminated => const Color(0xFFF7E4B8),
        BatterType.choux => const Color(0xFFF6DDA2),
        BatterType.mooncake => const Color(0xFFEBC27E),
      };

  /// Màu bột theo độ nướng: 0 sống, 1 vàng đẹp, 2 cháy.
  static Color bakedColor(BatterType b, double baked) {
    final raw = batterColor(b);
    final t = baked.clamp(0.0, 2.0);
    if (t <= 1) {
      // Bột sáng → vàng nâu nhẹ (bột sẫm như chocolate gần như không đổi).
      return Color.lerp(raw, Color.lerp(raw, const Color(0xFFD99A4E), 0.45)!, t)!;
    }
    final golden = Color.lerp(raw, const Color(0xFFD99A4E), 0.45)!;
    return Color.lerp(golden, const Color(0xFF3B2418), (t - 1) * 0.85)!;
  }

  static Color toppingColor(ToppingId t) => switch (t) {
        ToppingId.sprinkles => AppColors.strawberry,
        ToppingId.strawberry => const Color(0xFFE5404F),
        ToppingId.cherry => const Color(0xFFC81D3A),
        ToppingId.chocolateChips => const Color(0xFF4A2A1E),
        ToppingId.blueberry => const Color(0xFF4B5BA8),
        ToppingId.mintLeaf => const Color(0xFF5DB37E),
        ToppingId.sugarPearl => const Color(0xFFFFF0F4),
        ToppingId.candle => const Color(0xFF8FC6E8),
        ToppingId.almondFlakes => const Color(0xFFF3DDB8),
        ToppingId.powderedSugar => const Color(0xFFFFFFFF),
        ToppingId.kiwi => const Color(0xFF8CC63F),
        ToppingId.sesame => const Color(0xFFF5ECD6),
        ToppingId.meringueMushroom => AppColors.cream,
      };

  static Color boxColor(BoxType b) => switch (b) {
        BoxType.small => AppColors.mint,
        BoxType.cake => const Color(0xFFFFFFFF),
        BoxType.gift => AppColors.strawberry,
      };

  // ------------------------------------------------------------------ Topping

  static void paintTopping(Canvas canvas, Rect rect, ToppingId topping) {
    final r = square(rect);
    final s = r.width;
    final c = r.center;
    final line = s * 0.06;
    switch (topping) {
      case ToppingId.sprinkles:
        const colors = [AppColors.strawberry, AppColors.mint, AppColors.butter, Color(0xFF8FC6E8), Color(0xFFFFFFFF)];
        for (var i = 0; i < 7; i++) {
          final a = i * 2.4;
          final d = s * (0.08 + 0.05 * (i % 3));
          final p = c + Offset(math.cos(a) * d * 2.2, math.sin(a) * d * 2.2);
          final dir = Offset(math.cos(a * 1.7), math.sin(a * 1.7)) * (s * 0.11);
          canvas.drawLine(p - dir, p + dir, stroke(outline, s * 0.11));
          canvas.drawLine(p - dir, p + dir, stroke(colors[i % colors.length], s * 0.07));
        }
      case ToppingId.strawberry:
        final body = Path()
          ..moveTo(c.dx, r.bottom - s * 0.08)
          ..cubicTo(r.left + s * 0.05, c.dy + s * 0.15, r.left + s * 0.1, r.top + s * 0.25, c.dx, r.top + s * 0.3)
          ..cubicTo(r.right - s * 0.1, r.top + s * 0.25, r.right - s * 0.05, c.dy + s * 0.15, c.dx, r.bottom - s * 0.08)
          ..close();
        canvas.drawPath(body, fill(toppingColor(topping)));
        canvas.drawPath(body, stroke(outline, line));
        for (final o in const [Offset(-0.12, 0.05), Offset(0.12, 0.05), Offset(0, 0.18), Offset(-0.05, -0.05), Offset(0.07, -0.08)]) {
          canvas.drawOval(Rect.fromCenter(center: c + o * s, width: s * 0.04, height: s * 0.06), fill(AppColors.butter));
        }
        final leaf = Path()
          ..moveTo(c.dx - s * 0.22, r.top + s * 0.22)
          ..lineTo(c.dx - s * 0.06, r.top + s * 0.3)
          ..lineTo(c.dx, r.top + s * 0.12)
          ..lineTo(c.dx + s * 0.06, r.top + s * 0.3)
          ..lineTo(c.dx + s * 0.22, r.top + s * 0.22)
          ..lineTo(c.dx, r.top + s * 0.36)
          ..close();
        canvas.drawPath(leaf, fill(const Color(0xFF5DB37E)));
        canvas.drawPath(leaf, stroke(outline, line * 0.7));
      case ToppingId.cherry:
        final stem = Path()
          ..moveTo(c.dx, c.dy)
          ..quadraticBezierTo(c.dx + s * 0.05, r.top + s * 0.2, c.dx + s * 0.22, r.top + s * 0.08);
        canvas.drawPath(stem, stroke(const Color(0xFF6B8E3D), s * 0.06));
        final ball = Rect.fromCircle(center: c.translate(0, s * 0.12), radius: s * 0.28);
        canvas.drawOval(ball, fill(toppingColor(topping)));
        canvas.drawOval(ball, stroke(outline, line));
        canvas.drawCircle(ball.center.translate(-s * 0.1, -s * 0.1), s * 0.06, fill(const Color(0xAAFFFFFF)));
      case ToppingId.chocolateChips:
        final drop = Path()
          ..moveTo(c.dx, r.top + s * 0.15)
          ..quadraticBezierTo(c.dx + s * 0.08, c.dy, r.right - s * 0.2, r.bottom - s * 0.25)
          ..quadraticBezierTo(c.dx, r.bottom - s * 0.1, r.left + s * 0.2, r.bottom - s * 0.25)
          ..quadraticBezierTo(c.dx - s * 0.08, c.dy, c.dx, r.top + s * 0.15)
          ..close();
        canvas.drawPath(drop, fill(toppingColor(topping)));
        canvas.drawPath(drop, stroke(outline, line * 0.6));
        canvas.drawCircle(c.translate(-s * 0.07, s * 0.05), s * 0.04, fill(const Color(0x66FFFFFF)));
      case ToppingId.blueberry:
        final ball = Rect.fromCircle(center: c, radius: s * 0.32);
        canvas.drawOval(ball, fill(toppingColor(topping)));
        canvas.drawOval(ball, stroke(outline, line));
        final crown = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final p = c.translate(0, -s * 0.12) + Offset(math.cos(a), math.sin(a)) * (s * 0.08);
          if (i == 0) {
            crown.moveTo(p.dx, p.dy);
          } else {
            crown.lineTo(p.dx, p.dy);
          }
        }
        crown.close();
        canvas.drawPath(crown, fill(const Color(0xFF2E3A72)));
        canvas.drawCircle(c.translate(s * 0.12, s * 0.06), s * 0.05, fill(const Color(0x55FFFFFF)));
      case ToppingId.mintLeaf:
        final leaf = Path()
          ..moveTo(r.left + s * 0.12, r.bottom - s * 0.15)
          ..quadraticBezierTo(r.left + s * 0.1, r.top + s * 0.1, r.right - s * 0.1, r.top + s * 0.12)
          ..quadraticBezierTo(r.right - s * 0.12, r.bottom - s * 0.12, r.left + s * 0.12, r.bottom - s * 0.15)
          ..close();
        canvas.drawPath(leaf, fill(toppingColor(topping)));
        canvas.drawPath(leaf, stroke(outline, line * 0.8));
        canvas.drawLine(
          Offset(r.left + s * 0.14, r.bottom - s * 0.17),
          Offset(r.right - s * 0.2, r.top + s * 0.2),
          stroke(const Color(0xFF3D8A5A), line * 0.7),
        );
      case ToppingId.sugarPearl:
        final ball = Rect.fromCircle(center: c, radius: s * 0.28);
        canvas.drawOval(ball, fill(toppingColor(topping)));
        canvas.drawOval(ball, stroke(const Color(0xFFD9A6B5), line));
        canvas.drawCircle(c.translate(-s * 0.09, -s * 0.09), s * 0.08, fill(const Color(0xFFFFFFFF)));
      case ToppingId.candle:
        final body = Rect.fromLTWH(c.dx - s * 0.1, r.top + s * 0.32, s * 0.2, s * 0.6);
        canvas.drawRect(body, fill(toppingColor(topping)));
        canvas.save();
        canvas.clipRect(body);
        for (var i = -2; i < 8; i++) {
          final y = body.top + i * s * 0.12;
          canvas.drawLine(Offset(body.left, y + s * 0.12), Offset(body.right, y), stroke(const Color(0xFFFFFFFF), s * 0.05));
        }
        canvas.restore();
        canvas.drawRect(body, stroke(outline, line * 0.8));
        canvas.drawLine(Offset(c.dx, body.top), Offset(c.dx, body.top - s * 0.06), stroke(outline, line * 0.6));
        final flame = Path()
          ..moveTo(c.dx, r.top + s * 0.04)
          ..quadraticBezierTo(c.dx + s * 0.1, r.top + s * 0.18, c.dx, r.top + s * 0.26)
          ..quadraticBezierTo(c.dx - s * 0.1, r.top + s * 0.18, c.dx, r.top + s * 0.04)
          ..close();
        canvas.drawPath(flame, fill(const Color(0xFFFFB443)));
        canvas.drawCircle(Offset(c.dx, r.top + s * 0.19), s * 0.035, fill(AppColors.butter));
      case ToppingId.almondFlakes:
        // Ba lát hạnh nhân mỏng, mép nâu nướng.
        for (final (o, a) in const [(Offset(-0.14, 0.08), -0.5), (Offset(0.14, 0.1), 0.6), (Offset(0, -0.12), 0.1)]) {
          canvas.save();
          canvas.translate(c.dx + o.dx * s, c.dy + o.dy * s);
          canvas.rotate(a);
          final flake = Rect.fromCenter(center: Offset.zero, width: s * 0.42, height: s * 0.22);
          canvas.drawOval(flake, fill(toppingColor(topping)));
          canvas.drawOval(flake, stroke(AppColors.caramel, line * 0.7));
          canvas.drawLine(Offset(-s * 0.1, 0), Offset(s * 0.1, 0), stroke(const Color(0x66B9805A), line * 0.5));
          canvas.restore();
        }
      case ToppingId.powderedSugar:
        // Đám đường bột: mây trắng mờ + hạt li ti, viền nâu nhạt để nổi trên nền sáng.
        final cloud = Rect.fromCircle(center: c, radius: s * 0.36);
        canvas.drawOval(cloud, fill(const Color(0xCCFFFFFF)));
        canvas.drawOval(cloud, stroke(const Color(0x66C9A27E), line * 0.5));
        for (var i = 0; i < 12; i++) {
          final a = i * 2.4;
          final d = math.min(s * 0.06 + s * 0.022 * i, s * 0.3);
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, s * 0.03, fill(const Color(0xFFFFFFFF)));
        }
      case ToppingId.kiwi:
        // Lát kiwi: vỏ nâu, thịt xanh, lõi sáng, vòng hạt đen.
        final slice = Rect.fromCircle(center: c, radius: s * 0.36);
        canvas.drawOval(slice, fill(const Color(0xFF8A6A3E)));
        canvas.drawOval(slice.deflate(s * 0.04), fill(toppingColor(topping)));
        canvas.drawOval(Rect.fromCircle(center: c, radius: s * 0.1), fill(const Color(0xFFF1F5D0)));
        for (var i = 0; i < 10; i++) {
          final a = i * math.pi / 5;
          canvas.drawOval(
            Rect.fromCenter(center: c + Offset(math.cos(a), math.sin(a)) * (s * 0.16), width: s * 0.04, height: s * 0.06),
            fill(const Color(0xFF2E2A22)),
          );
        }
        canvas.drawOval(slice, stroke(outline, line));
      case ToppingId.sesame:
        // Vài hạt mè hình giọt nước.
        for (final (o, a) in const [
          (Offset(-0.18, -0.1), 0.4),
          (Offset(0.16, -0.14), -0.6),
          (Offset(0.02, 0.06), 1.2),
          (Offset(-0.12, 0.2), -0.2),
          (Offset(0.2, 0.16), 0.9),
        ]) {
          canvas.save();
          canvas.translate(c.dx + o.dx * s, c.dy + o.dy * s);
          canvas.rotate(a);
          final seed = Path()
            ..moveTo(0, -s * 0.1)
            ..quadraticBezierTo(s * 0.07, 0, 0, s * 0.08)
            ..quadraticBezierTo(-s * 0.07, 0, 0, -s * 0.1)
            ..close();
          canvas.drawPath(seed, fill(toppingColor(topping)));
          canvas.drawPath(seed, stroke(AppColors.caramel, line * 0.5));
          canvas.restore();
        }
      case ToppingId.meringueMushroom:
        // Nấm meringue: chân trắng, mũ trắng rắc cacao.
        final stem = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, s * 0.16), width: s * 0.22, height: s * 0.36), Radius.circular(s * 0.08));
        canvas.drawRRect(stem, fill(toppingColor(topping)));
        canvas.drawRRect(stem, stroke(outline, line * 0.8));
        final cap = Path()
          ..moveTo(r.left + s * 0.12, c.dy + s * 0.02)
          ..cubicTo(r.left + s * 0.12, r.top + s * 0.08, r.right - s * 0.12, r.top + s * 0.08, r.right - s * 0.12, c.dy + s * 0.02)
          ..quadraticBezierTo(c.dx, c.dy + s * 0.1, r.left + s * 0.12, c.dy + s * 0.02)
          ..close();
        canvas.drawPath(cap, fill(const Color(0xFFFFFBF3)));
        canvas.drawPath(cap, stroke(outline, line));
        for (final o in const [Offset(-0.14, -0.1), Offset(0.06, -0.18), Offset(0.18, -0.06), Offset(-0.02, -0.04)]) {
          canvas.drawCircle(c + o * s, s * 0.025, fill(const Color(0x998A5A42)));
        }
    }
  }

  // ------------------------------------------------------------------ Khuôn

  static void paintMould(Canvas canvas, Rect rect, MouldType mould) {
    final r = square(rect);
    final s = r.width;
    final c = r.center;
    final line = s * 0.035;
    const metal = Color(0xFFD9DDE3);
    const metalDark = Color(0xFFA9AFB8);
    switch (mould) {
      case MouldType.cupcakeLiner:
      case MouldType.muffinCup:
        final tall = mould == MouldType.muffinCup;
        final color = tall ? AppColors.caramel : AppColors.strawberry;
        final top = c.dy - s * (tall ? 0.22 : 0.15);
        final bottom = c.dy + s * 0.3;
        final cup = Path()
          ..moveTo(c.dx - s * 0.36, top)
          ..lineTo(c.dx + s * 0.36, top)
          ..lineTo(c.dx + s * 0.26, bottom)
          ..lineTo(c.dx - s * 0.26, bottom)
          ..close();
        canvas.drawPath(cup, fill(color));
        for (var i = 1; i < 6; i++) {
          final t = i / 6;
          canvas.drawLine(
            Offset(c.dx - s * 0.36 + s * 0.72 * t, top),
            Offset(c.dx - s * 0.26 + s * 0.52 * t, bottom),
            stroke(Color.lerp(color, outline, 0.35)!, line * 0.7),
          );
        }
        canvas.drawPath(cup, stroke(outline, line));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, top), width: s * 0.72, height: s * 0.12), fill(Color.lerp(color, const Color(0xFFFFFFFF), 0.4)!));
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, top), width: s * 0.72, height: s * 0.12), stroke(outline, line));
      case MouldType.tartShell:
        final shell = Rect.fromCenter(center: c.translate(0, s * 0.05), width: s * 0.84, height: s * 0.36);
        final path = Path();
        const n = 16;
        for (var i = 0; i <= n * 2; i++) {
          final a = math.pi * i / (n * 2) * 2;
          final rr = i.isEven ? 1.0 : 0.94;
          final p = Offset(shell.center.dx + math.cos(a) * shell.width / 2 * rr, shell.center.dy + math.sin(a) * shell.height / 2 * rr);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawRect(Rect.fromLTRB(shell.left + s * 0.06, shell.center.dy, shell.right - s * 0.06, shell.center.dy + s * 0.14), fill(const Color(0xFFE8B66A)));
        canvas.drawOval(shell.translate(0, s * 0.14).deflate(s * 0.06), fill(const Color(0xFFD9A055)));
        canvas.drawPath(path, fill(const Color(0xFFF1CC86)));
        canvas.drawPath(path, stroke(outline, line));
        canvas.drawOval(shell.deflate(s * 0.07), fill(const Color(0xFFE2B36C)));
      case MouldType.roundPan:
      case MouldType.springformPan:
      case MouldType.tallPan:
        final h = switch (mould) {
          MouldType.tallPan => s * 0.5,
          MouldType.springformPan => s * 0.3,
          _ => s * 0.26,
        };
        final w = s * 0.8;
        final topY = c.dy - h / 2 + s * 0.04;
        final topOval = Rect.fromCenter(center: Offset(c.dx, topY), width: w, height: s * 0.2);
        final bottomOval = topOval.translate(0, h);
        final side = Path()
          ..moveTo(topOval.left, topY)
          ..lineTo(bottomOval.left, bottomOval.center.dy)
          ..arcTo(bottomOval, math.pi, -math.pi, false)
          ..lineTo(topOval.right, topY)
          ..close();
        canvas.drawPath(side, fill(metal));
        canvas.drawPath(side, stroke(outline, line));
        canvas.drawOval(topOval, fill(metalDark));
        canvas.drawOval(topOval, stroke(outline, line));
        canvas.drawOval(topOval.deflate(s * 0.03), fill(const Color(0xFF8E949C)));
        if (mould == MouldType.springformPan) {
          final clasp = Rect.fromCenter(center: Offset(topOval.right - s * 0.02, topY + h / 2), width: s * 0.1, height: s * 0.16);
          canvas.drawRRect(RRect.fromRectAndRadius(clasp, Radius.circular(s * 0.02)), fill(metalDark));
          canvas.drawRRect(RRect.fromRectAndRadius(clasp, Radius.circular(s * 0.02)), stroke(outline, line * 0.8));
        }
      case MouldType.macaronMat:
        final mat = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.62), Radius.circular(s * 0.08));
        canvas.drawRRect(mat, fill(const Color(0xFFF7C7D3)));
        canvas.drawRRect(mat, stroke(outline, line));
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 3; col++) {
            final p = Offset(mat.left + mat.width * (col + 0.5) / 3, mat.top + mat.height * (row + 0.5) / 2);
            canvas.drawCircle(p, s * 0.1, fill(const Color(0xFFFBE3E9)));
            canvas.drawCircle(p, s * 0.1, stroke(const Color(0xFFD98FA4), line * 0.7));
          }
        }
      case MouldType.pastryTray:
      case MouldType.logPan:
        // Khay phẳng lót giấy nến (bánh cán bơ); khuôn cuộn (bûche): thành cao hơn.
        final log = mould == MouldType.logPan;
        final topY = c.dy - s * (log ? 0.12 : 0.14);
        final bottomY = c.dy + s * (log ? 0.14 : 0.18);
        final rim = Rect.fromLTRB(c.dx - s * 0.44, bottomY, c.dx + s * 0.44, bottomY + s * (log ? 0.08 : 0.04));
        Path tray(double inset) => Path()
          ..moveTo(c.dx - s * (log ? 0.38 : 0.33) + inset, topY + inset)
          ..lineTo(c.dx + s * (log ? 0.38 : 0.33) - inset, topY + inset)
          ..lineTo(c.dx + s * 0.44 - inset, bottomY - inset)
          ..lineTo(c.dx - s * 0.44 + inset, bottomY - inset)
          ..close();
        canvas.drawRect(rim, fill(metalDark));
        canvas.drawRect(rim, stroke(outline, line));
        canvas.drawPath(tray(0), fill(metal));
        canvas.drawPath(tray(0), stroke(outline, line));
        canvas.drawPath(tray(s * 0.05), fill(AppColors.cream));
        canvas.drawPath(tray(s * 0.05), stroke(metalDark, line * 0.6));
      case MouldType.shellMould:
        // Khay 3 hốc vỏ sò (madeleine).
        final tray = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.5), Radius.circular(s * 0.06));
        canvas.drawRRect(tray, fill(metal));
        canvas.drawRRect(tray, stroke(outline, line));
        for (var i = -1; i <= 1; i++) {
          final cell = Rect.fromCenter(center: c.translate(i * s * 0.29, 0), width: s * 0.24, height: s * 0.3);
          canvas.drawOval(cell, fill(metalDark));
          final hinge = Offset(cell.center.dx, cell.bottom - s * 0.02);
          for (var k = 1; k < 6; k++) {
            final a = math.pi + math.pi * k / 6;
            final edge = Offset(cell.center.dx + math.cos(a) * cell.width * 0.46, cell.center.dy + math.sin(a) * cell.height * 0.46);
            canvas.drawLine(hinge, edge, stroke(const Color(0xFF8E949C), line * 0.5));
          }
          canvas.drawOval(cell, stroke(outline, line * 0.8));
        }
      case MouldType.eclairTray:
        // Khay nướng có 3 rãnh dài (bắt bột choux thành thanh).
        final tray = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.52), Radius.circular(s * 0.05));
        canvas.drawRRect(tray, fill(metal));
        canvas.drawRRect(tray, stroke(outline, line));
        for (var i = -1; i <= 1; i++) {
          final groove = RRect.fromRectAndRadius(
              Rect.fromCenter(center: c.translate(0, i * s * 0.14), width: s * 0.7, height: s * 0.09), Radius.circular(s * 0.045));
          canvas.drawRRect(groove, fill(metalDark));
          canvas.drawRRect(groove, stroke(outline, line * 0.7));
        }
      case MouldType.piePan:
        // Đĩa pie gốm bạc hà, mép gợn sóng.
        final top = Rect.fromCenter(center: c.translate(0, -s * 0.02), width: s * 0.86, height: s * 0.36);
        final bottom = Rect.fromCenter(center: c.translate(0, s * 0.16), width: s * 0.66, height: s * 0.22);
        final side = Path()
          ..moveTo(top.left, top.center.dy)
          ..lineTo(bottom.left, bottom.center.dy)
          ..arcTo(bottom, math.pi, -math.pi, false)
          ..lineTo(top.right, top.center.dy)
          ..close();
        final dish = Color.lerp(AppColors.mint, outline, 0.12)!;
        final light = Color.lerp(AppColors.mint, const Color(0xFFFFFFFF), 0.35)!;
        canvas.drawPath(side, fill(dish));
        canvas.drawPath(side, stroke(outline, line));
        canvas.drawOval(top, fill(AppColors.mint));
        for (var i = 0; i < 18; i++) {
          final a = math.pi * 2 * i / 18;
          canvas.drawCircle(
              Offset(top.center.dx + math.cos(a) * top.width * 0.47, top.center.dy + math.sin(a) * top.height * 0.45), s * 0.028, fill(light));
        }
        canvas.drawOval(top, stroke(outline, line));
        canvas.drawOval(top.deflate(s * 0.07), fill(Color.lerp(AppColors.mint, const Color(0xFFFFFFFF), 0.5)!));
        canvas.drawOval(top.deflate(s * 0.07), stroke(dish, line * 0.6));
      case MouldType.mooncakeMould:
        // Khuôn gỗ ép bánh Trung thu: cán + đầu khuôn khắc hoa.
        const wood = AppColors.caramel;
        final woodDark = Color.lerp(wood, outline, 0.3)!;
        final handle = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, -s * 0.24), width: s * 0.14, height: s * 0.32), Radius.circular(s * 0.05));
        canvas.drawRRect(handle, fill(wood));
        canvas.drawRRect(handle, stroke(outline, line));
        final head = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, s * 0.1), width: s * 0.66, height: s * 0.4), Radius.circular(s * 0.08));
        canvas.drawRRect(head, fill(woodDark));
        canvas.drawRRect(head, stroke(outline, line));
        final face = Rect.fromCenter(center: head.center, width: s * 0.44, height: s * 0.28);
        canvas.drawOval(face, fill(const Color(0xFF8A5A3E)));
        canvas.drawOval(face, stroke(outline, line * 0.7));
        for (var i = 0; i < 4; i++) {
          final a = math.pi / 2 * i + math.pi / 4;
          final petal = Rect.fromCenter(
            center: face.center + Offset(math.cos(a) * face.width * 0.16, math.sin(a) * face.height * 0.16),
            width: face.width * 0.26,
            height: face.height * 0.3,
          );
          canvas.drawOval(petal, stroke(wood, line * 0.6));
        }
        canvas.drawCircle(face.center, s * 0.03, fill(wood));
    }
  }

  // ------------------------------------------------------------------ Hộp

  static void paintBox(Canvas canvas, Rect rect, BoxType box, {bool open = false}) {
    final r = square(rect);
    final s = r.width;
    final c = r.center;
    final line = s * 0.035;
    final color = boxColor(box);
    final h = box == BoxType.cake ? s * 0.5 : s * 0.42;
    final w = box == BoxType.cake ? s * 0.84 : s * 0.7;
    final body = Rect.fromCenter(center: c.translate(0, s * 0.14), width: w, height: h);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(s * 0.03)), fill(color));
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(s * 0.03)), stroke(outline, line));
    if (box == BoxType.cake) {
      final window = Rect.fromCenter(center: body.center, width: w * 0.5, height: h * 0.45);
      canvas.drawRRect(RRect.fromRectAndRadius(window, Radius.circular(s * 0.04)), fill(const Color(0xFFDFF1F7)));
      canvas.drawRRect(RRect.fromRectAndRadius(window, Radius.circular(s * 0.04)), stroke(outline, line * 0.7));
    }
    final lid = open
        ? Rect.fromLTWH(body.left - s * 0.02, body.top - s * 0.26, w + s * 0.04, s * 0.12)
        : Rect.fromLTWH(body.left - s * 0.03, body.top - s * 0.1, w + s * 0.06, s * 0.13);
    final lidColor = Color.lerp(color, const Color(0xFF000000), 0.06)!;
    canvas.drawRRect(RRect.fromRectAndRadius(lid, Radius.circular(s * 0.03)), fill(lidColor));
    canvas.drawRRect(RRect.fromRectAndRadius(lid, Radius.circular(s * 0.03)), stroke(outline, line));
    if (box == BoxType.gift) {
      const ribbon = AppColors.butter;
      canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, body.center.dy), width: s * 0.1, height: h), fill(ribbon));
      canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, lid.center.dy), width: s * 0.1, height: lid.height), fill(ribbon));
      final knot = Offset(c.dx, lid.top);
      for (final dir in const [-1.0, 1.0]) {
        final loop = Path()
          ..moveTo(knot.dx, knot.dy)
          ..quadraticBezierTo(knot.dx + dir * s * 0.24, knot.dy - s * 0.2, knot.dx + dir * s * 0.18, knot.dy + s * 0.02)
          ..close();
        canvas.drawPath(loop, fill(ribbon));
        canvas.drawPath(loop, stroke(outline, line * 0.8));
      }
      canvas.drawCircle(knot, s * 0.05, fill(ribbon));
      canvas.drawCircle(knot, s * 0.05, stroke(outline, line * 0.8));
    } else {
      // Nhãn lá nhỏ của tiệm.
      final tag = Offset(c.dx, box == BoxType.cake ? body.bottom - h * 0.14 : body.center.dy);
      canvas.drawOval(Rect.fromCenter(center: tag, width: s * 0.16, height: s * 0.08), fill(const Color(0xFF7BC47F)));
      canvas.drawOval(Rect.fromCenter(center: tag, width: s * 0.16, height: s * 0.08), stroke(outline, line * 0.6));
    }
  }

  // ------------------------------------------------------------------ Kem (mẫu màu)

  static void paintFrostingSwatch(Canvas canvas, Rect rect, FrostingId frosting) {
    final r = square(rect);
    final s = r.width;
    final c = r.center;
    final color = frostingColor(frosting);
    final edge = Color.lerp(color, outline, 0.45)!;
    // Ba tầng kem xoắn.
    final layers = [
      Rect.fromCenter(center: c.translate(0, s * 0.18), width: s * 0.8, height: s * 0.3),
      Rect.fromCenter(center: c.translate(0, s * 0.0), width: s * 0.6, height: s * 0.26),
      Rect.fromCenter(center: c.translate(0, -s * 0.15), width: s * 0.38, height: s * 0.22),
    ];
    for (final l in layers) {
      canvas.drawOval(l, fill(color));
      canvas.drawOval(l, stroke(edge, s * 0.035));
    }
    final tip = Path()
      ..moveTo(c.dx - s * 0.1, c.dy - s * 0.2)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.42, c.dx + s * 0.06, c.dy - s * 0.38)
      ..quadraticBezierTo(c.dx + s * 0.04, c.dy - s * 0.26, c.dx + s * 0.1, c.dy - s * 0.2)
      ..close();
    canvas.drawPath(tip, fill(color));
    canvas.drawPath(tip, stroke(edge, s * 0.035));
    canvas.drawCircle(c.translate(-s * 0.12, -s * 0.02), s * 0.04, fill(const Color(0x88FFFFFF)));
  }

  // ------------------------------------------------------------------ Tiền tệ, sao

  static void coin(Canvas canvas, Rect rect) {
    final r = square(rect);
    final s = r.width;
    canvas.drawOval(r.deflate(s * 0.04), fill(const Color(0xFFF2B33D)));
    canvas.drawOval(r.deflate(s * 0.04), stroke(outline, s * 0.07));
    canvas.drawOval(r.deflate(s * 0.2), fill(AppColors.butter));
    canvas.drawOval(r.deflate(s * 0.2), stroke(const Color(0xFFD08B1C), s * 0.05));
    // Chiếc lá nhỏ (biểu tượng Sugarleaf) giữa đồng xu.
    final c = r.center;
    final leaf = Path()
      ..moveTo(c.dx - s * 0.14, c.dy + s * 0.12)
      ..quadraticBezierTo(c.dx - s * 0.16, c.dy - s * 0.14, c.dx + s * 0.14, c.dy - s * 0.12)
      ..quadraticBezierTo(c.dx + s * 0.12, c.dy + s * 0.14, c.dx - s * 0.14, c.dy + s * 0.12)
      ..close();
    canvas.drawPath(leaf, fill(const Color(0xFFD08B1C)));
  }

  static void gem(Canvas canvas, Rect rect) {
    final r = square(rect);
    final s = r.width;
    final c = r.center;
    final top = c.dy - s * 0.18;
    final mid = c.dy - s * 0.02;
    final outlinePath = Path()
      ..moveTo(c.dx - s * 0.22, top)
      ..lineTo(c.dx + s * 0.22, top)
      ..lineTo(c.dx + s * 0.4, mid)
      ..lineTo(c.dx, c.dy + s * 0.38)
      ..lineTo(c.dx - s * 0.4, mid)
      ..close();
    canvas.drawPath(outlinePath, fill(const Color(0xFF7FD3E0)));
    final crown = Path()
      ..moveTo(c.dx - s * 0.22, top)
      ..lineTo(c.dx + s * 0.22, top)
      ..lineTo(c.dx + s * 0.4, mid)
      ..lineTo(c.dx - s * 0.4, mid)
      ..close();
    canvas.drawPath(crown, fill(const Color(0xFFB5EBF2)));
    final facets = stroke(const Color(0xFF3E98A8), s * 0.03);
    canvas.drawLine(Offset(c.dx - s * 0.4, mid), Offset(c.dx + s * 0.4, mid), facets);
    canvas.drawLine(Offset(c.dx - s * 0.12, mid), Offset(c.dx, c.dy + s * 0.38), facets);
    canvas.drawLine(Offset(c.dx + s * 0.12, mid), Offset(c.dx, c.dy + s * 0.38), facets);
    canvas.drawLine(Offset(c.dx - s * 0.22, top), Offset(c.dx - s * 0.12, mid), facets);
    canvas.drawLine(Offset(c.dx + s * 0.22, top), Offset(c.dx + s * 0.12, mid), facets);
    canvas.drawPath(outlinePath, stroke(outline, s * 0.06));
  }

  /// Sao 5 cánh; [filled] = false → sao rỗng (xám kem).
  static void star(Canvas canvas, Rect rect, {bool filled = true}) {
    final r = square(rect);
    final s = r.width;
    final c = r.center.translate(0, s * 0.03);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? s * 0.46 : s * 0.2;
      final p = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill(filled ? AppColors.butter : const Color(0xFFEADBC8)));
    canvas.drawPath(path, stroke(filled ? outline : const Color(0xFFC9B39C), s * 0.06));
    if (filled) canvas.drawCircle(c.translate(-s * 0.08, -s * 0.08), s * 0.05, fill(const Color(0xAAFFFFFF)));
  }
}
