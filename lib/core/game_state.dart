import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'economy.dart';
import 'level/level_data.dart';
import 'level/level_progress.dart';
import 'level/level_result.dart';
import 'models/bake.dart';
import 'models/customer.dart';
import 'models/ids.dart';
import 'models/mochi.dart';
import 'models/order.dart';
import 'models/quest.dart';
import 'monetization/monetization.dart';
import 'save_repository.dart';
import 'unlock/shop_setup.dart';
import 'unlock/unlock_config.dart';

export 'monetization/monetization.dart';
export 'unlock/shop_setup.dart';
export 'unlock/unlock_config.dart';

/// Trạng thái một mục mở khoá (`GameState.unlockState`).
enum UnlockState {
  /// Chưa qua level của mục.
  locked,

  /// Đã qua level, chưa mua.
  available,

  /// Đã mua.
  owned,

  /// Chưa mua được ở bản này (đào tạo nhân viên, bộ trang trí hiếm, mở rộng chương sau…).
  comingSoon,
}

/// Trạng thái ván chơi (một nguồn duy nhất). Mỗi hàm ghi gọi `notifyListeners`; khi đã
/// `attachAutosave`, mỗi lần notify sẽ lưu (debounce 300ms, bất đồng bộ).
///
/// Tiến trình V2: kỷ lục từng level ([levelRecord]) + quy tắc mở level/chương tính theo [levelConfig]
/// (gắn bằng [attachLevelConfig] sau khi nạp levels.json). Mở rộng tiệm + thiết bị có cấp theo [unlockConfig]
/// ([attachUnlockConfig], unlocks.json) → [shopSetup] cho mỗi lượt chơi. Nhân viên (GĐ4): thuê bằng [buyUnlock], nâng
/// bằng [upgradeStaff]; quản lý sinh thu nhập khi vắng nhà ([pendingOffline], [refreshOffline], [claimOffline]).
/// GĐ6 ([attachMonetizationConfig], monetization.json): kho vật phẩm hỗ trợ ([boosterCount], [consumeBoosters]),
/// interstitial theo lượt chơi ([shouldShowInterstitialAfterResult]), thẻ mùa ([seasonPoints], [claimSeason]), IAP
/// giả lập ([grantIap], [restoreIap]).
class GameState extends ChangeNotifier {
  GameState.newGame({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _resetToNew();
  }

  /// Thiếu trường → mặc định; từng trường sai kiểu → trường đó về mặc định, các trường khác giữ nguyên.
  factory GameState.fromJson(Map<String, dynamic> json, {DateTime Function()? clock}) {
    final state = GameState.newGame(clock: clock);
    final bad = state._readJson(json);
    if (bad.isNotEmpty) debugPrint('GameState.fromJson: trường hỏng dùng mặc định: ${bad.join(', ')}');
    return state;
  }

  /// v2: thêm `progress` (kỷ lục level), GĐ3 thêm `shop` (mở rộng đã mua, cấp thiết bị, mục đã xem), GĐ4 thêm `staff`
  /// (cấp chỉ số nhân viên), `lastActive` (epoch ms), `offline` (thời gian vắng chưa nhận, xu các lượt gần đây), GĐ6 thêm
  /// `boosters` (kho vật phẩm), `boosterIntro`, `playsSinceInterstitial`, `season`, `frames`, `outfits` — vẫn v2, mỗi
  /// phần đọc độc lập. Bản v1 được quy đổi một lần khi đọc (xem [load]).
  static const saveVersion = 2;
  static const autosaveDelay = Duration(milliseconds: 300);

  /// Quy đổi bản lưu v1: đã chơi tới ngày D → qua L1..min(D−1, [migrationMaxLevel]), mỗi level [migrationStars]★.
  static const migrationMaxLevel = 9, migrationStars = 2;

  /// Quà chào mừng một lần cho người chơi V1 (cộng khi quy đổi, xem [welcomeGiftPending]).
  static const welcomeGiftCoins = 500;
  static const welcomeGiftGems = 20;

  /// Trần ví xu / kim cương: 2^53 − 1 (số nguyên lớn nhất biểu diễn chính xác trên web). Mọi phép cộng ví đi qua
  /// [walletAdd] và bản lưu bị kẹp về [0, walletCap] khi đọc → không bao giờ tràn int rồi bị kẹp về 0.
  static const walletCap = 9007199254740991;

  /// [balance] + [amount], kẹp trong [0, [walletCap]] mà không tràn int ([balance] luôn nằm trong khoảng đó).
  static int walletAdd(int balance, int amount) {
    if (amount >= walletCap - balance) return walletCap;
    if (amount <= -balance) return 0;
    return balance + amount;
  }

  final DateTime Function() _clock;

  int _coins = Economy.startCoins;
  int _gems = Economy.startGems;
  int _xp = 0;
  int _day = 1;

  /// Id thiết bị → cấp (≥ 1). Lò/dụng cụ V1 (`oven`, `tools` trong bản lưu) nằm ở `goldenOven` / `whisk` / … Gồm cả
  /// id không còn trong unlocks.json (giữ nguyên khi lưu).
  final Map<String, int> _equipment = {};

  /// Id mục mở khoá đã mua (gồm cả id không còn trong config).
  final Set<String> _owned = {};

  /// Khoá `UnlockKeys` đã xem (thẻ "Mở khoá mới!" / màn Nâng cấp).
  final Set<String> _seen = {};
  final Set<DecorId> _decorOwned = {};
  final Map<DecorSlot, DecorId?> _decorEquipped = {};
  final Map<RecipeId, int> _mastery = {};

  /// Bí quyết của bà (GĐ8): món → bậc đã mua (thiếu = 0). Khác [_mastery] (sao sổ công thức 0–3).
  final Map<RecipeId, int> _recipeSecrets = {};
  String _questDate = '';
  List<QuestProgress> _quests = const [];
  int _loginStreak = 0;
  String? _loginDate;
  final Set<StorySceneId> _scenes = {};
  final Set<StationId> _tutorial = {};

  /// GĐ5: đã xem cảnh mở đầu (lần đầu mở app) — các lần sau chỉ chạy intro ngắn.
  bool _introSeen = false;

  /// GĐ5: id kịch bản hướng dẫn level đã xong (`TutorialIds`; gồm cả id lạ, giữ nguyên khi lưu).
  final Set<String> _tutorialsDone = {};
  LanguagePref _lang = LanguagePref.system;
  bool _sound = true;
  bool _removeAds = false;
  String _adDate = '';
  int _rewardedToday = 0;
  int? _lastInterstitialDay;
  final Set<IapProductId> _iap = {};
  int _served = 0;
  int _mochiVisits = 0;
  int _mochiPets = 0;
  int _lastMochiDay = 0;

  /// Kỷ lục theo id level — gồm cả id không còn trong config (giữ nguyên khi lưu, bỏ qua khi tính).
  final Map<int, LevelRecord> _levels = {};
  bool _migratedFromV1 = false;
  bool _welcomeGiftPending = false;

  /// Id nhân viên → cấp (tốc độ, tay nghề). Thuê = có trong [_owned]; thiếu ở đây → cấp 1. Gồm cả id không còn trong
  /// config (giữ nguyên khi lưu).
  final Map<String, ({int speed, int skill})> _staffLevels = {};

  /// Mốc hoạt động gần nhất (epoch ms); null = chưa có. Chỉ tiến, không bao giờ lùi ([_touchActive]).
  int? _lastActive;

  /// Thời gian vắng (ms) đã tính mà chưa nhận (cộng dồn qua nhiều lần vắng, trần [maxStoredAway]).
  int _awayMs = 0;

  /// Xu của các lượt chơi level gần nhất (mới nhất cuối, tối đa [recentIncomeCount]) — thu nhập TB cho quản lý.
  final List<int> _recentCoins = [];
  OfflineEarnings? _pendingOffline;
  LevelConfig _levelConfig = LevelConfig.empty();
  UnlockConfig _unlockConfig = UnlockConfig.empty();
  MonetizationConfig _monetization = MonetizationConfig.empty();

  // GĐ6: vật phẩm hỗ trợ, interstitial theo lượt, thẻ mùa, khung chân dung, trang phục.
  final Map<BoosterId, int> _boosters = {};

  /// Đã nhận quà giới thiệu vật phẩm (tới L4) / đã xem thẻ giới thiệu ở thẻ Sẵn sàng.
  bool _boosterGift = false;
  bool _boosterIntroSeen = false;
  int _playsSinceInterstitial = 0;

  /// Id mùa của phần điểm/bậc đang giữ; null = chưa tham gia mùa nào (hoặc mùa trước đã đặt lại).
  String? _seasonId;
  int _seasonPoints = 0;
  final Set<int> _seasonClaimedFree = {};
  final Set<int> _seasonClaimedPremium = {};
  bool _seasonPremium = false;
  SeasonAutoClaim? _seasonAutoClaim;
  final Set<String> _frames = {};
  bool _outfitsEnabled = false;

  /// Kết quả màn đã nhân đôi xu (quảng cáo ở màn kết quả) — một lần mỗi kết quả.
  final Expando<bool> _doubledResults = Expando('doubledResults');

  SaveRepository? _repo;
  Timer? _saveTimer;
  bool _disposed = false;

  /// true → phiên này không ghi lưu (bản lưu từ phiên bản mới hơn, không đọc được bộ nhớ, hoặc không chép được
  /// bản pre_v2 trước khi quy đổi v1).
  bool _savesLocked = false;

  void _resetToNew() {
    final today = _todayKey();
    _coins = Economy.startCoins;
    _gems = Economy.startGems;
    _xp = 0;
    _day = 1;
    _equipment
      ..clear()
      ..addAll({EquipmentIds.goldenOven: 1, for (final t in ToolId.values) t.name: 1});
    _owned.clear();
    _seen.clear();
    _decorOwned.clear();
    _decorEquipped
      ..clear()
      ..addAll({for (final s in DecorSlot.values) s: null});
    _mastery.clear();
    _recipeSecrets.clear();
    _questDate = today;
    _quests = _newQuests(today);
    _loginStreak = 0;
    _loginDate = null;
    _scenes.clear();
    _tutorial.clear();
    _introSeen = false;
    _tutorialsDone.clear();
    _lang = LanguagePref.system;
    _sound = true;
    _removeAds = false;
    _adDate = today;
    _rewardedToday = 0;
    _lastInterstitialDay = null;
    _iap.clear();
    _served = 0;
    _mochiVisits = 0;
    _mochiPets = 0;
    _lastMochiDay = 0;
    _levels.clear();
    _migratedFromV1 = false;
    _welcomeGiftPending = false;
    _staffLevels.clear();
    _lastActive = null;
    _awayMs = 0;
    _recentCoins.clear();
    _pendingOffline = null;
    _boosters.clear();
    _boosterGift = false;
    _boosterIntroSeen = false;
    _playsSinceInterstitial = 0;
    _clearSeason();
    _seasonAutoClaim = null;
    _frames.clear();
    _outfitsEnabled = false;
  }

  void _clearSeason() {
    _seasonId = null;
    _seasonPoints = 0;
    _seasonClaimedFree.clear();
    _seasonClaimedPremium.clear();
    _seasonPremium = false;
  }

  // ------------------------------------------------------------------ Lưu / tải

  /// Đọc ván đã lưu, không bao giờ làm mất dữ liệu cũ:
  /// - JSON hỏng / không phải object → ván mới, chuỗi gốc được chép sang bản dự phòng;
  /// - một số trường hỏng → các trường đó về mặc định, chuỗi gốc cũng được chép dự phòng;
  /// - `v` lớn hơn [saveVersion] (bản app mới hơn đã lưu) hoặc không đọc được bộ nhớ → khoá ghi cả phiên;
  /// - bản v1: chép nguyên chuỗi sang bản pre_v2 ([SaveRepository.backupPreV2], không ghi đè lần 2), quy đổi
  ///   (mọi trường v1 giữ nguyên + kỷ lục level + quà chào mừng một lần) rồi ghi ngay bản v2 để quà không lặp lại.
  ///   Chép pre_v2 thất bại → khoá ghi cả phiên (bản v1 gốc còn nguyên, lần mở sau quy đổi lại).
  static Future<GameState> load(SaveRepository repo, {DateTime Function()? clock}) async {
    final state = GameState.newGame(clock: clock);
    String? raw;
    try {
      raw = await repo.read();
    } catch (e) {
      debugPrint('GameState.load: không đọc được bộ nhớ lưu, phiên này sẽ không ghi đè ($e)');
      state._savesLocked = true;
    }
    if (raw != null && raw.isNotEmpty) {
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        decoded = null;
      }
      if (decoded is! Map<String, dynamic>) {
        debugPrint('GameState.load: dữ liệu lưu hỏng, tạo ván mới và giữ bản dự phòng');
        await _backup(repo, raw);
      } else {
        final v = decoded['v'];
        if (v is num && v > saveVersion) {
          debugPrint('GameState.load: dữ liệu lưu v=$v mới hơn v=$saveVersion, phiên này sẽ không ghi đè');
          state._savesLocked = true;
        }
        final fromV1 = _isV1(decoded);
        if (fromV1) {
          try {
            await repo.backupPreV2(raw);
          } catch (e) {
            debugPrint('GameState.load: không chép được bản pre_v2, phiên này sẽ không ghi đè bản v1 ($e)');
            state._savesLocked = true;
          }
        }
        final bad = state._readJson(decoded);
        if (bad.isNotEmpty) {
          debugPrint('GameState.load: trường hỏng dùng mặc định (${bad.join(', ')}), giữ bản dự phòng');
          await _backup(repo, raw);
        }
        if (fromV1 && !state._savesLocked) {
          try {
            await repo.write(jsonEncode(state.toJson()));
          } catch (e) {
            debugPrint('GameState.load: chưa ghi được bản v2 sau quy đổi ($e)');
          }
        }
      }
    }
    state.refreshDaily();
    return state;
  }

  /// Bản lưu v1 (`v` < 2) → cần quy đổi. Thiếu `v` coi như bản hiện tại (không quy đổi).
  static bool _isV1(Map<String, dynamic> json) {
    final v = json['v'];
    return v is num && v < 2;
  }

  static Future<void> _backup(SaveRepository repo, String raw) async {
    try {
      await repo.backupCorrupt(raw);
    } catch (e) {
      debugPrint('GameState: không chép được bản dự phòng ($e)');
    }
  }

  /// Phiên này có bị khoá ghi lưu không (xem [load]).
  bool get savesLocked => _savesLocked;

  /// true khi vừa quy đổi từ v1 (đã cộng [welcomeGiftCoins] xu + [welcomeGiftGems] đá quý) và chưa hiện lời chào.
  bool get welcomeGiftPending => _welcomeGiftPending;

  /// Đánh dấu lời chào đã hiện (lưu qua autosave).
  void ackWelcomeGift() {
    if (!_welcomeGiftPending) return;
    _welcomeGiftPending = false;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'v': saveVersion,
        'coins': _coins,
        'gems': _gems,
        'xp': _xp,
        'day': _day,
        // Trường V1 (app cũ vẫn đọc được); bản đầy đủ ở `shop.equipment`.
        'oven': ovenLevel,
        'tools': {for (final t in ToolId.values) t.name: toolLevel(t)},
        'decorOwned': [for (final d in DecorId.values) if (_decorOwned.contains(d)) d.name],
        'decorEquipped': {for (final s in DecorSlot.values) s.name: _decorEquipped[s]?.name},
        'mastery': {for (final r in RecipeId.values) r.name: recipeMastery(r)},
        'recipeSecrets': {for (final r in RecipeId.values) r.name: _recipeSecrets[r] ?? 0},
        'questDate': _questDate,
        'quests': [
          for (final q in _quests) {'type': q.type.name, 'progress': q.progress, 'claimed': q.claimed},
        ],
        'loginStreak': _loginStreak,
        'loginDate': _loginDate,
        'scenes': [for (final s in StorySceneId.values) if (_scenes.contains(s)) s.name],
        'tutorial': [for (final s in StationId.values) if (_tutorial.contains(s)) s.name],
        'introSeen': _introSeen,
        'tutorialsDone': _tutorialsDone.toList()..sort(),
        'lang': _lang.name,
        'sound': _sound,
        'removeAds': _removeAds,
        'adDate': _adDate,
        'rewardedToday': _rewardedToday,
        'lastInterstitialDay': _lastInterstitialDay,
        'iap': [for (final p in IapProductId.values) if (_iap.contains(p)) p.name],
        'served': _served,
        'mochiVisits': _mochiVisits,
        'mochiPets': _mochiPets,
        'lastMochiDay': _lastMochiDay,
        'progress': {
          'levels': {
            for (final id in (_levels.keys.toList()..sort())) '$id': _levels[id]!.toJson(),
          },
          'migratedFromV1': _migratedFromV1,
          'welcomeGiftPending': _welcomeGiftPending,
        },
        'shop': {
          'owned': _owned.toList()..sort(),
          'equipment': {for (final id in (_equipment.keys.toList()..sort())) id: _equipment[id]},
          'seen': _seen.toList()..sort(),
        },
        'staff': {
          for (final id in (_staffLevels.keys.toList()..sort()))
            id: {'speed': _staffLevels[id]!.speed, 'skill': _staffLevels[id]!.skill},
        },
        'lastActive': _lastActive,
        'offline': {'awayMs': _awayMs, 'recentCoins': List.of(_recentCoins)},
        'boosters': {for (final b in BoosterId.values) b.name: boosterCount(b)},
        'boosterIntro': {'gift': _boosterGift, 'seen': _boosterIntroSeen},
        'playsSinceInterstitial': _playsSinceInterstitial,
        'season': {
          'id': _seasonId,
          'points': _seasonPoints,
          'claimedFree': _seasonClaimedFree.toList()..sort(),
          'claimedPremium': _seasonClaimedPremium.toList()..sort(),
          'premium': _seasonPremium,
          'autoClaim': _seasonAutoClaim == null ? null : _autoClaimToJson(_seasonAutoClaim!),
        },
        'frames': _frames.toList()..sort(),
        'outfits': {'enabled': _outfitsEnabled},
      };

  static Map<String, dynamic> _autoClaimToJson(SeasonAutoClaim a) => {
        'seasonId': a.seasonId,
        'coins': a.coins,
        'gems': a.gems,
        'boosters': {for (final e in a.boosters.entries) e.key.name: e.value},
        'frames': List.of(a.frames),
      };

  /// Ghi đè các trường có trong [json]; trường thiếu hoặc null giữ mặc định. Mỗi trường đọc độc lập:
  /// sai kiểu → giữ mặc định của trường đó, các trường khác không ảnh hưởng. Trả về tên các trường hỏng.
  List<String> _readJson(Map<String, dynamic> json) {
    final bad = <String>[];
    void field(String key, void Function(Object v) read) {
      final v = json[key];
      if (v == null) return;
      try {
        read(v);
      } catch (_) {
        bad.add(key);
      }
    }

    /// Map tên → số: phần tử hỏng bị bỏ qua (trường vẫn bị đánh dấu hỏng), phần tử tốt được giữ.
    void numMap(String key, void Function(String name, int value) read) {
      field(key, (v) {
        var failed = false;
        (v as Map<String, dynamic>).forEach((name, value) {
          if (value is num) {
            read(name, value.toInt());
          } else {
            failed = true;
          }
        });
        if (failed) bad.add(key);
      });
    }

    void names(String key, void Function(Object? name) read) => field(key, (v) => (v as List<dynamic>).forEach(read));

    int asInt(Object v) => (v as num).toInt();
    // So sánh trước khi toInt: 1e300 / ±vô cực không bị đổi thành 2^63 − 1 (NaN.toInt() ném → trường hỏng).
    int asWallet(Object v) {
      final n = v as num;
      if (n >= walletCap) return walletCap;
      return n <= 0 ? 0 : n.toInt();
    }

    field('coins', (v) => _coins = asWallet(v));
    field('gems', (v) => _gems = asWallet(v));
    field('xp', (v) => _xp = math.max(0, asInt(v)));
    field('day', (v) => _day = math.max(1, asInt(v)));
    // Lò/dụng cụ V1 → thiết bị goldenOven / whisk / pipingBag / tongs (`shop.equipment` đọc sau, lấy cấp cao hơn).
    field('oven', (v) => _equipment[EquipmentIds.goldenOven] = asInt(v).clamp(1, Economy.maxOvenLevel));

    numMap('tools', (name, value) {
      final id = enumByName(ToolId.values, name);
      if (id != null) _equipment[id.name] = value.clamp(1, Economy.maxToolLevel(id));
    });

    names('decorOwned', (name) {
      final id = enumByName(DecorId.values, name);
      if (id != null) _decorOwned.add(id);
    });
    field('decorEquipped', (v) {
      (v as Map<String, dynamic>).forEach((k, value) {
        final slot = enumByName(DecorSlot.values, k);
        final id = enumByName(DecorId.values, value);
        if (slot != null && (id == null || (_decorOwned.contains(id) && Catalog.decorItem(id).slot == slot))) {
          _decorEquipped[slot] = id;
        }
      });
    });

    numMap('mastery', (name, value) {
      final id = enumByName(RecipeId.values, name);
      if (id != null) _mastery[id] = value.clamp(0, 3);
    });

    // GĐ8: đọc độc lập, thiếu → 0; bậc vượt số bậc của config bị kẹp khi đọc ([recipeSecretTier]).
    numMap('recipeSecrets', (name, value) {
      final id = enumByName(RecipeId.values, name);
      if (id != null && value > 0) _recipeSecrets[id] = math.min(value, maxRecipeSecretTier);
    });

    _readQuests(json, bad);

    field('loginStreak', (v) => _loginStreak = asInt(v).clamp(0, Catalog.loginRewards.length));
    field('loginDate', (v) => _loginDate = v as String);

    names('scenes', (name) {
      final id = enumByName(StorySceneId.values, name);
      if (id != null) _scenes.add(id);
    });
    names('tutorial', (name) {
      final id = enumByName(StationId.values, name);
      if (id != null) _tutorial.add(id);
    });
    field('introSeen', (v) => _introSeen = v as bool);
    field('tutorialsDone', (v) {
      var failed = false;
      for (final id in v as List<dynamic>) {
        if (id is String && id.isNotEmpty) {
          _tutorialsDone.add(id);
        } else {
          failed = true;
        }
      }
      if (failed) bad.add('tutorialsDone');
    });

    field('lang', (v) => _lang = enumByName(LanguagePref.values, v) ?? (throw FormatException('lang: $v')));
    field('sound', (v) => _sound = v as bool);
    field('removeAds', (v) => _removeAds = v as bool);
    field('adDate', (v) => _adDate = v as String);
    field('rewardedToday', (v) => _rewardedToday = math.max(0, asInt(v)));
    field('lastInterstitialDay', (v) => _lastInterstitialDay = asInt(v));

    names('iap', (name) {
      final id = enumByName(IapProductId.values, name);
      if (id != null) _iap.add(id);
    });
    field('served', (v) => _served = math.max(0, asInt(v)));
    field('mochiVisits', (v) => _mochiVisits = math.max(0, asInt(v)));
    field('mochiPets', (v) => _mochiPets = math.max(0, asInt(v)));
    field('lastMochiDay', (v) => _lastMochiDay = math.max(0, asInt(v)));

    _readProgress(json, bad);
    _migrateFinale();
    _readShop(json, bad);
    _readStaff(json, bad);
    field('lastActive', (v) {
      final ms = v as num;
      if (!ms.isFinite || ms < 0) throw FormatException('lastActive: $v');
      _lastActive = ms.toInt();
    });
    _readOffline(json, bad);
    _readMonetization(json, bad);
    if (_isV1(json) && !_migratedFromV1) {
      _migrateFromV1();
    } else if (_migratedFromV1 || _levels.isNotEmpty) {
      // Bản v2 trước GĐ5 (chưa có hai trường này) đã quy đổi từ v1 hoặc đã chơi level: người chơi cũ, không chiếu lại
      // cảnh mở đầu / hướng dẫn L1–3. Bản đã có trường (kể cả sau khi reset trong Cài đặt) giữ nguyên.
      if (json['introSeen'] == null) _introSeen = true;
      if (json['tutorialsDone'] == null) _tutorialsDone.addAll(TutorialIds.all);
    }
    return bad;
  }

  /// Màn có cảnh kết `finale` (GĐ8, sau khi thắng lần đầu).
  static const finaleLevel = 50;

  /// Trước GĐ8 `finale` là lời kết sau L10 (nay là `ch2End`, sau L20). Bản lưu đã xem `finale` mà chưa thắng
  /// [finaleLevel] → đó là lời kết cũ: đổi thành `ch2End` + `ch1End` (không chiếu lại ở L10 / L20) để `finale` mới vẫn
  /// chiếu sau L50.
  void _migrateFinale() {
    if (_scenes.contains(StorySceneId.finale) && (_levels[finaleLevel]?.stars ?? 0) == 0) {
      _scenes
        ..remove(StorySceneId.finale)
        ..add(StorySceneId.ch2End)
        ..add(StorySceneId.ch1End);
    }
  }

  /// GĐ6: `boosters` (id → số, ≥ 0), `boosterIntro` {gift, seen}, `playsSinceInterstitial`, `season` {id, points,
  /// claimedFree[], claimedPremium[], premium, autoClaim}, `frames` [], `outfits` {enabled}. Mỗi phần (và mỗi trường con)
  /// đọc độc lập; id vật phẩm lạ bị bỏ (đánh dấu hỏng).
  void _readMonetization(Map<String, dynamic> json, List<String> bad) {
    final boosters = json['boosters'];
    if (boosters is Map<String, dynamic>) {
      boosters.forEach((name, n) {
        final id = enumByName(BoosterId.values, name);
        if (id != null && n is num && n.isFinite && n >= 0) {
          _boosters[id] = math.min(n.toInt(), maxBoosterStock);
        } else {
          bad.add('boosters.$name');
        }
      });
    } else if (boosters != null) {
      bad.add('boosters');
    }

    bool? flag(Map<String, dynamic> m, String key, String where) {
      final v = m[key];
      if (v == null || v is bool) return v as bool?;
      bad.add('$where.$key');
      return null;
    }

    final intro = json['boosterIntro'];
    if (intro is Map<String, dynamic>) {
      _boosterGift = flag(intro, 'gift', 'boosterIntro') ?? false;
      _boosterIntroSeen = flag(intro, 'seen', 'boosterIntro') ?? false;
    } else if (intro != null) {
      bad.add('boosterIntro');
    }

    final plays = json['playsSinceInterstitial'];
    if (plays is num && plays.isFinite && plays >= 0) {
      _playsSinceInterstitial = math.min(plays.toInt(), 1 << 20);
    } else if (plays != null) {
      bad.add('playsSinceInterstitial');
    }

    _readSeason(json, bad);

    final frames = json['frames'];
    if (frames is List) {
      for (final f in frames) {
        if (f is String && f.isNotEmpty) {
          _frames.add(f);
        } else {
          bad.add('frames');
        }
      }
    } else if (frames != null) {
      bad.add('frames');
    }

    final outfits = json['outfits'];
    if (outfits is Map<String, dynamic>) {
      _outfitsEnabled = flag(outfits, 'enabled', 'outfits') ?? false;
    } else if (outfits != null) {
      bad.add('outfits');
    }
  }

  void _readSeason(Map<String, dynamic> json, List<String> bad) {
    final season = json['season'];
    if (season == null) return;
    if (season is! Map<String, dynamic>) {
      bad.add('season');
      return;
    }
    final id = season['id'];
    if (id != null && (id is! String || id.isEmpty)) {
      // Không biết mùa nào → bỏ cả phần mùa (điểm không gắn được với mùa).
      bad.add('season.id');
      return;
    }
    _seasonId = id as String?;
    final points = season['points'];
    if (points is num && points.isFinite && points >= 0) {
      _seasonPoints = math.min(points.toInt(), 1 << 30);
    } else if (points != null) {
      bad.add('season.points');
    }
    void tiers(String key, Set<int> into) {
      final v = season[key];
      if (v == null) return;
      if (v is! List) {
        bad.add('season.$key');
        return;
      }
      for (final t in v) {
        if (t is num && t.isFinite && t >= 1 && t == t.toInt()) {
          into.add(t.toInt());
        } else {
          bad.add('season.$key');
        }
      }
    }

    tiers('claimedFree', _seasonClaimedFree);
    tiers('claimedPremium', _seasonClaimedPremium);
    final premium = season['premium'];
    if (premium is bool) {
      _seasonPremium = premium;
    } else if (premium != null) {
      bad.add('season.premium');
    }
    final auto = season['autoClaim'];
    if (auto is Map<String, dynamic>) {
      try {
        final boosters = <BoosterId, int>{};
        ((auto['boosters'] ?? const <String, dynamic>{}) as Map<String, dynamic>).forEach((k, v) {
          final b = enumByName(BoosterId.values, k);
          if (b != null) boosters[b] = (v as num).toInt();
        });
        _seasonAutoClaim = SeasonAutoClaim(
          seasonId: auto['seasonId'] as String,
          coins: (auto['coins'] as num? ?? 0).toInt(),
          gems: (auto['gems'] as num? ?? 0).toInt(),
          boosters: Map.unmodifiable(boosters),
          frames: List.unmodifiable([for (final f in (auto['frames'] ?? const []) as List) f as String]),
        );
      } catch (_) {
        bad.add('season.autoClaim');
      }
    } else if (auto != null) {
      bad.add('season.autoClaim');
    }
  }

  /// `staff` (GĐ4): id → {"speed": cấp, "skill": cấp}. Mỗi nhân viên đọc độc lập; chỉ số thiếu → 1, sai kiểu → 1 (đánh
  /// dấu hỏng). Cấp kẹp 1..[maxEquipmentTier] (cấp theo config kẹp khi đọc ra).
  void _readStaff(Map<String, dynamic> json, List<String> bad) {
    final staff = json['staff'];
    if (staff == null) return;
    if (staff is! Map<String, dynamic>) {
      bad.add('staff');
      return;
    }
    staff.forEach((id, v) {
      if (id.isEmpty || v is! Map<String, dynamic>) {
        bad.add('staff.$id');
        return;
      }
      var failed = false;
      int level(String k) {
        final n = v[k];
        if (n == null) return 1;
        if (n is num && n.isFinite) return n.toInt().clamp(1, maxEquipmentTier);
        failed = true;
        return 1;
      }

      _staffLevels[id] = (speed: level('speed'), skill: level('skill'));
      if (failed) bad.add('staff.$id');
    });
  }

  /// `offline` (GĐ4): `awayMs` (≥ 0) và `recentCoins` (mảng số ≥ 0), đọc độc lập.
  void _readOffline(Map<String, dynamic> json, List<String> bad) {
    final offline = json['offline'];
    if (offline == null) return;
    if (offline is! Map<String, dynamic>) {
      bad.add('offline');
      return;
    }
    final away = offline['awayMs'];
    if (away is num && away.isFinite && away >= 0) {
      _awayMs = math.min(away.toInt(), maxStoredAway.inMilliseconds);
    } else if (away != null) {
      bad.add('offline.awayMs');
    }
    final recent = offline['recentCoins'];
    if (recent is List) {
      var failed = false;
      for (final c in recent) {
        if (c is num && c.isFinite && c >= 0) {
          _recentCoins.add(c.toInt());
        } else {
          failed = true;
        }
      }
      while (_recentCoins.length > recentIncomeCount) {
        _recentCoins.removeAt(0);
      }
      if (failed) bad.add('offline.recentCoins');
    } else if (recent != null) {
      bad.add('offline.recentCoins');
    }
  }

  /// `shop` (GĐ3): `owned` / `seen` là mảng chuỗi, `equipment` là map id → cấp. Mỗi phần đọc độc lập; phần tử hỏng bị
  /// bỏ (đánh dấu hỏng), id lạ được giữ nguyên. Cấp thiết bị = max(trường V1 `oven`/`tools`, `shop.equipment`).
  /// Thiếu `shop` (bản v2 trước GĐ3) → chưa mua mở rộng nào, thiết bị lấy từ trường V1.
  void _readShop(Map<String, dynamic> json, List<String> bad) {
    final shop = json['shop'];
    if (shop == null) return;
    if (shop is! Map<String, dynamic>) {
      bad.add('shop');
      return;
    }
    void ids(String key, Set<String> into) {
      final v = shop[key];
      if (v == null) return;
      if (v is! List) {
        bad.add('shop.$key');
        return;
      }
      var failed = false;
      for (final e in v) {
        if (e is String && e.isNotEmpty) {
          into.add(e);
        } else {
          failed = true;
        }
      }
      if (failed) bad.add('shop.$key');
    }

    ids('owned', _owned);
    ids('seen', _seen);
    final eq = shop['equipment'];
    if (eq == null) return;
    if (eq is! Map<String, dynamic>) {
      bad.add('shop.equipment');
      return;
    }
    var failed = false;
    eq.forEach((id, v) {
      if (id.isNotEmpty && v is num && v.isFinite) {
        _equipment[id] = math.max(_equipment[id] ?? 1, v.toInt().clamp(1, maxEquipmentTier));
      } else {
        failed = true;
      }
    });
    if (failed) bad.add('shop.equipment');
  }

  /// `progress`: mỗi level đọc độc lập; trường sai kiểu → trường đó về mặc định (đánh dấu hỏng), khoá không phải
  /// số nguyên dương → bỏ (đánh dấu hỏng, chuỗi gốc vào bản dự phòng).
  void _readProgress(Map<String, dynamic> json, List<String> bad) {
    final progress = json['progress'];
    if (progress == null) return;
    if (progress is! Map<String, dynamic>) {
      bad.add('progress');
      return;
    }
    final migrated = progress['migratedFromV1'];
    if (migrated is bool) {
      _migratedFromV1 = migrated;
    } else if (migrated != null) {
      bad.add('progress.migratedFromV1');
    }
    // Thiếu (bản v2 trước khi có cờ này) → coi như lời chào đã hiện.
    final gift = progress['welcomeGiftPending'];
    if (gift is bool) {
      _welcomeGiftPending = gift;
    } else if (gift != null) {
      bad.add('progress.welcomeGiftPending');
    }
    final levels = progress['levels'];
    if (levels == null) return;
    if (levels is! Map<String, dynamic>) {
      bad.add('progress.levels');
      return;
    }
    levels.forEach((key, value) {
      final id = int.tryParse(key);
      if (id == null || id < 1 || value is! Map<String, dynamic>) {
        bad.add('progress.levels.$key');
        return;
      }
      var failed = false;
      int count(String k, {int max = 1 << 31}) {
        final v = value[k];
        if (v == null) return 0;
        if (v is num && v.isFinite) return v.toInt().clamp(0, max);
        failed = true;
        return 0;
      }

      final stars = count('stars', max: 3);
      final best = count('best');
      final plays = count('plays');
      final win = value['firstWin'];
      if (win != null && win is! bool) failed = true;
      if (failed) bad.add('progress.levels.$key');
      _levels[id] = LevelRecord(
        stars: stars,
        best: best,
        plays: math.max(plays, stars > 0 ? 1 : 0),
        firstWin: win == true,
      );
    });
  }

  /// Quy đổi v1 → v2 (một lần): đã chơi tới ngày D → qua L1..min(D−1, 9) mỗi level 2★ (lượt đầu thắng), + quà
  /// chào mừng ([welcomeGiftPending] = true tới khi UI gọi [ackWelcomeGift]). Không đè kỷ lục đã có.
  /// Trường `day` hỏng → về 1 → không level nào, nhưng vẫn tặng quà (cố ý: người chơi V1 vẫn được chào mừng).
  void _migrateFromV1() {
    final last = math.min(_day - 1, migrationMaxLevel);
    for (var id = 1; id <= last; id++) {
      _levels.putIfAbsent(id, () => const LevelRecord(stars: migrationStars, plays: 1, firstWin: true));
    }
    _coins = walletAdd(_coins, welcomeGiftCoins);
    _gems = walletAdd(_gems, welcomeGiftGems);
    _migratedFromV1 = true;
    _welcomeGiftPending = true;
    // Người chơi V1 đã biết cách chơi: bỏ cảnh mở đầu + hướng dẫn L1–3.
    _introSeen = true;
    _tutorialsDone.addAll(TutorialIds.all);
  }

  /// Nhiệm vụ ngày phải đúng 3 mục hợp lệ, khác loại nhau; nếu không → 3 nhiệm vụ mới của hôm nay.
  void _readQuests(Map<String, dynamic> json, List<String> bad) {
    final date = json['questDate'];
    final list = json['quests'];
    if (date == null && list == null) return;
    List<QuestProgress>? parsed;
    if (date is String && list is List) {
      try {
        parsed = [
          for (final q in list)
            if (q case {'type': final Object? type})
              QuestProgress(
                type: enumByName(QuestType.values, type) ?? (throw FormatException('quest: $type')),
                progress: math.max(0, (q['progress'] as num?)?.toInt() ?? 0),
                claimed: q['claimed'] as bool? ?? false,
              )
            else
              throw FormatException('quest: $q'),
        ];
      } catch (_) {
        parsed = null;
      }
    }
    if (parsed != null && parsed.length == 3 && parsed.map((q) => q.type).toSet().length == 3) {
      _questDate = date as String;
      _quests = List.unmodifiable(parsed);
      return;
    }
    bad.add('quests');
    final today = _todayKey();
    _questDate = today;
    _quests = _newQuests(today);
  }

  /// Mỗi lần notifyListeners → lưu sau 300ms (gộp nhiều thay đổi), bất đồng bộ.
  void attachAutosave(SaveRepository repo) {
    _repo = repo;
    removeListener(_scheduleSave);
    addListener(_scheduleSave);
  }

  void _scheduleSave() {
    if (_repo == null || _disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, () => unawaited(_save()));
  }

  Future<void> _save() async {
    final repo = _repo;
    if (repo == null) return;
    if (_savesLocked) {
      debugPrint('GameState: bỏ qua lưu (phiên bị khoá ghi để giữ dữ liệu cũ)');
      return;
    }
    try {
      await repo.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('GameState: lưu thất bại ($e)');
    }
  }

  /// Lưu ngay (gọi khi app paused).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _save();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _heartbeat?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ Ngày lịch

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _todayKey() => dateKey(_clock());

  String _yesterdayKey() {
    final now = _clock();
    return dateKey(DateTime(now.year, now.month, now.day - 1));
  }

  /// 3 loại nhiệm vụ khác nhau của một ngày lịch, chọn bằng `Random(yyyymmdd)`.
  static List<QuestType> questTypesFor(String dateKey) {
    final seed = int.tryParse(dateKey.replaceAll('-', '')) ?? 0;
    final types = List<QuestType>.of(QuestType.values)..shuffle(math.Random(seed));
    return types.take(3).toList();
  }

  static List<QuestProgress> _newQuests(String dateKey) =>
      List.unmodifiable([for (final t in questTypesFor(dateKey)) QuestProgress(type: t)]);

  /// Đổi ngày lịch → nhiệm vụ mới, rewardedToday = 0. Trả true nếu có thay đổi (không notify).
  bool _rollDaily() {
    final today = _todayKey();
    var changed = false;
    if (_questDate != today) {
      _questDate = today;
      _quests = _newQuests(today);
      changed = true;
    }
    if (_adDate != today) {
      _adDate = today;
      _rewardedToday = 0;
      changed = true;
    }
    return changed;
  }

  /// Gọi khi load và mỗi lần vào menu chính. Cũng: kiểm tra mùa (hết mùa / đổi mùa → tự nhận thưởng chờ, xem
  /// [seasonAutoClaim]) và quà giới thiệu vật phẩm cho bản lưu cũ đã qua L3.
  void refreshDaily() {
    final daily = _rollDaily();
    final season = _refreshSeason();
    final gift = _grantBoosterGift();
    if (daily || season || gift) notifyListeners();
  }

  // ------------------------------------------------------------------ Đọc

  int get coins => _coins;
  int get gems => _gems;
  /// XP của V1 (chỉ còn đọc/ghi trong bản lưu, V2 không cộng nữa).
  int get xp => _xp;

  /// "Cấp tiệm" V1 quy đổi từ số level đã qua — chỉ dùng khi chưa gắn levels.json (mở món/topping như trước).
  static int _legacyShopLevel(int passed) => passed <= 0 ? 1 : math.min(Economy.maxLevel, 1 + (passed + 1) ~/ 2);

  /// Ngày game sắp chơi (bắt đầu 1).
  int get dayNumber => _day;

  /// Cấp lò vùng vàng (thiết bị `goldenOven`) 1..5.
  int get ovenLevel => equipmentTier(EquipmentIds.goldenOven);

  /// Cấp dụng cụ (thiết bị cùng tên) 1..3.
  int toolLevel(ToolId id) => equipmentTier(id.name);

  Set<DecorId> get ownedDecor => Set.unmodifiable(_decorOwned);
  Map<DecorSlot, DecorId?> get equippedDecor =>
      Map.unmodifiable({for (final s in DecorSlot.values) s: _decorEquipped[s]});

  /// Tổng % tip của đồ trang trí đang đặt, đã áp trần 30.
  int get decorTipBonusPct {
    var sum = 0;
    for (final id in _decorEquipped.values) {
      if (id != null) sum += Catalog.decorItem(id).tipBonusPct;
    }
    return math.min(sum, Economy.decorTipCapPct);
  }

  /// 0..3.
  int recipeMastery(RecipeId id) => _mastery[id] ?? 0;

  // ------------------------------------------------------------------ Bí quyết của bà (GĐ8)

  /// Trần bậc lưu được (phòng bản lưu hỏng); số bậc thật theo `unlocks.json`.
  static const maxRecipeSecretTier = 9;

  /// Cấu hình Bí quyết của bà (`unlocks.json`); null = không có (tính năng khoá).
  RecipeSecretsData? get recipeSecretsConfig => _unlockConfig.recipeSecrets;

  /// Đã mở tính năng (đã qua màn `recipeSecretsConfig.level`, 41).
  bool get recipeSecretsUnlocked {
    final cfg = _unlockConfig.recipeSecrets;
    return cfg != null && highestCompletedLevel >= cfg.level;
  }

  /// Số bậc tối đa của một món (0 nếu không có cấu hình).
  int get recipeSecretMaxTier => _unlockConfig.recipeSecrets?.maxTier ?? 0;

  /// Bậc đã mua của món [id] (0..[recipeSecretMaxTier]).
  int recipeSecretTier(RecipeId id) {
    final t = _recipeSecrets[id] ?? 0;
    final cfg = _unlockConfig.recipeSecrets;
    return cfg == null ? t : math.min(t, cfg.maxTier);
  }

  /// % đang cộng vào giá bán món [id] (0 nếu chưa mua bậc nào).
  int recipeSecretPricePct(RecipeId id) {
    final cfg = _unlockConfig.recipeSecrets;
    final t = recipeSecretTier(id);
    return cfg == null || t == 0 ? 0 : cfg.tiers[t - 1].pricePct;
  }

  /// % giá bán của bậc kế tiếp của món [id]; null khi đã tối đa / không có cấu hình.
  int? recipeSecretNextPricePct(RecipeId id) {
    final cfg = _unlockConfig.recipeSecrets;
    final t = recipeSecretTier(id);
    return cfg == null || t >= cfg.maxTier ? null : cfg.tiers[t].pricePct;
  }

  /// Giá bán gốc của món (4★, hệ số 1.0) sau khi cộng bí quyết — để hiển thị.
  int recipeSellPrice(RecipeId id) => (Catalog.recipe(id).price * (100 + recipeSecretPricePct(id)) / 100).round();

  /// Giá xu của bậc kế tiếp = `round50(giá món × costMult)`; null khi chưa mở tính năng, món chưa mở, hoặc đã tối đa.
  int? recipeSecretPrice(RecipeId id) {
    final cfg = _unlockConfig.recipeSecrets;
    if (cfg == null || !recipeSecretsUnlocked || !isRecipeUnlocked(id)) return null;
    final t = recipeSecretTier(id);
    if (t >= cfg.maxTier) return null;
    return Economy.round50(Catalog.recipe(id).price * cfg.tiers[t].costMult);
  }

  /// Mua bậc kế tiếp của món [id]; false nếu không mua được ([recipeSecretPrice] null) hoặc thiếu xu.
  bool buyRecipeSecret(RecipeId id) {
    final price = recipeSecretPrice(id);
    if (price == null || _coins < price) return false;
    _coins -= price;
    _recipeSecrets[id] = recipeSecretTier(id) + 1;
    notifyListeners();
    return true;
  }

  /// Món có trong menu của một level đã mở. Chưa gắn levels.json (cấu hình rỗng) → theo cấp tiệm như V1.
  bool isRecipeUnlocked(RecipeId id) => _unlockedRecipeSet().contains(id);

  /// Topping mở theo level đã mở xa nhất (khớp `LevelSession`: `toppingUnlockLevel` ≤ id level). Cấu hình rỗng → cấp
  /// tiệm.
  bool isToppingUnlocked(ToppingId id) =>
      (Catalog.toppingUnlockLevel[id] ?? 1) <=
      (_levelConfig.isEmpty ? _legacyShopLevel(highestCompletedLevel) : currentLevelId);

  /// Theo thứ tự `Catalog.recipes`.
  List<RecipeId> get unlockedRecipes {
    final set = _unlockedRecipeSet();
    return [
      for (final r in Catalog.recipes)
        if (set.contains(r.id)) r.id,
    ];
  }

  Set<RecipeId> _unlockedRecipeSet() {
    if (_levelConfig.isEmpty) {
      final shopLevel = _legacyShopLevel(highestCompletedLevel);
      return {
        for (final r in Catalog.recipes)
          if (shopLevel >= r.unlockLevel) r.id,
      };
    }
    final unlocked = _unlockedLevelIds();
    return {
      for (final l in _levelConfig.levels)
        if (unlocked.contains(l.id)) ...l.menu,
    };
  }

  List<ToppingId> get unlockedToppings => [
        for (final t in ToppingId.values)
          if (isToppingUnlocked(t)) t,
      ];

  /// 3 nhiệm vụ hôm nay.
  List<QuestProgress> get quests => _quests;

  /// Quà sẽ nhận hôm nay; null nếu hôm nay đã nhận.
  LoginReward? get pendingLoginReward {
    if (_loginDate == _todayKey()) return null;
    final continues = _loginDate == _yesterdayKey() && _loginStreak < Catalog.loginRewards.length;
    return Catalog.loginReward(continues ? _loginStreak + 1 : 1);
  }

  /// 0..7: ngày quà đã nhận gần nhất trong chuỗi hiện tại (0 nếu chuỗi đã đứt hoặc vừa hết vòng 7).
  int get loginStreakDay {
    if (_loginDate == _todayKey()) return _loginStreak;
    if (_loginDate == _yesterdayKey() && _loginStreak < Catalog.loginRewards.length) return _loginStreak;
    return 0;
  }

  Set<StorySceneId> get seenScenes => Set.unmodifiable(_scenes);
  /// Đã xong chương 1 (nghĩa như trước GĐ8): đã xem lời kết `ch1End` (sau L10), `ch2End` (sau L20) hoặc `finale` (sau
  /// L50) — người chơi xem cảnh sau thì chắc chắn đã qua L10; bản lưu cũ đã xem `finale` cũ được đổi thành
  /// `ch1End` + `ch2End` ([_migrateFinale]). Xem `docs/v2/phase8-spec.md` §2.3.
  bool get chapter1Complete =>
      _scenes.contains(StorySceneId.ch1End) ||
      _scenes.contains(StorySceneId.ch2End) ||
      _scenes.contains(StorySceneId.finale);
  Set<StationId> get tutorialSeen => Set.unmodifiable(_tutorial);

  /// Đã xem cảnh mở đầu (hoặc bỏ qua) → các lần mở sau chạy intro ngắn rồi vào bản đồ.
  bool get introSeen => _introSeen;

  /// Kịch bản hướng dẫn [id] (`TutorialIds`) đã xong → lượt chơi level đó không tạo hướng dẫn.
  bool isTutorialDone(String id) => _tutorialsDone.contains(id);

  /// Id các kịch bản đã xong (chỉ đọc).
  Set<String> get tutorialsDone => Set.unmodifiable(_tutorialsDone);
  LanguagePref get language => _lang;
  bool get soundOn => _sound;
  bool get removeAds => _removeAds;

  /// Số rewarded đã xem hôm nay (ngày lịch); ngày đã qua → 0.
  int get rewardedToday => _adDate == _todayKey() ? _rewardedToday : 0;
  /// Trường V1 (interstitial theo ngày): chỉ còn đọc/ghi lại nguyên giá trị trong bản lưu, V2 không dùng.
  int? get lastInterstitialDay => _lastInterstitialDay;

  /// Số rewarded còn xem được hôm nay (chung mọi chỗ, [Economy.maxRewardedPerDay]).
  int get rewardedLeftToday => math.max(0, Economy.maxRewardedPerDay - rewardedToday);
  Set<IapProductId> get ownedIap => Set.unmodifiable(_iap);
  int get totalServed => _served;

  /// Số lần mèo Mochi đã ghé (ngày mưa).
  int get mochiVisits => _mochiVisits;

  /// Số lần đã vuốt ve Mochi.
  int get mochiPets => _mochiPets;

  /// Ngày game Mochi ghé gần nhất (0 = chưa bao giờ); bằng [dayNumber] → hôm nay Mochi không ghé nữa.
  int get lastMochiDay => _lastMochiDay;

  // ------------------------------------------------------------------ Tiến trình level (V2)

  /// Gắn dữ liệu levels.json (main.dart gọi một lần sau khi nạp; `AppServices` cũng tự gắn). Cấu hình rỗng vẫn chạy:
  /// không level nào mở, món/topping/cấp tiệm tính như V1 theo kỷ lục đã có.
  void attachLevelConfig(LevelConfig cfg) {
    if (identical(cfg, _levelConfig)) return;
    _levelConfig = cfg;
    _recomputeOffline();
    notifyListeners();
  }

  LevelConfig get levelConfig => _levelConfig;

  /// null nếu chưa chơi xong lượt nào của level [id].
  LevelRecord? levelRecord(int id) => _levels[id];

  /// Kỷ lục được tính: id có trong config (cấu hình rỗng → mọi id).
  bool _counts(int id) => _levelConfig.isEmpty || _levelConfig.hasLevel(id);

  bool _completed(int id) => _levels[id]?.completed ?? false;

  /// Tổng sao mọi level (0..3 mỗi level).
  int get totalStars {
    var sum = 0;
    _levels.forEach((id, r) {
      if (_counts(id)) sum += r.stars;
    });
    return sum;
  }

  int starsInChapter(int chapter) {
    var sum = 0;
    for (final l in _levelConfig.levelsInChapter(chapter)) {
      sum += _levels[l.id]?.stars ?? 0;
    }
    return sum;
  }

  /// Id lớn nhất đã qua (≥ 1★); 0 nếu chưa qua level nào.
  int get highestCompletedLevel {
    var best = 0;
    _levels.forEach((id, r) {
      if (r.completed && id > best && _counts(id)) best = id;
    });
    return best;
  }

  /// Chương đầu luôn mở; chương N mở khi đã qua level cuối chương trước VÀ [totalStars] ≥ `starsToUnlock`.
  bool isChapterUnlocked(int chapter) {
    final data = _levelConfig.chapter(chapter);
    if (data == null) return false;
    final prev = _levelConfig.previousChapter(chapter);
    if (prev != null) {
      final prevLevels = _levelConfig.levelsInChapter(prev.id);
      if (prevLevels.isNotEmpty && !_completed(prevLevels.last.id)) return false;
    }
    return totalStars >= data.starsToUnlock;
  }

  /// Level đầu luôn mở; level sau mở khi level liền trước (thứ tự levels.json) đã qua VÀ chương của nó đã mở.
  bool isLevelUnlocked(int id) {
    final levels = _levelConfig.levels;
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].id != id) continue;
      if (i == 0) return true;
      return _completed(levels[i - 1].id) && isChapterUnlocked(levels[i].chapter);
    }
    return false;
  }

  /// Level mở thấp nhất chưa qua; qua hết (hoặc level sau đang chờ đủ sao mở chương) → level mở cao nhất.
  /// Cấu hình rỗng → 1.
  int get currentLevelId {
    final levels = _levelConfig.levels;
    if (levels.isEmpty) return 1;
    var last = levels.first.id;
    for (final l in levels) {
      if (!isLevelUnlocked(l.id)) break;
      if (!_completed(l.id)) return l.id;
      last = l.id;
    }
    return last;
  }

  Set<int> _unlockedLevelIds() => {
        for (final l in _levelConfig.levels)
          if (isLevelUnlocked(l.id)) l.id,
      };

  Set<int> _unlockedChapterIds() => {
        for (final c in _levelConfig.chapters)
          if (isChapterUnlocked(c.id)) c.id,
      };

  /// Từ lò vùng vàng + dụng cụ (`value` của cấp hiện tại; vùng "được" của lò = vùng hoàn hảo + 0.10).
  BakeModifiers get bakeModifiers {
    const b = BakeModifiers.base;
    double value(String id, double fallback) {
      final tiers = _tiersOf(id);
      return tiers == null ? fallback : tiers[equipmentTier(id) - 1].value.toDouble();
    }

    final perfect = value(EquipmentIds.goldenOven, b.bakePerfectHalfWidth);
    return BakeModifiers(
      bakePerfectHalfWidth: perfect,
      bakeOkHalfWidth: ((perfect + 0.10) * 1000).round() / 1000,
      mixPerfectBand: value(ToolId.whisk.name, b.mixPerfectBand),
      frostBrushRadius: value(ToolId.pipingBag.name, b.frostBrushRadius),
      toppingSnapRadius: value(ToolId.tongs.name, b.toppingSnapRadius),
    );
  }

  // ------------------------------------------------------------------ Mở khoá, thiết bị (GĐ3)

  /// Cấp thiết bị tối đa đọc từ bản lưu (chặn số rác).
  static const maxEquipmentTier = 20;

  /// Bảng dự phòng khi unlocks.json không có lò/dụng cụ V1 (cấu hình rỗng, test): `Economy.ovenTiers` / `toolTiers`.
  static final Map<String, List<EquipmentTier>> _fallbackTiers = {
    EquipmentIds.goldenOven: [
      for (final t in Economy.ovenTiers)
        EquipmentTier(level: t.requiredShopLevel, price: t.cost, value: t.perfectHalfWidth),
    ],
    for (final MapEntry(:key, :value) in Economy.toolTiers.entries)
      key.name: [for (final t in value) EquipmentTier(level: t.requiredShopLevel, price: t.cost, value: t.value)],
  };

  /// Gắn dữ liệu unlocks.json (main.dart gọi một lần sau khi nạp; `AppServices` cũng tự gắn). Cấu hình rỗng vẫn chạy:
  /// không có mở rộng, lò/dụng cụ V1 nâng theo bảng dự phòng.
  void attachUnlockConfig(UnlockConfig cfg) {
    if (identical(cfg, _unlockConfig)) return;
    _unlockConfig = cfg;
    _recomputeOffline();
    notifyListeners();
  }

  UnlockConfig get unlockConfig => _unlockConfig;

  /// "Sắp có": theo `UnlockData.comingSoon`, và nhân viên không có dữ liệu ở mục `staff` của config.
  bool _isComingSoon(UnlockData u) =>
      u.comingSoon || (u.kind == UnlockKind.staff && _unlockConfig.staffById(u.id) == null);

  /// Mục phải có trước mà chưa có (nhân viên có `requires`, vd. phục vụ cần `cafe_tables`); null nếu không thiếu.
  String? _missingRequirement(String id) {
    final req = _unlockConfig.staffById(id)?.requires;
    return req != null && !_owned.contains(req) ? req : null;
  }

  /// Mục mở khoá (id) phải mua trước mới thuê được nhân viên [id] mà chưa có (vd. `staff_waiter` → `cafe_tables`);
  /// null nếu không cần / đã có. `unlockState` là [UnlockState.locked] khi thiếu — UI ghi "Cần … trước".
  String? staffRequirementMissing(String id) => _owned.contains(id) ? null : _missingRequirement(id);

  /// Mục không có trong config → [UnlockState.locked]. Nhân viên đã qua mốc mà thiếu mục phải có trước
  /// ([staffRequirementMissing]) → [UnlockState.locked].
  UnlockState unlockState(String id) {
    final u = _unlockConfig.unlock(id);
    if (u == null) return UnlockState.locked;
    if (_owned.contains(id)) return UnlockState.owned;
    if (_isComingSoon(u)) return UnlockState.comingSoon;
    return highestCompletedLevel >= u.level && _missingRequirement(id) == null
        ? UnlockState.available
        : UnlockState.locked;
  }

  /// Mua mục mở khoá: trừ `price` xu (+ `gemPrice` kim cương), áp cho mọi lượt chơi sau qua [shopSetup]. Nhân viên
  /// (`kind: staff`) = thuê, bắt đầu cấp 1 / 1.
  PurchaseResult buyUnlock(String id) {
    final u = _unlockConfig.unlock(id);
    if (u == null) return PurchaseResult.locked;
    if (_owned.contains(id)) return PurchaseResult.alreadyOwned;
    if (_isComingSoon(u)) return PurchaseResult.comingSoon;
    if (highestCompletedLevel < u.level || _missingRequirement(id) != null) return PurchaseResult.locked;
    if (_coins < u.price) return PurchaseResult.notEnoughCoins;
    if (_gems < u.gemPrice) return PurchaseResult.notEnoughGems;
    _coins -= u.price;
    _gems -= u.gemPrice;
    _owned.add(id);
    _recomputeOffline();
    notifyListeners();
    return PurchaseResult.ok;
  }

  /// Các cấp của thiết bị [id]: unlocks.json, thiếu thì bảng dự phòng (lò/dụng cụ V1); không có → null.
  List<EquipmentTier>? _tiersOf(String id) {
    final tiers = _unlockConfig.equipmentById(id)?.tiers;
    return tiers != null && tiers.isNotEmpty ? tiers : _fallbackTiers[id];
  }

  /// Cấp hiện tại của thiết bị [id] (1 = có sẵn; kẹp theo số cấp trong config).
  int equipmentTier(String id) {
    final stored = _equipment[id] ?? 1;
    final tiers = _tiersOf(id);
    return tiers == null ? math.max(1, stored) : stored.clamp(1, tiers.length);
  }

  /// Nâng thiết bị [id] lên cấp kế (cả lò vùng vàng `goldenOven` và dụng cụ `whisk` / `pipingBag` / `tongs`).
  PurchaseResult buyEquipment(String id) {
    final tiers = _tiersOf(id);
    if (tiers == null) return PurchaseResult.locked;
    final current = equipmentTier(id);
    if (current >= tiers.length) return PurchaseResult.maxed;
    final next = tiers[current];
    if (highestCompletedLevel < next.level) return PurchaseResult.locked;
    if (_coins < next.price) return PurchaseResult.notEnoughCoins;
    _coins -= next.price;
    _equipment[id] = current + 1;
    notifyListeners();
    return PurchaseResult.ok;
  }

  /// Id mọi thiết bị đang biết (config + thiết bị code biết + bản lưu), thứ tự config trước.
  Iterable<String> _equipmentIds() => {
        for (final e in _unlockConfig.equipment) e.id,
        ...EquipmentIds.known,
        ..._equipment.keys,
      };

  /// Cấu hình tiệm cho lượt chơi kế: hiệu ứng mở rộng đã mua (`UnlockEffects.supported`, bỏ qua loại "Sắp có") +
  /// thông số thiết bị `fastOven` / `bigTray` / `wideCase` theo cấp.
  ShopSetup get shopSetup {
    const b = ShopSetup.base;
    var caseSlots = 0, ovens = 0, queue = 0, spots = 0, tip = 0, spawn = 0;
    var patience = 1.0;
    for (final u in _unlockConfig.unlocks) {
      if (_isComingSoon(u) || !_owned.contains(u.id)) continue;
      u.effect.forEach((k, v) {
        switch (k) {
          case UnlockEffects.caseSlots:
            caseSlots += v.round();
          case UnlockEffects.ovens:
            ovens += v.round();
          case UnlockEffects.maxQueue:
            queue += v.round();
          case UnlockEffects.counterSpots:
            spots += v.round();
          case UnlockEffects.tipPct:
            tip += v.round();
          case UnlockEffects.spawnRatePct:
            spawn += v.round();
          case UnlockEffects.patienceMult:
            patience *= v;
          default:
            break; // UnlockEffects.reserved: chương sau
        }
      });
    }
    num stat(String id, num fallback) {
      final tiers = _tiersOf(id);
      return tiers == null ? fallback : tiers[equipmentTier(id) - 1].value;
    }

    return ShopSetup(
      caseSlotsBonus: caseSlots,
      ovens: b.ovens + ovens,
      batchSize: stat(EquipmentIds.bigTray, b.batchSize).round(),
      slotCapacity: stat(EquipmentIds.wideCase, b.slotCapacity).round(),
      maxQueueBonus: queue,
      counterSpotsBonus: spots,
      tipPct: tip,
      spawnRatePct: spawn,
      ovenSec: stat(EquipmentIds.fastOven, b.ovenSec).toDouble(),
      patienceMult: patience,
      owned: Set.unmodifiable(_owned),
      equipmentTiers: Map.unmodifiable({for (final id in _equipmentIds()) id: equipmentTier(id)}),
      staff: _workingStaff(),
      recipePricePct: Map.unmodifiable({
        for (final r in RecipeId.values)
          if (recipeSecretPricePct(r) > 0) r: recipeSecretPricePct(r),
      }),
    );
  }

  /// Nhân viên đã thuê làm trong màn (bỏ quản lý, bỏ người thiếu mục phải có trước), thứ tự config; [StaffMember.lane]
  /// đếm theo vai trò.
  List<StaffMember> _workingStaff() {
    final lanes = <StaffRole, int>{};
    final out = <StaffMember>[];
    for (final d in _unlockConfig.staff) {
      if (d.role == StaffRole.manager || !isStaffHired(d.id) || _missingRequirement(d.id) != null) continue;
      final lane = lanes[d.role] ?? 0;
      lanes[d.role] = lane + 1;
      out.add(StaffMember.of(d,
          speed: staffLevel(d.id, StaffStat.speed), skill: staffLevel(d.id, StaffStat.skill), lane: lane));
    }
    return List.unmodifiable(out);
  }

  // ------------------------------------------------------------------ Nhân viên (GĐ4)

  /// Đã thuê nhân viên [id] (có trong mục đã mua và có dữ liệu `staff` trong config).
  bool isStaffHired(String id) => _owned.contains(id) && _unlockConfig.staffById(id) != null;

  /// Cấp chỉ số [stat] của nhân viên [id] (1..`maxLevel`); 0 = chưa thuê.
  int staffLevel(String id, StaffStat stat) {
    final d = _unlockConfig.staffById(id);
    if (d == null || !_owned.contains(id)) return 0;
    final l = _staffLevels[id];
    final level = l == null ? 1 : (stat == StaffStat.speed ? l.speed : l.skill);
    return level.clamp(1, d.maxLevel);
  }

  /// Giá nâng [stat] của [id] lên cấp kế; null nếu chưa thuê / đã tối đa / không có nhân viên.
  int? staffUpgradePrice(String id, StaffStat stat) {
    final level = staffLevel(id, stat);
    if (level == 0) return null;
    return _unlockConfig.staffById(id)!.priceTo(stat, level + 1);
  }

  /// Nâng [stat] của nhân viên [id] lên cấp kế: locked (không có / chưa thuê) · maxed · notEnoughCoins · ok.
  PurchaseResult upgradeStaff(String id, StaffStat stat) {
    final d = _unlockConfig.staffById(id);
    final level = staffLevel(id, stat);
    if (d == null || level == 0) return PurchaseResult.locked;
    final price = d.priceTo(stat, level + 1);
    if (price == null) return PurchaseResult.maxed;
    if (_coins < price) return PurchaseResult.notEnoughCoins;
    _coins -= price;
    final speed = staffLevel(id, StaffStat.speed), skill = staffLevel(id, StaffStat.skill);
    _staffLevels[id] = stat == StaffStat.speed ? (speed: speed + 1, skill: skill) : (speed: speed, skill: skill + 1);
    // Quản lý: tỉ lệ / trần giờ đổi → khoản đang chờ tính lại ngay.
    _recomputeOffline();
    notifyListeners();
    return PurchaseResult.ok;
  }

  // ------------------------------------------------------------------ Thu nhập khi vắng nhà (quản lý)

  /// Số lượt chơi gần nhất lấy trung bình xu cho quản lý.
  static const recentIncomeCount = 5;

  /// Thời gian vắng chưa nhận giữ tối đa (chặn số rác / đồng hồ nhảy xa).
  static const maxStoredAway = Duration(days: 30);

  /// Thu nhập khi vắng nhà đang chờ nhận; null nếu không có (chưa thuê quản lý, vắng chưa đủ `minAwayMin` phút, hoặc
  /// đã nhận). Tính khi gọi [refreshOffline] (main.dart: lúc mở app sau khi gắn config, và khi app quay lại từ nền).
  OfflineEarnings? get pendingOffline => _pendingOffline;

  /// Nhịp ghi mốc hoạt động khi app ở foreground ([startActiveHeartbeat]).
  static const activeHeartbeat = Duration(seconds: 60);

  Timer? _heartbeat;

  /// Ghi mốc hoạt động = bây giờ (main.dart gọi khi app inactive / vào nền / pause; [applyLevelResult] cũng tự ghi).
  /// Lưu cùng bản lưu (lên lịch lưu, không báo listener).
  void markActive() {
    _touchActive(_clock().millisecondsSinceEpoch);
    _scheduleSave();
  }

  /// Dời mốc hoạt động tới [ms] nếu [ms] mới hơn; mốc không bao giờ lùi (QA-01). Đồng hồ máy bị lùi thì mốc giữ nguyên,
  /// thời gian vắng = 0 cho tới khi giờ máy vượt lại mốc — chu kỳ "tiến giờ → nhận → lùi giờ → tiến giờ" không nhận lại
  /// được. Không có giờ máy chủ nên một lần tiến giờ vẫn ăn được một lần trần giờ quản lý (chấp nhận).
  void _touchActive(int ms) {
    final last = _lastActive;
    if (last == null || ms > last) _lastActive = ms;
  }

  /// Bật nhịp ghi mốc hoạt động mỗi [activeHeartbeat] khi app ở foreground — app bị tắt đột ngột lúc đang mở thì thời
  /// gian đang chơi không bị tính là vắng (sai số ≤ một nhịp). Mỗi nhịp chỉ dời mốc; lên lịch lưu khi đã thuê quản lý
  /// (chưa thuê thì mốc không dùng tới, tránh ghi đĩa thừa). Gọi SAU [refreshOffline] (không tự ghi mốc lúc bật, để không
  /// xoá thời gian vắng chưa tính). Gọi lặp lại = khởi động lại nhịp.
  void startActiveHeartbeat() {
    _heartbeat?.cancel();
    if (_disposed) return;
    _heartbeat = Timer.periodic(activeHeartbeat, (_) {
      _touchActive(_clock().millisecondsSinceEpoch);
      if (_hiredManager() != null) _scheduleSave();
    });
  }

  /// Tắt nhịp ghi mốc (main.dart gọi khi app vào nền).
  void stopActiveHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// Tính thời gian vắng từ mốc hoạt động tới [now] rồi tính lại [pendingOffline]; dời mốc tới [now]. Lần vắng ngắn
  /// hơn `minAwayMin` phút không tính; đồng hồ lùi ([now] < mốc) → không tính và GIỮ mốc cũ (mốc không lùi, QA-01: lùi
  /// giờ rồi chỉnh lại không được tính là vắng); chưa thuê quản lý → không tính. Gọi lặp lại vô hại. Notify (→ lưu) khi
  /// có thay đổi.
  void refreshOffline(DateTime now) {
    final before = _pendingOffline;
    final t = now.millisecondsSinceEpoch;
    final last = _lastActive;
    _touchActive(t);
    final manager = _hiredManager();
    if (manager != null && last != null && t > last) {
      final minAway = manager.param(StaffParams.minAwayMin, StaffParams.defaultMinAwayMin).toDouble();
      final segment = t - last;
      if (segment >= minAway * Duration.millisecondsPerMinute) {
        _awayMs = math.min(_awayMs + segment, maxStoredAway.inMilliseconds);
      }
    }
    _recomputeOffline();
    if (_pendingOffline != before) {
      notifyListeners();
    } else {
      _scheduleSave();
    }
  }

  /// Nhận [pendingOffline] (x2 khi [doubled] — bên gọi đã cho xem quảng cáo `AdPlacement.offlineDouble`): cộng xu,
  /// xoá thời gian vắng đã tính, lưu. Trả số xu đã cộng (0 nếu không có gì để nhận — gọi lần hai không cộng nữa).
  int claimOffline({bool doubled = false}) {
    final p = _pendingOffline;
    if (p == null) return 0;
    final coins = doubled ? p.coins * 2 : p.coins;
    _coins = walletAdd(_coins, coins);
    _awayMs = 0;
    _pendingOffline = null;
    notifyListeners();
    return coins;
  }

  /// Quản lý đã thuê đầu tiên (theo config), null nếu không có.
  StaffData? _hiredManager() {
    for (final d in _unlockConfig.staff) {
      if (d.role == StaffRole.manager && _owned.contains(d.id)) return d;
    }
    return null;
  }

  /// Xu TB một level ở tiến trình hiện tại: trung bình [recentIncomeCount] lượt gần nhất; chưa có → `fallbackIncome`.
  double _levelIncome(StaffData manager) {
    if (_recentCoins.isEmpty) {
      return manager.param(StaffParams.fallbackIncome, StaffParams.defaultFallbackIncome).toDouble();
    }
    return _recentCoins.reduce((a, b) => a + b) / _recentCoins.length;
  }

  /// `coins = tỉ lệ (tốc độ) × xu TB một level × giờ được tính (≤ trần giờ theo tay nghề)`.
  void _recomputeOffline() {
    final manager = _hiredManager();
    if (manager == null || _awayMs <= 0) {
      _pendingOffline = null;
      return;
    }
    final rate = manager.value(StaffStat.speed, staffLevel(manager.id, StaffStat.speed)).toDouble();
    final capHours = manager.value(StaffStat.skill, staffLevel(manager.id, StaffStat.skill)).round();
    final countedMs = math.min(_awayMs, capHours * Duration.millisecondsPerHour);
    final coins = (rate * _levelIncome(manager) * countedMs / Duration.millisecondsPerHour).round();
    _pendingOffline = coins <= 0
        ? null
        : OfflineEarnings(
            away: Duration(milliseconds: _awayMs),
            counted: Duration(milliseconds: countedMs),
            coins: coins,
            capHours: capHours,
          );
  }

  /// Mục đã tới mốc khi đã qua level [passed] mà chưa sở hữu, theo level tăng dần: mục mở khoá mua được (mở rộng +
  /// nhân viên; bỏ qua "Sắp có" và nhân viên còn thiếu mục phải có trước) + mọi cấp thiết bị chưa có (`eq:<id>:<cấp>`).
  List<String> _reachedKeys(int passed) {
    final out = <(int, String)>[
      for (final u in _unlockConfig.unlocks)
        if (!_isComingSoon(u) && u.level <= passed && !_owned.contains(u.id) && _missingRequirement(u.id) == null)
          (u.level, u.id),
    ];
    for (final id in _equipmentIds()) {
      final tiers = _tiersOf(id);
      if (tiers == null) continue;
      for (var k = equipmentTier(id) + 1; k <= tiers.length; k++) {
        if (tiers[k - 1].level <= passed) out.add((tiers[k - 1].level, UnlockKeys.equipment(id, k)));
      }
    }
    return _sortedByLevel(out);
  }

  /// (level, khoá) → khoá, theo level tăng dần (cùng level giữ thứ tự).
  static List<String> _sortedByLevel(List<(int, String)> entries) {
    final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])]
      ..sort((a, b) => a.$2.$1 != b.$2.$1 ? a.$2.$1.compareTo(b.$2.$1) : a.$1.compareTo(b.$1));
    return [for (final e in indexed) e.$2.$2];
  }

  /// Mục mua được ngay (mở rộng / nhân viên [UnlockState.available] + cấp kế của thiết bị đã tới mốc) mà chưa xem, theo level
  /// tăng dần (khoá `UnlockKeys`). Không rỗng → chấm đỏ trên nút Nâng cấp.
  List<String> get unseenUnlocks {
    final passed = highestCompletedLevel;
    final out = <(int, String)>[
      for (final u in _unlockConfig.unlocks)
        if (!_seen.contains(u.id) && unlockState(u.id) == UnlockState.available) (u.level, u.id),
    ];
    for (final id in _equipmentIds()) {
      final tiers = _tiersOf(id);
      if (tiers == null) continue;
      final next = equipmentTier(id) + 1;
      if (next > tiers.length || tiers[next - 1].level > passed) continue;
      final key = UnlockKeys.equipment(id, next);
      if (!_seen.contains(key)) out.add((tiers[next - 1].level, key));
    }
    return _sortedByLevel(out);
  }

  /// Đánh dấu đã xem (khoá `UnlockKeys`: id mục mở khoá hoặc `eq:<id>:<cấp>`).
  void markUnlocksSeen(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      if (id.isNotEmpty && _seen.add(id)) changed = true;
    }
    if (changed) notifyListeners();
  }

  // ------------------------------------------------------------------ Ghi

  void addCoins(int amount) {
    _coins = walletAdd(_coins, amount);
    notifyListeners();
  }

  void addGems(int amount) {
    _gems = walletAdd(_gems, amount);
    notifyListeners();
  }

  bool trySpendCoins(int amount) {
    if (amount < 0 || _coins < amount) return false;
    _coins -= amount;
    notifyListeners();
    return true;
  }

  bool trySpendGems(int amount) {
    if (amount < 0 || _gems < amount) return false;
    _gems -= amount;
    notifyListeners();
    return true;
  }

  /// Mua (không tự đặt). Gọi `equipDecor` để đặt. Khoá tới khi qua level `unlockLevel` của món.
  PurchaseResult buyDecor(DecorId id) {
    if (_decorOwned.contains(id)) return PurchaseResult.alreadyOwned;
    final item = Catalog.decorItem(id);
    if (highestCompletedLevel < item.unlockLevel) return PurchaseResult.locked;
    if (item.paidWithGems) {
      if (_gems < item.gemPrice) return PurchaseResult.notEnoughGems;
      _gems -= item.gemPrice;
    } else {
      if (_coins < item.coinPrice) return PurchaseResult.notEnoughCoins;
      _coins -= item.coinPrice;
    }
    _decorOwned.add(id);
    notifyListeners();
    return PurchaseResult.ok;
  }

  /// null = mặc định "Cơ bản". Bỏ qua nếu chưa sở hữu hoặc sai ô.
  void equipDecor(DecorSlot slot, DecorId? id) {
    if (id != null && (!_decorOwned.contains(id) || Catalog.decorItem(id).slot != slot)) return;
    if (_decorEquipped[slot] == id) return;
    _decorEquipped[slot] = id;
    notifyListeners();
  }

  /// Cộng xu (net), thành thạo, nhiệm vụ, thống kê của một đơn đã phục vụ (không cộng XP).
  void applyOrderResult(Order order, Customer customer, BakeResult result) {
    _rollDaily();
    _coins = walletAdd(_coins, result.net);
    _served++;

    _raiseMastery(order.recipe, result.stars);

    _quests = List.unmodifiable([
      for (final q in _quests)
        q.claimed
            ? q
            : q.copyWith(
                progress: math.min(
                  Catalog.quest(q.type).target,
                  q.progress + _questGain(q.type, result),
                ),
              ),
    ]);
    notifyListeners();
  }

  /// Cộng kết quả một lượt chơi level (thắng hay thua đều nhận xu đã kiếm): xu, khách đã phục vụ, thành thạo
  /// công thức theo `recipeStars`, nhiệm vụ ngày, kỷ lục level (sao = max, best = max goalValue, plays++,
  /// firstWin = thắng ở lượt đầu). Không cộng XP. Notify một lần. Trả thay đổi tiến trình cho hoạt cảnh bản đồ
  /// (gồm `newUnlocks`: mục mở khoá / cấp thiết bị vừa tới mốc).
  LevelProgressDelta applyLevelResult(LevelResult r) {
    final levelsBefore = _unlockedLevelIds();
    final chaptersBefore = _unlockedChapterIds();
    final reachedBefore = _reachedKeys(highestCompletedLevel).toSet();
    final gemsBefore = _gems;
    _rollDaily();
    _refreshSeason();
    _coins = walletAdd(_coins, r.coins);
    _served += math.max(0, r.served);
    _recentCoins.add(math.max(0, r.coins));
    while (_recentCoins.length > recentIncomeCount) {
      _recentCoins.removeAt(0);
    }
    _touchActive(_clock().millisecondsSinceEpoch);
    // Xu TB một level đổi → khoản đang chờ (chưa nhận) tính lại theo thu nhập mới.
    _recomputeOffline();
    r.recipeStars.forEach(_raiseMastery);
    _quests = List.unmodifiable([
      for (final q in _quests)
        q.claimed
            ? q
            : q.copyWith(
                progress: math.min(Catalog.quest(q.type).target, q.progress + math.max(0, _levelQuestGain(q.type, r))),
              ),
    ]);

    final old = _levels[r.levelId] ?? const LevelRecord();
    final stars = r.won ? r.stars.clamp(1, 3) : 0;
    final goal = math.max(0, r.goalValue);
    final record = LevelRecord(
      stars: math.max(old.stars, stars),
      best: math.max(old.best, goal),
      plays: old.plays + 1,
      firstWin: old.firstWin || (old.plays == 0 && r.won),
    );
    _levels[r.levelId] = record;

    // Kim cương kiếm trong game (GĐ6): lần đầu 3★ một level, lần đầu qua level cuối một chương.
    if (old.stars < 3 && record.stars >= 3) _gems = walletAdd(_gems, Economy.levelThreeStarGems);
    if (!old.completed && record.completed && _isLastOfChapter(r.levelId)) {
      _gems = walletAdd(_gems, Economy.chapterCompleteGems);
    }

    // Thẻ mùa: mỗi sao mới của level + mỗi lượt thắng (chỉ khi mùa đang diễn ra).
    var seasonGain = 0;
    final season = activeSeason;
    if (season != null) {
      seasonGain = (record.stars - old.stars) * season.pointsPerNewStar + (r.won ? season.pointsPerWin : 0);
      _seasonPoints += seasonGain;
    }
    final gift = _grantBoosterGift();

    int? firstNew(Set<int> after, Set<int> before) {
      int? found;
      for (final id in after) {
        if (!before.contains(id) && (found == null || id < found)) found = id;
      }
      return found;
    }

    final delta = LevelProgressDelta(
      levelId: r.levelId,
      oldStars: old.stars,
      newStars: record.stars,
      newBest: old.plays > 0 && goal > old.best,
      unlockedLevel: firstNew(_unlockedLevelIds(), levelsBefore),
      unlockedChapter: firstNew(_unlockedChapterIds(), chaptersBefore),
      newUnlocks: List.unmodifiable([
        for (final k in _reachedKeys(highestCompletedLevel))
          if (!reachedBefore.contains(k)) k,
      ]),
      seasonPoints: seasonGain,
      gems: _gems - gemsBefore,
      boosterGift: gift,
    );
    notifyListeners();
    return delta;
  }

  /// [id] là level cuối (theo levels.json) của chương của nó. Cấu hình rỗng → false.
  bool _isLastOfChapter(int id) {
    if (!_levelConfig.hasLevel(id)) return false;
    final level = _levelConfig.level(id);
    final inChapter = _levelConfig.levelsInChapter(level.chapter);
    return inChapter.isNotEmpty && inChapter.last.id == id;
  }

  /// Thắng hay thua, sau [applyLevelResult]: ×2 xu của lượt [r] (bên gọi đã cho xem quảng cáo
  /// `AdPlacement.doubleCoins`). Một lần mỗi kết quả, chỉ khi xu > 0. Trả số xu đã cộng (0 = không cộng).
  int doubleResultCoins(LevelResult r) {
    if (r.coins <= 0 || _doubledResults[r] == true) return 0;
    _doubledResults[r] = true;
    _coins = walletAdd(_coins, r.coins);
    notifyListeners();
    return r.coins;
  }

  /// Đã nhân đôi xu của kết quả [r] chưa ([doubleResultCoins]).
  bool isResultDoubled(LevelResult r) => _doubledResults[r] == true;

  static int _levelQuestGain(QuestType type, LevelResult r) => switch (type) {
        QuestType.serveCustomers => r.served,
        QuestType.earnStars => r.treatStars,
        QuestType.perfectBakes => r.perfectBakes,
        QuestType.fiveStarTreats => r.fiveStarTreats,
        QuestType.earnCoins => r.coins,
        QuestType.earnTips => r.tips,
      };

  /// Thành thạo theo sao bánh (như V1): đã làm → 1, ≥4★ → 2, 5★ → 3 (+ đá quý lần đầu đạt 3).
  void _raiseMastery(RecipeId recipe, int stars) {
    if (stars <= 0) return;
    final old = recipeMastery(recipe);
    var mastery = math.max(old, 1);
    if (stars >= 4) mastery = math.max(mastery, 2);
    if (stars >= 5) mastery = 3;
    if (mastery == 3 && old < 3) _gems = walletAdd(_gems, Economy.masteryGemReward);
    _mastery[recipe] = mastery;
  }

  static int _questGain(QuestType type, BakeResult r) => switch (type) {
        QuestType.serveCustomers => 1,
        QuestType.earnStars => r.stars,
        QuestType.perfectBakes => r.isPerfectBake ? 1 : 0,
        QuestType.fiveStarTreats => r.stars == 5 ? 1 : 0,
        QuestType.earnCoins => math.max(0, r.net),
        QuestType.earnTips => r.tip,
      };

  /// dayNumber++.
  void completeDay() {
    _day++;
    notifyListeners();
  }

  /// null nếu chưa xong/đã nhận/sai chỉ số.
  QuestProgress? claimQuest(int index) {
    if (index < 0 || index >= _quests.length) return null;
    final q = _quests[index];
    final def = Catalog.quest(q.type);
    if (q.claimed || q.progress < def.target) return null;
    final claimed = q.copyWith(claimed: true);
    _quests = List.unmodifiable([
      for (var i = 0; i < _quests.length; i++) i == index ? claimed : _quests[i],
    ]);
    _coins = walletAdd(_coins, def.rewardCoins);
    _gems = walletAdd(_gems, def.rewardGems);
    notifyListeners();
    return claimed;
  }

  LoginReward? claimLogin() {
    final reward = pendingLoginReward;
    if (reward == null) return null;
    _loginStreak = reward.day;
    _loginDate = _todayKey();
    _coins = walletAdd(_coins, reward.coins);
    _gems = walletAdd(_gems, reward.gems);
    notifyListeners();
    return reward;
  }

  /// Vuốt ve Mochi: ghi lượt ghé của ngày [day] (mặc định ngày đang chơi) + quà
  /// ([Economy.mochiPetCoins] xu; lần vuốt ve đầu tiên trong đời thêm [Economy.mochiFirstPetGems] đá quý).
  /// Trả quà đã cộng; null nếu ngày đó Mochi đã ghé (không cho quà lần hai).
  MochiGift? petMochi({int? day}) {
    if (!_recordMochiVisit(day ?? _day)) return null;
    final gift = MochiGift(
      coins: Economy.mochiPetCoins,
      gems: _mochiPets == 0 ? Economy.mochiFirstPetGems : 0,
    );
    _mochiPets++;
    _coins = walletAdd(_coins, gift.coins);
    _gems = walletAdd(_gems, gift.gems);
    notifyListeners();
    return gift;
  }

  /// Để Mochi nghỉ: chỉ ghi lượt ghé, không quà. Trả false nếu ngày đó Mochi đã ghé.
  bool restMochi({int? day}) {
    if (!_recordMochiVisit(day ?? _day)) return false;
    notifyListeners();
    return true;
  }

  bool _recordMochiVisit(int day) {
    if (_lastMochiDay == day) return false;
    _lastMochiDay = day;
    _mochiVisits++;
    return true;
  }

  /// `ch1End` / `ch2End` / `finale` → [chapter1Complete] = true.
  void markSceneSeen(StorySceneId id) {
    if (_scenes.add(id)) notifyListeners();
  }

  void markTutorialSeen(StationId id) {
    if (_tutorial.add(id)) notifyListeners();
  }

  /// Xem xong hoặc bỏ qua cảnh mở đầu (lưu qua autosave, bất đồng bộ).
  void markIntroSeen() {
    if (_introSeen) return;
    _introSeen = true;
    notifyListeners();
  }

  /// "Xem lại cảnh mở đầu": lần mở app sau chiếu lại. Hiện chưa có UI gọi (Cài đặt mở thẳng `AppRoutes.intro`, không
  /// cần reset); giữ cho nút Cài đặt / công cụ debug sau này — có test.
  void resetIntro() {
    if (!_introSeen) return;
    _introSeen = false;
    notifyListeners();
  }

  /// Gọi khi session phát `SessionEventType.tutorialDone` (id = `session.tutorial!.id`).
  void markTutorialDone(String id) {
    if (id.isEmpty) return;
    if (_tutorialsDone.add(id)) notifyListeners();
  }

  /// Cài đặt "Hướng dẫn lại L1–3": lượt chơi L1–3 kế tiếp hiện lại hướng dẫn.
  void resetTutorials() {
    if (_tutorialsDone.isEmpty) return;
    _tutorialsDone.clear();
    notifyListeners();
  }

  void setLanguage(LanguagePref pref) {
    if (_lang == pref) return;
    _lang = pref;
    notifyListeners();
  }

  void setSound(bool on) {
    if (_sound == on) return;
    _sound = on;
    notifyListeners();
  }

  void registerRewardedShown() {
    _rollDaily();
    _rewardedToday++;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Interstitial (GĐ6 §3)

  /// Lượt chơi xong (thắng / thua) kể từ interstitial gần nhất — chỉ đếm khi đã qua [Economy.interstitialAfterLevel].
  int get playsSinceInterstitial => _playsSinceInterstitial;

  /// Gọi một lần mỗi lượt chơi kết thúc (thắng hay thua; thoát giữa chừng không tính), SAU [applyLevelResult]. Chưa qua
  /// level [Economy.interstitialAfterLevel] → không đếm.
  void registerLevelPlayEnded() {
    if (highestCompletedLevel < Economy.interstitialAfterLevel) return;
    _playsSinceInterstitial++;
    notifyListeners();
  }

  /// Có hiện interstitial khi rời màn kết quả không: đã qua L5, đủ [Economy.interstitialEveryPlays] lượt kể từ lần
  /// trước, chưa mua Bỏ quảng cáo, KHÔNG vừa xem rewarded ở chính màn kết quả đó ([watchedRewardedHere]) và lượt vừa rồi
  /// KHÔNG mở chương mới ([unlockedChapter], = `LevelProgressDelta.unlockedChapter != null`). Không hiện thì lượt vẫn
  /// được giữ tới lần rời kết quả sau.
  bool shouldShowInterstitialAfterResult({required bool watchedRewardedHere, required bool unlockedChapter}) {
    if (_removeAds || _iap.contains(IapProductId.removeAds)) return false;
    if (watchedRewardedHere || unlockedChapter) return false;
    if (highestCompletedLevel < Economy.interstitialAfterLevel) return false;
    return _playsSinceInterstitial >= Economy.interstitialEveryPlays;
  }

  /// Interstitial đã hiện → đếm lại từ 0.
  void registerInterstitialShown() {
    _playsSinceInterstitial = 0;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Vật phẩm hỗ trợ (GĐ6 §1)

  /// Trần số vật phẩm mỗi loại trong kho (chặn số rác trong bản lưu).
  static const maxBoosterStock = 999;

  /// Gắn dữ liệu monetization.json (main.dart gọi một lần sau khi nạp; `AppServices` cũng tự gắn). Cấu hình rỗng vẫn
  /// chạy: giá vật phẩm theo bản dự phòng, không có thẻ mùa (phần mùa trong bản lưu giữ nguyên).
  void attachMonetizationConfig(MonetizationConfig cfg) {
    if (identical(cfg, _monetization)) return;
    _monetization = cfg;
    _refreshSeason();
    notifyListeners();
  }

  MonetizationConfig get monetizationConfig => _monetization;

  /// Dữ liệu các vật phẩm (thứ tự hiện ở thẻ Sẵn sàng).
  List<BoosterData> get boosterCatalog => _monetization.boosters;
  BoosterData boosterData(BoosterId id) => _monetization.booster(id);

  /// Số [id] trong kho.
  int boosterCount(BoosterId id) => _boosters[id] ?? 0;

  /// Kho vật phẩm (chỉ đọc, đủ mọi loại).
  Map<BoosterId, int> get boosterInventory => Map.unmodifiable({for (final b in BoosterId.values) b: boosterCount(b)});

  /// Vật phẩm dùng được ở level [levelId] (từ [BoosterEffects.minLevel]; L1–L3 đang hướng dẫn).
  static bool boostersAvailableFor(int levelId) => levelId >= BoosterEffects.minLevel;

  /// Đã nhận quà giới thiệu (`BoosterEffects.introGift` ×1 khi tới L4).
  bool get boosterGiftReceived => _boosterGift;

  /// Thẻ Sẵn sàng đã giới thiệu vật phẩm lần đầu chưa ([markBoosterIntroSeen]).
  bool get boosterIntroSeen => _boosterIntroSeen;

  void markBoosterIntroSeen() {
    if (_boosterIntroSeen) return;
    _boosterIntroSeen = true;
    notifyListeners();
  }

  /// Tới L4 (đã qua level liền trước) lần đầu → quà giới thiệu vào kho (một lần). Trả true nếu vừa trao (không notify).
  bool _grantBoosterGift() {
    if (_boosterGift || highestCompletedLevel < BoosterEffects.minLevel - 1) return false;
    _boosterGift = true;
    _addBooster(BoosterEffects.introGift, 1);
    return true;
  }

  void _addBooster(BoosterId id, int n) {
    if (n <= 0) return;
    _boosters[id] = math.min(maxBoosterStock, boosterCount(id) + n);
  }

  /// Hoàn vật phẩm của một lượt bị bỏ trước lần bán đầu tiên (UI: Thoát / Chơi lại ở menu tạm dừng khi
  /// `!session.hasSold`): MỖI vật phẩm của [ids] +1 vào KHO, dù lúc Bắt đầu trả bằng kho, kim cương hay quảng cáo (không
  /// trả lại kim cương). Lưu ngay (bất đồng bộ).
  void refundBoosters(Set<BoosterId> ids) {
    if (ids.isEmpty) return;
    for (final id in ids) {
      _addBooster(id, 1);
    }
    notifyListeners();
    unawaited(flush());
  }

  /// Thêm [n] vật phẩm [id] vào kho (quà, công cụ thử).
  void addBoosters(BoosterId id, int n) {
    if (n <= 0) return;
    _addBooster(id, n);
    notifyListeners();
  }

  /// Một vật phẩm đơn lẻ sẽ trả bằng gì: kho trước, hết kho → kim cương; null nếu không đủ cả hai. Chọn nhiều vật phẩm
  /// cùng lúc thì dùng [boosterPlan] (tổng kim cương có thể không đủ dù từng món đủ).
  BoosterPayment? boosterPaymentFor(BoosterId id) {
    if (boosterCount(id) > 0) return BoosterPayment.inventory;
    if (_gems >= boosterData(id).gemPrice) return BoosterPayment.gems;
    return null;
  }

  /// Cách trả cho cả lượt: mỗi vật phẩm của [ids] (+ [adFree], miễn phí nhờ quảng cáo — một vật phẩm mỗi lượt) →
  /// [BoosterPayment.ad] / kho / kim cương. null nếu tổng kim cương không đủ. Rỗng → `{}`.
  Map<BoosterId, BoosterPayment>? boosterPlan(Set<BoosterId> ids, {BoosterId? adFree}) {
    final plan = <BoosterId, BoosterPayment>{};
    var gems = 0;
    for (final id in BoosterId.values) {
      if (id == adFree) {
        plan[id] = BoosterPayment.ad;
      } else if (ids.contains(id)) {
        if (boosterCount(id) > 0) {
          plan[id] = BoosterPayment.inventory;
        } else {
          plan[id] = BoosterPayment.gems;
          gems += boosterData(id).gemPrice;
        }
      }
    }
    return gems > _gems ? null : plan;
  }

  /// Tổng kim cương [boosterPlan] sẽ trừ (kể cả khi không đủ).
  int boosterGemCost(Set<BoosterId> ids, {BoosterId? adFree}) {
    var gems = 0;
    for (final id in ids) {
      if (id != adFree && boosterCount(id) == 0) gems += boosterData(id).gemPrice;
    }
    return gems;
  }

  /// Gọi đúng một lần khi bấm **Bắt đầu** (thoát ở thẻ Sẵn sàng thì không gọi — không mất gì): trừ kho / kim cương theo
  /// [boosterPlan]; [adFree] miễn phí (bên gọi đã cho xem `AdPlacement.booster`). Thiếu kim cương → false, không trừ gì.
  /// Thua không hoàn lại. Truyền cùng tập vật phẩm (gồm [adFree]) vào `LevelSession(boosters: …)`.
  bool consumeBoosters(Set<BoosterId> ids, {BoosterId? adFree}) {
    final plan = boosterPlan(ids, adFree: adFree);
    if (plan == null) return false;
    if (plan.isEmpty) return true;
    plan.forEach((id, pay) {
      switch (pay) {
        case BoosterPayment.inventory:
          _boosters[id] = boosterCount(id) - 1;
        case BoosterPayment.gems:
          _gems -= boosterData(id).gemPrice;
        case BoosterPayment.ad:
          break;
      }
    });
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ Thẻ mùa (GĐ6 §5)

  /// Mùa đang diễn ra mà người chơi đang tham gia (đã gắn id); null = không có.
  SeasonData? get activeSeason {
    final s = _monetization.season;
    return s != null && s.id == _seasonId && s.isActive(_clock()) ? s : null;
  }

  /// Thời gian còn lại của mùa (null nếu không có mùa).
  Duration? get seasonTimeLeft => activeSeason?.timeLeft(_clock());

  int get seasonPoints => activeSeason == null ? 0 : _seasonPoints;

  /// Số bậc đã đạt (0..số bậc); bậc t (1-based) đạt khi t ≤ [seasonTier].
  int get seasonTier => activeSeason?.tierFor(_seasonPoints) ?? 0;

  /// Đã mua thẻ cao cấp của mùa hiện tại.
  bool get seasonPremium => activeSeason != null && _seasonPremium;

  bool seasonClaimed(int tier, {required bool premium}) =>
      activeSeason != null && (premium ? _seasonClaimedPremium : _seasonClaimedFree).contains(tier);

  /// Hàng [premium] của bậc [tier] (1-based) nhận được ngay: đã đạt, chưa nhận, thưởng không rỗng, (cao cấp) đã mua.
  bool seasonCanClaim(int tier, {required bool premium}) {
    final s = activeSeason;
    final t = s?.tier(tier);
    if (s == null || t == null || tier > s.tierFor(_seasonPoints)) return false;
    if (premium && !_seasonPremium) return false;
    if ((premium ? t.premium : t.free).isEmpty) return false;
    return !(premium ? _seasonClaimedPremium : _seasonClaimedFree).contains(tier);
  }

  /// Bậc (1-based, tăng dần) có ít nhất một hàng nhận được ngay ([seasonCanClaim] free hoặc premium). Không rỗng → chấm
  /// đỏ trên nút Thẻ mùa.
  List<int> get seasonClaimable {
    final s = activeSeason;
    if (s == null) return const [];
    return [
      for (var t = 1; t <= s.tiers.length; t++)
        if (seasonCanClaim(t, premium: false) || seasonCanClaim(t, premium: true)) t,
    ];
  }

  /// Nhận hàng [premium] của bậc [tier] (1-based). false nếu không nhận được ([seasonCanClaim]).
  bool claimSeason(int tier, {required bool premium}) {
    final changed = _refreshSeason();
    if (!seasonCanClaim(tier, premium: premium)) {
      if (changed) notifyListeners();
      return false;
    }
    final t = activeSeason!.tier(tier)!;
    _applyReward(premium ? t.premium : t.free);
    (premium ? _seasonClaimedPremium : _seasonClaimedFree).add(tier);
    notifyListeners();
    return true;
  }

  /// Nhận mọi hàng đang nhận được (cả cao cấp nếu đã mua). Trả số hàng đã nhận.
  int claimAllSeason() {
    final changed = _refreshSeason();
    final s = activeSeason;
    var n = 0;
    if (s != null) {
      for (var t = 1; t <= s.tiers.length; t++) {
        for (final premium in const [false, true]) {
          if (!seasonCanClaim(t, premium: premium)) continue;
          final tier = s.tier(t)!;
          _applyReward(premium ? tier.premium : tier.free);
          (premium ? _seasonClaimedPremium : _seasonClaimedFree).add(t);
          n++;
        }
      }
    }
    if (n > 0 || changed) notifyListeners();
    return n;
  }

  /// Thưởng đã tự nhận khi mùa trước kết thúc mà UI chưa thông báo; null nếu không có.
  SeasonAutoClaim? get seasonAutoClaim => _seasonAutoClaim;

  /// UI đã thông báo [seasonAutoClaim].
  void ackSeasonAutoClaim() {
    if (_seasonAutoClaim == null) return;
    _seasonAutoClaim = null;
    notifyListeners();
  }

  /// Kiểm tra mùa ngay (UI gọi khi mở màn Thẻ mùa / bản đồ; [refreshDaily] cũng gọi). Notify khi có thay đổi.
  void refreshSeason() {
    if (_refreshSeason()) notifyListeners();
  }

  /// Hết mùa / đổi id mùa → tự nhận thưởng còn chờ của mùa cũ rồi đặt lại điểm, bậc đã nhận, cao cấp; mùa mới đang
  /// diễn ra → tham gia. Chỉ đặt lại khi chắc chắn: mùa cũ đã hết (cùng id, quá `end`), có dữ liệu mùa cũ ở
  /// `previousSeasons` (tự nhận), hoặc file có mùa MỚI hợp lệ khác id và phần mùa của file không hỏng. Config rỗng / mùa
  /// trong file hỏng (`seasonInvalid`) / không có mùa nào → giữ nguyên dữ liệu mùa của bản lưu. Trả true nếu có thay đổi
  /// (không notify).
  bool _refreshSeason() {
    if (_monetization.isEmpty) return false;
    final now = _clock();
    final current = _monetization.season;
    var changed = false;
    final id = _seasonId;
    if (id != null && (current == null || current.id != id || !now.isBefore(current.end))) {
      final old = _monetization.seasonById(id);
      if (old != null) {
        _autoClaimSeason(old);
        _clearSeason();
        changed = true;
      } else if (current != null && !_monetization.seasonInvalid) {
        debugPrint('GameState: mùa "$id" không còn trong monetization.json, đặt lại phần mùa (không tự nhận thưởng)');
        _clearSeason();
        changed = true;
      } else {
        // Mùa trong file hỏng hoặc không có mùa nào: không biết mùa cũ đã hết chưa → giữ nguyên (không mất điểm,
        // bậc đã nhận, thẻ cao cấp).
        return false;
      }
    }
    if (_seasonId == null && current != null && current.isActive(now)) {
      _seasonId = current.id;
      changed = true;
    }
    return changed;
  }

  void _autoClaimSeason(SeasonData s) {
    var coins = 0, gems = 0;
    final boosters = <BoosterId, int>{};
    final frames = <String>[];
    final reached = s.tierFor(_seasonPoints);
    for (var t = 1; t <= reached; t++) {
      final tier = s.tier(t)!;
      for (final (premium, reward) in [(false, tier.free), (true, tier.premium)]) {
        if (reward.isEmpty) continue;
        if (premium && !_seasonPremium) continue;
        if ((premium ? _seasonClaimedPremium : _seasonClaimedFree).contains(t)) continue;
        _applyReward(reward);
        coins += reward.coins;
        gems += reward.gems;
        reward.boosters.forEach((b, n) => boosters[b] = (boosters[b] ?? 0) + n);
        if (reward.frame != null) frames.add(reward.frame!);
      }
    }
    final claim = SeasonAutoClaim(
      seasonId: s.id,
      coins: coins,
      gems: gems,
      boosters: Map.unmodifiable(boosters),
      frames: List.unmodifiable(frames),
    );
    if (!claim.isEmpty) _seasonAutoClaim = claim;
  }

  /// Cộng một phần thưởng (không notify).
  void _applyReward(Reward r) {
    _coins = walletAdd(_coins, math.max(0, r.coins));
    _gems = walletAdd(_gems, math.max(0, r.gems));
    r.boosters.forEach(_addBooster);
    if (r.frame != null) _frames.add(r.frame!);
  }

  /// Khung chân dung trang trí đã có (thẻ mùa).
  Set<String> get ownedFrames => Set.unmodifiable(_frames);

  // ------------------------------------------------------------------ IAP (giả lập, GĐ6 §4)

  /// Gói khởi đầu hiện nổi bật ở cửa hàng: từ L4 (đã qua L3) tới khi mua.
  bool get starterPackFeatured =>
      highestCompletedLevel >= BoosterEffects.minLevel - 1 && !_iap.contains(IapProductId.starterPack);

  /// Đã mua Trang phục lễ hội.
  bool get outfitsOwned => _iap.contains(IapProductId.staffOutfits);

  /// Nhân viên dùng ảnh trang phục lễ hội (`staff_<id>_fest_<nét mặt>`): đã mua và đang bật.
  bool get outfitsEnabled => outfitsOwned && _outfitsEnabled;

  /// Bật/tắt trang phục (tab Nhân viên); chưa mua → bỏ qua.
  void setOutfitsEnabled(bool on) {
    if (!outfitsOwned || _outfitsEnabled == on) return;
    _outfitsEnabled = on;
    notifyListeners();
  }

  /// Gói [id] mua được lúc này: thẻ mùa cần mùa đang diễn ra và chưa mua; gói một lần chưa sở hữu; gói tiêu hao luôn.
  bool canBuyIap(IapProductId id) => switch (_monetization.product(id).kind) {
        IapKind.consumable => true,
        IapKind.oneTime => !_iap.contains(id),
        IapKind.season => activeSeason != null && !_seasonPremium,
      };

  /// Trao gói IAP (giả lập): nội dung theo `monetization.json` (thiếu → `IapCatalog`) + quyền đặc biệt (bỏ quảng cáo,
  /// trang phục — bật luôn, thẻ mùa cao cấp, bộ trang trí V1). Gói một lần đã sở hữu / thẻ mùa đã mua hoặc không có mùa
  /// → false, không trao lại.
  bool grantIap(IapProductId id) {
    _refreshSeason();
    if (!canBuyIap(id)) {
      notifyListeners();
      return false;
    }
    final p = _monetization.product(id);
    switch (p.kind) {
      case IapKind.oneTime:
        _iap.add(id);
      case IapKind.season:
        _seasonPremium = true;
      case IapKind.consumable:
        break;
    }
    _applyReward(p.reward);
    _applyEntitlement(id);
    if (id == IapProductId.staffOutfits) _outfitsEnabled = true;
    notifyListeners();
    return true;
  }

  /// Quyền của gói một lần (không cộng xu/kim cương). Trả true nếu có thay đổi.
  bool _applyEntitlement(IapProductId id) {
    switch (id) {
      case IapProductId.removeAds:
        if (_removeAds) return false;
        _removeAds = true;
        return true;
      case IapProductId.decorSetSeaside:
        final before = _decorOwned.length;
        _decorOwned.addAll(Catalog.decorSetSeaside);
        return _decorOwned.length != before;
      default:
        return false;
    }
  }

  /// Khôi phục giao dịch (giả lập: đọc lại [ownedIap]): áp lại quyền của mọi gói một lần đã mua (bỏ quảng cáo, bộ trang
  /// trí V1…), không trao lại xu / kim cương / vật phẩm. Trả số gói một lần đã sở hữu.
  int restoreIap() {
    var changed = false;
    var n = 0;
    for (final id in IapProductId.values) {
      if (!_iap.contains(id) || _monetization.product(id).kind != IapKind.oneTime) continue;
      n++;
      if (_applyEntitlement(id)) changed = true;
    }
    if (changed) notifyListeners();
    return n;
  }

  /// Xoá lưu + về ván mới (giữ nguyên autosave đã gắn).
  /// Người chơi chủ động xoá → mở khoá ghi (kể cả khi bản lưu đến từ phiên bản mới hơn).
  Future<void> resetAll() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _savesLocked = false;
    try {
      await _repo?.clear();
    } catch (e) {
      debugPrint('GameState.resetAll: xoá lưu thất bại ($e)');
    }
    _resetToNew();
    notifyListeners();
  }
}
