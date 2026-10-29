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

  /// No description provided for @commonUnlockAtLevel.
  ///
  /// In en, this message translates to:
  /// **'Unlocks at level {level}'**
  String commonUnlockAtLevel(int level);

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

  /// No description provided for @commonNotEnoughGems.
  ///
  /// In en, this message translates to:
  /// **'Not enough gems'**
  String get commonNotEnoughGems;

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

  /// No description provided for @menuXpMax.
  ///
  /// In en, this message translates to:
  /// **'Max level'**
  String get menuXpMax;

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
  /// **'Leave for now?'**
  String get dayExitConfirmTitle;

  /// No description provided for @dayExitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Coins earned so far are kept, but today won\'t count as completed.'**
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

  /// Speech bubble the first time Mochi arrives (sad face). Keep under 70 characters.
  ///
  /// In en, this message translates to:
  /// **'A little soaked cat is sheltering from the rain at your door…'**
  String get mochiArriveFirst;

  /// Speech bubble when Mochi arrives on later rainy days
  ///
  /// In en, this message translates to:
  /// **'Mochi is back, sheltering from the rain!'**
  String get mochiArriveAgain;

  /// Speech bubble after the player taps Mochi once (neutral face)
  ///
  /// In en, this message translates to:
  /// **'Mochi looks up at you, tail swishing softly.'**
  String get mochiLook;

  /// Button: pet Mochi. Keep under 12 characters.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get mochiPet;

  /// Button: let Mochi rest without petting. Keep under 16 characters.
  ///
  /// In en, this message translates to:
  /// **'Let Mochi rest'**
  String get mochiRest;

  /// Speech bubble after petting Mochi (joy face)
  ///
  /// In en, this message translates to:
  /// **'Mochi purrs happily!'**
  String get mochiPetThanks;

  /// Speech bubble after choosing to let Mochi rest (smile face)
  ///
  /// In en, this message translates to:
  /// **'Mochi curls up for a nap by the stove.'**
  String get mochiNap;

  /// Gift toast after petting Mochi. Only mentions coins when gems is 0.
  ///
  /// In en, this message translates to:
  /// **'{gems, plural, =0{Mochi left you {coins} coins!} =1{Mochi left you {coins} coins and 1 gem!} other{Mochi left you {coins} coins and {gems} gems!}}'**
  String mochiGift(int coins, int gems);

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

  /// No description provided for @storyChapter1Title.
  ///
  /// In en, this message translates to:
  /// **'Chapter 1: The Seaside Bakery'**
  String get storyChapter1Title;

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

  /// No description provided for @storyFinaleLine3.
  ///
  /// In en, this message translates to:
  /// **'Chapter 1 complete. More stories are coming soon!'**
  String get storyFinaleLine3;

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
  /// **'Day bonus +{xp} XP'**
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
  /// **'Level up! Bakery level {level}'**
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

  /// No description provided for @upgradesTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get upgradesTitle;

  /// No description provided for @upgradeOven.
  ///
  /// In en, this message translates to:
  /// **'Oven'**
  String get upgradeOven;

  /// No description provided for @upgradeOvenDesc.
  ///
  /// In en, this message translates to:
  /// **'A wider golden zone when baking'**
  String get upgradeOvenDesc;

  /// No description provided for @upgradeOvenPerfectZone.
  ///
  /// In en, this message translates to:
  /// **'Perfect zone ±{percent}%'**
  String upgradeOvenPerfectZone(int percent);

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

  /// No description provided for @upgradeLevelOf.
  ///
  /// In en, this message translates to:
  /// **'Level {current}/{max}'**
  String upgradeLevelOf(int current, int max);

  /// No description provided for @upgradeBuy.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradeBuy;

  /// No description provided for @upgradeMaxed.
  ///
  /// In en, this message translates to:
  /// **'Fully upgraded'**
  String get upgradeMaxed;

  /// No description provided for @upgradeDone.
  ///
  /// In en, this message translates to:
  /// **'Upgraded!'**
  String get upgradeDone;

  /// No description provided for @decorTitle.
  ///
  /// In en, this message translates to:
  /// **'Decorate the bakery'**
  String get decorTitle;

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

  /// No description provided for @decorTipBonus.
  ///
  /// In en, this message translates to:
  /// **'+{percent}% tips'**
  String decorTipBonus(int percent);

  /// No description provided for @decorTotalBonus.
  ///
  /// In en, this message translates to:
  /// **'Total tip bonus: +{percent}%'**
  String decorTotalBonus(int percent);

  /// No description provided for @decorEquip.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get decorEquip;

  /// No description provided for @decorEquipped.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get decorEquipped;

  /// No description provided for @recipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipe book'**
  String get recipesTitle;

  /// No description provided for @recipesPrice.
  ///
  /// In en, this message translates to:
  /// **'Price: {amount}'**
  String recipesPrice(int amount);

  /// No description provided for @recipesIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get recipesIngredients;

  /// No description provided for @recipesMastery.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get recipesMastery;

  /// No description provided for @recipesMasteryHint.
  ///
  /// In en, this message translates to:
  /// **'Serve it once, get 4 stars, then 5 stars to master it'**
  String get recipesMasteryHint;

  /// No description provided for @recipesMasteryReward.
  ///
  /// In en, this message translates to:
  /// **'Mastered! +{gems} gems'**
  String recipesMasteryReward(int gems);

  /// No description provided for @recipesMissingPage.
  ///
  /// In en, this message translates to:
  /// **'Missing page. Unlocks at level {level}'**
  String recipesMissingPage(int level);

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

  /// No description provided for @storeTitle.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get storeTitle;

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

  /// No description provided for @storeDecorSetDesc.
  ///
  /// In en, this message translates to:
  /// **'3 special decorations'**
  String get storeDecorSetDesc;

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

  /// No description provided for @storeFreeGem.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad for {gems} gem'**
  String storeFreeGem(int gems);

  /// No description provided for @storeOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get storeOwned;

  /// No description provided for @storeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulated purchase'**
  String get storeConfirmTitle;

  /// No description provided for @storeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Buy {item} for {price}? No real money will be charged.'**
  String storeConfirmBody(String item, String price);

  /// No description provided for @storePurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your items have been added.'**
  String get storePurchaseSuccess;

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
  /// **'Coins, levels, decorations and story progress will be erased. This can\'t be undone.'**
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
