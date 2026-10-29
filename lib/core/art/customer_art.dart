import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/ids.dart';
import 'art_sprites.dart';
import 'characters/character_sprites.dart';
import 'characters/expression.dart';

export 'characters/expression.dart';

/// Vẽ khách và nhân vật truyện — CHỈ bằng ảnh minh hoạ vẽ tay (`CharacterSprites`,
/// `assets/characters/<id>_<expr>.webp`; người kể truyện = ảnh sổ công thức của `ArtSprites`).
///
/// Không có hình nhân vật vẽ bằng code: ảnh chưa nạp xong hoặc thiếu thì không vẽ gì (trong suốt). UI dùng
/// [repaint] làm `repaint` của CustomPainter để ảnh hiện ra ngay khi nạp xong, và gọi các hàm `preload…`
/// (khởi động: [preloadCast]; đầu ngày: [preload], [preloadMochi]; trước cảnh truyện: [preloadSpeakers]) để
/// ảnh có sẵn trước khi cần.
///
/// Nhân vật vẽ trong khung dọc 3:4 đặt giữa `rect`: [paint] vẽ toàn thân (cả ảnh), [paintSpeaker] vẽ nửa trên
/// ảnh (đầu + vai).
abstract final class CustomerArt {
  /// Số kiểu ảnh khách thường (`regular_00..14`) và khách VIP (`vip_00..02`).
  static const regularSprites = 15;
  static const vipSprites = 3;

  /// Báo khi có ảnh nhân vật (hoặc ảnh sổ của người kể, `ArtSprites`) mới nạp xong — truyền vào
  /// `CustomPaint`/`CustomPainter(repaint: ...)`.
  static Listenable get repaint => _repaint;
  static final _repaint = Listenable.merge([CharacterSprites.changes, ArtSprites.changes]);

  /// Nạp sẵn (không chặn) ảnh của những người nói trong một cảnh truyện: nét mặt hội thoại của nhân vật, ảnh sổ
  /// công thức nếu có người kể. Gọi trước khi mở cảnh truyện, vd. `preloadSpeakers(scene.lines.map((l) => l.speaker))`.
  static Future<void> preloadSpeakers(Iterable<Speaker> speakers) {
    final set = speakers.toSet();
    return Future.wait([
      CharacterSprites.preload([
        for (final s in set)
          if (speakerSpriteId(s) case final id?) (id, spriteExpr(speakerExpression(s))),
      ]),
      if (set.contains(Speaker.narrator)) ArtSprites.preload(narratorArts),
    ]);
  }

  /// Nạp sẵn (không chặn) 4 nét mặt của dàn cố định: Mai, ông Hòa, Linh, Kenji + ảnh sổ của người kể. Gọi khi
  /// khởi động.
  static Future<void> preloadCast() => Future.wait([
        CharacterSprites.preload([
          for (final id in const ['mai', 'hoa', 'linh', 'kenji'])
            for (final e in CharacterSprites.expressions) (id, e),
        ]),
        ArtSprites.preload(narratorArts),
      ]);

  /// Nạp sẵn (không chặn) ảnh của các khách trong ngày với mọi tâm trạng khi phục vụ — nét mặt
  /// `neutral` của mọi khách trước. Gọi khi bắt đầu ngày.
  static Future<void> preload(Iterable<Customer> customers) {
    final list = customers.toList();
    return CharacterSprites.preload({
      for (final mood in CustomerMood.values)
        for (final c in list) (spriteId(c), spriteExpr(expressionFor(mood))),
    });
  }

  /// id ảnh vẽ tay của khách: bạn quen → `hoa`/`linh`/`kenji`; VIP → `vip_00..02`; còn lại → `regular_00..14`
  /// (theo `appearanceSeed`).
  static String spriteId(Customer c) => switch (c.kind) {
        CustomerKind.friend when c.friend != null => c.friend!.name,
        CustomerKind.vip => 'vip_${_two(c.appearanceSeed.abs() % vipSprites)}',
        _ => 'regular_${_two(c.appearanceSeed.abs() % regularSprites)}',
      };

  /// id ảnh nhân vật (`CharacterSprites`) của người nói; người kể (cuốn sổ) không có ảnh nhân vật — vẽ bằng ảnh đồ
  /// vật ([narratorBook] / `ArtSprites.book`).
  static String? speakerSpriteId(Speaker s) => switch (s) {
        Speaker.narrator => null,
        Speaker.mai => 'mai',
        Speaker.hoa => 'hoa',
        Speaker.linh => 'linh',
        Speaker.kenji => 'kenji',
      };

  /// Tên nét mặt trong tên file ảnh (`neutral`/`smile`/`joy`/`sad`).
  static String spriteExpr(Expression e) => switch (e) {
        Expression.neutral => 'neutral',
        Expression.smile => 'smile',
        Expression.joy => 'joy',
        Expression.sad => 'sad',
      };

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Nét mặt của khách theo tâm trạng: hài lòng → `joy` (nhắm mắt cười).
  static Expression expressionFor(CustomerMood mood) => switch (mood) {
        CustomerMood.neutral => Expression.neutral,
        CustomerMood.happy => Expression.joy,
        CustomerMood.sad => Expression.sad,
      };

  /// Khách (thường/VIP/bạn quen) với nét mặt theo [mood]. Ảnh chưa nạp → không vẽ gì.
  static void paint(Canvas canvas, Rect rect, Customer customer, {CustomerMood mood = CustomerMood.neutral}) =>
      _draw(canvas, rect, spriteId(customer), expressionFor(mood), bust: false);

  /// Nét mặt của người nói trong hội thoại truyện.
  static Expression speakerExpression(Speaker speaker) =>
      speaker == Speaker.kenji ? Expression.neutral : Expression.smile;

  /// Nhân vật trong hội thoại truyện (nửa trên ảnh). narrator → cuốn sổ công thức. Ảnh chưa nạp → không vẽ gì.
  static void paintSpeaker(Canvas canvas, Rect rect, Speaker speaker) {
    final id = speakerSpriteId(speaker);
    if (id == null) {
      _paintBook(canvas, rect);
    } else {
      _draw(canvas, rect, id, speakerExpression(speaker), bust: true);
    }
  }

  // ------------------------------------------------------------------ Mèo Mochi (khách ngày mưa)

  /// id ảnh vẽ tay của mèo Mochi: `assets/characters/mochi_<expr>.webp` (480×640 như ảnh nhân vật).
  static const mochiSpriteId = 'mochi';

  /// Nạp sẵn (không chặn) 4 nét mặt của Mochi. Gọi khi bắt đầu ngày mưa.
  static Future<void> preloadMochi() =>
      CharacterSprites.preload([for (final e in CharacterSprites.expressions) (mochiSpriteId, e)]);

  /// Mèo Mochi ngồi, toàn thân trong khung 3:4 giữa [rect] (như [paint]). Ảnh chưa nạp → không vẽ gì.
  static void paintMochi(Canvas canvas, Rect rect, {CustomerMood mood = CustomerMood.neutral}) =>
      _draw(canvas, rect, mochiSpriteId, expressionFor(mood), bust: false);

  // ------------------------------------------------------------------ Ảnh

  static void _draw(Canvas canvas, Rect rect, String sprite, Expression expr, {required bool bust}) {
    // Khung dọc tỉ lệ 3:4 đặt giữa rect.
    final w = math.min(rect.width, rect.height * 0.75);
    if (w <= 0) return;
    final image = CharacterSprites.image(sprite, spriteExpr(expr));
    if (image == null) return;
    _drawSprite(canvas, Rect.fromCenter(center: rect.center, width: w, height: w / 0.75), image, bust: bust);
  }

  static final _spritePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  /// Vẽ ảnh vẽ tay vừa khung 3:4 [frame]. [bust]: chỉ nửa trên ảnh (đầu + vai), cắt giữa theo tỉ lệ 3:4.
  /// Ảnh lệch tỉ lệ thì co vừa khung, căn giữa ngang, sát đáy.
  static void _drawSprite(Canvas canvas, Rect frame, Image image, {required bool bust}) {
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final src = bust
        ? Rect.fromLTWH((iw - math.min(iw, ih * 0.375)) / 2, 0, math.min(iw, ih * 0.375), ih / 2)
        : Rect.fromLTWH(0, 0, iw, ih);
    final k = math.min(frame.width / src.width, frame.height / src.height);
    final dst = Rect.fromLTWH(frame.center.dx - src.width * k / 2, frame.bottom - src.height * k, src.width * k, src.height * k);
    canvas.drawImageRect(image, src, dst, _spritePaint);
  }

  // ------------------------------------------------------------------ Sổ công thức (người kể)

  /// Ảnh riêng của người kể: sổ công thức mở, không chữ (`assets/art/items/narrator_book.webp`). Chưa có file
  /// (ArtSprites coi là thiếu) → dùng ảnh sổ đóng `ArtSprites.book`.
  static const narratorBook = ArtRef(ArtGroup.items, 'narrator_book');

  /// Ảnh có thể dùng cho người kể, theo thứ tự ưu tiên.
  static const narratorArts = [narratorBook, ArtSprites.book];

  /// Ảnh người kể đang dùng được: [narratorBook] nếu đã nạp; đang nạp → null (chờ, không nháy ảnh sổ cũ);
  /// thiếu hẳn → `ArtSprites.book`.
  static Image? narratorImage() => narratorBook.image ?? (narratorBook.isMissing ? ArtSprites.book.image : null);

  /// Sổ công thức: cả ảnh (không cắt nửa trên như nhân vật) trong ô vuông cạnh 86% bề rộng khung 3:4, căn giữa
  /// ngang, đáy ô cách đáy khung 10% chiều cao (thân sổ ≈ 76% khung, chừa chỗ cho phần đáy khung bị UI cắt);
  /// bóng mềm dưới sổ. Ảnh chưa nạp → không vẽ gì.
  static void _paintBook(Canvas canvas, Rect rect) {
    final w = math.min(rect.width, rect.height * 0.75);
    if (w <= 0) return;
    final image = narratorImage();
    if (image == null) return;
    final frame = Rect.fromCenter(center: rect.center, width: w, height: w / 0.75);
    final s = w * 0.86;
    final r = Rect.fromLTWH(frame.center.dx - s / 2, frame.bottom - frame.height * 0.1 - s, s, s);
    // Bóng dưới thân sổ (thân sổ trong ảnh kết thúc ở ~79% chiều cao ảnh).
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r.center.dx, r.top + s * 0.79), width: s * 0.78, height: s * 0.09),
      Paint()
        ..color = const Color(0x405A3E36)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025),
    );
    paintArt(canvas, r, image);
  }
}
