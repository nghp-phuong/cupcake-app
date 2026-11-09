/// Trạng thái thành phố của một phiên (save v3, docs/v3/city-gd2-spec.md §2): ví + cài đặt + cờ (đã xem intro, mốc
/// cấp đã báo), quảng cáo thưởng trong ngày, IAP đã sở hữu, thống kê tiệm của bà (GĐ3, khoá `bakery`), chi nhánh (GĐ4,
/// khoá `branches` / `staff`). Mỗi hàm ghi gọi `notifyListeners` (không đổi thì không); `CitySaveStore` nghe
/// [CityGame.wallet], [CityGame.settings], [CityGame.branches] và chính đối tượng này để tự lưu.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../branch/city_branches.dart';
import '../economy.dart';
import '../models/ids.dart';
import '../save/city_save.dart';
import '../shift/shift_stats.dart';
import 'city_day.dart';
import 'city_settings.dart';
import 'city_wallet.dart';
import 'player_level.dart';

/// Sổ đếm quảng cáo thưởng mà dịch vụ quảng cáo cần (đợt 2: `FakeAdService(AdLedger)`). Đếm theo ngày lịch của máy.
abstract interface class AdLedger {
  /// Số quảng cáo thưởng đã xem hôm nay.
  int get rewardedToday;

  /// [rewardedToday] < [CityGame.maxRewardedPerDay].
  bool get canShowRewarded;

  /// Gọi sau khi xem xong một quảng cáo thưởng (sang ngày mới thì đếm lại từ 0).
  void registerRewardedShown();
}

class CityGame extends ChangeNotifier implements AdLedger {
  /// [mono]: đồng hồ đơn điệu cho két chi nhánh (mặc định `Stopwatch`; test truyền đồng hồ giả).
  CityGame({
    CityWallet? wallet,
    CitySettings? settings,
    DateTime Function()? clock,
    Duration Function()? mono,
  }) : this._(
         wallet ?? CityWallet(),
         settings ?? CitySettings(),
         clock ?? DateTime.now,
         mono,
       );

  CityGame._(this.wallet, this.settings, this._clock, Duration Function()? mono)
    : branches = CityBranches(wallet: wallet, clock: _clock, mono: mono) {
    _base = CitySave(createdAt: _clock().millisecondsSinceEpoch);
    _levelSeen = wallet.level;
  }

  /// Quảng cáo thưởng tối đa mỗi ngày lịch.
  static const maxRewardedPerDay = Economy.maxRewardedPerDay;

  /// Interstitial: sớm nhất ngày thứ [interstitialFromDay], cách nhau ít nhất [interstitialEveryDays] ngày.
  static const interstitialFromDay = 4, interstitialEveryDays = 2;

  /// Trần các bộ đếm của thống kê tiệm (2^31 − 1).
  static const _countCap = 2147483647;

  final CityWallet wallet;
  final CitySettings settings;

  /// Chi nhánh, nhân viên, két (GĐ4).
  final CityBranches branches;
  final DateTime Function() _clock;

  /// Phần save mà phiên này không sửa (thời điểm tạo, nguồn nhập, khoá để dành, khoá lạ): giữ nguyên khi ghi lại.
  late CitySave _base;
  bool _introSeen = false;
  late int _levelSeen;
  bool _removeAds = false;
  final Set<String> _iap = {};
  String _adsDate = '';
  int _rewarded = 0;
  ShiftStats _bakery = ShiftStats();

  bool get introSeen => _introSeen;

  void markIntroSeen() {
    if (_introSeen) return;
    _introSeen = true;
    notifyListeners();
  }

  /// Cấp đã báo "mở lô" gần nhất (1..30). Cấp hiện tại cao hơn → phố báo bù.
  int get levelSeen => _levelSeen;

  /// Kẹp 1..30; đặt cả khi thấp hơn (cấp giảm thì đặt lại mốc).
  void markLevelSeen(int level) {
    final l = level.clamp(1, PlayerLevel.maxLevel);
    if (l == _levelSeen) return;
    _levelSeen = l;
    notifyListeners();
  }

  bool get removeAds => _removeAds;

  /// Sản phẩm IAP đã sở hữu (giữ cả id lạ); chỉ đọc.
  Set<String> get iapOwned => UnmodifiableSetView(_iap);

  @override
  int get rewardedToday => _adsDate == cityDateKey(_clock()) ? _rewarded : 0;

  @override
  bool get canShowRewarded => rewardedToday < maxRewardedPerDay;

  @override
  void registerRewardedShown() {
    _rollAds(cityDateKey(_clock()));
    _rewarded++;
    notifyListeners();
  }

  /// Kiểm ngày lịch ([now] hoặc đồng hồ): sang ngày mới → ví xoá bộ đếm ăn, tăng số ngày (`CityWallet.rollDay`), đếm
  /// quảng cáo thưởng về 0. Gọi khi nạp và khi app quay lại. Trả true nếu có đổi (đã notify).
  bool refreshDay([DateTime? now]) {
    final today = cityDateKey(now ?? _clock());
    final day = wallet.rollDay(today);
    final ads = _rollAds(today);
    if (ads) notifyListeners();
    return day || ads;
  }

  /// Mở app / quay lại app: [refreshDay] rồi `branches.resume()` (bù két theo giờ máy).
  BranchAway resume([DateTime? now]) {
    refreshDay(now);
    return branches.resume();
  }

  bool _rollAds(String today) {
    if (_adsDate == today) return false;
    _adsDate = today;
    _rewarded = 0;
    return true;
  }

  // ---------------------------------------------------------------- Tiệm của bà (GĐ3)

  /// Thống kê các ca bán; chỉ đọc (sửa qua các hàm bên dưới).
  ShiftStats get bakery => _bakery;

  void _setBakery(ShiftStats next) {
    if (next == _bakery) return;
    _bakery = next;
    notifyListeners();
  }

  /// Ghi một đơn đã tính: +1 đơn, cộng [stars] (kẹp 0..5; 5★ đếm riêng), cộng [coins] (âm → 0).
  void recordOrder({required int stars, required int coins}) {
    final s = stars.clamp(0, 5);
    _setBakery(
      _bakery.copyWith(
        orders: _addCount(_bakery.orders, 1),
        stars: _addCount(_bakery.stars, s),
        five: s == 5 ? _addCount(_bakery.five, 1) : null,
        coins: _addCoins(_bakery.coins, coins),
      ),
    );
  }

  /// Ghi một ca đã đóng: +1 ca; [completed] (hết khách) → kỷ lục [best] = max(best, [coins]).
  void recordShift({required int coins, required bool completed}) {
    _setBakery(
      _bakery.copyWith(
        shifts: _addCount(_bakery.shifts, 1),
        best: completed && coins > _bakery.best
            ? coins.clamp(0, CityWallet.coinCap)
            : null,
      ),
    );
  }

  /// Cộng xu ngoài đơn vào tổng xu của tiệm (x2 quảng cáo cuối ca); không đổi kỷ lục ca. ≤ 0 → không đổi.
  void addBakeryCoins(int coins) {
    if (coins <= 0) return;
    _setBakery(_bakery.copyWith(coins: _addCoins(_bakery.coins, coins)));
  }

  /// Trạm đã xem hướng dẫn (bỏ qua tên lạ trong save; tên lạ vẫn được giữ khi ghi).
  Set<StationId> get tutorialSeen => {
    for (final s in StationId.values)
      if (_bakery.tutorial.contains(s.name)) s,
  };

  void markTutorialSeen(StationId s) {
    if (_bakery.tutorial.contains(s.name)) return;
    _setBakery(_bakery.copyWith(tutorial: {..._bakery.tutorial, s.name}));
  }

  /// Món đã xem hướng dẫn từng bước (chung tập `bakery.tutorial`, mục `recipe.<id>`).
  bool recipeTutorialSeen(RecipeId r) => _bakery.tutorial.contains('recipe.${r.name}');

  void markRecipeTutorialSeen(RecipeId r) {
    final key = 'recipe.${r.name}';
    if (_bakery.tutorial.contains(key)) return;
    _setBakery(_bakery.copyWith(tutorial: {..._bakery.tutorial, key}));
  }

  /// Cấp đã báo "Mở mới!" (1..30); 0 = chưa có mốc (ca bán lấy cấp hiện tại, không báo bù).
  int get recipeSeen => _bakery.recipeSeen;

  /// Kẹp 1..30; đặt cả khi thấp hơn.
  void markRecipeSeen(int level) {
    _setBakery(
      _bakery.copyWith(recipeSeen: level.clamp(1, PlayerLevel.maxLevel)),
    );
  }

  /// Interstitial ở tổng kết ca: từ ngày 4, cách lần trước ít nhất 2 ngày (theo `wallet.dayNumber`), không bao giờ khi
  /// đã mua xoá quảng cáo.
  bool get interstitialDue =>
      !_removeAds &&
      wallet.dayNumber >= interstitialFromDay &&
      wallet.dayNumber - _bakery.adDay >= interstitialEveryDays;

  /// Gọi sau khi hiện interstitial: ghi mốc ngày.
  void registerInterstitialShown() {
    _setBakery(_bakery.copyWith(adDay: wallet.dayNumber));
  }

  static int _addCount(int a, int b) => (a + b).clamp(0, _countCap);

  static int _addCoins(int a, int b) =>
      b <= 0 ? a : (a + b).clamp(0, CityWallet.coinCap);

  /// Khoá lạ ở cấp trên cùng của save (bản app mới hơn ghi); chỉ đọc.
  Map<String, Object?> get extra => _base.extra;

  /// Bản chụp để ghi. Chụp chi nhánh trước khi đọc ví: phần quản lý gửi về đã vào ví, két và ví khớp cùng một lúc.
  CitySave toSave() {
    final book = branches.snapshot();
    return _base.copyWith(
      coins: wallet.coins,
      xp: wallet.xp,
      look: wallet.look,
      dayKey: wallet.dayKey,
      dayNumber: wallet.dayNumber,
      eaten: wallet.eatenToday,
      fullBuff: wallet.fullBuff,
      visited: wallet.visited,
      language: settings.language,
      sound: settings.sound,
      introSeen: _introSeen,
      levelSeen: _levelSeen,
      removeAds: _removeAds,
      adsDate: _adsDate,
      rewarded: _rewarded,
      iap: _iap,
      bakery: _bakery,
      branches: book,
    );
  }

  /// Nạp [s] tại chỗ: giữ nguyên các object [wallet], [settings] và chính nó (màn đang nghe không phải gắn lại).
  void restore(CitySave s) {
    _base = s;
    wallet.restore(
      coins: s.coins,
      xp: s.xp,
      look: s.look,
      visited: s.visited,
      eatenToday: s.eaten,
      fullBuff: s.fullBuff,
      dayKey: s.dayKey,
      dayNumber: s.dayNumber,
    );
    settings
      ..setLanguage(s.language)
      ..setSound(s.sound);
    _introSeen = s.introSeen;
    _levelSeen = s.levelSeen.clamp(1, PlayerLevel.maxLevel);
    _removeAds = s.removeAds;
    _iap
      ..clear()
      ..addAll(s.iap);
    _adsDate = s.adsDate;
    _rewarded = s.rewarded < 0 ? 0 : s.rewarded;
    _bakery = s.bakery;
    branches.restore(s.branches);
    notifyListeners();
  }
}
