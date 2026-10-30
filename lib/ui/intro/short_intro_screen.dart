import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../common/navigation.dart';
import '../sugarleaf/sugarleaf.dart';
import 'intro_art.dart';

/// Intro ngắn mỗi lần mở app (sau khi đã xem cảnh mở đầu): tiệm (`shop_base.webp`) phóng chậm vào tủ kính + lấp
/// lánh, logo, dòng "Chạm để vào tiệm" nhấp nháy. Hết [duration] tự sang bản đồ; chạm bất kỳ lúc nào → bản đồ ngay.
/// Giảm chuyển động: ảnh đứng yên, không lấp lánh, chữ không nhấp nháy (vẫn tự sang sau [duration]).
class ShortIntroScreen extends StatefulWidget {
  const ShortIntroScreen({super.key});

  static const duration = Duration(seconds: 4);

  /// Bề ngang logo (đặt trên cao, chừa tủ kính ở giữa dưới).
  static const logoWidth = 330.0;

  @override
  State<ShortIntroScreen> createState() => _ShortIntroScreenState();
}

class _ShortIntroScreenState extends State<ShortIntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _seconds = IntroMapped(_c, (v) => v * ShortIntroScreen.duration.inMilliseconds / 1000);
  late final _sparkle = IntroSparklePainter(time: _seconds, region: IntroLayout.caseGlass, count: 12, seed: 0x5401);
  Timer? _timer;
  bool _left = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: ShortIntroScreen.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    _timer = Timer(ShortIntroScreen.duration, _enter);
    if (!slReduceMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _enter() {
    if (_left || !mounted) return;
    _left = true;
    _timer?.cancel();
    goToMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduce = slReduceMotion(context);
    final image = IntroImage(
      image: introSceneImage(context, IntroAssets.shop),
      fallback: const IntroPaperBackdrop(icon: 'storefront', seed: 0x5402),
    );
    final scene = reduce
        ? image
        : AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final u = Curves.easeOut.transform(_c.value);
              final s = 1.0 + 0.14 * u;
              final f = Offset.lerp(const Offset(640, 360), IntroLayout.caseCenter, u)!;
              final hw = 640 / s, hh = 360 / s;
              final fx = f.dx.clamp(hw, 1280 - hw), fy = f.dy.clamp(hh, 720 - hh);
              return Transform(
                transform: Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(640 - fx * s, 360 - fy * s, 0),
                child: child,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [image, RepaintBoundary(child: CustomPaint(painter: _sparkle, size: Size.infinite))],
            ),
          );
    final hintStyle = SLTextStyles.of(context).label.copyWith(fontSize: 24, color: SLColors.paper);
    final hint = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xA65A3E36),
        borderRadius: BorderRadius.circular(SLMetrics.radiusButton),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Text(l.introTapToEnter, key: const ValueKey('short-intro-hint'), style: hintStyle),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _enter();
      },
      child: GestureDetector(
        key: const ValueKey('short-intro'),
        behavior: HitTestBehavior.opaque,
        onTap: _enter,
        child: Semantics(
          button: true,
          label: l.introTapToEnter,
          onTap: _enter,
          child: ExcludeSemantics(
            child: ColoredBox(
              color: SLColors.cream,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: scene),
                  // Nền mờ nhẹ sau logo để chữ nổi trên ảnh.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.7,
                        colors: [Color(0x66FFF4E6), Color(0x00FFF4E6)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 28,
                    child: Center(child: IntroLogo(title: l.appTitle, width: ShortIntroScreen.logoWidth)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 56,
                    child: Center(
                      child: reduce
                          ? hint
                          : FadeTransition(
                              opacity: IntroMapped(_seconds, (t) => 0.7 + 0.3 * math.cos(t * math.pi * 1.2)),
                              child: hint,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
