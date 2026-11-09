import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../sugarleaf/sugarleaf.dart';
import 'intro_art.dart';
import 'intro_stage.dart';

/// Cảnh mở đầu 3D (~18 giây): phố "Tiệm Bánh" của thành phố V3 (cùng lưới, cùng nhân vật với màn chơi — dựng bởi lớp
/// [stageBuilder]), một cú máy quay liền mạch qua 4 cảnh: (1) phố ven biển buổi sáng nhìn từ trên cao, Mai đi bộ dọc
/// vỉa hè; (2) Mai dừng trước tiệm của bà, máy quay hạ xuống thấy mặt tiền; (3) Mai quay ra phố, nhảy vui (+ tiếng
/// chuông cửa) rồi vẫy tay; (4) máy quay nâng lên biển hiệu, màn kem mờ dần + logo. Phụ đề dưới khung theo cảnh.
///
/// Lớp 3D dựng xong mới chạy đồng hồ (trong lúc chờ: nền giấy, quá [openingDelay] hiện "Đang mở cửa…"); chờ quá
/// [stageWait], lớp 3D hỏng, hoặc không có [stageBuilder] (test) → chạy trên nền giấy (phụ đề + logo). Nút **Bỏ qua**
/// luôn hiện; nút Back = Bỏ qua. Xong / bỏ qua → `markIntroSeen`, phủ nền giấy, chờ lớp 3D huỷ viewer (tối đa
/// [releaseWait]) rồi thay route bằng phố ([AppRoutes.town]). Giảm chuyển động: cảnh ngắn hơn, máy quay cắt cảnh thay
/// vì lia, không hạt.
///
/// Trạng thái (đồng hồ, lớp 3D + viewer) nằm ở [_IntroBody] mang GlobalKey cố định: `RefFrame` đổi cây con khi khung
/// chuyển giữa 1280 và khung rộng (đổi cỡ cửa sổ web, thanh hệ thống Android ẩn / hiện) → [IntroScreen] bị dựng lại,
/// nhưng phần thân được chuyển chỗ nguyên trạng thay vì chạy lại từ đầu và tạo viewer thứ hai.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  /// Chỉ có một cảnh mở đầu tại một thời điểm (route intro thay bằng phố).
  static final _bodyKey = GlobalKey(debugLabel: 'intro-body');

  /// Lớp 3D (main.dart gán `IntroStage3d.new`); null → nền giấy.
  static IntroStageBuilder? stageBuilder;

  /// Thời lượng từng cảnh (giây).
  static const sceneSeconds = [5.0, 5.0, 5.0, 3.0];

  /// Thời lượng từng cảnh khi máy bật giảm chuyển động.
  static const reducedSceneSeconds = [2.5, 2.5, 3.0, 2.0];

  /// Chờ lớp 3D dựng tối đa chừng này rồi chạy trên nền giấy (cảnh 3D xong muộn vẫn hiện, đúng nhịp đồng hồ).
  static const stageWait = Duration(seconds: 25);

  /// Hết cảnh / bỏ qua: chờ lớp 3D huỷ viewer tối đa chừng này rồi sang phố.
  static const releaseWait = Duration(seconds: 4);

  /// Đang chờ lớp 3D quá chừng này thì hiện "Đang mở cửa…".
  static const openingDelay = Duration(seconds: 1);

  @override
  Widget build(BuildContext context) => _IntroBody(key: _bodyKey);
}

enum _Stage { none, loading, ready, failed }

class _IntroBody extends StatefulWidget {
  const _IntroBody({super.key});

  @override
  State<_IntroBody> createState() => _IntroBodyState();
}

class _IntroBodyState extends State<_IntroBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late List<double> _durations;
  late List<double> _starts;
  late double _total;
  late bool _reduce;
  late final Animation<double> _time = IntroMapped(_c, (v) => v * _total);
  IntroStageHost? _host;
  Widget? _stageWidget;
  _Stage _stage = _Stage.none;
  bool _configured = false;
  bool _started = false;
  bool _done = false;
  bool _bellRung = false;
  bool _opening = false;
  Timer? _stageTimer;
  Timer? _openingTimer;

  /// Cảnh đang hiện (phụ đề / logo).
  int _scene = 0;

  @override
  void initState() {
    super.initState();
    // `preserve`: khi máy bật giảm chuyển động, AnimationController mặc định chạy nhanh gấp ~20 lần → cảnh rút gọn
    // vụt qua trong nửa giây. Thời lượng rút gọn đã tự chọn ở [IntroScreen.reducedSceneSeconds].
    _c = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve)
      ..addListener(_onTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) unawaited(_finish());
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
      s,
    ];
    _total = s;
    _c.duration = Duration(milliseconds: (_total * 1000).round());
    // Huy hiệu logo nạp sẵn (không chờ).
    unawaited(precacheImage(introObjectImage(context, IntroAssets.emblem, _logoWidth), context, onError: (_, _) {}));
    final builder = IntroScreen.stageBuilder;
    if (builder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
      return;
    }
    final host = _host = IntroStageHost(
      time: _time,
      starts: List.unmodifiable(_starts),
      reduceMotion: _reduce,
      onReady: _onStageReady,
      onFailed: _onStageFailed,
    );
    _stage = _Stage.loading;
    _stageWidget = builder(host);
    _stageTimer = Timer(IntroScreen.stageWait, _begin);
    _openingTimer = Timer(IntroScreen.openingDelay, () {
      if (mounted && !_started) setState(() => _opening = true);
    });
  }

  void _onStageReady() {
    if (!mounted || _done) return;
    setState(() => _stage = _Stage.ready);
    _begin();
  }

  void _onStageFailed() {
    if (!mounted || _done) return;
    setState(() => _stage = _Stage.failed);
    _begin();
  }

  void _begin() {
    _stageTimer?.cancel();
    _openingTimer?.cancel();
    if (_started || _done || !mounted) return;
    setState(() {
      _started = true;
      _opening = false;
    });
    _c.forward();
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _openingTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onTick() {
    final t = _time.value;
    var scene = 0;
    while (scene < _durations.length - 1 && t >= _starts[scene + 1]) {
      scene++;
    }
    if (scene != _scene) setState(() => _scene = scene);
    if (!_bellRung && t >= _starts[2] + IntroBeats.joy) {
      _bellRung = true;
      AppScope.read(context).audio.success();
    }
  }

  Future<void> _finish() async {
    if (_done || !mounted) return;
    setState(() => _done = true);
    _stageTimer?.cancel();
    _openingTimer?.cancel();
    _c.stop();
    AppScope.read(context).game.markIntroSeen();
    final navigator = Navigator.of(context);
    // Phố tạo viewer riêng: gỡ viewer của cảnh mở đầu trước (dưới nền giấy), có giới hạn thời gian.
    final release = _host?.release;
    if (release != null) {
      try {
        await release().timeout(IntroScreen.releaseWait);
      } catch (e) {
        debugPrint('IntroScreen: stage release: $e');
      }
    }
    if (mounted) unawaited(navigator.pushReplacementNamed(AppRoutes.town));
  }

  static const _logoWidth = 460.0;

  /// Giây trong cảnh [i] (âm khi chưa tới).
  Animation<double> _local(int i) => IntroMapped(_c, (v) => v * _total - _starts[i]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lines = [l.introLineKitchen, l.introLineCase, l.introLineDoor, null];
    final stage = _stageWidget;
    // Nền giấy che lớp 3D khi chưa có / hỏng / đang sang phố.
    final covered = _done || _stage != _Stage.ready;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: Semantics(
        label: l.introSemantics,
        child: ColoredBox(
          color: SLColors.cream,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (stage != null) Positioned.fill(child: ExcludeSemantics(child: stage)),
              IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey('intro-cover'),
                  opacity: covered ? 1 : 0,
                  duration: Duration(milliseconds: _done ? 200 : 400),
                  child: const IntroPaperBackdrop(seed: 0x1A71),
                ),
              ),
              if (_opening)
                Center(
                  child: Text(
                    l.townOpening,
                    key: const ValueKey('intro-opening'),
                    style: SLTextStyles.of(context).body.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              if (_started && !_done) ...[
                if (_scene == 3)
                  _LogoScene(
                    key: const ValueKey('intro-logo'),
                    time: _local(3),
                    reduce: _reduce,
                    logoWidth: _logoWidth,
                    veil: _stage == _Stage.ready,
                  ),
                if (lines[_scene] case final text?)
                  _Subtitle(
                    key: ValueKey('intro-subtitle-$_scene'),
                    text: text,
                    time: _local(_scene),
                    duration: _durations[_scene],
                  ),
              ],
              Positioned(
                top: 20,
                right: 24 + MediaQuery.paddingOf(context).right,
                child: SLButton(
                  key: const ValueKey('intro-skip'),
                  label: l.storySkip,
                  icon: 'skip',
                  variant: SLButtonVariant.secondary,
                  height: 52,
                  fontSize: 18,
                  onPressed: () => unawaited(_finish()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================== Cảnh 4: logo

/// Logo; có cảnh 3D ([veil]) thì màn kem mờ dần lên 85% che phố, không có thì nền giấy đã phủ sẵn.
class _LogoScene extends StatefulWidget {
  const _LogoScene({super.key, required this.time, required this.reduce, required this.logoWidth, required this.veil});

  final Animation<double> time;
  final bool reduce;
  final double logoWidth;
  final bool veil;

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
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.veil)
            FadeTransition(
              opacity: widget.reduce
                  ? const AlwaysStoppedAnimation(0.85)
                  : IntroMapped(widget.time, (t) => 0.85 * Curves.easeOut.transform((t / 0.8).clamp(0.0, 1.0))),
              child: const IntroPaperBackdrop(seed: 0x1A77),
            ),
          Center(
            child: widget.reduce
                ? logo
                : AnimatedBuilder(
                    animation: widget.time,
                    builder: (context, child) {
                      final u = Curves.easeOutCubic.transform(((widget.time.value - 0.3) / 0.9).clamp(0.0, 1.0));
                      return Opacity(opacity: u, child: Transform.scale(scale: 0.9 + 0.1 * u, child: child));
                    },
                    child: logo,
                  ),
          ),
          if (!widget.reduce)
            introStage(
              introFrameWidth(MediaQuery.sizeOf(context)),
              RepaintBoundary(child: CustomPaint(painter: _sparkle, size: Size.infinite)),
            ),
        ],
      ),
    );
  }
}

// ==================================================================== Phụ đề

/// Phụ đề nhỏ dưới khung: dải mực mờ, chữ giấy; hiện sau đầu cảnh 0,5 giây, ẩn trước hết cảnh 0,4 giây.
class _Subtitle extends StatelessWidget {
  const _Subtitle({super.key, required this.text, required this.time, required this.duration});

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
            final fadeOut = ((duration - 0.4 - t) / 0.4).clamp(0.0, 1.0);
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
