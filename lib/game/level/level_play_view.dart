import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/l10n_lookup.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../core/staff/staff.dart';
import '../../l10n/gen/app_localizations.dart';
import 'level_characters.dart';
import 'level_game.dart';
import 'level_labels.dart';

/// Màn chơi level (Flame): sân tiệm (y 64–440) + bếp nhanh (y 440–720). Widget DUY NHẤT mà lib/ui import từ
/// `lib/game/level/`.
///
/// Chiếm khung 1280×720 (FittedBox như `BakeSessionView`); y 0–64 vẽ nền tiệm nhưng không nhận chạm — HUD của ui vẽ
/// đè. Mỗi khung gọi `session.advance(dt)`, tự rút `drainEvents()` → hiệu ứng rồi chuyển cho [onEvent]. Không đọc/ghi
/// `GameState`. Chịu được việc bị ẩn tạm (Offstage/TickerMode) rồi hiện lại: khung dài được session kẹp lại.
///
/// Theo dõi cỡ cửa sổ (`View.physicalSize`) để ảnh nhân vật giải mã đúng độ nét của màn (`LevelCharacters.pixelScale`).
class LevelPlayView extends StatefulWidget {
  const LevelPlayView({
    super.key,
    required this.session,
    required this.onSpecialTap,
    this.onEvent,
    this.decor = const {},
    this.tutorialText,
    this.festiveOutfits = false,
  });

  /// Đồ đã mua (kệ bánh tầng, lò thứ 2, bàn ghế, cấp lò nhanh) đọc từ `session.setup`.
  final LevelSession session;

  /// Đồ trang trí đã đặt (`GameState.equippedDecor`): ô quầy (bình hoa / bánh chuông kính) và cây được vẽ trong tiệm;
  /// tường / sàn / cửa sổ không vẽ ở màn chơi level (nền tiệm là một ảnh vẽ sẵn).
  final Map<DecorSlot, DecorId?> decor;

  /// Chạm khách đặc biệt đang chờ ở mép trái quầy (id khách) → ui gọi `session.beginSpecial(id)`.
  final ValueChanged<int> onSpecialTap;

  /// Mỗi sự kiện của session (âm thanh / rung ở ui).
  final ValueChanged<SessionEvent>? onEvent;

  /// Chữ đã dịch của bước hướng dẫn L1–L3 theo id bước (`TutorialStep.id`); null → chữ tiếng Anh dự phòng
  /// (`LevelLabels.fallbackTutorial`). Nên là hàm ổn định (đổi hàm → dựng lại nhãn).
  final String Function(String step)? tutorialText;

  /// Trang phục lễ hội của nhân viên đang bật (mua `staffOutfits` + bật ở tab Nhân viên): nhân viên dùng ảnh
  /// `<character>_fest_<expr>` (thiếu → ảnh thường). Chỉ đổi hình.
  final bool festiveOutfits;

  /// Nạp sẵn (không chặn) ảnh của [level] trước khi mở màn chơi. Không bao giờ báo lỗi, không cần `await`.
  /// [staff]: nhân viên đã thuê (`ShopSetup.staff`) — ảnh nhân viên nạp trước ảnh khách. [festiveOutfits]: như
  /// [LevelPlayView.festiveOutfits] (nạp ảnh trang phục lễ hội trước).
  static Future<void> preload(LevelData level,
          {int ovenLevel = 1,
          Map<DecorSlot, DecorId?> decor = const {},
          List<StaffMember> staff = const [],
          bool festiveOutfits = false}) =>
      LevelGame.preloadFor(level, ovenLevel: ovenLevel, decor: decor, staff: staff, festiveOutfits: festiveOutfits);

  @override
  State<LevelPlayView> createState() => _LevelPlayViewState();
}

class _LevelPlayViewState extends State<LevelPlayView> with WidgetsBindingObserver {
  /// Khoá của lớp nhận con trỏ (test đổi toạ độ khung 1280×720 → toạ độ màn hình).
  static const inputKey = ValueKey('level-play-input');

  late final LevelGame _game;

  @override
  void initState() {
    super.initState();
    _game = LevelGame(
      session: widget.session,
      onSpecialTap: (id) => widget.onSpecialTap(id),
      onEvent: (e) => widget.onEvent?.call(e),
      decor: widget.decor,
      festiveOutfits: widget.festiveOutfits,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Đổi cỡ cửa sổ / xoay máy: chỉ giải mã lại ảnh nhân vật khi sang bậc hệ số màn khác.
  @override
  void didChangeMetrics() {
    if (mounted) LevelCharacters.updatePixelScale(View.of(context).physicalSize);
  }

  @override
  void didUpdateWidget(LevelPlayView old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) _game.attachSession(widget.session);
    _game.decor = widget.decor;
    _game.festiveOutfits = widget.festiveOutfits;
    if (old.tutorialText != widget.tutorialText) _applyLabels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    LevelCharacters.updatePixelScale(View.of(context).physicalSize);
    _applyLabels();
  }

  void _applyLabels() {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    _game.setLabels(
      LevelLabels(
        caseFull: l.lvlCaseFull,
        rushHour: l.lvlRushHour,
        combo: l.lvlCombo,
        done: l.commonDone,
        waitOven: l.lvlWaitOven,
        waiting: l.lvlWaiting,
        pickTreat: l.lvlPickTreat,
        burnt: l.lvlBurnt,
        takeOut: l.lvlTakeOut,
        stirHint: l.lvlStirHint,
        swipeHint: l.lvlSwipeHint,
        station: l.stationName,
        mould: l.mouldName,
        box: l.boxName,
        tutorial: widget.tutorialText ?? LevelLabels.fallbackTutorial,
      ),
      fontFamily: text.bodyMedium?.fontFamily,
      titleFontFamily: text.titleLarge?.fontFamily,
      titleFallback: text.titleLarge?.fontFamilyFallback,
    );
  }

  bool _primary(PointerEvent e) => e.kind != PointerDeviceKind.mouse || (e.buttons & kPrimaryMouseButton) != 0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: kRefSize,
        child: ClipRect(
          child: Listener(
            key: inputKey,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              if (_primary(e)) _game.pointerDown(e.pointer, e.localPosition);
            },
            onPointerMove: (e) => _game.pointerMove(e.pointer, e.localPosition),
            onPointerUp: (e) => _game.pointerUp(e.pointer, e.localPosition),
            onPointerCancel: (e) => _game.pointerCancel(e.pointer),
            child: GameWidget<LevelGame>(game: _game),
          ),
        ),
      ),
    );
  }
}
