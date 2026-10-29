// Toàn bộ enum dùng chung. Tên chốt — dùng `.name` làm khoá lưu, KHÔNG đổi tên.

enum RecipeId { cupcakeVanilla, cupcakeChocolate, muffinBlueberry, eggTart, strawberryCake, macaron, redVelvetCupcake, matchaCake, cheesecake, birthdayCake }

enum MouldType { cupcakeLiner, muffinCup, tartShell, roundPan, macaronMat, springformPan, tallPan }

enum BatterType { vanilla, chocolate, redVelvet, matcha, butter, almond, cheese }

enum FrostingId { vanillaCream, chocolateGanache, strawberryCream, matchaCream, creamCheese, custard }

enum ToppingId { sprinkles, strawberry, cherry, chocolateChips, blueberry, mintLeaf, sugarPearl, candle }

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

enum Speaker { narrator, mai, hoa, linh, kenji }

enum OrderLineKind { generic1, generic2, generic3, generic4, generic5, generic6, vip, hoa, linh, kenji }

enum ToolId { whisk, pipingBag, tongs }

enum DecorSlot { wallpaper, floor, counter, window, plant }

enum DecorId { wallpaperStripes, wallpaperFloral, floorCheckered, floorHerringbone, counterFlowers, counterCakeStand, windowCurtains, windowSeaView, plantFern, plantLemonTree }

enum QuestType { serveCustomers, earnStars, perfectBakes, fiveStarTreats, earnCoins, earnTips }

enum StorySceneId { prologue, hoa1, linh1, hoa2, kenji1, linh2, kenji2, hoa3, linh3, kenji3, finale }

enum AdPlacement { doubleCoins, remake, freeGem }

enum IapProductId { starterPack, pantryS, pantryM, pantryL, decorSetSeaside, removeAds }

enum PurchaseResult { ok, notEnoughCoins, notEnoughGems, locked, maxed, alreadyOwned }

enum UnlockKind { recipe, topping, vipGuests, upgrade, decor, moreCustomers }

enum LanguagePref { system, en, vi }

/// Tra enum theo `.name`; trả null nếu không có (dữ liệu lưu cũ/hỏng).
T? enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
