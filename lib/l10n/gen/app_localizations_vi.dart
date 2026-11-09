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
  String get dayExitConfirmTitle => 'Đóng ca sớm?';

  @override
  String get dayExitConfirmBody =>
      'Xu của các khách đã phục vụ vẫn giữ, nhưng không có thưởng hết ca.';

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
  String get mochiPet => 'Vuốt ve';

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
    return 'Thưởng hết ca +$xp XP';
  }

  @override
  String get summaryRainyDay => 'Ngày mưa — Mochi ghé chơi';

  @override
  String get summaryDouble => 'Nhân đôi xu (xem QC)';

  @override
  String get summaryDoubled => 'Đã nhân đôi xu!';

  @override
  String summaryLevelUp(int level) {
    return 'Lên cấp! Mai đạt cấp $level';
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
  String get storeRemoveAds => 'Xoá quảng cáo';

  @override
  String get storeRemoveAdsDesc =>
      'Không còn quảng cáo giữa các ngày. Quảng cáo nhận thưởng vẫn tuỳ bạn.';

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
      'Xu, cấp, kiểu tóc của Mai, các nơi đã ghé, chi nhánh và nhân viên sẽ bị xoá. Giữ nguyên ngôn ngữ và âm thanh. Không thể hoàn tác.';

  @override
  String get settingsResetDone => 'Đã xoá dữ liệu game';

  @override
  String settingsVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get settingsAlphaNote => 'Bản alpha. Cảm ơn bạn đã chơi thử!';

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
  String get offlineDouble => 'x2 (xem quảng cáo)';

  @override
  String get introLineKitchen => 'Một buổi sáng ở thị trấn ven biển…';

  @override
  String get introLineCase => 'Tiệm bánh nhỏ của bà vẫn ở đó như ngày nào.';

  @override
  String get introLineDoor => 'Mai đã về — tiệm Sugarleaf lại mở cửa!';

  @override
  String get introSignOpen => 'Mở cửa';

  @override
  String get introSemantics => 'Cảnh mở đầu';

  @override
  String get settingsReplayIntro => 'Xem lại cảnh mở đầu';

  @override
  String get charNora => 'Nora';

  @override
  String get charBao => 'Bảo';

  @override
  String get charTheo => 'Theo';

  @override
  String get npcSquirrel => 'Bạn Sóc';

  @override
  String get npcHamster => 'Bé Hamster';

  @override
  String get npcShiba => 'Cậu Shiba';

  @override
  String get npcBlackCat => 'Bạn Mèo Mun';

  @override
  String get npcWalrus => 'Bác Hải Mã';

  @override
  String get npcLion => 'Bác Sư Tử';

  @override
  String get talkHoaOwlL1 =>
      'Người ta bảo cú thức đêm. Ông thì năm giờ sáng đã đứng trước cửa tiệm cháu rồi.';

  @override
  String get talkHoaOwlL2 => 'Ông ơi, tiệm mở lúc bảy giờ mà!';

  @override
  String get talkHoaOwlL3 =>
      'Ông biết. Hai tiếng đó là để ngửi mùi bơ bay qua khe cửa.';

  @override
  String get talkHoaOwlC1 => 'Mai mốt cháu mở cửa sớm cho ông nhé!';

  @override
  String get talkHoaOwlR1 =>
      'Đừng, đừng. Chờ đợi là một nửa cái ngon của tart trứng.';

  @override
  String get talkHoaOwlC2 =>
      'Vậy cháu nướng thơm hơn nữa, ông ngồi nhà cũng ngửi thấy!';

  @override
  String get talkHoaOwlR2 => 'Thế thì ông hết cớ dậy sớm mất. Được, ông chịu.';

  @override
  String get talkHoaOwlL4 => 'Vậy mai, chiếc tart đầu lò là của ông ạ.';

  @override
  String get talkLinhSketchL1 =>
      'Chị Mai đứng yên chút nha! Em đang ký họa chị đó.';

  @override
  String get talkLinhSketchL2 => 'Ơ, tóc chị đang dính đầy bột mà…';

  @override
  String get talkLinhSketchL3 => 'Xong rồi! Chị xem nè.';

  @override
  String get talkLinhSketchL4 =>
      'Linh ơi… sao chị lại thành cái bánh bao đeo tạp dề?';

  @override
  String get talkLinhSketchL5 => 'Tại chị tròn tròn, mềm mềm, ấm ấm. Khen đó!';

  @override
  String get talkLinhSketchC1 => 'Vậy vẽ thêm cho chị cái nơ nhé!';

  @override
  String get talkLinhSketchR1 => 'Hai cái luôn! Bánh bao xinh nhất thị trấn!';

  @override
  String get talkLinhSketchC2 => 'Cho chị treo tranh cạnh quầy được không?';

  @override
  String get talkLinhSketchR2 =>
      'Thật hả? Chị nhìn nè, tai em dựng hết cả lên rồi!';

  @override
  String get talkKenjiCloudL1 =>
      'Hôm nay tôi thấy mình như một đám mây định mưa… rồi đổi ý.';

  @override
  String get talkKenjiCloudL2 => 'Một đám mây đổi ý… Để Mai nghĩ xem nào.';

  @override
  String get talkKenjiCloudC1 =>
      'Bánh kem matcha: lúc đầu hơi đắng, rồi ngọt dần.';

  @override
  String get talkKenjiCloudR1 =>
      'Đúng là đám mây đó. Tôi sẽ chụp nó trước khi ăn.';

  @override
  String get talkKenjiCloudC2 => 'Cupcake vani, trắng và bông như mây.';

  @override
  String get talkKenjiCloudR2 =>
      'Hơi… theo nghĩa đen. Nhưng tôi thích sự thẳng thắn này.';

  @override
  String get talkKenjiCloudL3 =>
      'Mỗi lần ghé đây, cuộn phim của tôi lại vơi đi một ít.';

  @override
  String get talkRosaSecretL1 =>
      'Cháu biết không, sáu mươi năm nay bà chỉ ăn bánh bằng nĩa bạc.';

  @override
  String get talkRosaSecretL2 =>
      'Dạ… nhưng chóp mũi bà đang dính một chấm kem ạ.';

  @override
  String get talkRosaSecretL3 => 'Hừm. Chắc là… gió thổi vào.';

  @override
  String get talkRosaSecretL4 => 'Trong tiệm làm gì có gió ạ?';

  @override
  String get talkRosaSecretC1 => '(Nháy mắt) Cháu không thấy gì đâu ạ.';

  @override
  String get talkRosaSecretR1 => 'Cô bé tinh ý. Đây, tip cho sự kín đáo.';

  @override
  String get talkRosaSecretC2 => 'Bà nếm thử đi, kem hôm nay ngon lắm!';

  @override
  String get talkRosaSecretR2 =>
      '(Liếm thật nhanh) …Ngon thật. Đừng kể với ai nhé.';

  @override
  String get talkMochiBellyL1 => 'Meo.';

  @override
  String get talkMochiBellyL2 =>
      'Hôm nay em lại ướt sũng à? Lò còn ấm đó, ra hong lông đi.';

  @override
  String get talkMochiBellyL3 => '(Mochi lăn ra, chìa cái bụng tròn mềm.)';

  @override
  String get talkMochiBellyL4 => 'Bẫy đấy, chị biết mà. Xoa bụng là bị cắn.';

  @override
  String get talkMochiBellyC1 => 'Xoa bụng';

  @override
  String get talkMochiBellyR1 =>
      '(Mochi ôm chặt tay Mai bằng cả bốn chân… và rù rù.)';

  @override
  String get talkMochiBellyC2 => 'Lăn cuộn len cho em';

  @override
  String get talkMochiBellyR2 =>
      '(Mochi lao theo cuộn len, trượt một vòng trên sàn gỗ.)';

  @override
  String get talkMochiBellyL5 => 'Đúng là đồ mèo con nghịch ngợm.';

  @override
  String get talkWalrusFishL1 =>
      'Cháu đoán xem sáng nay bác câu được con cá to cỡ nào?';

  @override
  String get talkWalrusFishL2 => 'To cỡ nào ạ?';

  @override
  String get talkWalrusFishL3 => 'To bằng… cái lò nướng của cháu!';

  @override
  String get talkWalrusFishC1 =>
      'Tuần trước bác bảo nó to bằng cái tủ lạnh mà.';

  @override
  String get talkWalrusFishR1 =>
      'Thì… nó lớn lên chứ! Cá cũng ăn bánh của cháu mà.';

  @override
  String get talkWalrusFishC2 => 'Thế bác có mang nó về không ạ?';

  @override
  String get talkWalrusFishR2 =>
      'Nó xin bác tha, hứa mai quay lại… còn to hơn.';

  @override
  String get talkWalrusFishL4 => 'Vậy mai cháu chuẩn bị cái lò to hơn ạ.';

  @override
  String get talkSquirrelNutL1 =>
      'Chị ơi, em trả bằng hạt dẻ được không? Em có cả một kho!';

  @override
  String get talkSquirrelNutL2 => 'Ơ… tiệm chị chỉ nhận xu thôi em.';

  @override
  String get talkSquirrelNutL3 => 'Khoan, để em lục cái đuôi…';

  @override
  String get talkSquirrelNutL4 =>
      'Đây rồi! Ba đồng xu, một cái cúc áo, và… một hạt dẻ dự phòng.';

  @override
  String get talkSquirrelNutC1 => 'Chị nhận xu thôi, hạt dẻ em giữ nhé.';

  @override
  String get talkSquirrelNutR1 =>
      'Chị tốt ghê! Em sẽ chôn nó trước tiệm, mọc thành cây cho chị.';

  @override
  String get talkSquirrelNutC2 => 'Đưa chị hạt dẻ, chị làm bánh hạt dẻ cho em!';

  @override
  String get talkSquirrelNutR2 =>
      'Thật á? Để em đi lấy thêm… ở chỗ nào đó em quên mất rồi.';

  @override
  String get talkHamsterCheeksL1 => 'Chị ơi, cho em… ưm-ưm-mm…';

  @override
  String get talkHamsterCheeksL2 =>
      'Em ơi, hai má em đang nhét đầy bánh quy rồi kìa.';

  @override
  String get talkHamsterCheeksL3 =>
      '(Nuốt ực) Đó là bánh để dành. Cái này là bánh để ăn!';

  @override
  String get talkHamsterCheeksC1 => 'Để chị gói cho em một hộp mang về nhé.';

  @override
  String get talkHamsterCheeksR1 => 'Hộp á! Vậy hôm nay má em được nghỉ rồi!';

  @override
  String get talkHamsterCheeksC2 => 'Thử nhét thêm một cái nữa xem nào?';

  @override
  String get talkHamsterCheeksR2 => 'Thử thì thử! …Ưm… vừa khít luôn.';

  @override
  String get smallTalkNora =>
      'Hôm nay bạn dùng như mọi khi chứ? Mình nhớ rồi nha!';

  @override
  String get smallTalkBao => '…Bánh vừa ra lò. Còn ấm.';

  @override
  String get smallTalkTheo => 'Trà hôm nay pha bằng nụ cười đó, uống thử đi!';

  @override
  String get smallTalkMai1 => 'Hôm nay trời đẹp ghê, bạn ra biển chưa?';

  @override
  String get smallTalkMai2 => 'Mẻ bánh sau có thêm chút quế, ghé lại thử nha!';

  @override
  String get smallTalkReply1 => 'Cảm ơn nha, dễ thương quá!';

  @override
  String get smallTalkReply2 => 'Ngon tuyệt, mai mình lại ghé!';

  @override
  String get smallTalkReply3 => 'Tiệm này lúc nào cũng thơm ghê.';

  @override
  String get quarrelLastCakeL1 =>
      'Chiếc cupcake dâu này của em! Em thấy nó trước!';

  @override
  String get quarrelLastCakeL2 => 'Nhưng em mơ về nó từ hôm qua cơ!';

  @override
  String get quarrelLastCakeL3 => 'Mơ thì không tính!';

  @override
  String get quarrelLastCakeL4 => 'Hai em ơi, từ từ nào, bánh sắp bẹp rồi kìa!';

  @override
  String get quarrelLastCakeA => 'Chia đôi chiếc bánh';

  @override
  String get quarrelLastCakeRA1 => 'Nửa cái… vừa khít một bên má!';

  @override
  String get quarrelLastCakeRA2 => 'Nửa của em nhiều kem hơn. Hihi.';

  @override
  String get quarrelLastCakeB => 'Oẳn tù tì, ai thắng được bánh';

  @override
  String get quarrelLastCakeRB1 => 'Oẳn tù tì… ra cái gì ra cái này!';

  @override
  String get quarrelLastCakeRB2 => 'Em thắng rồi!';

  @override
  String get quarrelLastCakeRB3 => 'Hừm… lần sau em ra búa.';

  @override
  String get quarrelLastCakeC => 'Mẻ cupcake mới sắp ra lò, mỗi em một cái!';

  @override
  String get quarrelLastCakeRC1 => 'Mỗi đứa một cái á?!';

  @override
  String get quarrelLastCakeRC2 => 'Chị đúng là thiên thần bánh ngọt!';

  @override
  String get quarrelFirstL1 =>
      'Tôi đứng đây từ lúc mặt trời mọc! Tôi vào trước!';

  @override
  String get quarrelFirstL2 =>
      'Còn tôi ngủ trước cửa từ tối qua. Mèo là phải thế.';

  @override
  String get quarrelFirstL3 => 'Ngủ thì không phải xếp hàng!';

  @override
  String get quarrelFirstL4 => 'Với mèo thì có.';

  @override
  String get quarrelFirstL5 => 'Hai bạn ơi, hít thở sâu nào!';

  @override
  String get quarrelFirstA => 'Mời cả hai cùng vào, cửa rộng mà!';

  @override
  String get quarrelFirstRA1 => '…Hơi chật.';

  @override
  String get quarrelFirstRA2 => 'Cậu hóp bụng vào.';

  @override
  String get quarrelFirstRA3 =>
      '(Cả hai kẹt cứng ở cửa một giây… rồi cùng bật cười.)';

  @override
  String get quarrelFirstB => 'Xem dấu chân trên thảm cửa';

  @override
  String get quarrelFirstRB1 =>
      'Dấu chân mèo ở dưới… dấu chân shiba đè lên trên.';

  @override
  String get quarrelFirstRB2 => 'Thì… tôi đứng lên dấu chân cậu ấy thật.';

  @override
  String get quarrelFirstRB3 => 'Cảm ơn. Cậu dễ thương lắm, đi sau tôi nhé.';

  @override
  String get quarrelFirstC => 'Ai kể chuyện cười hay hơn được vào trước';

  @override
  String get quarrelFirstRC1 =>
      'Vì sao bánh mì lúc nào cũng buồn? Vì toàn bị… bơ!';

  @override
  String get quarrelFirstRC2 => '…Dở tệ. Mà tôi cười rồi. Cậu vào trước đi.';

  @override
  String get quarrelTartL1 =>
      'Tart trứng là vua các loại bánh! Giòn, béo, vàng như mặt trời!';

  @override
  String get quarrelTartL2 => 'Vua à? Vua là tôi đây. Và vua chọn pie táo.';

  @override
  String get quarrelTartL3 => 'Ông thì được mỗi cái bờm to!';

  @override
  String get quarrelTartL4 => 'Còn ông thì được mỗi cái bụng tròn!';

  @override
  String get quarrelTartL5 => 'Hai bác ơi, cả phố đang nhìn kìa!';

  @override
  String get quarrelTartA => 'Mời hai bác bịt mắt nếm thử cả hai';

  @override
  String get quarrelTartRA1 => 'Cái này… ngon hơn. Là pie táo à?!';

  @override
  String get quarrelTartRA2 => 'Còn tôi chọn… tart trứng. Ôi không.';

  @override
  String get quarrelTartRA3 => 'Thôi, mua cả hai!';

  @override
  String get quarrelTartB => 'Bánh nào cũng ngon, hai bác bắt tay nhé!';

  @override
  String get quarrelTartRB1 => 'Đúng là câu trả lời của nhà ngoại giao.';

  @override
  String get quarrelTartRB2 => 'Nhạt như bột chưa nêm.';

  @override
  String get quarrelTartC => 'Gọi ông Hòa ra phân xử';

  @override
  String get quarrelTartCAlt => 'Bắt chước giọng ông Hòa';

  @override
  String get quarrelTartRC1 => 'Tart trứng. Bốn mươi năm rồi, không bàn cãi.';

  @override
  String get quarrelTartRC1Alt =>
      'E hèm… Tart trứng. Bốn mươi năm rồi, không bàn cãi.';

  @override
  String get quarrelTartRC2 => 'Nghe chưa! Nghe chưa!';

  @override
  String get quarrelTartRC3 => 'Hừm. Hội người cao tuổi thiên vị.';

  @override
  String get quarrelBanner => 'Có chuyện ồn ào trước cửa tiệm!';

  @override
  String get quarrelLook => 'Xem';

  @override
  String get quarrelSendMai => 'Mai ra xem';

  @override
  String get quarrelIntervene => 'Can ngăn';

  @override
  String get quarrelTimeout => 'Hai vị khách phụng phịu bỏ đi mất rồi…';

  @override
  String get quarrelPeace => 'Trước cửa tiệm lại yên bình.';

  @override
  String get staffMenuControl => 'Điều khiển';

  @override
  String get staffMenuTalk => 'Nói chuyện với khách';

  @override
  String get actionPickUp => 'Nhặt';

  @override
  String get actionPutDown => 'Đặt xuống';

  @override
  String get actionPlaceOn => 'Đặt lên';

  @override
  String get actionGive => 'Mời bánh';

  @override
  String get actionThrow => 'Ném';

  @override
  String get actionTalk => 'Nói chuyện';

  @override
  String get actionWave => 'Vẫy chào';

  @override
  String get controlHint =>
      'Kéo vòng tròn bên trái để đi, bấm nút bên phải để thao tác.';

  @override
  String get talkPickCustomer => 'Chọn khách để trò chuyện';

  @override
  String get talkNoCustomer => 'Chưa có vị khách nào rảnh để trò chuyện.';

  @override
  String get itemYarn => 'Cuộn len';

  @override
  String get itemCakeBox => 'Hộp bánh';

  @override
  String get itemFlour => 'Bao bột';

  @override
  String get reactOops => 'Ơ!';

  @override
  String get reactStop => 'Thôi mà!';

  @override
  String get reactThanks => 'Cảm ơn nha!';

  @override
  String get reactFull => 'Mình no rồi, cảm ơn nha!';

  @override
  String get reactNoThrowCake => 'Bánh phải mời tận tay chứ!';

  @override
  String get reactExcuseMe => 'Cho mình qua với!';

  @override
  String get reactPurr => 'Rừ rừ…';

  @override
  String interactGoodwill(int count) {
    return '+$count thiện cảm';
  }

  @override
  String interactCoins(int count) {
    return '+$count xu';
  }

  @override
  String get townEnterShop => 'Vào tiệm';

  @override
  String get townExitShop => 'Ra phố';

  @override
  String get shopExitButton => 'Ra ngoài';

  @override
  String get townMap => 'Bản đồ';

  @override
  String get townOpenMap => 'Mở bản đồ';

  @override
  String get townYouAreHere => 'Bạn ở đây';

  @override
  String get townHomeShop => 'Tiệm của bà';

  @override
  String townBranchN(int n) {
    return 'Chi nhánh $n';
  }

  @override
  String get townLotForSale => 'Lô đất trống';

  @override
  String townLotLocked(int level) {
    return 'Mở ở cấp $level';
  }

  @override
  String get townLotUnlocked => 'Đã mở · đang bán ở văn phòng địa ốc';

  @override
  String townLotsUnlockedToast(int count) {
    return 'Đã mở khoá $count lô mới!';
  }

  @override
  String get townComingSoon => 'Sắp mở';

  @override
  String get townStreetName => 'Phố Tiệm Bánh';

  @override
  String get townOpening => 'Đang mở cửa…';

  @override
  String get townActionCollect => 'Thu tiền';

  @override
  String get townActionBranch => 'Chi nhánh';

  @override
  String get townActionRealty => 'Xem lô đất';

  @override
  String realtyLotN(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Lô số $nString';
  }

  @override
  String get realtyOwned => 'Của bạn';

  @override
  String get realtyConfirmTitle => 'Mua lô này?';

  @override
  String realtyConfirmBody(int price) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$priceString xu. Lô sẽ thành một chi nhánh nhỏ tự bán hàng.';
  }

  @override
  String branchOpenedToast(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Chi nhánh $nString khai trương!';
  }

  @override
  String branchBannerTill(int level, int coins, int cap) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat capNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String capString = capNumberFormat.format(cap);

    return 'Cấp $levelString · Két $coinsString/$capString xu';
  }

  @override
  String branchBannerFull(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Cấp $levelString · Két đầy!';
  }

  @override
  String branchIncome(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '~$coinsString xu/giờ';
  }

  @override
  String branchTillCap(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Két chứa $coinsString xu (8 giờ)';
  }

  @override
  String get branchTill => 'Két';

  @override
  String get branchTillFull => 'Đầy rồi — thu tiền để bán tiếp';

  @override
  String branchFullIn(String time) {
    return 'Đầy sau $time';
  }

  @override
  String branchCollect(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Thu $coinsString xu';
  }

  @override
  String branchCollectedToast(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString xu từ chi nhánh';
  }

  @override
  String branchUpgrade(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Nâng cấp · $coinsString xu';
  }

  @override
  String branchNextLevel(int level, int coins) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Cấp $levelString: $coinsString xu/giờ';
  }

  @override
  String branchNeedMaiLevel(int level) {
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Cần Mai cấp $levelString';
  }

  @override
  String branchUpgradedToast(int n, int level) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat levelNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String levelString = levelNumberFormat.format(level);

    return 'Chi nhánh $nString lên cấp $levelString!';
  }

  @override
  String get branchStaff => 'Nhân viên';

  @override
  String branchSlots(int used, int total) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$usedString/$totalString chỗ';
  }

  @override
  String get branchNoSlot => 'Hết chỗ — cấp 3 có thêm một chỗ';

  @override
  String branchHire(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Thuê · $coinsString xu';
  }

  @override
  String get branchDismiss => 'Cho nghỉ';

  @override
  String branchDismissConfirm(String name, int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$name sẽ nghỉ dài ngày. Bạn được hoàn $coinsString xu.';
  }

  @override
  String branchHiredToast(String name, int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return '$name bắt đầu làm ở Chi nhánh $nString';
  }

  @override
  String branchWorksAt(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Đang làm ở Chi nhánh $nString';
  }

  @override
  String get staffRoleServer => 'Phục vụ';

  @override
  String get staffRoleBaker => 'Thợ bánh';

  @override
  String get staffRoleManager => 'Quản lý';

  @override
  String staffEffectBonus(int pct) {
    final intl.NumberFormat pctNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pctString = pctNumberFormat.format(pct);

    return '+$pctString% doanh thu';
  }

  @override
  String staffEffectDeposit(int pct) {
    final intl.NumberFormat pctNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pctString = pctNumberFormat.format(pct);

    return 'Gửi $pctString% tiền bán về ví';
  }

  @override
  String get charAmi => 'Ami';

  @override
  String get charHanh => 'Hạnh';

  @override
  String get charBiscuit => 'Bánh Quy';

  @override
  String get charNutmeg => 'Hạt Dẻ';

  @override
  String get charCocoa => 'Ca Cao';

  @override
  String get charMaple => 'Lá Phong';

  @override
  String branchAwayToast(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Trong lúc bạn đi vắng, các chi nhánh đã bán được $coinsString xu — ghé thu nhé!';
  }

  @override
  String branchDepositToast(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Quản lý gửi về +$coinsString xu';
  }

  @override
  String get branchClockBehind =>
      'Giờ trên máy đang chậm hơn lần chơi trước nên két tạm nghỉ.';

  @override
  String get citySeaMarketName => 'Phố Chợ Biển';

  @override
  String get cityRealtyName => 'Văn phòng địa ốc Bến Cảng';

  @override
  String get cityParkName => 'Công viên Hải Đăng';

  @override
  String get cityRestaurantName => 'Bếp Hải Đăng';

  @override
  String get citySalonName => 'Tiệm tóc Vỏ Sò';

  @override
  String get cityOrderFood => 'Gọi món';

  @override
  String get cityGetHaircut => 'Làm tóc';

  @override
  String cityPrice(int coins) {
    final intl.NumberFormat coinsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString xu';
  }

  @override
  String cityXpGain(int xp) {
    return '+$xp XP';
  }

  @override
  String cityMaiLevel(int n) {
    return 'Cấp $n';
  }

  @override
  String get cityLevelUp => 'Lên cấp!';

  @override
  String get cityNotEnoughCoins => 'Không đủ xu';

  @override
  String get cityAteToday => 'Hôm nay đã ăn món này – ít XP hơn';

  @override
  String get cityBuffFull => 'No bụng vui vẻ: +10% tip ca sau';

  @override
  String get cityConfirm => 'Xác nhận';

  @override
  String get cityCancel => 'Thôi';

  @override
  String get cityFirstVisit => 'Thưởng ghé lần đầu!';

  @override
  String get cityMenuTitle => 'Thực đơn hôm nay';

  @override
  String get citySalonTitle => 'Chọn kiểu mới';

  @override
  String get cityHairStyle => 'Kiểu tóc';

  @override
  String get cityHairColor => 'Màu tóc';

  @override
  String get cityEating => 'Đang thưởng thức…';

  @override
  String get citySaveReadOnly =>
      'Bản lưu này đến từ phiên bản game mới hơn. Tiến trình phiên này sẽ không được lưu.';

  @override
  String get shiftOpen => 'Mở ca';

  @override
  String get shiftHintCounter => 'Tới quầy rồi bấm “Mở ca” để bắt đầu bán';

  @override
  String get shiftCustomerComing => 'Khách đang tới…';

  @override
  String get shiftSummaryTitle => 'Hết ca rồi!';

  @override
  String get shiftCloseEarly => 'Đóng ca sớm';

  @override
  String shiftClosedToast(int coins) {
    return 'Đã đóng ca · giữ +$coins xu';
  }

  @override
  String shiftBuffTip(int amount) {
    return 'No bụng: +$amount tip';
  }

  @override
  String get dishFishSoup => 'Canh cá ven biển';

  @override
  String get dishOmeletteRice => 'Cơm trứng cuộn';

  @override
  String get dishVeggieCurry => 'Cà ri rau củ';

  @override
  String get dishSeafoodNoodles => 'Mì hải sản';

  @override
  String get hairPonytail => 'Đuôi ngựa';

  @override
  String get hairBob => 'Tóc ngắn bob';

  @override
  String get hairBun => 'Búi tóc';

  @override
  String get hairTwinTails => 'Hai bím';

  @override
  String get hairColorChestnut => 'Nâu hạt dẻ';

  @override
  String get hairColorCaramel => 'Caramel';

  @override
  String get hairColorBlack => 'Đen';

  @override
  String get hairColorStrawberry => 'Hồng dâu';
}
