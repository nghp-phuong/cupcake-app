import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/city/city_game.dart';
import '../../core/city/recipe_unlocks.dart';
import '../../core/constants.dart';
import '../../core/models/bake.dart';
import '../../core/models/ids.dart';
import '../../core/ref_frame.dart';
import '../../core/services/ad_service.dart';
import '../../core/shift/shift_host.dart';
import '../../core/shift/shift_session.dart';
import '../../game/bake_session_view.dart';
import '../../l10n/gen/app_localizations.dart';
import '../day/order_ticket.dart';
import '../day/result_card.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';
import 'shift_news_card.dart';
import 'shift_summary_card.dart';

/// Lớp 2D của ca bán, phủ cảnh 3D trong cùng route (docs/v3/city-gd3-spec.md §2, §5). Đặt bằng `Positioned.fill`.
///
/// - arriving / ordering: HUD nhẹ theo px màn ([Shop3dStyle.scaleOf]), không nền, không che giữa màn: chip "Khách
///   x/y" (+ "Khách đang tới…"), nút X góc phải trên, vé đơn + nút "Làm bánh" bên phải.
/// - baking: 6 trạm ([BakeSessionView] trong [RefFrame]) mờ đục, chặn mọi chạm; X góc trái dưới.
/// - result: nền mờ nhạt + [ResultCard] (không chân dung) lệch phải.
/// - finished: nền mờ + [ShiftSummaryCard] ở giữa.
/// - Thẻ "Mở mới!" trước khách đầu khi `session.recipeNews` khác rỗng.
///
/// Đóng ca sớm bằng X, Esc ([CallbackShortcuts]; lúc làm bánh GameWidget của Flame nuốt phím nên nghe thêm
/// [HardwareKeyboard]) hoặc Back ([PopScope]): panel xác nhận ngay trong lớp → `abort` → toast → `host.close`.
class ShiftLayer extends StatefulWidget {
  const ShiftLayer({
    super.key,
    required this.session,
    required this.host,
    required this.ads,
    required this.game,
  });

  final ShiftSession session;
  final ShiftLayerHost host;
  final AdService ads;
  final CityGame game;

  @override
  State<ShiftLayer> createState() => _ShiftLayerState();
}

class _ShiftLayerState extends State<ShiftLayer> {
  /// Nền mờ nhạt sau thẻ kết quả / tổng kết / thẻ "Mở mới!" (cảnh 3D vẫn thấy rõ).
  static final _dim = AppColors.chocolate.withValues(alpha: 0.25);

  /// Toast trong lớp: dưới chip "Khách x/y" (kể cả máy thấp 360 dp).
  static const _toastAlign = Alignment(0, -0.35);

  final _focus = FocusNode(debugLabel: 'shift-layer');
  final _toasts = Shop3dToastController();

  late ShiftPhase _phase;

  /// Topping của thẻ "Mở mới!" (tính trước khi `acknowledgeRecipeNews` dời mốc `recipeSeen`).
  late List<ToppingId> _newToppings;

  /// Panel xác nhận đóng ca đang mở.
  late bool _confirm;

  /// Đang chờ quảng cáo: khoá nút, bỏ qua Esc / Back.
  late bool _busy;

  /// Đã gọi `host.close` (chờ cảnh gỡ lớp).
  late bool _closing;

  /// Esc vừa được [HardwareKeyboard] xử lý (cùng sự kiện có thể còn tới [CallbackShortcuts]).
  bool _escHandled = false;

  /// Tăng mỗi lần vào `baking` (làm lại → [BakeSessionView] mới).
  int _bakeSerial = 0;

  ShiftSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _attach();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void didUpdateWidget(ShiftLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      _attach();
    }
  }

  /// Bắt đầu nghe [ShiftLayer.session] (ca mới: xoá trạng thái của ca trước).
  void _attach() {
    _phase = _session.phase;
    _newToppings = _session.recipeNews.isEmpty
        ? const []
        : RecipeUnlocks.newToppings(widget.game.recipeSeen, _session.levelAtStart);
    _confirm = false;
    _busy = false;
    _closing = false;
    _session.addListener(_onSession);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _session.removeListener(_onSession);
    _toasts.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSession() {
    final phase = _session.phase;
    final leftBaking = _phase == ShiftPhase.baking && phase != ShiftPhase.baking;
    if (phase == ShiftPhase.baking && _phase != ShiftPhase.baking) _bakeSerial++;
    _phase = phase;
    if (!mounted) return;
    setState(() {});
    // GameWidget giữ focus khi làm bánh; gỡ xong thì lấy lại để Esc tới CallbackShortcuts.
    if (leftBaking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  /// Esc lúc đang làm bánh: GameWidget của Flame giữ focus và trả `handled` cho mọi phím, Esc không tới
  /// [CallbackShortcuts]. Handler của [HardwareKeyboard] chạy trước hệ focus, nên đánh dấu để không xử lý hai lần.
  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (_session.phase != ShiftPhase.baking || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _escHandled = true;
    scheduleMicrotask(() => _escHandled = false);
    _onBack();
    return true;
  }

  /// Esc / Back: đóng panel xác nhận nếu đang mở; hết ca → như "Xong"; còn lại → hỏi đóng ca.
  void _onBack() {
    if (_closing || _busy) return;
    if (_confirm) {
      setState(() => _confirm = false);
      return;
    }
    switch (_session.phase) {
      case ShiftPhase.finished:
        _done();
      case ShiftPhase.aborted:
        return;
      default:
        setState(() => _confirm = true);
    }
  }

  void _askClose() {
    if (_closing || _busy) return;
    setState(() => _confirm = true);
  }

  void _closeEarly() {
    if (_closing) return;
    if (_session.phase == ShiftPhase.baking) widget.host.setBaking(false);
    _session.abort();
    final l = AppLocalizations.of(context);
    // Đơn 1★ có thể lỗ (net < 0): toast chỉ báo xu giữ được, không hiện "+-N".
    _close(toast: l.shiftClosedToast(math.max(0, _session.summary?.totalCoins ?? 0)));
  }

  /// Gỡ lớp (một lần). [toast] hiện trên Overlay của app để còn thấy sau khi lớp bị gỡ.
  void _close({String? toast}) {
    if (_closing) return;
    setState(() {
      _closing = true;
      _confirm = false;
    });
    if (toast != null) _toastOverApp(toast);
    widget.host.close();
  }

  void _toastOverApp(String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final toasts = Shop3dToastController();
    final entry = OverlayEntry(
      builder: (_) => Stack(fit: StackFit.expand, children: [Shop3dToastHost(controller: toasts)]),
    );
    overlay.insert(entry);
    toasts.show(message);
    Timer(Shop3dToastController.defaultDuration + Shop3dStyle.fade, () {
      if (entry.mounted) entry.remove();
      entry.dispose();
      toasts.dispose();
    });
  }

  void _closeNews() {
    _session.acknowledgeRecipeNews();
  }

  void _startBaking() {
    if (_busy || _closing) return;
    _session.startBaking();
    if (_session.phase == ShiftPhase.baking) widget.host.setBaking(true);
  }

  void _bakeDone(BakeOutcome outcome) {
    if (_session.phase != ShiftPhase.baking) return;
    _session.completeBake(outcome);
    widget.host.setBaking(false);
  }

  void _next() {
    if (_busy || _closing) return;
    final level = _session.next();
    // Hết ca: thẻ tổng kết đã báo "Lên cấp!".
    if (level != null && _session.phase != ShiftPhase.finished) {
      _toasts.show(AppLocalizations.of(context).cityLevelUp);
    }
  }

  /// Xem quảng cáo thưởng ở [placement]; true = xem xong. Lỗi / không xem → toast (hết lượt hoặc chưa xem hết).
  Future<bool> _rewarded(AdPlacement placement) async {
    setState(() => _busy = true);
    var watched = false;
    try {
      watched = await widget.ads.showRewarded(context, placement);
    } catch (e) {
      debugPrint('ShiftLayer: quảng cáo ${placement.name} lỗi ($e)');
    }
    if (!mounted) return false;
    setState(() => _busy = false);
    if (!watched) {
      final l = AppLocalizations.of(context);
      _toasts.show(widget.ads.canShowRewarded() ? l.adNotCompleted : l.adsLimitReached);
    }
    return watched;
  }

  Future<void> _remake() async {
    if (_busy || _closing || !_session.canRemake) return;
    if (!await _rewarded(AdPlacement.remake) || _closing) return;
    _session.remake();
    if (_session.phase == ShiftPhase.baking) widget.host.setBaking(true);
  }

  Future<void> _double() async {
    if (_busy || _closing || !_session.canDouble) return;
    if (await _rewarded(AdPlacement.doubleCoins)) _session.applyDouble();
  }

  Future<void> _done() async {
    if (_busy || _closing) return;
    setState(() => _busy = true);
    try {
      if (widget.game.interstitialDue) {
        await widget.ads.showInterstitial(context);
        widget.game.registerInterstitialShown();
      }
    } catch (e) {
      // Quảng cáo lỗi không được giữ người chơi ở lại tổng kết.
      debugPrint('ShiftLayer: interstitial lỗi ($e)');
    }
    if (!mounted) return;
    _busy = false;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (!_escHandled) _onBack();
          },
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: SLScope(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: _closing ? const [] : _layers(context, constraints.biggest),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _layers(BuildContext context, Size size) {
    final l = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    final s = Shop3dStyle.scaleOf(size);
    final phase = _session.phase;
    final closeSize = math.max(Shop3dStyle.minTap, 52 * s);
    // Vùng thẻ giữa màn: chừa lề an toàn.
    final inner = Rect.fromLTRB(pad.left + 12, pad.top + 12, size.width - pad.right - 12, size.height - pad.bottom - 12);
    return [
      ...switch (phase) {
        ShiftPhase.arriving || ShiftPhase.ordering => _hud(l, size, pad, s, closeSize),
        ShiftPhase.baking => [_bakeLayer()],
        ShiftPhase.result => _resultLayer(size, pad, closeSize),
        ShiftPhase.finished => [
            _barrier(),
            Positioned.fromRect(
              rect: inner,
              child: Center(child: _summaryCard(size, inner.size)),
            ),
          ],
        ShiftPhase.aborted => const <Widget>[],
      },
      if (_session.recipeNews.isNotEmpty && phase != ShiftPhase.finished && phase != ShiftPhase.aborted) ...[
        _barrier(),
        Positioned.fromRect(
          rect: inner,
          child: Center(
            child: _fit(
              ShiftNewsCard.size,
              inner.size,
              size,
              ShiftNewsCard(recipes: _session.recipeNews, toppings: _newToppings, onClose: _closeNews),
            ),
          ),
        ),
      ],
      if (phase != ShiftPhase.finished && phase != ShiftPhase.aborted)
        Positioned(
          right: phase == ShiftPhase.baking ? null : pad.right + 12,
          top: phase == ShiftPhase.baking ? null : pad.top + 12,
          left: phase == ShiftPhase.baking ? pad.left + 12 : null,
          bottom: phase == ShiftPhase.baking ? pad.bottom + 12 : null,
          child: _CloseButton(size: closeSize, label: l.shiftCloseEarly, onPressed: _busy ? null : _askClose),
        ),
      if (_confirm) ...[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _confirm = false),
            child: const ColoredBox(color: SLColors.barrier),
          ),
        ),
        Positioned.fromRect(
          rect: inner,
          child: Center(
            child: _fit(
              _ConfirmPanel.size,
              inner.size,
              size,
              _ConfirmPanel(
                title: l.dayExitConfirmTitle,
                body: l.dayExitConfirmBody,
                confirmLabel: l.shiftCloseEarly,
                cancelLabel: l.commonCancel,
                onConfirm: _closeEarly,
                onCancel: () => setState(() => _confirm = false),
              ),
            ),
          ),
        ),
      ],
      Shop3dToastHost(controller: _toasts, alignment: _toastAlign),
    ];
  }

  /// Thẻ cỡ cố định [design] (đơn vị ref) co vừa [region]; không phóng quá hệ số khung `min(w/1280, h/720)` (≥ 1).
  /// Chữ không phóng theo cài đặt máy (bố cục cố định).
  static Widget _fit(Size design, Size region, Size screen, Widget child) {
    final cap = math.max(1.0, math.min(screen.width / kRefMinWidth, screen.height / kRefHeight));
    final k = math.max(
      0.1,
      math.min(cap, math.min(region.width / design.width, region.height / design.height)),
    );
    return SizedBox(
      width: design.width * k,
      height: design.height * k,
      child: FittedBox(
        child: SizedBox.fromSize(size: design, child: MediaQuery.withNoTextScaling(child: child)),
      ),
    );
  }

  /// Nền mờ nhạt, chặn chạm xuống cảnh.
  Widget _barrier() => Positioned.fill(
        child: Listener(behavior: HitTestBehavior.opaque, child: ColoredBox(color: _dim)),
      );

  /// arriving / ordering: chip tiến độ ở giữa mép trên; ordering thêm vé đơn + "Làm bánh" bên phải.
  List<Widget> _hud(AppLocalizations l, Size size, EdgeInsets pad, double s, double closeSize) {
    final ordering = _session.phase == ShiftPhase.ordering;
    // Chừa chỗ HUD tiền/cấp (trái, rộng 230) và nút X (phải).
    final chipMax = math.max(120.0, size.width - 2 * (12 + 230 + 12) - pad.horizontal);
    final widgets = <Widget>[
      Positioned(
        top: pad.top + 12,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: chipMax),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HudChip(
                    key: const ValueKey('shift-progress'),
                    text: l.dayCustomerProgress(_session.index + 1, _session.total),
                    scale: s,
                  ),
                  if (!ordering) ...[
                    SizedBox(height: 6 * s),
                    _HudChip(text: l.shiftCustomerComing, scale: s, soft: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ];
    if (!ordering) return widgets;
    const design = Size(580, 420);
    final gap = 8 * s;
    final buttonHeight = math.max(Shop3dStyle.minTap, 52 * s);
    final top = pad.top + 12 + closeSize + gap;
    final room = size.height - top - pad.bottom - 12 - buttonHeight - gap;
    final width = math.max(0.0, math.min(math.min(400 * s, size.width * 0.42), room * design.width / design.height));
    final current = _session.current;
    widgets.add(
      Positioned(
        right: pad.right + 12,
        top: top,
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              child: SizedBox(
                width: width,
                height: width * design.height / design.width,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: design,
                    child: MediaQuery.withNoTextScaling(
                      child: OrderTicket(order: current.order, customer: current.customer, height: design.height),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: gap),
            Shop3dPillButton(
              key: const ValueKey('shift-start-baking'),
              label: l.dayStartBaking,
              icon: Icons.cake_rounded,
              color: AppColors.mint,
              width: width,
              height: buttonHeight,
              fontSize: 18 * s,
              onPressed: _startBaking,
            ),
          ],
        ),
      ),
    );
    return widgets;
  }

  /// 6 trạm làm bánh: nền kem mờ đục, chặn mọi chạm xuống cảnh (kể cả vùng viền ngoài khung).
  Widget _bakeLayer() {
    final current = _session.current;
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: AppColors.cream,
          child: SLScope(
            child: RefFrame(
              child: BakeSessionView(
                key: ValueKey('shift-bake-${current.index}-$_bakeSerial'),
                order: current.order,
                modifiers: _session.modifiers,
                tutorialFor: _session.tutorialFor,
                onTutorialShown: _session.tutorialShown,
                recipeTutorial: _session.recipeTutorial,
                onRecipeTutorialShown: _session.recipeTutorialShown,
                onComplete: _bakeDone,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kết quả: nền mờ nhạt + thẻ lệch phải (bên trái để thấy khách 3D phản ứng), dưới nút X.
  List<Widget> _resultLayer(Size size, EdgeInsets pad, double closeSize) {
    final served = _session.served;
    if (served == null) return const [];
    const design = Size(720, 440);
    final top = pad.top + 12 + closeSize + 8;
    final bottom = pad.bottom + 12;
    final region = Size(size.width * 0.58, math.max(0.0, size.height - top - bottom));
    return [
      _barrier(),
      Positioned(
        right: pad.right + 16,
        top: top,
        bottom: bottom,
        width: region.width,
        child: Align(
          alignment: Alignment.centerRight,
          child: _fit(
            design,
            region,
            size,
            ResultCard(
              order: served.order.order,
              customer: served.order.customer,
              outcome: served.outcome,
              result: served.result,
              canRemake: _session.canRemake,
              onNext: _next,
              onRemake: _remake,
              busy: _busy,
              showPortrait: false,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _summaryCard(Size screen, Size region) {
    final summary = _session.summary!;
    return _fit(
      ShiftSummaryCard.sizeFor(summary),
      region,
      screen,
      ShiftSummaryCard(
        summary: summary,
        canDouble: _session.canDouble,
        busy: _busy,
        onDouble: _double,
        onDone: _done,
      ),
    );
  }
}

/// Chip HUD (nền kem viền nâu, bóng mềm) co theo [scale]; [soft] = chữ nhạt hơn, nhỏ hơn.
class _HudChip extends StatelessWidget {
  const _HudChip({super.key, required this.text, required this.scale, this.soft = false});

  final String text;
  final double scale;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 6 * scale),
      decoration: Shop3dStyle.box(color: soft ? SLColors.paper : AppColors.cream, radius: 18 * scale),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: soft
            ? Shop3dStyle.body(15 * scale, weight: FontWeight.w700, color: SLColors.inkSoft)
            : Shop3dStyle.title(context, 20 * scale),
      ),
    );
  }
}

/// Nút X tròn (đóng ca sớm), vùng chạm ≥ 48 dp. [onPressed] = null → mờ.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.size, required this.label, required this.onPressed});

  final double size;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final d = math.max(size, Shop3dStyle.minTap);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('shift-close'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: Shop3dStyle.circle(color: enabled ? AppColors.butter : SLColors.disabledFill),
          child: Icon(
            Icons.close_rounded,
            size: d * 0.55,
            color: enabled ? AppColors.chocolate : SLColors.disabledInk,
          ),
        ),
      ),
    );
  }
}

/// Panel xác nhận đóng ca sớm (ngay trong lớp, không mở route): tiêu đề, lời giải thích, Huỷ / Đóng ca sớm.
class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  static const size = Size(580, 320);

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: SizedBox.fromSize(
        size: size,
        child: SLPaperCard(
          attach: SLAttach.tape,
          radius: 24,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          seed: 0xC105,
          child: Column(
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: styles.title.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: Text(
                    body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: styles.body.copyWith(fontSize: 19, height: 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SLButton(
                      key: const ValueKey('shift-confirm-cancel'),
                      label: cancelLabel,
                      variant: SLButtonVariant.secondary,
                      onPressed: onCancel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SLButton(
                      key: const ValueKey('shift-confirm-close'),
                      label: confirmLabel,
                      color: AppColors.strawberry,
                      onPressed: onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
