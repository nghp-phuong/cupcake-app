import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants.dart';
import '../sugarleaf/sugarleaf.dart';
import 'shop3d_toasts.dart' show Shop3dPillButton, Shop3dSlideIn, Shop3dStyle;

/// Khung hội thoại ở đáy màn của cảnh tiệm 3D (đặc tả `docs/v3/interaction-spec.md` 2.4).
///
/// Rộng `min(960, W−64)`, cao 168–200, nền kem, viền nâu 2px, bo 20. Chip tên người nói (font tiêu đề), câu
/// thoại Nunito 22 tối đa 3 dòng, chữ hiện dần [charsPerSecond] ký tự/s (đếm theo cụm ký tự, giữ nguyên dấu tiếng Việt).
///
/// Chạm vào khung: lần đầu hiện hết câu; lần nữa → [onNext] (khi không có lựa chọn). Có [choices] (2–3): lựa chọn
/// hiện ở cột phải rộng 320 sau khi câu hiện hết, chạm khung không gọi [onNext] và không có nút Bỏ qua — widget
/// không bao giờ tự bỏ qua lựa chọn. Nút Bỏ qua gọi [onSkip]; người nối nhảy tới lựa chọn kế tiếp hoặc tới cuối.
///
/// Câu mới (đổi [text] / [speaker] / [lineId]) → chữ chạy lại từ đầu. Hai câu liền nhau trùng chữ thì truyền
/// [lineId] khác nhau. Tự trả về `Positioned` — đặt làm con của `Stack` phủ cảnh; ngoài khung chạm vẫn tới cảnh.
class Shop3dDialoguePanel extends StatefulWidget {
  const Shop3dDialoguePanel({
    super.key,
    required this.speaker,
    required this.text,
    required this.tapHint,
    required this.skipLabel,
    this.choices = const [],
    this.onNext,
    this.onSkip,
    this.onChoice,
    this.lineId,
    this.speakerColor = AppColors.strawberry,
    this.charsPerSecond = 40,
    this.bottom = 16,
  });

  static const maxWidth = 960.0;
  static const minHeight = 168.0;
  static const maxHeight = 200.0;
  static const choiceWidth = 320.0;
  static const choiceHeight = 56.0;

  /// Phần chip tên / nút Bỏ qua lấn lên trên mép khung.
  static const overhang = 24.0;

  static const panelKey = ValueKey('shop3d-dialogue-panel');
  static const lineTextKey = ValueKey('shop3d-dialogue-line');
  static const skipKey = ValueKey('shop3d-dialogue-skip');
  static Key choiceKey(int i) => ValueKey('shop3d-dialogue-choice-$i');

  /// Tên người nói (đã dịch); null = lời dẫn, không có chip tên.
  final String? speaker;
  final String text;

  /// Gợi ý chạm để tiếp tục (`storyTapToContinue`).
  final String tapHint;

  /// Nhãn nút Bỏ qua (`storySkip`).
  final String skipLabel;

  /// Nhãn lựa chọn (đã dịch); rỗng = câu thường.
  final List<String> choices;
  final VoidCallback? onNext;

  /// null → không có nút Bỏ qua.
  final VoidCallback? onSkip;
  final ValueChanged<int>? onChoice;

  /// Định danh câu (vd. `'$nodeId/$index'`) để chữ chạy lại khi hai câu liền nhau trùng chữ.
  final Object? lineId;
  final Color speakerColor;
  final double charsPerSecond;

  /// Khoảng cách tới mép dưới (cộng thêm padding an toàn).
  final double bottom;

  @override
  State<Shop3dDialoguePanel> createState() => _Shop3dDialoguePanelState();
}

class _Shop3dDialoguePanelState extends State<Shop3dDialoguePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _type = AnimationController(vsync: this)..addListener(_onTypeTick);

  /// Số cụm ký tự đang hiện — đổi tối đa [Shop3dDialoguePanel.charsPerSecond] lần/s, chỉ dựng lại dòng chữ.
  final _shown = ValueNotifier<int>(0);

  /// Vị trí kết thúc (code unit) của từng cụm ký tự.
  List<int> _ends = const [];
  bool _revealed = false;

  /// Đã gọi callback cho câu này, chờ khung sau (chặn chạm đúp gọi hai lần).
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startLine();
    }
  }

  @override
  void didUpdateWidget(Shop3dDialoguePanel old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.speaker != widget.speaker || old.lineId != widget.lineId) {
      _startLine();
    }
  }

  @override
  void dispose() {
    _type.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _startLine() {
    final ends = <int>[];
    var off = 0;
    for (final g in widget.text.characters) {
      off += g.length;
      ends.add(off);
    }
    _ends = ends;
    _busy = false;
    final n = ends.length;
    if (n == 0 || widget.charsPerSecond <= 0 || slReduceMotion(context)) {
      _type.stop();
      _shown.value = n;
      _revealed = true;
      return;
    }
    _revealed = false;
    _shown.value = 0;
    _type.duration = Duration(microseconds: (n * 1e6 / widget.charsPerSecond).round());
    _type.forward(from: 0);
  }

  void _onTypeTick() {
    final n = _ends.length;
    final k = math.min(n, (_type.value * n).floor());
    if (k != _shown.value) _shown.value = k;
    if (_type.isCompleted && !_revealed) _markRevealed();
  }

  void _markRevealed() {
    _shown.value = _ends.length;
    if (!_revealed && mounted) setState(() => _revealed = true);
  }

  void _revealAll() {
    _type.stop();
    _markRevealed();
  }

  /// Gọi [cb] một lần cho câu này; mở lại sau khung kế (người nối có thể giữ nguyên câu).
  void _fire(VoidCallback? cb) {
    if (cb == null || _busy) return;
    _busy = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => _busy = false);
    SchedulerBinding.instance.ensureVisualUpdate();
    cb();
  }

  void _onTap() {
    if (!_revealed) {
      _revealAll();
      return;
    }
    if (widget.choices.isEmpty) _fire(widget.onNext);
  }

  String _prefix(int k) => k <= 0 ? '' : widget.text.substring(0, _ends[math.min(k, _ends.length) - 1]);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final w = math.max(0.0, math.min(Shop3dDialoguePanel.maxWidth, screen.width - 64));
    final hasChoices = widget.choices.isNotEmpty;
    final h = widget.choices.length >= 3
        ? Shop3dDialoguePanel.maxHeight
        : (screen.height * 0.25).clamp(Shop3dDialoguePanel.minHeight, Shop3dDialoguePanel.maxHeight).toDouble();
    final choiceW = math.min(Shop3dDialoguePanel.choiceWidth, w * 0.45);
    final showChoices = hasChoices && _revealed;
    final showSkip = !hasChoices && widget.onSkip != null;
    const over = Shop3dDialoguePanel.overhang;
    final lineStyle = Shop3dStyle.body(22, weight: FontWeight.w700, height: 1.3);
    final speaker = widget.speaker;

    final line = ValueListenableBuilder<int>(
      valueListenable: _shown,
      builder: (context, k, _) {
        final shown = _prefix(k);
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: shown),
            TextSpan(text: widget.text.substring(shown.length), style: const TextStyle(color: Color(0x00000000))),
          ]),
          key: Shop3dDialoguePanel.lineTextKey,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: lineStyle,
        );
      },
    );

    final hint = AnimatedOpacity(
      opacity: _revealed && !hasChoices ? 1 : 0,
      duration: Shop3dStyle.fade,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.tapHint, maxLines: 1, style: Shop3dStyle.body(14, color: SLColors.inkSoft)),
          const Icon(Icons.arrow_drop_down_rounded, size: 24, color: SLColors.inkSoft),
        ],
      ),
    );

    final body = Container(
      decoration: Shop3dStyle.box(color: AppColors.cream, radius: 20),
      padding: EdgeInsets.only(left: 24, right: hasChoices ? 8 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: speaker == null ? 16 : 22, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Align(alignment: Alignment.topLeft, child: line)),
                  Align(alignment: Alignment.bottomRight, child: hint),
                ],
              ),
            ),
          ),
          if (hasChoices) ...[
            const SizedBox(width: 12),
            Container(
              width: choiceW,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: showChoices
                  ? Shop3dSlideIn(
                      from: const Offset(0.15, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.choices.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            Shop3dPillButton(
                              key: Shop3dDialoguePanel.choiceKey(i),
                              label: widget.choices[i],
                              onPressed: () => _fire(() => widget.onChoice?.call(i)),
                              width: choiceW,
                              height: Shop3dDialoguePanel.choiceHeight,
                              fontSize: 16,
                              maxLines: 2,
                              radius: 16,
                              alignStart: true,
                            ),
                          ],
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: mq.padding.bottom + widget.bottom,
      child: Center(
        child: SizedBox(
          width: w,
          height: h + over,
          child: Shop3dSlideIn(
            from: const Offset(0, 0.25),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: over,
                  bottom: 0,
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: speaker == null ? widget.text : '$speaker: ${widget.text}',
                    hint: hasChoices ? null : widget.tapHint,
                    onTap: _onTap,
                    child: GestureDetector(
                      key: Shop3dDialoguePanel.panelKey,
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: _onTap,
                      child: RepaintBoundary(child: body),
                    ),
                  ),
                ),
                if (speaker != null)
                  Positioned(
                    left: 24,
                    top: 4,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        decoration: Shop3dStyle.box(color: widget.speakerColor, radius: 16),
                        child: Text(speaker, maxLines: 1, style: Shop3dStyle.title(context, 20)),
                      ),
                    ),
                  ),
                if (showSkip)
                  Positioned(
                    right: 20,
                    top: 0,
                    child: Shop3dPillButton(
                      key: Shop3dDialoguePanel.skipKey,
                      label: widget.skipLabel,
                      icon: Icons.fast_forward_rounded,
                      onPressed: () => _fire(widget.onSkip),
                      color: AppColors.mint,
                      height: 36,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
