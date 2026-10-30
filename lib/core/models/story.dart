import '../../l10n/gen/app_localizations.dart';
import '../art/art_sprites.dart' show ArtScene;
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
    this.backdrop = ArtScene.storyGrandmaKitchen,
    required this.lines,
  });

  final StorySceneId id;
  final int minLevel;
  final int minDay;

  /// Nếu có: khách đầu tiên của ngày là bạn này, gọi `featuredRecipe`.
  final FriendId? featuredFriend;
  final RecipeId? featuredRecipe;
  final List<ToppingRequest>? forcedToppings;

  /// Nền cảnh (ảnh thiếu → `backdrop.fallback`).
  final ArtScene backdrop;
  final List<StoryLine> lines;
}
