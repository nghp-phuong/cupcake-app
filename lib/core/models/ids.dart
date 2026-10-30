// Toàn bộ enum dùng chung. Tên chốt — dùng `.name` làm khoá lưu, KHÔNG đổi tên. Thêm giá trị mới ở CUỐI (GĐ8: 8 món
// croissant…bucheDeNoel cùng khuôn/bột/kem/topping của chúng).

enum RecipeId { cupcakeVanilla, cupcakeChocolate, muffinBlueberry, eggTart, strawberryCake, macaron, redVelvetCupcake, matchaCake, cheesecake, birthdayCake, croissant, painAuChocolat, madeleine, eclair, fruitTart, applePie, mooncake, bucheDeNoel }

enum MouldType { cupcakeLiner, muffinCup, tartShell, roundPan, macaronMat, springformPan, tallPan, pastryTray, shellMould, eclairTray, piePan, mooncakeMould, logPan }

enum BatterType { vanilla, chocolate, redVelvet, matcha, butter, almond, cheese, laminated, choux, mooncake }

enum FrostingId { vanillaCream, chocolateGanache, strawberryCream, matchaCream, creamCheese, custard, butterGlaze, appleFilling, lotusPaste }

enum ToppingId { sprinkles, strawberry, cherry, chocolateChips, blueberry, mintLeaf, sugarPearl, candle, almondFlakes, powderedSugar, kiwi, sesame, meringueMushroom }

enum BoxType { small, cake, gift }

/// Thứ tự chơi của 6 trạm.
enum StationId { mould, mix, bake, frost, topping, box }

enum StationIssue { none, wrongMould, underMixed, overMixed, underBaked, burnt, patchy, missingTopping, wrongTopping, wrongBox }

enum FeedbackKey {
  allGood,
  mouldGood,
  mixGood,
  bakeGood,
  frostGood,
  toppingGood,
  boxGood,
  mouldWrong,
  mixUnder,
  mixOver,
  bakeUnder,
  bakeBurnt,
  frostPatchy,
  toppingMissing,
  toppingWrong,
  boxWrong,
}

enum CustomerKind { regular, friend, vip }

enum FriendId { hoa, linh, kenji }

enum CustomerMood { neutral, happy, sad }

/// `rosa` (GĐ8): bà Rosa, khách VIP quen (ảnh `vip_00`).
enum Speaker { narrator, mai, hoa, linh, kenji, rosa }

enum OrderLineKind { generic1, generic2, generic3, generic4, generic5, generic6, vip, hoa, linh, kenji }

enum ToolId { whisk, pipingBag, tongs }

enum DecorSlot { wallpaper, floor, counter, window, plant }

enum DecorId { wallpaperStripes, wallpaperFloral, floorCheckered, floorHerringbone, counterFlowers, counterCakeStand, windowCurtains, windowSeaView, plantFern, plantLemonTree }

enum QuestType { serveCustomers, earnStars, perfectBakes, fiveStarTreats, earnCoins, earnTips }

/// Thêm giá trị mới ở CUỐI. GĐ8: `ch2End` (sau L20, lời kết chương cũ), cảnh chương 3–5, `ch1End` (sau L10); `finale`
/// chuyển về sau L50.
enum StorySceneId {
  prologue,
  hoa1,
  linh1,
  hoa2,
  kenji1,
  linh2,
  kenji2,
  hoa3,
  linh3,
  kenji3,
  finale,
  ch2End,
  ch3Open,
  mochi1,
  kenji4,
  ch4Open,
  rosa1,
  linh4,
  ch5Open,
  hoa4,
  rosa2,
  ch1End,
}

/// Thêm giá trị mới ở CUỐI (không đổi tên giá trị cũ). `offlineDouble`: x2 thu nhập khi vắng nhà (GĐ4). `booster`: một
/// vật phẩm hỗ trợ miễn phí ở thẻ Sẵn sàng, một lần mỗi lượt (GĐ6).
enum AdPlacement { doubleCoins, remake, freeGem, extraTime, offlineDouble, booster }

/// Thêm giá trị mới ở CUỐI. `pantryS/M/L`, `decorSetSeaside`: gói V1, ẩn khỏi cửa hàng V2 (giữ quyền sở hữu cũ).
/// GĐ6: `gemsS/M/L` (kim cương, tiêu hao), `staffOutfits` (một lần), `seasonPass` (theo mùa).
enum IapProductId {
  starterPack,
  pantryS,
  pantryM,
  pantryL,
  decorSetSeaside,
  removeAds,
  gemsS,
  gemsM,
  gemsL,
  staffOutfits,
  seasonPass,
}

/// Thêm giá trị mới ở CUỐI. `comingSoon`: mục mở khoá chưa mua được ở bản này (nhân viên GĐ4…).
enum PurchaseResult { ok, notEnoughCoins, notEnoughGems, locked, maxed, alreadyOwned, comingSoon }

enum LanguagePref { system, en, vi }

/// Tra enum theo `.name`; trả null nếu không có (dữ liệu lưu cũ/hỏng).
T? enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
