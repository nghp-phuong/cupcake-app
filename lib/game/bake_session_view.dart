import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/art/art_sprites.dart';
import '../core/art/cake_art.dart';
import '../core/catalog.dart';
import '../core/ref_frame.dart';
import '../core/l10n_lookup.dart';
import '../core/models/bake.dart';
import '../core/models/ids.dart';
import '../core/models/order.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/common/art.dart';
import '../ui/sugarleaf/sugarleaf.dart';
import 'bakery_game.dart';

/// Màn làm bánh: 6 trạm (Flame) + lớp Flutter vẽ tay bộ SL* (thanh bước, vé đơn, gợi ý, nút Xong, thẻ hướng dẫn).
///
/// Widget DUY NHẤT mà lib/ui import từ game. Chiếm trọn khung W×720 (`RefMetrics`, W = 1280–1600): nền bếp và
/// thanh bước trải tới hai mép, sân chơi / vé đơn / gợi ý / nút Xong giữ trong vùng 1280 ở giữa. Không đọc/ghi `GameState`,
/// không chấm điểm: chỉ trả số đo thô qua [onComplete] (đúng 1 lần, sau hoạt cảnh đóng hộp).
class BakeSessionView extends StatefulWidget {
  const BakeSessionView({
    super.key,
    required this.order,
    required this.modifiers,
    required this.onComplete,
    this.tutorialFor = const {},
    this.onTutorialShown,
    this.recipeTutorial = false,
    this.onRecipeTutorialShown,
    this.ovenLevel,
  });

  final Order order;

  /// Từ `dayController.modifiers`.
  final BakeModifiers modifiers;

  /// Gọi ĐÚNG 1 lần sau trạm hộp (+0.6 s hoạt cảnh).
  final ValueChanged<BakeOutcome> onComplete;

  /// Trạm cần hiện thẻ hướng dẫn (= StationId.values − state.tutorialSeen).
  final Set<StationId> tutorialFor;

  /// Báo trạm vừa hiện thẻ hướng dẫn (ui gọi `state.markTutorialSeen`).
  final ValueChanged<StationId>? onTutorialShown;

  /// Lần đầu làm món của [order]: hiện thẻ hướng dẫn từng bước của món trước khi làm.
  final bool recipeTutorial;

  /// Báo thẻ hướng dẫn của món vừa hiện (ui ghi đã xem món này vào save).
  final VoidCallback? onRecipeTutorialShown;

  /// Cấp lò (`state.ovenLevel`) để nạp sẵn ảnh lò; null → suy từ [modifiers].
  final int? ovenLevel;

  @override
  State<BakeSessionView> createState() => _BakeSessionViewState();
}

class _BakeSessionViewState extends State<BakeSessionView> with WidgetsBindingObserver {
  /// Khoá của lớp nhận con trỏ (test dùng để đổi toạ độ khung W×720 → toạ độ màn hình; thế giới = khung − inset).
  static const inputKey = ValueKey('bake-session-input');

  late final BakeryGame _game;
  bool _completed = false;
  final Set<StationId> _tutorialReported = {};
  bool _recipeReported = false;

  @override
  void initState() {
    super.initState();
    _game = BakeryGame(
      order: widget.order,
      modifiers: widget.modifiers,
      tutorialFor: widget.tutorialFor,
      recipeTutorial: widget.recipeTutorial,
      ovenLevel: widget.ovenLevel,
    );
    _game.hud.addListener(_onHud);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Cỡ màn đổi (xoay, đổi cửa sổ): dựng lại để tính lại độ phân giải raster ([_pixelRatio]) — khung `RefFrame` giữ
  /// nguyên cỡ W×720 nên không có phụ thuộc nào khác báo việc này.
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    _game.setLabels(
      BakeLabels(mould: l.mouldName, topping: l.toppingName, box: l.boxName, hold: l.gameHold),
      fontFamily: text.bodyMedium?.fontFamily,
      titleFontFamily: text.titleLarge?.fontFamily,
      titleFallback: text.titleLarge?.fontFamilyFallback,
    );
  }

  void _onHud() {
    final hud = _game.hud;
    final tut = hud.tutorial;
    if (tut != null && _tutorialReported.add(tut)) widget.onTutorialShown?.call(tut);
    if (hud.recipeGuide && !_recipeReported) {
      _recipeReported = true;
      widget.onRecipeTutorialShown?.call();
    }
    final outcome = hud.outcome;
    if (outcome != null && !_completed && mounted) {
      _completed = true;
      widget.onComplete(outcome);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.hud.removeListener(_onHud);
    _game.hud.dispose();
    super.dispose();
  }

  bool _primary(PointerEvent e) => e.kind != PointerDeviceKind.mouse || (e.buttons & kPrimaryMouseButton) != 0;

  /// Toạ độ khung W×720 → toạ độ thế giới 1280×720 (trừ độ lệch vùng giữa).
  Offset _world(Offset p) => p.translate(-_game.inset, 0);

  /// Số điểm ảnh thật trên một đơn vị khung W×720 (DPR × hệ số co của khung lên màn). Khung `RefFrame` lấp màn
  /// theo chiều nhỏ hơn → tính từ cỡ màn vật lý; có vùng tai thỏ thì khung nhỏ hơn chút → ảnh dư điểm, không mờ.
  static double _pixelRatio(BuildContext context, Size frame) {
    final screen = View.of(context).physicalSize;
    final r = math.min(screen.width / frame.width, screen.height / frame.height);
    return r.isFinite && r > 0 ? r : MediaQuery.devicePixelRatioOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = RefMetrics.of(context);
    final ratio = _pixelRatio(context, metrics.size);
    _game.pixelRatio = ratio;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: metrics.size,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  key: inputKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    if (_primary(e)) _game.pointerDown(e.pointer, _world(e.localPosition));
                  },
                  onPointerMove: (e) => _game.pointerMove(e.pointer, _world(e.localPosition)),
                  onPointerUp: (e) => _game.pointerUp(e.pointer, _world(e.localPosition)),
                  onPointerCancel: (e) => _game.pointerCancel(e.pointer),
                  // Game không dùng phím: không giữ focus (mặc định autofocus nuốt mọi phím → Esc không tới lớp ca).
                  child: GameWidget<BakeryGame>(game: _game, autofocus: false),
                ),
              ),
              ListenableBuilder(
                listenable: _game.hud,
                builder: (context, _) => SLScope(
                    child: _Overlay(
                        order: widget.order, hud: _game.hud, game: _game, inset: metrics.inset, safe: metrics.safe, pixelRatio: ratio)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.order,
    required this.hud,
    required this.game,
    this.inset = 0,
    this.safe = EdgeInsets.zero,
    this.pixelRatio = 1,
  });

  final Order order;
  final BakeHud hud;
  final BakeryGame game;

  /// Độ lệch vùng nội dung 1280 trong khung rộng ((W − 1280) / 2; 0 ở máy 16:9).
  final double inset;

  /// Vùng tai thỏ (đơn vị ref) của khung rộng: chấm bước / chữ của thanh bước lùi vào.
  final EdgeInsets safe;

  /// Điểm ảnh thật / đơn vị khung: độ phân giải của ảnh chụp các mảng tĩnh ([_Snap]).
  final double pixelRatio;

  @override
  Widget build(BuildContext context) {
    final station = hud.station;
    final tutorial = hud.tutorial;
    return Stack(
      children: [
        // Dải giấy tràn qua mép trái/phải/trên khung (cả khung rộng): chỉ lộ mép dưới run tay.
        _Snap.positioned(
          left: -14,
          right: -14,
          top: -16,
          height: 88,
          token: station,
          pixelRatio: pixelRatio,
          child: IgnorePointer(child: _StepBar(station: station, safe: safe)),
        ),
        // Nội dung giữ trong vùng 1280 ở giữa khung.
        Positioned(
          left: inset,
          top: 0,
          width: 1280,
          height: 720,
          child: Stack(children: _content(context)),
        ),
        // Thẻ hướng dẫn (của món trước, rồi của trạm): nền tối phủ cả khung, thẻ ở giữa (giữa khung = giữa vùng 1280).
        if (hud.recipeGuide)
          Positioned.fill(child: _RecipeGuideCard(order: order, onGotIt: game.dismissRecipeGuide))
        else if (tutorial != null)
          Positioned.fill(child: _TutorialCard(station: tutorial, onGotIt: game.dismissTutorial)),
      ],
    );
  }

  /// Vé đơn, gợi ý, thông báo, nút Xong (toạ độ vùng 1280×720).
  List<Widget> _content(BuildContext context) {
    final l = AppLocalizations.of(context);
    final station = hud.station;
    return [
      _Snap.positioned(
        left: 960,
        top: 86,
        width: 300,
        height: 226,
        token: order,
        pixelRatio: pixelRatio,
        child: IgnorePointer(child: _OrderTicket(order: order)),
      ),
      _Snap.positioned(
        left: 952,
        top: 322,
        width: 316,
        height: 284,
        token: station,
        pixelRatio: pixelRatio,
        child: IgnorePointer(child: _HintPanel(station: station)),
      ),
      Positioned(
        left: 170,
        top: 136,
        width: 600,
        height: 90,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hud.toast == null
                ? const SizedBox.shrink()
                : Center(
                    key: ValueKey(hud.toastSerial),
                    child: _Toast(text: switch (hud.toast!) { GameToast.wrongMould => l.gameWrongMould }),
                  ),
          ),
        ),
      ),
      if (hud.doneVisible)
        Positioned(
          left: 1060,
          top: 620,
          width: 180,
          height: 70,
          child: SLButton(
            label: l.commonDone,
            icon: 'check',
            color: SLColors.mint,
            height: 70,
            fontSize: 26,
            seed: 0xD09E,
            onPressed: hud.doneEnabled ? game.pressDone : null,
          ),
        ),
    ];
  }
}

/// Mảng tĩnh của lớp phủ (thanh bước, vé đơn, giấy gợi ý): chụp MỘT lần thành ảnh ([SnapshotWidget]) ở độ phân giải
/// thật của màn ([pixelRatio]), mỗi khung chỉ dán ảnh.
///
/// Lý do: trên web (CanvasKit) không có raster cache — game Flame vẽ mỗi khung nên cả cây lớp được rasterize lại từ
/// đầu, và nét run tay / vân giấy / cắt theo viền của bộ SL* chiếm ~2/3 thời gian khung dù không đổi gì
/// (docs/v3/thermion-api-notes.md §31).
///
/// Ảnh chụp KHÔNG tự biết con vẽ lại (bộ SL* có `RepaintBoundary` riêng; AnimatedSwitcher / AnimatedScale chỉ cập
/// nhật layer) → khi [token] đổi, con chạy trực tiếp trong [settle] (dài hơn hoạt cảnh 250 ms) rồi mới chụp; ảnh vẽ
/// tay vừa nạp (`ArtSprites.changes`) hoặc font hệ thống đổi → chụp lại khi đã yên [settle] (đầu phiên ảnh bếp nạp
/// dồn dập: chụp lại theo từng ảnh tốn như vẽ trực tiếp).
class _Snap extends StatefulWidget {
  const _Snap({required this.token, required this.pixelRatio, required this.child});

  /// Lề thêm mỗi phía của ảnh chụp (bóng, nét lố, vé nghiêng nằm trọn trong ảnh).
  static const double margin = 12;

  /// Thời gian con chạy trực tiếp sau khi [token] đổi.
  static const Duration settle = Duration(milliseconds: 400);

  /// `Positioned` như cũ nhưng nới [margin] mỗi phía; con vẫn nhận đúng cỡ cũ (Padding bù lại).
  static Widget positioned({
    double? left,
    double? top,
    double? right,
    double? width,
    double? height,
    required Object? token,
    required double pixelRatio,
    required Widget child,
  }) {
    const m = margin;
    return Positioned(
      left: left == null ? null : left - m,
      top: top == null ? null : top - m,
      right: right == null ? null : right - m,
      width: width == null ? null : width + 2 * m,
      height: height == null ? null : height + 2 * m,
      child: _Snap(
        token: token,
        pixelRatio: pixelRatio,
        child: Padding(padding: const EdgeInsets.all(m), child: child),
      ),
    );
  }

  /// Đổi giá trị này (vd. trạm) → chạy trực tiếp [settle] rồi chụp lại.
  final Object? token;

  /// Điểm ảnh thật / đơn vị khung.
  final double pixelRatio;
  final Widget child;

  @override
  State<_Snap> createState() => _SnapState();
}

class _SnapState extends State<_Snap> {
  final SnapshotController _controller = SnapshotController();
  Timer? _settle;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    ArtSprites.changes.addListener(_refresh);
    PaintingBinding.instance.systemFonts.addListener(_refresh);
    _goLive();
  }

  @override
  void didUpdateWidget(_Snap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _goLive();
  }

  void _goLive() {
    _controller.allowSnapshotting = false;
    _settle?.cancel();
    _settle = Timer(_Snap.settle, () => _controller.allowSnapshotting = true);
  }

  void _refresh() {
    // Đang chạy trực tiếp → lần chụp tới đã có ảnh mới.
    if (!_controller.allowSnapshotting) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_Snap.settle, _controller.clear);
  }

  @override
  void dispose() {
    _settle?.cancel();
    _refreshTimer?.cancel();
    ArtSprites.changes.removeListener(_refresh);
    PaintingBinding.instance.systemFonts.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SnapshotWidget chụp theo devicePixelRatio của MediaQuery → đặt bằng độ phân giải thật của khung; con vẫn thấy
    // MediaQuery gốc.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(devicePixelRatio: widget.pixelRatio),
      child: SnapshotWidget(
        controller: _controller,
        mode: SnapshotMode.permissive,
        child: MediaQuery(data: media, child: widget.child),
      ),
    );
  }
}

/// Thanh trên (HUD): dải giấy vẽ tay — 6 chấm bước (nhãn dán tròn) nối bằng vệt màu nước + tên trạm + "Bước x/6".
class _StepBar extends StatelessWidget {
  const _StepBar({required this.station, this.safe = EdgeInsets.zero});

  final StationId station;

  /// Tai thỏ (khung rộng): nội dung lùi vào, dải giấy vẫn chạm mép.
  final EdgeInsets safe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final styles = SLTextStyles.of(context);
    final idx = station.index;
    return SLSurface(
      spec: const SLSurfaceSpec(shape: SLRoundRect(16), inkWidth: 2.6, seed: 0x57E9),
      lift: 4,
      // Phần lộ ra trong khung: x 0..W, y 0..72 (dải lệch −14, −16).
      padding: EdgeInsets.fromLTRB(14 + 24 + safe.left, 16, 14 + 24 + safe.right, 0),
      child: Row(
        children: [
          for (final s in StationId.values) ...[
            _StepDot(index: s.index, state: s.index < idx ? 0 : (s.index == idx ? 1 : 2)),
            if (s.index < StationId.values.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  width: 24,
                  height: 9,
                  child: SLSurface(
                    spec: SLSurfaceSpec(
                      shape: const SLRoundRect(4.5),
                      material: SLMaterial.wash,
                      color: s.index < idx ? SLColors.good : SLColors.paperShade,
                      inkWidth: 1.4,
                      seed: 0x5100 + s.index,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              l.stationName(station),
              style: theme.headlineSmall?.copyWith(color: SLColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            l.gameStepProgress(idx + 1, StationId.values.length),
            style: styles.label.copyWith(color: SLColors.inkSoft, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Chấm bước: nhãn dán tròn vẽ tay (xong: xanh + dấu tích, đang làm: hồng dâu to hơn, chưa tới: giấy cũ).
class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.state});

  final int index;

  /// 0 xong, 1 đang làm, 2 chưa tới.
  final int state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      0 => SLColors.good,
      1 => SLColors.strawberry,
      _ => SLColors.paperShade,
    };
    final ink = state == 2 ? SLColors.inkSoft : SLColors.ink;
    // Vẽ ở cỡ cố định 40 (một hình cache / trạng thái), to/nhỏ bằng AnimatedScale.
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: state == 1 ? 1 : 0.8,
      child: SizedBox.square(
        dimension: 40,
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: const SLCircle(),
            material: SLMaterial.wash,
            color: color,
            ink: ink,
            inkWidth: state == 1 ? 2.8 : 2.2,
            sticker: state == 1,
            seed: 0x5D07 + index,
          ),
          lift: state == 1 ? 3 : 0,
          child: Center(
            child: state == 0
                ? const SLIcon('check', size: 26)
                : Text(
                    '${index + 1}',
                    style: SLTextStyles.of(context).label.copyWith(fontSize: state == 1 ? 20 : 19, color: ink, height: 1),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Vé đơn nhỏ góc phải trên (vé giấy ghim, cùng kiểu vé ở quầy): tên món ở cuống; hình món, kem, topping × số, hộp.
class _OrderTicket extends StatelessWidget {
  const _OrderTicket({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final small = styles.body.copyWith(fontSize: 15);
    final bold = styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w800);
    return Align(
      alignment: Alignment.topCenter,
      child: SLOrderTicket(
        width: 300,
        stub: 44,
        tilt: -0.012,
        seed: 0x7C4E,
        header: Text(
          l.recipeName(order.recipe),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styles.title.copyWith(fontSize: 20),
        ),
        child: Row(
          children: [
            // Món đích: ảnh vẽ tay của món (như vé ở quầy); chưa nạp / thiếu ảnh → hình code.
            SizedBox(
              width: 86,
              height: 96,
              child: Center(child: CakeImage(visual: CakeVisual.order(order), recipe: order.recipe, size: 86)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TicketRow(
                    icon: FrostingSwatch(order.frosting, size: _TicketRow.iconSize),
                    child: Text(l.frostingName(order.frosting), style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  for (final t in order.toppings)
                    _TicketRow(
                      icon: ToppingImage(t.topping, size: _TicketRow.iconSize),
                      child: Text('${l.toppingName(t.topping)} ×${t.count}', style: bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  _TicketRow(
                    icon: BoxImage(order.box, size: _TicketRow.iconSize),
                    child: Text(l.boxName(order.box), style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một dòng vé: ảnh vẽ tay (kem / topping / hộp, tự vẽ lại khi ảnh nạp xong) + chữ.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.icon, required this.child});

  static const double iconSize = 28;

  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Ô gợi ý thao tác của trạm (cột phải, dưới vé đơn): giấy note vàng bơ dán băng dính, bóng đèn + tên trạm.
class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.station});

  final StationId station;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Padding(
          key: ValueKey(station),
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: SLPaperCard(
            attach: SLAttach.tape,
            color: SLColors.butterLight,
            tilt: 0.01,
            seed: 0x41E7,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SLIcon('bulb', size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.stationName(station),
                        style: styles.title.copyWith(fontSize: 21),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.stationHint(station), style: styles.body.copyWith(fontSize: 17, height: 1.3)),
                if (station == StationId.topping) ...[
                  const SizedBox(height: 8),
                  Text(l.gameTapToRemove, style: styles.body.copyWith(fontSize: 15, color: SLColors.inkSoft, height: 1.3)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lời nhắn ngắn trên vùng chơi: mẩu giấy hồng nhạt dán băng dính, dấu cảnh báo + chữ mực (cùng kiểu `SLToast`).
class _Toast extends StatelessWidget {
  const _Toast({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: SLPaperCard(
        attach: SLAttach.tape,
        color: SLColors.strawberryLight,
        tilt: -0.015,
        seed: 0x7057,
        padding: const EdgeInsets.fromLTRB(16, 10, 22, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SLIcon('warning', size: 30),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTextStyles.of(context).body.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hướng dẫn lần đầu vào trạm: che vùng chơi, bấm "Đã hiểu!" để chơi. Panel giấy có dải vải ghi tên trạm.
class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.station, required this.onGotIt});

  final StationId station;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return ColoredBox(
      color: SLColors.barrier,
      child: Center(
        child: SizedBox(
          width: 560,
          child: SLPanel(
            title: l.stationName(station),
            seed: 0x7E7A,
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 26),
            // Panel có dải tên co theo nội dung → giãn nội dung cho đủ 560.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: double.infinity),
                Text(
                  l.stationHint(station),
                  style: styles.body.copyWith(fontSize: 20, height: 1.35),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SLButton(label: l.gameTutorialGotIt, icon: 'check', onPressed: onGotIt, seed: 0x6071),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ hướng dẫn lần đầu làm một món: hình món + 6 bước của đơn này (trạm, thứ cần dùng, cách làm). Bấm "Đã hiểu!"
/// để bắt đầu; thẻ hướng dẫn của trạm (nếu có) hiện sau.
class _RecipeGuideCard extends StatelessWidget {
  const _RecipeGuideCard({required this.order, required this.onGotIt});

  final Order order;
  final VoidCallback onGotIt;

  static const double _icon = 30;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final recipe = Catalog.recipe(order.recipe);
    final toppings = [for (final t in order.toppings) '${l.toppingName(t.topping)} ×${t.count}'].join(', ');
    final steps = <(StationId, Widget, String?)>[
      (StationId.mould, MouldImage(recipe.mould, size: _icon), l.mouldName(recipe.mould)),
      (StationId.mix, BatterSwatch(recipe.batter, size: _icon), l.batterName(recipe.batter)),
      (StationId.bake, const SLIcon('oven', size: _icon), null),
      (StationId.frost, FrostingSwatch(order.frosting, size: _icon), l.frostingName(order.frosting)),
      (StationId.topping, ToppingImage(order.toppings.first.topping, size: _icon), toppings),
      (StationId.box, BoxImage(order.box, size: _icon), l.boxName(order.box)),
    ];
    final bold = styles.body.copyWith(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2);
    final hint = styles.body.copyWith(fontSize: 15, color: SLColors.inkSoft, height: 1.2);
    return ColoredBox(
      color: SLColors.barrier,
      child: Center(
        child: SizedBox(
          width: 820,
          child: SLPanel(
            title: l.unlockRecipe(l.recipeName(order.recipe)),
            seed: 0x7E7B,
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Center(child: CakeImage(visual: CakeVisual.order(order), recipe: order.recipe, size: 160)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, (station, icon, item)) in steps.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 26,
                                    child: Text('${i + 1}', style: styles.title.copyWith(fontSize: 20), textAlign: TextAlign.center),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(width: _icon, height: _icon, child: Center(child: icon)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item == null ? l.stationName(station) : '${l.stationName(station)}: $item',
                                          style: bold,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(l.stationHint(station), style: hint, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SLButton(label: l.gameTutorialGotIt, icon: 'check', onPressed: onGotIt, seed: 0x6072),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
