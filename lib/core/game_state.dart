import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'economy.dart';
import 'models/bake.dart';
import 'models/customer.dart';
import 'models/ids.dart';
import 'models/mochi.dart';
import 'models/order.dart';
import 'models/quest.dart';
import 'save_repository.dart';

/// Trạng thái ván chơi (một nguồn duy nhất). Mỗi hàm ghi gọi `notifyListeners`; khi đã
/// `attachAutosave`, mỗi lần notify sẽ lưu (debounce 300ms, bất đồng bộ).
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

  static const saveVersion = 1;
  static const autosaveDelay = Duration(milliseconds: 300);

  final DateTime Function() _clock;

  int _coins = Economy.startCoins;
  int _gems = Economy.startGems;
  int _xp = 0;
  int _day = 1;
  int _oven = 1;
  final Map<ToolId, int> _tools = {};
  final Set<DecorId> _decorOwned = {};
  final Map<DecorSlot, DecorId?> _decorEquipped = {};
  final Map<RecipeId, int> _mastery = {};
  String _questDate = '';
  List<QuestProgress> _quests = const [];
  int _loginStreak = 0;
  String? _loginDate;
  final Set<StorySceneId> _scenes = {};
  final Set<StationId> _tutorial = {};
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

  SaveRepository? _repo;
  Timer? _saveTimer;
  bool _disposed = false;

  /// true → phiên này không ghi lưu (bản lưu từ phiên bản mới hơn, hoặc không đọc được bộ nhớ).
  bool _savesLocked = false;

  void _resetToNew() {
    final today = _todayKey();
    _coins = Economy.startCoins;
    _gems = Economy.startGems;
    _xp = 0;
    _day = 1;
    _oven = 1;
    _tools
      ..clear()
      ..addAll({for (final t in ToolId.values) t: 1});
    _decorOwned.clear();
    _decorEquipped
      ..clear()
      ..addAll({for (final s in DecorSlot.values) s: null});
    _mastery.clear();
    _questDate = today;
    _quests = _newQuests(today);
    _loginStreak = 0;
    _loginDate = null;
    _scenes.clear();
    _tutorial.clear();
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
  }

  // ------------------------------------------------------------------ Lưu / tải

  /// Đọc ván đã lưu, không bao giờ làm mất dữ liệu cũ:
  /// - JSON hỏng / không phải object → ván mới, chuỗi gốc được chép sang bản dự phòng;
  /// - một số trường hỏng → các trường đó về mặc định, chuỗi gốc cũng được chép dự phòng;
  /// - `v` lớn hơn [saveVersion] (bản app mới hơn đã lưu) hoặc không đọc được bộ nhớ → khoá ghi cả phiên.
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
        final bad = state._readJson(decoded);
        if (bad.isNotEmpty) {
          debugPrint('GameState.load: trường hỏng dùng mặc định (${bad.join(', ')}), giữ bản dự phòng');
          await _backup(repo, raw);
        }
      }
    }
    state.refreshDaily();
    return state;
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

  Map<String, dynamic> toJson() => {
        'v': saveVersion,
        'coins': _coins,
        'gems': _gems,
        'xp': _xp,
        'day': _day,
        'oven': _oven,
        'tools': {for (final t in ToolId.values) t.name: toolLevel(t)},
        'decorOwned': [for (final d in DecorId.values) if (_decorOwned.contains(d)) d.name],
        'decorEquipped': {for (final s in DecorSlot.values) s.name: _decorEquipped[s]?.name},
        'mastery': {for (final r in RecipeId.values) r.name: recipeMastery(r)},
        'questDate': _questDate,
        'quests': [
          for (final q in _quests) {'type': q.type.name, 'progress': q.progress, 'claimed': q.claimed},
        ],
        'loginStreak': _loginStreak,
        'loginDate': _loginDate,
        'scenes': [for (final s in StorySceneId.values) if (_scenes.contains(s)) s.name],
        'tutorial': [for (final s in StationId.values) if (_tutorial.contains(s)) s.name],
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

    field('coins', (v) => _coins = math.max(0, asInt(v)));
    field('gems', (v) => _gems = math.max(0, asInt(v)));
    field('xp', (v) => _xp = math.max(0, asInt(v)));
    field('day', (v) => _day = math.max(1, asInt(v)));
    field('oven', (v) => _oven = asInt(v).clamp(1, Economy.maxOvenLevel));

    numMap('tools', (name, value) {
      final id = enumByName(ToolId.values, name);
      if (id != null) _tools[id] = value.clamp(1, Economy.maxToolLevel(id));
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
    return bad;
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

  /// Gọi khi load và mỗi lần vào menu chính.
  void refreshDaily() {
    if (_rollDaily()) notifyListeners();
  }

  // ------------------------------------------------------------------ Đọc

  int get coins => _coins;
  int get gems => _gems;
  int get xp => _xp;
  int get level => Economy.levelForXp(_xp);
  int get xpIntoLevel => _xp - Economy.xpToReachLevel(level);
  int get xpForNextLevel {
    final l = level;
    if (l >= Economy.maxLevel) return 0;
    return Economy.xpToReachLevel(l + 1) - Economy.xpToReachLevel(l);
  }

  /// Ngày game sắp chơi (bắt đầu 1).
  int get dayNumber => _day;

  /// 1..5.
  int get ovenLevel => _oven;

  /// 1..3.
  int toolLevel(ToolId id) => _tools[id] ?? 1;

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

  bool isRecipeUnlocked(RecipeId id) => level >= Catalog.recipe(id).unlockLevel;
  bool isToppingUnlocked(ToppingId id) => level >= (Catalog.toppingUnlockLevel[id] ?? 1);

  /// Theo thứ tự `Catalog.recipes`.
  List<RecipeId> get unlockedRecipes => [
        for (final r in Catalog.recipes)
          if (level >= r.unlockLevel) r.id,
      ];
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
  bool get chapter1Complete => _scenes.contains(StorySceneId.finale);
  Set<StationId> get tutorialSeen => Set.unmodifiable(_tutorial);
  LanguagePref get language => _lang;
  bool get soundOn => _sound;
  bool get removeAds => _removeAds;

  /// Số rewarded đã xem hôm nay (ngày lịch); ngày đã qua → 0.
  int get rewardedToday => _adDate == _todayKey() ? _rewardedToday : 0;
  int? get lastInterstitialDay => _lastInterstitialDay;
  Set<IapProductId> get ownedIap => Set.unmodifiable(_iap);
  int get totalServed => _served;

  /// Số lần mèo Mochi đã ghé (ngày mưa).
  int get mochiVisits => _mochiVisits;

  /// Số lần đã vuốt ve Mochi.
  int get mochiPets => _mochiPets;

  /// Ngày game Mochi ghé gần nhất (0 = chưa bao giờ); bằng [dayNumber] → hôm nay Mochi không ghé nữa.
  int get lastMochiDay => _lastMochiDay;

  /// Từ lò + dụng cụ.
  BakeModifiers get bakeModifiers {
    final oven = Economy.ovenTiers[_oven - 1];
    double tool(ToolId id) => Economy.toolTiers[id]![toolLevel(id) - 1].value;
    return BakeModifiers(
      bakePerfectHalfWidth: oven.perfectHalfWidth,
      bakeOkHalfWidth: oven.okHalfWidth,
      mixPerfectBand: tool(ToolId.whisk),
      frostBrushRadius: tool(ToolId.pipingBag),
      toppingSnapRadius: tool(ToolId.tongs),
    );
  }

  // ------------------------------------------------------------------ Ghi

  void addCoins(int amount) {
    _coins = math.max(0, _coins + amount);
    notifyListeners();
  }

  void addGems(int amount) {
    _gems = math.max(0, _gems + amount);
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

  /// Trả các cấp vừa lên (đã cộng thưởng lên cấp).
  List<int> addXp(int amount) {
    final ups = _addXp(amount);
    notifyListeners();
    return ups;
  }

  List<int> _addXp(int amount) {
    if (amount <= 0) return const [];
    final before = level;
    _xp += amount;
    final after = level;
    final ups = <int>[];
    for (var l = before + 1; l <= after; l++) {
      ups.add(l);
      _coins += Economy.levelUpCoins(l);
      _gems += Economy.levelUpGems;
    }
    return ups;
  }

  PurchaseResult buyOvenUpgrade() {
    if (_oven >= Economy.maxOvenLevel) return PurchaseResult.maxed;
    final next = Economy.ovenTiers[_oven];
    if (level < next.requiredShopLevel) return PurchaseResult.locked;
    if (_coins < next.cost) return PurchaseResult.notEnoughCoins;
    _coins -= next.cost;
    _oven = next.level;
    notifyListeners();
    return PurchaseResult.ok;
  }

  PurchaseResult buyToolUpgrade(ToolId id) {
    final tiers = Economy.toolTiers[id]!;
    final current = toolLevel(id);
    if (current >= tiers.length) return PurchaseResult.maxed;
    final next = tiers[current];
    if (level < next.requiredShopLevel) return PurchaseResult.locked;
    if (_coins < next.cost) return PurchaseResult.notEnoughCoins;
    _coins -= next.cost;
    _tools[id] = next.level;
    notifyListeners();
    return PurchaseResult.ok;
  }

  /// Mua (không tự đặt). Gọi `equipDecor` để đặt.
  PurchaseResult buyDecor(DecorId id) {
    if (_decorOwned.contains(id)) return PurchaseResult.alreadyOwned;
    final item = Catalog.decorItem(id);
    if (level < item.unlockLevel) return PurchaseResult.locked;
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

  /// Cộng xu (net), xp, thành thạo, nhiệm vụ, thống kê của một đơn đã phục vụ.
  void applyOrderResult(Order order, Customer customer, BakeResult result) {
    _rollDaily();
    _coins = math.max(0, _coins + result.net);
    _addXp(result.xp);
    _served++;

    final oldMastery = recipeMastery(order.recipe);
    var mastery = math.max(oldMastery, 1);
    if (result.stars >= 4) mastery = math.max(mastery, 2);
    if (result.stars >= 5) mastery = 3;
    if (mastery == 3 && oldMastery < 3) _gems += Economy.masteryGemReward;
    _mastery[order.recipe] = mastery;

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
    _coins += def.rewardCoins;
    _gems += def.rewardGems;
    notifyListeners();
    return claimed;
  }

  LoginReward? claimLogin() {
    final reward = pendingLoginReward;
    if (reward == null) return null;
    _loginStreak = reward.day;
    _loginDate = _todayKey();
    _coins += reward.coins;
    _gems += reward.gems;
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
    _coins += gift.coins;
    _gems += gift.gems;
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

  /// finale → chapter1Complete = true.
  void markSceneSeen(StorySceneId id) {
    if (_scenes.add(id)) notifyListeners();
  }

  void markTutorialSeen(StationId id) {
    if (_tutorial.add(id)) notifyListeners();
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

  void registerInterstitialShown(int completedDay) {
    _lastInterstitialDay = completedDay;
    notifyListeners();
  }

  /// Trao gói IAP (giả lập).
  void grantIap(IapProductId id) {
    _coins += Catalog.iapCoins[id] ?? 0;
    _gems += Catalog.iapGems[id] ?? 0;
    switch (id) {
      case IapProductId.starterPack:
        _iap.add(id);
      case IapProductId.decorSetSeaside:
        _iap.add(id);
        _decorOwned.addAll(Catalog.decorSetSeaside);
      case IapProductId.removeAds:
        _iap.add(id);
        _removeAds = true;
      case IapProductId.pantryS:
      case IapProductId.pantryM:
      case IapProductId.pantryL:
        break;
    }
    notifyListeners();
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
