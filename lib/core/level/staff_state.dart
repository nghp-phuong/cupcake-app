part of 'level_session.dart';

/// Một nhân viên đang làm trong màn (`LevelSession.staff`, thứ tự = `setup.staff` bỏ quản lý). Chỉ [LevelSession]
/// sửa; UI đọc để vẽ (vòng tiến độ, món đang làm, khách đang nhắm, nét mặt `smile` ngay sau khi làm xong).
class StaffState {
  StaffState._(this.member, this.index);

  final StaffMember member;

  /// Chỉ số trong `LevelSession.staff` (= `SessionEvent.staffIndex`).
  final int index;

  double _progress = 0;
  RecipeId? _working;
  int _workingStars = 0;
  int? _target;
  int _actions = 0;
  double _lastActionAt = -1e9;
  double _retryAt = 0;

  StaffRole get role => member.role;

  /// 0..1 tiến độ việc đang làm: thu ngân / phục vụ — đang phục vụ [targetCustomer] (0 khi chưa có ai); thợ — mẻ
  /// đang nướng (1 = mẻ xong nhưng tủ chưa đủ chỗ, chờ).
  double get progress => _progress;

  /// Thợ bánh: món đang làm (null = đang rảnh vì tủ không còn chỗ cho cả mẻ).
  RecipeId? get working => _working;

  /// Thợ bánh: số sao của mẻ đang làm (0 = không có mẻ).
  int get workingStars => _working == null ? 0 : _workingStars;

  /// Thu ngân / phục vụ: id khách đang phục vụ (khách quầy / khách chờ kiên nhẫn thấp nhất có món trong tủ); null nếu
  /// chưa có ai.
  int? get targetCustomer => _target;

  /// Số lượt đã làm xong (bán / mẻ).
  int get actions => _actions;

  /// `LevelSession.elapsed` lúc làm xong gần nhất (âm nếu chưa) — vẽ `smile` trong ~1 giây sau đó.
  double get lastActionAt => _lastActionAt;

  @override
  String toString() => 'StaffState(#$index ${member.id} ${role.name} progress=${_progress.toStringAsFixed(2)}'
      '${_working != null ? ' ${_working!.name}' : ''}${_target != null ? ' →#$_target' : ''} actions=$_actions)';
}
