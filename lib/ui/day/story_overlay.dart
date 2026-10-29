import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/ids.dart';
import '../../core/models/story.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/panel.dart';
import '../sugarleaf/sugarleaf.dart';

/// Cảnh nền vẽ tay: mở đầu và kết thúc ở phố biển, các cảnh khác trong bếp cũ của bà.
ArtScene _backdropOf(StorySceneId id) => switch (id) {
  StorySceneId.prologue || StorySceneId.finale => ArtScene.storyTown,
  _ => ArtScene.storyGrandmaKitchen,
};

Speaker _speakerOf(FriendId f) => switch (f) {
  FriendId.hoa => Speaker.hoa,
  FriendId.linh => Speaker.linh,
  FriendId.kenji => Speaker.kenji,
};

/// Hội thoại truyện trước khách đầu tiên: bong bóng thoại giấy ở dưới (đuôi chỉ về người đang nói, người kể thì
/// không đuôi), dải vải tên người nói, chạm để tiếp, nút bỏ qua nhãn dán.
/// Bạn quen đứng trái, Mai đứng phải; người đang nói sáng, người kia mờ.
class StoryOverlay extends StatefulWidget {
  const StoryOverlay({super.key, required this.scene, required this.onFinished});

  final StoryScene scene;
  final VoidCallback onFinished;

  @override
  State<StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<StoryOverlay> {
  int _line = 0;
  bool _done = false;

  void _advance() {
    if (_done) return;
    AppScope.read(context).audio.tap();
    if (_line < widget.scene.lines.length - 1) {
      setState(() => _line++);
    } else {
      _finish();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scene = widget.scene;
    final line = scene.lines[_line];
    final friend = scene.featuredFriend == null ? null : _speakerOf(scene.featuredFriend!);
    final maiInScene = scene.lines.any((x) => x.speaker == Speaker.mai);
    final leftSpeaker = friend ?? (line.speaker == Speaker.narrator ? Speaker.narrator : null);
    final name = l.speakerName(line.speaker);
    final narrator = line.speaker == Speaker.narrator;
    // Mai đứng bên phải; người kể không đứng ở đâu → bong bóng không đuôi.
    final speakerRight = line.speaker == Speaker.mai;
    final tail = narrator ? SLTail.none : SLTail.top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: Stack(
        children: [
          // Chưa có ảnh nền → trong suốt, thấy cảnh tiệm của màn ngày bên dưới.
          Positioned.fill(child: SceneBackdrop(scene: _backdropOf(scene.id))),
          const Positioned.fill(child: ColoredBox(color: Color(0x405A3E36))),
          if (scene.id == StorySceneId.prologue && _line == 0)
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: slReduceMotion(context) ? 1 : 0.6, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Transform.scale(scale: t, child: child),
                  child: TitleRibbon(
                    l.storyChapter1Title,
                    color: SLColors.butter,
                    fontSize: 34,
                    iconId: 'book',
                    art: ArtSprites.book,
                  ),
                ),
              ),
            ),
          if (leftSpeaker != null)
            Positioned(
              left: 70,
              top: 150,
              child: _Actor(speaker: leftSpeaker, active: line.speaker == leftSpeaker),
            ),
          if (maiInScene)
            Positioned(
              right: 70,
              top: 150,
              child: _Actor(speaker: Speaker.mai, active: line.speaker == Speaker.mai),
            ),
          // Bong bóng thoại: đuôi ở mép trên chỉ lên người đang nói (trái: bạn quen, phải: Mai).
          Positioned(
            left: 40,
            right: 40,
            top: 466,
            height: 232,
            child: SLSpeechBubble(
              tail: tail,
              tailAt: speakerRight ? 0.82 : 0.2,
              tailSize: 20,
              maxWidth: double.infinity,
              color: SLColors.paper,
              seed: 0x5701,
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200),
                      child: Align(
                        key: ValueKey(_line),
                        alignment: Alignment.topLeft,
                        child: Text(
                          line.text(l),
                          style: SLTextStyles.of(context).body.copyWith(
                                fontSize: 26,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                fontStyle: narrator ? FontStyle.italic : FontStyle.normal,
                              ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Chấm tiến trình các dòng: chấm màu nước vẽ tay.
                      for (var i = 0; i < scene.lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _ProgressDot(filled: i <= _line, seed: i),
                        ),
                      const Spacer(),
                      Text(
                        l.storyTapToContinue,
                        style: SLTextStyles.of(context).label.copyWith(fontSize: 17, color: SLColors.inkSoft),
                      ),
                      const SizedBox(width: 4),
                      const _BobbingArrow(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (name.isNotEmpty)
            Positioned(
              left: speakerRight ? null : 80,
              right: speakerRight ? 80 : null,
              top: 444,
              child: SLNameTag(
                name,
                height: 46,
                fontSize: 22,
                maxWidth: 360,
                color: line.speaker == Speaker.mai ? SLColors.strawberry : SLColors.mint,
                seed: line.speaker.index,
              ),
            ),
          Positioned(
            top: 20,
            right: 24,
            child: SLButton(
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
    );
  }
}

class _Actor extends StatelessWidget {
  const _Actor({required this.speaker, required this.active});

  final Speaker speaker;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1 : 0.55,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: active ? 1.04 : 0.96,
        alignment: Alignment.bottomCenter,
        child: SpeakerImage(speaker: speaker, width: 300, height: 400, clipBottom: 64),
      ),
    );
  }
}

/// Chấm tiến trình một dòng thoại: chấm tròn viền mực run tay, tô màu nước hồng dâu khi đã đọc.
class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.filled, required this.seed});

  final bool filled;
  final int seed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 13,
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: const SLCircle(),
            material: SLMaterial.wash,
            color: filled ? SLColors.strawberry : SLColors.paperShade,
            inkWidth: 1.3,
            seed: 0x5D07 + seed,
          ),
        ),
      );
}

/// Mũi tên vẽ tay nhún lên xuống nhẹ (gợi ý "chạm để tiếp tục"). Lặp liên tục khi hội thoại đang mở — đây là
/// gợi ý cần thiết; tắt hiệu ứng → đứng yên.
class _BobbingArrow extends StatefulWidget {
  const _BobbingArrow();

  @override
  State<_BobbingArrow> createState() => _BobbingArrowState();
}

class _BobbingArrowState extends State<_BobbingArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (slReduceMotion(context)) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) =>
              Transform.translate(offset: Offset(0, 4 * math.sin(_c.value * math.pi)), child: child),
          child: const SLIcon('arrow_down', size: 28, color: SLColors.inkSoft),
        ),
      );
}
