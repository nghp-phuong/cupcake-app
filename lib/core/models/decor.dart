import 'ids.dart';

class DecorItem {
  const DecorItem({
    required this.id,
    required this.slot,
    this.coinPrice = 0,
    this.gemPrice = 0,
    required this.unlockLevel,
    required this.tipBonusPct,
  });

  final DecorId id;
  final DecorSlot slot;
  final int coinPrice;

  /// 0 nếu trả xu.
  final int gemPrice;
  final int unlockLevel;
  final int tipBonusPct;

  bool get paidWithGems => gemPrice > 0;
}
