import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ids.dart';

export 'art_paint.dart';

/// Nhóm ảnh vẽ tay = thư mục `assets/art/<name>/`.
enum ArtGroup {
  cakes,
  moulds,
  batter,
  baked,
  frosting,
  toppings,
  boxes,
  items,
  decor,
  tiles,
  scenes,
  shop,
  kitchen,
  icons;

  String get dir => 'assets/art/$name/';

  /// Ảnh nền 1280×720 (~3,7 MB khi giải mã): cache riêng [ArtSprites.largeCacheBytes].
  bool get isLarge => this == scenes || this == shop || this == kitchen;

  /// Cạnh dài tối đa khi giải mã (null = giữ kích thước gốc). Topping luôn vẽ nhỏ → 256 px, tốn 1/4 RAM.
  /// Icon giao diện vẽ tay luôn hiển thị nhỏ → 192 px.
  int? get maxDecodeSide => switch (this) {
        toppings => 256,
        icons => 192,
        _ => null,
      };

  /// Nhóm chưa có ảnh đóng gói (chưa khai báo thư mục trong pubspec): mọi id bị coi là thiếu, vẽ dự phòng.
  /// Có ảnh thì khai báo `assets/art/<nhóm>/` trong pubspec và bỏ nhóm khỏi đây.
  bool get isPending => this == icons;
}

/// Cảnh nền toàn màn (1280×720) trong `assets/art/scenes/`.
enum ArtScene {
  menu('menu_bg'),
  daySummary('day_summary_bg'),
  kitchenOverview('kitchen_overview'),
  rainyDay('rainy_day'),
  storyGrandmaKitchen('story_grandma_kitchen'),
  storyTown('story_town');

  const ArtScene(this.id);

  final String id;
}

/// Một ảnh vẽ tay: nhóm + id (tên file không đuôi).
@immutable
class ArtRef {
  const ArtRef(this.group, this.id);

  final ArtGroup group;
  final String id;

  String get assetPath => ArtSprites.assetPath(group, id);

  /// Ảnh đã giải mã; null khi chưa nạp xong hoặc thiếu (người gọi vẽ hình code dự phòng).
  ui.Image? get image => ArtSprites.image(group, id);

  bool get isMissing => ArtSprites.isMissing(group, id);

  @override
  bool operator ==(Object other) => other is ArtRef && other.group == group && other.id == id;

  @override
  int get hashCode => Object.hash(group, id);

  @override
  String toString() => 'ArtRef(${group.name}/$id)';
}

/// Đồ hoạ vẽ tay (WebP) ở `assets/art/<nhóm>/<id>.webp`: bánh, khuôn, bột, đế đã nướng, kem, topping, hộp,
/// đồ vật/icon, trang trí, hoạ tiết lặp (512×512) và cảnh nền / tiệm / 6 trạm bếp (1280×720).
///
/// Cùng cơ chế với `CharacterSprites`: nạp bất đồng bộ (tối đa [_maxActive] ảnh cùng lúc), chỉ nạp file có
/// trong AssetManifest, giải mã thành `ui.Image`, giữ trong hai cache LRU tính theo byte đã giải mã —
/// ảnh nhỏ [smallCacheBytes] (~1 MB/ảnh 512×512), ảnh nền [largeCacheBytes] (~3,7 MB/ảnh 1280×720, đủ 6 trạm +
/// tiệm + 1 cảnh) — để máy Android tầm trung không tốn RAM. File thiếu hoặc đọc lỗi bị coi là thiếu: không nạp
/// lại, không log ồn — người gọi vẽ hình code dự phòng. [changes] báo mỗi khi có ảnh mới nạp xong để painter
/// vẽ lại.
abstract final class ArtSprites {
  static const smallCacheBytes = 48 << 20;
  static const largeCacheBytes = 32 << 20;
  static const _maxActive = 2;
  static const _root = 'assets/art/';

  /// Số cấp lò có ảnh (`oven_1..oven_5`).
  static const ovenLevels = 5;

  /// Mọi id có ảnh đóng gói, theo nhóm.
  static const Map<ArtGroup, List<String>> ids = {
    ArtGroup.cakes: [
      'birthdayCake', 'cheesecake', 'cupcakeChocolate', 'cupcakeVanilla', 'eggTart', //
      'macaron', 'matchaCake', 'muffinBlueberry', 'redVelvetCupcake', 'strawberryCake',
    ],
    ArtGroup.moulds: ['cupcakeLiner', 'macaronMat', 'muffinCup', 'roundPan', 'springformPan', 'tallPan', 'tartShell'],
    ArtGroup.batter: ['almond', 'butter', 'cheese', 'chocolate', 'matcha', 'redVelvet', 'vanilla'],
    ArtGroup.baked: [
      'cupcakeLiner', 'cupcakeLiner_chocolate', 'cupcakeLiner_redVelvet', 'macaronMat', 'muffinCup', //
      'roundPan', 'roundPan_matcha', 'springformPan', 'tallPan', 'tartShell',
    ],
    ArtGroup.frosting: ['chocolateGanache', 'creamCheese', 'custard', 'matchaCream', 'strawberryCream', 'vanillaCream'],
    ArtGroup.toppings: ['blueberry', 'candle', 'cherry', 'chocolateChips', 'mintLeaf', 'sprinkles', 'strawberry', 'sugarPearl'],
    ArtGroup.boxes: ['small_closed', 'small_open', 'cake_closed', 'cake_open', 'gift_closed', 'gift_open'],
    ArtGroup.items: [
      'oven_1', 'oven_2', 'oven_3', 'oven_4', 'oven_5', 'tool_whisk', 'tool_pipingBag', 'tool_tongs', //
      'bowl', 'coin', 'gem', 'star_on', 'star_off', 'ticket', 'book', 'gift_daily', 'narrator_book', //
      'baking_tray', 'plate_serving', 'pantry_sack', 'no_ads_badge',
    ],
    ArtGroup.decor: ['counterCakeStand', 'counterFlowers', 'plantFern', 'plantLemonTree', 'windowCurtains', 'windowSeaView'],
    ArtGroup.tiles: ['floorCheckered', 'floorHerringbone', 'wallpaperFloral', 'wallpaperStripes'],
    ArtGroup.scenes: ['day_summary_bg', 'kitchen_overview', 'menu_bg', 'rainy_day', 'story_grandma_kitchen', 'story_town'],
    ArtGroup.shop: ['shop_base'],
    ArtGroup.kitchen: ['station_mould', 'station_mix', 'station_bake', 'station_frost', 'station_topping', 'station_box'],
    ArtGroup.icons: [
      'settings', 'close', 'back', 'forward', 'arrow_up', 'arrow_down', 'skip', 'exit', 'check', 'lock', //
      'info', 'warning', 'error', 'medal_max', 'sound_on', 'sound_off', 'language', 'phone', 'trash', 'reset', //
      'play_video', 'no_ads', 'shop_bag', 'basket', 'quest_board', 'decor_chair', 'slot_wallpaper', 'slot_floor', //
      'slot_counter', 'slot_window', 'slot_plant', 'heart', 'vip', 'customer', 'sun', 'umbrella', 'raindrop', 'paw', //
      'moon', 'flame', 'sparkle', 'trophy', 'confetti', 'clock', 'tip_jar', 'bulb', 'leaf_logo', 'pin', 'plus', //
      'cake_slice', 'book', 'star', 'oven', 'gift', 'tap', 'storefront', 'coin', 'ticket',
    ],
  };

  /// Ảnh đang chờ vẽ: có trong [ids] (code đã dùng) nhưng có thể chưa có file — thiếu thì bị coi là thiếu êm,
  /// người gọi dùng ảnh thay thế. Có file rồi thì bỏ khỏi đây.
  static const Map<ArtGroup, Set<String>> pendingIds = {};

  static String assetPath(ArtGroup group, String id) => '${group.dir}$id.webp';

  /// Mọi ảnh của [group].
  static List<ArtRef> group(ArtGroup group) => [for (final id in ids[group] ?? const <String>[]) ArtRef(group, id)];

  // ------------------------------------------------------------------ Tra ảnh theo enum của game

  static ArtRef cake(RecipeId recipe) => ArtRef(ArtGroup.cakes, recipe.name);

  static ArtRef mould(MouldType mould) => ArtRef(ArtGroup.moulds, mould.name);

  /// Bột trong tô.
  static ArtRef batter(BatterType batter) => ArtRef(ArtGroup.batter, batter.name);

  /// Đế đã nướng theo khuôn: có biến thể theo bột (`<khuôn>_<bột>`) thì dùng, không thì ảnh gốc của khuôn.
  static ArtRef baked(MouldType mould, BatterType batter) {
    final variant = '${mould.name}_${batter.name}';
    return ArtRef(ArtGroup.baked, _bakedVariants.contains(variant) ? variant : mould.name);
  }

  static const _bakedVariants = {'cupcakeLiner_chocolate', 'cupcakeLiner_redVelvet', 'roundPan_matcha'};

  /// Túi bắt kem (chén cho custard).
  static ArtRef frosting(FrostingId frosting) => ArtRef(ArtGroup.frosting, frosting.name);

  static ArtRef topping(ToppingId topping) => ArtRef(ArtGroup.toppings, topping.name);

  static ArtRef box(BoxType box, {bool open = false}) => ArtRef(ArtGroup.boxes, '${box.name}_${open ? 'open' : 'closed'}');

  /// Món trang trí: giấy dán tường / sàn → hoạ tiết lặp ([ArtGroup.tiles], vẽ bằng `paintArtTiled`);
  /// quầy / cửa sổ / cây → ảnh trong suốt ([ArtGroup.decor]).
  static ArtRef decor(DecorId decor) => ArtRef(switch (decor) {
        DecorId.wallpaperStripes || DecorId.wallpaperFloral || DecorId.floorCheckered || DecorId.floorHerringbone => ArtGroup.tiles,
        _ => ArtGroup.decor,
      }, decor.name);

  /// Lò theo cấp 1..[ovenLevels] (ngoài khoảng thì kẹp lại).
  static ArtRef oven(int level) => ArtRef(ArtGroup.items, 'oven_${level.clamp(1, ovenLevels)}');

  static ArtRef tool(ToolId tool) => ArtRef(ArtGroup.items, 'tool_${tool.name}');

  static ArtRef star({bool filled = true}) => filled ? starOn : starOff;

  static const coin = ArtRef(ArtGroup.items, 'coin');
  static const gem = ArtRef(ArtGroup.items, 'gem');
  static const starOn = ArtRef(ArtGroup.items, 'star_on');
  static const starOff = ArtRef(ArtGroup.items, 'star_off');
  static const ticket = ArtRef(ArtGroup.items, 'ticket');
  static const book = ArtRef(ArtGroup.items, 'book');
  static const giftDaily = ArtRef(ArtGroup.items, 'gift_daily');
  static const bowl = ArtRef(ArtGroup.items, 'bowl');

  /// Khay nướng (trạm 1: đặt khuôn lên khay).
  static const bakingTray = ArtRef(ArtGroup.items, 'baking_tray');

  /// Đĩa phục vụ (trạm topping/đóng hộp, vé đơn ở quầy).
  static const servingPlate = ArtRef(ArtGroup.items, 'plate_serving');

  /// Bao nguyên liệu (kho / gói nguyên liệu).
  static const pantrySack = ArtRef(ArtGroup.items, 'pantry_sack');

  /// Huy hiệu xoá quảng cáo (cửa hàng).
  static const noAdsBadge = ArtRef(ArtGroup.items, 'no_ads_badge');

  static ArtRef scene(ArtScene scene) => ArtRef(ArtGroup.scenes, scene.id);

  /// Nội thất tiệm / quầy (1280×720).
  static const shopBase = ArtRef(ArtGroup.shop, 'shop_base');

  /// Nền trạm làm bánh (1280×720).
  static ArtRef station(StationId station) => ArtRef(ArtGroup.kitchen, 'station_${station.name}');

  /// Icon giao diện vẽ tay (`assets/art/icons/<id>.webp`, id trong `ids[ArtGroup.icons]`); chưa có ảnh → null,
  /// người gọi vẽ icon dự phòng.
  static ArtRef icon(String id) => ArtRef(ArtGroup.icons, id);

  // ------------------------------------------------------------------ Nạp / cache

  /// Báo khi có ảnh mới nạp xong (dùng làm `repaint` cho CustomPainter).
  static Listenable get changes => _changes;
  static final _changes = _ArtNotifier();

  static AssetBundle _bundle = rootBundle;
  static final _small = _Pool(smallCacheBytes);
  static final _large = _Pool(largeCacheBytes);
  static final _missing = <String>{};
  static final _queue = ListQueue<ArtRef>();
  static final _waiters = <String, Completer<void>>{}; // đang xếp hàng hoặc đang nạp.
  static var _active = 0;
  static var _generation = 0;
  static Future<Set<String>?>? _manifest;

  static _Pool _pool(ArtGroup group) => group.isLarge ? _large : _small;

  /// Ảnh [id] của [group]; chưa nạp → xếp hàng nạp (ưu tiên) và trả null — người gọi vẽ hình code dự phòng,
  /// rồi vẽ lại khi [changes] báo.
  static ui.Image? image(ArtGroup group, String id) {
    final key = assetPath(group, id);
    final hit = _pool(group).touch(key);
    if (hit != null) return hit;
    _request(ArtRef(group, id), urgent: true);
    return null;
  }

  /// Ảnh đã được xác định là thiếu (không có file hoặc đọc lỗi).
  static bool isMissing(ArtGroup group, String id) => _missing.contains(assetPath(group, id));

  /// Nạp sẵn theo thứ tự, không ưu tiên hơn ảnh đang cần vẽ. Future xong khi mọi ảnh đã nạp hoặc được xác
  /// định là thiếu; không bao giờ báo lỗi. Không cần `await` (không chặn UI).
  static Future<void> preload(Iterable<ArtRef> refs) {
    final waits = <Future<void>>[];
    for (final ref in refs) {
      if (_pool(ref.group).touch(ref.assetPath) != null) continue;
      final wait = _request(ref, urgent: false);
      if (wait != null) waits.add(wait);
    }
    return Future.wait(waits);
  }

  /// Nạp lúc khởi động (sau frame đầu): nền menu, nội thất tiệm (màn ngày/trang trí vẽ ngay bằng ảnh), icon/đồ
  /// vật (gồm sổ công thức của người kể truyện), bánh.
  static Future<void> preloadStartup() =>
      preload([scene(ArtScene.menu), shopBase, ...group(ArtGroup.items), ...group(ArtGroup.cakes)]);

  /// Nạp icon giao diện (gọi khi màn đầu tiên dùng icon đã dựng). Nhóm chưa có ảnh → xong ngay, không tra manifest.
  static Future<void> preloadIcons() => ArtGroup.icons.isPending ? Future.value() : preload(group(ArtGroup.icons));

  /// Ảnh cần cho cảnh tiệm một ngày: nội thất tiệm + đĩa phục vụ (vé đơn ở quầy) + đồ trang trí đang đặt
  /// ([equippedDecor], ô trống bỏ qua) + cảnh mưa nếu [rainy]. Nội thất tiệm đứng đầu (vẽ được ngay khi có,
  /// trang trí phủ lên sau).
  static List<ArtRef> dayRefs({Map<DecorSlot, DecorId?> equippedDecor = const {}, bool rainy = false}) => [
        shopBase,
        servingPlate,
        for (final slot in DecorSlot.values)
          if (equippedDecor[slot] case final id?) decor(id),
        if (rainy) scene(ArtScene.rainyDay),
      ];

  /// Nạp trước một ngày kinh doanh (gọi trước khi mở màn ngày để cảnh tiệm không thoáng hình code): xem
  /// [dayRefs]. Future xong khi mọi ảnh đã nạp hoặc được xác định là thiếu; không cần `await`.
  static Future<void> preloadDay({Map<DecorSlot, DecorId?> equippedDecor = const {}, bool rainy = false}) =>
      preload(dayRefs(equippedDecor: equippedDecor, rainy: rainy));

  /// Ảnh một trạm làm bánh cần để vẽ hoàn toàn bằng ảnh: nền trạm trước, rồi đồ vật của trạm. Có [mould] thì
  /// gồm đế đã nướng của món (theo [batter]) cho trạm 3–6.
  ///
  /// - mould: nền + mọi khuôn + khay nướng.
  /// - mix: nền + mọi bột + tô + phới.
  /// - bake: nền + lò cấp [ovenLevel] + đế đã nướng.
  /// - frost: nền + đế đã nướng + mọi túi kem + túi bắt kem.
  /// - topping: nền + đế đã nướng + mọi topping + kẹp + đĩa phục vụ.
  /// - box: nền + đế đã nướng + mọi hộp + đĩa phục vụ.
  static List<ArtRef> stationRefs(StationId s, {int ovenLevel = 1, MouldType? mould, BatterType batter = BatterType.vanilla}) {
    final cake = mould == null ? null : baked(mould, batter);
    return [
      station(s),
      ...switch (s) {
        StationId.mould => [...group(ArtGroup.moulds), bakingTray],
        StationId.mix => [...group(ArtGroup.batter), bowl, tool(ToolId.whisk)],
        StationId.bake => [oven(ovenLevel), ?cake],
        StationId.frost => [?cake, ...group(ArtGroup.frosting), tool(ToolId.pipingBag)],
        StationId.topping => [?cake, ...group(ArtGroup.toppings), tool(ToolId.tongs), servingPlate],
        StationId.box => [?cake, ...group(ArtGroup.boxes), servingPlate],
      },
    ];
  }

  /// Nạp ảnh của một trạm ([stationRefs]). Future xong khi đủ ảnh của trạm (đã nạp hoặc xác định thiếu) — game có
  /// thể chờ (kèm thời hạn) trước khi hiện trạm để không thoáng hình code. Không bao giờ báo lỗi.
  static Future<void> preloadStation(StationId s, {int ovenLevel = 1, MouldType? mould, BatterType batter = BatterType.vanilla}) =>
      preload(stationRefs(s, ovenLevel: ovenLevel, mould: mould, batter: batter));

  /// Nạp trước cả phiên làm bánh: ảnh của 6 trạm theo thứ tự chơi (trạm 1 — nền + khuôn — đứng đầu hàng chờ),
  /// lò cấp [ovenLevel]; có [mould] thì nạp cả đế đã nướng của món (theo [batter]) để bánh ở trạm 3–6 vẽ bằng ảnh
  /// ngay. Future xong khi đủ ảnh của MỌI trạm; muốn chờ riêng trạm đầu thì gọi thêm
  /// `preloadStation(StationId.mould)` (hai lời gọi dùng chung một lần nạp, không nạp đôi).
  static Future<void> preloadKitchen({int ovenLevel = 1, MouldType? mould, BatterType batter = BatterType.vanilla}) => preload({
        for (final s in StationId.values) ...stationRefs(s, ovenLevel: ovenLevel, mould: mould, batter: batter),
      });

  static Future<void>? _request(ArtRef ref, {required bool urgent}) {
    final key = ref.assetPath;
    if (_missing.contains(key)) return null;
    if (ref.group.isPending) {
      _missing.add(key);
      return null;
    }
    final pending = _waiters[key];
    if (pending != null) {
      // Đang chờ trong hàng mà giờ cần vẽ ngay → đưa lên đầu.
      if (urgent && _queue.remove(ref)) _queue.addFirst(ref);
      return pending.future;
    }
    final waiter = _waiters[key] = Completer<void>();
    urgent ? _queue.addFirst(ref) : _queue.addLast(ref);
    _pump();
    return waiter.future;
  }

  static void _pump() {
    while (_active < _maxActive && _queue.isNotEmpty) {
      _active++;
      unawaited(_load(_queue.removeFirst(), _generation));
    }
  }

  static Future<void> _load(ArtRef ref, int generation) async {
    final key = ref.assetPath;
    ui.Image? image;
    try {
      final assets = await (_manifest ??= _loadManifest());
      if (assets != null && assets.contains(key)) {
        final buffer = await _bundle.loadBuffer(key);
        final maxSide = ref.group.maxDecodeSide;
        final codec = maxSide == null
            ? await ui.instantiateImageCodecFromBuffer(buffer)
            : await ui.instantiateImageCodecWithSize(buffer, getTargetSize: (w, h) {
                final k = maxSide / math.max(w, h);
                return k >= 1 ? const ui.TargetImageSize() : ui.TargetImageSize(width: (w * k).round(), height: (h * k).round());
              });
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } catch (e) {
      // File có trong manifest mà đọc/giải mã lỗi: báo một lần (chỉ bản debug), sau đó dùng hình code.
      if (kDebugMode) debugPrint('ArtSprites: bỏ qua $key ($e)');
    }
    if (generation != _generation) {
      image?.dispose(); // Đã reset trong lúc nạp.
      return;
    }
    _active--;
    if (image == null) {
      _missing.add(key);
    } else {
      _pool(ref.group).put(key, image);
    }
    _waiters.remove(key)?.complete();
    if (image != null) _changes.ping();
    _pump();
  }

  /// Danh sách ảnh đồ hoạ đóng gói trong app; null nếu không đọc được manifest (vd. test thuần không binding).
  static Future<Set<String>?> _loadManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      return {for (final a in manifest.listAssets()) if (a.startsWith(_root)) a};
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static int get debugCachedCount => _small.cache.length + _large.cache.length;

  @visibleForTesting
  static int debugCachedBytes({required bool large}) => (large ? _large : _small).bytes;

  /// Ảnh đã nằm trong cache (không xếp hàng nạp như [image]).
  @visibleForTesting
  static bool debugIsCached(ArtRef ref) => _pool(ref.group).cache.containsKey(ref.assetPath);

  /// Xoá cache/hàng chờ; [bundle] thay cho rootBundle (test).
  @visibleForTesting
  static void debugReset({AssetBundle? bundle}) {
    _generation++;
    _small.clear();
    _large.clear();
    _missing.clear();
    _queue.clear();
    for (final w in _waiters.values) {
      w.complete();
    }
    _waiters.clear();
    _active = 0;
    _manifest = null;
    _bundle = bundle ?? rootBundle;
  }
}

/// Cache LRU giới hạn theo byte đã giải mã (RGBA: rộng × cao × 4). Luôn giữ ít nhất ảnh mới nhất.
class _Pool {
  _Pool(this.maxBytes);

  final int maxBytes;
  final cache = <String, ui.Image>{}; // LinkedHashMap: cuối = dùng gần nhất.
  var bytes = 0;

  static int _size(ui.Image image) => image.width * image.height * 4;

  ui.Image? touch(String key) {
    final hit = cache.remove(key);
    if (hit != null) cache[key] = hit;
    return hit;
  }

  void put(String key, ui.Image image) {
    final old = cache.remove(key);
    if (old != null) {
      bytes -= _size(old);
      old.dispose();
    }
    cache[key] = image;
    bytes += _size(image);
    while (bytes > maxBytes && cache.length > 1) {
      final evicted = cache.remove(cache.keys.first)!;
      bytes -= _size(evicted);
      evicted.dispose();
    }
  }

  void clear() {
    for (final image in cache.values) {
      image.dispose();
    }
    cache.clear();
    bytes = 0;
  }
}

class _ArtNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
