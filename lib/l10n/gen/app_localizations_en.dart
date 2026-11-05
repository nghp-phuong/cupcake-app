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
  String get dayExitConfirmTitle => 'Close the shop early?';

  @override
  String get dayExitConfirmBody =>
      'You keep the coins from customers already served, but there\'s no shift bonus.';

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
  String get mochiPet => 'Pet';

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
  String get mouldPastryTray => 'Pastry tray';

  @override
  String get mouldShellMould => 'Shell mould';

  @override
  String get mouldEclairTray => 'Éclair tray';

  @override
  String get mouldPiePan => 'Pie dish';

  @override
  String get mouldMooncakeMould => 'Mooncake press';

  @override
  String get mouldLogPan => 'Swiss roll pan';

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
  String get batterLaminated => 'Laminated dough';

  @override
  String get batterChoux => 'Choux pastry';

  @override
  String get batterMooncake => 'Mooncake crust';

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
  String get frostingButterGlaze => 'Egg wash glaze';

  @override
  String get frostingAppleFilling => 'Apple filling';

  @override
  String get frostingLotusPaste => 'Lotus paste';

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
  String get toppingAlmondFlakes => 'Almond flakes';

  @override
  String get toppingPowderedSugar => 'Powdered sugar';

  @override
  String get toppingKiwi => 'Kiwi';

  @override
  String get toppingSesame => 'Sesame seeds';

  @override
  String get toppingMeringueMushroom => 'Meringue mushroom';

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
  String get recipeCroissant => 'Croissant';

  @override
  String get recipeCroissantDesc =>
      'Buttery, flaky layers rolled into a golden crescent.';

  @override
  String get recipePainAuChocolat => 'Pain au chocolat';

  @override
  String get recipePainAuChocolatDesc =>
      'Crisp pastry hugging two bars of dark chocolate.';

  @override
  String get recipeMadeleine => 'Madeleine';

  @override
  String get recipeMadeleineDesc => 'Little shell cakes, warm and lemony.';

  @override
  String get recipeEclair => 'Éclair';

  @override
  String get recipeEclairDesc =>
      'Light choux filled with custard, topped with ganache.';

  @override
  String get recipeFruitTart => 'Fruit tart';

  @override
  String get recipeFruitTartDesc =>
      'Custard tart crowned with jewel-bright fruit.';

  @override
  String get recipeApplePie => 'Apple pie';

  @override
  String get recipeApplePieDesc =>
      'Spiced apples under a golden lattice crust.';

  @override
  String get recipeMooncake => 'Mooncake';

  @override
  String get recipeMooncakeDesc =>
      'Lotus paste in a patterned golden crust, for the festival.';

  @override
  String get recipeBucheDeNoel => 'Bûche de Noël';

  @override
  String get recipeBucheDeNoelDesc =>
      'A chocolate Yule log with meringue mushrooms.';

  @override
  String get charMai => 'Mai';

  @override
  String get charHoa => 'Mr. Hoa';

  @override
  String get charLinh => 'Linh';

  @override
  String get charKenji => 'Kenji';

  @override
  String get charRosa => 'Mrs. Rosa';

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
  String get storyCh1End1 =>
      'The first pages of Grandma\'s book are filled again.';

  @override
  String get storyCh1End2 =>
      'The town is starting to know my cupcakes… Time to get busier!';

  @override
  String get storyCh2End3 =>
      'And just past the back door, a new chapter is waiting…';

  @override
  String get storyCh3Open1 =>
      'Behind the bakery, Grandma\'s garden has grown wild with mint and climbing roses.';

  @override
  String get storyCh3Open2 =>
      'What\'s hiding under all these leaves? A little garden shed!';

  @override
  String get storyCh3Open3 =>
      'A page from Grandma\'s book, tucked in a flowerpot: \"Croissants. Fold the butter in, and be patient.\"';

  @override
  String get storyCh3Open4 =>
      'Mai brushes off the soil and smiles. The garden kept Grandma\'s secret safe.';

  @override
  String get storyMochi1Line1 =>
      'Rain drums on the awning. Beneath it, a small grey cat sits very, very still.';

  @override
  String get storyMochi1Line2 =>
      'Oh! You\'re soaked, little one. Come in, the oven is warm.';

  @override
  String get storyMochi1Line3 =>
      'The cat curls up by the counter and purrs like a tiny engine.';

  @override
  String get storyMochi1Line4 =>
      'I\'ll call you Mochi. Come by whenever it rains, okay?';

  @override
  String get storyKenji4Line1 =>
      'Today I\'d like something… for a day when you miss home.';

  @override
  String get storyKenji4Line2 =>
      'Something small and warm, then. Like a hug from far away.';

  @override
  String get storyKenji4Line3 =>
      'A madeleine. Grandma said one bite can bring back a whole afternoon.';

  @override
  String get storyKenji4Line4 => 'Then I\'ll eat it slowly.';

  @override
  String get storyCh4Open1 =>
      'Upstairs, dust dances in the light of the little round window.';

  @override
  String get storyCh4Open2 =>
      'Grandma\'s old letter box… she kept every note her customers ever wrote.';

  @override
  String get storyCh4Open3 =>
      'And two more pages: éclairs, and a fruit tart \"for sunny days\".';

  @override
  String get storyCh4Open4 =>
      'Mai tucks the pages into the book. It feels a little heavier now, in the best way.';

  @override
  String get storyRosa1Line1 =>
      'Good afternoon, dear. Your grandmother baked my wedding cake, you know.';

  @override
  String get storyRosa1Line2 =>
      'Now my granddaughter is getting married, right by the sea.';

  @override
  String get storyRosa1Line3 => 'Mrs. Rosa, that\'s wonderful news!';

  @override
  String get storyRosa1Line4 =>
      'When the day comes, I\'ll order her cake from you. Your grandmother would like that.';

  @override
  String get storyLinh4Line1 =>
      'Mai! The school fair is next week, and I signed us up for a stall!';

  @override
  String get storyLinh4Line2 => 'Us? What are we selling?';

  @override
  String get storyLinh4Line3 =>
      'Apple pie! The whole school smells of cinnamon when someone brings one.';

  @override
  String get storyLinh4Line4 =>
      'Then we\'ll bake the prettiest lattice in town. Grandma\'s way.';

  @override
  String get storyCh5Open1 =>
      'Lanterns are going up all along the harbor. The seaside festival is almost here.';

  @override
  String get storyCh5Open2 =>
      'The whole town is decorating… and everyone keeps asking about mooncakes.';

  @override
  String get storyCh5Open3 =>
      'Grandma\'s book has a page for those too: lotus paste and a little flower press.';

  @override
  String get storyCh5Open4 =>
      'Tonight the bakery will glow like one more lantern by the sea.';

  @override
  String get storyHoa4Line1 =>
      'Every winter, your grandmother baked a chocolate log for the whole street.';

  @override
  String get storyHoa4Line2 =>
      'Little meringue mushrooms, a dusting of sugar snow… the children adored it.';

  @override
  String get storyHoa4Line3 => 'A bûche de Noël? I\'ve never made one.';

  @override
  String get storyHoa4Line4 =>
      'You will. Her hands are in yours now, I can tell.';

  @override
  String get storyRosa2Line1 =>
      'The wedding is today, dear. Is the cake ready?';

  @override
  String get storyRosa2Line2 =>
      'Almost. Three tiers, wrapped as a gift, just like the one Grandma made for you.';

  @override
  String get storyRosa2Line3 =>
      'Oh… my granddaughter will cry. I might cry too.';

  @override
  String get storyRosa2Line4 => 'Then let\'s make it worth every happy tear.';

  @override
  String get storyFinale2Line1 =>
      'The last empty page of Grandma\'s book is finally filled.';

  @override
  String get storyFinale2Line2 =>
      'The bakery is warm and busy again, full of friends and their stories.';

  @override
  String get storyFinale2Line3 =>
      'But a good bakery never runs out of stories… there are many more to come.';

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
    return 'Shift bonus +$xp XP';
  }

  @override
  String get summaryRainyDay => 'A rainy day — Mochi dropped by';

  @override
  String get summaryDouble => 'Double coins (watch ad)';

  @override
  String get summaryDoubled => 'Coins doubled!';

  @override
  String summaryLevelUp(int level) {
    return 'Level up! Mai is now level $level';
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
  String get storeRemoveAds => 'Remove ads';

  @override
  String get storeRemoveAdsDesc =>
      'No more ads between days. Reward ads stay optional.';

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
  String get adNotCompleted => 'The ad didn\'t finish, so no reward this time.';

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
      'Coins, level, Mai\'s hairstyle and the places you\'ve visited will be erased. Language and sound are kept. This can\'t be undone.';

  @override
  String get settingsResetDone => 'Game data reset';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAlphaNote => 'Alpha build. Thanks for playing!';

  @override
  String get unlockNoticeTitle => 'New unlock!';

  @override
  String unlockNoticeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new things are ready for your bakery.',
      one: 'Something new is ready for your bakery.',
    );
    return '$_temp0';
  }

  @override
  String get unlockNoticeView => 'Take a look';

  @override
  String get unlockNoticeLater => 'Later';

  @override
  String unlockNoticeTier(int tier) {
    return 'Tier $tier unlocked';
  }

  @override
  String unlockNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String offlineDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String offlineDurationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String offlineDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String offlineDurationDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: 'over a day',
    );
    return '$_temp0';
  }

  @override
  String get offlineDouble => 'x2 (watch ad)';

  @override
  String get introLineKitchen => 'One morning in a little seaside town…';

  @override
  String get introLineCase =>
      'Grandma\'s cake case still shines like it always did.';

  @override
  String get introLineDoor => 'Mai flips the sign — Sugarleaf is open!';

  @override
  String get introSignOpen => 'Open';

  @override
  String get introSemantics => 'Opening scene';

  @override
  String get settingsReplayIntro => 'Replay opening';

  @override
  String get charNora => 'Nora';

  @override
  String get charBao => 'Bao';

  @override
  String get charTheo => 'Theo';

  @override
  String get npcSquirrel => 'Squirrel';

  @override
  String get npcHamster => 'Hamster';

  @override
  String get npcShiba => 'Shiba';

  @override
  String get npcBlackCat => 'Black Cat';

  @override
  String get npcWalrus => 'Mr. Walrus';

  @override
  String get npcLion => 'Mr. Lion';

  @override
  String get talkHoaOwlL1 =>
      'They say owls are night birds. Yet here I am at your door by five every morning.';

  @override
  String get talkHoaOwlL2 => 'But Mr. Hoa, we open at seven!';

  @override
  String get talkHoaOwlL3 =>
      'I know. Those two hours are for smelling the butter through the door.';

  @override
  String get talkHoaOwlC1 => 'I\'ll open early for you, then!';

  @override
  String get talkHoaOwlR1 =>
      'No, no. Waiting is half the flavour of an egg tart.';

  @override
  String get talkHoaOwlC2 =>
      'Then I\'ll bake so well you can smell it from home!';

  @override
  String get talkHoaOwlR2 =>
      'Then I\'d lose my excuse to wake up early. Very well, deal.';

  @override
  String get talkHoaOwlL4 =>
      'Then tomorrow, the first tart out of the oven is yours.';

  @override
  String get talkLinhSketchL1 => 'Mai, hold still! I\'m sketching you.';

  @override
  String get talkLinhSketchL2 => 'But I\'ve got flour all over my hair…';

  @override
  String get talkLinhSketchL3 => 'Done! Take a look.';

  @override
  String get talkLinhSketchL4 =>
      'Linh… why am I a steamed bun wearing an apron?';

  @override
  String get talkLinhSketchL5 =>
      'Because you\'re round, soft and warm. It\'s a compliment!';

  @override
  String get talkLinhSketchC1 => 'Then give me a bow!';

  @override
  String get talkLinhSketchR1 => 'Two bows! The cutest bun in town!';

  @override
  String get talkLinhSketchC2 => 'Can I hang it by the counter?';

  @override
  String get talkLinhSketchR2 => 'Really? Look, my ears just shot straight up!';

  @override
  String get talkKenjiCloudL1 =>
      'Today I feel like a cloud that meant to rain… then changed its mind.';

  @override
  String get talkKenjiCloudL2 => 'A cloud that changed its mind… Let me think.';

  @override
  String get talkKenjiCloudC1 =>
      'Matcha cake: a little bitter at first, then sweeter.';

  @override
  String get talkKenjiCloudR1 =>
      'That\'s exactly the cloud. I\'ll photograph it before I eat.';

  @override
  String get talkKenjiCloudC2 =>
      'A vanilla cupcake, white and fluffy like a cloud.';

  @override
  String get talkKenjiCloudR2 => 'A bit… literal. But I like your honesty.';

  @override
  String get talkKenjiCloudL3 =>
      'Every visit here, my film roll gets a little shorter.';

  @override
  String get talkRosaSecretL1 =>
      'Do you know, dear, for sixty years I have eaten cake only with a silver fork.';

  @override
  String get talkRosaSecretL2 =>
      'Yes… but there\'s a dab of cream on the tip of your nose.';

  @override
  String get talkRosaSecretL3 => 'Hmm. The wind must have blown it there.';

  @override
  String get talkRosaSecretL4 => 'There\'s no wind indoors, though?';

  @override
  String get talkRosaSecretC1 => '(Wink) I didn\'t see a thing.';

  @override
  String get talkRosaSecretR1 =>
      'Clever girl. Here\'s a tip for your discretion.';

  @override
  String get talkRosaSecretC2 =>
      'Go on, have a taste, today\'s cream is lovely!';

  @override
  String get talkRosaSecretR2 =>
      '(A very quick lick) …It is lovely. Tell no one.';

  @override
  String get talkMochiBellyL1 => 'Mrrp.';

  @override
  String get talkMochiBellyL2 =>
      'Soaked again? The oven\'s still warm, go dry off.';

  @override
  String get talkMochiBellyL3 => '(Mochi flops over and shows a fluffy belly.)';

  @override
  String get talkMochiBellyL4 =>
      'It\'s a trap. I know it. Belly rubs mean bites.';

  @override
  String get talkMochiBellyC1 => 'Rub the belly';

  @override
  String get talkMochiBellyR1 =>
      '(Mochi hugs Mai\'s hand with all four paws… and purrs.)';

  @override
  String get talkMochiBellyC2 => 'Roll the yarn ball';

  @override
  String get talkMochiBellyR2 =>
      '(Mochi chases the yarn and skids a full circle across the floor.)';

  @override
  String get talkMochiBellyL5 => 'You little rascal.';

  @override
  String get talkWalrusFishL1 =>
      'Guess how big the fish I caught this morning was?';

  @override
  String get talkWalrusFishL2 => 'How big?';

  @override
  String get talkWalrusFishL3 => 'As big as… your oven!';

  @override
  String get talkWalrusFishC1 =>
      'Last week you said it was as big as the fridge.';

  @override
  String get talkWalrusFishR1 =>
      'Well… it\'s been growing! Even the fish eat your pastries.';

  @override
  String get talkWalrusFishC2 => 'Did you bring it home?';

  @override
  String get talkWalrusFishR2 =>
      'It begged to be let go. Promised to come back tomorrow… even bigger.';

  @override
  String get talkWalrusFishL4 => 'Then I\'d better get a bigger oven ready.';

  @override
  String get talkSquirrelNutL1 =>
      'Can I pay in chestnuts? I\'ve got a whole stash!';

  @override
  String get talkSquirrelNutL2 => 'Oh… we only take coins here.';

  @override
  String get talkSquirrelNutL3 => 'Wait, let me check my tail…';

  @override
  String get talkSquirrelNutL4 =>
      'Here! Three coins, a button, and… one emergency chestnut.';

  @override
  String get talkSquirrelNutC1 =>
      'I\'ll take the coins, you keep the chestnut.';

  @override
  String get talkSquirrelNutR1 =>
      'You\'re the best! I\'ll bury it outside so a tree grows for you.';

  @override
  String get talkSquirrelNutC2 =>
      'Give me the chestnut, I\'ll bake you something with it!';

  @override
  String get talkSquirrelNutR2 =>
      'Really? I\'ll fetch more… from wherever I buried them. I forgot where.';

  @override
  String get talkHamsterCheeksL1 => 'Could I have… mmf-mm-mmf…';

  @override
  String get talkHamsterCheeksL2 =>
      'Sweetie, your cheeks are already full of cookies.';

  @override
  String get talkHamsterCheeksL3 =>
      '(Gulp) Those are for later. This one is for now!';

  @override
  String get talkHamsterCheeksC1 => 'Let me box some up for you to take home.';

  @override
  String get talkHamsterCheeksR1 => 'A box! My cheeks get the day off!';

  @override
  String get talkHamsterCheeksC2 => 'Think you can fit one more?';

  @override
  String get talkHamsterCheeksR2 => 'Challenge accepted! …Mmf… perfect fit.';

  @override
  String get smallTalkNora => 'Your usual today? I remember!';

  @override
  String get smallTalkBao => '…Fresh out of the oven. Still warm.';

  @override
  String get smallTalkTheo =>
      'Today\'s tea is brewed with a smile, give it a try!';

  @override
  String get smallTalkMai1 => 'Lovely day! Been down to the beach yet?';

  @override
  String get smallTalkMai2 =>
      'The next batch has a pinch of cinnamon, come back and try it!';

  @override
  String get smallTalkReply1 => 'Aw, thank you!';

  @override
  String get smallTalkReply2 => 'Lovely, I\'ll be back tomorrow!';

  @override
  String get smallTalkReply3 => 'This place always smells so good.';

  @override
  String get quarrelLastCakeL1 =>
      'This strawberry cupcake is mine! I saw it first!';

  @override
  String get quarrelLastCakeL2 =>
      'But I\'ve been dreaming about it since yesterday!';

  @override
  String get quarrelLastCakeL3 => 'Dreaming doesn\'t count!';

  @override
  String get quarrelLastCakeL4 =>
      'Easy, you two, the cupcake\'s getting squished!';

  @override
  String get quarrelLastCakeA => 'Split it in half';

  @override
  String get quarrelLastCakeRA1 => 'Half… fits perfectly in one cheek!';

  @override
  String get quarrelLastCakeRA2 => 'My half has more frosting. Hehe.';

  @override
  String get quarrelLastCakeB => 'Rock-paper-scissors for it';

  @override
  String get quarrelLastCakeRB1 => 'Rock, paper, scissors… shoot!';

  @override
  String get quarrelLastCakeRB2 => 'I win!';

  @override
  String get quarrelLastCakeRB3 => 'Hmph… next time I\'m going rock.';

  @override
  String get quarrelLastCakeC => 'A fresh batch is almost out, one each!';

  @override
  String get quarrelLastCakeRC1 => 'One EACH?!';

  @override
  String get quarrelLastCakeRC2 => 'You\'re a pastry angel!';

  @override
  String get quarrelFirstL1 => 'I\'ve been here since sunrise! I go first!';

  @override
  String get quarrelFirstL2 =>
      'I napped on this doorstep all night. That\'s what cats do.';

  @override
  String get quarrelFirstL3 => 'Napping isn\'t queueing!';

  @override
  String get quarrelFirstL4 => 'For cats, it is.';

  @override
  String get quarrelFirstL5 => 'Okay, okay, deep breaths!';

  @override
  String get quarrelFirstA => 'Come in together, the door\'s wide enough!';

  @override
  String get quarrelFirstRA1 => '…It\'s a bit tight.';

  @override
  String get quarrelFirstRA2 => 'Suck in your tummy.';

  @override
  String get quarrelFirstRA3 =>
      '(They\'re stuck in the doorway for a second… then both burst out laughing.)';

  @override
  String get quarrelFirstB => 'Check the paw prints on the doormat';

  @override
  String get quarrelFirstRB1 => 'Cat prints underneath… shiba prints on top.';

  @override
  String get quarrelFirstRB2 => 'Well… I did stand on their paw prints.';

  @override
  String get quarrelFirstRB3 => 'Thank you. You\'re adorable. After me.';

  @override
  String get quarrelFirstC => 'Best joke goes first';

  @override
  String get quarrelFirstRC1 =>
      'Why did the croissant see a doctor? It was feeling flaky!';

  @override
  String get quarrelFirstRC2 => '…That was awful. I laughed. You go first.';

  @override
  String get quarrelTartL1 =>
      'Egg tarts are the king of pastries! Crisp, rich, golden as the sun!';

  @override
  String get quarrelTartL2 =>
      'King? I\'m the king around here. And the king picks apple pie.';

  @override
  String get quarrelTartL3 => 'All you\'ve got is a big mane!';

  @override
  String get quarrelTartL4 => 'And all you\'ve got is a round belly!';

  @override
  String get quarrelTartL5 => 'Gentlemen, the whole street is watching!';

  @override
  String get quarrelTartA => 'Blind taste test, try both!';

  @override
  String get quarrelTartRA1 => 'This one\'s… better. It\'s the apple pie?!';

  @override
  String get quarrelTartRA2 => 'And I picked… the egg tart. Oh no.';

  @override
  String get quarrelTartRA3 => 'Fine, we\'ll buy both!';

  @override
  String get quarrelTartB => 'Every pastry is delicious, shake hands!';

  @override
  String get quarrelTartRB1 => 'Spoken like a diplomat.';

  @override
  String get quarrelTartRB2 => 'Bland as unseasoned dough.';

  @override
  String get quarrelTartC => 'Ask Mr. Hoa to settle it';

  @override
  String get quarrelTartCAlt => 'Do your best Mr. Hoa impression';

  @override
  String get quarrelTartRC1 => 'Egg tart. Forty years. Not up for debate.';

  @override
  String get quarrelTartRC1Alt =>
      '(Deep voice) Ahem… Egg tart. Forty years. Not up for debate.';

  @override
  String get quarrelTartRC2 => 'Hear that? Hear that!';

  @override
  String get quarrelTartRC3 => 'Hmph. The seniors\' club is biased.';

  @override
  String get quarrelBanner => 'There\'s a commotion outside!';

  @override
  String get quarrelLook => 'Look';

  @override
  String get quarrelSendMai => 'Send Mai';

  @override
  String get quarrelIntervene => 'Step in';

  @override
  String get quarrelTimeout => 'The two customers stomped off in a huff…';

  @override
  String get quarrelPeace => 'Peace returns to the street.';

  @override
  String get staffMenuControl => 'Control';

  @override
  String get staffMenuTalk => 'Talk to a customer';

  @override
  String get actionPickUp => 'Pick up';

  @override
  String get actionPutDown => 'Put down';

  @override
  String get actionPlaceOn => 'Place';

  @override
  String get actionGive => 'Offer';

  @override
  String get actionThrow => 'Throw';

  @override
  String get actionTalk => 'Talk';

  @override
  String get actionWave => 'Wave';

  @override
  String get controlHint =>
      'Drag the left circle to walk, tap the right buttons to act.';

  @override
  String get talkPickCustomer => 'Pick a customer to chat with';

  @override
  String get talkNoCustomer => 'No customers are free to chat right now.';

  @override
  String get itemYarn => 'Yarn ball';

  @override
  String get itemCakeBox => 'Cake box';

  @override
  String get itemFlour => 'Flour sack';

  @override
  String get reactOops => 'Oops!';

  @override
  String get reactStop => 'Hey, quit it!';

  @override
  String get reactThanks => 'Thank you!';

  @override
  String get reactFull => 'I\'m full, but thank you!';

  @override
  String get reactNoThrowCake => 'Cake is handed, not thrown!';

  @override
  String get reactExcuseMe => 'Excuse me!';

  @override
  String get reactPurr => 'Purr…';

  @override
  String interactGoodwill(int count) {
    return '+$count goodwill';
  }

  @override
  String interactCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count coins',
      one: '+1 coin',
    );
    return '$_temp0';
  }

  @override
  String get townEnterShop => 'Enter';

  @override
  String get townExitShop => 'Go outside';

  @override
  String get townMap => 'Map';

  @override
  String get townOpenMap => 'Open map';

  @override
  String get townYouAreHere => 'You are here';

  @override
  String get townHomeShop => 'Grandma\'s bakery';

  @override
  String townBranchN(int n) {
    return 'Branch $n';
  }

  @override
  String get townLotForSale => 'Empty lot';

  @override
  String townLotLocked(int level) {
    return 'Unlocks at level $level';
  }

  @override
  String get townLotUnlocked => 'Unlocked · on sale soon';

  @override
  String townLotsUnlockedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new lots unlocked!',
      one: 'New lot unlocked!',
    );
    return '$_temp0';
  }

  @override
  String get townComingSoon => 'Coming soon';

  @override
  String get townStreetName => 'Bakery Street';

  @override
  String get townOpening => 'Opening the door…';

  @override
  String get citySeaMarketName => 'Seaside Market';

  @override
  String get cityRealtyName => 'Harbor Realty';

  @override
  String get cityParkName => 'Lighthouse Park';

  @override
  String get cityRestaurantName => 'Lighthouse Kitchen';

  @override
  String get citySalonName => 'Seashell Salon';

  @override
  String get cityOrderFood => 'Order';

  @override
  String get cityGetHaircut => 'Style hair';

  @override
  String cityPrice(int coins) {
    return '$coins coins';
  }

  @override
  String cityXpGain(int xp) {
    return '+$xp XP';
  }

  @override
  String cityMaiLevel(int n) {
    return 'Level $n';
  }

  @override
  String get cityLevelUp => 'Level up!';

  @override
  String get cityNotEnoughCoins => 'Not enough coins';

  @override
  String get cityAteToday => 'Already eaten today – less XP';

  @override
  String get cityBuffFull => 'Full & happy: +10% tips next shift';

  @override
  String get cityConfirm => 'Confirm';

  @override
  String get cityCancel => 'Cancel';

  @override
  String get cityFirstVisit => 'First visit bonus!';

  @override
  String get cityMenuTitle => 'Today\'s menu';

  @override
  String get citySalonTitle => 'Choose a new look';

  @override
  String get cityHairStyle => 'Hairstyle';

  @override
  String get cityHairColor => 'Hair color';

  @override
  String get cityEating => 'Enjoying the meal…';

  @override
  String get citySaveReadOnly =>
      'This save is from a newer game version. Progress this session won\'t be saved.';

  @override
  String get shiftOpen => 'Open shop';

  @override
  String get shiftHintCounter =>
      'Go to the counter and tap “Open shop” to start selling';

  @override
  String get shiftCustomerComing => 'A customer is on the way…';

  @override
  String get shiftSummaryTitle => 'Shift complete!';

  @override
  String get shiftCloseEarly => 'Close early';

  @override
  String shiftClosedToast(int coins) {
    return 'Shop closed · +$coins coins kept';
  }

  @override
  String shiftBuffTip(int amount) {
    return 'Full & happy: +$amount tips';
  }

  @override
  String get dishFishSoup => 'Seaside fish soup';

  @override
  String get dishOmeletteRice => 'Omelette rice';

  @override
  String get dishVeggieCurry => 'Veggie curry';

  @override
  String get dishSeafoodNoodles => 'Seafood noodles';

  @override
  String get hairPonytail => 'Ponytail';

  @override
  String get hairBob => 'Bob';

  @override
  String get hairBun => 'Bun';

  @override
  String get hairTwinTails => 'Twin tails';

  @override
  String get hairColorChestnut => 'Chestnut';

  @override
  String get hairColorCaramel => 'Caramel';

  @override
  String get hairColorBlack => 'Black';

  @override
  String get hairColorStrawberry => 'Strawberry';
}
