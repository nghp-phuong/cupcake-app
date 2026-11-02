import 'package:flutter/widgets.dart';

import 'art_sprites.dart';

/// Ảnh nền gốc 1280×720 phủ cả khung, kể cả khi khung rộng hơn 16:9 (máy 20:9): ảnh nằm ở vùng 16:9 giữa
/// ([wideCenterRect]), hai bên lấp bằng soi gương dải mép ([paintWideBackdrop]). Khung 16:9 → vẽ ảnh như thường;
/// hẹp hơn 16:9 → cắt kiểu cover. Đặt widget này ở lớp nền phủ cả khung W×720 (ngoài `RefCenter`).
///
/// Chưa nạp xong / thiếu ảnh → hiện [fallback] (nếu có). [tint] phủ lên cả khung khi có ảnh (vd. kem mờ cho chữ).
class WideArtBackdrop extends StatelessWidget {
  const WideArtBackdrop({super.key, required this.art, this.tint, this.fallback});

  final ArtRef art;
  final Color? tint;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (fallback != null)
          ListenableBuilder(
            listenable: ArtSprites.changes,
            builder: (context, _) => art.image == null ? fallback! : const SizedBox.shrink(),
          ),
        CustomPaint(painter: WideBackdropPainter(art, tint: tint)),
      ],
    );
  }
}

/// Painter của [WideArtBackdrop]; vẽ lại khi [ArtSprites.changes] báo có ảnh mới.
class WideBackdropPainter extends CustomPainter {
  WideBackdropPainter(this.art, {this.tint}) : super(repaint: ArtSprites.changes);

  final ArtRef art;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final image = art.image;
    if (image == null || size.isEmpty) return;
    final full = Offset.zero & size;
    final center = wideCenterRect(size);
    if (center.width < size.width) {
      paintWideBackdrop(canvas, image, center1280: center, full: full);
    } else {
      paintArt(canvas, full, image, fit: BoxFit.cover);
    }
    if (tint != null) canvas.drawRect(full, Paint()..color = tint!);
  }

  @override
  bool shouldRepaint(WideBackdropPainter oldDelegate) => oldDelegate.art != art || oldDelegate.tint != tint;
}
