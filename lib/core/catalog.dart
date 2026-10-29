import 'models/decor.dart';
import 'models/ids.dart';
import 'models/order.dart';
import 'models/quest.dart';
import 'models/recipe.dart';
import 'models/story.dart';

/// Dữ liệu tĩnh: món, topping, trang trí, cảnh truyện, nhiệm vụ, quà đăng nhập, gói IAP.
abstract final class Catalog {
  // ---------------------------------------------------------------- Món

  /// 10 món alpha, đúng thứ tự đặc tả.
  static const List<Recipe> recipes = [
    Recipe(
      id: RecipeId.cupcakeVanilla,
      unlockLevel: 1,
      price: 30,
      cost: 8,
      mould: MouldType.cupcakeLiner,
      batter: BatterType.vanilla,
      frostings: [FrostingId.vanillaCream, FrostingId.strawberryCream],
      toppings: [ToppingId.sprinkles, ToppingId.strawberry, ToppingId.cherry],
      mixTurns: 3,
      bakeTarget: 0.65,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.cupcakeChocolate,
      unlockLevel: 1,
      price: 34,
      cost: 9,
      mould: MouldType.cupcakeLiner,
      batter: BatterType.chocolate,
      frostings: [FrostingId.chocolateGanache, FrostingId.vanillaCream],
      toppings: [ToppingId.sprinkles, ToppingId.chocolateChips, ToppingId.cherry],
      mixTurns: 3,
      bakeTarget: 0.70,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.muffinBlueberry,
      unlockLevel: 2,
      price: 38,
      cost: 10,
      mould: MouldType.muffinCup,
      batter: BatterType.vanilla,
      frostings: [FrostingId.vanillaCream],
      toppings: [ToppingId.blueberry, ToppingId.sugarPearl, ToppingId.sprinkles],
      mixTurns: 3,
      bakeTarget: 0.72,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.eggTart,
      unlockLevel: 3,
      price: 42,
      cost: 11,
      mould: MouldType.tartShell,
      batter: BatterType.butter,
      frostings: [FrostingId.custard],
      toppings: [ToppingId.mintLeaf, ToppingId.strawberry],
      mixTurns: 4,
      bakeTarget: 0.62,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.strawberryCake,
      unlockLevel: 4,
      price: 60,
      cost: 15,
      mould: MouldType.roundPan,
      batter: BatterType.vanilla,
      frostings: [FrostingId.strawberryCream, FrostingId.vanillaCream],
      toppings: [ToppingId.strawberry, ToppingId.sprinkles, ToppingId.mintLeaf],
      mixTurns: 4,
      bakeTarget: 0.68,
      box: BoxType.cake,
    ),
    Recipe(
      id: RecipeId.macaron,
      unlockLevel: 5,
      price: 50,
      cost: 13,
      mould: MouldType.macaronMat,
      batter: BatterType.almond,
      frostings: [FrostingId.strawberryCream, FrostingId.vanillaCream, FrostingId.matchaCream],
      toppings: [ToppingId.sugarPearl, ToppingId.sprinkles],
      mixTurns: 5,
      bakeTarget: 0.55,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.redVelvetCupcake,
      unlockLevel: 6,
      price: 46,
      cost: 12,
      mould: MouldType.cupcakeLiner,
      batter: BatterType.redVelvet,
      frostings: [FrostingId.creamCheese],
      toppings: [ToppingId.cherry, ToppingId.chocolateChips, ToppingId.sprinkles],
      mixTurns: 4,
      bakeTarget: 0.70,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.matchaCake,
      unlockLevel: 8,
      price: 70,
      cost: 18,
      mould: MouldType.roundPan,
      batter: BatterType.matcha,
      frostings: [FrostingId.matchaCream, FrostingId.vanillaCream],
      toppings: [ToppingId.strawberry, ToppingId.mintLeaf, ToppingId.sugarPearl],
      mixTurns: 4,
      bakeTarget: 0.66,
      box: BoxType.cake,
    ),
    Recipe(
      id: RecipeId.cheesecake,
      unlockLevel: 10,
      price: 80,
      cost: 20,
      mould: MouldType.springformPan,
      batter: BatterType.cheese,
      frostings: [FrostingId.creamCheese],
      toppings: [ToppingId.blueberry, ToppingId.strawberry, ToppingId.cherry],
      mixTurns: 4,
      bakeTarget: 0.75,
      box: BoxType.cake,
    ),
    Recipe(
      id: RecipeId.birthdayCake,
      unlockLevel: 12,
      price: 110,
      cost: 28,
      mould: MouldType.tallPan,
      batter: BatterType.vanilla,
      frostings: [FrostingId.vanillaCream, FrostingId.chocolateGanache, FrostingId.strawberryCream],
      toppings: [ToppingId.candle, ToppingId.sprinkles, ToppingId.strawberry, ToppingId.cherry],
      mixTurns: 5,
      bakeTarget: 0.72,
      box: BoxType.cake,
    ),
  ];

  static Recipe recipe(RecipeId id) => recipes.firstWhere((r) => r.id == id);

  // ---------------------------------------------------------------- Topping

  /// Cấp tiệm mở từng topping. Topping chỉ được gọi khi đã mở.
  static const Map<ToppingId, int> toppingUnlockLevel = {
    ToppingId.sprinkles: 1,
    ToppingId.strawberry: 1,
    ToppingId.cherry: 1,
    ToppingId.chocolateChips: 1,
    ToppingId.blueberry: 2,
    ToppingId.mintLeaf: 3,
    ToppingId.sugarPearl: 5,
    ToppingId.candle: 12,
  };

  // ---------------------------------------------------------------- Trang trí

  static const List<DecorItem> decor = [
    DecorItem(id: DecorId.wallpaperStripes, slot: DecorSlot.wallpaper, coinPrice: 400, unlockLevel: 1, tipBonusPct: 3),
    DecorItem(id: DecorId.wallpaperFloral, slot: DecorSlot.wallpaper, coinPrice: 1200, unlockLevel: 6, tipBonusPct: 6),
    DecorItem(id: DecorId.floorCheckered, slot: DecorSlot.floor, coinPrice: 400, unlockLevel: 2, tipBonusPct: 3),
    DecorItem(id: DecorId.floorHerringbone, slot: DecorSlot.floor, coinPrice: 1200, unlockLevel: 7, tipBonusPct: 6),
    DecorItem(id: DecorId.counterFlowers, slot: DecorSlot.counter, coinPrice: 300, unlockLevel: 1, tipBonusPct: 2),
    DecorItem(id: DecorId.counterCakeStand, slot: DecorSlot.counter, coinPrice: 1000, unlockLevel: 5, tipBonusPct: 5),
    DecorItem(id: DecorId.windowCurtains, slot: DecorSlot.window, coinPrice: 350, unlockLevel: 3, tipBonusPct: 2),
    DecorItem(id: DecorId.windowSeaView, slot: DecorSlot.window, gemPrice: 30, unlockLevel: 1, tipBonusPct: 6),
    DecorItem(id: DecorId.plantFern, slot: DecorSlot.plant, coinPrice: 250, unlockLevel: 2, tipBonusPct: 2),
    DecorItem(id: DecorId.plantLemonTree, slot: DecorSlot.plant, gemPrice: 25, unlockLevel: 8, tipBonusPct: 5),
  ];

  static DecorItem decorItem(DecorId id) => decor.firstWhere((d) => d.id == id);

  /// Các món trang trí của một ô (không gồm "Cơ bản" = null).
  static List<DecorItem> decorForSlot(DecorSlot slot) => decor.where((d) => d.slot == slot).toList();

  // ---------------------------------------------------------------- Nhiệm vụ, quà

  static const List<QuestDef> quests = [
    QuestDef(type: QuestType.serveCustomers, target: 8, rewardCoins: 60),
    QuestDef(type: QuestType.earnStars, target: 15, rewardCoins: 60),
    QuestDef(type: QuestType.perfectBakes, target: 3, rewardCoins: 80),
    QuestDef(type: QuestType.fiveStarTreats, target: 2, rewardCoins: 80),
    QuestDef(type: QuestType.earnCoins, target: 250, rewardGems: 2),
    QuestDef(type: QuestType.earnTips, target: 50, rewardCoins: 70),
  ];

  static QuestDef quest(QuestType type) => quests.firstWhere((q) => q.type == type);

  /// Quà đăng nhập 7 ngày, index 0 = ngày 1.
  static const List<LoginReward> loginRewards = [
    LoginReward(day: 1, coins: 50),
    LoginReward(day: 2, coins: 80),
    LoginReward(day: 3, gems: 3),
    LoginReward(day: 4, coins: 120),
    LoginReward(day: 5, coins: 150),
    LoginReward(day: 6, gems: 5),
    LoginReward(day: 7, coins: 300, gems: 10),
  ];

  static LoginReward loginReward(int day) => loginRewards[(day - 1).clamp(0, loginRewards.length - 1)];

  // ---------------------------------------------------------------- IAP (giả lập)

  /// Xu trao cho từng gói IAP (ui dùng cho `storeStarterPackDesc`, `storePantryDesc`).
  static const Map<IapProductId, int> iapCoins = {
    IapProductId.starterPack: 1000,
    IapProductId.pantryS: 500,
    IapProductId.pantryM: 1800,
    IapProductId.pantryL: 5000,
  };

  /// Gem trao cho từng gói IAP.
  static const Map<IapProductId, int> iapGems = {IapProductId.starterPack: 30};

  /// Đồ trang trí trong bộ "Seaside" (sở hữu ngay, bỏ qua cấp mở).
  static const List<DecorId> decorSetSeaside = [DecorId.windowSeaView, DecorId.plantLemonTree, DecorId.wallpaperFloral];

  // ---------------------------------------------------------------- Truyện chương 1

  /// Cảnh truyện theo thứ tự chiếu.
  static final List<StoryScene> storyScenes = [
    StoryScene(
      id: StorySceneId.prologue,
      minLevel: 1,
      minDay: 1,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyPrologue1),
        StoryLine(Speaker.mai, (l) => l.storyPrologue2),
        StoryLine(Speaker.mai, (l) => l.storyPrologue3),
        StoryLine(Speaker.mai, (l) => l.storyPrologue4),
      ],
    ),
    StoryScene(
      id: StorySceneId.hoa1,
      minLevel: 1,
      minDay: 2,
      featuredFriend: FriendId.hoa,
      featuredRecipe: RecipeId.cupcakeVanilla,
      lines: [
        StoryLine(Speaker.hoa, (l) => l.storyHoa1Line1),
        StoryLine(Speaker.mai, (l) => l.storyHoa1Line2),
        StoryLine(Speaker.hoa, (l) => l.storyHoa1Line3),
        StoryLine(Speaker.mai, (l) => l.storyHoa1Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.linh1,
      minLevel: 2,
      minDay: 1,
      featuredFriend: FriendId.linh,
      featuredRecipe: RecipeId.muffinBlueberry,
      lines: [
        StoryLine(Speaker.linh, (l) => l.storyLinh1Line1),
        StoryLine(Speaker.linh, (l) => l.storyLinh1Line2),
        StoryLine(Speaker.mai, (l) => l.storyLinh1Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.hoa2,
      minLevel: 3,
      minDay: 1,
      featuredFriend: FriendId.hoa,
      featuredRecipe: RecipeId.eggTart,
      lines: [
        StoryLine(Speaker.mai, (l) => l.storyHoa2Line1),
        StoryLine(Speaker.hoa, (l) => l.storyHoa2Line2),
        StoryLine(Speaker.mai, (l) => l.storyHoa2Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.kenji1,
      minLevel: 4,
      minDay: 1,
      featuredFriend: FriendId.kenji,
      featuredRecipe: RecipeId.strawberryCake,
      lines: [
        StoryLine(Speaker.kenji, (l) => l.storyKenji1Line1),
        StoryLine(Speaker.kenji, (l) => l.storyKenji1Line2),
        StoryLine(Speaker.mai, (l) => l.storyKenji1Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.linh2,
      minLevel: 5,
      minDay: 1,
      featuredFriend: FriendId.linh,
      featuredRecipe: RecipeId.macaron,
      lines: [
        StoryLine(Speaker.linh, (l) => l.storyLinh2Line1),
        StoryLine(Speaker.mai, (l) => l.storyLinh2Line2),
        StoryLine(Speaker.linh, (l) => l.storyLinh2Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.kenji2,
      minLevel: 6,
      minDay: 1,
      featuredFriend: FriendId.kenji,
      featuredRecipe: RecipeId.redVelvetCupcake,
      lines: [
        StoryLine(Speaker.kenji, (l) => l.storyKenji2Line1),
        StoryLine(Speaker.mai, (l) => l.storyKenji2Line2),
        StoryLine(Speaker.kenji, (l) => l.storyKenji2Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.hoa3,
      minLevel: 7,
      minDay: 1,
      featuredFriend: FriendId.hoa,
      featuredRecipe: RecipeId.eggTart,
      lines: [
        StoryLine(Speaker.hoa, (l) => l.storyHoa3Line1),
        StoryLine(Speaker.mai, (l) => l.storyHoa3Line2),
        StoryLine(Speaker.hoa, (l) => l.storyHoa3Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.linh3,
      minLevel: 8,
      minDay: 1,
      featuredFriend: FriendId.linh,
      featuredRecipe: RecipeId.matchaCake,
      lines: [
        StoryLine(Speaker.linh, (l) => l.storyLinh3Line1),
        StoryLine(Speaker.mai, (l) => l.storyLinh3Line2),
        StoryLine(Speaker.linh, (l) => l.storyLinh3Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.kenji3,
      minLevel: 10,
      minDay: 1,
      featuredFriend: FriendId.kenji,
      featuredRecipe: RecipeId.cheesecake,
      forcedToppings: const [ToppingRequest(ToppingId.blueberry, 3)],
      lines: [
        StoryLine(Speaker.kenji, (l) => l.storyKenji3Line1),
        StoryLine(Speaker.kenji, (l) => l.storyKenji3Line2),
        StoryLine(Speaker.mai, (l) => l.storyKenji3Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.finale,
      minLevel: 10,
      minDay: 1,
      lines: [
        StoryLine(Speaker.mai, (l) => l.storyFinaleLine1),
        StoryLine(Speaker.mai, (l) => l.storyFinaleLine2),
        StoryLine(Speaker.narrator, (l) => l.storyFinaleLine3),
      ],
    ),
  ];

  static StoryScene storyScene(StorySceneId id) => storyScenes.firstWhere((s) => s.id == id);

  /// Cảnh đầu tiên giới thiệu từng bạn quen (đã xem → bạn đó có thể ghé ngẫu nhiên).
  static const Map<FriendId, StorySceneId> friendIntroScene = {
    FriendId.hoa: StorySceneId.hoa1,
    FriendId.linh: StorySceneId.linh1,
    FriendId.kenji: StorySceneId.kenji1,
  };
}
