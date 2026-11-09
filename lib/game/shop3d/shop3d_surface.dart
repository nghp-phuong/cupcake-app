import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion_flutter.dart' show ThermionViewer, ThermionWidgetInternal;
// ignore: implementation_imports
import 'package:thermion_flutter/src/widgets/src/thermion_widget_internal/surface_widget_builder.dart';

import 'shop3d_texture_watch.dart';

/// Ảnh 3D của [viewer], thay `ThermionWidget`: cùng cách cấp texture (`ThermionWidgetInternal` + bộ dựng bề mặt của
/// thermion) và cùng việc khi có texture (phép chiếu theo tỉ lệ texture, giữ near / far / tiêu cự; viewport = cỡ
/// texture), thêm:
/// - web: lần xin texture hỏng (canvas chưa vào DOM — xem [Shop3dTextureWatch]) → dựng lại để xin lại, nhịp 0,5 s;
/// - [onTexture]: báo mỗi lần có texture (màn chủ chờ lần đầu rồi mới hiện cảnh).
///
/// Màn chủ giữ cấu trúc cây phía trên widget này cố định (kể cả khi đổi tỉ lệ vẽ / cỡ cửa sổ): bị gỡ rồi dựng lại là
/// platform view mới, canvas lại rời DOM một lúc.
class Shop3dSurface extends StatefulWidget {
  const Shop3dSurface({super.key, required this.viewer, this.onTexture});

  final ThermionViewer viewer;

  /// Texture vừa được cấp (lần đầu, đổi cỡ) và phép chiếu / viewport đã đặt theo nó.
  final VoidCallback? onTexture;

  @override
  State<Shop3dSurface> createState() => _Shop3dSurfaceState();
}

class _Shop3dSurfaceState extends State<Shop3dSurface> {
  static const _period = Duration(milliseconds: 500);

  final _watch = Shop3dTextureWatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Native: Texture của Flutter không phụ thuộc DOM — không cần xin lại.
    if (kIsWeb) _timer = Timer.periodic(_period, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Còn thiếu texture → dựng lại: `ThermionWidgetInternal` thấy chưa có texture thì xin lại (100 ms sau).
  void _tick() {
    if (!mounted || !_watch.tick()) return;
    debugPrint('Shop3dSurface: texture not allocated, retry ${_watch.retries}');
    setState(() {});
  }

  Future<void> _onTexture(int width, int height) async {
    _watch.got(width, height);
    final view = widget.viewer.view;
    final camera = await view.getCamera();
    await camera.setLensProjection(
      near: await camera.getNear(),
      far: await camera.getCullingFar(),
      focalLength: await camera.getFocalLength(),
      aspect: width / height,
    );
    await view.setViewport(width, height);
    if (mounted) widget.onTexture?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      _watch.want((constraints.maxWidth * dpr).ceil(), (constraints.maxHeight * dpr).ceil());
      return ThermionWidgetInternal(
        view: widget.viewer.view,
        surfaceWidgetBuilder: surfaceWidgetBuilder,
        onTextureUpdated: (d) {
          if (d != null) unawaited(_onTexture(d.width, d.height));
        },
      );
    });
  }
}
