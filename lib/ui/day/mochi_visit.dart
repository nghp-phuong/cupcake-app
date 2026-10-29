import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/art/art_paint.dart';
import '../../core/art/characters/character_sprites.dart';
import '../../core/art/customer_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/speech_bubble.dart';
import '../common/sugar_button.dart';
import '../sugarleaf/sugarleaf.dart';

/// Nét mặt Mochi theo 4 ảnh `mochi_<expr>`.
enum MochiFace { sad, neutral, smile, joy }

/// Vẽ Mochi ngồi với nét mặt [face] trong khung 3:4 giữa [rect] (như `CustomerArt.paintMochi`).
/// `paintMochi` nhận `CustomerMood` (không có nét "smile") → smile vẽ thẳng ảnh `mochi_smile`, chưa có ảnh thì
/// dùng hình vui của `paintMochi`.
void paintMochiFace(Canvas canvas, Rect rect, MochiFace face) {
  if (face == MochiFace.smile) {
    final image = CharacterSprites.image(CustomerArt.mochiSpriteId, 'smile');
    if (image != null) {
      final w = math.min(rect.width, rect.height * 0.75);
      if (w <= 0) return;
      final frame = Rect.fromCenter(center: rect.center, width: w, height: w / 0.75);
      paintArt(canvas, frame, image, alignment: Alignment.bottomCenter);
      return;
    }
  }
  CustomerArt.paintMochi(canvas, rect, mood: switch (face) {
    MochiFace.sad => CustomerMood.sad,
    MochiFace.neutral => CustomerMood.neutral,
    MochiFace.smile || MochiFace.joy => CustomerMood.happy,
  });
}

/// Hình Mochi với nét mặt [face] (vẽ lại khi ảnh nạp xong).
class MochiImage extends StatelessWidget {
  const MochiImage({super.key, required this.face, required this.width, required this.height});

  final MochiFace face;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ArtCanvas(
        width: width,
        height: height,
        repaintKey: face,
        repaint: CustomerArt.repaint,
        paint: (c, s) => paintMochiFace(c, Offset.zero & s, face),
      );
}

enum _Step { arrive, look, petted, rested, leaving }

/// Mèo Mochi ghé tiệm ngày mưa (giữa hai khách, ở chỗ khách đứng): bước vào từ cửa (trái) với nét mặt buồn →
/// chạm → nhìn người chơi + 2 nút "Vuốt ve" / "Để Mochi nghỉ" → chạm → rời đi → [onDone].
///
/// Màn ngày lo phần game (`DayController.petMochi` / `restMochi`, toast quà) qua [onPet] / [onRest]. Phủ kín khung
/// nhưng nằm dưới HUD nên nút thoát ngày vẫn bấm được.
class MochiVisit extends StatefulWidget {
  const MochiVisit({
    super.key,
    required this.firstVisit,
    required this.onPet,
    required this.onRest,
    required this.onDone,
  });

  /// Lần đầu gặp Mochi trong đời game (đọc trước khi gọi pet/rest).
  final bool firstVisit;
  final VoidCallback onPet;
  final VoidCallback onRest;
  final VoidCallback onDone;

  /// Khung vẽ Mochi (toạ độ 1280×720): ngồi trên mặt quầy (y ~505) ở chỗ khách đứng (giữa x ~320). Ảnh 480×640
  /// có đáy thân mèo ở ~83% chiều cao, đỉnh tai ~17%.
  static const figure = Rect.fromLTWH(215, 272, 210, 280);

  @override
  State<MochiVisit> createState() => _MochiVisitState();
}

class _MochiVisitState extends State<MochiVisit> with TickerProviderStateMixin {
  static const _enterDistance = 440.0;

  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
    ..forward();
  late final AnimationController _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  _Step _step = _Step.arrive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tắt hiệu ứng: Mochi ngồi sẵn ở quầy, rời đi ngay.
    if (slReduceMotion(context)) {
      if (_step == _Step.arrive) _enter.value = 1;
      _leave.duration = const Duration(milliseconds: 1);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _leave.dispose();
    super.dispose();
  }

  MochiFace get _face => switch (_step) {
        _Step.arrive => MochiFace.sad,
        _Step.look => MochiFace.neutral,
        _Step.petted => MochiFace.joy,
        _Step.rested || _Step.leaving => MochiFace.smile,
      };

  void _onTap() {
    switch (_step) {
      case _Step.arrive:
        _enter.value = 1; // chạm sớm → ngồi luôn.
        setState(() => _step = _Step.look);
      case _Step.petted || _Step.rested:
        _goAway();
      case _Step.look || _Step.leaving:
        break;
    }
  }

  void _pet() {
    if (_step != _Step.look) return;
    widget.onPet();
    if (mounted) setState(() => _step = _Step.petted);
  }

  void _rest() {
    if (_step != _Step.look) return;
    widget.onRest();
    if (mounted) setState(() => _step = _Step.rested);
  }

  Future<void> _goAway() async {
    setState(() => _step = _Step.leaving);
    try {
      await _leave.forward().orCancel;
    } on TickerCanceled {
      return; // màn bị bỏ giữa chừng (thoát ngày).
    }
    if (mounted) widget.onDone();
  }

  String? _line(AppLocalizations l) => switch (_step) {
        _Step.arrive => widget.firstVisit ? l.mochiArriveFirst : l.mochiArriveAgain,
        _Step.look => l.mochiLook,
        _Step.petted => l.mochiPetThanks,
        _Step.rested => l.mochiNap,
        _Step.leaving => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final line = _line(l);
    const fig = MochiVisit.figure;
    final tapToContinue = _step == _Step.arrive || _step == _Step.petted || _step == _Step.rested;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        children: [
          // Mochi: trượt vào từ cửa bên trái, nảy nhẹ từng bước; rời đi cũng nảy về bên trái.
          Positioned.fromRect(
            rect: fig,
            child: AnimatedBuilder(
              animation: Listenable.merge([_enter, _leave]),
              builder: (context, child) {
                final enter = Curves.easeOutCubic.transform(_enter.value);
                final leave = Curves.easeInCubic.transform(_leave.value);
                final dx = -_enterDistance * (1 - enter) - _enterDistance * leave;
                final hops = (1 - enter) + leave;
                final dy = -16 * (math.sin(hops * math.pi * 4)).abs() * math.min(1.0, hops * 4);
                final opacity = (enter * (1 - leave) * 1.4).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(offset: Offset(dx, dy), child: child),
                );
              },
              child: _MochiFigure(face: _face),
            ),
          ),
          if (line != null)
            // Neo theo mép dưới (ngay trên đầu Mochi) để bong bóng 2–3 dòng mọc lên trên.
            Positioned(
              left: 96,
              width: 470,
              bottom: kRefSize.height - fig.top - 40,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_step),
                tween: Tween(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (context, t, child) =>
                    Transform.scale(scale: t, alignment: Alignment.bottomCenter, child: child),
                child: SpeechBubble(text: line, tailX: (fig.center.dx - 96) / 470),
              ),
            ),
          // Tim bay lên quanh Mochi, dưới bong bóng thoại (vẽ sau để luôn nằm trên cùng).
          if (_step == _Step.petted && !slReduceMotion(context))
            Positioned(
              left: fig.center.dx - 110,
              top: fig.top + 30,
              width: 220,
              height: 200,
              child: const IgnorePointer(child: _FloatingHearts()),
            ),
          if (_step != _Step.leaving)
            Positioned(
              left: fig.center.dx - 150,
              width: 300,
              top: 520,
              child: Center(child: _MochiTag(name: l.mochiName)),
            ),
          if (_step == _Step.look)
            Positioned(
              left: fig.center.dx - 260,
              width: 520,
              top: 580,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SugarButton(
                    label: l.mochiPet,
                    iconId: 'heart',
                    color: SLColors.strawberry,
                    width: 220,
                    height: 64,
                    fontSize: 22,
                    onPressed: _pet,
                  ),
                  const SizedBox(width: 16),
                  SugarButton(
                    label: l.mochiRest,
                    iconId: 'moon',
                    color: SLColors.mint,
                    width: 260,
                    height: 64,
                    fontSize: 22,
                    onPressed: _rest,
                  ),
                ],
              ),
            ),
          if (tapToContinue)
            Positioned(
              left: fig.center.dx - 220,
              width: 440,
              top: 588,
              child: Center(child: _TapHint(text: l.storyTapToContinue)),
            ),
        ],
      ),
    );
  }
}

/// Mochi + bóng mềm trên mặt quầy; ướt mưa (vài giọt nước) khi còn buồn. Đổi nét mặt thì nảy nhẹ.
class _MochiFigure extends StatelessWidget {
  const _MochiFigure({required this.face});

  final MochiFace face;

  @override
  Widget build(BuildContext context) {
    const fig = MochiVisit.figure;
    return TweenAnimationBuilder<double>(
      key: ValueKey(face),
      tween: Tween(begin: 0.93, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scaleY: t, alignment: Alignment.bottomCenter, child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bóng mềm trên mặt quầy, rộng hơn thân mèo một chút để lộ ra hai bên và dưới chân.
          Positioned(
            left: fig.width * 0.04,
            right: fig.width * 0.04,
            top: fig.height * 0.765,
            height: fig.height * 0.075,
            child: const SLGroundShadow(color: Color(0x665A3E36)),
          ),
          MochiImage(face: face, width: fig.width, height: fig.height),
          if (face == MochiFace.sad)
            for (final (x, y, s) in const [(0.22, 0.2, 18.0), (0.74, 0.16, 16.0), (0.82, 0.42, 14.0)])
              Positioned(
                left: fig.width * x,
                top: fig.height * y,
                child: Opacity(opacity: 0.85, child: SLIcon('raindrop', size: s, color: SLColors.inkSoft)),
              ),
        ],
      ),
    );
  }
}

/// Vài trái tim nhỏ bay lên rồi mờ dần (chạy một lần).
class _FloatingHearts extends StatelessWidget {
  const _FloatingHearts();

  /// (lệch ngang, độ cao bay, cỡ, trễ 0..1).
  static const _hearts = [
    (-82.0, 110.0, 26.0, 0.0),
    (78.0, 120.0, 30.0, 0.05),
    (-96.0, 150.0, 20.0, 0.2),
    (92.0, 160.0, 20.0, 0.25),
    (-66.0, 90.0, 16.0, 0.4),
    (70.0, 95.0, 18.0, 0.35),
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      builder: (context, t, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (dx, rise, size, delay) in _hearts)
            if (t > delay)
              Builder(builder: (context) {
                final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
                final y = 200 - size - Curves.easeOut.transform(p) * rise;
                final x = 110 + dx + math.sin(p * math.pi * 2) * 6 - size / 2;
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: p < 0.6 ? 1 : (1 - (p - 0.6) / 0.4).clamp(0.0, 1.0),
                    child: SLIcon('heart', size: size),
                  ),
                );
              }),
        ],
      ),
    );
  }
}

/// Bảng tên "Mochi": tấm ván gỗ sáng đóng đinh (như bảng tên khách), dấu chân mèo trước chữ.
class _MochiTag extends StatelessWidget {
  const _MochiTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) =>
      SLNameTag(name, style: SLNameTagStyle.wood, icon: 'paw', height: 46, fontSize: 22, maxWidth: 260, seed: 0x3C0C);
}

/// "Chạm để tiếp tục": mẩu giấy nhỏ nảy vào một lần (không nhấp nháy lặp; tắt hiệu ứng → hiện ngay).
class _TapHint extends StatelessWidget {
  const _TapHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return SLBounceIn(
      delay: const Duration(milliseconds: 250),
      child: SLSurface(
        spec: const SLSurfaceSpec(shape: SLRoundRect(16), color: SLColors.paper, inkWidth: 1.8, seed: 0x7A9),
        lift: 2.5,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SLIcon('tap', size: 24),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.label.copyWith(fontSize: 17, color: SLColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
