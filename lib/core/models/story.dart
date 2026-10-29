import '../../l10n/gen/app_localizations.dart';
import 'ids.dart';
import 'order.dart';

class StoryLine {
  const StoryLine(this.speaker, this.text);

  final Speaker speaker;
  final String Function(AppLocalizations l) text;
}

class StoryScene {
  const StoryScene({
    required this.id,
    required this.minLevel,
    required this.minDay,
    this.featuredFriend,
    this.featuredRecipe,
    this.forcedToppings,
    required this.lines,
  });

  final StorySceneId id;
  final int minLevel;
  final int minDay;

  /// Nếu có: khách đầu tiên của ngày là bạn này, gọi `featuredRecipe`.
  final FriendId? featuredFriend;
  final RecipeId? featuredRecipe;
  final List<ToppingRequest>? forcedToppings;
  final List<StoryLine> lines;
}
