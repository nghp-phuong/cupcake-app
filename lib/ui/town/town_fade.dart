import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shop3d/shop3d_toasts.dart';

/// Điều khiển lớp mờ đen chuyển cảnh (vào/ra tiệm, đổi quận). [fadeOut] = tối dần (0,4 s) → cảnh được phép đổi
/// khi Future hoàn tất; [fadeIn] = sáng dần (0,4 s). Tối quá [openingDelay] mà chưa [fadeIn] thì [showOpening]
/// bật (hiện "Đang mở cửa…"). Gọi chồng: lệnh mới thay lệnh cũ (Future cũ hoàn tất ngay), đi tiếp từ độ mờ hiện tại.
class TownFadeController {
  static const Duration duration = Duration(milliseconds: 400);
  static const Duration openingDelay = Duration(seconds: 1);

  /// 0 = trong suốt, 1 = đen hoàn toàn.
  final ValueNotifier<double> opacity = ValueNotifier<double>(0);

  /// Chữ "Đang mở cửa…" (chỉ bật khi đã tối hoàn toàn quá [openingDelay]).
  final ValueNotifier<bool> showOpening = ValueNotifier<bool>(false);

  Ticker? _ticker;
  Completer<void>? _done;
  Timer? _textTimer;
  bool _disposed = false;

  Future<void> fadeOut() => _run(1);

  Future<void> fadeIn() => _run(0);

  Future<void> _run(double target) {
    _cancelRun();
    _textTimer?.cancel();
    _textTimer = null;
    if (target == 0) showOpening.value = false;
    final begin = opacity.value;
    final done = Completer<void>();
    _done = done;
    if (_disposed || begin == target) {
      _finish(target);
      return done.future;
    }
    final total = duration * (target - begin).abs();
    _ticker = Ticker((elapsed) {
      final t = (elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
      opacity.value = begin + (target - begin) * t;
      if (t >= 1) _finish(target);
    })..start();
    return done.future;
  }

  void _finish(double target) {
    opacity.value = target;
    _ticker?.dispose();
    _ticker = null;
    if (target == 1 && !_disposed) {
      _textTimer = Timer(openingDelay, () {
        _textTimer = null;
        if (opacity.value == 1) showOpening.value = true;
      });
    }
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  void _cancelRun() {
    _ticker?.dispose();
    _ticker = null;
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  void dispose() {
    _disposed = true;
    _cancelRun();
    _textTimer?.cancel();
    opacity.dispose();
    showOpening.dispose();
  }
}

/// Lớp phủ đen của [TownFadeController]: đặt trên cùng `Stack` của cảnh. Khi đang tối nó nuốt mọi chạm; trong suốt
/// hẳn thì không chặn gì. Chỉ phần này dựng lại theo độ mờ (RepaintBoundary).
class TownFadeLayer extends StatelessWidget {
  const TownFadeLayer({super.key, required this.controller});

  final TownFadeController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Positioned.fill(
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: controller.opacity,
          builder: (context, o, _) {
            if (o <= 0) return const SizedBox.shrink();
            return AbsorbPointer(
              child: ColoredBox(
                color: Color.fromRGBO(0, 0, 0, o),
                child: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: controller.showOpening,
                    builder: (context, show, _) => show
                        ? Text(
                            l.townOpening,
                            style: Shop3dStyle.title(
                              context,
                              26,
                              color: AppColors.cream,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
