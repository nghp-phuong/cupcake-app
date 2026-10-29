import 'ids.dart';

class QuestDef {
  const QuestDef({required this.type, required this.target, this.rewardCoins = 0, this.rewardGems = 0});

  final QuestType type;
  final int target;
  final int rewardCoins;
  final int rewardGems;
}

/// Tiến trình một nhiệm vụ hôm nay. `target` lấy từ `Catalog.quest(type)`.
class QuestProgress {
  const QuestProgress({required this.type, this.progress = 0, this.claimed = false});

  final QuestType type;
  final int progress;
  final bool claimed;

  QuestProgress copyWith({int? progress, bool? claimed}) =>
      QuestProgress(type: type, progress: progress ?? this.progress, claimed: claimed ?? this.claimed);

  @override
  bool operator ==(Object other) =>
      other is QuestProgress && other.type == type && other.progress == progress && other.claimed == claimed;

  @override
  int get hashCode => Object.hash(type, progress, claimed);

  @override
  String toString() => 'QuestProgress(${type.name} $progress claimed=$claimed)';
}

class LoginReward {
  const LoginReward({required this.day, this.coins = 0, this.gems = 0});

  /// 1..7.
  final int day;
  final int coins;
  final int gems;

  @override
  bool operator ==(Object other) =>
      other is LoginReward && other.day == day && other.coins == coins && other.gems == gems;

  @override
  int get hashCode => Object.hash(day, coins, gems);

  @override
  String toString() => 'LoginReward(day $day: $coins coins, $gems gems)';
}
