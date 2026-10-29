import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/art/art_sprites.dart';
import 'paint/sl_icon_art.dart';
import 'sl_theme.dart';

export 'paint/sl_icon_art.dart' show kSLIconIds, slIconHasDrawing;

/// Nguồn hình của một icon (Gallery hiển thị).
enum SLIconSource { image, drawn, generic }

/// Điểm nối duy nhất tới ảnh icon vẽ tay (`assets/art/icons/<id>.webp`). Null = chưa có/chưa nạp → vẽ bằng code.
ui.Image? slIconImage(String id) => ArtSprites.icon(id).image;

SLIconSource slIconSource(String id) => slIconImage(id) != null
    ? SLIconSource.image
    : slIconHasDrawing(id)
        ? SLIconSource.drawn
        : SLIconSource.generic;

/// Icon vẽ tay theo [id] (xem [kSLIconIds]): ảnh vẽ tay nếu đã có, không thì hình vẽ bằng code theo nét tay
/// (nét mực run + tô màu nước, cache theo id/cỡ/màu). Tự vẽ lại khi ảnh nạp xong (`ArtSprites.changes`).
/// Không dùng Material Icons.
class SLIcon extends StatelessWidget {
  const SLIcon(this.id, {super.key, this.size = 28, this.color, this.dimmed = false, this.semanticLabel});

  final String id;
  final double size;

  /// Màu nét mực (mặc định: mực của theme).
  final Color? color;

  /// Mờ (trạng thái tắt).
  final bool dimmed;

  /// Nhãn đọc màn hình; null = icon trang trí (bỏ qua khi đọc).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SLIconPainter(id, color ?? SLTheme.of(context).ink, dimmed)),
    );
    return semanticLabel == null ? ExcludeSemantics(child: icon) : Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _SLIconPainter extends CustomPainter {
  _SLIconPainter(this.id, this.ink, this.dimmed) : super(repaint: ArtSprites.changes);

  final String id;
  final Color ink;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.shortestSide;
    final rect = Alignment.center.inscribe(Size.square(side), Offset.zero & size);
    final image = slIconImage(id);
    if (image != null) {
      paintArt(canvas, rect, image, opacity: dimmed ? 0.45 : 1);
      return;
    }
    final art = slIconArt(id, side, ink: ink, dimmed: dimmed);
    final k = side / art.size;
    canvas
      ..save()
      ..translate(rect.left, rect.top)
      ..scale(k)
      ..drawPicture(art.picture)
      ..restore();
  }

  @override
  bool shouldRepaint(_SLIconPainter old) => old.id != id || old.ink != ink || old.dimmed != dimmed;
}

/// Biểu tượng có ảnh vẽ tay: ảnh [art] khi đã nạp (vẽ to hơn một chút — [size] × 1,15 — trong cùng khoảng vì ảnh
/// nhiều chi tiết hơn icon); chưa có/thiếu → [SLIcon] theo [id]. Tự đổi khi ảnh nạp xong (`ArtSprites.changes`).
/// [dimmed] = mờ (nút khoá); [color] chỉ áp cho icon vẽ bằng code.
class SLArtIcon extends StatelessWidget {
  const SLArtIcon(this.art, this.id, {super.key, this.size = 28, this.color, this.dimmed = false});

  final ArtRef art;
  final String id;
  final double size;
  final Color? color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ArtSprites.changes,
        builder: (context, _) {
          if (art.image == null) return SLIcon(id, size: size, color: color, dimmed: dimmed);
          final image = SizedBox.square(dimension: size, child: CustomPaint(painter: _ArtIconPainter(art)));
          return dimmed ? Opacity(opacity: 0.5, child: image) : image;
        },
      );
}

class _ArtIconPainter extends CustomPainter {
  const _ArtIconPainter(this.art);

  final ArtRef art;

  @override
  void paint(Canvas canvas, Size size) {
    final image = art.image;
    if (image == null || size.isEmpty) return;
    paintArt(canvas, Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 1.15, height: size.height * 1.15), image);
  }

  @override
  bool shouldRepaint(_ArtIconPainter old) => old.art != art;
}
