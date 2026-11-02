import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/art/art_paint.dart';
import '../../core/constants.dart';
import '../../core/ref_frame.dart';

/// Phần nội dung đã được đặt vào vùng rộng 1280 ở giữa khung rộng (vd. thân màn phụ dưới thanh gỗ): đặt lại
/// [RefMetrics] chuẩn và `MediaQuery` 1280×720 không padding cho cây con — widget bên trong (dialog con, [RefCenter],
/// phần tử đọc `MediaQuery.padding`) cư xử như khung 1280 cũ. Khung 1280 → trả thẳng [child].
class RefContent extends StatelessWidget {
  const RefContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!RefMetrics.of(context).isWide) return child;
    final inner = MediaQuery.of(context).copyWith(
      size: kRefSize,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
    );
    return RefScope(metrics: RefMetrics.standard, child: MediaQuery(data: inner, child: child));
  }
}

/// Vùng nguồn của ảnh cỡ [image] khi vẽ kiểu `BoxFit.cover` (căn giữa) vào khung cỡ [dst].
Rect coverSourceRect(Size image, Size dst) =>
    Alignment.center.inscribe(applyBoxFit(BoxFit.cover, image, dst).source, Offset.zero & image);

/// Ảnh nền ([ImageProvider], vd. ảnh bản đồ / cảnh intro) cho vùng rộng hơn 16:9: ảnh vẽ kiểu cover vào vùng 16:9
/// giữa ([wideCenterRect]), hai bên lấp bằng soi gương dải mép ảnh ([paintWideBackdrop]). Tự nghe [ImageStream] để
/// lấy `ui.Image` (cùng provider với `Image` → dùng chung bộ nhớ đệm ảnh). Chưa nạp / lỗi → [fallback].
class WideImageBackdrop extends StatefulWidget {
  const WideImageBackdrop({super.key, required this.image, required this.fallback});

  final ImageProvider image;
  final Widget fallback;

  @override
  State<WideImageBackdrop> createState() => _WideImageBackdropState();
}

class _WideImageBackdropState extends State<WideImageBackdrop> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(_onImage, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(WideImageBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream != null && stream.key == _stream!.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool sync) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return widget.fallback;
    return CustomPaint(painter: _WideImagePainter(info.image), size: Size.infinite);
  }
}

class _WideImagePainter extends CustomPainter {
  const _WideImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = wideCenterRect(size);
    final src = coverSourceRect(Size(image.width.toDouble(), image.height.toDouble()), center.size);
    paintWideBackdrop(canvas, image, center1280: center, full: Offset.zero & size, src: src);
  }

  @override
  bool shouldRepaint(_WideImagePainter oldDelegate) => !identical(oldDelegate.image, image);
}
