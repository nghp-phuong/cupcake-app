/// Quà đã cộng khi vuốt ve mèo Mochi (để UI hiện toast).
class MochiGift {
  const MochiGift({required this.coins, required this.gems});

  final int coins;

  /// > 0 chỉ ở lần vuốt ve đầu tiên trong đời game.
  final int gems;

  @override
  bool operator ==(Object other) => other is MochiGift && other.coins == coins && other.gems == gems;

  @override
  int get hashCode => Object.hash(coins, gems);

  @override
  String toString() => 'MochiGift(coins: $coins, gems: $gems)';
}
