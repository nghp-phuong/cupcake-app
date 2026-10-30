import 'dart:ui' show Offset;

import '../models/ids.dart';

/// Loại mục tiêu của một level; `stars` cùng đơn vị (xu / khách đã phục vụ / đơn đặc biệt xong).
enum GoalType { coins, customers, specialOrders }

/// Khách đặc biệt ghé trong màn: ba bạn quen hoặc khách VIP (bà Rosa, ảnh `vip_00`).
enum SpecialWho { hoa, linh, kenji, vip }

/// Id kịch bản hướng dẫn lần đầu (trường `tutorial` của level trong levels.json). Kịch bản nằm trong code
/// (`tutorial.dart` + `LevelSession`), JSON chỉ ghi id.
abstract final class TutorialIds {
  /// L1: bán cho khách, làm một mẻ qua 6 trạm.
  static const basics = 'basics';

  /// L2: combo + mỗi khách một món.
  static const combo = 'combo';

  /// L3: vòng kiên nhẫn + khách bỏ đi.
  static const patience = 'patience';

  static const all = [basics, combo, patience];
}

/// Thông số chung của mọi level (`defaults` trong levels.json); level có thể ghi đè từng trường.
class LevelDefaults {
  const LevelDefaults({
    this.ovenSec = 7,
    this.ovens = 1,
    this.batchSize = 3,
    this.slotCapacity = 6,
    this.comboWindowSec = 6,
    this.specialPatienceSec = 90,
    this.specialRewardMult = 2.0,
    this.maxQueue = 5,
    this.counterSpots = 3,
    this.jitterPct = 20,
    this.patienceMult = 1.0,
  });

  /// Giây để kim lò chạy tới `bakeTarget` của món.
  final double ovenSec;

  /// Số lò (GĐ1: 1).
  final int ovens;

  /// Số bánh một mẻ đưa vào tủ.
  final int batchSize;

  /// Sức chứa mỗi ô tủ kính.
  final int slotCapacity;

  /// Bán trong khoảng này kể từ lần bán trước → combo tăng.
  final double comboWindowSec;
  final double specialPatienceSec;

  /// Hệ số xu của đơn đặc biệt.
  final double specialRewardMult;

  /// Tối đa khách vãng lai đứng quầy + chờ; đầy → khách mới quay đi.
  final int maxQueue;

  /// Số chỗ đứng ở quầy (sau tủ kính).
  final int counterSpots;

  /// Dao động ± % của khoảng cách sinh khách.
  final double jitterPct;

  /// Nhân kiên nhẫn của khách vãng lai (booster sau này).
  final double patienceMult;

  /// Tên trường trong JSON (dùng cho kiểm tra + ghi đè).
  static const keys = [
    'ovenSec',
    'ovens',
    'batchSize',
    'slotCapacity',
    'comboWindowSec',
    'specialPatienceSec',
    'specialRewardMult',
    'maxQueue',
    'counterSpots',
    'jitterPct',
    'patienceMult',
  ];

  /// Trường kiểu số nguyên (còn lại là số thực).
  static const intKeys = {'ovens', 'batchSize', 'slotCapacity', 'maxQueue', 'counterSpots'};

  /// Bản sao với các trường trong [values] (khoá thuộc [keys], đã kiểm tra kiểu ở loader).
  LevelDefaults overriddenBy(Map<String, num> values) {
    if (values.isEmpty) return this;
    double d(String k, double v) => values[k]?.toDouble() ?? v;
    int i(String k, int v) => values[k]?.toInt() ?? v;
    return LevelDefaults(
      ovenSec: d('ovenSec', ovenSec),
      ovens: i('ovens', ovens),
      batchSize: i('batchSize', batchSize),
      slotCapacity: i('slotCapacity', slotCapacity),
      comboWindowSec: d('comboWindowSec', comboWindowSec),
      specialPatienceSec: d('specialPatienceSec', specialPatienceSec),
      specialRewardMult: d('specialRewardMult', specialRewardMult),
      maxQueue: i('maxQueue', maxQueue),
      counterSpots: i('counterSpots', counterSpots),
      jitterPct: d('jitterPct', jitterPct),
      patienceMult: d('patienceMult', patienceMult),
    );
  }
}

class ChapterData {
  const ChapterData({required this.id, required this.title, required this.starsToUnlock, String? mapArt})
      : mapArt = mapArt ?? 'chapter_$id';

  final int id;

  /// {"en": "...", "vi": "..."}.
  final Map<String, String> title;

  /// Tổng sao (mọi chương) cần để mở chương; chương còn cần đã qua level cuối của chương trước.
  final int starsToUnlock;

  /// Tên ảnh nền bản đồ (không đuôi), vd `chapter_1` → [mapAssetPath]. Thiếu ảnh → UI vẽ nền bằng code.
  final String mapArt;

  String get mapAssetPath => 'assets/art/map/$mapArt.webp';

  String titleFor(String languageCode) => title[languageCode] ?? title['en'] ?? '';
}

/// Nhịp khách: khoảng cách nội suy `startEverySec → endEverySec` trong 0..`rushAtPct`% thời gian, sau đó
/// `rushEverySec` (giờ cao điểm).
class SpawnCurve {
  const SpawnCurve({
    required this.startEverySec,
    required this.endEverySec,
    required this.rushAtPct,
    required this.rushEverySec,
  });

  final double startEverySec;
  final double endEverySec;

  /// 0..100.
  final double rushAtPct;
  final double rushEverySec;

  /// Khoảng cách gốc (chưa jitter) ở tỉ lệ thời gian [progress] (0..1, >1 sau +30 giây).
  double intervalAt(double progress) {
    final rushAt = rushAtPct / 100;
    if (progress >= rushAt) return rushEverySec;
    final t = rushAt <= 0 ? 1.0 : (progress / rushAt).clamp(0.0, 1.0);
    return startEverySec + (endEverySec - startEverySec) * t;
  }

  bool isRushAt(double progress) => progress >= rushAtPct / 100;
}

/// Mục tiêu + 3 mốc sao (tăng dần, cùng đơn vị); thắng ⇔ đạt mốc đầu.
class LevelGoal {
  const LevelGoal({required this.type, required this.stars});

  final GoalType type;

  /// Đúng 3 phần tử, tăng dần.
  final List<int> stars;

  /// Mốc thắng (1★).
  int get target => stars.first;

  /// 0..3 theo giá trị hiện tại.
  int starsFor(int value) {
    var n = 0;
    for (final s in stars) {
      if (value >= s) n++;
    }
    return n;
  }
}

/// Một lượt ghé của khách đặc biệt (dừng giờ khi làm bánh).
class SpecialVisit {
  const SpecialVisit({
    required this.atSec,
    required this.who,
    required this.recipe,
    this.scene,
    this.afterServed = 0,
    this.look,
    this.bySec,
    this.box,
  });

  /// Số kiểu ảnh VIP (`vip_00..02`, khớp `CustomerArt.vipSprites`; appearanceSeed % 3 → ảnh).
  static const vipLooks = 3;

  /// `vip_00` = bà Rosa — chỉ ra khi level ghi rõ `"look": "vip_00"` (dành cho màn đặc biệt sau).
  static const reservedVipLook = 0;

  /// Giây (thời gian màn) khách tới; chỗ đặc biệt đang bận → tới ngay khi trống.
  final double atSec;

  /// Chỉ tới khi đã phục vụ ít nhất chừng này khách trong màn ("tiếng lành đồn xa"); 0 = không điều kiện.
  final int afterServed;

  /// Hạn chót (giây màn chơi) để đạt [afterServed]: quá hạn mà chưa đủ khách → lượt ghé bị bỏ. null = không hạn.
  final double? bySec;

  /// Chỉ cho `who == vip`: ảnh VIP cố định `"vip_01"` (quý ông) / `"vip_02"` (tiểu thư) / `"vip_00"` (bà Rosa).
  /// null → ngẫu nhiên vip_01 hoặc vip_02 (không bao giờ vip_00).
  final String? look;

  /// Chỉ số ảnh VIP (0..2) từ [look]; null nếu không ghi hoặc sai dạng.
  int? get vipLookIndex {
    final l = look;
    if (l == null || !l.startsWith('vip_')) return null;
    final n = int.tryParse(l.substring(4));
    return n != null && n >= 0 && n < vipLooks ? n : null;
  }
  final SpecialWho who;
  final RecipeId recipe;

  /// Cảnh truyện chiếu trước đơn (nếu chưa xem).
  final StorySceneId? scene;

  /// Hộp đơn này đòi (GĐ8, vd. bánh cưới của bà Rosa ở L50: `gift`); null = như thường (`Recipe.box`, VIP → `gift`).
  final BoxType? box;
}

/// Một level (bất biến, đọc từ levels.json).
class LevelData {
  const LevelData({
    required this.id,
    required this.chapter,
    required this.title,
    required this.durationSec,
    required this.goal,
    required this.menu,
    required this.caseSlots,
    required this.startStock,
    required this.patienceSec,
    required this.spawn,
    this.flexibleChance = 0,
    this.specials = const [],
    this.introScene,
    this.outroScene,
    this.isSpecial = false,
    this.newRecipe,
    this.overrides = const {},
    this.mapPos = Offset.zero,
    this.tutorial,
  });

  /// 1..N, toàn cục.
  final int id;
  final int chapter;

  /// {"en": "...", "vi": "..."}.
  final Map<String, String> title;
  final int durationSec;
  final LevelGoal goal;

  /// Món bán trong màn (1..4), món đầu = món của `startStock`.
  final List<RecipeId> menu;

  /// Số ô tủ kính.
  final int caseSlots;

  /// Số bánh 3★ của `menu.first` có sẵn trong tủ đầu màn.
  final int startStock;

  /// Kiên nhẫn gốc của khách vãng lai (giây).
  final double patienceSec;
  final SpawnCurve spawn;

  /// 0..1: xác suất khách chấp nhận thêm món thứ 2.
  final double flexibleChance;
  final List<SpecialVisit> specials;

  /// Cảnh truyện trước thẻ "Sẵn sàng" (vd. prologue).
  final StorySceneId? introScene;

  /// Cảnh truyện sau màn kết quả khi thắng (vd. finale).
  final StorySceneId? outroScene;

  /// Level đặc biệt (★, cuối chương).
  final bool isSpecial;

  /// Món lần đầu xuất hiện ở level này (trọng số gọi món 2); null nếu không có món mới.
  final RecipeId? newRecipe;

  /// Các trường của `defaults` mà level ghi đè.
  final Map<String, num> overrides;

  /// Vị trí nút trên trang bản đồ chương: `dx`, `dy` trong 0..1 theo khung 1280×720 (`dy` ≥ 0.14, chừa thanh trên).
  final Offset mapPos;

  /// Id kịch bản hướng dẫn lần đầu ([TutorialIds]); null = không có.
  final String? tutorial;

  /// Mốc sao (= `goal.stars`).
  List<int> get starThresholds => goal.stars;

  String titleFor(String languageCode) => title[languageCode] ?? title['en'] ?? '';

  /// Thông số áp cho level này = [defaults] + [overrides].
  LevelDefaults tuningWith(LevelDefaults defaults) => defaults.overriddenBy(overrides);

  /// Bản sao với vị trí bản đồ khác (loader tự rải nút khi thiếu `mapPos` ở chế độ khoan dung).
  LevelData withMapPos(Offset pos) => LevelData(
        id: id,
        chapter: chapter,
        title: title,
        durationSec: durationSec,
        goal: goal,
        menu: menu,
        caseSlots: caseSlots,
        startStock: startStock,
        patienceSec: patienceSec,
        spawn: spawn,
        flexibleChance: flexibleChance,
        specials: specials,
        introScene: introScene,
        outroScene: outroScene,
        isSpecial: isSpecial,
        newRecipe: newRecipe,
        overrides: overrides,
        mapPos: pos,
        tutorial: tutorial,
      );
}

/// Toàn bộ levels.json.
class LevelConfig {
  LevelConfig({required this.version, required this.defaults, required this.chapters, required this.levels})
      : _byId = {for (final l in levels) l.id: l};

  /// Không có chương / level (nạp levels.json thất bại) — UI ẩn lối vào màn chơi khi `levels.isEmpty`.
  LevelConfig.empty() : this(version: 0, defaults: const LevelDefaults(), chapters: const [], levels: const []);

  bool get isEmpty => levels.isEmpty;

  final int version;
  final LevelDefaults defaults;
  final List<ChapterData> chapters;

  /// Theo id tăng dần.
  final List<LevelData> levels;
  final Map<int, LevelData> _byId;

  bool hasLevel(int id) => _byId.containsKey(id);

  /// Ném [ArgumentError] nếu không có.
  LevelData level(int id) => _byId[id] ?? (throw ArgumentError.value(id, 'id', 'không có level'));

  /// Level kế tiếp (null nếu là level cuối).
  LevelData? next(int id) {
    for (final l in levels) {
      if (l.id > id) return l;
    }
    return null;
  }

  ChapterData? chapter(int id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<LevelData> levelsInChapter(int chapterId) => [
        for (final l in levels)
          if (l.chapter == chapterId) l,
      ];

  /// Chương đứng trước [chapterId] theo thứ tự trong levels.json (null nếu là chương đầu / không có).
  ChapterData? previousChapter(int chapterId) {
    for (var i = 1; i < chapters.length; i++) {
      if (chapters[i].id == chapterId) return chapters[i - 1];
    }
    return null;
  }

  /// Level đầu tiên có [recipe] trong menu (để ghi "mở ở level X"); null nếu chưa level nào bán món này.
  LevelData? firstLevelWithRecipe(RecipeId recipe) {
    for (final l in levels) {
      if (l.menu.contains(recipe)) return l;
    }
    return null;
  }
}
