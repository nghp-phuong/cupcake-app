import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/navigation.dart';
import '../sugarleaf/sugarleaf.dart';
import 'intro_art.dart';

/// Cảnh mở đầu (~22 giây, 4 cảnh nối nhau bằng mờ chéo 400ms): (1) bếp buổi sáng — phóng chậm, tia nắng, bụi nắng,
/// hơi nước từ lò; (2) tủ bánh của bà — máy quay lia sang rồi phóng vào tủ kính (2 lớp: nền + đèn), lấp lánh trên
/// kính; (3) cửa tiệm — Mai đi bộ từ mép trái tới trước cửa (đổi khung bước chân), với tay lật bảng "Mở cửa",
/// chuông lắc + tiếng chuông, Mai quay ra cười; (4) logo.
///
/// Nút **Bỏ qua** luôn hiện. Xong / bỏ qua → `markIntroSeen`; nếu có màn bên dưới (mở lại từ Cài đặt) thì quay về,
/// không thì vào thẳng màn đầu tiên (thẻ "Sẵn sàng" → hướng dẫn trong màn). Giảm chuyển động: cảnh ngắn hơn, không
/// lia/phóng, không hạt.
///
/// Ảnh của cả 4 cảnh được nạp trước khi chạy (chờ tối đa [preloadWait]); thiếu ảnh → nền giấy + chữ.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  /// Thời lượng từng cảnh (giây).
  static const sceneSeconds = [6.0, 6.0, 7.0, 3.0];

  /// Thời lượng từng cảnh khi máy bật giảm chuyển động.
  static const reducedSceneSeconds = [2.5, 2.5, 3.0, 2.0];

  /// Mờ chéo giữa hai cảnh (giây).
  static const crossFade = 0.4;

  /// Chờ nạp ảnh tối đa chừng này rồi chạy luôn (ảnh nạp muộn vẫn hiện khi xong).
  static const preloadWait = Duration(milliseconds: 1500);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

/// Mốc của cảnh 3 (giây trong cảnh), thường / giảm chuyển động.
class _DoorBeats {
  const _DoorBeats({required this.maiIn, required this.flipAt, required this.flipLen, required this.bellAt});

  /// Mai đi tới cửa xong (đi đều từ 0 tới mốc này); 0 = đứng sẵn trước cửa (giảm chuyển động).
  final double maiIn;
  final double flipAt;
  final double flipLen;

  /// Chuông rung (+ tiếng, Mai đổi vẻ mặt vui).
  final double bellAt;

  static const normal = _DoorBeats(maiIn: 2.5, flipAt: 2.6, flipLen: 0.6, bellAt: 3.4);
  static const reduced = _DoorBeats(maiIn: 0, flipAt: 0.6, flipLen: 0.3, bellAt: 1.2);
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late List<double> _durations;
  late List<double> _starts;
  late double _total;
  late bool _reduce;
  bool _configured = false;
  bool _started = false;
  bool _done = false;
  bool _bellRung = false;
  Timer? _preloadTimer;

  /// Có ảnh bước chân thứ hai (`mai_walk_b`): đổi khung a ↔ b; không có → chỉ walk_a + nhún/nghiêng theo bước.
  bool _hasWalkB = false;

  /// Cảnh đang có trong cây (đang hiện hoặc đang mờ vào).
  int _first = 0;
  int _last = 0;

  _DoorBeats get _beats => _reduce ? _DoorBeats.reduced : _DoorBeats.normal;

  double get _t => _c.value * _total;

  @override
  void initState() {
    super.initState();
    // `preserve`: khi máy bật giảm chuyển động, AnimationController mặc định chạy nhanh gấp ~20 lần → cảnh rút gọn
    // vụt qua trong nửa giây. Thời lượng rút gọn đã tự chọn ở [IntroScreen.reducedSceneSeconds].
    _c = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve)
      ..addListener(_onTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    _reduce = slReduceMotion(context);
    _durations = _reduce ? IntroScreen.reducedSceneSeconds : IntroScreen.sceneSeconds;
    var s = 0.0;
    _starts = [
      for (final d in _durations) (s += d) - d,
    ];
    _total = s;
    _c.duration = Duration(milliseconds: (_total * 1000).round());
    _preload();
  }

  /// Nạp trước ảnh của mọi cảnh (bất đồng bộ); chạy khi xong hoặc hết [IntroScreen.preloadWait].
  void _preload() {
    final images = [
      introSceneImage(context, IntroAssets.kitchen),
      introSceneImage(context, IntroAssets.shop),
      introSceneImage(context, IntroAssets.door),
      introObjectImage(context, IntroAssets.openSign, IntroLayout.signSize.width),
      introObjectImage(context, IntroAssets.doorBell, IntroLayout.bellSize.width),
      for (final pose in IntroAssets.maiPoses) introObjectImage(context, pose, IntroLayout.maiSize.width),
      introObjectImage(context, IntroAssets.emblem, _logoWidth),
    ];
    // Ảnh bước chân thứ hai có thể chưa có: nạp được thì dùng (đổi khung), không thì nhún theo bước.
    var walkBFailed = false;
    precacheImage(
      introObjectImage(context, IntroAssets.maiWalkB, IntroLayout.maiSize.width),
      context,
      onError: (_, _) => walkBFailed = true,
    ).whenComplete(() {
      if (!walkBFailed && mounted) setState(() => _hasWalkB = true);
    });
    _preloadTimer = Timer(IntroScreen.preloadWait, _begin);
    Future.wait([for (final i in images) precacheImage(i, context, onError: (_, _) {})]).whenComplete(_begin);
  }

  void _begin() {
    _preloadTimer?.cancel();
    if (_started || _done || !mounted) return;
    _started = true;
    _c.forward();
  }

  @override
  void dispose() {
    _preloadTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onTick() {
    final t = _t;
    // Cảnh i có trong cây từ (đầu cảnh − mờ chéo) tới hết cảnh; chỉ dựng lại khi tập cảnh đổi (~8 lần cả intro).
    var first = 0;
    while (first < _durations.length - 1 && t >= _starts[first] + _durations[first]) {
      first++;
    }
    var last = first;
    while (last < _durations.length - 1 && t >= _starts[last + 1] - IntroScreen.crossFade) {
      last++;
    }
    if (first != _first || last != _last) {
      setState(() {
        _first = first;
        _last = last;
      });
    }
    if (!_bellRung && t >= _starts[2] + _beats.bellAt) {
      _bellRung = true;
      AppScope.read(context).audio.success();
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _preloadTimer?.cancel();
    _c.stop();
    final services = AppScope.read(context);
    services.state.markIntroSeen();
    final nav = Navigator.of(context);
    // Mở lại từ Cài đặt → về Cài đặt. Lần đầu (màn khởi động) → vào thẳng màn đầu tiên.
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    final levels = services.levels.levels;
    if (levels.isEmpty) {
      goToMenu(context);
    } else {
      nav.pushReplacementNamed(AppRoutes.level, arguments: LevelArgs(levels.first.id));
    }
  }

  static const _logoWidth = 460.0;

  /// Giây trong cảnh [i] (âm khi chưa tới).
  Animation<double> _local(int i) => IntroMapped(_c, (v) => v * _total - _starts[i]);

  /// Độ mờ khi cảnh [i] mờ vào (cảnh đầu mờ vào từ nền giấy).
  Animation<double> _fadeIn(int i) => IntroMapped(_c, (v) {
        final t = v * _total;
        final from = i == 0 ? 0.0 : _starts[i] - IntroScreen.crossFade;
        return Curves.easeInOut.transform(((t - from) / IntroScreen.crossFade).clamp(0.0, 1.0));
      });

  Widget _scene(int i) {
    final time = _local(i);
    return switch (i) {
      0 => _KitchenScene(time: time, reduce: _reduce),
      1 => _CaseScene(time: time, reduce: _reduce, duration: _durations[1]),
      2 => _DoorScene(time: time, reduce: _reduce, beats: _beats, walkFrames: _hasWalkB),
      _ => _LogoScene(time: time, reduce: _reduce, logoWidth: _logoWidth),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lines = [l.introLineKitchen, l.introLineCase, l.introLineDoor, null];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Semantics(
        label: l.introSemantics,
        child: ColoredBox(
          color: SLColors.cream,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IntroPaperBackdrop(seed: 0x1A71),
              for (var i = _first; i <= _last; i++)
                FadeTransition(
                  key: ValueKey('intro-scene-$i'),
                  opacity: _fadeIn(i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: _scene(i)),
                      if (lines[i] case final text?)
                        _Subtitle(text: text, time: _local(i), duration: _durations[i]),
                    ],
                  ),
                ),
              Positioned(
                top: 20,
                right: 24,
                child: SLButton(
                  key: const ValueKey('intro-skip'),
                  label: l.storySkip,
                  icon: 'skip',
                  variant: SLButtonVariant.secondary,
                  height: 52,
                  fontSize: 18,
                  onPressed: _finish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================== Máy quay

/// Ma trận đưa điểm [focal] (toạ độ ảnh 1280×720) về giữa khung, phóng [scale] (≥ 1); tiêu điểm bị kẹp để mép ảnh
/// không lộ ra.
Matrix4 _camera(Offset focal, double scale) {
  final hw = 640 / scale, hh = 360 / scale;
  final fx = focal.dx.clamp(hw, 1280 - hw), fy = focal.dy.clamp(hh, 720 - hh);
  return Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(640 - fx * scale, 360 - fy * scale, 0);
}

double _ease(double u) => Curves.easeInOut.transform(u.clamp(0.0, 1.0));

// ==================================================================== Cảnh 1: bếp

class _KitchenScene extends StatefulWidget {
  const _KitchenScene({required this.time, required this.reduce});

  final Animation<double> time;
  final bool reduce;

  @override
  State<_KitchenScene> createState() => _KitchenSceneState();
}

class _KitchenSceneState extends State<_KitchenScene> {
  late final _steam = IntroSteamPainter(time: widget.time);
  late final _dust = IntroDustPainter(time: widget.time);
  /// Tia nắng nhấp nháy chậm: độ sáng vào alpha của Paint, vẽ cùng lớp với ảnh nền (không lớp mờ).
  late final _rays = IntroRaysPainter(
    brightness: widget.reduce
        ? const AlwaysStoppedAnimation(0.7)
        : IntroMapped(widget.time, (t) => 0.62 + 0.28 * math.sin(t * 1.25)),
  );

  @override
  Widget build(BuildContext context) {
    final image = IntroImage(
      image: introSceneImage(context, IntroAssets.kitchen),
      fallback: const IntroPaperBackdrop(icon: 'oven', seed: 0x1A72),
    );
    // Không RepaintBoundary: tia phải chung lớp vẽ với ảnh để cộng sáng lên ảnh.
    final rays = CustomPaint(painter: _rays, size: Size.infinite);
    final layers = Stack(
      fit: StackFit.expand,
      children: [
        image,
        rays,
        if (!widget.reduce) ...[
          RepaintBoundary(child: CustomPaint(painter: _steam, size: Size.infinite)),
          RepaintBoundary(child: CustomPaint(painter: _dust, size: Size.infinite)),
        ],
      ],
    );
    if (widget.reduce) return layers;
    // Phóng chậm 1.0 → 1.08 + trượt nhẹ sang trái (về phía lò).
    return AnimatedBuilder(
      animation: widget.time,
      builder: (context, child) {
        final u = _ease(widget.time.value / 6);
        return Transform(
          transform: _camera(Offset(660 - 60 * u, 370 - 10 * u), 1.0 + 0.08 * u),
          child: child,
        );
      },
      child: layers,
    );
  }
}

// ==================================================================== Cảnh 2: tủ bánh

class _CaseScene extends StatefulWidget {
  const _CaseScene({required this.time, required this.reduce, required this.duration});

  final Animation<double> time;
  final bool reduce;
  final double duration;

  @override
  State<_CaseScene> createState() => _CaseSceneState();
}

class _CaseSceneState extends State<_CaseScene> {
  late final _sparkle = IntroSparklePainter(time: widget.time, region: IntroLayout.caseGlass, count: 14);

  /// Lia sang tủ (0–3,2 giây), rồi phóng vào tủ kính.
  static (Offset, double) _shot(double t) {
    const s0 = 1.25, s1 = 1.6;
    final pan = _ease(t / 3.2);
    final zoom = _ease((t - 3.2) / 2.8);
    final f = Offset.lerp(const Offset(420, 330), const Offset(640, 420), pan)!;
    return (Offset.lerp(f, IntroLayout.caseCenter, zoom)!, s0 + (s1 - s0) * zoom);
  }

  @override
  Widget build(BuildContext context) {
    final image = IntroImage(
      image: introSceneImage(context, IntroAssets.shop),
      fallback: const IntroPaperBackdrop(icon: 'storefront', seed: 0x1A73),
    );
    const glow = RepaintBoundary(child: CustomPaint(painter: IntroLampGlowPainter(), size: Size.infinite));
    final sparkle = RepaintBoundary(child: CustomPaint(painter: _sparkle, size: Size.infinite));
    if (widget.reduce) {
      return Stack(fit: StackFit.expand, children: [image, glow]);
    }
    return AnimatedBuilder(
      animation: widget.time,
      builder: (context, _) {
        final t = widget.time.value;
        final (focal, scale) = _shot(t);
        // Lớp đèn gần máy quay hơn: trượt nhiều hơn nền 18% (parallax).
        final (start, _) = _shot(0);
        final glowFocal = focal + (focal - start) * 0.18;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform(
              transform: _camera(focal, scale),
              child: Stack(fit: StackFit.expand, children: [image, sparkle]),
            ),
            Transform(transform: _camera(glowFocal, scale), child: glow),
          ],
        );
      },
    );
  }
}

// ==================================================================== Cảnh 3: cửa tiệm

class _DoorScene extends StatelessWidget {
  const _DoorScene({required this.time, required this.reduce, required this.beats, required this.walkFrames});

  final Animation<double> time;
  final bool reduce;
  final _DoorBeats beats;

  /// Có `mai_walk_b` (đổi khung bước) — không có thì nhún + nghiêng ảnh walk_a theo bước.
  final bool walkFrames;

  /// Đổi khung bước chân mỗi chừng này giây.
  static const stepSec = 0.25;

  /// Mờ chéo giữa hai ảnh của Mai (giây).
  static const poseFade = 0.2;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    final l = AppLocalizations.of(context);
    const sign = IntroLayout.signSize;
    const bell = IntroLayout.bellSize;
    const mai = IntroLayout.maiSize;
    final signImage = introObjectImage(context, IntroAssets.openSign, sign.width);
    final signFallback = SLSurface(
      spec: const SLSurfaceSpec(shape: SLRoundRect(14), material: SLMaterial.wood, color: SLColors.woodLight, seed: 0x1A74),
      padding: EdgeInsets.fromLTRB(sign.width * 0.1, sign.height * 0.4, sign.width * 0.1, sign.height * 0.1),
      child: const SLSurface(spec: SLSurfaceSpec(shape: SLRoundRect(8), color: SLColors.paper, seed: 0x1A75)),
    );
    Widget board({required bool front}) => SizedBox.fromSize(
          size: sign,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IntroImage(image: signImage, fit: BoxFit.fill, fallback: signFallback),
              if (front)
                // Mặt trước: bảng trống hơi tối (mặt "đóng cửa").
                IgnorePointer(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x1F5A3E36), BlendMode.srcATop),
                    child: IntroImage(image: signImage, fit: BoxFit.fill, fallback: const SizedBox.shrink()),
                  ),
                )
              else
                Positioned(
                  left: IntroLayout.signTextRect.left * sign.width,
                  top: IntroLayout.signTextRect.top * sign.height,
                  width: IntroLayout.signTextRect.width * sign.width,
                  height: IntroLayout.signTextRect.height * sign.height,
                  child: FittedBox(
                    child: Text(
                      l.introSignOpen,
                      key: const ValueKey('intro-sign-text'),
                      maxLines: 1,
                      style: styles.heading.copyWith(fontSize: 58, color: SLColors.ink, height: 1.1),
                    ),
                  ),
                ),
            ],
          ),
        );
    final front = board(front: true);
    final back = board(front: false);
    final bellImage = IntroImage(
      image: introObjectImage(context, IntroAssets.doorBell, bell.width),
      fit: BoxFit.contain,
      fallback: const Center(child: SLIcon('bulb', size: 72)),
    );
    final ripple = IgnorePointer(
      child: CustomPaint(painter: IntroRipplePainter(time: IntroMapped(time, (t) => t - beats.bellAt))),
    );
    // Mỗi ảnh dịch nhẹ cho đáy giày + đầu trùng với ảnh đứng thẳng (đổi khung / mờ chéo không giật chân đế).
    Widget maiImage(String asset, {Widget fallback = const SizedBox.shrink()}) => Transform.translate(
          offset: IntroAssets.maiAlign(asset, mai),
          child: IntroImage(
            image: introObjectImage(context, asset, mai.width),
            fit: BoxFit.contain,
            fallback: fallback,
          ),
        );
    // Ảnh đi bộ / với tay vẽ nhìn sang trái, Mai đi từ phải sang trái và với tay về phía bảng bên trái mình → không
    // lật. (Đổi hướng đi thì lật ngang ảnh nghiêng.)
    const flip = IntroAssets.maiSideFacesLeft != IntroAssets.maiWalksLeft;
    Widget side(Widget w) => flip ? Transform.flip(flipX: true, child: w) : w;
    final neutral = maiImage(IntroAssets.maiNeutral);
    final walkA = side(maiImage(IntroAssets.maiWalkA, fallback: maiImage(IntroAssets.maiSmile)));
    final walkB = side(maiImage(IntroAssets.maiWalkB, fallback: maiImage(IntroAssets.maiWalkA)));
    // Thiếu ảnh với tay → mặt thường (ảnh nhìn thẳng: lật trước để hai lần lật triệt nhau).
    final reachFacing = side(maiImage(IntroAssets.maiReach, fallback: side(neutral)));
    final joy = maiImage(IntroAssets.maiJoy);
    final signPivot = Alignment(IntroLayout.signPivot.dx * 2 - 1, IntroLayout.signPivot.dy * 2 - 1);
    final bellPivot = Alignment(IntroLayout.bellPivot.dx * 2 - 1, IntroLayout.bellPivot.dy * 2 - 1);
    final signLeft = IntroLayout.signHook.dx - IntroLayout.signPivot.dx * sign.width;
    final signTop = IntroLayout.signHook.dy - IntroLayout.signPivot.dy * sign.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        IntroImage(
          image: introSceneImage(context, IntroAssets.door),
          fallback: const IntroPaperBackdrop(icon: 'storefront', seed: 0x1A76),
        ),
        // Chuông: lắc ±12° tắt dần quanh khoen treo + vòng sóng.
        Positioned(
          left: IntroLayout.bellTopLeft.dx,
          top: IntroLayout.bellTopLeft.dy,
          width: bell.width,
          height: bell.height,
          child: AnimatedBuilder(
            animation: time,
            builder: (context, child) {
              final tau = time.value - beats.bellAt;
              final angle = reduce || tau <= 0 ? 0.0 : 12 * math.pi / 180 * math.exp(-1.6 * tau) * math.sin(2 * math.pi * 2.1 * tau);
              return Transform.rotate(angle: angle, alignment: bellPivot, child: child);
            },
            child: bellImage,
          ),
        ),
        if (!reduce)
          Positioned(
            left: IntroLayout.bellTopLeft.dx + bell.width / 2 - 110,
            top: IntroLayout.bellTopLeft.dy + bell.height * 0.7 - 110,
            width: 220,
            height: 220,
            child: ripple,
          ),
        // Bảng treo: lật quanh trục dọc (scaleX 1 → 0 → 1), rồi đung đưa tắt dần quanh móc.
        Positioned(
          left: signLeft,
          top: signTop,
          width: sign.width,
          height: sign.height,
          child: AnimatedBuilder(
            animation: time,
            builder: (context, _) {
              final t = time.value;
              final p = ((t - beats.flipAt) / beats.flipLen).clamp(0.0, 1.0);
              if (reduce) {
                // Không lật: mặt sau hiện dần.
                return Stack(fit: StackFit.expand, children: [front, Opacity(opacity: p, child: back)]);
              }
              final sx = math.cos(math.pi * p).abs();
              final tau = t - beats.flipAt - beats.flipLen;
              final sway = tau <= 0 ? 0.0 : 0.09 * math.exp(-2.2 * tau) * math.sin(2 * math.pi * 1.2 * tau);
              return Transform.rotate(
                angle: sway,
                alignment: signPivot,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(math.max(sx, 0.02), 1, 1),
                  child: p < 0.5 ? front : back,
                ),
              );
            },
          ),
        ),
        // Mai: đi bộ đều từ ngoài mép phải tới trước cửa (đổi khung walk_a ↔ walk_b, hoặc nhún + nghiêng theo bước),
        // tới nơi → với tay đúng lúc bảng lật → chuông rung → quay ra cười + nhảy nhẹ (mờ chéo 200ms giữa các ảnh).
        // Giảm chuyển động: đứng sẵn trước cửa, chỉ đổi ảnh (mặt thường → với tay → cười).
        Positioned(
          left: IntroLayout.maiDoorX - mai.width / 2,
          top: IntroLayout.maiBottom - mai.height,
          width: mai.width,
          height: mai.height,
          child: AnimatedBuilder(
            animation: time,
            builder: (context, _) {
              final t = time.value;
              double fade(double at) => ((t - at) / poseFade).clamp(0.0, 1.0);
              final toReach = fade(beats.flipAt - poseFade);
              final toJoy = fade(beats.bellAt + 0.1);
              Widget layers(Widget first) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (toReach < 1) first,
                      if (toReach > 0 && toJoy < 1) Opacity(opacity: toReach, child: reachFacing),
                      if (toJoy > 0) Opacity(opacity: toJoy, child: joy),
                    ],
                  );
              if (reduce) {
                return Transform.translate(
                  key: const ValueKey('intro-mai'),
                  offset: Offset.zero,
                  child: Opacity(opacity: (t / 0.4).clamp(0.0, 1.0), child: layers(neutral)),
                );
              }
              final walk = beats.maiIn <= 0 ? 1.0 : (t / beats.maiIn).clamp(0.0, 1.0);
              final walking = walk < 1;
              // Vị trí xuất phát: ngoài mép khung theo hướng đi.
              final from = IntroAssets.maiWalksLeft ? 1280 + mai.width / 2 : -mai.width / 2;
              final dx = (from - IntroLayout.maiDoorX) * (1 - walk);
              var dy = 0.0;
              var tilt = 0.0;
              final Widget body;
              if (walking) {
                final step = (t / stepSec).floor();
                if (walkFrames) {
                  body = step.isEven ? walkA : walkB;
                  dy = -3 * math.sin(math.pi * (t / stepSec - step));
                } else {
                  // Một ảnh bước: nhún 6px mỗi bước + nghiêng ±2° đổi chiều theo chân.
                  final phase = t / stepSec - step;
                  dy = -6 * math.sin(math.pi * phase);
                  tilt = (step.isEven ? 1 : -1) * 2 * math.pi / 180 * math.sin(math.pi * phase);
                  body = walkA;
                }
              } else {
                body = walkA;
              }
              final hop = (t - beats.bellAt - 0.1) / 0.36;
              if (hop > 0 && hop < 1) dy -= 16 * math.sin(math.pi * hop);
              return Transform.translate(
                key: const ValueKey('intro-mai'),
                offset: Offset(dx, dy),
                child: Transform.rotate(angle: tilt, alignment: Alignment.bottomCenter, child: layers(body)),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==================================================================== Cảnh 4: logo

class _LogoScene extends StatefulWidget {
  const _LogoScene({required this.time, required this.reduce, required this.logoWidth});

  final Animation<double> time;
  final bool reduce;
  final double logoWidth;

  @override
  State<_LogoScene> createState() => _LogoSceneState();
}

class _LogoSceneState extends State<_LogoScene> {
  late final _sparkle = IntroSparklePainter(
    time: IntroMapped(widget.time, (t) => t - 0.5),
    region: const Rect.fromLTWH(380, 90, 520, 470),
    count: 12,
    maxRadius: 18,
    color: const Color(0xFFFFF4C2),
    seed: 0x1060,
  );

  @override
  Widget build(BuildContext context) {
    final logo = IntroLogo(title: AppLocalizations.of(context).appTitle, width: widget.logoWidth);
    return Stack(
      fit: StackFit.expand,
      children: [
        const IntroPaperBackdrop(seed: 0x1A77),
        Center(
          child: widget.reduce
              ? logo
              : AnimatedBuilder(
                  animation: widget.time,
                  builder: (context, child) {
                    final u = Curves.easeOutCubic.transform((widget.time.value / 0.9).clamp(0.0, 1.0));
                    return Opacity(opacity: u, child: Transform.scale(scale: 0.9 + 0.1 * u, child: child));
                  },
                  child: logo,
                ),
        ),
        if (!widget.reduce) IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _sparkle, size: Size.infinite))),
      ],
    );
  }
}

// ==================================================================== Phụ đề

/// Phụ đề nhỏ dưới khung: dải mực mờ, chữ giấy; hiện sau đầu cảnh 0,5 giây, ẩn trước hết cảnh 0,4 giây.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, required this.time, required this.duration});

  final String text;
  final Animation<double> time;
  final double duration;

  @override
  Widget build(BuildContext context) {
    final style = SLTextStyles.of(context).body.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: SLColors.paper);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 34,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: IntroMapped(time, (t) {
            final fadeIn = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
            final fadeOut = ((duration - IntroScreen.crossFade - t) / 0.4).clamp(0.0, 1.0);
            return math.min(fadeIn, fadeOut);
          }),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xA65A3E36),
                borderRadius: BorderRadius.circular(SLMetrics.radiusButton),
              ),
              child: Text(text, textAlign: TextAlign.center, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
