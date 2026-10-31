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

  /// No description provided for @recipeSecretsTitle.
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s secrets'**
  String get recipeSecretsTitle;

  /// No description provided for @recipeSecretsLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after level {level}'**
  String recipeSecretsLocked(int level);

  /// No description provided for @recipeSecretsTier.
  ///
  /// In en, this message translates to:
  /// **'Secret {tier}/{max}'**
  String recipeSecretsTier(int tier, int max);

  /// No description provided for @recipeSecretsBonus.
  ///
  /// In en, this message translates to:
  /// **'+{pct}% price'**
  String recipeSecretsBonus(int pct);

  /// No description provided for @recipeSecretsBuy.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get recipeSecretsBuy;

  /// No description provided for @recipeSecretsMaxed.
  ///
  /// In en, this message translates to:
  /// **'All secrets learned'**
  String get recipeSecretsMaxed;

  /// No description provided for @recipeSecretsRecipeLocked.
  ///
  /// In en, this message translates to:
  /// **'Find this recipe first'**
  String get recipeSecretsRecipeLocked;

  /// No description provided for @recipeSecretsHint.
  ///
  /// In en, this message translates to:
  /// **'Each secret makes this treat sell for more.'**
  String get recipeSecretsHint;

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

  /// Store: prominent stamp in the top corner next to the test notice banner.
  ///
  /// In en, this message translates to:
  /// **'Test mode'**
  String get storeTestMode;

  /// Store: description of gem pack S/M/L.
  ///
  /// In en, this message translates to:
  /// **'{gems} gems'**
  String storeGemsDesc(int gems);

  /// Store: description of the V2 starter pack.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins + {gems} gems + every booster ×{count}'**
  String storeStarterPackDescV2(int coins, int gems, int count);

  /// Store: highlight badge on the starter pack card. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Best deal'**
  String get storeStarterBadge;

  /// Store: description of the Remove ads pack (V2).
  ///
  /// In en, this message translates to:
  /// **'No more ads between levels. Reward ads stay optional.'**
  String get storeRemoveAdsDescV2;

  /// Store: description of the staff outfits pack.
  ///
  /// In en, this message translates to:
  /// **'Festival looks for Nora and Bao. Looks only — switch it in Staff.'**
  String get storeStaffOutfitsDesc;

  /// Store: description of the season pass pack.
  ///
  /// In en, this message translates to:
  /// **'Unlock the premium rewards of this season.'**
  String get storeSeasonPassDesc;

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

  /// Settings: label of the purchases row.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get settingsPurchases;

  /// Settings: button that restores purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestore;

  /// Settings: success toast after restoring (count >= 1).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 purchase} other{Restored {count} purchases}}'**
  String settingsRestoreDone(int count);

  /// Settings: toast when there is nothing to restore.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore'**
  String get settingsRestoreNone;

  /// Settings: toast when restoring fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore right now. Please try again later.'**
  String get settingsRestoreFailed;

  /// No description provided for @levelMenuButton.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get levelMenuButton;

  /// Chapter label under the chapter name banner in the level list
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter}'**
  String levelChapterLabel(int chapter);

  /// Level number banner on the Ready card, pause, result, and screen-reader label of a level tile
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelNumber(int level);

  /// No description provided for @levelNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get levelNewBadge;

  /// No description provided for @levelSpecialBadge.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get levelSpecialBadge;

  /// No description provided for @levelGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get levelGoalLabel;

  /// Coin goal (1-star threshold) on the Ready card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Earn 1 coin} other{Earn {count} coins}}'**
  String levelGoalCoins(int count);

  /// Customer goal on the Ready card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Serve 1 customer} other{Serve {count} customers}}'**
  String levelGoalCustomers(int count);

  /// Special order goal; only orders rated 3 stars or higher count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Finish 1 special order (3 stars or more)} other{Finish {count} special orders (3 stars or more)}}'**
  String levelGoalSpecials(int count);

  /// No description provided for @levelTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get levelTimeLabel;

  /// No description provided for @levelMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'On the menu'**
  String get levelMenuLabel;

  /// No description provided for @levelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get levelStart;

  /// No description provided for @levelPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get levelPause;

  /// No description provided for @levelRush.
  ///
  /// In en, this message translates to:
  /// **'Rush hour!'**
  String get levelRush;

  /// Text on the HUD goal bar and the goal line of the result screen
  ///
  /// In en, this message translates to:
  /// **'{value}/{target}'**
  String levelGoalProgress(int value, int target);

  /// HUD combo label; mult is an already formatted multiplier such as 1.3
  ///
  /// In en, this message translates to:
  /// **'Combo ×{mult}'**
  String levelCombo(String mult);

  /// No description provided for @levelPauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get levelPauseTitle;

  /// No description provided for @levelPauseBody.
  ///
  /// In en, this message translates to:
  /// **'Take a breather — your customers will wait.'**
  String get levelPauseBody;

  /// No description provided for @levelQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get levelQuit;

  /// No description provided for @levelReplay.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get levelReplay;

  /// No description provided for @levelTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up!'**
  String get levelTimeUp;

  /// Title of the extra time dialog
  ///
  /// In en, this message translates to:
  /// **'+{seconds} seconds?'**
  String levelExtraTimeTitle(int seconds);

  /// No description provided for @levelExtraTimeBody.
  ///
  /// In en, this message translates to:
  /// **'So close! Watch a short ad to keep the shop open a little longer.'**
  String get levelExtraTimeBody;

  /// Accept button of the extra time dialog
  ///
  /// In en, this message translates to:
  /// **'Watch ad (+{seconds}s)'**
  String levelExtraTimeWatch(int seconds);

  /// No description provided for @levelExtraTimeNo.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get levelExtraTimeNo;

  /// No description provided for @levelSpecialLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get levelSpecialLater;

  /// No description provided for @levelSpecialQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this order?'**
  String get levelSpecialQuitTitle;

  /// No description provided for @levelSpecialQuitBody.
  ///
  /// In en, this message translates to:
  /// **'The customer will keep waiting — you can come back to it.'**
  String get levelSpecialQuitBody;

  /// No description provided for @levelResultWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Level complete!'**
  String get levelResultWinTitle;

  /// No description provided for @levelResultLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'So close — let\'s try again!'**
  String get levelResultLoseTitle;

  /// Goal line below the stars on the result screen; progress is the formatted levelGoalProgress text
  ///
  /// In en, this message translates to:
  /// **'Goal: {progress}'**
  String levelResultGoal(String progress);

  /// No description provided for @levelResultCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins earned'**
  String get levelResultCoins;

  /// No description provided for @levelResultServed.
  ///
  /// In en, this message translates to:
  /// **'Happy customers'**
  String get levelResultServed;

  /// No description provided for @levelResultLost.
  ///
  /// In en, this message translates to:
  /// **'Customers who left'**
  String get levelResultLost;

  /// No description provided for @levelResultSpecials.
  ///
  /// In en, this message translates to:
  /// **'Special orders'**
  String get levelResultSpecials;

  /// No description provided for @levelResultBestCombo.
  ///
  /// In en, this message translates to:
  /// **'Best combo'**
  String get levelResultBestCombo;

  /// No description provided for @levelResultFiveStar.
  ///
  /// In en, this message translates to:
  /// **'5-star treats'**
  String get levelResultFiveStar;

  /// Result screen: one-time button, only when coins > 0.
  ///
  /// In en, this message translates to:
  /// **'×2 coins (watch ad)'**
  String get levelResultDoubleCoins;

  /// Result screen: toast after the ad. coins is the extra coins added.
  ///
  /// In en, this message translates to:
  /// **'Coins doubled! +{coins}'**
  String levelResultDoubled(int coins);

  /// No description provided for @levelNext.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get levelNext;

  /// No description provided for @levelList.
  ///
  /// In en, this message translates to:
  /// **'Level list'**
  String get levelList;

  /// Level play: the display case has no room for the boxed batch.
  ///
  /// In en, this message translates to:
  /// **'Case full!'**
  String get lvlCaseFull;

  /// Level play: banner when rush hour starts.
  ///
  /// In en, this message translates to:
  /// **'Rush hour!'**
  String get lvlRushHour;

  /// Level play: consecutive sales combo label.
  ///
  /// In en, this message translates to:
  /// **'Combo ×{count}'**
  String lvlCombo(int count);

  /// Level play, mix station: batch mixed, oven busy. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Waiting for oven'**
  String get lvlWaitOven;

  /// Level play, oven: taken out, frosting station still busy. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Waiting…'**
  String get lvlWaiting;

  /// Level play, mould station idle: tap a recipe card on the left. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Tap a treat'**
  String get lvlPickTreat;

  /// Level play, oven: the batch burnt.
  ///
  /// In en, this message translates to:
  /// **'Burnt!'**
  String get lvlBurnt;

  /// Level play, oven: needle in the golden zone, tap to take out. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Take out!'**
  String get lvlTakeOut;

  /// Level play, mix station hint: drag one full circle around the bowl. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Stir 1 turn'**
  String get lvlStirHint;

  /// Level play, frosting station hint: swipe across the cake. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Swipe across'**
  String get lvlSwipeHint;

  /// Ready card: small label above the row of 3 booster slots.
  ///
  /// In en, this message translates to:
  /// **'Boosters'**
  String get lvlBoosterTitle;

  /// Ready card: small button next to the booster row (once per attempt).
  ///
  /// In en, this message translates to:
  /// **'Watch ad: 1 free'**
  String get lvlBoosterAdFree;

  /// Ready card: label on a booster slot paid by the ad credit (replaces the price).
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get lvlBoosterFree;

  /// Ready card: hint after watching the ad when no slot is chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Pick a booster — one is free!'**
  String get lvlBoosterPickFree;

  /// Ready card: first-time intro bubble next to the booster row.
  ///
  /// In en, this message translates to:
  /// **'New! Boosters make a level easier. Here\'s one to try for free.'**
  String get lvlBoosterIntro;

  /// Ready card: screen reader label of the chosen booster slot.
  ///
  /// In en, this message translates to:
  /// **'{name}, selected'**
  String lvlBoosterSelected(String name);

  /// Level map: short label under the round season button in the top bar (max ~8 chars).
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get mapSeasonShort;

  /// Season pass screen title; tooltip of the map button.
  ///
  /// In en, this message translates to:
  /// **'Season pass'**
  String get seasonTitle;

  /// Season pass: time-left label. time comes from seasonDaysHours / seasonHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String seasonTimeLeft(String time);

  /// Season pass: time left, one day or more.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String seasonDaysHours(int days, int hours);

  /// Season pass: time left, under one day.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String seasonHoursMinutes(int hours, int minutes);

  /// Season pass: progress bar toward the next tier.
  ///
  /// In en, this message translates to:
  /// **'{points}/{need} points'**
  String seasonPoints(int points, int need);

  /// Season pass: progress bar when the last tier is reached.
  ///
  /// In en, this message translates to:
  /// **'{points} points · all tiers reached'**
  String seasonPointsMax(int points);

  /// Season pass: small line under the title.
  ///
  /// In en, this message translates to:
  /// **'+{star} points for each new star, +{win} for each win'**
  String seasonHowTo(int star, int win);

  /// Season pass: label of each tier column (also screen reader).
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String seasonTierLabel(int tier);

  /// Season pass: header of the free reward row.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get seasonFreeRow;

  /// Season pass: header of the premium reward row.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get seasonPremiumRow;

  /// Season pass: button that claims every pending reward.
  ///
  /// In en, this message translates to:
  /// **'Claim all'**
  String get seasonClaimAll;

  /// Season pass: toast after claiming.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Reward claimed!} other{{count} rewards claimed!}}'**
  String seasonClaimedToast(int count);

  /// Season pass: buy premium button. price is a fixed display price.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium · {price}'**
  String seasonBuyPremium(String price);

  /// Season pass: label replacing the buy button once owned.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocked'**
  String get seasonPremiumActive;

  /// Season pass: tooltip / screen reader label of a premium cell when not purchased.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium to claim'**
  String get seasonPremiumHint;

  /// Season pass: dialog text when the season ends.
  ///
  /// In en, this message translates to:
  /// **'The season has ended. Your unclaimed rewards were added automatically.'**
  String get seasonEnded;

  /// Season pass: shown when there is no season data.
  ///
  /// In en, this message translates to:
  /// **'No season is running right now.'**
  String get seasonNone;

  /// Season pass: tooltip name of the portrait frame reward.
  ///
  /// In en, this message translates to:
  /// **'Portrait frame'**
  String get seasonRewardFrame;

  /// Season pass: tooltip of a booster reward cell.
  ///
  /// In en, this message translates to:
  /// **'{name} ×{count}'**
  String seasonRewardBooster(String name, int count);

  /// Small HUD label under the goal bar: a special guest visits if enough customers are served before the deadline. who is the translated guest name, time is m:ss on the countdown clock.
  ///
  /// In en, this message translates to:
  /// **'{who} drops by if you serve {served}/{target} by {time}'**
  String levelSpecialCondition(String who, int served, int target, String time);

  /// Small HUD label: a special guest visits once enough customers are served, no deadline. who is the translated guest name.
  ///
  /// In en, this message translates to:
  /// **'{who} drops by after {served}/{target} served'**
  String levelSpecialConditionNoTime(String who, int served, int target);

  /// Toast when a special guest's visit is skipped because the deadline passed. who is the translated guest name.
  ///
  /// In en, this message translates to:
  /// **'{who} couldn\'t make it this time'**
  String levelSpecialSkipped(String who);

  /// Level map: screen-reader label of the total stars chip in the top bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String mapStarsTotal(int count);

  /// Level map: short label under the daily quests button (tooltip stays menuQuests). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Quests'**
  String get mapQuestsShort;

  /// Level map: short label under the daily gift button (tooltip stays menuLoginGift). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get mapGiftShort;

  /// Level map: tooltip of the previous chapter arrow button.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get mapPrevChapter;

  /// Level map: tooltip of the next chapter arrow button.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get mapNextChapter;

  /// Level map: screen-reader label of an unlocked level button, also used as the replay hint button label.
  ///
  /// In en, this message translates to:
  /// **'Level {level}: {stars} of 3 stars'**
  String mapLevelLabel(int level, int stars);

  /// Level map: screen-reader label of a locked level button.
  ///
  /// In en, this message translates to:
  /// **'Level {level}, locked'**
  String mapLevelLockedLabel(int level);

  /// Level map: toast shown when tapping a locked level button.
  ///
  /// In en, this message translates to:
  /// **'Finish the previous level to unlock this one!'**
  String get mapLevelLocked;

  /// Level map: title of the padlock card on a locked chapter page.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} is locked'**
  String mapChapterLockedTitle(int chapter);

  /// Level map: star requirement line on a locked chapter page; a star icon is drawn before the text.
  ///
  /// In en, this message translates to:
  /// **'Need {need} stars — you have {have}'**
  String mapChapterNeedStars(int need, int have);

  /// Level map: requirement line on a locked chapter page - clear the last level of the previous chapter.
  ///
  /// In en, this message translates to:
  /// **'Finish chapter {chapter} first'**
  String mapChapterNeedFinish(int chapter);

  /// Level map: hint on a locked chapter page when stars are not enough; shown with up to 3 low-star level buttons.
  ///
  /// In en, this message translates to:
  /// **'Replay levels with fewer stars to collect more'**
  String get mapChapterReplayHint;

  /// Level map: title of the dialog shown after the new chapter unlock animation.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} unlocked!'**
  String mapChapterUnlockedTitle(int chapter);

  /// Level map: body of the chapter unlocked dialog, below the chapter name.
  ///
  /// In en, this message translates to:
  /// **'New recipes and new faces are waiting in this part of town.'**
  String get mapChapterUnlockedBody;

  /// Level map: button that closes the chapter unlocked dialog. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get mapChapterUnlockedGo;

  /// Level result screen: button back to the level map (replaces levelList). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapBackToMap;

  /// Level map: message shown when levels.json failed to load (empty config).
  ///
  /// In en, this message translates to:
  /// **'The level map couldn\'t load. Please restart the game.'**
  String get mapLoadError;

  /// Upgrades / Decor screens: locked button text (replaces commonUnlockAtLevel); level is the level that must be cleared.
  ///
  /// In en, this message translates to:
  /// **'Clear level {level} to unlock'**
  String mapUnlockAfterLevel(int level);

  /// Recipe book: locked recipe (replaces recipesMissingPage); level is the first level that features the recipe.
  ///
  /// In en, this message translates to:
  /// **'Missing page. Reach level {level} to find it'**
  String mapRecipeFromLevel(int level);

  /// Recipe book: locked recipe that does not appear in any level yet.
  ///
  /// In en, this message translates to:
  /// **'Missing page. Coming in a later chapter'**
  String get mapRecipeLater;

  /// Level map: title of the dialog greeting returning players after the update.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get mapWelcomeTitle;

  /// Level map: body of the welcome-back dialog for returning players; announces the gift of coins and gems.
  ///
  /// In en, this message translates to:
  /// **'The bakery has a new look: play level by level on the town map. As a thank-you, here are {coins} coins and {gems} gems.'**
  String mapWelcomeBody(int coins, int gems);

  /// Upgrades screen: label of tab 1 (bakery expansions). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Expand the bakery'**
  String get upgTabExpansion;

  /// Upgrades screen: label of tab 2 (equipment tiers). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get upgTabEquipment;

  /// Upgrades screen: status label on an expansion card that was already bought.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get upgOwned;

  /// Upgrades screen: label on staff / rare decor cards that are not in this version yet.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get upgComingSoon;

  /// Upgrades screen: toast shown after buying an expansion.
  ///
  /// In en, this message translates to:
  /// **'Added to your bakery!'**
  String get upgExpansionDone;

  /// Upgrades screen: tier line of an equipment card (replaces upgradeLevelOf; 'Level' would be confused with map levels).
  ///
  /// In en, this message translates to:
  /// **'Tier {current}/{max}'**
  String upgTierOf(int current, int max);

  /// Upgrades screen: fast oven stat. seconds is an already formatted number such as 6.3 (6,3 in some locales).
  ///
  /// In en, this message translates to:
  /// **'Bakes in {seconds}s'**
  String upgStatOvenSec(String seconds);

  /// Upgrades screen: big tray stat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 cake per tray} other{{count} cakes per tray}}'**
  String upgStatBatch(int count);

  /// Upgrades screen: wide display case stat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 cake per case slot} other{{count} cakes per case slot}}'**
  String upgStatCaseSlot(int count);

  /// Upgrades screen: whisk stat (size of the good mixing zone).
  ///
  /// In en, this message translates to:
  /// **'Green zone {percent}%'**
  String upgStatMixZone(int percent);

  /// Upgrades screen: piping bag stat.
  ///
  /// In en, this message translates to:
  /// **'Frosting stroke {size}'**
  String upgStatStroke(int size);

  /// Upgrades screen: tongs stat (how far toppings snap into place).
  ///
  /// In en, this message translates to:
  /// **'Snap range {size}'**
  String upgStatSnap(int size);

  /// Upgrades screen: tongs stat at tier 1 (snap range is 0).
  ///
  /// In en, this message translates to:
  /// **'No snapping'**
  String get upgStatSnapNone;

  /// Upgrades screen: screen-reader label of the arrow between the current stat and the next tier stat. stat is one of the upgStat* strings.
  ///
  /// In en, this message translates to:
  /// **'Next: {stat}'**
  String upgStatNext(String stat);

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

  /// Level 'Ready' card: bakery summary part, joined with ' · '.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 case slot} other{{count} case slots}}'**
  String levelShopCase(int count);

  /// Level 'Ready' card: bakery summary part, joined with ' · '.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 oven} other{{count} ovens}}'**
  String levelShopOvens(int count);

  /// Level 'Ready' card: bakery summary part, joined with ' · '.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tray of 1} other{Tray of {count}}}'**
  String levelShopTray(int count);

  /// Upgrades screen: label of tab 3 (staff). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get upgTabStaff;

  /// Staff card: role label.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get staffRoleCashier;

  /// Staff card: role label.
  ///
  /// In en, this message translates to:
  /// **'Baker'**
  String get staffRoleBaker;

  /// Staff card: role label (the person who serves café tables).
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get staffRoleWaiter;

  /// Staff card: role label (the person who looks after the bakery while the player is away).
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get staffRoleManager;

  /// Staff card: label of stat row 1. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get staffStatSpeed;

  /// Staff card: label of stat row 2. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get staffStatSkill;

  /// Staff card: screen-reader label of the level dots row of one stat. stat is staffStatSpeed or staffStatSkill.
  ///
  /// In en, this message translates to:
  /// **'{stat} level {level} of {max}'**
  String staffStatLevel(String stat, int level, int max);

  /// Staff card: button that hires the staff member (shown next to the price). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get staffHire;

  /// Toast shown after hiring a staff member.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the team!'**
  String get staffHired;

  /// Staff card: screen-reader label of the button that upgrades one stat (the button itself only shows an arrow and the price). stat is staffStatSpeed or staffStatSkill.
  ///
  /// In en, this message translates to:
  /// **'Upgrade {stat}'**
  String staffUpgradeStat(String stat);

  /// Staff card: cashier Speed stat, shown as a 'before -> after' pair so keep it short. seconds is an already formatted number such as 3.2 (3,2 in some locales).
  ///
  /// In en, this message translates to:
  /// **'Sells every {seconds}s'**
  String staffCashierSpeed(String seconds);

  /// Staff card: cashier Skill stat, extra tips on sales the cashier handles; shown as a 'before -> after' pair so keep it short.
  ///
  /// In en, this message translates to:
  /// **'+{percent}% tips'**
  String staffCashierSkill(int percent);

  /// Staff card: baker Speed stat. seconds is an already formatted number such as 24 or 3.2.
  ///
  /// In en, this message translates to:
  /// **'A batch every {seconds}s'**
  String staffBakerSpeed(String seconds);

  /// Staff card: baker Skill stat, average star rating of the cakes. stars is an already formatted number such as 3.5 (3,5 in some locales). Do not use a star symbol.
  ///
  /// In en, this message translates to:
  /// **'Cakes around {stars} stars'**
  String staffBakerSkill(String stars);

  /// Staff card: server Speed stat. seconds is an already formatted number such as 3.2.
  ///
  /// In en, this message translates to:
  /// **'Serves every {seconds}s'**
  String staffWaiterSpeed(String seconds);

  /// Staff card: server Skill stat, extra patience of waiting guests.
  ///
  /// In en, this message translates to:
  /// **'Waiting guests +{percent}% patience'**
  String staffWaiterSkill(int percent);

  /// Staff card: manager Speed stat (income while the player is away). The number comes first so the 'before -> after' pair stays compact, e.g. '20% -> 25% of a level's coins per hour'.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of a level\'s coins per hour'**
  String staffManagerSpeed(int percent);

  /// Staff card: manager Skill stat, the maximum number of away hours that earn coins.
  ///
  /// In en, this message translates to:
  /// **'Counts up to {hours} hours away'**
  String staffManagerSkill(int hours);

  /// Staff card footer: the staff member is past the level gate but cannot be hired until an item is bought first (the server needs café tables). Replaces 'Reach level X to unlock'. item is the translated unlock name.
  ///
  /// In en, this message translates to:
  /// **'Needs {item} first'**
  String staffRequires(String item);

  /// Staff card: toggle label on Nora / Bao cards once the outfit pack is bought.
  ///
  /// In en, this message translates to:
  /// **'Festival outfit'**
  String get staffOutfitFestival;

  /// Level map: title of the away-income dialog.
  ///
  /// In en, this message translates to:
  /// **'While you were away'**
  String get offlineTitle;

  /// Away-income dialog: line under the manager portrait. name is the manager's name (from JSON); duration is one of the offlineDuration* strings.
  ///
  /// In en, this message translates to:
  /// **'{name} looked after the bakery for {duration}.'**
  String offlineBody(String name, String duration);

  /// Away-income dialog: note shown when the time away was cut to the manager's hour limit.
  ///
  /// In en, this message translates to:
  /// **'Counted {hours} hours (the manager\'s limit).'**
  String offlineCapped(int hours);

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

  /// Away-income dialog: screen-reader label of the coin amount line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You earned 1 coin} other{You earned {count} coins}}'**
  String offlineEarned(int count);

  /// Away-income dialog: button that collects the coins. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get offlineClaim;

  /// Away-income dialog: button that doubles the coins by watching a rewarded ad (hidden when no ads are left today).
  ///
  /// In en, this message translates to:
  /// **'x2 (watch ad)'**
  String get offlineDouble;

  /// Away-income dialog: toast after the rewarded ad is finished.
  ///
  /// In en, this message translates to:
  /// **'Coins doubled!'**
  String get offlineDoubled;

  /// Level 'Ready' card: label before the row of staff portraits.
  ///
  /// In en, this message translates to:
  /// **'Helping this level'**
  String get levelReadyStaff;

  /// Level 'Ready' card: screen-reader label of the staff portraits row. names are joined with ', '.
  ///
  /// In en, this message translates to:
  /// **'{names} will help this level'**
  String levelReadyStaffNames(String names);

  /// Opening scene: subtitle of scene 1 (morning kitchen).
  ///
  /// In en, this message translates to:
  /// **'One morning in a little seaside town…'**
  String get introLineKitchen;

  /// Opening scene: subtitle of scene 2 (glass cake case).
  ///
  /// In en, this message translates to:
  /// **'Grandma\'s cake case still shines like it always did.'**
  String get introLineCase;

  /// Opening scene: subtitle of scene 3 (shop door). Mai is the main character; Sugarleaf is the bakery name.
  ///
  /// In en, this message translates to:
  /// **'Mai flips the sign — Sugarleaf is open!'**
  String get introLineDoor;

  /// Opening scene: word painted on the wooden door sign after it is flipped. One short line, shown in big letters.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get introSignOpen;

  /// Short intro: small blinking hint line.
  ///
  /// In en, this message translates to:
  /// **'Tap to enter the bakery'**
  String get introTapToEnter;

  /// Opening scene: screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'Opening scene'**
  String get introSemantics;

  /// Level 1 tutorial bubble, step 1: points at the first customer. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'This customer wants this treat. Tap them to sell!'**
  String get lvlTutServe;

  /// Level 1 tutorial bubble, step 2: points at the cake card in the kitchen. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Tap a treat card to bake a fresh batch!'**
  String get lvlTutBake;

  /// Level 1 tutorial bubble: mould station. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Pick the right mould'**
  String get lvlTutMould;

  /// Level 1 tutorial bubble: mixing station (points at the bowl). Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Stir in circles to mix'**
  String get lvlTutMix;

  /// Level 1 tutorial bubble: oven. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Wait for the needle to hit the gold mark, then tap'**
  String get lvlTutOven;

  /// Level 1 tutorial bubble: frosting station. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Trace the frosting line'**
  String get lvlTutFrost;

  /// Level 1 tutorial bubble: topping station. count is the number of toppings needed (3 in level 1). Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tap the right jar once} other{Tap the right jar {count} times}}'**
  String lvlTutTopping(int count);

  /// Level 1 tutorial bubble: box station. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Pick the right box'**
  String get lvlTutBox;

  /// Level 1 tutorial bubble, last step; hides itself after 3 seconds. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Your treats are in the case. Now serve lots of customers!'**
  String get lvlTutCaseReady;

  /// Level 2 tutorial bubble: points at the combo meter on the HUD. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Sell back to back to grow your combo — more coins!'**
  String get lvlTutCombo;

  /// Level 2 tutorial bubble: shown the first time a second treat appears in an order bubble. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Each customer wants something different.'**
  String get lvlTutNewTreat;

  /// Level 3 tutorial bubble: shown when a customer's patience ring drops below 50%. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'The colored ring is their patience. Serve fast for tips!'**
  String get lvlTutPatience;

  /// Level 3 tutorial bubble: shown the first time a customer leaves. Keep short (small bubble).
  ///
  /// In en, this message translates to:
  /// **'Customers who wait too long will leave.'**
  String get lvlTutWalkout;

  /// Level 'Ready' card: reminder line under the goal, only on the level with the patience tutorial (level 3).
  ///
  /// In en, this message translates to:
  /// **'This level counts the coins you earn'**
  String get levelReadyCoinsHint;

  /// Settings: label of the row that holds the two buttons below.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get settingsGuide;

  /// Settings: button that replays the opening scene (returns to Settings afterwards). Keep short.
  ///
  /// In en, this message translates to:
  /// **'Replay opening'**
  String get settingsReplayIntro;

  /// Settings: button that turns the level 1-3 tutorials back on. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Replay tutorials'**
  String get settingsReplayTutorials;

  /// Settings: toast shown after tapping the replay tutorials button.
  ///
  /// In en, this message translates to:
  /// **'Tutorials will show again in Levels 1–3'**
  String get settingsTutorialsReset;

  /// Store: toast when a purchase attempt returns false (store, premium buy button on the Season pass).
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through.'**
  String get storePurchaseFailed;

  /// Store: description on the Season pass card when it can't be bought (no season running or already bought).
  ///
  /// In en, this message translates to:
  /// **'No season is running right now. Check back soon!'**
  String get storeSeasonNone;

  /// Level result: bonus row showing the Season pass points earned this run.
  ///
  /// In en, this message translates to:
  /// **'+{points} season points'**
  String levelResultSeasonPoints(int points);

  /// Level result: intro booster gift row (first time, up to level 4). name is the booster's display name.
  ///
  /// In en, this message translates to:
  /// **'Gift: {name} ×1'**
  String levelResultBoosterGift(String name);

  /// Pause dialog: shown when boosters were used and at least one treat was sold.
  ///
  /// In en, this message translates to:
  /// **'Boosters used in this run won\'t be refunded.'**
  String get levelPauseBoosterLost;

  /// Pause dialog: shown when boosters were used but nothing has been sold yet.
  ///
  /// In en, this message translates to:
  /// **'Quit or replay now and your boosters go back to your bag.'**
  String get levelPauseBoosterRefund;

  /// Small toast when Quit / Replay happens before the first sale (boosters refunded).
  ///
  /// In en, this message translates to:
  /// **'Boosters returned to your bag.'**
  String get levelBoostersRefunded;
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
