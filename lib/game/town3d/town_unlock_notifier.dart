import '../../core/city/city_config.dart';
import 'town_rules.dart';

/// Báo "mở lô" khi Mai lên cấp (docs/v3/city-gd2-spec.md §5). Dart thuần (test không cần engine): lớp view gọi
/// [levelChanged] mỗi khi ví đổi, và [take] khi phố đang hiện, không bảng nào mở, chỗ toast trống.
///
/// - Mốc [seen] = cấp đã báo gần nhất (`CityGame.levelSeen`). Cấp > mốc và có lô chi nhánh mở trong khoảng (mốc; cấp]
///   → chờ [delay] sau lần lên cấp cuối (hiệu ứng "Lên cấp" của HUD) rồi [take] trả các lô đó, mốc = cấp, gọi
///   [onSeen]. Lên nhiều cấp trước khi kịp báo → gộp một toast.
/// - Lên cấp mà không lô nào mở → dời mốc ngay, không báo.
/// - Phố vừa hiện mà cấp > mốc (mốc lưu từ phiên trước) → báo bù ở lần [take] đầu, không chờ.
/// - Cấp giảm xuống dưới mốc (xoá dữ liệu) → đặt lại mốc = cấp, không báo.
class TownUnlockNotifier {
  /// Mốc được chuẩn hoá ngay (cấp < mốc, hoặc không lô nào mở) nhưng KHÔNG gọi [onSeen]: nơi tạo tự so [seen] với
  /// [levelSeen] để lưu lại nếu cần.
  TownUnlockNotifier(this.district, {required int level, required int levelSeen, this.onSeen})
      : _level = level,
        _seen = levelSeen {
    _settle();
  }

  /// Chờ sau lần lên cấp cuối, khớp hiệu ứng "Lên cấp" của `CityHud` (~1,6 s).
  static const delay = Duration(milliseconds: 1600);

  final DistrictDef district;

  /// Gọi khi mốc đổi (đã báo xong, hoặc đặt lại khi cấp giảm / lên cấp không mở lô nào).
  final void Function(int level)? onSeen;

  int _level;
  int _seen;
  Duration _dueAt = Duration.zero;

  /// Cấp hiện tại (theo lần [levelChanged] gần nhất).
  int get level => _level;

  /// Cấp đã báo gần nhất.
  int get seen => _seen;

  /// Có lô mới mở chưa báo.
  bool get pending => _level > _seen;

  /// Ví đổi: [level] là cấp hiện tại, [now] là đồng hồ đơn điệu của view.
  void levelChanged(int level, Duration now) {
    if (level == _level) return;
    if (level > _level) _dueAt = now + delay;
    _level = level;
    if (_settle()) onSeen?.call(_seen);
  }

  /// Đến lúc báo thì trả các lô vừa mở (theo cấp tăng dần), dời mốc = cấp và gọi [onSeen]; chưa thì trả rỗng.
  List<LotDef> take(Duration now) {
    if (!pending || now < _dueAt) return const [];
    final lots = TownRules.newlyUnlocked(district, _seen, _level);
    _seen = _level;
    onSeen?.call(_seen);
    return lots;
  }

  /// Chuẩn hoá mốc; true nếu đổi.
  bool _settle() {
    if (_level < _seen || (_level > _seen && TownRules.newlyUnlocked(district, _seen, _level).isEmpty)) {
      _seen = _level;
      return true;
    }
    return false;
  }
}
