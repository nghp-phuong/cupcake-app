import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/art/cake_art.dart';
import '../core/constants.dart';
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
/// Widget DUY NHẤT mà lib/ui import từ game. Chiếm trọn khung 1280×720. Không đọc/ghi `GameState`,
/// không chấm điểm: chỉ trả số đo thô qua [onComplete] (đúng 1 lần, sau hoạt cảnh đóng hộp).
class BakeSessionView extends StatefulWidget {
  const BakeSessionView({
    super.key,
    required this.order,
    required this.modifiers,
    required this.onComplete,
    this.tutorialFor = const {},
    this.onTutorialShown,
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

  /// Cấp lò (`state.ovenLevel`) để nạp sẵn ảnh lò; null → suy từ [modifiers].
  final int? ovenLevel;

  @override
  State<BakeSessionView> createState() => _BakeSessionViewState();
}

class _BakeSessionViewState extends State<BakeSessionView> {
  /// Khoá của lớp nhận con trỏ (test dùng để đổi toạ độ khung 1280×720 → toạ độ màn hình).
  static const inputKey = ValueKey('bake-session-input');

  late final BakeryGame _game;
  bool _completed = false;
  final Set<StationId> _tutorialReported = {};

  @override
  void initState() {
    super.initState();
    _game = BakeryGame(
      order: widget.order,
      modifiers: widget.modifiers,
      tutorialFor: widget.tutorialFor,
      ovenLevel: widget.ovenLevel,
    );
    _game.hud.addListener(_onHud);
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
    final outcome = hud.outcome;
    if (outcome != null && !_completed && mounted) {
      _completed = true;
      widget.onComplete(outcome);
    }
  }

  @override
  void dispose() {
    _game.hud.removeListener(_onHud);
    _game.hud.dispose();
    super.dispose();
  }

  bool _primary(PointerEvent e) => e.kind != PointerDeviceKind.mouse || (e.buttons & kPrimaryMouseButton) != 0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: kRefSize,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  key: inputKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    if (_primary(e)) _game.pointerDown(e.pointer, e.localPosition);
                  },
                  onPointerMove: (e) => _game.pointerMove(e.pointer, e.localPosition),
                  onPointerUp: (e) => _game.pointerUp(e.pointer, e.localPosition),
                  onPointerCancel: (e) => _game.pointerCancel(e.pointer),
                  child: GameWidget<BakeryGame>(game: _game),
                ),
              ),
              ListenableBuilder(
                listenable: _game.hud,
                builder: (context, _) => SLScope(child: _Overlay(order: widget.order, hud: _game.hud, game: _game)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.order, required this.hud, required this.game});

  final Order order;
  final BakeHud hud;
  final BakeryGame game;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final station = hud.station;
    final tutorial = hud.tutorial;
    return Stack(
      children: [
        // Dải giấy tràn qua mép trái/phải/trên khung: chỉ lộ mép dưới run tay.
        Positioned(left: -14, top: -16, width: 1308, height: 88, child: IgnorePointer(child: _StepBar(station: station))),
        Positioned(left: 960, top: 86, width: 300, height: 226, child: IgnorePointer(child: _OrderTicket(order: order))),
        Positioned(
          left: 952,
          top: 322,
          width: 316,
          height: 284,
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
        if (tutorial != null) Positioned.fill(child: _TutorialCard(station: tutorial, onGotIt: game.dismissTutorial)),
      ],
    );
  }
}

/// Thanh trên (HUD): dải giấy vẽ tay — 6 chấm bước (nhãn dán tròn) nối bằng vệt màu nước + tên trạm + "Bước x/6".
class _StepBar extends StatelessWidget {
  const _StepBar({required this.station});

  final StationId station;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final styles = SLTextStyles.of(context);
    final idx = station.index;
    return SLSurface(
      spec: const SLSurfaceSpec(shape: SLRoundRect(16), inkWidth: 2.6, seed: 0x57E9),
      lift: 4,
      // Phần lộ ra trong khung: x 0..1280, y 0..72 (dải lệch −14, −16).
      padding: const EdgeInsets.fromLTRB(14 + 24, 16, 14 + 24, 0),
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
