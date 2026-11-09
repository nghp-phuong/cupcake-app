import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sugarleaf Bakery'**
  String get appTitle;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get commonBuy;

  /// No description provided for @commonClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get commonClaim;

  /// No description provided for @commonClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get commonClaimed;

  /// No description provided for @commonLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get commonLocked;

  /// No description provided for @commonMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get commonMax;

  /// No description provided for @commonLevelShort.
  ///
  /// In en, this message translates to:
  /// **'Lv. {level}'**
  String commonLevelShort(int level);

  /// No description provided for @commonCoins.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 coin} other{{count} coins}}'**
  String commonCoins(int count);

  /// No description provided for @commonGems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 gem} other{{count} gems}}'**
  String commonGems(int count);

  /// No description provided for @commonNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get commonNotEnoughCoins;

  /// No description provided for @commonWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get commonWatchAd;

  /// No description provided for @rotateDevicePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please turn your device sideways'**
  String get rotateDevicePrompt;

  /// No description provided for @levelUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Level up!'**
  String get levelUpTitle;

  /// No description provided for @menuTagline.
  ///
  /// In en, this message translates to:
  /// **'A cozy little bakery by the sea'**
  String get menuTagline;

  /// No description provided for @menuPlay.
  ///
  /// In en, this message translates to:
  /// **'Open the bakery'**
  String get menuPlay;

  /// No description provided for @menuDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String menuDayLabel(int day);

  /// No description provided for @menuRecipeBook.
  ///
  /// In en, this message translates to:
  /// **'Recipe book'**
  String get menuRecipeBook;

  /// No description provided for @menuUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get menuUpgrades;

  /// No description provided for @menuDecor.
  ///
  /// In en, this message translates to:
  /// **'Decor'**
  String get menuDecor;

  /// No description provided for @menuStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get menuStore;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuQuests.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get menuQuests;

  /// No description provided for @menuLoginGift.
  ///
  /// In en, this message translates to:
  /// **'Daily gift'**
  String get menuLoginGift;

  /// No description provided for @menuShopLevel.
  ///
  /// In en, this message translates to:
  /// **'Bakery level {level}'**
  String menuShopLevel(int level);

  /// No description provided for @menuXpProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{target} XP'**
  String menuXpProgress(int current, int target);

  /// No description provided for @dayStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String dayStartTitle(int day);

  /// No description provided for @dayCustomersToday.
  ///
  /// In en, this message translates to:
  /// **'{count} customers are coming today'**
  String dayCustomersToday(int count);

  /// No description provided for @dayCustomerProgress.
  ///
  /// In en, this message translates to:
  /// **'Customer {current}/{total}'**
  String dayCustomerProgress(int current, int total);

  /// No description provided for @dayOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get dayOrderTitle;

  /// No description provided for @dayOrderFrosting.
  ///
  /// In en, this message translates to:
  /// **'Frosting'**
  String get dayOrderFrosting;

  /// No description provided for @dayOrderToppings.
  ///
  /// In en, this message translates to:
  /// **'Toppings'**
  String get dayOrderToppings;

  /// No description provided for @dayOrderBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get dayOrderBox;

  /// No description provided for @dayStartBaking.
  ///
  /// In en, this message translates to:
  /// **'Start baking'**
  String get dayStartBaking;

  /// No description provided for @dayNextCustomer.
  ///
  /// In en, this message translates to:
  /// **'Next customer'**
  String get dayNextCustomer;

  /// No description provided for @dayRemakeWithAd.
  ///
  /// In en, this message translates to:
  /// **'Remake (watch ad)'**
  String get dayRemakeWithAd;

  /// No description provided for @dayRemakeLine.
  ///
  /// In en, this message translates to:
  /// **'No rush, I\'ll wait for a fresh one!'**
  String get dayRemakeLine;

  /// No description provided for @dayExitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the shop early?'**
  String get dayExitConfirmTitle;

  /// No description provided for @dayExitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You keep the coins from customers already served, but there\'s no shift bonus.'**
  String get dayExitConfirmBody;

  /// Short label on the day intro ribbon when the weather is rainy
  ///
  /// In en, this message translates to:
  /// **'Rainy day'**
  String get dayRainy;

  /// No description provided for @customerRegular.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerRegular;

  /// No description provided for @customerVip.
  ///
  /// In en, this message translates to:
  /// **'VIP guest'**
  String get customerVip;

  /// No description provided for @customerVipBadge.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get customerVipBadge;

  /// No description provided for @customerFriendBadge.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get customerFriendBadge;

  /// No description provided for @resultPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount}'**
  String resultPaid(int amount);

  /// No description provided for @resultTip.
  ///
  /// In en, this message translates to:
  /// **'Tip {amount}'**
  String resultTip(int amount);

  /// No description provided for @resultXp.
  ///
  /// In en, this message translates to:
  /// **'+{amount} XP'**
  String resultXp(int amount);

  /// No description provided for @feedbackNeedsWork.
  ///
  /// In en, this message translates to:
  /// **'Needs work: {station}'**
  String feedbackNeedsWork(String station);

  /// Name of the stray cat who visits on rainy days. Proper name, do not translate.
  ///
  /// In en, this message translates to:
  /// **'Mochi'**
  String get mochiName;

  /// Button: pet Mochi. Keep under 12 characters.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get mochiPet;

  /// No description provided for @orderLine1.
  ///
  /// In en, this message translates to:
  /// **'Hi! One {item}, please.'**
  String orderLine1(String item);

  /// No description provided for @orderLine2.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been craving {item} all day!'**
  String orderLine2(String item);

  /// No description provided for @orderLine3.
  ///
  /// In en, this message translates to:
  /// **'Could you make me one {item}?'**
  String orderLine3(String item);

  /// No description provided for @orderLine4.
  ///
  /// In en, this message translates to:
  /// **'One {item} to go, thank you!'**
  String orderLine4(String item);

  /// No description provided for @orderLine5.
  ///
  /// In en, this message translates to:
  /// **'Something sweet today... {item}!'**
  String orderLine5(String item);

  /// No description provided for @orderLine6.
  ///
  /// In en, this message translates to:
  /// **'My friend says your {item} is lovely.'**
  String orderLine6(String item);

  /// No description provided for @orderLineVip.
  ///
  /// In en, this message translates to:
  /// **'One {item} in your finest gift box, please.'**
  String orderLineVip(String item);

  /// No description provided for @orderLineHoa.
  ///
  /// In en, this message translates to:
  /// **'The usual for this old man: one {item}.'**
  String orderLineHoa(String item);

  /// No description provided for @orderLineLinh.
  ///
  /// In en, this message translates to:
  /// **'Eee, {item}! Make it extra cute, please!'**
  String orderLineLinh(String item);

  /// No description provided for @orderLineKenji.
  ///
  /// In en, this message translates to:
  /// **'Today feels like a day for {item}.'**
  String orderLineKenji(String item);

  /// No description provided for @fbAllGood.
  ///
  /// In en, this message translates to:
  /// **'Perfect! Just like I imagined!'**
  String get fbAllGood;

  /// No description provided for @fbMouldGood.
  ///
  /// In en, this message translates to:
  /// **'Such a cute shape!'**
  String get fbMouldGood;

  /// No description provided for @fbMixGood.
  ///
  /// In en, this message translates to:
  /// **'So soft and fluffy!'**
  String get fbMixGood;

  /// No description provided for @fbBakeGood.
  ///
  /// In en, this message translates to:
  /// **'Baked to golden perfection!'**
  String get fbBakeGood;

  /// No description provided for @fbFrostGood.
  ///
  /// In en, this message translates to:
  /// **'The frosting is so smooth!'**
  String get fbFrostGood;

  /// No description provided for @fbToppingGood.
  ///
  /// In en, this message translates to:
  /// **'The toppings are just right!'**
  String get fbToppingGood;

  /// No description provided for @fbBoxGood.
  ///
  /// In en, this message translates to:
  /// **'And it\'s packed so nicely!'**
  String get fbBoxGood;

  /// No description provided for @fbMouldWrong.
  ///
  /// In en, this message translates to:
  /// **'Hmm, the shape isn\'t what I expected.'**
  String get fbMouldWrong;

  /// No description provided for @fbMixUnder.
  ///
  /// In en, this message translates to:
  /// **'The texture is a bit lumpy.'**
  String get fbMixUnder;

  /// No description provided for @fbMixOver.
  ///
  /// In en, this message translates to:
  /// **'It\'s a little dense and tough.'**
  String get fbMixOver;

  /// No description provided for @fbBakeUnder.
  ///
  /// In en, this message translates to:
  /// **'It\'s still a bit gooey inside!'**
  String get fbBakeUnder;

  /// No description provided for @fbBakeBurnt.
  ///
  /// In en, this message translates to:
  /// **'Oops, it\'s a little burnt!'**
  String get fbBakeBurnt;

  /// No description provided for @fbFrostPatchy.
  ///
  /// In en, this message translates to:
  /// **'The frosting looks patchy.'**
  String get fbFrostPatchy;

  /// No description provided for @fbToppingMissing.
  ///
  /// In en, this message translates to:
  /// **'I think some toppings are missing.'**
  String get fbToppingMissing;

  /// No description provided for @fbToppingWrong.
  ///
  /// In en, this message translates to:
  /// **'Those aren\'t the toppings I asked for.'**
  String get fbToppingWrong;

  /// No description provided for @fbBoxWrong.
  ///
  /// In en, this message translates to:
  /// **'Hmm, that\'s not the right box.'**
  String get fbBoxWrong;

  /// No description provided for @stationMould.
  ///
  /// In en, this message translates to:
  /// **'Mould'**
  String get stationMould;

  /// No description provided for @stationMix.
  ///
  /// In en, this message translates to:
  /// **'Mixing'**
  String get stationMix;

  /// No description provided for @stationBake.
  ///
  /// In en, this message translates to:
  /// **'Baking'**
  String get stationBake;

  /// No description provided for @stationFrost.
  ///
  /// In en, this message translates to:
  /// **'Frosting'**
  String get stationFrost;

  /// No description provided for @stationTopping.
  ///
  /// In en, this message translates to:
  /// **'Toppings'**
  String get stationTopping;

  /// No description provided for @stationBox.
  ///
  /// In en, this message translates to:
  /// **'Boxing'**
  String get stationBox;

  /// No description provided for @hintMould.
  ///
  /// In en, this message translates to:
  /// **'Drag the right mould onto the tray'**
  String get hintMould;

  /// No description provided for @hintMix.
  ///
  /// In en, this message translates to:
  /// **'Swirl around the bowl and stop in the green zone'**
  String get hintMix;

  /// No description provided for @hintBake.
  ///
  /// In en, this message translates to:
  /// **'Hold to bake, release in the golden zone'**
  String get hintBake;

  /// No description provided for @hintFrost.
  ///
  /// In en, this message translates to:
  /// **'Trace the dotted line to frost the cake'**
  String get hintFrost;

  /// No description provided for @hintTopping.
  ///
  /// In en, this message translates to:
  /// **'Drag the toppings onto the cake'**
  String get hintTopping;

  /// No description provided for @hintBox.
  ///
  /// In en, this message translates to:
  /// **'Drag the treat into the right box'**
  String get hintBox;

  /// No description provided for @gameStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current}/{total}'**
  String gameStepProgress(int current, int total);

  /// No description provided for @gameHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get gameHold;

  /// No description provided for @gameTapToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap a topping to remove it'**
  String get gameTapToRemove;

  /// No description provided for @gameWrongMould.
  ///
  /// In en, this message translates to:
  /// **'Not this one!'**
  String get gameWrongMould;

  /// No description provided for @gameTutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gameTutorialGotIt;

  /// No description provided for @mouldCupcakeLiner.
  ///
  /// In en, this message translates to:
  /// **'Cupcake liner'**
  String get mouldCupcakeLiner;

  /// No description provided for @mouldMuffinCup.
  ///
  /// In en, this message translates to:
  /// **'Muffin cup'**
  String get mouldMuffinCup;

  /// No description provided for @mouldTartShell.
  ///
  /// In en, this message translates to:
  /// **'Tart shell'**
  String get mouldTartShell;

  /// No description provided for @mouldRoundPan.
  ///
  /// In en, this message translates to:
  /// **'Round pan'**
  String get mouldRoundPan;

  /// No description provided for @mouldMacaronMat.
  ///
  /// In en, this message translates to:
  /// **'Macaron mat'**
  String get mouldMacaronMat;

  /// No description provided for @mouldSpringformPan.
  ///
  /// In en, this message translates to:
  /// **'Springform pan'**
  String get mouldSpringformPan;

  /// No description provided for @mouldTallPan.
  ///
  /// In en, this message translates to:
  /// **'Tall layer pan'**
  String get mouldTallPan;

  /// No description provided for @mouldPastryTray.
  ///
  /// In en, this message translates to:
  /// **'Pastry tray'**
  String get mouldPastryTray;

  /// No description provided for @mouldShellMould.
  ///
  /// In en, this message translates to:
  /// **'Shell mould'**
  String get mouldShellMould;

  /// No description provided for @mouldEclairTray.
  ///
  /// In en, this message translates to:
  /// **'Éclair tray'**
  String get mouldEclairTray;

  /// No description provided for @mouldPiePan.
  ///
  /// In en, this message translates to:
  /// **'Pie dish'**
  String get mouldPiePan;

  /// No description provided for @mouldMooncakeMould.
  ///
  /// In en, this message translates to:
  /// **'Mooncake press'**
  String get mouldMooncakeMould;

  /// No description provided for @mouldLogPan.
  ///
  /// In en, this message translates to:
  /// **'Swiss roll pan'**
  String get mouldLogPan;

  /// No description provided for @batterVanilla.
  ///
  /// In en, this message translates to:
  /// **'Vanilla batter'**
  String get batterVanilla;

  /// No description provided for @batterChocolate.
  ///
  /// In en, this message translates to:
  /// **'Chocolate batter'**
  String get batterChocolate;

  /// No description provided for @batterRedVelvet.
  ///
  /// In en, this message translates to:
  /// **'Red velvet batter'**
  String get batterRedVelvet;

  /// No description provided for @batterMatcha.
  ///
  /// In en, this message translates to:
  /// **'Matcha batter'**
  String get batterMatcha;

  /// No description provided for @batterButter.
  ///
  /// In en, this message translates to:
  /// **'Butter pastry'**
  String get batterButter;

  /// No description provided for @batterAlmond.
  ///
  /// In en, this message translates to:
  /// **'Almond meringue'**
  String get batterAlmond;

  /// No description provided for @batterCheese.
  ///
  /// In en, this message translates to:
  /// **'Cheesecake batter'**
  String get batterCheese;

  /// No description provided for @batterLaminated.
  ///
  /// In en, this message translates to:
  /// **'Laminated dough'**
  String get batterLaminated;

  /// No description provided for @batterChoux.
  ///
  /// In en, this message translates to:
  /// **'Choux pastry'**
  String get batterChoux;

  /// No description provided for @batterMooncake.
  ///
  /// In en, this message translates to:
  /// **'Mooncake crust'**
  String get batterMooncake;

  /// No description provided for @frostingVanillaCream.
  ///
  /// In en, this message translates to:
  /// **'Vanilla cream'**
  String get frostingVanillaCream;

  /// No description provided for @frostingChocolateGanache.
  ///
  /// In en, this message translates to:
  /// **'Chocolate ganache'**
  String get frostingChocolateGanache;

  /// No description provided for @frostingStrawberryCream.
  ///
  /// In en, this message translates to:
  /// **'Strawberry cream'**
  String get frostingStrawberryCream;

  /// No description provided for @frostingMatchaCream.
  ///
  /// In en, this message translates to:
  /// **'Matcha cream'**
  String get frostingMatchaCream;

  /// No description provided for @frostingCreamCheese.
  ///
  /// In en, this message translates to:
  /// **'Cream cheese'**
  String get frostingCreamCheese;

  /// No description provided for @frostingCustard.
  ///
  /// In en, this message translates to:
  /// **'Egg custard'**
  String get frostingCustard;

  /// No description provided for @frostingButterGlaze.
  ///
  /// In en, this message translates to:
  /// **'Egg wash glaze'**
  String get frostingButterGlaze;

  /// No description provided for @frostingAppleFilling.
  ///
  /// In en, this message translates to:
  /// **'Apple filling'**
  String get frostingAppleFilling;

  /// No description provided for @frostingLotusPaste.
  ///
  /// In en, this message translates to:
  /// **'Lotus paste'**
  String get frostingLotusPaste;

  /// No description provided for @toppingSprinkles.
  ///
  /// In en, this message translates to:
  /// **'Sprinkles'**
  String get toppingSprinkles;

  /// No description provided for @toppingStrawberry.
  ///
  /// In en, this message translates to:
  /// **'Strawberry'**
  String get toppingStrawberry;

  /// No description provided for @toppingCherry.
  ///
  /// In en, this message translates to:
  /// **'Cherry'**
  String get toppingCherry;

  /// No description provided for @toppingChocolateChips.
  ///
  /// In en, this message translates to:
  /// **'Chocolate chips'**
  String get toppingChocolateChips;

  /// No description provided for @toppingBlueberry.
  ///
  /// In en, this message translates to:
  /// **'Blueberry'**
  String get toppingBlueberry;

  /// No description provided for @toppingMintLeaf.
  ///
  /// In en, this message translates to:
  /// **'Mint leaf'**
  String get toppingMintLeaf;

  /// No description provided for @toppingSugarPearl.
  ///
  /// In en, this message translates to:
  /// **'Sugar pearls'**
  String get toppingSugarPearl;

  /// No description provided for @toppingCandle.
  ///
  /// In en, this message translates to:
  /// **'Candle'**
  String get toppingCandle;

  /// No description provided for @toppingAlmondFlakes.
  ///
  /// In en, this message translates to:
  /// **'Almond flakes'**
  String get toppingAlmondFlakes;

  /// No description provided for @toppingPowderedSugar.
  ///
  /// In en, this message translates to:
  /// **'Powdered sugar'**
  String get toppingPowderedSugar;

  /// No description provided for @toppingKiwi.
  ///
  /// In en, this message translates to:
  /// **'Kiwi'**
  String get toppingKiwi;

  /// No description provided for @toppingSesame.
  ///
  /// In en, this message translates to:
  /// **'Sesame seeds'**
  String get toppingSesame;

  /// No description provided for @toppingMeringueMushroom.
  ///
  /// In en, this message translates to:
  /// **'Meringue mushroom'**
  String get toppingMeringueMushroom;

  /// No description provided for @boxSmall.
  ///
  /// In en, this message translates to:
  /// **'Small box'**
  String get boxSmall;

  /// No description provided for @boxCake.
  ///
  /// In en, this message translates to:
  /// **'Cake box'**
  String get boxCake;

  /// No description provided for @boxGift.
  ///
  /// In en, this message translates to:
  /// **'Gift box'**
  String get boxGift;

  /// No description provided for @recipeCupcakeVanilla.
  ///
  /// In en, this message translates to:
  /// **'Vanilla cupcake'**
  String get recipeCupcakeVanilla;

  /// No description provided for @recipeCupcakeVanillaDesc.
  ///
  /// In en, this message translates to:
  /// **'Fluffy vanilla sponge with a cloud of cream.'**
  String get recipeCupcakeVanillaDesc;

  /// No description provided for @recipeCupcakeChocolate.
  ///
  /// In en, this message translates to:
  /// **'Chocolate cupcake'**
  String get recipeCupcakeChocolate;

  /// No description provided for @recipeCupcakeChocolateDesc.
  ///
  /// In en, this message translates to:
  /// **'Rich cocoa crumb and glossy ganache.'**
  String get recipeCupcakeChocolateDesc;

  /// No description provided for @recipeMuffinBlueberry.
  ///
  /// In en, this message translates to:
  /// **'Blueberry muffin'**
  String get recipeMuffinBlueberry;

  /// No description provided for @recipeMuffinBlueberryDesc.
  ///
  /// In en, this message translates to:
  /// **'A golden muffin bursting with berries.'**
  String get recipeMuffinBlueberryDesc;

  /// No description provided for @recipeEggTart.
  ///
  /// In en, this message translates to:
  /// **'Egg tart'**
  String get recipeEggTart;

  /// No description provided for @recipeEggTartDesc.
  ///
  /// In en, this message translates to:
  /// **'Flaky shell, silky custard. Grandma\'s favorite.'**
  String get recipeEggTartDesc;

  /// No description provided for @recipeStrawberryCake.
  ///
  /// In en, this message translates to:
  /// **'Strawberry cake'**
  String get recipeStrawberryCake;

  /// No description provided for @recipeStrawberryCakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft layers with fresh strawberry cream.'**
  String get recipeStrawberryCakeDesc;

  /// No description provided for @recipeMacaron.
  ///
  /// In en, this message translates to:
  /// **'Macaron'**
  String get recipeMacaron;

  /// No description provided for @recipeMacaronDesc.
  ///
  /// In en, this message translates to:
  /// **'Crisp almond shells with a sweet filling.'**
  String get recipeMacaronDesc;

  /// No description provided for @recipeRedVelvetCupcake.
  ///
  /// In en, this message translates to:
  /// **'Red velvet cupcake'**
  String get recipeRedVelvetCupcake;

  /// No description provided for @recipeRedVelvetCupcakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Velvety red crumb with tangy cream cheese.'**
  String get recipeRedVelvetCupcakeDesc;

  /// No description provided for @recipeMatchaCake.
  ///
  /// In en, this message translates to:
  /// **'Matcha cake'**
  String get recipeMatchaCake;

  /// No description provided for @recipeMatchaCakeDesc.
  ///
  /// In en, this message translates to:
  /// **'A gentle green tea cake, not too sweet.'**
  String get recipeMatchaCakeDesc;

  /// No description provided for @recipeCheesecake.
  ///
  /// In en, this message translates to:
  /// **'Cheesecake'**
  String get recipeCheesecake;

  /// No description provided for @recipeCheesecakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Creamy, rich, and baked low and slow.'**
  String get recipeCheesecakeDesc;

  /// No description provided for @recipeBirthdayCake.
  ///
  /// In en, this message translates to:
  /// **'Birthday layer cake'**
  String get recipeBirthdayCake;

  /// No description provided for @recipeBirthdayCakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Tall, festive, and made for wishes.'**
  String get recipeBirthdayCakeDesc;

  /// No description provided for @recipeCroissant.
  ///
  /// In en, this message translates to:
  /// **'Croissant'**
  String get recipeCroissant;

  /// No description provided for @recipeCroissantDesc.
  ///
  /// In en, this message translates to:
  /// **'Buttery, flaky layers rolled into a golden crescent.'**
  String get recipeCroissantDesc;

  /// No description provided for @recipePainAuChocolat.
  ///
  /// In en, this message translates to:
  /// **'Pain au chocolat'**
  String get recipePainAuChocolat;

  /// No description provided for @recipePainAuChocolatDesc.
  ///
  /// In en, this message translates to:
  /// **'Crisp pastry hugging two bars of dark chocolate.'**
  String get recipePainAuChocolatDesc;

  /// No description provided for @recipeMadeleine.
  ///
  /// In en, this message translates to:
  /// **'Madeleine'**
  String get recipeMadeleine;

  /// No description provided for @recipeMadeleineDesc.
  ///
  /// In en, this message translates to:
  /// **'Little shell cakes, warm and lemony.'**
  String get recipeMadeleineDesc;

  /// No description provided for @recipeEclair.
  ///
  /// In en, this message translates to:
  /// **'Éclair'**
  String get recipeEclair;

  /// No description provided for @recipeEclairDesc.
  ///
  /// In en, this message translates to:
  /// **'Light choux filled with custard, topped with ganache.'**
  String get recipeEclairDesc;

  /// No description provided for @recipeFruitTart.
  ///
  /// In en, this message translates to:
  /// **'Fruit tart'**
  String get recipeFruitTart;

  /// No description provided for @recipeFruitTartDesc.
  ///
  /// In en, this message translates to:
  /// **'Custard tart crowned with jewel-bright fruit.'**
  String get recipeFruitTartDesc;

  /// No description provided for @recipeApplePie.
  ///
  /// In en, this message translates to:
  /// **'Apple pie'**
  String get recipeApplePie;

  /// No description provided for @recipeApplePieDesc.
  ///
  /// In en, this message translates to:
  /// **'Spiced apples under a golden lattice crust.'**
  String get recipeApplePieDesc;

  /// No description provided for @recipeMooncake.
  ///
  /// In en, this message translates to:
  /// **'Mooncake'**
  String get recipeMooncake;

  /// No description provided for @recipeMooncakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Lotus paste in a patterned golden crust, for the festival.'**
  String get recipeMooncakeDesc;

  /// No description provided for @recipeBucheDeNoel.
  ///
  /// In en, this message translates to:
  /// **'Bûche de Noël'**
  String get recipeBucheDeNoel;

  /// No description provided for @recipeBucheDeNoelDesc.
  ///
  /// In en, this message translates to:
  /// **'A chocolate Yule log with meringue mushrooms.'**
  String get recipeBucheDeNoelDesc;

  /// No description provided for @charMai.
  ///
  /// In en, this message translates to:
  /// **'Mai'**
  String get charMai;

  /// No description provided for @charHoa.
  ///
  /// In en, this message translates to:
  /// **'Mr. Hoa'**
  String get charHoa;

  /// No description provided for @charLinh.
  ///
  /// In en, this message translates to:
  /// **'Linh'**
  String get charLinh;

  /// No description provided for @charKenji.
  ///
  /// In en, this message translates to:
  /// **'Kenji'**
  String get charKenji;

  /// No description provided for @charRosa.
  ///
  /// In en, this message translates to:
  /// **'Mrs. Rosa'**
  String get charRosa;

  /// No description provided for @storyTapToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get storyTapToContinue;

  /// No description provided for @storySkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get storySkip;

  /// No description provided for @storyPrologue1.
  ///
  /// In en, this message translates to:
  /// **'A sleepy seaside town. A little bakery with a faded sign: Sugarleaf.'**
  String get storyPrologue1;

  /// No description provided for @storyPrologue2.
  ///
  /// In en, this message translates to:
  /// **'Grandma, I\'m home... I\'ll take care of your bakery now.'**
  String get storyPrologue2;

  /// No description provided for @storyPrologue3.
  ///
  /// In en, this message translates to:
  /// **'Her recipe book! But so many pages are missing...'**
  String get storyPrologue3;

  /// No description provided for @storyPrologue4.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start with something simple. Cupcakes!'**
  String get storyPrologue4;

  /// No description provided for @storyHoa1Line1.
  ///
  /// In en, this message translates to:
  /// **'The lights are on at Sugarleaf again. You must be little Mai.'**
  String get storyHoa1Line1;

  /// No description provided for @storyHoa1Line2.
  ///
  /// In en, this message translates to:
  /// **'Yes! Did you know my grandma?'**
  String get storyHoa1Line2;

  /// No description provided for @storyHoa1Line3.
  ///
  /// In en, this message translates to:
  /// **'Every Sunday for forty years. Her egg tarts... I still miss them.'**
  String get storyHoa1Line3;

  /// No description provided for @storyHoa1Line4.
  ///
  /// In en, this message translates to:
  /// **'Then I\'ll learn to make them for you. I promise!'**
  String get storyHoa1Line4;

  /// No description provided for @storyLinh1Line1.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m Linh. I study at the art school up the hill.'**
  String get storyLinh1Line1;

  /// No description provided for @storyLinh1Line2.
  ///
  /// In en, this message translates to:
  /// **'I draw every pastry I eat. Your shop is SO cute!'**
  String get storyLinh1Line2;

  /// No description provided for @storyLinh1Line3.
  ///
  /// In en, this message translates to:
  /// **'Then I\'d better make them pretty for you!'**
  String get storyLinh1Line3;

  /// No description provided for @storyHoa2Line1.
  ///
  /// In en, this message translates to:
  /// **'Mr. Hoa! I found the egg tart page today.'**
  String get storyHoa2Line1;

  /// No description provided for @storyHoa2Line2.
  ///
  /// In en, this message translates to:
  /// **'Then today is a good day. Let\'s see if your hands remember her.'**
  String get storyHoa2Line2;

  /// No description provided for @storyHoa2Line3.
  ///
  /// In en, this message translates to:
  /// **'I\'ll do my best!'**
  String get storyHoa2Line3;

  /// No description provided for @storyKenji1Line1.
  ///
  /// In en, this message translates to:
  /// **'Hello. I\'m Kenji. I travel and photograph small towns.'**
  String get storyKenji1Line1;

  /// No description provided for @storyKenji1Line2.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure what I want. Something that feels like a sunny morning?'**
  String get storyKenji1Line2;

  /// No description provided for @storyKenji1Line3.
  ///
  /// In en, this message translates to:
  /// **'A sunny morning... Strawberry cake, I think!'**
  String get storyKenji1Line3;

  /// No description provided for @storyLinh2Line1.
  ///
  /// In en, this message translates to:
  /// **'Mai, can you make macarons? They\'re my favorite thing to draw!'**
  String get storyLinh2Line1;

  /// No description provided for @storyLinh2Line2.
  ///
  /// In en, this message translates to:
  /// **'They\'re tricky... but let\'s try together.'**
  String get storyLinh2Line2;

  /// No description provided for @storyLinh2Line3.
  ///
  /// In en, this message translates to:
  /// **'Yay! I\'ll sketch while you bake!'**
  String get storyLinh2Line3;

  /// No description provided for @storyKenji2Line1.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow I\'ll climb the lighthouse at dawn. I need some courage.'**
  String get storyKenji2Line1;

  /// No description provided for @storyKenji2Line2.
  ///
  /// In en, this message translates to:
  /// **'Courage tastes bold and a little sweet. Red velvet!'**
  String get storyKenji2Line2;

  /// No description provided for @storyKenji2Line3.
  ///
  /// In en, this message translates to:
  /// **'You read moods like recipes.'**
  String get storyKenji2Line3;

  /// No description provided for @storyHoa3Line1.
  ///
  /// In en, this message translates to:
  /// **'I brought something. She gave me this page years ago, for safekeeping.'**
  String get storyHoa3Line1;

  /// No description provided for @storyHoa3Line2.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s handwriting... Thank you, Mr. Hoa.'**
  String get storyHoa3Line2;

  /// No description provided for @storyHoa3Line3.
  ///
  /// In en, this message translates to:
  /// **'It belongs in this kitchen. Just like you.'**
  String get storyHoa3Line3;

  /// No description provided for @storyLinh3Line1.
  ///
  /// In en, this message translates to:
  /// **'Look! My drawing of your shop won a prize at school!'**
  String get storyLinh3Line1;

  /// No description provided for @storyLinh3Line2.
  ///
  /// In en, this message translates to:
  /// **'It\'s beautiful, Linh! Can I hang it by the window?'**
  String get storyLinh3Line2;

  /// No description provided for @storyLinh3Line3.
  ///
  /// In en, this message translates to:
  /// **'Only if we celebrate with a matcha cake!'**
  String get storyLinh3Line3;

  /// No description provided for @storyKenji3Line1.
  ///
  /// In en, this message translates to:
  /// **'My photos of this town will be shown in a gallery in Tokyo.'**
  String get storyKenji3Line1;

  /// No description provided for @storyKenji3Line2.
  ///
  /// In en, this message translates to:
  /// **'I want to remember it with something calm and rich.'**
  String get storyKenji3Line2;

  /// No description provided for @storyKenji3Line3.
  ///
  /// In en, this message translates to:
  /// **'Then cheesecake, with blueberries like the sea.'**
  String get storyKenji3Line3;

  /// No description provided for @storyFinaleLine1.
  ///
  /// In en, this message translates to:
  /// **'Mr. Hoa, Linh, Kenji... this bakery feels alive again.'**
  String get storyFinaleLine1;

  /// No description provided for @storyFinaleLine2.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s book still has empty pages. I\'ll fill them, one by one.'**
  String get storyFinaleLine2;

  /// No description provided for @storyCh1End1.
  ///
  /// In en, this message translates to:
  /// **'The first pages of Grandma\'s book are filled again.'**
  String get storyCh1End1;

  /// No description provided for @storyCh1End2.
  ///
  /// In en, this message translates to:
  /// **'The town is starting to know my cupcakes… Time to get busier!'**
  String get storyCh1End2;

  /// No description provided for @storyCh2End3.
  ///
  /// In en, this message translates to:
  /// **'And just past the back door, a new chapter is waiting…'**
  String get storyCh2End3;

  /// No description provided for @storyCh3Open1.
  ///
  /// In en, this message translates to:
  /// **'Behind the bakery, Grandma\'s garden has grown wild with mint and climbing roses.'**
  String get storyCh3Open1;

  /// No description provided for @storyCh3Open2.
  ///
  /// In en, this message translates to:
  /// **'What\'s hiding under all these leaves? A little garden shed!'**
  String get storyCh3Open2;

  /// No description provided for @storyCh3Open3.
  ///
  /// In en, this message translates to:
  /// **'A page from Grandma\'s book, tucked in a flowerpot: \"Croissants. Fold the butter in, and be patient.\"'**
  String get storyCh3Open3;

  /// No description provided for @storyCh3Open4.
  ///
  /// In en, this message translates to:
  /// **'Mai brushes off the soil and smiles. The garden kept Grandma\'s secret safe.'**
  String get storyCh3Open4;

  /// No description provided for @storyMochi1Line1.
  ///
  /// In en, this message translates to:
  /// **'Rain drums on the awning. Beneath it, a small grey cat sits very, very still.'**
  String get storyMochi1Line1;

  /// No description provided for @storyMochi1Line2.
  ///
  /// In en, this message translates to:
  /// **'Oh! You\'re soaked, little one. Come in, the oven is warm.'**
  String get storyMochi1Line2;

  /// No description provided for @storyMochi1Line3.
  ///
  /// In en, this message translates to:
  /// **'The cat curls up by the counter and purrs like a tiny engine.'**
  String get storyMochi1Line3;

  /// No description provided for @storyMochi1Line4.
  ///
  /// In en, this message translates to:
  /// **'I\'ll call you Mochi. Come by whenever it rains, okay?'**
  String get storyMochi1Line4;

  /// No description provided for @storyKenji4Line1.
  ///
  /// In en, this message translates to:
  /// **'Today I\'d like something… for a day when you miss home.'**
  String get storyKenji4Line1;

  /// No description provided for @storyKenji4Line2.
  ///
  /// In en, this message translates to:
  /// **'Something small and warm, then. Like a hug from far away.'**
  String get storyKenji4Line2;

  /// No description provided for @storyKenji4Line3.
  ///
  /// In en, this message translates to:
  /// **'A madeleine. Grandma said one bite can bring back a whole afternoon.'**
  String get storyKenji4Line3;

  /// No description provided for @storyKenji4Line4.
  ///
  /// In en, this message translates to:
  /// **'Then I\'ll eat it slowly.'**
  String get storyKenji4Line4;

  /// No description provided for @storyCh4Open1.
  ///
  /// In en, this message translates to:
  /// **'Upstairs, dust dances in the light of the little round window.'**
  String get storyCh4Open1;

  /// No description provided for @storyCh4Open2.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s old letter box… she kept every note her customers ever wrote.'**
  String get storyCh4Open2;

  /// No description provided for @storyCh4Open3.
  ///
  /// In en, this message translates to:
  /// **'And two more pages: éclairs, and a fruit tart \"for sunny days\".'**
  String get storyCh4Open3;

  /// No description provided for @storyCh4Open4.
  ///
  /// In en, this message translates to:
  /// **'Mai tucks the pages into the book. It feels a little heavier now, in the best way.'**
  String get storyCh4Open4;

  /// No description provided for @storyRosa1Line1.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, dear. Your grandmother baked my wedding cake, you know.'**
  String get storyRosa1Line1;

  /// No description provided for @storyRosa1Line2.
  ///
  /// In en, this message translates to:
  /// **'Now my granddaughter is getting married, right by the sea.'**
  String get storyRosa1Line2;

  /// No description provided for @storyRosa1Line3.
  ///
  /// In en, this message translates to:
  /// **'Mrs. Rosa, that\'s wonderful news!'**
  String get storyRosa1Line3;

  /// No description provided for @storyRosa1Line4.
  ///
  /// In en, this message translates to:
  /// **'When the day comes, I\'ll order her cake from you. Your grandmother would like that.'**
  String get storyRosa1Line4;

  /// No description provided for @storyLinh4Line1.
  ///
  /// In en, this message translates to:
  /// **'Mai! The school fair is next week, and I signed us up for a stall!'**
  String get storyLinh4Line1;

  /// No description provided for @storyLinh4Line2.
  ///
  /// In en, this message translates to:
  /// **'Us? What are we selling?'**
  String get storyLinh4Line2;

  /// No description provided for @storyLinh4Line3.
  ///
  /// In en, this message translates to:
  /// **'Apple pie! The whole school smells of cinnamon when someone brings one.'**
  String get storyLinh4Line3;

  /// No description provided for @storyLinh4Line4.
  ///
  /// In en, this message translates to:
  /// **'Then we\'ll bake the prettiest lattice in town. Grandma\'s way.'**
  String get storyLinh4Line4;

  /// No description provided for @storyCh5Open1.
  ///
  /// In en, this message translates to:
  /// **'Lanterns are going up all along the harbor. The seaside festival is almost here.'**
  String get storyCh5Open1;

  /// No description provided for @storyCh5Open2.
  ///
  /// In en, this message translates to:
  /// **'The whole town is decorating… and everyone keeps asking about mooncakes.'**
  String get storyCh5Open2;

  /// No description provided for @storyCh5Open3.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s book has a page for those too: lotus paste and a little flower press.'**
  String get storyCh5Open3;

  /// No description provided for @storyCh5Open4.
  ///
  /// In en, this message translates to:
  /// **'Tonight the bakery will glow like one more lantern by the sea.'**
  String get storyCh5Open4;

  /// No description provided for @storyHoa4Line1.
  ///
  /// In en, this message translates to:
  /// **'Every winter, your grandmother baked a chocolate log for the whole street.'**
  String get storyHoa4Line1;

  /// No description provided for @storyHoa4Line2.
  ///
  /// In en, this message translates to:
  /// **'Little meringue mushrooms, a dusting of sugar snow… the children adored it.'**
  String get storyHoa4Line2;

  /// No description provided for @storyHoa4Line3.
  ///
  /// In en, this message translates to:
  /// **'A bûche de Noël? I\'ve never made one.'**
  String get storyHoa4Line3;

  /// No description provided for @storyHoa4Line4.
  ///
  /// In en, this message translates to:
  /// **'You will. Her hands are in yours now, I can tell.'**
  String get storyHoa4Line4;

  /// No description provided for @storyRosa2Line1.
  ///
  /// In en, this message translates to:
  /// **'The wedding is today, dear. Is the cake ready?'**
  String get storyRosa2Line1;

  /// No description provided for @storyRosa2Line2.
  ///
  /// In en, this message translates to:
  /// **'Almost. Three tiers, wrapped as a gift, just like the one Grandma made for you.'**
  String get storyRosa2Line2;

  /// No description provided for @storyRosa2Line3.
  ///
  /// In en, this message translates to:
  /// **'Oh… my granddaughter will cry. I might cry too.'**
  String get storyRosa2Line3;

  /// No description provided for @storyRosa2Line4.
  ///
  /// In en, this message translates to:
  /// **'Then let\'s make it worth every happy tear.'**
  String get storyRosa2Line4;

  /// No description provided for @storyFinale2Line1.
  ///
  /// In en, this message translates to:
  /// **'The last empty page of Grandma\'s book is finally filled.'**
  String get storyFinale2Line1;

  /// No description provided for @storyFinale2Line2.
  ///
  /// In en, this message translates to:
  /// **'The bakery is warm and busy again, full of friends and their stories.'**
  String get storyFinale2Line2;

  /// No description provided for @storyFinale2Line3.
  ///
  /// In en, this message translates to:
  /// **'But a good bakery never runs out of stories… there are many more to come.'**
  String get storyFinale2Line3;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Day {day} complete!'**
  String summaryTitle(int day);

  /// No description provided for @summaryCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers served'**
  String get summaryCustomers;

  /// No description provided for @summaryAvgStars.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get summaryAvgStars;

  /// No description provided for @summaryRevenue.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get summaryRevenue;

  /// No description provided for @summaryTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get summaryTips;

  /// No description provided for @summaryCosts.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get summaryCosts;

  /// No description provided for @summaryNet.
  ///
  /// In en, this message translates to:
  /// **'Total earned'**
  String get summaryNet;

  /// No description provided for @summaryXp.
  ///
  /// In en, this message translates to:
  /// **'XP gained'**
  String get summaryXp;

  /// No description provided for @summaryDayBonusXp.
  ///
  /// In en, this message translates to:
  /// **'Shift bonus +{xp} XP'**
  String summaryDayBonusXp(int xp);

  /// Line in the day summary shown only on rainy days
  ///
  /// In en, this message translates to:
  /// **'A rainy day — Mochi dropped by'**
  String get summaryRainyDay;

  /// No description provided for @summaryDouble.
  ///
  /// In en, this message translates to:
  /// **'Double coins (watch ad)'**
  String get summaryDouble;

  /// No description provided for @summaryDoubled.
  ///
  /// In en, this message translates to:
  /// **'Coins doubled!'**
  String get summaryDoubled;

  /// No description provided for @summaryLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level up! Mai is now level {level}'**
  String summaryLevelUp(int level);

  /// No description provided for @summaryNewUnlocks.
  ///
  /// In en, this message translates to:
  /// **'New unlocks'**
  String get summaryNewUnlocks;

  /// No description provided for @unlockRecipe.
  ///
  /// In en, this message translates to:
  /// **'New recipe: {name}'**
  String unlockRecipe(String name);

  /// No description provided for @unlockTopping.
  ///
  /// In en, this message translates to:
  /// **'New topping: {name}'**
  String unlockTopping(String name);

  /// No description provided for @unlockVipGuests.
  ///
  /// In en, this message translates to:
  /// **'VIP guests start visiting!'**
  String get unlockVipGuests;

  /// No description provided for @unlockUpgrades.
  ///
  /// In en, this message translates to:
  /// **'New upgrades available'**
  String get unlockUpgrades;

  /// No description provided for @unlockDecor.
  ///
  /// In en, this message translates to:
  /// **'New decorations available'**
  String get unlockDecor;

  /// No description provided for @unlockMoreCustomers.
  ///
  /// In en, this message translates to:
  /// **'More customers each day'**
  String get unlockMoreCustomers;

  /// No description provided for @upgradeWhisk.
  ///
  /// In en, this message translates to:
  /// **'Whisk'**
  String get upgradeWhisk;

  /// No description provided for @upgradeWhiskDesc.
  ///
  /// In en, this message translates to:
  /// **'A bigger green zone when mixing'**
  String get upgradeWhiskDesc;

  /// No description provided for @upgradePipingBag.
  ///
  /// In en, this message translates to:
  /// **'Piping bag'**
  String get upgradePipingBag;

  /// No description provided for @upgradePipingBagDesc.
  ///
  /// In en, this message translates to:
  /// **'A thicker frosting stroke'**
  String get upgradePipingBagDesc;

  /// No description provided for @upgradeTongs.
  ///
  /// In en, this message translates to:
  /// **'Pastry tongs'**
  String get upgradeTongs;

  /// No description provided for @upgradeTongsDesc.
  ///
  /// In en, this message translates to:
  /// **'Toppings land on the cake more easily'**
  String get upgradeTongsDesc;

  /// No description provided for @decorSlotWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get decorSlotWallpaper;

  /// No description provided for @decorSlotFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get decorSlotFloor;

  /// No description provided for @decorSlotCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get decorSlotCounter;

  /// No description provided for @decorSlotWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get decorSlotWindow;

  /// No description provided for @decorSlotPlant.
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get decorSlotPlant;

  /// No description provided for @decorDefault.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get decorDefault;

  /// No description provided for @decorWallpaperStripes.
  ///
  /// In en, this message translates to:
  /// **'Cream stripes'**
  String get decorWallpaperStripes;

  /// No description provided for @decorWallpaperFloral.
  ///
  /// In en, this message translates to:
  /// **'Floral wallpaper'**
  String get decorWallpaperFloral;

  /// No description provided for @decorFloorCheckered.
  ///
  /// In en, this message translates to:
  /// **'Checkered tiles'**
  String get decorFloorCheckered;

  /// No description provided for @decorFloorHerringbone.
  ///
  /// In en, this message translates to:
  /// **'Herringbone wood'**
  String get decorFloorHerringbone;

  /// No description provided for @decorCounterFlowers.
  ///
  /// In en, this message translates to:
  /// **'Flower vase'**
  String get decorCounterFlowers;

  /// No description provided for @decorCounterCakeStand.
  ///
  /// In en, this message translates to:
  /// **'Tiered cake stand'**
  String get decorCounterCakeStand;

  /// No description provided for @decorWindowCurtains.
  ///
  /// In en, this message translates to:
  /// **'Lace curtains'**
  String get decorWindowCurtains;

  /// No description provided for @decorWindowSeaView.
  ///
  /// In en, this message translates to:
  /// **'Sea view window'**
  String get decorWindowSeaView;

  /// No description provided for @decorPlantFern.
  ///
  /// In en, this message translates to:
  /// **'Fern'**
  String get decorPlantFern;

  /// No description provided for @decorPlantLemonTree.
  ///
  /// In en, this message translates to:
  /// **'Lemon tree'**
  String get decorPlantLemonTree;

  /// No description provided for @questsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get questsTitle;

  /// No description provided for @questServeCustomers.
  ///
  /// In en, this message translates to:
  /// **'Serve {count} customers'**
  String questServeCustomers(int count);

  /// No description provided for @questEarnStars.
  ///
  /// In en, this message translates to:
  /// **'Earn {count} stars'**
  String questEarnStars(int count);

  /// No description provided for @questPerfectBakes.
  ///
  /// In en, this message translates to:
  /// **'Get {count} perfect bakes'**
  String questPerfectBakes(int count);

  /// No description provided for @questFiveStarTreats.
  ///
  /// In en, this message translates to:
  /// **'Serve {count} five-star treats'**
  String questFiveStarTreats(int count);

  /// No description provided for @questEarnCoins.
  ///
  /// In en, this message translates to:
  /// **'Earn {count} coins'**
  String questEarnCoins(int count);

  /// No description provided for @questEarnTips.
  ///
  /// In en, this message translates to:
  /// **'Collect {count} coins in tips'**
  String questEarnTips(int count);

  /// No description provided for @questProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{target}'**
  String questProgress(int current, int target);

  /// No description provided for @questsResetHint.
  ///
  /// In en, this message translates to:
  /// **'New quests every day'**
  String get questsResetHint;

  /// No description provided for @questsAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done for today!'**
  String get questsAllDone;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily gift'**
  String get loginTitle;

  /// No description provided for @loginDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String loginDay(int day);

  /// No description provided for @loginComeBack.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for more!'**
  String get loginComeBack;

  /// No description provided for @storeSimulatedNotice.
  ///
  /// In en, this message translates to:
  /// **'Test store: purchases are simulated and no money is charged.'**
  String get storeSimulatedNotice;

  /// No description provided for @storeStarterPack.
  ///
  /// In en, this message translates to:
  /// **'Starter pack'**
  String get storeStarterPack;

  /// No description provided for @storeStarterPackDesc.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins + {gems} gems'**
  String storeStarterPackDesc(int coins, int gems);

  /// No description provided for @storePantryS.
  ///
  /// In en, this message translates to:
  /// **'Pantry pack S'**
  String get storePantryS;

  /// No description provided for @storePantryM.
  ///
  /// In en, this message translates to:
  /// **'Pantry pack M'**
  String get storePantryM;

  /// No description provided for @storePantryL.
  ///
  /// In en, this message translates to:
  /// **'Pantry pack L'**
  String get storePantryL;

  /// No description provided for @storePantryDesc.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins for ingredients'**
  String storePantryDesc(int coins);

  /// No description provided for @storeDecorSet.
  ///
  /// In en, this message translates to:
  /// **'Seaside decor set'**
  String get storeDecorSet;

  /// No description provided for @storeRemoveAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get storeRemoveAds;

  /// No description provided for @storeRemoveAdsDesc.
  ///
  /// In en, this message translates to:
  /// **'No more ads between days. Reward ads stay optional.'**
  String get storeRemoveAdsDesc;

  /// No description provided for @adsLimitReached.
  ///
  /// In en, this message translates to:
  /// **'No more ad rewards today'**
  String get adsLimitReached;

  /// No description provided for @adSimulatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad (simulated)'**
  String get adSimulatedTitle;

  /// No description provided for @adSimulatedBody.
  ///
  /// In en, this message translates to:
  /// **'A real ad will play here in the release version.'**
  String get adSimulatedBody;

  /// No description provided for @adSimulatedClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing in {seconds}s'**
  String adSimulatedClosing(int seconds);

  /// No description provided for @adRewardGranted.
  ///
  /// In en, this message translates to:
  /// **'Reward received!'**
  String get adRewardGranted;

  /// Toast shown when the player closes a rewarded ad before it finishes (daily ad limit not yet reached).
  ///
  /// In en, this message translates to:
  /// **'The ad didn\'t finish, so no reward this time.'**
  String get adNotCompleted;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsLanguageVi.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get settingsLanguageVi;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsResetData.
  ///
  /// In en, this message translates to:
  /// **'Reset game data'**
  String get settingsResetData;

  /// No description provided for @settingsResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress?'**
  String get settingsResetConfirmTitle;

  /// No description provided for @settingsResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Coins, level, Mai\'s hairstyle, the places you\'ve visited, your branches and staff will be erased. Language and sound are kept. This can\'t be undone.'**
  String get settingsResetConfirmBody;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Game data reset'**
  String get settingsResetDone;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsAlphaNote.
  ///
  /// In en, this message translates to:
  /// **'Alpha build. Thanks for playing!'**
  String get settingsAlphaNote;

  /// Level map: title of the notice card shown after the map animation when something new is unlocked.
  ///
  /// In en, this message translates to:
  /// **'New unlock!'**
  String get unlockNoticeTitle;

  /// Level map: line under the unlock notice title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Something new is ready for your bakery.} other{{count} new things are ready for your bakery.}}'**
  String unlockNoticeBody(int count);

  /// Unlock notice: button that opens the Upgrades screen on the right tab/card. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Take a look'**
  String get unlockNoticeView;

  /// Unlock notice: button that closes the card (the red dot on the Upgrades button stays). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get unlockNoticeLater;

  /// Unlock notice: sub-line for an equipment item that reached a new tier.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier} unlocked'**
  String unlockNoticeTier(int tier);

  /// Unlock notice: end of the list when there are more than 3 items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more} other{+{count} more}}'**
  String unlockNoticeMore(int count);

  /// Away-income dialog: time away shorter than 1 hour.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String offlineDurationMinutes(int minutes);

  /// Away-income dialog: time away of whole hours (under 1 day).
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}}'**
  String offlineDurationHours(int hours);

  /// Away-income dialog: time away with hours and leftover minutes (under 1 day).
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String offlineDurationHoursMinutes(int hours, int minutes);

  /// Away-income dialog: time away of 1 day or more (rounded down).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{over a day} other{{days} days}}'**
  String offlineDurationDays(int days);

  /// Away-income dialog: button that doubles the coins by watching a rewarded ad (hidden when no ads are left today).
  ///
  /// In en, this message translates to:
  /// **'x2 (watch ad)'**
  String get offlineDouble;

  /// Opening scene: subtitle of scene 1 (morning kitchen).
  ///
  /// In en, this message translates to:
  /// **'One morning in a little seaside town…'**
  String get introLineKitchen;

  /// Opening scene: subtitle of scene 2 (glass cake case).
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s little bakery is still right where it was.'**
  String get introLineCase;

  /// Opening scene: subtitle of scene 3 (shop door). Mai is the main character; Sugarleaf is the bakery name.
  ///
  /// In en, this message translates to:
  /// **'Mai is home — Sugarleaf opens its doors again!'**
  String get introLineDoor;

  /// Opening scene: word painted on the wooden door sign after it is flipped. One short line, shown in big letters.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get introSignOpen;

  /// Opening scene: screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Opening scene'**
  String get introSemantics;

  /// Settings: button that replays the opening scene (returns to Settings afterwards). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Replay opening'**
  String get settingsReplayIntro;

  /// No description provided for @charNora.
  ///
  /// In en, this message translates to:
  /// **'Nora'**
  String get charNora;

  /// No description provided for @charBao.
  ///
  /// In en, this message translates to:
  /// **'Bao'**
  String get charBao;

  /// No description provided for @charTheo.
  ///
  /// In en, this message translates to:
  /// **'Theo'**
  String get charTheo;

  /// No description provided for @npcSquirrel.
  ///
  /// In en, this message translates to:
  /// **'Squirrel'**
  String get npcSquirrel;

  /// No description provided for @npcHamster.
  ///
  /// In en, this message translates to:
  /// **'Hamster'**
  String get npcHamster;

  /// No description provided for @npcShiba.
  ///
  /// In en, this message translates to:
  /// **'Shiba'**
  String get npcShiba;

  /// No description provided for @npcBlackCat.
  ///
  /// In en, this message translates to:
  /// **'Black Cat'**
  String get npcBlackCat;

  /// No description provided for @npcWalrus.
  ///
  /// In en, this message translates to:
  /// **'Mr. Walrus'**
  String get npcWalrus;

  /// No description provided for @npcLion.
  ///
  /// In en, this message translates to:
  /// **'Mr. Lion'**
  String get npcLion;

  /// No description provided for @talkHoaOwlL1.
  ///
  /// In en, this message translates to:
  /// **'They say owls are night birds. Yet here I am at your door by five every morning.'**
  String get talkHoaOwlL1;

  /// No description provided for @talkHoaOwlL2.
  ///
  /// In en, this message translates to:
  /// **'But Mr. Hoa, we open at seven!'**
  String get talkHoaOwlL2;

  /// No description provided for @talkHoaOwlL3.
  ///
  /// In en, this message translates to:
  /// **'I know. Those two hours are for smelling the butter through the door.'**
  String get talkHoaOwlL3;

  /// No description provided for @talkHoaOwlC1.
  ///
  /// In en, this message translates to:
  /// **'I\'ll open early for you, then!'**
  String get talkHoaOwlC1;

  /// No description provided for @talkHoaOwlR1.
  ///
  /// In en, this message translates to:
  /// **'No, no. Waiting is half the flavour of an egg tart.'**
  String get talkHoaOwlR1;

  /// No description provided for @talkHoaOwlC2.
  ///
  /// In en, this message translates to:
  /// **'Then I\'ll bake so well you can smell it from home!'**
  String get talkHoaOwlC2;

  /// No description provided for @talkHoaOwlR2.
  ///
  /// In en, this message translates to:
  /// **'Then I\'d lose my excuse to wake up early. Very well, deal.'**
  String get talkHoaOwlR2;

  /// No description provided for @talkHoaOwlL4.
  ///
  /// In en, this message translates to:
  /// **'Then tomorrow, the first tart out of the oven is yours.'**
  String get talkHoaOwlL4;

  /// No description provided for @talkLinhSketchL1.
  ///
  /// In en, this message translates to:
  /// **'Mai, hold still! I\'m sketching you.'**
  String get talkLinhSketchL1;

  /// No description provided for @talkLinhSketchL2.
  ///
  /// In en, this message translates to:
  /// **'But I\'ve got flour all over my hair…'**
  String get talkLinhSketchL2;

  /// No description provided for @talkLinhSketchL3.
  ///
  /// In en, this message translates to:
  /// **'Done! Take a look.'**
  String get talkLinhSketchL3;

  /// No description provided for @talkLinhSketchL4.
  ///
  /// In en, this message translates to:
  /// **'Linh… why am I a steamed bun wearing an apron?'**
  String get talkLinhSketchL4;

  /// No description provided for @talkLinhSketchL5.
  ///
  /// In en, this message translates to:
  /// **'Because you\'re round, soft and warm. It\'s a compliment!'**
  String get talkLinhSketchL5;

  /// No description provided for @talkLinhSketchC1.
  ///
  /// In en, this message translates to:
  /// **'Then give me a bow!'**
  String get talkLinhSketchC1;

  /// No description provided for @talkLinhSketchR1.
  ///
  /// In en, this message translates to:
  /// **'Two bows! The cutest bun in town!'**
  String get talkLinhSketchR1;

  /// No description provided for @talkLinhSketchC2.
  ///
  /// In en, this message translates to:
  /// **'Can I hang it by the counter?'**
  String get talkLinhSketchC2;

  /// No description provided for @talkLinhSketchR2.
  ///
  /// In en, this message translates to:
  /// **'Really? Look, my ears just shot straight up!'**
  String get talkLinhSketchR2;

  /// No description provided for @talkKenjiCloudL1.
  ///
  /// In en, this message translates to:
  /// **'Today I feel like a cloud that meant to rain… then changed its mind.'**
  String get talkKenjiCloudL1;

  /// No description provided for @talkKenjiCloudL2.
  ///
  /// In en, this message translates to:
  /// **'A cloud that changed its mind… Let me think.'**
  String get talkKenjiCloudL2;

  /// No description provided for @talkKenjiCloudC1.
  ///
  /// In en, this message translates to:
  /// **'Matcha cake: a little bitter at first, then sweeter.'**
  String get talkKenjiCloudC1;

  /// No description provided for @talkKenjiCloudR1.
  ///
  /// In en, this message translates to:
  /// **'That\'s exactly the cloud. I\'ll photograph it before I eat.'**
  String get talkKenjiCloudR1;

  /// No description provided for @talkKenjiCloudC2.
  ///
  /// In en, this message translates to:
  /// **'A vanilla cupcake, white and fluffy like a cloud.'**
  String get talkKenjiCloudC2;

  /// No description provided for @talkKenjiCloudR2.
  ///
  /// In en, this message translates to:
  /// **'A bit… literal. But I like your honesty.'**
  String get talkKenjiCloudR2;

  /// No description provided for @talkKenjiCloudL3.
  ///
  /// In en, this message translates to:
  /// **'Every visit here, my film roll gets a little shorter.'**
  String get talkKenjiCloudL3;

  /// No description provided for @talkRosaSecretL1.
  ///
  /// In en, this message translates to:
  /// **'Do you know, dear, for sixty years I have eaten cake only with a silver fork.'**
  String get talkRosaSecretL1;

  /// No description provided for @talkRosaSecretL2.
  ///
  /// In en, this message translates to:
  /// **'Yes… but there\'s a dab of cream on the tip of your nose.'**
  String get talkRosaSecretL2;

  /// No description provided for @talkRosaSecretL3.
  ///
  /// In en, this message translates to:
  /// **'Hmm. The wind must have blown it there.'**
  String get talkRosaSecretL3;

  /// No description provided for @talkRosaSecretL4.
  ///
  /// In en, this message translates to:
  /// **'There\'s no wind indoors, though?'**
  String get talkRosaSecretL4;

  /// No description provided for @talkRosaSecretC1.
  ///
  /// In en, this message translates to:
  /// **'(Wink) I didn\'t see a thing.'**
  String get talkRosaSecretC1;

  /// No description provided for @talkRosaSecretR1.
  ///
  /// In en, this message translates to:
  /// **'Clever girl. Here\'s a tip for your discretion.'**
  String get talkRosaSecretR1;

  /// No description provided for @talkRosaSecretC2.
  ///
  /// In en, this message translates to:
  /// **'Go on, have a taste, today\'s cream is lovely!'**
  String get talkRosaSecretC2;

  /// No description provided for @talkRosaSecretR2.
  ///
  /// In en, this message translates to:
  /// **'(A very quick lick) …It is lovely. Tell no one.'**
  String get talkRosaSecretR2;

  /// No description provided for @talkMochiBellyL1.
  ///
  /// In en, this message translates to:
  /// **'Mrrp.'**
  String get talkMochiBellyL1;

  /// No description provided for @talkMochiBellyL2.
  ///
  /// In en, this message translates to:
  /// **'Soaked again? The oven\'s still warm, go dry off.'**
  String get talkMochiBellyL2;

  /// No description provided for @talkMochiBellyL3.
  ///
  /// In en, this message translates to:
  /// **'(Mochi flops over and shows a fluffy belly.)'**
  String get talkMochiBellyL3;

  /// No description provided for @talkMochiBellyL4.
  ///
  /// In en, this message translates to:
  /// **'It\'s a trap. I know it. Belly rubs mean bites.'**
  String get talkMochiBellyL4;

  /// No description provided for @talkMochiBellyC1.
  ///
  /// In en, this message translates to:
  /// **'Rub the belly'**
  String get talkMochiBellyC1;

  /// No description provided for @talkMochiBellyR1.
  ///
  /// In en, this message translates to:
  /// **'(Mochi hugs Mai\'s hand with all four paws… and purrs.)'**
  String get talkMochiBellyR1;

  /// No description provided for @talkMochiBellyC2.
  ///
  /// In en, this message translates to:
  /// **'Roll the yarn ball'**
  String get talkMochiBellyC2;

  /// No description provided for @talkMochiBellyR2.
  ///
  /// In en, this message translates to:
  /// **'(Mochi chases the yarn and skids a full circle across the floor.)'**
  String get talkMochiBellyR2;

  /// No description provided for @talkMochiBellyL5.
  ///
  /// In en, this message translates to:
  /// **'You little rascal.'**
  String get talkMochiBellyL5;

  /// No description provided for @talkWalrusFishL1.
  ///
  /// In en, this message translates to:
  /// **'Guess how big the fish I caught this morning was?'**
  String get talkWalrusFishL1;

  /// No description provided for @talkWalrusFishL2.
  ///
  /// In en, this message translates to:
  /// **'How big?'**
  String get talkWalrusFishL2;

  /// No description provided for @talkWalrusFishL3.
  ///
  /// In en, this message translates to:
  /// **'As big as… your oven!'**
  String get talkWalrusFishL3;

  /// No description provided for @talkWalrusFishC1.
  ///
  /// In en, this message translates to:
  /// **'Last week you said it was as big as the fridge.'**
  String get talkWalrusFishC1;

  /// No description provided for @talkWalrusFishR1.
  ///
  /// In en, this message translates to:
  /// **'Well… it\'s been growing! Even the fish eat your pastries.'**
  String get talkWalrusFishR1;

  /// No description provided for @talkWalrusFishC2.
  ///
  /// In en, this message translates to:
  /// **'Did you bring it home?'**
  String get talkWalrusFishC2;

  /// No description provided for @talkWalrusFishR2.
  ///
  /// In en, this message translates to:
  /// **'It begged to be let go. Promised to come back tomorrow… even bigger.'**
  String get talkWalrusFishR2;

  /// No description provided for @talkWalrusFishL4.
  ///
  /// In en, this message translates to:
  /// **'Then I\'d better get a bigger oven ready.'**
  String get talkWalrusFishL4;

  /// No description provided for @talkSquirrelNutL1.
  ///
  /// In en, this message translates to:
  /// **'Can I pay in chestnuts? I\'ve got a whole stash!'**
  String get talkSquirrelNutL1;

  /// No description provided for @talkSquirrelNutL2.
  ///
  /// In en, this message translates to:
  /// **'Oh… we only take coins here.'**
  String get talkSquirrelNutL2;

  /// No description provided for @talkSquirrelNutL3.
  ///
  /// In en, this message translates to:
  /// **'Wait, let me check my tail…'**
  String get talkSquirrelNutL3;

  /// No description provided for @talkSquirrelNutL4.
  ///
  /// In en, this message translates to:
  /// **'Here! Three coins, a button, and… one emergency chestnut.'**
  String get talkSquirrelNutL4;

  /// No description provided for @talkSquirrelNutC1.
  ///
  /// In en, this message translates to:
  /// **'I\'ll take the coins, you keep the chestnut.'**
  String get talkSquirrelNutC1;

  /// No description provided for @talkSquirrelNutR1.
  ///
  /// In en, this message translates to:
  /// **'You\'re the best! I\'ll bury it outside so a tree grows for you.'**
  String get talkSquirrelNutR1;

  /// No description provided for @talkSquirrelNutC2.
  ///
  /// In en, this message translates to:
  /// **'Give me the chestnut, I\'ll bake you something with it!'**
  String get talkSquirrelNutC2;

  /// No description provided for @talkSquirrelNutR2.
  ///
  /// In en, this message translates to:
  /// **'Really? I\'ll fetch more… from wherever I buried them. I forgot where.'**
  String get talkSquirrelNutR2;

  /// No description provided for @talkHamsterCheeksL1.
  ///
  /// In en, this message translates to:
  /// **'Could I have… mmf-mm-mmf…'**
  String get talkHamsterCheeksL1;

  /// No description provided for @talkHamsterCheeksL2.
  ///
  /// In en, this message translates to:
  /// **'Sweetie, your cheeks are already full of cookies.'**
  String get talkHamsterCheeksL2;

  /// No description provided for @talkHamsterCheeksL3.
  ///
  /// In en, this message translates to:
  /// **'(Gulp) Those are for later. This one is for now!'**
  String get talkHamsterCheeksL3;

  /// No description provided for @talkHamsterCheeksC1.
  ///
  /// In en, this message translates to:
  /// **'Let me box some up for you to take home.'**
  String get talkHamsterCheeksC1;

  /// No description provided for @talkHamsterCheeksR1.
  ///
  /// In en, this message translates to:
  /// **'A box! My cheeks get the day off!'**
  String get talkHamsterCheeksR1;

  /// No description provided for @talkHamsterCheeksC2.
  ///
  /// In en, this message translates to:
  /// **'Think you can fit one more?'**
  String get talkHamsterCheeksC2;

  /// No description provided for @talkHamsterCheeksR2.
  ///
  /// In en, this message translates to:
  /// **'Challenge accepted! …Mmf… perfect fit.'**
  String get talkHamsterCheeksR2;

  /// No description provided for @smallTalkNora.
  ///
  /// In en, this message translates to:
  /// **'Your usual today? I remember!'**
  String get smallTalkNora;

  /// No description provided for @smallTalkBao.
  ///
  /// In en, this message translates to:
  /// **'…Fresh out of the oven. Still warm.'**
  String get smallTalkBao;

  /// No description provided for @smallTalkTheo.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tea is brewed with a smile, give it a try!'**
  String get smallTalkTheo;

  /// No description provided for @smallTalkMai1.
  ///
  /// In en, this message translates to:
  /// **'Lovely day! Been down to the beach yet?'**
  String get smallTalkMai1;

  /// No description provided for @smallTalkMai2.
  ///
  /// In en, this message translates to:
  /// **'The next batch has a pinch of cinnamon, come back and try it!'**
  String get smallTalkMai2;

  /// No description provided for @smallTalkReply1.
  ///
  /// In en, this message translates to:
  /// **'Aw, thank you!'**
  String get smallTalkReply1;

  /// No description provided for @smallTalkReply2.
  ///
  /// In en, this message translates to:
  /// **'Lovely, I\'ll be back tomorrow!'**
  String get smallTalkReply2;

  /// No description provided for @smallTalkReply3.
  ///
  /// In en, this message translates to:
  /// **'This place always smells so good.'**
  String get smallTalkReply3;

  /// No description provided for @quarrelLastCakeL1.
  ///
  /// In en, this message translates to:
  /// **'This strawberry cupcake is mine! I saw it first!'**
  String get quarrelLastCakeL1;

  /// No description provided for @quarrelLastCakeL2.
  ///
  /// In en, this message translates to:
  /// **'But I\'ve been dreaming about it since yesterday!'**
  String get quarrelLastCakeL2;

  /// No description provided for @quarrelLastCakeL3.
  ///
  /// In en, this message translates to:
  /// **'Dreaming doesn\'t count!'**
  String get quarrelLastCakeL3;

  /// No description provided for @quarrelLastCakeL4.
  ///
  /// In en, this message translates to:
  /// **'Easy, you two, the cupcake\'s getting squished!'**
  String get quarrelLastCakeL4;

  /// No description provided for @quarrelLastCakeA.
  ///
  /// In en, this message translates to:
  /// **'Split it in half'**
  String get quarrelLastCakeA;

  /// No description provided for @quarrelLastCakeRA1.
  ///
  /// In en, this message translates to:
  /// **'Half… fits perfectly in one cheek!'**
  String get quarrelLastCakeRA1;

  /// No description provided for @quarrelLastCakeRA2.
  ///
  /// In en, this message translates to:
  /// **'My half has more frosting. Hehe.'**
  String get quarrelLastCakeRA2;

  /// No description provided for @quarrelLastCakeB.
  ///
  /// In en, this message translates to:
  /// **'Rock-paper-scissors for it'**
  String get quarrelLastCakeB;

  /// No description provided for @quarrelLastCakeRB1.
  ///
  /// In en, this message translates to:
  /// **'Rock, paper, scissors… shoot!'**
  String get quarrelLastCakeRB1;

  /// No description provided for @quarrelLastCakeRB2.
  ///
  /// In en, this message translates to:
  /// **'I win!'**
  String get quarrelLastCakeRB2;

  /// No description provided for @quarrelLastCakeRB3.
  ///
  /// In en, this message translates to:
  /// **'Hmph… next time I\'m going rock.'**
  String get quarrelLastCakeRB3;

  /// No description provided for @quarrelLastCakeC.
  ///
  /// In en, this message translates to:
  /// **'A fresh batch is almost out, one each!'**
  String get quarrelLastCakeC;

  /// No description provided for @quarrelLastCakeRC1.
  ///
  /// In en, this message translates to:
  /// **'One EACH?!'**
  String get quarrelLastCakeRC1;

  /// No description provided for @quarrelLastCakeRC2.
  ///
  /// In en, this message translates to:
  /// **'You\'re a pastry angel!'**
  String get quarrelLastCakeRC2;

  /// No description provided for @quarrelFirstL1.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been here since sunrise! I go first!'**
  String get quarrelFirstL1;

  /// No description provided for @quarrelFirstL2.
  ///
  /// In en, this message translates to:
  /// **'I napped on this doorstep all night. That\'s what cats do.'**
  String get quarrelFirstL2;

  /// No description provided for @quarrelFirstL3.
  ///
  /// In en, this message translates to:
  /// **'Napping isn\'t queueing!'**
  String get quarrelFirstL3;

  /// No description provided for @quarrelFirstL4.
  ///
  /// In en, this message translates to:
  /// **'For cats, it is.'**
  String get quarrelFirstL4;

  /// No description provided for @quarrelFirstL5.
  ///
  /// In en, this message translates to:
  /// **'Okay, okay, deep breaths!'**
  String get quarrelFirstL5;

  /// No description provided for @quarrelFirstA.
  ///
  /// In en, this message translates to:
  /// **'Come in together, the door\'s wide enough!'**
  String get quarrelFirstA;

  /// No description provided for @quarrelFirstRA1.
  ///
  /// In en, this message translates to:
  /// **'…It\'s a bit tight.'**
  String get quarrelFirstRA1;

  /// No description provided for @quarrelFirstRA2.
  ///
  /// In en, this message translates to:
  /// **'Suck in your tummy.'**
  String get quarrelFirstRA2;

  /// No description provided for @quarrelFirstRA3.
  ///
  /// In en, this message translates to:
  /// **'(They\'re stuck in the doorway for a second… then both burst out laughing.)'**
  String get quarrelFirstRA3;

  /// No description provided for @quarrelFirstB.
  ///
  /// In en, this message translates to:
  /// **'Check the paw prints on the doormat'**
  String get quarrelFirstB;

  /// No description provided for @quarrelFirstRB1.
  ///
  /// In en, this message translates to:
  /// **'Cat prints underneath… shiba prints on top.'**
  String get quarrelFirstRB1;

  /// No description provided for @quarrelFirstRB2.
  ///
  /// In en, this message translates to:
  /// **'Well… I did stand on their paw prints.'**
  String get quarrelFirstRB2;

  /// No description provided for @quarrelFirstRB3.
  ///
  /// In en, this message translates to:
  /// **'Thank you. You\'re adorable. After me.'**
  String get quarrelFirstRB3;

  /// No description provided for @quarrelFirstC.
  ///
  /// In en, this message translates to:
  /// **'Best joke goes first'**
  String get quarrelFirstC;

  /// No description provided for @quarrelFirstRC1.
  ///
  /// In en, this message translates to:
  /// **'Why did the croissant see a doctor? It was feeling flaky!'**
  String get quarrelFirstRC1;

  /// No description provided for @quarrelFirstRC2.
  ///
  /// In en, this message translates to:
  /// **'…That was awful. I laughed. You go first.'**
  String get quarrelFirstRC2;

  /// No description provided for @quarrelTartL1.
  ///
  /// In en, this message translates to:
  /// **'Egg tarts are the king of pastries! Crisp, rich, golden as the sun!'**
  String get quarrelTartL1;

  /// No description provided for @quarrelTartL2.
  ///
  /// In en, this message translates to:
  /// **'King? I\'m the king around here. And the king picks apple pie.'**
  String get quarrelTartL2;

  /// No description provided for @quarrelTartL3.
  ///
  /// In en, this message translates to:
  /// **'All you\'ve got is a big mane!'**
  String get quarrelTartL3;

  /// No description provided for @quarrelTartL4.
  ///
  /// In en, this message translates to:
  /// **'And all you\'ve got is a round belly!'**
  String get quarrelTartL4;

  /// No description provided for @quarrelTartL5.
  ///
  /// In en, this message translates to:
  /// **'Gentlemen, the whole street is watching!'**
  String get quarrelTartL5;

  /// No description provided for @quarrelTartA.
  ///
  /// In en, this message translates to:
  /// **'Blind taste test, try both!'**
  String get quarrelTartA;

  /// No description provided for @quarrelTartRA1.
  ///
  /// In en, this message translates to:
  /// **'This one\'s… better. It\'s the apple pie?!'**
  String get quarrelTartRA1;

  /// No description provided for @quarrelTartRA2.
  ///
  /// In en, this message translates to:
  /// **'And I picked… the egg tart. Oh no.'**
  String get quarrelTartRA2;

  /// No description provided for @quarrelTartRA3.
  ///
  /// In en, this message translates to:
  /// **'Fine, we\'ll buy both!'**
  String get quarrelTartRA3;

  /// No description provided for @quarrelTartB.
  ///
  /// In en, this message translates to:
  /// **'Every pastry is delicious, shake hands!'**
  String get quarrelTartB;

  /// No description provided for @quarrelTartRB1.
  ///
  /// In en, this message translates to:
  /// **'Spoken like a diplomat.'**
  String get quarrelTartRB1;

  /// No description provided for @quarrelTartRB2.
  ///
  /// In en, this message translates to:
  /// **'Bland as unseasoned dough.'**
  String get quarrelTartRB2;

  /// No description provided for @quarrelTartC.
  ///
  /// In en, this message translates to:
  /// **'Ask Mr. Hoa to settle it'**
  String get quarrelTartC;

  /// No description provided for @quarrelTartCAlt.
  ///
  /// In en, this message translates to:
  /// **'Do your best Mr. Hoa impression'**
  String get quarrelTartCAlt;

  /// No description provided for @quarrelTartRC1.
  ///
  /// In en, this message translates to:
  /// **'Egg tart. Forty years. Not up for debate.'**
  String get quarrelTartRC1;

  /// No description provided for @quarrelTartRC1Alt.
  ///
  /// In en, this message translates to:
  /// **'(Deep voice) Ahem… Egg tart. Forty years. Not up for debate.'**
  String get quarrelTartRC1Alt;

  /// No description provided for @quarrelTartRC2.
  ///
  /// In en, this message translates to:
  /// **'Hear that? Hear that!'**
  String get quarrelTartRC2;

  /// No description provided for @quarrelTartRC3.
  ///
  /// In en, this message translates to:
  /// **'Hmph. The seniors\' club is biased.'**
  String get quarrelTartRC3;

  /// No description provided for @quarrelBanner.
  ///
  /// In en, this message translates to:
  /// **'There\'s a commotion outside!'**
  String get quarrelBanner;

  /// No description provided for @quarrelLook.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get quarrelLook;

  /// No description provided for @quarrelSendMai.
  ///
  /// In en, this message translates to:
  /// **'Send Mai'**
  String get quarrelSendMai;

  /// No description provided for @quarrelIntervene.
  ///
  /// In en, this message translates to:
  /// **'Step in'**
  String get quarrelIntervene;

  /// No description provided for @quarrelTimeout.
  ///
  /// In en, this message translates to:
  /// **'The two customers stomped off in a huff…'**
  String get quarrelTimeout;

  /// No description provided for @quarrelPeace.
  ///
  /// In en, this message translates to:
  /// **'Peace returns to the street.'**
  String get quarrelPeace;

  /// No description provided for @staffMenuControl.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get staffMenuControl;

  /// No description provided for @staffMenuTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk to a customer'**
  String get staffMenuTalk;

  /// No description provided for @actionPickUp.
  ///
  /// In en, this message translates to:
  /// **'Pick up'**
  String get actionPickUp;

  /// No description provided for @actionPutDown.
  ///
  /// In en, this message translates to:
  /// **'Put down'**
  String get actionPutDown;

  /// No description provided for @actionPlaceOn.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get actionPlaceOn;

  /// No description provided for @actionGive.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get actionGive;

  /// No description provided for @actionThrow.
  ///
  /// In en, this message translates to:
  /// **'Throw'**
  String get actionThrow;

  /// No description provided for @actionTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get actionTalk;

  /// No description provided for @actionWave.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get actionWave;

  /// No description provided for @controlHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the left circle to walk, tap the right buttons to act.'**
  String get controlHint;

  /// No description provided for @talkPickCustomer.
  ///
  /// In en, this message translates to:
  /// **'Pick a customer to chat with'**
  String get talkPickCustomer;

  /// No description provided for @talkNoCustomer.
  ///
  /// In en, this message translates to:
  /// **'No customers are free to chat right now.'**
  String get talkNoCustomer;

  /// No description provided for @itemYarn.
  ///
  /// In en, this message translates to:
  /// **'Yarn ball'**
  String get itemYarn;

  /// No description provided for @itemCakeBox.
  ///
  /// In en, this message translates to:
  /// **'Cake box'**
  String get itemCakeBox;

  /// No description provided for @itemFlour.
  ///
  /// In en, this message translates to:
  /// **'Flour sack'**
  String get itemFlour;

  /// No description provided for @reactOops.
  ///
  /// In en, this message translates to:
  /// **'Oops!'**
  String get reactOops;

  /// No description provided for @reactStop.
  ///
  /// In en, this message translates to:
  /// **'Hey, quit it!'**
  String get reactStop;

  /// No description provided for @reactThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get reactThanks;

  /// No description provided for @reactFull.
  ///
  /// In en, this message translates to:
  /// **'I\'m full, but thank you!'**
  String get reactFull;

  /// No description provided for @reactNoThrowCake.
  ///
  /// In en, this message translates to:
  /// **'Cake is handed, not thrown!'**
  String get reactNoThrowCake;

  /// No description provided for @reactExcuseMe.
  ///
  /// In en, this message translates to:
  /// **'Excuse me!'**
  String get reactExcuseMe;

  /// No description provided for @reactPurr.
  ///
  /// In en, this message translates to:
  /// **'Purr…'**
  String get reactPurr;

  /// Goodwill reward toast in the 3D shop scene.
  ///
  /// In en, this message translates to:
  /// **'+{count} goodwill'**
  String interactGoodwill(int count);

  /// Coin reward toast in the 3D shop scene.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 coin} other{+{count} coins}}'**
  String interactCoins(int count);

  /// No description provided for @townEnterShop.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get townEnterShop;

  /// No description provided for @townExitShop.
  ///
  /// In en, this message translates to:
  /// **'Go outside'**
  String get townExitShop;

  /// Shop scene: button that leaves the bakery and goes back to the town street. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Go outside'**
  String get shopExitButton;

  /// No description provided for @townMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get townMap;

  /// No description provided for @townOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get townOpenMap;

  /// No description provided for @townYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get townYouAreHere;

  /// No description provided for @townHomeShop.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s bakery'**
  String get townHomeShop;

  /// No description provided for @townBranchN.
  ///
  /// In en, this message translates to:
  /// **'Branch {n}'**
  String townBranchN(int n);

  /// No description provided for @townLotForSale.
  ///
  /// In en, this message translates to:
  /// **'Empty lot'**
  String get townLotForSale;

  /// No description provided for @townLotLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocks at level {level}'**
  String townLotLocked(int level);

  /// Branch lot note once the player's level has reached this lot. The lot opens for business later.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · for sale at Harbor Realty'**
  String get townLotUnlocked;

  /// Toast shown after a level-up unlocks new branch lots. count = number of new lots.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{New lot unlocked!} other{{count} new lots unlocked!}}'**
  String townLotsUnlockedToast(int count);

  /// No description provided for @townComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get townComingSoon;

  /// No description provided for @townStreetName.
  ///
  /// In en, this message translates to:
  /// **'Bakery Street'**
  String get townStreetName;

  /// No description provided for @townOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the door…'**
  String get townOpening;

  /// Action button at a branch door when the till has coins. Collects them now.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get townActionCollect;

  /// Action button at a branch door when the till is empty. Opens the branch sheet.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get townActionBranch;

  /// Action button at the Harbor Realty counter. Opens the lot list.
  ///
  /// In en, this message translates to:
  /// **'Browse lots'**
  String get townActionRealty;

  /// Lot name in the realty sheet. n = lot number.
  ///
  /// In en, this message translates to:
  /// **'Lot {n}'**
  String realtyLotN(int n);

  /// Tag on a lot the player already owns.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get realtyOwned;

  /// Title of the buy confirmation panel in the realty sheet.
  ///
  /// In en, this message translates to:
  /// **'Buy this lot?'**
  String get realtyConfirmTitle;

  /// Body of the buy confirmation panel. price = lot price.
  ///
  /// In en, this message translates to:
  /// **'{price} coins. It becomes a little branch that sells on its own.'**
  String realtyConfirmBody(int price);

  /// Toast after buying a lot. n = branch number.
  ///
  /// In en, this message translates to:
  /// **'Branch {n} is open!'**
  String branchOpenedToast(int n);

  /// Branch sign note: level, till coins and till cap.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · Till {coins}/{cap}'**
  String branchBannerTill(int level, int coins, int cap);

  /// Branch sign note when the till is full. level = branch level.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · Till full!'**
  String branchBannerFull(int level);

  /// Branch sheet: income per hour. coins = coins per hour.
  ///
  /// In en, this message translates to:
  /// **'~{coins} coins/hour'**
  String branchIncome(int coins);

  /// Branch sheet: till capacity. coins = till cap.
  ///
  /// In en, this message translates to:
  /// **'Till holds {coins} coins (8 h)'**
  String branchTillCap(int coins);

  /// Section title for the till in the branch sheet.
  ///
  /// In en, this message translates to:
  /// **'Till'**
  String get branchTill;

  /// Branch sheet note when the till is full.
  ///
  /// In en, this message translates to:
  /// **'Full — collect to keep selling'**
  String get branchTillFull;

  /// Branch sheet: time until the till is full. time = formatted duration.
  ///
  /// In en, this message translates to:
  /// **'Full in {time}'**
  String branchFullIn(String time);

  /// Collect button in the branch sheet. coins = coins in the till.
  ///
  /// In en, this message translates to:
  /// **'Collect {coins}'**
  String branchCollect(int coins);

  /// Toast after collecting from a branch.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins from the branch'**
  String branchCollectedToast(int coins);

  /// Upgrade button in the branch sheet. coins = upgrade cost.
  ///
  /// In en, this message translates to:
  /// **'Upgrade · {coins}'**
  String branchUpgrade(int coins);

  /// Branch sheet: next level and its income. level = next level, coins = coins per hour.
  ///
  /// In en, this message translates to:
  /// **'Level {level}: {coins} coins/hour'**
  String branchNextLevel(int level, int coins);

  /// Branch sheet: reason an upgrade is blocked. level = Mai's level needed.
  ///
  /// In en, this message translates to:
  /// **'Mai needs level {level}'**
  String branchNeedMaiLevel(int level);

  /// Toast after upgrading a branch. n = branch number, level = new level.
  ///
  /// In en, this message translates to:
  /// **'Branch {n} is now level {level}!'**
  String branchUpgradedToast(int n, int level);

  /// Section title for staff in the branch sheet.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get branchStaff;

  /// Branch sheet: used and total staff spots.
  ///
  /// In en, this message translates to:
  /// **'{used}/{total} spots'**
  String branchSlots(int used, int total);

  /// Branch sheet note when all staff spots are taken.
  ///
  /// In en, this message translates to:
  /// **'No free spot — level 3 adds one'**
  String get branchNoSlot;

  /// Hire button in the branch sheet. coins = hire cost.
  ///
  /// In en, this message translates to:
  /// **'Hire · {coins}'**
  String branchHire(int coins);

  /// Button to dismiss a staff member from a branch.
  ///
  /// In en, this message translates to:
  /// **'Let go'**
  String get branchDismiss;

  /// Confirmation for dismissing staff. name = staff name, coins = refund.
  ///
  /// In en, this message translates to:
  /// **'{name} will take a long rest. You get {coins} coins back.'**
  String branchDismissConfirm(String name, int coins);

  /// Toast after hiring staff. name = staff name, n = branch number.
  ///
  /// In en, this message translates to:
  /// **'{name} now works at Branch {n}'**
  String branchHiredToast(String name, int n);

  /// Label on a staff card that is already working at a branch. n = branch number.
  ///
  /// In en, this message translates to:
  /// **'Works at Branch {n}'**
  String branchWorksAt(int n);

  /// Staff role: server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get staffRoleServer;

  /// Staff role: baker.
  ///
  /// In en, this message translates to:
  /// **'Baker'**
  String get staffRoleBaker;

  /// Staff role: manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get staffRoleManager;

  /// Staff effect: sales bonus. pct = percent.
  ///
  /// In en, this message translates to:
  /// **'+{pct}% sales'**
  String staffEffectBonus(int pct);

  /// Staff effect: manager sends part of sales to the wallet. pct = percent.
  ///
  /// In en, this message translates to:
  /// **'Sends {pct}% of sales home'**
  String staffEffectDeposit(int pct);

  /// Staff name: Ami (baker).
  ///
  /// In en, this message translates to:
  /// **'Ami'**
  String get charAmi;

  /// Staff name: Hanh (manager).
  ///
  /// In en, this message translates to:
  /// **'Hanh'**
  String get charHanh;

  /// Staff name: Biscuit (server).
  ///
  /// In en, this message translates to:
  /// **'Biscuit'**
  String get charBiscuit;

  /// Staff name: Nutmeg (server).
  ///
  /// In en, this message translates to:
  /// **'Nutmeg'**
  String get charNutmeg;

  /// Staff name: Cocoa (baker).
  ///
  /// In en, this message translates to:
  /// **'Cocoa'**
  String get charCocoa;

  /// Staff name: Maple (baker).
  ///
  /// In en, this message translates to:
  /// **'Maple'**
  String get charMaple;

  /// Toast on opening the app after being away. coins = coins sold while away.
  ///
  /// In en, this message translates to:
  /// **'While you were away your branches sold {coins} coins — drop by to collect!'**
  String branchAwayToast(int coins);

  /// Toast on opening the app: manager deposited coins to the wallet. coins = deposited amount.
  ///
  /// In en, this message translates to:
  /// **'Your manager sent home +{coins} coins'**
  String branchDepositToast(int coins);

  /// Note shown when the device clock has been set back; the till pauses.
  ///
  /// In en, this message translates to:
  /// **'Your device clock is behind your last visit, so the till is resting.'**
  String get branchClockBehind;

  /// No description provided for @citySeaMarketName.
  ///
  /// In en, this message translates to:
  /// **'Seaside Market'**
  String get citySeaMarketName;

  /// No description provided for @cityRealtyName.
  ///
  /// In en, this message translates to:
  /// **'Harbor Realty'**
  String get cityRealtyName;

  /// No description provided for @cityParkName.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse Park'**
  String get cityParkName;

  /// No description provided for @cityRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Lighthouse Kitchen'**
  String get cityRestaurantName;

  /// No description provided for @citySalonName.
  ///
  /// In en, this message translates to:
  /// **'Seashell Salon'**
  String get citySalonName;

  /// No description provided for @cityOrderFood.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get cityOrderFood;

  /// No description provided for @cityGetHaircut.
  ///
  /// In en, this message translates to:
  /// **'Style hair'**
  String get cityGetHaircut;

  /// No description provided for @cityPrice.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String cityPrice(int coins);

  /// No description provided for @cityXpGain.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String cityXpGain(int xp);

  /// No description provided for @cityMaiLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String cityMaiLevel(int n);

  /// No description provided for @cityLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level up!'**
  String get cityLevelUp;

  /// No description provided for @cityNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get cityNotEnoughCoins;

  /// No description provided for @cityAteToday.
  ///
  /// In en, this message translates to:
  /// **'Already eaten today – less XP'**
  String get cityAteToday;

  /// No description provided for @cityBuffFull.
  ///
  /// In en, this message translates to:
  /// **'Full & happy: +10% tips next shift'**
  String get cityBuffFull;

  /// No description provided for @cityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get cityConfirm;

  /// No description provided for @cityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cityCancel;

  /// No description provided for @cityFirstVisit.
  ///
  /// In en, this message translates to:
  /// **'First visit bonus!'**
  String get cityFirstVisit;

  /// No description provided for @cityMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s menu'**
  String get cityMenuTitle;

  /// No description provided for @citySalonTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new look'**
  String get citySalonTitle;

  /// No description provided for @cityHairStyle.
  ///
  /// In en, this message translates to:
  /// **'Hairstyle'**
  String get cityHairStyle;

  /// No description provided for @cityHairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair color'**
  String get cityHairColor;

  /// No description provided for @cityEating.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the meal…'**
  String get cityEating;

  /// No description provided for @citySaveReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This save is from a newer game version. Progress this session won\'t be saved.'**
  String get citySaveReadOnly;

  /// Action button shown at the shop counter in the 3D town to start a shift.
  ///
  /// In en, this message translates to:
  /// **'Open shop'**
  String get shiftOpen;

  /// Toast on the first visit to the shop, pointing Mai to the counter.
  ///
  /// In en, this message translates to:
  /// **'Go to the counter and tap “Open shop” to start selling'**
  String get shiftHintCounter;

  /// Chip shown while the next customer walks to the counter during a shift.
  ///
  /// In en, this message translates to:
  /// **'A customer is on the way…'**
  String get shiftCustomerComing;

  /// Title of the end-of-shift summary card.
  ///
  /// In en, this message translates to:
  /// **'Shift complete!'**
  String get shiftSummaryTitle;

  /// Button to close the shop before the shift ends.
  ///
  /// In en, this message translates to:
  /// **'Close early'**
  String get shiftCloseEarly;

  /// Toast after closing the shop early. coins = coins kept from served customers.
  ///
  /// In en, this message translates to:
  /// **'Shop closed · +{coins} coins kept'**
  String shiftClosedToast(int coins);

  /// Line on the result card for the tip bonus from the Full & happy buff. amount = extra tip.
  ///
  /// In en, this message translates to:
  /// **'Full & happy: +{amount} tips'**
  String shiftBuffTip(int amount);

  /// No description provided for @dishFishSoup.
  ///
  /// In en, this message translates to:
  /// **'Seaside fish soup'**
  String get dishFishSoup;

  /// No description provided for @dishOmeletteRice.
  ///
  /// In en, this message translates to:
  /// **'Omelette rice'**
  String get dishOmeletteRice;

  /// No description provided for @dishVeggieCurry.
  ///
  /// In en, this message translates to:
  /// **'Veggie curry'**
  String get dishVeggieCurry;

  /// No description provided for @dishSeafoodNoodles.
  ///
  /// In en, this message translates to:
  /// **'Seafood noodles'**
  String get dishSeafoodNoodles;

  /// No description provided for @hairPonytail.
  ///
  /// In en, this message translates to:
  /// **'Ponytail'**
  String get hairPonytail;

  /// No description provided for @hairBob.
  ///
  /// In en, this message translates to:
  /// **'Bob'**
  String get hairBob;

  /// No description provided for @hairBun.
  ///
  /// In en, this message translates to:
  /// **'Bun'**
  String get hairBun;

  /// No description provided for @hairTwinTails.
  ///
  /// In en, this message translates to:
  /// **'Twin tails'**
  String get hairTwinTails;

  /// No description provided for @hairColorChestnut.
  ///
  /// In en, this message translates to:
  /// **'Chestnut'**
  String get hairColorChestnut;

  /// No description provided for @hairColorCaramel.
  ///
  /// In en, this message translates to:
  /// **'Caramel'**
  String get hairColorCaramel;

  /// No description provided for @hairColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get hairColorBlack;

  /// No description provided for @hairColorStrawberry.
  ///
  /// In en, this message translates to:
  /// **'Strawberry'**
  String get hairColorStrawberry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
