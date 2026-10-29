// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Sugarleaf Bakery';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Huỷ';

  @override
  String get commonConfirm => 'Đồng ý';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonContinue => 'Tiếp tục';

  @override
  String get commonDone => 'Xong';

  @override
  String get commonBuy => 'Mua';

  @override
  String get commonClaim => 'Nhận';

  @override
  String get commonClaimed => 'Đã nhận';

  @override
  String get commonLocked => 'Chưa mở';

  @override
  String get commonMax => 'Tối đa';

  @override
  String commonUnlockAtLevel(int level) {
    return 'Mở ở cấp $level';
  }

  @override
  String commonLevelShort(int level) {
    return 'Cấp $level';
  }

  @override
  String commonCoins(int count) {
    return '$count xu';
  }

  @override
  String commonGems(int count) {
    return '$count kim cương';
  }

  @override
  String get commonNotEnoughCoins => 'Không đủ xu';

  @override
  String get commonNotEnoughGems => 'Không đủ kim cương';

  @override
  String get commonWatchAd => 'Xem quảng cáo';

  @override
  String get rotateDevicePrompt => 'Hãy xoay ngang thiết bị nhé';

  @override
  String get levelUpTitle => 'Lên cấp!';

  @override
  String get menuTagline => 'Tiệm bánh nhỏ xinh bên bờ biển';

  @override
  String get menuPlay => 'Mở cửa tiệm';

  @override
  String menuDayLabel(int day) {
    return 'Ngày $day';
  }

  @override
  String get menuRecipeBook => 'Sổ công thức';

  @override
  String get menuUpgrades => 'Nâng cấp';

  @override
  String get menuDecor => 'Trang trí';

  @override
  String get menuStore => 'Cửa hàng';

  @override
  String get menuSettings => 'Cài đặt';

  @override
  String get menuQuests => 'Nhiệm vụ ngày';

  @override
  String get menuLoginGift => 'Quà hằng ngày';

  @override
  String menuShopLevel(int level) {
    return 'Tiệm cấp $level';
  }

  @override
  String menuXpProgress(int current, int target) {
    return '$current/$target XP';
  }

  @override
  String get menuXpMax => 'Cấp tối đa';

  @override
  String dayStartTitle(int day) {
    return 'Ngày $day';
  }

  @override
  String dayCustomersToday(int count) {
    return 'Hôm nay có $count khách ghé';
  }

  @override
  String dayCustomerProgress(int current, int total) {
    return 'Khách $current/$total';
  }

  @override
  String get dayOrderTitle => 'Đơn hàng';

  @override
  String get dayOrderFrosting => 'Kem phủ';

  @override
  String get dayOrderToppings => 'Topping';

  @override
  String get dayOrderBox => 'Hộp';

  @override
  String get dayStartBaking => 'Bắt đầu làm bánh';

  @override
  String get dayNextCustomer => 'Khách tiếp theo';

  @override
  String get dayRemakeWithAd => 'Làm lại (xem QC)';

  @override
  String get dayRemakeLine => 'Không sao, mình đợi cái mới nhé!';

  @override
  String get dayExitConfirmTitle => 'Tạm rời tiệm?';

  @override
  String get dayExitConfirmBody =>
      'Xu đã kiếm vẫn được giữ, nhưng hôm nay sẽ không tính là hoàn thành.';

  @override
  String get dayRainy => 'Ngày mưa';

  @override
  String get customerRegular => 'Khách';

  @override
  String get customerVip => 'Khách VIP';

  @override
  String get customerVipBadge => 'VIP';

  @override
  String get customerFriendBadge => 'Khách quen';

  @override
  String resultPaid(int amount) {
    return 'Trả $amount';
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
    return 'Cần cải thiện: $station';
  }

  @override
  String get mochiName => 'Mochi';

  @override
  String get mochiArriveFirst =>
      'Một chú mèo nhỏ ướt sũng đang trú mưa trước cửa tiệm…';

  @override
  String get mochiArriveAgain => 'Mochi lại ghé trú mưa!';

  @override
  String get mochiLook => 'Mochi nhìn bạn, đuôi khẽ ve vẩy.';

  @override
  String get mochiPet => 'Vuốt ve';

  @override
  String get mochiRest => 'Để Mochi nghỉ';

  @override
  String get mochiPetThanks => 'Mochi rừ rừ vui vẻ!';

  @override
  String get mochiNap => 'Mochi cuộn tròn ngủ bên lò sưởi.';

  @override
  String mochiGift(int coins, int gems) {
    String _temp0 = intl.Intl.pluralLogic(
      gems,
      locale: localeName,
      other: 'Mochi tặng bạn $coins xu và $gems kim cương!',
      zero: 'Mochi tặng bạn $coins xu!',
    );
    return '$_temp0';
  }

  @override
  String orderLine1(String item) {
    return 'Chào bạn! Cho mình một $item nhé.';
  }

  @override
  String orderLine2(String item) {
    return 'Cả ngày nay mình thèm $item lắm!';
  }

  @override
  String orderLine3(String item) {
    return 'Bạn làm giúp mình một $item được không?';
  }

  @override
  String orderLine4(String item) {
    return 'Một $item mang đi, cảm ơn nha!';
  }

  @override
  String orderLine5(String item) {
    return 'Hôm nay muốn ăn gì ngọt ngọt... $item nhé!';
  }

  @override
  String orderLine6(String item) {
    return 'Bạn mình khen $item ở đây ngon lắm.';
  }

  @override
  String orderLineVip(String item) {
    return 'Cho tôi một $item, gói hộp quà đẹp nhất nhé.';
  }

  @override
  String orderLineHoa(String item) {
    return 'Như mọi khi nhé cháu: một $item.';
  }

  @override
  String orderLineLinh(String item) {
    return 'Ui, $item! Làm thật xinh giúp em nha!';
  }

  @override
  String orderLineKenji(String item) {
    return 'Hôm nay là một ngày hợp với $item.';
  }

  @override
  String get fbAllGood => 'Hoàn hảo! Đúng như mình tưởng tượng!';

  @override
  String get fbMouldGood => 'Hình dáng xinh quá!';

  @override
  String get fbMixGood => 'Mềm xốp quá đi!';

  @override
  String get fbBakeGood => 'Nướng vàng ươm hoàn hảo!';

  @override
  String get fbFrostGood => 'Lớp kem mịn màng quá!';

  @override
  String get fbToppingGood => 'Topping chuẩn y như mình gọi!';

  @override
  String get fbBoxGood => 'Lại còn gói đẹp nữa!';

  @override
  String get fbMouldWrong => 'Ơ, hình dáng không giống mình nghĩ.';

  @override
  String get fbMixUnder => 'Bánh hơi lợn cợn, chưa mịn.';

  @override
  String get fbMixOver => 'Bánh hơi chặt và dai.';

  @override
  String get fbBakeUnder => 'Bên trong vẫn còn hơi sống!';

  @override
  String get fbBakeBurnt => 'Ôi, bánh hơi cháy rồi!';

  @override
  String get fbFrostPatchy => 'Lớp kem phủ bị lem nhem.';

  @override
  String get fbToppingMissing => 'Hình như thiếu topping rồi.';

  @override
  String get fbToppingWrong => 'Đây không phải topping mình gọi.';

  @override
  String get fbBoxWrong => 'Ơ, hộp này không đúng rồi.';

  @override
  String get stationMould => 'Khuôn';

  @override
  String get stationMix => 'Trộn bột';

  @override
  String get stationBake => 'Nướng';

  @override
  String get stationFrost => 'Phủ kem';

  @override
  String get stationTopping => 'Trang trí';

  @override
  String get stationBox => 'Đóng hộp';

  @override
  String get hintMould => 'Kéo đúng khuôn vào khay';

  @override
  String get hintMix => 'Xoay vòng quanh tô, dừng khi vào vùng xanh';

  @override
  String get hintBake => 'Nhấn giữ để nướng, thả tay ở vùng vàng';

  @override
  String get hintFrost => 'Vẽ theo nét chấm để phủ kem';

  @override
  String get hintTopping => 'Kéo topping lên bánh';

  @override
  String get hintBox => 'Kéo bánh vào đúng hộp';

  @override
  String gameStepProgress(int current, int total) {
    return 'Bước $current/$total';
  }

  @override
  String get gameHold => 'Giữ';

  @override
  String get gameTapToRemove => 'Chạm vào topping để gỡ ra';

  @override
  String get gameWrongMould => 'Không phải khuôn này!';

  @override
  String get gameTutorialGotIt => 'Đã hiểu!';

  @override
  String get mouldCupcakeLiner => 'Cốc giấy cupcake';

  @override
  String get mouldMuffinCup => 'Cốc muffin';

  @override
  String get mouldTartShell => 'Đế tart';

  @override
  String get mouldRoundPan => 'Khuôn tròn';

  @override
  String get mouldMacaronMat => 'Thảm macaron';

  @override
  String get mouldSpringformPan => 'Khuôn đáy rời';

  @override
  String get mouldTallPan => 'Khuôn tầng cao';

  @override
  String get batterVanilla => 'Bột vani';

  @override
  String get batterChocolate => 'Bột chocolate';

  @override
  String get batterRedVelvet => 'Bột red velvet';

  @override
  String get batterMatcha => 'Bột matcha';

  @override
  String get batterButter => 'Bột bơ làm vỏ';

  @override
  String get batterAlmond => 'Bột hạnh nhân';

  @override
  String get batterCheese => 'Bột phô mai';

  @override
  String get frostingVanillaCream => 'Kem vani';

  @override
  String get frostingChocolateGanache => 'Ganache chocolate';

  @override
  String get frostingStrawberryCream => 'Kem dâu';

  @override
  String get frostingMatchaCream => 'Kem matcha';

  @override
  String get frostingCreamCheese => 'Kem phô mai';

  @override
  String get frostingCustard => 'Nhân trứng sữa';

  @override
  String get toppingSprinkles => 'Cốm màu';

  @override
  String get toppingStrawberry => 'Dâu tây';

  @override
  String get toppingCherry => 'Anh đào';

  @override
  String get toppingChocolateChips => 'Chocolate chip';

  @override
  String get toppingBlueberry => 'Việt quất';

  @override
  String get toppingMintLeaf => 'Lá bạc hà';

  @override
  String get toppingSugarPearl => 'Ngọc đường';

  @override
  String get toppingCandle => 'Nến';

  @override
  String get boxSmall => 'Hộp nhỏ';

  @override
  String get boxCake => 'Hộp bánh kem';

  @override
  String get boxGift => 'Hộp quà';

  @override
  String get recipeCupcakeVanilla => 'Cupcake vani';

  @override
  String get recipeCupcakeVanillaDesc =>
      'Cốt vani xốp mềm, phủ một đám mây kem.';

  @override
  String get recipeCupcakeChocolate => 'Cupcake chocolate';

  @override
  String get recipeCupcakeChocolateDesc =>
      'Cốt cacao đậm đà, ganache bóng mượt.';

  @override
  String get recipeMuffinBlueberry => 'Muffin việt quất';

  @override
  String get recipeMuffinBlueberryDesc => 'Muffin vàng ươm, mọng việt quất.';

  @override
  String get recipeEggTart => 'Tart trứng';

  @override
  String get recipeEggTartDesc =>
      'Vỏ giòn tan, nhân trứng mịn. Món bà thích nhất.';

  @override
  String get recipeStrawberryCake => 'Bánh kem dâu';

  @override
  String get recipeStrawberryCakeDesc => 'Bánh mềm cùng lớp kem dâu tươi.';

  @override
  String get recipeMacaron => 'Macaron';

  @override
  String get recipeMacaronDesc => 'Vỏ hạnh nhân giòn, nhân ngọt dịu.';

  @override
  String get recipeRedVelvetCupcake => 'Cupcake red velvet';

  @override
  String get recipeRedVelvetCupcakeDesc =>
      'Cốt đỏ mịn như nhung, kem phô mai chua nhẹ.';

  @override
  String get recipeMatchaCake => 'Bánh kem matcha';

  @override
  String get recipeMatchaCakeDesc => 'Bánh trà xanh dịu nhẹ, ngọt vừa phải.';

  @override
  String get recipeCheesecake => 'Bánh phô mai';

  @override
  String get recipeCheesecakeDesc => 'Béo mịn, đậm vị, nướng chậm lửa nhỏ.';

  @override
  String get recipeBirthdayCake => 'Bánh sinh nhật tầng';

  @override
  String get recipeBirthdayCakeDesc =>
      'Cao tầng, rực rỡ, dành cho những điều ước.';

  @override
  String get charMai => 'Mai';

  @override
  String get charHoa => 'Ông Hòa';

  @override
  String get charLinh => 'Linh';

  @override
  String get charKenji => 'Kenji';

  @override
  String get storyChapter1Title => 'Chương 1: Tiệm bánh bên bờ biển';

  @override
  String get storyTapToContinue => 'Chạm để tiếp tục';

  @override
  String get storySkip => 'Bỏ qua';

  @override
  String get storyPrologue1 =>
      'Một thị trấn ven biển yên bình. Một tiệm bánh nhỏ với tấm biển đã bạc màu: Sugarleaf.';

  @override
  String get storyPrologue2 =>
      'Bà ơi, cháu về rồi... Từ nay cháu sẽ chăm lo tiệm bánh của bà.';

  @override
  String get storyPrologue3 =>
      'Sổ công thức của bà! Nhưng thiếu nhiều trang quá...';

  @override
  String get storyPrologue4 => 'Bắt đầu từ món đơn giản thôi. Cupcake nào!';

  @override
  String get storyHoa1Line1 =>
      'Tiệm Sugarleaf lại sáng đèn rồi. Cháu là bé Mai phải không?';

  @override
  String get storyHoa1Line2 => 'Dạ! Ông quen bà cháu ạ?';

  @override
  String get storyHoa1Line3 =>
      'Chủ nhật nào ông cũng ghé, suốt bốn mươi năm. Tart trứng của bà... ông vẫn nhớ mãi.';

  @override
  String get storyHoa1Line4 => 'Vậy cháu sẽ học làm cho ông. Cháu hứa đấy ạ!';

  @override
  String get storyLinh1Line1 =>
      'Chào chị! Em là Linh, học trường mỹ thuật trên đồi.';

  @override
  String get storyLinh1Line2 =>
      'Em vẽ lại mọi chiếc bánh em ăn. Tiệm chị dễ thương xỉu luôn!';

  @override
  String get storyLinh1Line3 =>
      'Vậy chị phải làm bánh thật xinh cho em vẽ rồi!';

  @override
  String get storyHoa2Line1 =>
      'Ông Hòa ơi! Hôm nay cháu tìm được trang tart trứng rồi.';

  @override
  String get storyHoa2Line2 =>
      'Vậy hôm nay là ngày đẹp trời. Để xem tay cháu có nhớ bà không nào.';

  @override
  String get storyHoa2Line3 => 'Cháu sẽ cố hết sức!';

  @override
  String get storyKenji1Line1 =>
      'Xin chào. Tôi là Kenji. Tôi đi khắp nơi chụp ảnh những thị trấn nhỏ.';

  @override
  String get storyKenji1Line2 =>
      'Tôi không chắc mình muốn gì. Món gì đó giống một buổi sáng đầy nắng?';

  @override
  String get storyKenji1Line3 => 'Buổi sáng đầy nắng... Chắc là bánh kem dâu!';

  @override
  String get storyLinh2Line1 =>
      'Chị Mai ơi, chị làm macaron được không? Em mê vẽ macaron nhất!';

  @override
  String get storyLinh2Line2 => 'Món này khó lắm... nhưng mình cùng thử nhé.';

  @override
  String get storyLinh2Line3 => 'Yeah! Chị làm bánh, em ngồi ký họa!';

  @override
  String get storyKenji2Line1 =>
      'Sáng mai tôi sẽ leo ngọn hải đăng lúc bình minh. Tôi cần chút can đảm.';

  @override
  String get storyKenji2Line2 =>
      'Can đảm thì đậm đà và ngọt nhẹ. Red velvet nhé!';

  @override
  String get storyKenji2Line3 => 'Cô đọc cảm xúc như đọc công thức vậy.';

  @override
  String get storyHoa3Line1 =>
      'Ông mang cái này đến. Năm xưa bà nhờ ông giữ hộ trang này.';

  @override
  String get storyHoa3Line2 => 'Chữ của bà... Cháu cảm ơn ông.';

  @override
  String get storyHoa3Line3 => 'Nó thuộc về căn bếp này. Cũng như cháu vậy.';

  @override
  String get storyLinh3Line1 =>
      'Chị xem! Tranh em vẽ tiệm chị được giải ở trường đó!';

  @override
  String get storyLinh3Line2 => 'Đẹp quá Linh ơi! Chị treo cạnh cửa sổ nhé?';

  @override
  String get storyLinh3Line3 =>
      'Với điều kiện mình ăn mừng bằng bánh kem matcha!';

  @override
  String get storyKenji3Line1 =>
      'Ảnh tôi chụp thị trấn này sẽ được trưng bày ở Tokyo.';

  @override
  String get storyKenji3Line2 =>
      'Tôi muốn nhớ về nơi này bằng một món dịu dàng mà đậm vị.';

  @override
  String get storyKenji3Line3 =>
      'Vậy là cheesecake, thêm việt quất xanh như biển.';

  @override
  String get storyFinaleLine1 =>
      'Ông Hòa, Linh, Kenji... tiệm bánh lại rộn ràng như xưa.';

  @override
  String get storyFinaleLine2 =>
      'Sổ của bà vẫn còn những trang trống. Cháu sẽ viết tiếp, từng trang một.';

  @override
  String get storyFinaleLine3 =>
      'Hoàn thành chương 1. Câu chuyện sẽ còn tiếp tục!';

  @override
  String summaryTitle(int day) {
    return 'Hoàn thành ngày $day!';
  }

  @override
  String get summaryCustomers => 'Khách đã phục vụ';

  @override
  String get summaryAvgStars => 'Đánh giá trung bình';

  @override
  String get summaryRevenue => 'Doanh thu';

  @override
  String get summaryTips => 'Tiền tip';

  @override
  String get summaryCosts => 'Nguyên liệu';

  @override
  String get summaryNet => 'Tổng thu';

  @override
  String get summaryXp => 'XP nhận được';

  @override
  String summaryDayBonusXp(int xp) {
    return 'Thưởng cuối ngày +$xp XP';
  }

  @override
  String get summaryRainyDay => 'Ngày mưa — Mochi ghé chơi';

  @override
  String get summaryDouble => 'Nhân đôi xu (xem QC)';

  @override
  String get summaryDoubled => 'Đã nhân đôi xu!';

  @override
  String summaryLevelUp(int level) {
    return 'Lên cấp! Tiệm cấp $level';
  }

  @override
  String get summaryNewUnlocks => 'Mở khoá mới';

  @override
  String unlockRecipe(String name) {
    return 'Công thức mới: $name';
  }

  @override
  String unlockTopping(String name) {
    return 'Topping mới: $name';
  }

  @override
  String get unlockVipGuests => 'Khách VIP bắt đầu ghé tiệm!';

  @override
  String get unlockUpgrades => 'Có nâng cấp mới';

  @override
  String get unlockDecor => 'Có đồ trang trí mới';

  @override
  String get unlockMoreCustomers => 'Mỗi ngày có thêm khách';

  @override
  String get upgradesTitle => 'Nâng cấp';

  @override
  String get upgradeOven => 'Lò nướng';

  @override
  String get upgradeOvenDesc => 'Vùng vàng khi nướng rộng hơn';

  @override
  String upgradeOvenPerfectZone(int percent) {
    return 'Vùng hoàn hảo ±$percent%';
  }

  @override
  String get upgradeWhisk => 'Phới lồng';

  @override
  String get upgradeWhiskDesc => 'Vùng xanh khi trộn rộng hơn';

  @override
  String get upgradePipingBag => 'Túi bắt kem';

  @override
  String get upgradePipingBagDesc => 'Nét kem to hơn';

  @override
  String get upgradeTongs => 'Kẹp gắp bánh';

  @override
  String get upgradeTongsDesc => 'Topping dễ đặt lên bánh hơn';

  @override
  String upgradeLevelOf(int current, int max) {
    return 'Cấp $current/$max';
  }

  @override
  String get upgradeBuy => 'Nâng cấp';

  @override
  String get upgradeMaxed => 'Đã nâng tối đa';

  @override
  String get upgradeDone => 'Đã nâng cấp!';

  @override
  String get decorTitle => 'Trang trí tiệm';

  @override
  String get decorSlotWallpaper => 'Giấy dán tường';

  @override
  String get decorSlotFloor => 'Sàn nhà';

  @override
  String get decorSlotCounter => 'Quầy';

  @override
  String get decorSlotWindow => 'Cửa sổ';

  @override
  String get decorSlotPlant => 'Cây xanh';

  @override
  String get decorDefault => 'Cơ bản';

  @override
  String get decorWallpaperStripes => 'Sọc kem';

  @override
  String get decorWallpaperFloral => 'Giấy hoa nhí';

  @override
  String get decorFloorCheckered => 'Gạch caro';

  @override
  String get decorFloorHerringbone => 'Sàn gỗ xương cá';

  @override
  String get decorCounterFlowers => 'Bình hoa';

  @override
  String get decorCounterCakeStand => 'Kệ bánh nhiều tầng';

  @override
  String get decorWindowCurtains => 'Rèm ren';

  @override
  String get decorWindowSeaView => 'Cửa sổ hướng biển';

  @override
  String get decorPlantFern => 'Cây dương xỉ';

  @override
  String get decorPlantLemonTree => 'Cây chanh';

  @override
  String decorTipBonus(int percent) {
    return '+$percent% tip';
  }

  @override
  String decorTotalBonus(int percent) {
    return 'Tổng thưởng tip: +$percent%';
  }

  @override
  String get decorEquip => 'Đặt';

  @override
  String get decorEquipped => 'Đang dùng';

  @override
  String get recipesTitle => 'Sổ công thức';

  @override
  String recipesPrice(int amount) {
    return 'Giá: $amount';
  }

  @override
  String get recipesIngredients => 'Nguyên liệu';

  @override
  String get recipesMastery => 'Thành thạo';

  @override
  String get recipesMasteryHint =>
      'Phục vụ 1 lần, đạt 4 sao rồi 5 sao để thành thạo';

  @override
  String recipesMasteryReward(int gems) {
    return 'Thành thạo! +$gems kim cương';
  }

  @override
  String recipesMissingPage(int level) {
    return 'Trang còn thiếu. Mở ở cấp $level';
  }

  @override
  String get questsTitle => 'Nhiệm vụ ngày';

  @override
  String questServeCustomers(int count) {
    return 'Phục vụ $count khách';
  }

  @override
  String questEarnStars(int count) {
    return 'Đạt $count sao';
  }

  @override
  String questPerfectBakes(int count) {
    return 'Nướng hoàn hảo $count lần';
  }

  @override
  String questFiveStarTreats(int count) {
    return 'Phục vụ $count bánh 5 sao';
  }

  @override
  String questEarnCoins(int count) {
    return 'Kiếm $count xu';
  }

  @override
  String questEarnTips(int count) {
    return 'Nhận $count xu tiền tip';
  }

  @override
  String questProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get questsResetHint => 'Mỗi ngày có nhiệm vụ mới';

  @override
  String get questsAllDone => 'Hôm nay xong hết rồi!';

  @override
  String get loginTitle => 'Quà hằng ngày';

  @override
  String loginDay(int day) {
    return 'Ngày $day';
  }

  @override
  String get loginComeBack => 'Mai nhớ quay lại nhận tiếp nhé!';

  @override
  String get storeTitle => 'Cửa hàng';

  @override
  String get storeSimulatedNotice =>
      'Cửa hàng thử nghiệm: giao dịch là giả lập, không trừ tiền thật.';

  @override
  String get storeStarterPack => 'Gói khởi đầu';

  @override
  String storeStarterPackDesc(int coins, int gems) {
    return '$coins xu + $gems kim cương';
  }

  @override
  String get storePantryS => 'Gói nguyên liệu S';

  @override
  String get storePantryM => 'Gói nguyên liệu M';

  @override
  String get storePantryL => 'Gói nguyên liệu L';

  @override
  String storePantryDesc(int coins) {
    return '$coins xu mua nguyên liệu';
  }

  @override
  String get storeDecorSet => 'Bộ trang trí biển xanh';

  @override
  String get storeDecorSetDesc => '3 món trang trí đặc biệt';

  @override
  String get storeRemoveAds => 'Xoá quảng cáo';

  @override
  String get storeRemoveAdsDesc =>
      'Không còn quảng cáo giữa các ngày. Quảng cáo nhận thưởng vẫn tuỳ bạn.';

  @override
  String storeFreeGem(int gems) {
    return 'Xem quảng cáo nhận $gems kim cương';
  }

  @override
  String get storeOwned => 'Đã sở hữu';

  @override
  String get storeConfirmTitle => 'Mua giả lập';

  @override
  String storeConfirmBody(String item, String price) {
    return 'Mua $item giá $price? Không trừ tiền thật.';
  }

  @override
  String get storePurchaseSuccess => 'Cảm ơn bạn! Đã nhận vật phẩm.';

  @override
  String get adsLimitReached => 'Hôm nay đã hết lượt nhận thưởng';

  @override
  String get adSimulatedTitle => 'Quảng cáo (giả lập)';

  @override
  String get adSimulatedBody => 'Bản phát hành sẽ hiện quảng cáo thật ở đây.';

  @override
  String adSimulatedClosing(int seconds) {
    return 'Đóng sau $seconds giây';
  }

  @override
  String get adRewardGranted => 'Đã nhận thưởng!';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsLanguageSystem => 'Theo máy';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageVi => 'Tiếng Việt';

  @override
  String get settingsSound => 'Âm thanh';

  @override
  String get settingsOn => 'Bật';

  @override
  String get settingsOff => 'Tắt';

  @override
  String get settingsResetData => 'Xoá dữ liệu game';

  @override
  String get settingsResetConfirmTitle => 'Xoá toàn bộ tiến trình?';

  @override
  String get settingsResetConfirmBody =>
      'Xu, cấp, đồ trang trí và tiến trình truyện sẽ bị xoá. Không thể hoàn tác.';

  @override
  String get settingsResetDone => 'Đã xoá dữ liệu game';

  @override
  String settingsVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get settingsAlphaNote => 'Bản alpha. Cảm ơn bạn đã chơi thử!';
}
