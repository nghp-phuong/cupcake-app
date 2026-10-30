part of 'level_session.dart';

/// entering: từ cửa đi vào (tới hàng chờ / chỗ đặc biệt) · queued: đứng hàng chờ · atCounter: đứng quầy (sau tủ kính)
/// · leavingHappy / leavingSad: rời đi (xong hoạt cảnh thì biến khỏi `customers`).
enum CustomerPhase { entering, queued, atCounter, leavingHappy, leavingSad }

/// Khách trong màn. Đối tượng được TÁI DÙNG (pool): UI đừng giữ tham chiếu qua nhiều khung, hãy so theo [id].
/// Mọi trường chỉ đọc với UI; chỉ [LevelSession] sửa.
class LevelCustomer {
  LevelCustomer._();

  /// Thời lượng hoạt cảnh (giây) mà [phaseT] chạy 0 → 1.
  static const enterSec = 1.2, shiftSec = 0.5, toCounterSec = 0.6, leaveSec = 1.2;

  /// Dưới tỉ lệ này → nét mặt buồn / vòng kiên nhẫn đỏ.
  static const sadBelow = 0.3;

  int _id = 0;
  Customer _look = const Customer(kind: CustomerKind.regular, appearanceSeed: 0);
  bool _isSpecial = false;
  final List<RecipeId> _wants = [];
  late final List<RecipeId> _wantsView = UnmodifiableListView(_wants);
  double _patience = 0;
  double _patienceMax = 1;
  CustomerPhase _phase = CustomerPhase.entering;
  int _slot = 0;
  double _phaseT = 0;
  bool _turnedAway = false;
  bool _inSpecial = false;
  SpecialVisit? _visit;
  Order? _order;

  int get id => _id;

  /// Ngoại hình (dùng `CustomerArt` như V1).
  Customer get look => _look;
  bool get isSpecial => _isSpecial;

  /// 1–2 món chấp nhận, ưu tiên món đầu (bong bóng vẽ món đầu). Khách đặc biệt: món của đơn.
  List<RecipeId> get wants => _wantsView;
  RecipeId get want => _wants.first;

  /// Giây kiên nhẫn còn lại.
  double get patience => _patience;
  double get patienceMax => _patienceMax;

  /// 0..1.
  double get patienceFrac => _patienceMax <= 0 ? 0 : (_patience / _patienceMax).clamp(0.0, 1.0);

  CustomerPhase get phase => _phase;

  /// atCounter: chỗ quầy 0..counterSpots−1 · entering/queued: vị trí hàng chờ (0 = đầu hàng, gần quầy) ·
  /// leaving: chỗ vừa rời (−1 = khách quay đi ngay ở cửa vì hàng đầy). Khách đặc biệt luôn 0 (chỗ đặc biệt).
  int get slot => _slot;

  /// 0..1 tiến độ hoạt cảnh của pha hiện tại (đi vào, dịch hàng, bước lên quầy, rời đi); 1 = đứng yên.
  double get phaseT => _phaseT;

  /// Khách quay đi ở cửa vì hàng đầy (không vào hàng).
  bool get turnedAway => _turnedAway;

  /// Đang làm đơn đặc biệt của khách này (giữa `beginSpecial` và `finishSpecial`/`cancelSpecial`).
  bool get inSpecial => _inSpecial;

  /// Lượt ghé (chỉ khách đặc biệt).
  SpecialVisit? get visit => _visit;

  /// Đơn 6 trạm (chỉ khách đặc biệt).
  Order? get order => _order;

  bool get isLeaving => _phase == CustomerPhase.leavingHappy || _phase == CustomerPhase.leavingSad;

  /// Có thể bấm bán (khách vãng lai đang đứng quầy).
  bool get canBuy => !_isSpecial && _phase == CustomerPhase.atCounter;

  void _reset(int id) {
    _id = id;
    _isSpecial = false;
    _wants.clear();
    _patience = 0;
    _patienceMax = 1;
    _phase = CustomerPhase.entering;
    _slot = 0;
    _phaseT = 0;
    _turnedAway = false;
    _inSpecial = false;
    _visit = null;
    _order = null;
  }

  void _setPhase(CustomerPhase p) {
    _phase = p;
    _phaseT = 0;
  }

  @override
  String toString() => 'LevelCustomer(#$_id ${_phase.name} slot=$_slot wants=$_wants '
      'patience=${_patience.toStringAsFixed(1)}/${_patienceMax.toStringAsFixed(0)}${_isSpecial ? ' special' : ''})';
}
