import 'dart:math' as math;

import '../../../core/l10n_lookup.dart';
import '../../../core/models/ids.dart';
import '../../../core/shift/shift_economy.dart';
import '../../../core/shift/shift_session.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'shift_cast.dart';
import 'shift_stage.dart';

/// Nối một ca bán ([ShiftSession] của core) với sân khấu 3D ([ShiftStage]) và bong bóng trên đầu khách
/// (docs/v3/city-gd3-spec.md §5). Dart thuần — không import thermion; test dùng thế giới giả.
///
/// - [start]: chọn chibi cho từng khách ([castForShift], khách VIP của đơn → `vip_01` / `vip_02`) rồi `stage.begin`.
/// - Stage báo khách tới quầy → `session.customerArrived()` + bong bóng câu gọi món (`orderLineText`).
/// - `baking → result` (kể cả sau khi làm lại) → khách phản ứng theo số sao ([ShiftStage.react]) + bong bóng lời chê
///   (nếu có) hoặc lời khen (`feedbackText`).
/// - `result → arriving` ("Khách tiếp") → [ShiftStage.dismiss]; `finished` / `aborted` → [ShiftStage.end].
/// - [stop]: thôi nghe phiên, khách còn lại đi ra ([ShiftStage.end]; đã kết thúc thì không làm gì).
///
/// Mở / khoá Mai, camera, dừng 3D lúc làm bánh là việc của lớp cảnh (`Town3dView`), không ở đây.
class ShiftBinder {
  ShiftBinder({
    required this.session,
    required this.stage,
    required this.say,
    required this.l10n,
    math.Random? random,
  }) : _random = random;

  final ShiftSession session;
  final ShiftStage stage;

  /// Bong bóng chữ [text] trên đầu chibi [actorId] trong [seconds] giây (`Shop3dPilot.say`).
  final void Function(String actorId, String text, double seconds) say;

  /// Chuỗi giao diện hiện tại; null = chưa có trong cây (bỏ bong bóng, ca vẫn chạy).
  final AppLocalizations? Function() l10n;

  /// Bong bóng câu gọi món / lời khen chê hiện chừng này giây.
  static const double orderSeconds = 4.0, feedbackSeconds = 3.5;

  final math.Random? _random;

  /// Pha đã thấy lần trước; null = chưa [start] hoặc đã [stop].
  ShiftPhase? _phase;
  bool _stopped = false;

  /// Đang nối (sau [start], trước [stop]).
  bool get running => _phase != null;

  /// Bắt đầu ca trên sân khấu: hạn tới quầy theo [ShiftEconomy.arriveTimeout]. Gọi một lần.
  void start() {
    if (_phase != null || _stopped) return;
    _phase = session.phase;
    session.addListener(_onSession);
    stage
      ..arriveTimeout = ShiftEconomy.arriveTimeout
      ..onArrived = _onArrived
      ..begin(castForShift(
        [for (final o in session.orders) o.customer.kind == CustomerKind.vip],
        random: _random,
      ));
  }

  /// Thôi nối: bỏ nghe phiên, khách còn lại đi ra, khách nền về vòng cũ.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    if (_phase == null) return;
    _phase = null;
    session.removeListener(_onSession);
    stage
      ..onArrived = null
      ..end();
  }

  void _onArrived(int index) {
    if (session.phase != ShiftPhase.arriving || index != session.index) return;
    session.customerArrived();
    final order = session.current.order;
    _say((l) => l.orderLineText(order.line, l.recipeName(order.recipe)), orderSeconds);
  }

  void _onSession() {
    final from = _phase, to = session.phase;
    if (from == null || from == to) return;
    _phase = to;
    switch (to) {
      case ShiftPhase.result when from == ShiftPhase.baking:
        final r = session.served?.result;
        if (r == null) return;
        stage.react(r.stars);
        _say((l) => l.feedbackText(r.complaint ?? r.praise), feedbackSeconds);
      case ShiftPhase.arriving when from == ShiftPhase.result:
        stage.dismiss();
      case ShiftPhase.finished:
      case ShiftPhase.aborted:
        stage.end();
      default:
        break;
    }
  }

  /// Bong bóng trên đầu khách đang ở quầy.
  void _say(String Function(AppLocalizations l) text, double seconds) {
    final id = stage.currentId, l = l10n();
    if (id == null || l == null) return;
    say(id, text(l), seconds);
  }
}
