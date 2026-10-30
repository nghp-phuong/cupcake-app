import 'dart:math' as math;

import 'art/art_sprites.dart' show ArtScene;
import 'models/decor.dart';
import 'models/ids.dart';
import 'models/order.dart';
import 'models/quest.dart';
import 'models/recipe.dart';
import 'models/story.dart';

/// Dữ liệu tĩnh: món, topping, trang trí, cảnh truyện, nhiệm vụ, quà đăng nhập, gói IAP.
abstract final class Catalog {
  // ---------------------------------------------------------------- Món

  /// 18 món, đúng thứ tự `RecipeId`: 10 món alpha (`unlockLevel` ≈ cấp tiệm/màn chương 1–2) + 8 món GĐ8 (màn 21–47).
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
    // GĐ8 (chương 3–5): `unlockLevel` = màn mở món. Giá/chi phí đề xuất, cân lại ở 8C theo mô phỏng.
    // Bánh cán bơ nướng nhạy: mục tiêu lệch khỏi 0.65 (croissant, pain au chocolat, éclair).
    Recipe(
      id: RecipeId.croissant,
      unlockLevel: 21,
      price: 64,
      cost: 16,
      mould: MouldType.pastryTray,
      batter: BatterType.laminated,
      frostings: [FrostingId.butterGlaze],
      toppings: [ToppingId.almondFlakes, ToppingId.powderedSugar],
      mixTurns: 5,
      bakeTarget: 0.60,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.painAuChocolat,
      unlockLevel: 24,
      price: 68,
      cost: 17,
      mould: MouldType.pastryTray,
      batter: BatterType.laminated,
      frostings: [FrostingId.chocolateGanache],
      toppings: [ToppingId.chocolateChips, ToppingId.powderedSugar],
      mixTurns: 5,
      bakeTarget: 0.70,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.madeleine,
      unlockLevel: 27,
      price: 58,
      cost: 15,
      mould: MouldType.shellMould,
      batter: BatterType.butter,
      frostings: [FrostingId.butterGlaze],
      toppings: [ToppingId.powderedSugar, ToppingId.sugarPearl],
      mixTurns: 4,
      bakeTarget: 0.66,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.eclair,
      unlockLevel: 31,
      price: 74,
      cost: 19,
      mould: MouldType.eclairTray,
      batter: BatterType.choux,
      frostings: [FrostingId.chocolateGanache, FrostingId.custard],
      toppings: [ToppingId.almondFlakes, ToppingId.sprinkles],
      mixTurns: 5,
      bakeTarget: 0.58,
      box: BoxType.small,
    ),
    Recipe(
      id: RecipeId.fruitTart,
      unlockLevel: 34,
      price: 82,
      cost: 21,
      mould: MouldType.tartShell,
      batter: BatterType.butter,
      frostings: [FrostingId.custard],
      toppings: [ToppingId.strawberry, ToppingId.blueberry, ToppingId.kiwi, ToppingId.mintLeaf],
      mixTurns: 4,
      bakeTarget: 0.64,
      box: BoxType.cake,
    ),
    Recipe(
      id: RecipeId.applePie,
      unlockLevel: 38,
      price: 86,
      cost: 22,
      mould: MouldType.piePan,
      batter: BatterType.butter,
      frostings: [FrostingId.appleFilling],
      toppings: [ToppingId.powderedSugar, ToppingId.mintLeaf],
      mixTurns: 4,
      bakeTarget: 0.68,
      box: BoxType.cake,
    ),
    // Món mùa (Trung thu, Bûche de Noël): mở theo màn như món thường, không khoá theo lịch thật.
    Recipe(
      id: RecipeId.mooncake,
      unlockLevel: 43,
      price: 92,
      cost: 23,
      mould: MouldType.mooncakeMould,
      batter: BatterType.mooncake,
      frostings: [FrostingId.lotusPaste],
      toppings: [ToppingId.sesame, ToppingId.sugarPearl],
      mixTurns: 5,
      bakeTarget: 0.62,
      box: BoxType.gift,
    ),
    Recipe(
      id: RecipeId.bucheDeNoel,
      unlockLevel: 47,
      price: 98,
      cost: 25,
      mould: MouldType.logPan,
      batter: BatterType.chocolate,
      frostings: [FrostingId.chocolateGanache],
      toppings: [ToppingId.meringueMushroom, ToppingId.powderedSugar, ToppingId.cherry, ToppingId.mintLeaf],
      mixTurns: 5,
      bakeTarget: 0.72,
      box: BoxType.cake,
    ),
  ];

  static Recipe recipe(RecipeId id) => recipes.firstWhere((r) => r.id == id);

  /// Màn mở sớm nhất của mọi món dùng chung khuôn.
  static final Map<MouldType, int> _mouldIntroLevel = {
    for (final m in MouldType.values)
      m: recipes.where((r) => r.mould == m).map((r) => r.unlockLevel).fold(1 << 30, math.min),
  };

  /// Món/nguyên liệu chương 1–2 (mở tới màn này) luôn được làm mồi như trước GĐ8.
  static const decoyBaseLevel = 20;

  /// Khuôn được làm mồi ở trạm khuôn khi làm món mở ở màn [level]: mọi khuôn chương 1–2, khuôn mới (chương 3–5)
  /// chỉ khi đã có món dùng nó mở tới [level] (người chơi đã gặp).
  static bool isDecoyMould(MouldType m, int level) => _mouldIntroLevel[m]! <= math.max(level, decoyBaseLevel);

  /// Như [isDecoyMould] cho topping (theo [toppingUnlockLevel]).
  static bool isDecoyTopping(ToppingId t, int level) => (toppingUnlockLevel[t] ?? 1) <= math.max(level, decoyBaseLevel);

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
    // GĐ8: mở cùng màn của món đầu tiên dùng topping đó.
    ToppingId.almondFlakes: 21,
    ToppingId.powderedSugar: 21,
    ToppingId.kiwi: 34,
    ToppingId.sesame: 43,
    ToppingId.meringueMushroom: 47,
  };

  // ---------------------------------------------------------------- Trang trí

  /// `unlockLevel` = phải qua level này mới mua được (0 = có sẵn từ đầu; GĐ3 trải L0–L16); giá xu cân theo thu nhập level
  /// (`test/core/progression_sim_test.dart`).
  static const List<DecorItem> decor = [
    DecorItem(id: DecorId.wallpaperStripes, slot: DecorSlot.wallpaper, coinPrice: 900, unlockLevel: 4, tipBonusPct: 3),
    DecorItem(id: DecorId.wallpaperFloral, slot: DecorSlot.wallpaper, coinPrice: 5000, unlockLevel: 12, tipBonusPct: 6),
    DecorItem(id: DecorId.floorCheckered, slot: DecorSlot.floor, coinPrice: 1400, unlockLevel: 6, tipBonusPct: 3),
    DecorItem(id: DecorId.floorHerringbone, slot: DecorSlot.floor, coinPrice: 6500, unlockLevel: 16, tipBonusPct: 6),
    DecorItem(id: DecorId.counterFlowers, slot: DecorSlot.counter, coinPrice: 400, unlockLevel: 0, tipBonusPct: 2),
    DecorItem(id: DecorId.counterCakeStand, slot: DecorSlot.counter, coinPrice: 3000, unlockLevel: 9, tipBonusPct: 5),
    DecorItem(id: DecorId.windowCurtains, slot: DecorSlot.window, coinPrice: 700, unlockLevel: 3, tipBonusPct: 2),
    DecorItem(id: DecorId.windowSeaView, slot: DecorSlot.window, gemPrice: 30, unlockLevel: 8, tipBonusPct: 6),
    DecorItem(id: DecorId.plantFern, slot: DecorSlot.plant, coinPrice: 500, unlockLevel: 2, tipBonusPct: 2),
    DecorItem(id: DecorId.plantLemonTree, slot: DecorSlot.plant, gemPrice: 25, unlockLevel: 14, tipBonusPct: 5),
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

  /// Xu trao cho từng gói IAP (ui dùng cho `storeStarterPackDesc`, `storePantryDesc`). Nội dung đầy đủ (kim cương, vật
  /// phẩm) của gói V2: `IapCatalog.v2` / `monetization.json`; `GameState.grantIap` trao theo đó.
  static const Map<IapProductId, int> iapCoins = {
    IapProductId.starterPack: 8000,
    IapProductId.pantryS: 500,
    IapProductId.pantryM: 1800,
    IapProductId.pantryL: 5000,
  };

  /// Gem trao cho từng gói IAP.
  static const Map<IapProductId, int> iapGems = {
    IapProductId.starterPack: 120,
    IapProductId.gemsS: 80,
    IapProductId.gemsM: 450,
    IapProductId.gemsL: 1000,
  };

  /// Đồ trang trí trong bộ "Seaside" (sở hữu ngay, bỏ qua cấp mở).
  static const List<DecorId> decorSetSeaside = [DecorId.windowSeaView, DecorId.plantLemonTree, DecorId.wallpaperFloral];

  // ---------------------------------------------------------------- Truyện

  /// Cảnh truyện theo thứ tự chiếu.
  static final List<StoryScene> storyScenes = [
    StoryScene(
      id: StorySceneId.prologue,
      minLevel: 1,
      minDay: 1,
      backdrop: ArtScene.storyTown,
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
    // GĐ8: `finale` = kết thúc sau khi thắng L50 lần đầu (lời mới); lời kết cũ (trước là sau L10) chuyển sang `ch2End`
    // (sau L20); sau L10 là `ch1End` (cuối danh sách, theo thứ tự enum).
    StoryScene(
      id: StorySceneId.finale,
      minLevel: 50,
      minDay: 1,
      backdrop: ArtScene.storyTown,
      lines: [
        StoryLine(Speaker.mai, (l) => l.storyFinale2Line1),
        StoryLine(Speaker.mai, (l) => l.storyFinale2Line2),
        StoryLine(Speaker.narrator, (l) => l.storyFinale2Line3),
      ],
    ),
    StoryScene(
      id: StorySceneId.ch2End,
      minLevel: 20,
      minDay: 1,
      backdrop: ArtScene.storyTown,
      lines: [
        // Lời kết chương 1–2 cũ (trước GĐ8 là `finale`), dòng cuối mới.
        StoryLine(Speaker.mai, (l) => l.storyFinaleLine1),
        StoryLine(Speaker.mai, (l) => l.storyFinaleLine2),
        StoryLine(Speaker.narrator, (l) => l.storyCh2End3),
      ],
    ),
    StoryScene(
      id: StorySceneId.ch3Open,
      minLevel: 21,
      minDay: 1,
      backdrop: ArtScene.storyGarden,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyCh3Open1),
        StoryLine(Speaker.mai, (l) => l.storyCh3Open2),
        StoryLine(Speaker.mai, (l) => l.storyCh3Open3),
        StoryLine(Speaker.narrator, (l) => l.storyCh3Open4),
      ],
    ),
    StoryScene(
      id: StorySceneId.mochi1,
      minLevel: 23,
      minDay: 1,
      backdrop: ArtScene.rainyDay,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyMochi1Line1),
        StoryLine(Speaker.mai, (l) => l.storyMochi1Line2),
        StoryLine(Speaker.narrator, (l) => l.storyMochi1Line3),
        StoryLine(Speaker.mai, (l) => l.storyMochi1Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.kenji4,
      minLevel: 27,
      minDay: 1,
      featuredFriend: FriendId.kenji,
      featuredRecipe: RecipeId.madeleine,
      backdrop: ArtScene.storyTown,
      lines: [
        StoryLine(Speaker.kenji, (l) => l.storyKenji4Line1),
        StoryLine(Speaker.mai, (l) => l.storyKenji4Line2),
        StoryLine(Speaker.mai, (l) => l.storyKenji4Line3),
        StoryLine(Speaker.kenji, (l) => l.storyKenji4Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.ch4Open,
      minLevel: 31,
      minDay: 1,
      backdrop: ArtScene.storyAttic,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyCh4Open1),
        StoryLine(Speaker.mai, (l) => l.storyCh4Open2),
        StoryLine(Speaker.mai, (l) => l.storyCh4Open3),
        StoryLine(Speaker.narrator, (l) => l.storyCh4Open4),
      ],
    ),
    StoryScene(
      id: StorySceneId.rosa1,
      minLevel: 33,
      minDay: 1,
      featuredRecipe: RecipeId.eclair,
      backdrop: ArtScene.storyTown,
      lines: [
        StoryLine(Speaker.rosa, (l) => l.storyRosa1Line1),
        StoryLine(Speaker.rosa, (l) => l.storyRosa1Line2),
        StoryLine(Speaker.mai, (l) => l.storyRosa1Line3),
        StoryLine(Speaker.rosa, (l) => l.storyRosa1Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.linh4,
      minLevel: 37,
      minDay: 1,
      featuredFriend: FriendId.linh,
      featuredRecipe: RecipeId.fruitTart,
      backdrop: ArtScene.storyTown,
      lines: [
        StoryLine(Speaker.linh, (l) => l.storyLinh4Line1),
        StoryLine(Speaker.mai, (l) => l.storyLinh4Line2),
        StoryLine(Speaker.linh, (l) => l.storyLinh4Line3),
        StoryLine(Speaker.mai, (l) => l.storyLinh4Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.ch5Open,
      minLevel: 41,
      minDay: 1,
      backdrop: ArtScene.storyFestival,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyCh5Open1),
        StoryLine(Speaker.mai, (l) => l.storyCh5Open2),
        StoryLine(Speaker.mai, (l) => l.storyCh5Open3),
        StoryLine(Speaker.narrator, (l) => l.storyCh5Open4),
      ],
    ),
    StoryScene(
      id: StorySceneId.hoa4,
      minLevel: 46,
      minDay: 1,
      featuredFriend: FriendId.hoa,
      featuredRecipe: RecipeId.mooncake,
      backdrop: ArtScene.storyFestival,
      lines: [
        StoryLine(Speaker.hoa, (l) => l.storyHoa4Line1),
        StoryLine(Speaker.hoa, (l) => l.storyHoa4Line2),
        StoryLine(Speaker.mai, (l) => l.storyHoa4Line3),
        StoryLine(Speaker.hoa, (l) => l.storyHoa4Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.rosa2,
      minLevel: 50,
      minDay: 1,
      featuredRecipe: RecipeId.birthdayCake,
      backdrop: ArtScene.storyFestival,
      lines: [
        StoryLine(Speaker.rosa, (l) => l.storyRosa2Line1),
        StoryLine(Speaker.mai, (l) => l.storyRosa2Line2),
        StoryLine(Speaker.rosa, (l) => l.storyRosa2Line3),
        StoryLine(Speaker.mai, (l) => l.storyRosa2Line4),
      ],
    ),
    StoryScene(
      id: StorySceneId.ch1End,
      minLevel: 10,
      minDay: 1,
      lines: [
        StoryLine(Speaker.narrator, (l) => l.storyCh1End1),
        StoryLine(Speaker.mai, (l) => l.storyCh1End2),
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
