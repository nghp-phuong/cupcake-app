import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../shop3d/shop3d_toasts.dart';

/// Nội dung một băng tên khu vực.
@immutable
class LocationBannerData {
  const LocationBannerData(this.id, this.text, this.subtitle);

  /// Tăng dần mỗi lần `show` (để hoạt ảnh chạy lại kể cả khi chữ trùng).
  final int id;
  final String text;

  /// Dòng phụ (vd. "Sắp mở"); null → không có.
  final String? subtitle;
}

/// Điều khiển băng tên: [show] hiện [duration] (~2 s) rồi tự ẩn; gọi lại thì thay băng cũ và tính giờ lại.
class LocationBannerController {
  LocationBannerController({this.duration = const Duration(seconds: 2)});

  final Duration duration;
  final ValueNotifier<LocationBannerData?> current =
      ValueNotifier<LocationBannerData?>(null);
  Timer? _timer;
  int _seq = 0;

  /// [text] = tên khu vực/tiệm đã dịch; [subtitle] = dòng phụ đã dịch (vd. `l.townComingSoon` cho lô "Sắp mở").
  void show(String text, {String? subtitle}) {
    _timer?.cancel();
    current.value = LocationBannerData(++_seq, text, subtitle);
    _timer = Timer(duration, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    current.value = null;
  }

  void dispose() {
    _timer?.cancel();
    current.dispose();
  }
}

/// Băng tên trượt xuống từ mép trên giữa màn hình. Không nhận chạm (cảnh bên dưới vẫn điều khiển được). Đặt làm
/// con của `Stack` phủ cảnh.
class LocationBanner extends StatelessWidget {
  const LocationBanner({super.key, required this.controller, this.top = 12});

  final LocationBannerController controller;
  final double top;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Positioned(
      top: top + pad.top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ValueListenableBuilder<LocationBannerData?>(
            valueListenable: controller.current,
            builder: (context, data, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.8),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: data == null
                  ? const SizedBox.shrink(key: ValueKey(-1))
                  : _BannerCard(key: ValueKey(data.id), data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({super.key, required this.data});

  final LocationBannerData data;

  @override
  Widget build(BuildContext context) {
    final s = Shop3dStyle.scaleOf(MediaQuery.sizeOf(context));
    final soon = data.subtitle != null;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: soon ? '${data.text}. ${data.subtitle}' : data.text,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560 * s),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 8 * s),
            decoration: Shop3dStyle.box(
              color: soon ? AppColors.cream : AppColors.butter,
              radius: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Shop3dStyle.title(context, 24 * s),
                ),
                if (soon)
                  Text(
                    data.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Shop3dStyle.body(16 * s, weight: FontWeight.w800),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
