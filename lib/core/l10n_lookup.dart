import '../l10n/gen/app_localizations.dart';
import 'models/customer.dart';
import 'models/day_summary.dart';
import 'models/ids.dart';

/// Tra chuỗi giao diện theo enum.
extension AppL10nLookup on AppLocalizations {
  String recipeName(RecipeId id) => switch (id) {
        RecipeId.cupcakeVanilla => recipeCupcakeVanilla,
        RecipeId.cupcakeChocolate => recipeCupcakeChocolate,
        RecipeId.muffinBlueberry => recipeMuffinBlueberry,
        RecipeId.eggTart => recipeEggTart,
        RecipeId.strawberryCake => recipeStrawberryCake,
        RecipeId.macaron => recipeMacaron,
        RecipeId.redVelvetCupcake => recipeRedVelvetCupcake,
        RecipeId.matchaCake => recipeMatchaCake,
        RecipeId.cheesecake => recipeCheesecake,
        RecipeId.birthdayCake => recipeBirthdayCake,
      };

  String recipeDesc(RecipeId id) => switch (id) {
        RecipeId.cupcakeVanilla => recipeCupcakeVanillaDesc,
        RecipeId.cupcakeChocolate => recipeCupcakeChocolateDesc,
        RecipeId.muffinBlueberry => recipeMuffinBlueberryDesc,
        RecipeId.eggTart => recipeEggTartDesc,
        RecipeId.strawberryCake => recipeStrawberryCakeDesc,
        RecipeId.macaron => recipeMacaronDesc,
        RecipeId.redVelvetCupcake => recipeRedVelvetCupcakeDesc,
        RecipeId.matchaCake => recipeMatchaCakeDesc,
        RecipeId.cheesecake => recipeCheesecakeDesc,
        RecipeId.birthdayCake => recipeBirthdayCakeDesc,
      };

  String mouldName(MouldType m) => switch (m) {
        MouldType.cupcakeLiner => mouldCupcakeLiner,
        MouldType.muffinCup => mouldMuffinCup,
        MouldType.tartShell => mouldTartShell,
        MouldType.roundPan => mouldRoundPan,
        MouldType.macaronMat => mouldMacaronMat,
        MouldType.springformPan => mouldSpringformPan,
        MouldType.tallPan => mouldTallPan,
      };

  String batterName(BatterType b) => switch (b) {
        BatterType.vanilla => batterVanilla,
        BatterType.chocolate => batterChocolate,
        BatterType.redVelvet => batterRedVelvet,
        BatterType.matcha => batterMatcha,
        BatterType.butter => batterButter,
        BatterType.almond => batterAlmond,
        BatterType.cheese => batterCheese,
      };

  String frostingName(FrostingId f) => switch (f) {
        FrostingId.vanillaCream => frostingVanillaCream,
        FrostingId.chocolateGanache => frostingChocolateGanache,
        FrostingId.strawberryCream => frostingStrawberryCream,
        FrostingId.matchaCream => frostingMatchaCream,
        FrostingId.creamCheese => frostingCreamCheese,
        FrostingId.custard => frostingCustard,
      };

  String toppingName(ToppingId t) => switch (t) {
        ToppingId.sprinkles => toppingSprinkles,
        ToppingId.strawberry => toppingStrawberry,
        ToppingId.cherry => toppingCherry,
        ToppingId.chocolateChips => toppingChocolateChips,
        ToppingId.blueberry => toppingBlueberry,
        ToppingId.mintLeaf => toppingMintLeaf,
        ToppingId.sugarPearl => toppingSugarPearl,
        ToppingId.candle => toppingCandle,
      };

  String boxName(BoxType b) => switch (b) {
        BoxType.small => boxSmall,
        BoxType.cake => boxCake,
        BoxType.gift => boxGift,
      };

  String stationName(StationId s) => switch (s) {
        StationId.mould => stationMould,
        StationId.mix => stationMix,
        StationId.bake => stationBake,
        StationId.frost => stationFrost,
        StationId.topping => stationTopping,
        StationId.box => stationBox,
      };

  /// Gợi ý thao tác của trạm (thẻ hướng dẫn).
  String stationHint(StationId s) => switch (s) {
        StationId.mould => hintMould,
        StationId.mix => hintMix,
        StationId.bake => hintBake,
        StationId.frost => hintFrost,
        StationId.topping => hintTopping,
        StationId.box => hintBox,
      };

  String feedbackText(FeedbackKey k) => switch (k) {
        FeedbackKey.allGood => fbAllGood,
        FeedbackKey.mouldGood => fbMouldGood,
        FeedbackKey.mixGood => fbMixGood,
        FeedbackKey.bakeGood => fbBakeGood,
        FeedbackKey.frostGood => fbFrostGood,
        FeedbackKey.toppingGood => fbToppingGood,
        FeedbackKey.boxGood => fbBoxGood,
        FeedbackKey.mouldWrong => fbMouldWrong,
        FeedbackKey.mixUnder => fbMixUnder,
        FeedbackKey.mixOver => fbMixOver,
        FeedbackKey.bakeUnder => fbBakeUnder,
        FeedbackKey.bakeBurnt => fbBakeBurnt,
        FeedbackKey.frostPatchy => fbFrostPatchy,
        FeedbackKey.toppingMissing => fbToppingMissing,
        FeedbackKey.toppingWrong => fbToppingWrong,
        FeedbackKey.boxWrong => fbBoxWrong,
      };

  String orderLineText(OrderLineKind k, String item) => switch (k) {
        OrderLineKind.generic1 => orderLine1(item),
        OrderLineKind.generic2 => orderLine2(item),
        OrderLineKind.generic3 => orderLine3(item),
        OrderLineKind.generic4 => orderLine4(item),
        OrderLineKind.generic5 => orderLine5(item),
        OrderLineKind.generic6 => orderLine6(item),
        OrderLineKind.vip => orderLineVip(item),
        OrderLineKind.hoa => orderLineHoa(item),
        OrderLineKind.linh => orderLineLinh(item),
        OrderLineKind.kenji => orderLineKenji(item),
      };

  /// regular → customerRegular, vip → customerVip, friend → charHoa/charLinh/charKenji.
  String customerName(Customer c) => switch (c.kind) {
        CustomerKind.regular => customerRegular,
        CustomerKind.vip => customerVip,
        CustomerKind.friend => switch (c.friend) {
            FriendId.hoa => charHoa,
            FriendId.linh => charLinh,
            FriendId.kenji => charKenji,
            null => customerRegular,
          },
      };

  /// narrator → ''.
  String speakerName(Speaker s) => switch (s) {
        Speaker.narrator => '',
        Speaker.mai => charMai,
        Speaker.hoa => charHoa,
        Speaker.linh => charLinh,
        Speaker.kenji => charKenji,
      };

  String questText(QuestType t, int count) => switch (t) {
        QuestType.serveCustomers => questServeCustomers(count),
        QuestType.earnStars => questEarnStars(count),
        QuestType.perfectBakes => questPerfectBakes(count),
        QuestType.fiveStarTreats => questFiveStarTreats(count),
        QuestType.earnCoins => questEarnCoins(count),
        QuestType.earnTips => questEarnTips(count),
      };

  String toolName(ToolId t) => switch (t) {
        ToolId.whisk => upgradeWhisk,
        ToolId.pipingBag => upgradePipingBag,
        ToolId.tongs => upgradeTongs,
      };

  String toolDesc(ToolId t) => switch (t) {
        ToolId.whisk => upgradeWhiskDesc,
        ToolId.pipingBag => upgradePipingBagDesc,
        ToolId.tongs => upgradeTongsDesc,
      };

  /// null → decorDefault.
  String decorName(DecorId? id) => switch (id) {
        null => decorDefault,
        DecorId.wallpaperStripes => decorWallpaperStripes,
        DecorId.wallpaperFloral => decorWallpaperFloral,
        DecorId.floorCheckered => decorFloorCheckered,
        DecorId.floorHerringbone => decorFloorHerringbone,
        DecorId.counterFlowers => decorCounterFlowers,
        DecorId.counterCakeStand => decorCounterCakeStand,
        DecorId.windowCurtains => decorWindowCurtains,
        DecorId.windowSeaView => decorWindowSeaView,
        DecorId.plantFern => decorPlantFern,
        DecorId.plantLemonTree => decorPlantLemonTree,
      };

  String decorSlotName(DecorSlot s) => switch (s) {
        DecorSlot.wallpaper => decorSlotWallpaper,
        DecorSlot.floor => decorSlotFloor,
        DecorSlot.counter => decorSlotCounter,
        DecorSlot.window => decorSlotWindow,
        DecorSlot.plant => decorSlotPlant,
      };

  String unlockText(Unlock u) => switch (u.kind) {
        UnlockKind.recipe => unlockRecipe(u.recipe == null ? '' : recipeName(u.recipe!)),
        UnlockKind.topping => unlockTopping(u.topping == null ? '' : toppingName(u.topping!)),
        UnlockKind.vipGuests => unlockVipGuests,
        UnlockKind.upgrade => unlockUpgrades,
        UnlockKind.decor => unlockDecor,
        UnlockKind.moreCustomers => unlockMoreCustomers,
      };

  /// Tên gói IAP (giả lập).
  String iapName(IapProductId id) => switch (id) {
        IapProductId.starterPack => storeStarterPack,
        IapProductId.pantryS => storePantryS,
        IapProductId.pantryM => storePantryM,
        IapProductId.pantryL => storePantryL,
        IapProductId.decorSetSeaside => storeDecorSet,
        IapProductId.removeAds => storeRemoveAds,
      };
}
