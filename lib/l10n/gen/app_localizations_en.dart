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
  String get recipeSecretsTitle => 'Grandma\'s secrets';

  @override
  String recipeSecretsLocked(int level) {
    return 'Unlocks after level $level';
  }

  @override
  String recipeSecretsTier(int tier, int max) {
    return 'Secret $tier/$max';
  }

  @override
  String recipeSecretsBonus(int pct) {
    return '+$pct% price';
  }

  @override
  String get recipeSecretsBuy => 'Learn';

  @override
  String get recipeSecretsMaxed => 'All secrets learned';

  @override
  String get recipeSecretsRecipeLocked => 'Find this recipe first';

  @override
  String get recipeSecretsHint => 'Each secret makes this treat sell for more.';

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
  String get storeTestMode => 'Test mode';

  @override
  String storeGemsDesc(int gems) {
    return '$gems gems';
  }

  @override
  String storeStarterPackDescV2(int coins, int gems, int count) {
    return '$coins coins + $gems gems + every booster ×$count';
  }

  @override
  String get storeStarterBadge => 'Best deal';

  @override
  String get storeRemoveAdsDescV2 =>
      'No more ads between levels. Reward ads stay optional.';

  @override
  String get storeStaffOutfitsDesc =>
      'Festival looks for Nora and Bao. Looks only — switch it in Staff.';

  @override
  String get storeSeasonPassDesc =>
      'Unlock the premium rewards of this season.';

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

  @override
  String get settingsPurchases => 'Purchases';

  @override
  String get settingsRestore => 'Restore purchases';

  @override
  String settingsRestoreDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count purchases',
      one: 'Restored 1 purchase',
    );
    return '$_temp0';
  }

  @override
  String get settingsRestoreNone => 'Nothing to restore';

  @override
  String get settingsRestoreFailed =>
      'Couldn\'t restore right now. Please try again later.';

  @override
  String get levelMenuButton => 'Levels';

  @override
  String levelChapterLabel(int chapter) {
    return 'Chapter $chapter';
  }

  @override
  String levelNumber(int level) {
    return 'Level $level';
  }

  @override
  String get levelNewBadge => 'New';

  @override
  String get levelSpecialBadge => 'Special';

  @override
  String get levelGoalLabel => 'Goal';

  @override
  String levelGoalCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Earn $count coins',
      one: 'Earn 1 coin',
    );
    return '$_temp0';
  }

  @override
  String levelGoalCustomers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Serve $count customers',
      one: 'Serve 1 customer',
    );
    return '$_temp0';
  }

  @override
  String levelGoalSpecials(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finish $count special orders (3 stars or more)',
      one: 'Finish 1 special order (3 stars or more)',
    );
    return '$_temp0';
  }

  @override
  String get levelTimeLabel => 'Time';

  @override
  String get levelMenuLabel => 'On the menu';

  @override
  String get levelStart => 'Start';

  @override
  String get levelPause => 'Pause';

  @override
  String get levelRush => 'Rush hour!';

  @override
  String levelGoalProgress(int value, int target) {
    return '$value/$target';
  }

  @override
  String levelCombo(String mult) {
    return 'Combo ×$mult';
  }

  @override
  String get levelPauseTitle => 'Paused';

  @override
  String get levelPauseBody => 'Take a breather — your customers will wait.';

  @override
  String get levelQuit => 'Quit';

  @override
  String get levelReplay => 'Play again';

  @override
  String get levelTimeUp => 'Time\'s up!';

  @override
  String levelExtraTimeTitle(int seconds) {
    return '+$seconds seconds?';
  }

  @override
  String get levelExtraTimeBody =>
      'So close! Watch a short ad to keep the shop open a little longer.';

  @override
  String levelExtraTimeWatch(int seconds) {
    return 'Watch ad (+${seconds}s)';
  }

  @override
  String get levelExtraTimeNo => 'No thanks';

  @override
  String get levelSpecialLater => 'Later';

  @override
  String get levelSpecialQuitTitle => 'Leave this order?';

  @override
  String get levelSpecialQuitBody =>
      'The customer will keep waiting — you can come back to it.';

  @override
  String get levelResultWinTitle => 'Level complete!';

  @override
  String get levelResultLoseTitle => 'So close — let\'s try again!';

  @override
  String levelResultGoal(String progress) {
    return 'Goal: $progress';
  }

  @override
  String get levelResultCoins => 'Coins earned';

  @override
  String get levelResultServed => 'Happy customers';

  @override
  String get levelResultLost => 'Customers who left';

  @override
  String get levelResultSpecials => 'Special orders';

  @override
  String get levelResultBestCombo => 'Best combo';

  @override
  String get levelResultFiveStar => '5-star treats';

  @override
  String get levelResultDoubleCoins => '×2 coins (watch ad)';

  @override
  String levelResultDoubled(int coins) {
    return 'Coins doubled! +$coins';
  }

  @override
  String get levelNext => 'Next level';

  @override
  String get levelList => 'Level list';

  @override
  String get lvlCaseFull => 'Case full!';

  @override
  String get lvlRushHour => 'Rush hour!';

  @override
  String lvlCombo(int count) {
    return 'Combo ×$count';
  }

  @override
  String get lvlWaitOven => 'Waiting for oven';

  @override
  String get lvlWaiting => 'Waiting…';

  @override
  String get lvlPickTreat => 'Tap a treat';

  @override
  String get lvlBurnt => 'Burnt!';

  @override
  String get lvlTakeOut => 'Take out!';

  @override
  String get lvlStirHint => 'Stir 1 turn';

  @override
  String get lvlSwipeHint => 'Swipe across';

  @override
  String get lvlBoosterTitle => 'Boosters';

  @override
  String get lvlBoosterAdFree => 'Watch ad: 1 free';

  @override
  String get lvlBoosterFree => 'Free';

  @override
  String get lvlBoosterPickFree => 'Pick a booster — one is free!';

  @override
  String get lvlBoosterIntro =>
      'New! Boosters make a level easier. Here\'s one to try for free.';

  @override
  String lvlBoosterSelected(String name) {
    return '$name, selected';
  }

  @override
  String get mapSeasonShort => 'Season';

  @override
  String get seasonTitle => 'Season pass';

  @override
  String seasonTimeLeft(String time) {
    return 'Ends in $time';
  }

  @override
  String seasonDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String seasonHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String seasonPoints(int points, int need) {
    return '$points/$need points';
  }

  @override
  String seasonPointsMax(int points) {
    return '$points points · all tiers reached';
  }

  @override
  String seasonHowTo(int star, int win) {
    return '+$star points for each new star, +$win for each win';
  }

  @override
  String seasonTierLabel(int tier) {
    return 'Tier $tier';
  }

  @override
  String get seasonFreeRow => 'Free';

  @override
  String get seasonPremiumRow => 'Premium';

  @override
  String get seasonClaimAll => 'Claim all';

  @override
  String seasonClaimedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rewards claimed!',
      one: 'Reward claimed!',
    );
    return '$_temp0';
  }

  @override
  String seasonBuyPremium(String price) {
    return 'Unlock premium · $price';
  }

  @override
  String get seasonPremiumActive => 'Premium unlocked';

  @override
  String get seasonPremiumHint => 'Unlock premium to claim';

  @override
  String get seasonEnded =>
      'The season has ended. Your unclaimed rewards were added automatically.';

  @override
  String get seasonNone => 'No season is running right now.';

  @override
  String get seasonRewardFrame => 'Portrait frame';

  @override
  String seasonRewardBooster(String name, int count) {
    return '$name ×$count';
  }

  @override
  String levelSpecialCondition(
    String who,
    int served,
    int target,
    String time,
  ) {
    return '$who drops by if you serve $served/$target by $time';
  }

  @override
  String levelSpecialConditionNoTime(String who, int served, int target) {
    return '$who drops by after $served/$target served';
  }

  @override
  String levelSpecialSkipped(String who) {
    return '$who couldn\'t make it this time';
  }

  @override
  String mapStarsTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get mapQuestsShort => 'Quests';

  @override
  String get mapGiftShort => 'Gift';

  @override
  String get mapPrevChapter => 'Previous chapter';

  @override
  String get mapNextChapter => 'Next chapter';

  @override
  String mapLevelLabel(int level, int stars) {
    return 'Level $level: $stars of 3 stars';
  }

  @override
  String mapLevelLockedLabel(int level) {
    return 'Level $level, locked';
  }

  @override
  String get mapLevelLocked => 'Finish the previous level to unlock this one!';

  @override
  String mapChapterLockedTitle(int chapter) {
    return 'Chapter $chapter is locked';
  }

  @override
  String mapChapterNeedStars(int need, int have) {
    return 'Need $need stars — you have $have';
  }

  @override
  String mapChapterNeedFinish(int chapter) {
    return 'Finish chapter $chapter first';
  }

  @override
  String get mapChapterReplayHint =>
      'Replay levels with fewer stars to collect more';

  @override
  String mapChapterUnlockedTitle(int chapter) {
    return 'Chapter $chapter unlocked!';
  }

  @override
  String get mapChapterUnlockedBody =>
      'New recipes and new faces are waiting in this part of town.';

  @override
  String get mapChapterUnlockedGo => 'Let\'s go!';

  @override
  String get mapBackToMap => 'Map';

  @override
  String get mapLoadError =>
      'The level map couldn\'t load. Please restart the game.';

  @override
  String mapUnlockAfterLevel(int level) {
    return 'Clear level $level to unlock';
  }

  @override
  String mapRecipeFromLevel(int level) {
    return 'Missing page. Reach level $level to find it';
  }

  @override
  String get mapRecipeLater => 'Missing page. Coming in a later chapter';

  @override
  String get mapWelcomeTitle => 'Welcome back!';

  @override
  String mapWelcomeBody(int coins, int gems) {
    return 'The bakery has a new look: play level by level on the town map. As a thank-you, here are $coins coins and $gems gems.';
  }

  @override
  String get upgTabExpansion => 'Expand the bakery';

  @override
  String get upgTabEquipment => 'Equipment';

  @override
  String get upgOwned => 'Owned';

  @override
  String get upgComingSoon => 'Coming soon';

  @override
  String get upgExpansionDone => 'Added to your bakery!';

  @override
  String upgTierOf(int current, int max) {
    return 'Tier $current/$max';
  }

  @override
  String upgStatOvenSec(String seconds) {
    return 'Bakes in ${seconds}s';
  }

  @override
  String upgStatBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cakes per tray',
      one: '1 cake per tray',
    );
    return '$_temp0';
  }

  @override
  String upgStatCaseSlot(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cakes per case slot',
      one: '1 cake per case slot',
    );
    return '$_temp0';
  }

  @override
  String upgStatMixZone(int percent) {
    return 'Green zone $percent%';
  }

  @override
  String upgStatStroke(int size) {
    return 'Frosting stroke $size';
  }

  @override
  String upgStatSnap(int size) {
    return 'Snap range $size';
  }

  @override
  String get upgStatSnapNone => 'No snapping';

  @override
  String upgStatNext(String stat) {
    return 'Next: $stat';
  }

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
  String levelShopCase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count case slots',
      one: '1 case slot',
    );
    return '$_temp0';
  }

  @override
  String levelShopOvens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ovens',
      one: '1 oven',
    );
    return '$_temp0';
  }

  @override
  String levelShopTray(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tray of $count',
      one: 'Tray of 1',
    );
    return '$_temp0';
  }

  @override
  String get upgTabStaff => 'Staff';

  @override
  String get staffRoleCashier => 'Cashier';

  @override
  String get staffRoleBaker => 'Baker';

  @override
  String get staffRoleWaiter => 'Server';

  @override
  String get staffRoleManager => 'Manager';

  @override
  String get staffStatSpeed => 'Speed';

  @override
  String get staffStatSkill => 'Skill';

  @override
  String staffStatLevel(String stat, int level, int max) {
    return '$stat level $level of $max';
  }

  @override
  String get staffHire => 'Hire';

  @override
  String get staffHired => 'Welcome to the team!';

  @override
  String staffUpgradeStat(String stat) {
    return 'Upgrade $stat';
  }

  @override
  String staffCashierSpeed(String seconds) {
    return 'Sells every ${seconds}s';
  }

  @override
  String staffCashierSkill(int percent) {
    return '+$percent% tips';
  }

  @override
  String staffBakerSpeed(String seconds) {
    return 'A batch every ${seconds}s';
  }

  @override
  String staffBakerSkill(String stars) {
    return 'Cakes around $stars stars';
  }

  @override
  String staffWaiterSpeed(String seconds) {
    return 'Serves every ${seconds}s';
  }

  @override
  String staffWaiterSkill(int percent) {
    return 'Waiting guests +$percent% patience';
  }

  @override
  String staffManagerSpeed(int percent) {
    return '$percent% of a level\'s coins per hour';
  }

  @override
  String staffManagerSkill(int hours) {
    return 'Counts up to $hours hours away';
  }

  @override
  String staffRequires(String item) {
    return 'Needs $item first';
  }

  @override
  String get staffOutfitFestival => 'Festival outfit';

  @override
  String get offlineTitle => 'While you were away';

  @override
  String offlineBody(String name, String duration) {
    return '$name looked after the bakery for $duration.';
  }

  @override
  String offlineCapped(int hours) {
    return 'Counted $hours hours (the manager\'s limit).';
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
  String offlineEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You earned $count coins',
      one: 'You earned 1 coin',
    );
    return '$_temp0';
  }

  @override
  String get offlineClaim => 'Collect';

  @override
  String get offlineDouble => 'x2 (watch ad)';

  @override
  String get offlineDoubled => 'Coins doubled!';

  @override
  String get levelReadyStaff => 'Helping this level';

  @override
  String levelReadyStaffNames(String names) {
    return '$names will help this level';
  }

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
  String get introTapToEnter => 'Tap to enter the bakery';

  @override
  String get introSemantics => 'Opening scene';

  @override
  String get lvlTutServe => 'This customer wants this treat. Tap them to sell!';

  @override
  String get lvlTutBake => 'Tap a treat card to bake a fresh batch!';

  @override
  String get lvlTutMould => 'Pick the right mould';

  @override
  String get lvlTutMix => 'Stir in circles to mix';

  @override
  String get lvlTutOven => 'Wait for the needle to hit the gold mark, then tap';

  @override
  String get lvlTutFrost => 'Trace the frosting line';

  @override
  String lvlTutTopping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tap the right jar $count times',
      one: 'Tap the right jar once',
    );
    return '$_temp0';
  }

  @override
  String get lvlTutBox => 'Pick the right box';

  @override
  String get lvlTutCaseReady =>
      'Your treats are in the case. Now serve lots of customers!';

  @override
  String get lvlTutCombo =>
      'Sell back to back to grow your combo — more coins!';

  @override
  String get lvlTutNewTreat => 'Each customer wants something different.';

  @override
  String get lvlTutPatience =>
      'The colored ring is their patience. Serve fast for tips!';

  @override
  String get lvlTutWalkout => 'Customers who wait too long will leave.';

  @override
  String get levelReadyCoinsHint => 'This level counts the coins you earn';

  @override
  String get settingsGuide => 'Getting started';

  @override
  String get settingsReplayIntro => 'Replay opening';

  @override
  String get settingsReplayTutorials => 'Replay tutorials';

  @override
  String get settingsTutorialsReset =>
      'Tutorials will show again in Levels 1–3';

  @override
  String get storePurchaseFailed => 'The purchase didn\'t go through.';

  @override
  String get storeSeasonNone =>
      'No season is running right now. Check back soon!';

  @override
  String levelResultSeasonPoints(int points) {
    return '+$points season points';
  }

  @override
  String levelResultBoosterGift(String name) {
    return 'Gift: $name ×1';
  }

  @override
  String get levelPauseBoosterLost =>
      'Boosters used in this run won\'t be refunded.';

  @override
  String get levelPauseBoosterRefund =>
      'Quit or replay now and your boosters go back to your bag.';

  @override
  String get levelBoostersRefunded => 'Boosters returned to your bag.';
}
