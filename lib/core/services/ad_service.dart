import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../constants.dart';
import '../economy.dart';
import '../game_state.dart';
import '../models/ids.dart';

/// Quảng cáo. Rewarded chỉ khi người chơi bấm (tối đa [Economy.maxRewardedPerDay]/ngày lịch, chung mọi chỗ);
/// interstitial chỉ khi rời màn kết quả (GĐ6 §3), không bao giờ trong lúc chơi / thẻ Sẵn sàng / hướng dẫn / cảnh mở
/// đầu. Việc trao thưởng do bên gọi làm.
abstract class AdService {
  /// rewardedToday < [Economy.maxRewardedPerDay].
  bool canShowRewarded();

  /// true = xem xong; TỰ ghi đếm vào GameState.
  Future<bool> showRewarded(BuildContext context, AdPlacement placement);

  /// Theo `GameState.shouldShowInterstitialAfterResult`.
  bool shouldShowInterstitial({required bool watchedRewardedHere, required bool unlockedChapter});

  /// Gọi khi rời màn kết quả (về bản đồ / màn tiếp / chơi lại), SAU `GameState.registerLevelPlayEnded`. Hiện nếu
  /// [shouldShowInterstitial]; TỰ ghi `GameState.registerInterstitialShown`. Trả true nếu đã hiện.
  Future<bool> showInterstitial(
    BuildContext context, {
    required bool watchedRewardedHere,
    required bool unlockedChapter,
  });
}

/// Cách mở hộp thoại quảng cáo giả lập (không đóng được, tự đóng sau [duration]). Core chỉ có bản mặc định
/// [showSimulatedAdDialog]; `app.dart` (nơi ghép tầng) tiêm bản vẽ tay — core không import lib/ui.
typedef SimulatedAdPresenter = Future<void> Function(BuildContext context, Duration duration);

/// Bản mặc định: [SimulatedAdDialog] trong `showDialog`.
Future<void> showSimulatedAdDialog(BuildContext context, Duration duration) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SimulatedAdDialog(duration: duration),
    );

/// Quảng cáo giả lập: hộp thoại không đóng được, đếm ngược rồi tự đóng.
class FakeAdService implements AdService {
  FakeAdService(this.state, {this.duration = const Duration(seconds: 2), this.presenter = showSimulatedAdDialog});

  final GameState state;
  final Duration duration;

  /// Mở hộp thoại quảng cáo giả; chỉ đổi giao diện, việc đếm/giới hạn vẫn ở đây.
  final SimulatedAdPresenter presenter;

  @override
  bool canShowRewarded() => state.rewardedToday < Economy.maxRewardedPerDay;

  @override
  Future<bool> showRewarded(BuildContext context, AdPlacement placement) async {
    if (!canShowRewarded()) return false;
    await _showSimulated(context);
    state.registerRewardedShown();
    return true;
  }

  @override
  bool shouldShowInterstitial({required bool watchedRewardedHere, required bool unlockedChapter}) =>
      state.shouldShowInterstitialAfterResult(watchedRewardedHere: watchedRewardedHere, unlockedChapter: unlockedChapter);

  @override
  Future<bool> showInterstitial(
    BuildContext context, {
    required bool watchedRewardedHere,
    required bool unlockedChapter,
  }) async {
    if (!shouldShowInterstitial(watchedRewardedHere: watchedRewardedHere, unlockedChapter: unlockedChapter)) {
      return false;
    }
    await _showSimulated(context);
    state.registerInterstitialShown();
    return true;
  }

  Future<void> _showSimulated(BuildContext context) => presenter(context, duration);
}

/// Dựng phần nhìn của hộp thoại quảng cáo giả theo số giây còn lại.
typedef SimulatedAdViewBuilder = Widget Function(BuildContext context, int secondsLeft);

/// Hộp thoại quảng cáo giả lập: tiêu đề `adSimulatedTitle`, nội dung `adSimulatedBody`,
/// đếm ngược `adSimulatedClosing(seconds)`, hết giờ tự đóng (không đóng bằng nút Back).
/// [builder] thay phần nhìn (giữ nguyên đếm ngược/tự đóng); null = hộp thoại mặc định.
class SimulatedAdDialog extends StatefulWidget {
  const SimulatedAdDialog({super.key, required this.duration, this.builder});

  final Duration duration;
  final SimulatedAdViewBuilder? builder;

  @override
  State<SimulatedAdDialog> createState() => _SimulatedAdDialogState();
}

class _SimulatedAdDialogState extends State<SimulatedAdDialog> {
  late int _seconds = (widget.duration.inMilliseconds / 1000).ceil();
  Timer? _tick;
  Timer? _close;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _seconds > 1) setState(() => _seconds--);
    });
    _close = Timer(widget.duration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.builder;
    return PopScope(canPop: false, child: custom != null ? custom(context, _seconds) : _defaultView(context));
  }

  Widget _defaultView(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.adSimulatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 420,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.caramel, width: 2),
            ),
            alignment: Alignment.center,
            child: const SizedBox.square(dimension: 72, child: CustomPaint(painter: _PlayPainter())),
          ),
          const SizedBox(height: 16),
          Text(l.adSimulatedBody, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            l.adSimulatedClosing(_seconds),
            style: const TextStyle(color: AppColors.caramel, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Nút "phát" tròn nét mực (thay Material Icons ở hộp thoại mặc định).
class _PlayPainter extends CustomPainter {
  const _PlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final ink = Paint()
      ..color = AppColors.chocolate
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(c, s * 0.44, ink);
    final tri = Path()
      ..moveTo(c.dx - s * 0.12, c.dy - s * 0.18)
      ..lineTo(c.dx + s * 0.2, c.dy)
      ..lineTo(c.dx - s * 0.12, c.dy + s * 0.18)
      ..close();
    canvas
      ..drawPath(tri, Paint()..color = AppColors.butter)
      ..drawPath(tri, ink);
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) => false;
}
