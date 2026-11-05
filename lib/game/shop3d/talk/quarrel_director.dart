import 'dart:math' as math;

/// Lịch và máy trạng thái sự kiện khách gây gổ trước tiệm (docs/v3/interaction-spec.md mục 2.5). Dart thuần; dữ liệu
/// hội thoại của từng sự kiện nằm ở `quarrel_events.dart` (viết sau), file này chỉ lo thời gian và trạng thái.
///
/// Vòng đời một sự kiện:
/// `waiting` → (tới giờ, không có hội thoại) `gathering` ~6 s → `arguing` (banner, "Xem", "Mai ra xem") → Mai tới ≤
/// 1,6 m rồi can → `intervening` (hội thoại 3 lựa chọn, đồng hồ hết giờ tạm dừng) → [QuarrelDirector.resolve] →
/// `aftermath` (khách vào tiệm / phụng phịu bỏ đi; lớp cảnh gọi [QuarrelDirector.endAftermath] khi xong) → `waiting`.
/// Quá 45 s ở `arguing` mà chưa ai can: tín hiệu [QuarrelSignalKind.timedOut], chuyển thẳng `aftermath` (hai khách
/// phụng phịu bỏ đi, không trừ gì).
///
/// Lịch: sự kiện đầu sau 75 ± 15 s; các sự kiện sau cách 150–210 s tính từ lúc sự kiện trước kết thúc; tối đa 1 sự
/// kiện cùng lúc; xoay vòng [eventIds]. RNG tiêm vào để test.

enum QuarrelPhase { waiting, gathering, arguing, intervening, aftermath }

/// Tín hiệu do [QuarrelDirector.update] phát ra khi **đồng hồ** chuyển pha. Các thay đổi do chính lớp nối gọi hàm
/// ([QuarrelDirector.forceStart], [QuarrelDirector.beginIntervention]…) không phát tín hiệu — người gọi đã biết.
enum QuarrelSignalKind {
  /// Tới giờ: hai khách kéo tới (dựng / hiện cặp khách, cho họ đi vào vị trí).
  gatherStarted,

  /// Hai khách bắt đầu cãi (hiện banner "Có chuyện ồn ào trước cửa tiệm!").
  arguingStarted,

  /// Hết giờ 45 s: hai khách phụng phịu bỏ đi, toast "Hai vị khách phụng phịu bỏ đi mất rồi…". Đã sang `aftermath`.
  timedOut,

  /// `aftermath` quá [QuarrelDirector.aftermathMaxSeconds] mà lớp cảnh chưa báo xong: tự kết thúc sự kiện.
  ended,
}

class QuarrelSignal {
  const QuarrelSignal(this.kind, this.eventId);

  final QuarrelSignalKind kind;
  final String eventId;

  @override
  String toString() => 'QuarrelSignal($kind, $eventId)';
}

class QuarrelDirector {
  QuarrelDirector({
    math.Random? rng,
    List<String> eventIds = defaultEventIds,
    this.enabled = true,
    this.firstDelay = 75,
    this.firstJitter = 15,
    this.minGap = 150,
    this.maxGap = 210,
    this.gatherSeconds = 6,
    this.timeoutSeconds = 45,
    this.aftermathMaxSeconds = 90,
  })  : assert(eventIds.isNotEmpty),
        eventIds = List.unmodifiable(eventIds),
        _rng = rng ?? math.Random() {
    _wait = firstDelay - firstJitter + _rng.nextDouble() * 2 * firstJitter;
  }

  /// Id theo `?event=lastCake|first|tart`: Q1, Q2, Q3.
  static const List<String> defaultEventIds = ['lastCake', 'first', 'tart'];

  /// Mai cách tâm sự kiện ≤ giá trị này (m) thì được can / tự mở hội thoại sau "Mai ra xem".
  static const double interveneRange = 1.6;

  final math.Random _rng;
  final List<String> eventIds;

  /// Tắt = không tự bắt đầu sự kiện theo lịch ([forceStart] vẫn chạy được). Lineup, billboard, `actors=0`, `?events=0`.
  bool enabled;

  final double firstDelay, firstJitter, minGap, maxGap;
  final double gatherSeconds, timeoutSeconds, aftermathMaxSeconds;

  QuarrelPhase _phase = QuarrelPhase.waiting;
  double _wait = 0; // giây tới sự kiện kế (pha waiting)
  double _clock = 0; // giây trong pha gathering / aftermath
  double _argueClock = 0; // giây đã cãi mà chưa ai can
  int _next = 0; // chỉ số sự kiện kế trong eventIds
  String _current = '';
  bool _sendMai = false;
  final List<QuarrelSignal> _signals = [];

  QuarrelPhase get phase => _phase;

  /// Có sự kiện đang chạy không (mọi pha trừ `waiting`).
  bool get active => _phase != QuarrelPhase.waiting;

  /// Id sự kiện đang chạy ('' khi `waiting`).
  String get currentEventId => active ? _current : '';

  /// Sự kiện sẽ chạy kế tiếp — lớp cảnh dựng sẵn cặp khách của sự kiện này lúc rảnh.
  String get nextEventId => eventIds[_next];

  /// Giây còn lại tới lúc sự kiện kế tự bắt đầu (0 nếu đang chờ hội thoại xong; chỉ có nghĩa khi `waiting`).
  double get secondsUntilNext => _wait;

  /// Giây còn lại trước khi hết giờ (chỉ có nghĩa ở `arguing`).
  double get timeoutRemaining => math.max(0, timeoutSeconds - _argueClock);

  /// Nút A có thể thành "Can ngăn" (hai khách đang cãi, chưa ai can).
  bool get canIntervene => _phase == QuarrelPhase.arguing;

  /// Người chơi đã bấm "Mai ra xem" và Mai đang tự đi tới chỗ can.
  bool get sendMaiRequested => _sendMai;

  /// Tiến [dt] giây. [dialogueOpen]: đang có hội thoại thường (không tính hội thoại can ngăn) — sự kiện chưa bắt đầu sẽ
  /// chờ. Trả danh sách tín hiệu phát sinh (tái dùng giữa các lần gọi; đọc ngay).
  List<QuarrelSignal> update(double dt, {bool dialogueOpen = false}) {
    _signals.clear();
    switch (_phase) {
      case QuarrelPhase.waiting:
        if (!enabled) break;
        _wait = math.max(0, _wait - dt);
        if (_wait <= 0 && !dialogueOpen) _begin(eventIds[_next], emit: true);
      case QuarrelPhase.gathering:
        _clock += dt;
        if (_clock >= gatherSeconds) {
          _phase = QuarrelPhase.arguing;
          _argueClock = 0;
          _emit(QuarrelSignalKind.arguingStarted);
        }
      case QuarrelPhase.arguing:
        _argueClock += dt;
        if (_argueClock >= timeoutSeconds) {
          _sendMai = false;
          _phase = QuarrelPhase.aftermath;
          _clock = 0;
          _emit(QuarrelSignalKind.timedOut);
        }
      case QuarrelPhase.intervening:
        break; // đồng hồ hết giờ tạm dừng trong hội thoại can ngăn
      case QuarrelPhase.aftermath:
        _clock += dt;
        if (_clock >= aftermathMaxSeconds) {
          final id = _current;
          endAftermath();
          _signals.add(QuarrelSignal(QuarrelSignalKind.ended, id));
        }
    }
    return _signals;
  }

  /// Ép chạy sự kiện [id] ngay (test / nút debug / `?event=`). false nếu id không có hoặc đang có sự kiện.
  bool forceStart(String id) {
    final i = eventIds.indexOf(id);
    if (i < 0 || active) return false;
    _next = i;
    _begin(id, emit: false);
    return true;
  }

  void _begin(String id, {required bool emit}) {
    _current = id;
    _next = (eventIds.indexOf(id) + 1) % eventIds.length;
    _phase = QuarrelPhase.gathering;
    _clock = 0;
    _argueClock = 0;
    _sendMai = false;
    if (emit) _emit(QuarrelSignalKind.gatherStarted);
  }

  /// "Mai ra xem": Mai tự đi tới chỗ can (chỉ khi đang cãi). Người chơi đẩy joystick thì gọi [cancelSendMai].
  bool requestSendMai() {
    if (_phase != QuarrelPhase.arguing) return false;
    _sendMai = true;
    return true;
  }

  void cancelSendMai() => _sendMai = false;

  /// Gọi mỗi khung khi Mai tự đi: true đúng một lần khi Mai tới cách tâm sự kiện ≤ [interveneRange] — lúc đó mở
  /// hội thoại (rồi gọi [beginIntervention]).
  bool maiArrived(double distanceToCenter) {
    if (!_sendMai || _phase != QuarrelPhase.arguing || distanceToCenter > interveneRange) return false;
    _sendMai = false;
    return true;
  }

  /// Mai bắt đầu can (từ nút A "Can ngăn" hoặc [maiArrived]). false nếu không phải lúc.
  bool beginIntervention() {
    if (_phase != QuarrelPhase.arguing) return false;
    _sendMai = false;
    _phase = QuarrelPhase.intervening;
        return true;
  }

  /// Hội thoại can ngăn bị huỷ (thôi điều khiển…): về lại `arguing`, đồng hồ hết giờ chạy tiếp.
  void cancelIntervention() {
    if (_phase != QuarrelPhase.intervening) return;
    _phase = QuarrelPhase.arguing;
  }

  /// Hội thoại can ngăn xong (đã chọn): sang `aftermath` để khách vào tiệm / bỏ đi.
  void resolve() {
    if (_phase != QuarrelPhase.intervening) return;
    _phase = QuarrelPhase.aftermath;
    _clock = 0;
  }

  /// Lớp cảnh báo khách đã vào tiệm / bỏ đi xong: kết thúc sự kiện và hẹn sự kiện sau 150–210 s.
  void endAftermath() {
    if (_phase != QuarrelPhase.aftermath) return;
    _phase = QuarrelPhase.waiting;
    _wait = minGap + _rng.nextDouble() * (maxGap - minGap);
    _clock = 0;
  }

  /// Huỷ sự kiện đang chạy (đổi chế độ cảnh…). Không đổi lịch.
  void abort() {
    if (_phase == QuarrelPhase.waiting) return;
    _phase = QuarrelPhase.waiting;
    _sendMai = false;
  }

  void _emit(QuarrelSignalKind k) => _signals.add(QuarrelSignal(k, _current));
}
