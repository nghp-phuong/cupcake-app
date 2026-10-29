// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sugarleaf Bakery';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDone => 'Done';

  @override
  String get commonBuy => 'Buy';

  @override
  String get commonClaim => 'Claim';

  @override
  String get commonClaimed => 'Claimed';

  @override
  String get commonLocked => 'Locked';

  @override
  String get commonMax => 'Max';

  @override
  String commonUnlockAtLevel(int level) {
    return 'Unlocks at level $level';
  }

  @override
  String commonLevelShort(int level) {
    return 'Lv. $level';
  }

  @override
  String commonCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
    );
    return '$_temp0';
  }

  @override
  String commonGems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gems',
      one: '1 gem',
    );
    return '$_temp0';
  }

  @override
  String get commonNotEnoughCoins => 'Not enough coins';

  @override
  String get commonNotEnoughGems => 'Not enough gems';

  @override
  String get commonWatchAd => 'Watch ad';

  @override
  String get rotateDevicePrompt => 'Please turn your device sideways';

  @override
  String get levelUpTitle => 'Level up!';

  @override
  String get menuTagline => 'A cozy little bakery by the sea';

  @override
  String get menuPlay => 'Open the bakery';

  @override
  String menuDayLabel(int day) {
    return 'Day $day';
  }

  @override
  String get menuRecipeBook => 'Recipe book';

  @override
  String get menuUpgrades => 'Upgrades';

  @override
  String get menuDecor => 'Decor';

  @override
  String get menuStore => 'Store';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuQuests => 'Daily quests';

  @override
  String get menuLoginGift => 'Daily gift';

  @override
  String menuShopLevel(int level) {
    return 'Bakery level $level';
  }

  @override
  String menuXpProgress(int current, int target) {
    return '$current/$target XP';
  }

  @override
  String get menuXpMax => 'Max level';

  @override
  String dayStartTitle(int day) {
    return 'Day $day';
  }

  @override
  String dayCustomersToday(int count) {
    return '$count customers are coming today';
  }

  @override
  String dayCustomerProgress(int current, int total) {
    return 'Customer $current/$total';
  }

  @override
  String get dayOrderTitle => 'Order';

  @override
  String get dayOrderFrosting => 'Frosting';

  @override
  String get dayOrderToppings => 'Toppings';

  @override
  String get dayOrderBox => 'Box';

  @override
  String get dayStartBaking => 'Start baking';

  @override
  String get dayNextCustomer => 'Next customer';

  @override
  String get dayRemakeWithAd => 'Remake (watch ad)';

  @override
  String get dayRemakeLine => 'No rush, I\'ll wait for a fresh one!';

  @override
  String get dayExitConfirmTitle => 'Leave for now?';

  @override
  String get dayExitConfirmBody =>
      'Coins earned so far are kept, but today won\'t count as completed.';

  @override
  String get dayRainy => 'Rainy day';

  @override
  String get customerRegular => 'Customer';

  @override
  String get customerVip => 'VIP guest';

  @override
  String get customerVipBadge => 'VIP';

  @override
  String get customerFriendBadge => 'Regular';

  @override
  String resultPaid(int amount) {
    return 'Paid $amount';
  }

  @override
  String resultTip(int amount) {
    return 'Tip $amount';
  }

  @override
  String resultXp(int amount) {
    return '+$amount XP';
  }

  @override
  String feedbackNeedsWork(String station) {
    return 'Needs work: $station';
  }

  @override
  String get mochiName => 'Mochi';

  @override
  String get mochiArriveFirst =>
      'A little soaked cat is sheltering from the rain at your door…';

  @override
  String get mochiArriveAgain => 'Mochi is back, sheltering from the rain!';

  @override
  String get mochiLook => 'Mochi looks up at you, tail swishing softly.';

  @override
  String get mochiPet => 'Pet';

  @override
  String get mochiRest => 'Let Mochi rest';

  @override
  String get mochiPetThanks => 'Mochi purrs happily!';

  @override
  String get mochiNap => 'Mochi curls up for a nap by the stove.';

  @override
  String mochiGift(int coins, int gems) {
    String _temp0 = intl.Intl.pluralLogic(
      gems,
      locale: localeName,
      other: 'Mochi left you $coins coins and $gems gems!',
      one: 'Mochi left you $coins coins and 1 gem!',
      zero: 'Mochi left you $coins coins!',
    );
    return '$_temp0';
  }

  @override
  String orderLine1(String item) {
    return 'Hi! One $item, please.';
  }

  @override
  String orderLine2(String item) {
    return 'I\'ve been craving $item all day!';
  }

  @override
  String orderLine3(String item) {
    return 'Could you make me one $item?';
  }

  @override
  String orderLine4(String item) {
    return 'One $item to go, thank you!';
  }

  @override
  String orderLine5(String item) {
    return 'Something sweet today... $item!';
  }

  @override
  String orderLine6(String item) {
    return 'My friend says your $item is lovely.';
  }

  @override
  String orderLineVip(String item) {
    return 'One $item in your finest gift box, please.';
  }

  @override
  String orderLineHoa(String item) {
    return 'The usual for this old man: one $item.';
  }

  @override
  String orderLineLinh(String item) {
    return 'Eee, $item! Make it extra cute, please!';
  }

  @override
  String orderLineKenji(String item) {
    return 'Today feels like a day for $item.';
  }

  @override
  String get fbAllGood => 'Perfect! Just like I imagined!';

  @override
  String get fbMouldGood => 'Such a cute shape!';

  @override
  String get fbMixGood => 'So soft and fluffy!';

  @override
  String get fbBakeGood => 'Baked to golden perfection!';

  @override
  String get fbFrostGood => 'The frosting is so smooth!';

  @override
  String get fbToppingGood => 'The toppings are just right!';

  @override
  String get fbBoxGood => 'And it\'s packed so nicely!';

  @override
  String get fbMouldWrong => 'Hmm, the shape isn\'t what I expected.';

  @override
  String get fbMixUnder => 'The texture is a bit lumpy.';

  @override
  String get fbMixOver => 'It\'s a little dense and tough.';

  @override
  String get fbBakeUnder => 'It\'s still a bit gooey inside!';

  @override
  String get fbBakeBurnt => 'Oops, it\'s a little burnt!';

  @override
  String get fbFrostPatchy => 'The frosting looks patchy.';

  @override
  String get fbToppingMissing => 'I think some toppings are missing.';

  @override
  String get fbToppingWrong => 'Those aren\'t the toppings I asked for.';

  @override
  String get fbBoxWrong => 'Hmm, that\'s not the right box.';

  @override
  String get stationMould => 'Mould';

  @override
  String get stationMix => 'Mixing';

  @override
  String get stationBake => 'Baking';

  @override
  String get stationFrost => 'Frosting';

  @override
  String get stationTopping => 'Toppings';

  @override
  String get stationBox => 'Boxing';

  @override
  String get hintMould => 'Drag the right mould onto the tray';

  @override
  String get hintMix => 'Swirl around the bowl and stop in the green zone';

  @override
  String get hintBake => 'Hold to bake, release in the golden zone';

  @override
  String get hintFrost => 'Trace the dotted line to frost the cake';

  @override
  String get hintTopping => 'Drag the toppings onto the cake';

  @override
  String get hintBox => 'Drag the treat into the right box';

  @override
  String gameStepProgress(int current, int total) {
    return 'Step $current/$total';
  }

  @override
  String get gameHold => 'Hold';

  @override
  String get gameTapToRemove => 'Tap a topping to remove it';

  @override
  String get gameWrongMould => 'Not this one!';

  @override
  String get gameTutorialGotIt => 'Got it!';

  @override
  String get mouldCupcakeLiner => 'Cupcake liner';

  @override
  String get mouldMuffinCup => 'Muffin cup';

  @override
  String get mouldTartShell => 'Tart shell';

  @override
  String get mouldRoundPan => 'Round pan';

  @override
  String get mouldMacaronMat => 'Macaron mat';

  @override
  String get mouldSpringformPan => 'Springform pan';

  @override
  String get mouldTallPan => 'Tall layer pan';

  @override
  String get batterVanilla => 'Vanilla batter';

  @override
  String get batterChocolate => 'Chocolate batter';

  @override
  String get batterRedVelvet => 'Red velvet batter';

  @override
  String get batterMatcha => 'Matcha batter';

  @override
  String get batterButter => 'Butter pastry';

  @override
  String get batterAlmond => 'Almond meringue';

  @override
  String get batterCheese => 'Cheesecake batter';

  @override
  String get frostingVanillaCream => 'Vanilla cream';

  @override
  String get frostingChocolateGanache => 'Chocolate ganache';

  @override
  String get frostingStrawberryCream => 'Strawberry cream';

  @override
  String get frostingMatchaCream => 'Matcha cream';

  @override
  String get frostingCreamCheese => 'Cream cheese';

  @override
  String get frostingCustard => 'Egg custard';

  @override
  String get toppingSprinkles => 'Sprinkles';

  @override
  String get toppingStrawberry => 'Strawberry';

  @override
  String get toppingCherry => 'Cherry';

  @override
  String get toppingChocolateChips => 'Chocolate chips';

  @override
  String get toppingBlueberry => 'Blueberry';

  @override
  String get toppingMintLeaf => 'Mint leaf';

  @override
  String get toppingSugarPearl => 'Sugar pearls';

  @override
  String get toppingCandle => 'Candle';

  @override
  String get boxSmall => 'Small box';

  @override
  String get boxCake => 'Cake box';

  @override
  String get boxGift => 'Gift box';

  @override
  String get recipeCupcakeVanilla => 'Vanilla cupcake';

  @override
  String get recipeCupcakeVanillaDesc =>
      'Fluffy vanilla sponge with a cloud of cream.';

  @override
  String get recipeCupcakeChocolate => 'Chocolate cupcake';

  @override
  String get recipeCupcakeChocolateDesc =>
      'Rich cocoa crumb and glossy ganache.';

  @override
  String get recipeMuffinBlueberry => 'Blueberry muffin';

  @override
  String get recipeMuffinBlueberryDesc =>
      'A golden muffin bursting with berries.';

  @override
  String get recipeEggTart => 'Egg tart';

  @override
  String get recipeEggTartDesc =>
      'Flaky shell, silky custard. Grandma\'s favorite.';

  @override
  String get recipeStrawberryCake => 'Strawberry cake';

  @override
  String get recipeStrawberryCakeDesc =>
      'Soft layers with fresh strawberry cream.';

  @override
  String get recipeMacaron => 'Macaron';

  @override
  String get recipeMacaronDesc => 'Crisp almond shells with a sweet filling.';

  @override
  String get recipeRedVelvetCupcake => 'Red velvet cupcake';

  @override
  String get recipeRedVelvetCupcakeDesc =>
      'Velvety red crumb with tangy cream cheese.';

  @override
  String get recipeMatchaCake => 'Matcha cake';

  @override
  String get recipeMatchaCakeDesc => 'A gentle green tea cake, not too sweet.';

  @override
  String get recipeCheesecake => 'Cheesecake';

  @override
  String get recipeCheesecakeDesc => 'Creamy, rich, and baked low and slow.';

  @override
  String get recipeBirthdayCake => 'Birthday layer cake';

  @override
  String get recipeBirthdayCakeDesc => 'Tall, festive, and made for wishes.';

  @override
  String get charMai => 'Mai';

  @override
  String get charHoa => 'Mr. Hoa';

  @override
  String get charLinh => 'Linh';

  @override
  String get charKenji => 'Kenji';

  @override
  String get storyChapter1Title => 'Chapter 1: The Seaside Bakery';

  @override
  String get storyTapToContinue => 'Tap to continue';

  @override
  String get storySkip => 'Skip';

  @override
  String get storyPrologue1 =>
      'A sleepy seaside town. A little bakery with a faded sign: Sugarleaf.';

  @override
  String get storyPrologue2 =>
      'Grandma, I\'m home... I\'ll take care of your bakery now.';

  @override
  String get storyPrologue3 =>
      'Her recipe book! But so many pages are missing...';

  @override
  String get storyPrologue4 => 'Let\'s start with something simple. Cupcakes!';

  @override
  String get storyHoa1Line1 =>
      'The lights are on at Sugarleaf again. You must be little Mai.';

  @override
  String get storyHoa1Line2 => 'Yes! Did you know my grandma?';

  @override
  String get storyHoa1Line3 =>
      'Every Sunday for forty years. Her egg tarts... I still miss them.';

  @override
  String get storyHoa1Line4 =>
      'Then I\'ll learn to make them for you. I promise!';

  @override
  String get storyLinh1Line1 =>
      'Hi! I\'m Linh. I study at the art school up the hill.';

  @override
  String get storyLinh1Line2 =>
      'I draw every pastry I eat. Your shop is SO cute!';

  @override
  String get storyLinh1Line3 => 'Then I\'d better make them pretty for you!';

  @override
  String get storyHoa2Line1 => 'Mr. Hoa! I found the egg tart page today.';

  @override
  String get storyHoa2Line2 =>
      'Then today is a good day. Let\'s see if your hands remember her.';

  @override
  String get storyHoa2Line3 => 'I\'ll do my best!';

  @override
  String get storyKenji1Line1 =>
      'Hello. I\'m Kenji. I travel and photograph small towns.';

  @override
  String get storyKenji1Line2 =>
      'I\'m not sure what I want. Something that feels like a sunny morning?';

  @override
  String get storyKenji1Line3 => 'A sunny morning... Strawberry cake, I think!';

  @override
  String get storyLinh2Line1 =>
      'Mai, can you make macarons? They\'re my favorite thing to draw!';

  @override
  String get storyLinh2Line2 => 'They\'re tricky... but let\'s try together.';

  @override
  String get storyLinh2Line3 => 'Yay! I\'ll sketch while you bake!';

  @override
  String get storyKenji2Line1 =>
      'Tomorrow I\'ll climb the lighthouse at dawn. I need some courage.';

  @override
  String get storyKenji2Line2 =>
      'Courage tastes bold and a little sweet. Red velvet!';

  @override
  String get storyKenji2Line3 => 'You read moods like recipes.';

  @override
  String get storyHoa3Line1 =>
      'I brought something. She gave me this page years ago, for safekeeping.';

  @override
  String get storyHoa3Line2 => 'Grandma\'s handwriting... Thank you, Mr. Hoa.';

  @override
  String get storyHoa3Line3 => 'It belongs in this kitchen. Just like you.';

  @override
  String get storyLinh3Line1 =>
      'Look! My drawing of your shop won a prize at school!';

  @override
  String get storyLinh3Line2 =>
      'It\'s beautiful, Linh! Can I hang it by the window?';

  @override
  String get storyLinh3Line3 => 'Only if we celebrate with a matcha cake!';

  @override
  String get storyKenji3Line1 =>
      'My photos of this town will be shown in a gallery in Tokyo.';

  @override
  String get storyKenji3Line2 =>
      'I want to remember it with something calm and rich.';

  @override
  String get storyKenji3Line3 =>
      'Then cheesecake, with blueberries like the sea.';

  @override
  String get storyFinaleLine1 =>
      'Mr. Hoa, Linh, Kenji... this bakery feels alive again.';

  @override
  String get storyFinaleLine2 =>
      'Grandma\'s book still has empty pages. I\'ll fill them, one by one.';

  @override
  String get storyFinaleLine3 =>
      'Chapter 1 complete. More stories are coming soon!';

  @override
  String summaryTitle(int day) {
    return 'Day $day complete!';
  }

  @override
  String get summaryCustomers => 'Customers served';

  @override
  String get summaryAvgStars => 'Average rating';

  @override
  String get summaryRevenue => 'Sales';

  @override
  String get summaryTips => 'Tips';

  @override
  String get summaryCosts => 'Ingredients';

  @override
  String get summaryNet => 'Total earned';

  @override
  String get summaryXp => 'XP gained';

  @override
  String summaryDayBonusXp(int xp) {
    return 'Day bonus +$xp XP';
  }

  @override
  String get summaryRainyDay => 'A rainy day — Mochi dropped by';

  @override
  String get summaryDouble => 'Double coins (watch ad)';

  @override
  String get summaryDoubled => 'Coins doubled!';

  @override
  String summaryLevelUp(int level) {
    return 'Level up! Bakery level $level';
  }

  @override
  String get summaryNewUnlocks => 'New unlocks';

  @override
  String unlockRecipe(String name) {
    return 'New recipe: $name';
  }

  @override
  String unlockTopping(String name) {
    return 'New topping: $name';
  }

  @override
  String get unlockVipGuests => 'VIP guests start visiting!';

  @override
  String get unlockUpgrades => 'New upgrades available';

  @override
  String get unlockDecor => 'New decorations available';

  @override
  String get unlockMoreCustomers => 'More customers each day';

  @override
  String get upgradesTitle => 'Upgrades';

  @override
  String get upgradeOven => 'Oven';

  @override
  String get upgradeOvenDesc => 'A wider golden zone when baking';

  @override
  String upgradeOvenPerfectZone(int percent) {
    return 'Perfect zone ±$percent%';
  }

  @override
  String get upgradeWhisk => 'Whisk';

  @override
  String get upgradeWhiskDesc => 'A bigger green zone when mixing';

  @override
  String get upgradePipingBag => 'Piping bag';

  @override
  String get upgradePipingBagDesc => 'A thicker frosting stroke';

  @override
  String get upgradeTongs => 'Pastry tongs';

  @override
  String get upgradeTongsDesc => 'Toppings land on the cake more easily';

  @override
  String upgradeLevelOf(int current, int max) {
    return 'Level $current/$max';
  }

  @override
  String get upgradeBuy => 'Upgrade';

  @override
  String get upgradeMaxed => 'Fully upgraded';

  @override
  String get upgradeDone => 'Upgraded!';

  @override
  String get decorTitle => 'Decorate the bakery';

  @override
  String get decorSlotWallpaper => 'Wallpaper';

  @override
  String get decorSlotFloor => 'Floor';

  @override
  String get decorSlotCounter => 'Counter';

  @override
  String get decorSlotWindow => 'Window';

  @override
  String get decorSlotPlant => 'Plants';

  @override
  String get decorDefault => 'Basic';

  @override
  String get decorWallpaperStripes => 'Cream stripes';

  @override
  String get decorWallpaperFloral => 'Floral wallpaper';

  @override
  String get decorFloorCheckered => 'Checkered tiles';

  @override
  String get decorFloorHerringbone => 'Herringbone wood';

  @override
  String get decorCounterFlowers => 'Flower vase';

  @override
  String get decorCounterCakeStand => 'Tiered cake stand';

  @override
  String get decorWindowCurtains => 'Lace curtains';

  @override
  String get decorWindowSeaView => 'Sea view window';

  @override
  String get decorPlantFern => 'Fern';

  @override
  String get decorPlantLemonTree => 'Lemon tree';

  @override
  String decorTipBonus(int percent) {
    return '+$percent% tips';
  }

  @override
  String decorTotalBonus(int percent) {
    return 'Total tip bonus: +$percent%';
  }

  @override
  String get decorEquip => 'Place';

  @override
  String get decorEquipped => 'Placed';

  @override
  String get recipesTitle => 'Recipe book';

  @override
  String recipesPrice(int amount) {
    return 'Price: $amount';
  }

  @override
  String get recipesIngredients => 'Ingredients';

  @override
  String get recipesMastery => 'Mastery';

  @override
  String get recipesMasteryHint =>
      'Serve it once, get 4 stars, then 5 stars to master it';

  @override
  String recipesMasteryReward(int gems) {
    return 'Mastered! +$gems gems';
  }

  @override
  String recipesMissingPage(int level) {
    return 'Missing page. Unlocks at level $level';
  }

  @override
  String get questsTitle => 'Daily quests';

  @override
  String questServeCustomers(int count) {
    return 'Serve $count customers';
  }

  @override
  String questEarnStars(int count) {
    return 'Earn $count stars';
  }

  @override
  String questPerfectBakes(int count) {
    return 'Get $count perfect bakes';
  }

  @override
  String questFiveStarTreats(int count) {
    return 'Serve $count five-star treats';
  }

  @override
  String questEarnCoins(int count) {
    return 'Earn $count coins';
  }

  @override
  String questEarnTips(int count) {
    return 'Collect $count coins in tips';
  }

  @override
  String questProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get questsResetHint => 'New quests every day';

  @override
  String get questsAllDone => 'All done for today!';

  @override
  String get loginTitle => 'Daily gift';

  @override
  String loginDay(int day) {
    return 'Day $day';
  }

  @override
  String get loginComeBack => 'Come back tomorrow for more!';

  @override
  String get storeTitle => 'Store';

  @override
  String get storeSimulatedNotice =>
      'Test store: purchases are simulated and no money is charged.';

  @override
  String get storeStarterPack => 'Starter pack';

  @override
  String storeStarterPackDesc(int coins, int gems) {
    return '$coins coins + $gems gems';
  }

  @override
  String get storePantryS => 'Pantry pack S';

  @override
  String get storePantryM => 'Pantry pack M';

  @override
  String get storePantryL => 'Pantry pack L';

  @override
  String storePantryDesc(int coins) {
    return '$coins coins for ingredients';
  }

  @override
  String get storeDecorSet => 'Seaside decor set';

  @override
  String get storeDecorSetDesc => '3 special decorations';

  @override
  String get storeRemoveAds => 'Remove ads';

  @override
  String get storeRemoveAdsDesc =>
      'No more ads between days. Reward ads stay optional.';

  @override
  String storeFreeGem(int gems) {
    return 'Watch an ad for $gems gem';
  }

  @override
  String get storeOwned => 'Owned';

  @override
  String get storeConfirmTitle => 'Simulated purchase';

  @override
  String storeConfirmBody(String item, String price) {
    return 'Buy $item for $price? No real money will be charged.';
  }

  @override
  String get storePurchaseSuccess => 'Thank you! Your items have been added.';

  @override
  String get adsLimitReached => 'No more ad rewards today';

  @override
  String get adSimulatedTitle => 'Ad (simulated)';

  @override
  String get adSimulatedBody =>
      'A real ad will play here in the release version.';

  @override
  String adSimulatedClosing(int seconds) {
    return 'Closing in ${seconds}s';
  }

  @override
  String get adRewardGranted => 'Reward received!';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Device language';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageVi => 'Tiếng Việt';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsResetData => 'Reset game data';

  @override
  String get settingsResetConfirmTitle => 'Reset all progress?';

  @override
  String get settingsResetConfirmBody =>
      'Coins, levels, decorations and story progress will be erased. This can\'t be undone.';

  @override
  String get settingsResetDone => 'Game data reset';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAlphaNote => 'Alpha build. Thanks for playing!';
}
