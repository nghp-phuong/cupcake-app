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
  String get mouldPastryTray => 'Khay bánh ngàn lớp';

  @override
  String get mouldShellMould => 'Khuôn vỏ sò';

  @override
  String get mouldEclairTray => 'Khay éclair';

  @override
  String get mouldPiePan => 'Đĩa nướng pie';

  @override
  String get mouldMooncakeMould => 'Khuôn ép bánh Trung thu';

  @override
  String get mouldLogPan => 'Khay bánh cuộn';

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
  String get batterLaminated => 'Bột cán bơ nhiều lớp';

  @override
  String get batterChoux => 'Bột choux';

  @override
  String get batterMooncake => 'Vỏ bánh nướng';

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
  String get frostingButterGlaze => 'Quét bơ trứng';

  @override
  String get frostingAppleFilling => 'Nhân táo';

  @override
  String get frostingLotusPaste => 'Nhân sen';

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
  String get toppingAlmondFlakes => 'Hạnh nhân lát';

  @override
  String get toppingPowderedSugar => 'Đường bột';

  @override
  String get toppingKiwi => 'Kiwi';

  @override
  String get toppingSesame => 'Mè';

  @override
  String get toppingMeringueMushroom => 'Nấm meringue';

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
  String get recipeCroissant => 'Bánh sừng bò';

  @override
  String get recipeCroissantDesc =>
      'Nhiều lớp bơ giòn xốp, cuộn thành vầng trăng vàng.';

  @override
  String get recipePainAuChocolat => 'Bánh mì sô-cô-la';

  @override
  String get recipePainAuChocolatDesc =>
      'Vỏ bánh giòn ôm hai thanh sô-cô-la đen.';

  @override
  String get recipeMadeleine => 'Bánh madeleine';

  @override
  String get recipeMadeleineDesc => 'Bánh nhỏ hình vỏ sò, ấm và thơm chanh.';

  @override
  String get recipeEclair => 'Bánh éclair';

  @override
  String get recipeEclairDesc => 'Vỏ choux nhẹ nhân kem trứng, phủ ganache.';

  @override
  String get recipeFruitTart => 'Tart trái cây';

  @override
  String get recipeFruitTartDesc => 'Tart kem trứng phủ trái cây tươi rực rỡ.';

  @override
  String get recipeApplePie => 'Bánh táo nướng';

  @override
  String get recipeApplePieDesc => 'Táo quế dưới lớp vỏ đan lưới vàng ruộm.';

  @override
  String get recipeMooncake => 'Bánh Trung thu';

  @override
  String get recipeMooncakeDesc =>
      'Nhân sen trong vỏ vàng in hoa, cho mùa lễ hội.';

  @override
  String get recipeBucheDeNoel => 'Bánh khúc cây Giáng sinh';

  @override
  String get recipeBucheDeNoelDesc => 'Khúc cây sô-cô-la với nấm meringue.';

  @override
  String get charMai => 'Mai';

  @override
  String get charHoa => 'Ông Hòa';

  @override
  String get charLinh => 'Linh';

  @override
  String get charKenji => 'Kenji';

  @override
  String get charRosa => 'Bà Rosa';

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
  String get storyCh1End1 => 'Những trang đầu của sổ bà lại đầy ắp rồi.';

  @override
  String get storyCh1End2 =>
      'Thị trấn bắt đầu biết đến cupcake của mình rồi... Phải bận rộn hơn thôi!';

  @override
  String get storyCh2End3 =>
      'Và ngay sau cánh cửa sau, một chương mới đang chờ...';

  @override
  String get storyCh3Open1 =>
      'Sau tiệm, khu vườn của bà mọc um tùm bạc hà và hoa hồng leo.';

  @override
  String get storyCh3Open2 =>
      'Dưới đám lá này có gì nhỉ? Một nhà kho nhỏ xinh!';

  @override
  String get storyCh3Open3 =>
      'Một trang sổ của bà nằm trong chậu hoa: \"Bánh sừng bò. Gấp bơ vào bột, và kiên nhẫn nhé.\"';

  @override
  String get storyCh3Open4 =>
      'Mai phủi đất, mỉm cười. Khu vườn đã giữ bí mật của bà thật kỹ.';

  @override
  String get storyMochi1Line1 =>
      'Mưa rơi lộp độp trên mái hiên. Dưới đó, một chú mèo xám nhỏ ngồi im thật im.';

  @override
  String get storyMochi1Line2 =>
      'Ôi! Em ướt sũng rồi, bé con. Vào đây đi, lò đang ấm lắm.';

  @override
  String get storyMochi1Line3 =>
      'Chú mèo cuộn tròn cạnh quầy, rù rù như một chiếc máy nhỏ.';

  @override
  String get storyMochi1Line4 =>
      'Chị đặt tên em là Mochi nhé. Hễ trời mưa là ghé chơi, được không?';

  @override
  String get storyKenji4Line1 =>
      'Hôm nay tôi muốn một món... cho ngày nhớ nhà.';

  @override
  String get storyKenji4Line2 =>
      'Vậy là món nhỏ và ấm nhé. Như cái ôm từ phương xa.';

  @override
  String get storyKenji4Line3 =>
      'Madeleine. Bà bảo chỉ một miếng cũng gợi lại cả buổi chiều.';

  @override
  String get storyKenji4Line4 => 'Vậy tôi sẽ ăn thật chậm.';

  @override
  String get storyCh4Open1 =>
      'Trên gác, bụi nhảy múa trong ánh sáng từ ô cửa sổ tròn nhỏ.';

  @override
  String get storyCh4Open2 =>
      'Hộp thư cũ của bà... bà giữ từng lời nhắn khách đã viết.';

  @override
  String get storyCh4Open3 =>
      'Và thêm hai trang nữa: éclair, và tart trái cây \"cho những ngày nắng\".';

  @override
  String get storyCh4Open4 =>
      'Mai gài các trang vào sổ. Giờ cuốn sổ nặng hơn một chút, theo cách đáng yêu nhất.';

  @override
  String get storyRosa1Line1 =>
      'Chào cháu. Bà cháu từng nướng bánh cưới cho bà đấy.';

  @override
  String get storyRosa1Line2 => 'Giờ cháu gái bà sắp cưới, ngay bên bờ biển.';

  @override
  String get storyRosa1Line3 => 'Bà Rosa ơi, tin vui quá ạ!';

  @override
  String get storyRosa1Line4 =>
      'Đến ngày, bà sẽ đặt bánh của cháu cho con bé. Bà cháu sẽ vui lắm.';

  @override
  String get storyLinh4Line1 =>
      'Chị Mai! Tuần sau trường có hội chợ, em đăng ký gian hàng cho hai đứa rồi!';

  @override
  String get storyLinh4Line2 => 'Hai đứa á? Mình bán gì đây?';

  @override
  String get storyLinh4Line3 =>
      'Bánh táo! Ai mang một cái là cả trường thơm mùi quế.';

  @override
  String get storyLinh4Line4 =>
      'Vậy mình sẽ nướng lớp lưới xinh nhất thị trấn. Theo cách của bà.';

  @override
  String get storyCh5Open1 =>
      'Đèn lồng được treo khắp bến cảng. Lễ hội biển sắp đến rồi.';

  @override
  String get storyCh5Open2 =>
      'Cả thị trấn đang trang hoàng... và ai cũng hỏi về bánh Trung thu.';

  @override
  String get storyCh5Open3 =>
      'Sổ của bà cũng có trang cho món đó: nhân sen và khuôn hoa nhỏ.';

  @override
  String get storyCh5Open4 =>
      'Tối nay tiệm bánh sẽ sáng như một chiếc đèn lồng nữa bên biển.';

  @override
  String get storyHoa4Line1 =>
      'Mỗi mùa đông, bà cháu nướng một khúc cây sô-cô-la cho cả xóm.';

  @override
  String get storyHoa4Line2 =>
      'Nấm meringue bé xíu, tuyết đường phủ nhẹ... lũ trẻ mê lắm.';

  @override
  String get storyHoa4Line3 =>
      'Bánh khúc cây Giáng sinh ạ? Cháu chưa làm bao giờ.';

  @override
  String get storyHoa4Line4 =>
      'Rồi cháu sẽ làm được. Tay bà đang ở trong tay cháu đấy, ông nhìn là biết.';

  @override
  String get storyRosa2Line1 => 'Hôm nay đám cưới rồi cháu. Bánh xong chưa?';

  @override
  String get storyRosa2Line2 =>
      'Sắp xong ạ. Ba tầng, gói như một món quà, giống chiếc bà đã làm cho bà.';

  @override
  String get storyRosa2Line3 =>
      'Ôi... cháu gái bà sẽ khóc mất. Có khi bà cũng khóc.';

  @override
  String get storyRosa2Line4 =>
      'Vậy mình làm cho xứng từng giọt nước mắt hạnh phúc nhé.';

  @override
  String get storyFinale2Line1 =>
      'Trang trống cuối cùng trong sổ của bà cuối cùng đã được lấp đầy.';

  @override
  String get storyFinale2Line2 =>
      'Tiệm bánh lại ấm áp và rộn ràng, đầy bạn bè cùng câu chuyện của họ.';

  @override
  String get storyFinale2Line3 =>
      'Nhưng một tiệm bánh hay thì không bao giờ hết chuyện... còn nhiều chương nữa đang chờ.';

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
  String get recipeSecretsTitle => 'Bí quyết của bà';

  @override
  String recipeSecretsLocked(int level) {
    return 'Mở sau màn $level';
  }

  @override
  String recipeSecretsTier(int tier, int max) {
    return 'Bí quyết $tier/$max';
  }

  @override
  String recipeSecretsBonus(int pct) {
    return '+$pct% giá';
  }

  @override
  String get recipeSecretsBuy => 'Học bí quyết';

  @override
  String get recipeSecretsMaxed => 'Đã học hết bí quyết';

  @override
  String get recipeSecretsRecipeLocked => 'Tìm lại công thức này trước đã';

  @override
  String get recipeSecretsHint =>
      'Mỗi bí quyết giúp món này bán được giá cao hơn.';

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
  String get storeTestMode => 'Chế độ thử';

  @override
  String storeGemsDesc(int gems) {
    return '$gems kim cương';
  }

  @override
  String storeStarterPackDescV2(int coins, int gems, int count) {
    return '$coins xu + $gems kim cương + mỗi vật phẩm ×$count';
  }

  @override
  String get storeStarterBadge => 'Ưu đãi nhất';

  @override
  String get storeRemoveAdsDescV2 =>
      'Không còn quảng cáo giữa các màn. Quảng cáo nhận thưởng vẫn tuỳ bạn.';

  @override
  String get storeStaffOutfitsDesc =>
      'Trang phục lễ hội cho Nora và Bảo. Chỉ đổi hình — bật/tắt ở tab Nhân viên.';

  @override
  String get storeSeasonPassDesc => 'Mở hàng thưởng cao cấp của mùa này.';

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
  String get adNotCompleted => 'Quảng cáo chưa xem xong nên chưa có thưởng.';

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

  @override
  String get settingsPurchases => 'Giao dịch';

  @override
  String get settingsRestore => 'Khôi phục giao dịch';

  @override
  String settingsRestoreDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã khôi phục $count giao dịch',
    );
    return '$_temp0';
  }

  @override
  String get settingsRestoreNone => 'Không có giao dịch nào để khôi phục';

  @override
  String get settingsRestoreFailed =>
      'Chưa khôi phục được. Bạn thử lại sau nhé.';

  @override
  String get levelMenuButton => 'Màn chơi';

  @override
  String levelChapterLabel(int chapter) {
    return 'Chương $chapter';
  }

  @override
  String levelNumber(int level) {
    return 'Màn $level';
  }

  @override
  String get levelNewBadge => 'Mới';

  @override
  String get levelSpecialBadge => 'Đặc biệt';

  @override
  String get levelGoalLabel => 'Mục tiêu';

  @override
  String levelGoalCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kiếm $count xu',
    );
    return '$_temp0';
  }

  @override
  String levelGoalCustomers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Phục vụ $count khách',
    );
    return '$_temp0';
  }

  @override
  String levelGoalSpecials(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hoàn thành $count đơn đặc biệt (từ 3 sao)',
    );
    return '$_temp0';
  }

  @override
  String get levelTimeLabel => 'Thời gian';

  @override
  String get levelMenuLabel => 'Thực đơn hôm nay';

  @override
  String get levelStart => 'Bắt đầu';

  @override
  String get levelPause => 'Tạm dừng';

  @override
  String get levelRush => 'Giờ cao điểm!';

  @override
  String levelGoalProgress(int value, int target) {
    return '$value/$target';
  }

  @override
  String levelCombo(String mult) {
    return 'Combo ×$mult';
  }

  @override
  String get levelPauseTitle => 'Tạm nghỉ';

  @override
  String get levelPauseBody => 'Nghỉ tay chút nhé — khách sẽ đợi bạn.';

  @override
  String get levelQuit => 'Thoát';

  @override
  String get levelReplay => 'Chơi lại';

  @override
  String get levelTimeUp => 'Hết giờ!';

  @override
  String levelExtraTimeTitle(int seconds) {
    return 'Thêm $seconds giây?';
  }

  @override
  String get levelExtraTimeBody =>
      'Sắp đạt rồi! Xem một quảng cáo ngắn để mở tiệm thêm chút nữa.';

  @override
  String levelExtraTimeWatch(int seconds) {
    return 'Xem quảng cáo (+$seconds giây)';
  }

  @override
  String get levelExtraTimeNo => 'Thôi';

  @override
  String get levelSpecialLater => 'Để sau';

  @override
  String get levelSpecialQuitTitle => 'Bỏ dở đơn này?';

  @override
  String get levelSpecialQuitBody =>
      'Khách vẫn đợi — bạn có thể quay lại làm sau.';

  @override
  String get levelResultWinTitle => 'Qua màn rồi!';

  @override
  String get levelResultLoseTitle => 'Suýt nữa thôi — thử lại nhé!';

  @override
  String levelResultGoal(String progress) {
    return 'Mục tiêu: $progress';
  }

  @override
  String get levelResultCoins => 'Xu kiếm được';

  @override
  String get levelResultServed => 'Khách hài lòng';

  @override
  String get levelResultLost => 'Khách bỏ đi';

  @override
  String get levelResultSpecials => 'Đơn đặc biệt';

  @override
  String get levelResultBestCombo => 'Combo cao nhất';

  @override
  String get levelResultFiveStar => 'Bánh 5 sao';

  @override
  String get levelResultDoubleCoins => '×2 xu (xem quảng cáo)';

  @override
  String levelResultDoubled(int coins) {
    return 'Đã nhân đôi xu! +$coins';
  }

  @override
  String get levelNext => 'Màn tiếp';

  @override
  String get levelList => 'Danh sách';

  @override
  String get lvlCaseFull => 'Tủ đầy!';

  @override
  String get lvlRushHour => 'Giờ cao điểm!';

  @override
  String lvlCombo(int count) {
    return 'Combo ×$count';
  }

  @override
  String get lvlWaitOven => 'Chờ lò';

  @override
  String get lvlWaiting => 'Đang chờ…';

  @override
  String get lvlPickTreat => 'Chạm chọn món';

  @override
  String get lvlBurnt => 'Cháy rồi!';

  @override
  String get lvlTakeOut => 'Lấy ra!';

  @override
  String get lvlStirHint => 'Khuấy 1 vòng';

  @override
  String get lvlSwipeHint => 'Quẹt ngang';

  @override
  String get lvlBoosterTitle => 'Vật phẩm hỗ trợ';

  @override
  String get lvlBoosterAdFree => 'Xem quảng cáo: 1 miễn phí';

  @override
  String get lvlBoosterFree => 'Miễn phí';

  @override
  String get lvlBoosterPickFree => 'Chọn một vật phẩm — miễn phí một cái!';

  @override
  String get lvlBoosterIntro =>
      'Mới! Vật phẩm hỗ trợ giúp màn chơi dễ hơn. Tặng bạn một cái để thử.';

  @override
  String lvlBoosterSelected(String name) {
    return '$name, đã chọn';
  }

  @override
  String get mapSeasonShort => 'Thẻ mùa';

  @override
  String get seasonTitle => 'Thẻ mùa';

  @override
  String seasonTimeLeft(String time) {
    return 'Còn $time';
  }

  @override
  String seasonDaysHours(int days, int hours) {
    return '$days ngày $hours giờ';
  }

  @override
  String seasonHoursMinutes(int hours, int minutes) {
    return '$hours giờ $minutes phút';
  }

  @override
  String seasonPoints(int points, int need) {
    return '$points/$need điểm';
  }

  @override
  String seasonPointsMax(int points) {
    return '$points điểm · đã đạt mọi bậc';
  }

  @override
  String seasonHowTo(int star, int win) {
    return '+$star điểm mỗi sao mới, +$win điểm mỗi lần thắng';
  }

  @override
  String seasonTierLabel(int tier) {
    return 'Bậc $tier';
  }

  @override
  String get seasonFreeRow => 'Miễn phí';

  @override
  String get seasonPremiumRow => 'Cao cấp';

  @override
  String get seasonClaimAll => 'Nhận tất cả';

  @override
  String seasonClaimedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã nhận $count phần thưởng!',
    );
    return '$_temp0';
  }

  @override
  String seasonBuyPremium(String price) {
    return 'Mở cao cấp · $price';
  }

  @override
  String get seasonPremiumActive => 'Đã mở cao cấp';

  @override
  String get seasonPremiumHint => 'Mở cao cấp để nhận';

  @override
  String get seasonEnded =>
      'Mùa đã kết thúc. Thưởng chưa nhận đã được tự động cộng cho bạn.';

  @override
  String get seasonNone => 'Hiện chưa có mùa nào.';

  @override
  String get seasonRewardFrame => 'Khung chân dung';

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
    return '$who ghé nếu phục vụ $served/$target khách trước $time';
  }

  @override
  String levelSpecialConditionNoTime(String who, int served, int target) {
    return '$who ghé khi phục vụ $served/$target khách';
  }

  @override
  String levelSpecialSkipped(String who) {
    return '$who không ghé được rồi';
  }

  @override
  String mapStarsTotal(int count) {
    return '$count sao';
  }

  @override
  String get mapQuestsShort => 'Nhiệm vụ';

  @override
  String get mapGiftShort => 'Quà';

  @override
  String get mapPrevChapter => 'Chương trước';

  @override
  String get mapNextChapter => 'Chương sau';

  @override
  String mapLevelLabel(int level, int stars) {
    return 'Màn $level: $stars/3 sao';
  }

  @override
  String mapLevelLockedLabel(int level) {
    return 'Màn $level, chưa mở';
  }

  @override
  String get mapLevelLocked => 'Qua màn trước để mở màn này nhé!';

  @override
  String mapChapterLockedTitle(int chapter) {
    return 'Chương $chapter chưa mở';
  }

  @override
  String mapChapterNeedStars(int need, int have) {
    return 'Cần $need sao — bạn đang có $have';
  }

  @override
  String mapChapterNeedFinish(int chapter) {
    return 'Hãy hoàn thành chương $chapter trước';
  }

  @override
  String get mapChapterReplayHint => 'Chơi lại các màn ít sao để gom thêm sao';

  @override
  String mapChapterUnlockedTitle(int chapter) {
    return 'Chương $chapter đã mở!';
  }

  @override
  String get mapChapterUnlockedBody =>
      'Món mới và những vị khách mới đang chờ ở góc phố này.';

  @override
  String get mapChapterUnlockedGo => 'Đi thôi!';

  @override
  String get mapBackToMap => 'Bản đồ';

  @override
  String get mapLoadError =>
      'Không tải được bản đồ màn chơi. Hãy mở lại trò chơi nhé.';

  @override
  String mapUnlockAfterLevel(int level) {
    return 'Qua màn $level để mở';
  }

  @override
  String mapRecipeFromLevel(int level) {
    return 'Trang còn thiếu. Tới màn $level để tìm lại';
  }

  @override
  String get mapRecipeLater => 'Trang còn thiếu. Sẽ tìm thấy ở chương sau';

  @override
  String get mapWelcomeTitle => 'Chào mừng bạn trở lại!';

  @override
  String mapWelcomeBody(int coins, int gems) {
    return 'Tiệm bánh có diện mạo mới: giờ bạn chơi từng màn trên bản đồ thị trấn. Cảm ơn bạn đã gắn bó, tặng bạn $coins xu và $gems kim cương.';
  }

  @override
  String get upgTabExpansion => 'Mở rộng tiệm';

  @override
  String get upgTabEquipment => 'Thiết bị';

  @override
  String get upgOwned => 'Đã có';

  @override
  String get upgComingSoon => 'Sắp có';

  @override
  String get upgExpansionDone => 'Đã thêm vào tiệm!';

  @override
  String upgTierOf(int current, int max) {
    return 'Cấp $current/$max';
  }

  @override
  String upgStatOvenSec(String seconds) {
    return 'Nướng $seconds giây';
  }

  @override
  String upgStatBatch(int count) {
    return '$count bánh mỗi khay';
  }

  @override
  String upgStatCaseSlot(int count) {
    return '$count bánh mỗi ô tủ';
  }

  @override
  String upgStatMixZone(int percent) {
    return 'Vùng xanh $percent%';
  }

  @override
  String upgStatStroke(int size) {
    return 'Nét kem cỡ $size';
  }

  @override
  String upgStatSnap(int size) {
    return 'Tầm hút $size';
  }

  @override
  String get upgStatSnapNone => 'Chưa hút topping';

  @override
  String upgStatNext(String stat) {
    return 'Cấp sau: $stat';
  }

  @override
  String get unlockNoticeTitle => 'Mở khoá mới!';

  @override
  String unlockNoticeBody(int count) {
    return '$count mục mới đã sẵn sàng cho tiệm của bạn.';
  }

  @override
  String get unlockNoticeView => 'Xem';

  @override
  String get unlockNoticeLater => 'Để sau';

  @override
  String unlockNoticeTier(int tier) {
    return 'Mở cấp $tier';
  }

  @override
  String unlockNoticeMore(int count) {
    return 'và $count mục khác';
  }

  @override
  String levelShopCase(int count) {
    return 'Tủ $count ô';
  }

  @override
  String levelShopOvens(int count) {
    return '$count lò';
  }

  @override
  String levelShopTray(int count) {
    return 'Khay $count bánh';
  }

  @override
  String get upgTabStaff => 'Nhân viên';

  @override
  String get staffRoleCashier => 'Thu ngân';

  @override
  String get staffRoleBaker => 'Thợ bánh';

  @override
  String get staffRoleWaiter => 'Phục vụ';

  @override
  String get staffRoleManager => 'Quản lý';

  @override
  String get staffStatSpeed => 'Tốc độ';

  @override
  String get staffStatSkill => 'Tay nghề';

  @override
  String staffStatLevel(String stat, int level, int max) {
    return '$stat cấp $level/$max';
  }

  @override
  String get staffHire => 'Thuê';

  @override
  String get staffHired => 'Chào mừng vào tiệm!';

  @override
  String staffUpgradeStat(String stat) {
    return 'Nâng $stat';
  }

  @override
  String staffCashierSpeed(String seconds) {
    return 'Bán mỗi $seconds giây';
  }

  @override
  String staffCashierSkill(int percent) {
    return 'Tip thêm $percent%';
  }

  @override
  String staffBakerSpeed(String seconds) {
    return 'Một mẻ mỗi $seconds giây';
  }

  @override
  String staffBakerSkill(String stars) {
    return 'Bánh khoảng $stars sao';
  }

  @override
  String staffWaiterSpeed(String seconds) {
    return 'Phục vụ mỗi $seconds giây';
  }

  @override
  String staffWaiterSkill(int percent) {
    return 'Khách chờ kiên nhẫn +$percent%';
  }

  @override
  String staffManagerSpeed(int percent) {
    return '$percent% xu một màn mỗi giờ';
  }

  @override
  String staffManagerSkill(int hours) {
    return 'Tính tối đa $hours giờ vắng';
  }

  @override
  String staffRequires(String item) {
    return 'Cần có $item trước';
  }

  @override
  String get staffOutfitFestival => 'Trang phục lễ hội';

  @override
  String get offlineTitle => 'Khi bạn vắng nhà';

  @override
  String offlineBody(String name, String duration) {
    return '$name đã trông tiệm giúp bạn $duration.';
  }

  @override
  String offlineCapped(int hours) {
    return 'Chỉ tính $hours giờ (giới hạn của quản lý).';
  }

  @override
  String offlineDurationMinutes(int minutes) {
    return '$minutes phút';
  }

  @override
  String offlineDurationHours(int hours) {
    return '$hours giờ';
  }

  @override
  String offlineDurationHoursMinutes(int hours, int minutes) {
    return '$hours giờ $minutes phút';
  }

  @override
  String offlineDurationDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ngày',
      one: 'hơn một ngày',
    );
    return '$_temp0';
  }

  @override
  String offlineEarned(int count) {
    return 'Bạn nhận được $count xu';
  }

  @override
  String get offlineClaim => 'Nhận';

  @override
  String get offlineDouble => 'x2 (xem quảng cáo)';

  @override
  String get offlineDoubled => 'Đã nhân đôi xu!';

  @override
  String get levelReadyStaff => 'Phụ bạn màn này';

  @override
  String levelReadyStaffNames(String names) {
    return '$names sẽ phụ bạn màn này';
  }

  @override
  String get introLineKitchen => 'Một buổi sáng ở thị trấn ven biển…';

  @override
  String get introLineCase => 'Tủ bánh của bà vẫn sáng như ngày nào.';

  @override
  String get introLineDoor => 'Mai lật tấm biển — tiệm Sugarleaf mở cửa!';

  @override
  String get introSignOpen => 'Mở cửa';

  @override
  String get introTapToEnter => 'Chạm để vào tiệm';

  @override
  String get introSemantics => 'Cảnh mở đầu';

  @override
  String get lvlTutServe => 'Khách muốn bánh này. Chạm khách để bán!';

  @override
  String get lvlTutBake => 'Chạm thẻ bánh để làm mẻ mới nhé!';

  @override
  String get lvlTutMould => 'Chọn đúng khuôn';

  @override
  String get lvlTutMix => 'Xoay tròn để trộn';

  @override
  String get lvlTutOven => 'Đợi kim tới vạch vàng rồi chạm';

  @override
  String get lvlTutFrost => 'Vẽ theo đường kem';

  @override
  String lvlTutTopping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chạm hũ đúng $count lần',
    );
    return '$_temp0';
  }

  @override
  String get lvlTutBox => 'Chọn hộp đúng';

  @override
  String get lvlTutCaseReady =>
      'Bánh đã lên tủ. Cứ thế phục vụ thật nhiều khách nhé!';

  @override
  String get lvlTutCombo => 'Bán liên tục để nhân combo — tiền nhiều hơn!';

  @override
  String get lvlTutNewTreat => 'Mỗi khách muốn một món khác nhau.';

  @override
  String get lvlTutPatience =>
      'Vòng màu là độ kiên nhẫn của khách. Nhanh tay để nhận tip!';

  @override
  String get lvlTutWalkout => 'Khách chờ lâu quá sẽ bỏ đi.';

  @override
  String get levelReadyCoinsHint => 'Màn này tính theo xu kiếm được';

  @override
  String get settingsGuide => 'Làm quen';

  @override
  String get settingsReplayIntro => 'Xem lại cảnh mở đầu';

  @override
  String get settingsReplayTutorials => 'Hướng dẫn lại';

  @override
  String get settingsTutorialsReset => 'Hướng dẫn sẽ hiện lại ở Màn 1–3';

  @override
  String get storePurchaseFailed => 'Giao dịch chưa thành công.';

  @override
  String get storeSeasonNone => 'Hiện chưa có mùa mới. Quay lại sau nhé!';

  @override
  String levelResultSeasonPoints(int points) {
    return '+$points điểm mùa';
  }

  @override
  String levelResultBoosterGift(String name) {
    return 'Quà: $name ×1';
  }

  @override
  String get levelPauseBoosterLost =>
      'Vật phẩm đã dùng ở lượt này sẽ không được hoàn lại.';

  @override
  String get levelPauseBoosterRefund =>
      'Thoát hoặc chơi lại lúc này, vật phẩm sẽ được trả lại vào kho.';

  @override
  String get levelBoostersRefunded => 'Đã trả vật phẩm vào kho.';
}
