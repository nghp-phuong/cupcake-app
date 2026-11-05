/// Save v3 của thành phố (docs/v3/city-gd2-spec.md §2.1–2.3): bản chụp bất biến, so sánh bằng `==`.
///
/// Đọc ([CitySave.decode]) từng trường độc lập: thiếu hoặc null → mặc định; sai kiểu → trường đó về mặc định (ghi tên
/// vào `bad`), các trường khác giữ; số ngoài khoảng bị kẹp (không tính là hỏng). Khoá lạ ở cấp trên cùng giữ nguyên
/// trong [CitySave.extra] để ghi lại. Ghi ([CitySave.toJson]) theo thứ tự ổn định: `visited`, khoá của `eaten`, `iap`,
/// khoá lạ đều được sắp xếp.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../city/city_config.dart';
import '../city/city_day.dart';
import '../city/city_wallet.dart';
import '../city/mai_look.dart';
import '../city/player_level.dart';
import '../models/ids.dart';
import '../shift/shift_stats.dart';

class CitySave {
  CitySave({
    this.createdAt = 0,
    this.savedAt = 0,
    this.migratedFrom,
    this.coins = CityWallet.startCoins,
    this.xp = 0,
    this.look = MaiLook.defaults,
    this.dayKey = '',
    this.dayNumber = 1,
    Map<String, int> eaten = const {},
    this.fullBuff = false,
    Set<String> visited = const {},
    this.language = LanguagePref.system,
    this.sound = true,
    this.introSeen = false,
    this.levelSeen = 1,
    this.removeAds = false,
    this.adsDate = '',
    this.rewarded = 0,
    Set<String> iap = const {},
    Map<String, Object?> branches = const {},
    List<Object?> staff = const [],
    this.district = defaultDistrict,
    Map<String, Object?> quests = const {},
    Map<String, Object?> login = const {},
    ShiftStats? bakery,
    Map<String, Object?> extra = const {},
  }) : eaten = Map.unmodifiable(eaten),
       visited = Set.unmodifiable(visited),
       iap = Set.unmodifiable(iap),
       branches = _freezeMap(branches),
       staff = List.unmodifiable(staff.map(_freeze)),
       quests = _freezeMap(quests),
       login = _freezeMap(login),
       bakery = bakery ?? ShiftStats(),
       extra = _freezeMap({
         for (final e in extra.entries)
           if (!knownKeys.contains(e.key)) e.key: e.value,
       });

  /// Người chơi mới tại thời điểm [now]: mọi trường mặc định, ngày = hôm nay.
  factory CitySave.fresh(DateTime now) {
    final today = cityDateKey(now);
    return CitySave(
      createdAt: now.millisecondsSinceEpoch,
      dayKey: today,
      adsDate: today,
    );
  }

  /// Thêm trường thì không tăng (§2.2).
  static const int version = 3;
  static const String defaultDistrict = 'bakery_street';

  /// Khoá cấp trên cùng mà bản này hiểu; khoá khác đi vào [extra].
  static const Set<String> knownKeys = {
    'v',
    'createdAt',
    'savedAt',
    'migratedFrom',
    'wallet',
    'look',
    'day',
    'visited',
    'settings',
    'flags',
    'ads',
    'iap',
    'branches',
    'staff',
    'district',
    'quests',
    'login',
    'bakery',
  };

  /// Thời điểm tạo / lần ghi gần nhất (ms epoch; 0 = chưa có).
  final int createdAt, savedAt;

  /// 2 = nhập từ save v2; null = không nhập.
  final int? migratedFrom;

  final int coins, xp;
  final MaiLook look;

  /// Ngày `yyyy-mm-dd` của bộ đếm ăn ('' = chưa đặt), số ngày đã chơi, món → số lần ăn trong ngày, buff "No bụng".
  final String dayKey;
  final int dayNumber;
  final Map<String, int> eaten;
  final bool fullBuff;

  /// Lô đã ghé (gồm cả id lạ).
  final Set<String> visited;

  final LanguagePref language;
  final bool sound;

  /// Đã xem intro; cấp cao nhất đã báo mở lô (1..30).
  final bool introSeen;
  final int levelSeen;

  /// Quảng cáo: đã mua xoá quảng cáo, ngày của bộ đếm, số quảng cáo thưởng đã xem trong ngày đó.
  final bool removeAds;
  final String adsDate;
  final int rewarded;

  /// Sản phẩm IAP đã sở hữu (giữ cả id lạ).
  final Set<String> iap;

  /// Để dành cho GĐ4–5: GĐ2 giữ nguyên giá trị, không dùng.
  final Map<String, Object?> branches;
  final List<Object?> staff;
  final String district;
  final Map<String, Object?> quests;
  final Map<String, Object?> login;

  /// Thống kê tiệm của bà qua các ca (GĐ3; bản GĐ2 cất khoá này vào [extra] nên không mất).
  final ShiftStats bakery;

  /// Khoá lạ ở cấp trên cùng (bản app mới hơn ghi), giữ nguyên khi ghi lại.
  final Map<String, Object?> extra;

  /// JSON để ghi; `savedAt` = [now].
  Map<String, Object?> toJson(DateTime now) => {
    'v': version,
    'createdAt': createdAt,
    'savedAt': now.millisecondsSinceEpoch,
    if (migratedFrom != null) 'migratedFrom': migratedFrom,
    'wallet': {'coins': coins, 'xp': xp},
    'look': look.toJson(),
    'day': {
      'key': dayKey,
      'n': dayNumber,
      'eaten': {for (final id in eaten.keys.toList()..sort()) id: eaten[id]},
      'fullBuff': fullBuff,
    },
    'visited': visited.toList()..sort(),
    'settings': {'lang': language.name, 'sound': sound},
    'flags': {'introSeen': introSeen, 'levelSeen': levelSeen},
    'ads': {'removeAds': removeAds, 'date': adsDate, 'rewarded': rewarded},
    'iap': iap.toList()..sort(),
    'branches': branches,
    'staff': staff,
    'district': district,
    'quests': quests,
    'login': login,
    'bakery': bakery.toJson(),
    for (final k in extra.keys.toList()..sort()) k: extra[k],
  };

  /// Đọc save v3 đã `jsonDecode`. Không bao giờ ném: [json] không phải object → mặc định, `bad = ['<root>']`.
  /// `bad`: tên các trường hỏng (dạng `wallet.coins`); `newer`: `v` > [version] (bản app mới hơn đã ghi).
  static ({CitySave save, List<String> bad, bool newer}) decode(Object? json) {
    if (json is! Map) {
      return (save: CitySave(), bad: const ['<root>'], newer: false);
    }
    final r = _Reader();

    var newer = false;
    final v = json['v'];
    if (v != null) {
      if (v is num && !v.isNaN) {
        newer = v > version;
      } else {
        r.bad.add('v');
      }
    }

    final createdAt = r.field(
      'createdAt',
      json['createdAt'],
      0,
      (v) => _int(v, 0, CityWallet.coinCap),
    );
    final savedAt = r.field(
      'savedAt',
      json['savedAt'],
      0,
      (v) => _int(v, 0, CityWallet.coinCap),
    );
    int? migratedFrom;
    if (json['migratedFrom'] case final Object m) {
      migratedFrom = _int(m, 0, _intCap);
      if (migratedFrom == null) r.bad.add('migratedFrom');
    }

    final wallet = r.section('wallet', json['wallet']);
    final coins = r.field(
      'wallet.coins',
      wallet?['coins'],
      CityWallet.startCoins,
      (v) => _int(v, 0, CityWallet.coinCap),
    );
    final xp = r.field(
      'wallet.xp',
      wallet?['xp'],
      0,
      (v) => _int(v, 0, CityWallet.xpCap),
    );

    final lookJ = r.section('look', json['look']);
    final look = MaiLook(
      hair: r.field(
        'look.hair',
        lookJ?['hair'],
        MaiLook.defaults.hair,
        (v) => enumByName(MaiHair.values, v),
      ),
      hairColor: r.field(
        'look.hairColor',
        lookJ?['hairColor'],
        MaiLook.defaults.hairColor,
        (v) => enumByName(MaiHairColor.values, v),
      ),
    );

    final day = r.section('day', json['day']);
    final dayKey = r.field(
      'day.key',
      day?['key'],
      '',
      (v) => v is String ? (isCityDateKey(v) ? v : '') : null,
    );
    final dayNumber = r.field(
      'day.n',
      day?['n'],
      1,
      (v) => _int(v, 1, _intCap),
    );
    final eaten = r.field<Map<String, int>>(
      'day.eaten',
      day?['eaten'],
      const {},
      (v) => r.counts('day.eaten', v as Map),
    );
    final fullBuff = r.field('day.fullBuff', day?['fullBuff'], false, _bool);

    final visited = r.field<Set<String>>(
      'visited',
      json['visited'],
      const {},
      (v) => r.strings('visited', v as List),
    );

    final settings = r.section('settings', json['settings']);
    final language = r.field(
      'settings.lang',
      settings?['lang'],
      LanguagePref.system,
      (v) => enumByName(LanguagePref.values, v),
    );
    final sound = r.field('settings.sound', settings?['sound'], true, _bool);

    final flags = r.section('flags', json['flags']);
    final introSeen = r.field(
      'flags.introSeen',
      flags?['introSeen'],
      false,
      _bool,
    );
    final levelSeen = r.field(
      'flags.levelSeen',
      flags?['levelSeen'],
      PlayerLevel.levelForXp(xp),
      (v) => _int(v, 1, PlayerLevel.maxLevel),
    );

    final ads = r.section('ads', json['ads']);
    final removeAds = r.field('ads.removeAds', ads?['removeAds'], false, _bool);
    final adsDate = r.field(
      'ads.date',
      ads?['date'],
      '',
      (v) => v is String ? (isCityDateKey(v) ? v : '') : null,
    );
    final rewarded = r.field(
      'ads.rewarded',
      ads?['rewarded'],
      0,
      (v) => _int(v, 0, _intCap),
    );

    final iap = r.field<Set<String>>(
      'iap',
      json['iap'],
      const {},
      (v) => r.strings('iap', v as List),
    );

    final branches = r.field<Map<String, Object?>>(
      'branches',
      json['branches'],
      const {},
      (v) => Map<String, Object?>.from(v as Map),
    );
    final staff = r.field<List<Object?>>(
      'staff',
      json['staff'],
      const [],
      (v) => v as List,
    );
    final district = r.field(
      'district',
      json['district'],
      defaultDistrict,
      (v) => v is String
          ? (CityConfig.alpha.districts.any((d) => d.id == v)
                ? v
                : defaultDistrict)
          : null,
    );
    final quests = r.field<Map<String, Object?>>(
      'quests',
      json['quests'],
      const {},
      (v) => Map<String, Object?>.from(v as Map),
    );
    final login = r.field<Map<String, Object?>>(
      'login',
      json['login'],
      const {},
      (v) => Map<String, Object?>.from(v as Map),
    );

    final bakeryJ = r.section('bakery', json['bakery']);
    int counter(String k) =>
        r.field('bakery.$k', bakeryJ?[k], 0, (v) => _int(v, 0, _intCap));
    int coinsField(String k) => r.field(
      'bakery.$k',
      bakeryJ?[k],
      0,
      (v) => _int(v, 0, CityWallet.coinCap),
    );
    final bakery = ShiftStats(
      shifts: counter('shifts'),
      orders: counter('orders'),
      stars: counter('stars'),
      five: counter('five'),
      coins: coinsField('coins'),
      best: coinsField('best'),
      tutorial: r.field<Set<String>>(
        'bakery.tutorial',
        bakeryJ?['tutorial'],
        const {},
        (v) => r.strings('bakery.tutorial', v as List),
      ),
      recipeSeen: r.field(
        'bakery.recipeSeen',
        bakeryJ?['recipeSeen'],
        0,
        (v) => _int(v, 0, PlayerLevel.maxLevel),
      ),
      adDay: counter('adDay'),
    );

    final extra = <String, Object?>{};
    json.forEach((k, v) {
      if (k is String && !knownKeys.contains(k)) extra[k] = v;
    });

    final save = CitySave(
      createdAt: createdAt,
      savedAt: savedAt,
      migratedFrom: migratedFrom,
      coins: coins,
      xp: xp,
      look: look,
      dayKey: dayKey,
      dayNumber: dayNumber,
      eaten: eaten,
      fullBuff: fullBuff,
      visited: visited,
      language: language,
      sound: sound,
      introSeen: introSeen,
      levelSeen: levelSeen,
      removeAds: removeAds,
      adsDate: adsDate,
      rewarded: rewarded,
      iap: iap,
      branches: branches,
      staff: staff,
      district: district,
      quests: quests,
      login: login,
      bakery: bakery,
      extra: extra,
    );
    return (save: save, bad: List.unmodifiable(r.bad), newer: newer);
  }

  /// Bản sao đổi vài trường (null = giữ).
  CitySave copyWith({
    int? createdAt,
    int? savedAt,
    int? migratedFrom,
    int? coins,
    int? xp,
    MaiLook? look,
    String? dayKey,
    int? dayNumber,
    Map<String, int>? eaten,
    bool? fullBuff,
    Set<String>? visited,
    LanguagePref? language,
    bool? sound,
    bool? introSeen,
    int? levelSeen,
    bool? removeAds,
    String? adsDate,
    int? rewarded,
    Set<String>? iap,
    Map<String, Object?>? branches,
    List<Object?>? staff,
    String? district,
    Map<String, Object?>? quests,
    Map<String, Object?>? login,
    ShiftStats? bakery,
    Map<String, Object?>? extra,
  }) => CitySave(
    createdAt: createdAt ?? this.createdAt,
    savedAt: savedAt ?? this.savedAt,
    migratedFrom: migratedFrom ?? this.migratedFrom,
    coins: coins ?? this.coins,
    xp: xp ?? this.xp,
    look: look ?? this.look,
    dayKey: dayKey ?? this.dayKey,
    dayNumber: dayNumber ?? this.dayNumber,
    eaten: eaten ?? this.eaten,
    fullBuff: fullBuff ?? this.fullBuff,
    visited: visited ?? this.visited,
    language: language ?? this.language,
    sound: sound ?? this.sound,
    introSeen: introSeen ?? this.introSeen,
    levelSeen: levelSeen ?? this.levelSeen,
    removeAds: removeAds ?? this.removeAds,
    adsDate: adsDate ?? this.adsDate,
    rewarded: rewarded ?? this.rewarded,
    iap: iap ?? this.iap,
    branches: branches ?? this.branches,
    staff: staff ?? this.staff,
    district: district ?? this.district,
    quests: quests ?? this.quests,
    login: login ?? this.login,
    bakery: bakery ?? this.bakery,
    extra: extra ?? this.extra,
  );

  @override
  bool operator ==(Object other) =>
      other is CitySave &&
      other.createdAt == createdAt &&
      other.savedAt == savedAt &&
      other.migratedFrom == migratedFrom &&
      other.coins == coins &&
      other.xp == xp &&
      other.look == look &&
      other.dayKey == dayKey &&
      other.dayNumber == dayNumber &&
      mapEquals(other.eaten, eaten) &&
      other.fullBuff == fullBuff &&
      setEquals(other.visited, visited) &&
      other.language == language &&
      other.sound == sound &&
      other.introSeen == introSeen &&
      other.levelSeen == levelSeen &&
      other.removeAds == removeAds &&
      other.adsDate == adsDate &&
      other.rewarded == rewarded &&
      setEquals(other.iap, iap) &&
      _jsonEquals(other.branches, branches) &&
      _jsonEquals(other.staff, staff) &&
      other.district == district &&
      _jsonEquals(other.quests, quests) &&
      _jsonEquals(other.login, login) &&
      other.bakery == bakery &&
      _jsonEquals(other.extra, extra);

  @override
  int get hashCode => Object.hashAll([
    createdAt,
    savedAt,
    migratedFrom,
    coins,
    xp,
    look,
    dayKey,
    dayNumber,
    _jsonHash(eaten),
    fullBuff,
    Object.hashAllUnordered(visited),
    language,
    sound,
    introSeen,
    levelSeen,
    removeAds,
    adsDate,
    rewarded,
    Object.hashAllUnordered(iap),
    _jsonHash(branches),
    _jsonHash(staff),
    district,
    _jsonHash(quests),
    _jsonHash(login),
    bakery,
    _jsonHash(extra),
  ]);

  @override
  String toString() {
    try {
      return 'CitySave(${jsonEncode(toJson(DateTime.fromMillisecondsSinceEpoch(savedAt)))})';
    } catch (_) {
      return 'CitySave(coins: $coins, xp: $xp, day: $dayKey)';
    }
  }
}

/// Trần chung cho các số đếm (2^31 − 1).
const int _intCap = 2147483647;

/// Số (kể cả ±∞) → kẹp [min, max]; không phải số / NaN → null (trường hỏng). So sánh trước khi `toInt` để 1e400 /
/// vô cực không bị đổi thành số khác.
int? _int(Object v, int min, int max) {
  if (v is! num || v.isNaN) return null;
  if (v >= max) return max;
  if (v <= min) return min;
  return v.toInt();
}

bool? _bool(Object v) => v is bool ? v : null;

class _Reader {
  final List<String> bad = [];

  /// Mục con là object: thiếu / null → null; sai kiểu → null và đánh dấu hỏng.
  Map? section(String path, Object? v) {
    if (v == null) return null;
    if (v is Map) return v;
    bad.add(path);
    return null;
  }

  /// Thiếu / null → [fallback]; [read] ném hoặc trả null → [fallback] và đánh dấu hỏng.
  T field<T extends Object>(
    String path,
    Object? v,
    T fallback,
    T? Function(Object v) read,
  ) {
    if (v == null) return fallback;
    try {
      final value = read(v);
      if (value != null) return value;
    } catch (_) {
      // Sai kiểu: rơi xuống mặc định.
    }
    bad.add(path);
    return fallback;
  }

  /// Danh sách chuỗi khác rỗng: phần tử hỏng bị bỏ (trường vẫn đánh dấu hỏng), phần tử tốt giữ.
  Set<String> strings(String path, List list) {
    final out = <String>{};
    var failed = false;
    for (final e in list) {
      if (e is String && e.isNotEmpty) {
        out.add(e);
      } else {
        failed = true;
      }
    }
    if (failed) bad.add(path);
    return out;
  }

  /// id → số lần 0..999: mục hỏng / ngoài khoảng bị bỏ (trường vẫn đánh dấu hỏng), mục tốt giữ (gồm cả id lạ).
  Map<String, int> counts(String path, Map map) {
    final out = <String, int>{};
    var failed = false;
    map.forEach((k, v) {
      if (k is String &&
          v is num &&
          !v.isNaN &&
          v >= 0 &&
          v <= CityWallet.maxEatenPerDay) {
        out[k] = v.toInt();
      } else {
        failed = true;
      }
    });
    if (failed) bad.add(path);
    return out;
  }
}

Object? _freeze(Object? v) => switch (v) {
  Map() => _freezeMap(v),
  List() => List<Object?>.unmodifiable(v.map(_freeze)),
  _ => v,
};

Map<String, Object?> _freezeMap(Map v) => Map<String, Object?>.unmodifiable({
  for (final e in v.entries) '${e.key}': _freeze(e.value),
});

bool _jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _jsonHash(Object? v) => switch (v) {
  Map() => Object.hashAllUnordered(
    v.entries.map((e) => Object.hash(e.key, _jsonHash(e.value))),
  ),
  List() => Object.hashAll(v.map(_jsonHash)),
  _ => v.hashCode,
};
