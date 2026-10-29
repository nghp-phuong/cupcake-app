import 'ids.dart';

class Customer {
  const Customer({required this.kind, this.friend, required this.appearanceSeed});

  final CustomerKind kind;

  /// != null khi kind == friend.
  final FriendId? friend;

  /// `CustomerArt` dùng để chọn màu tóc/áo.
  final int appearanceSeed;

  bool get isVip => kind == CustomerKind.vip;

  @override
  bool operator ==(Object other) =>
      other is Customer && other.kind == kind && other.friend == friend && other.appearanceSeed == appearanceSeed;

  @override
  int get hashCode => Object.hash(kind, friend, appearanceSeed);

  @override
  String toString() => 'Customer(${kind.name} ${friend?.name ?? '-'} seed=$appearanceSeed)';
}
