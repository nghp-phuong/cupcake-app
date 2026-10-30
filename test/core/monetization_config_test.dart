import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/monetization/monetization.dart';

/// `assets/config/monetization.json` (GĐ6) + loader chặt / khoan dung / loadOrEmpty.
final _raw = File(MonetizationConfigLoader.assetPath).readAsStringSync();

Map<String, dynamic> _json() => jsonDecode(_raw) as Map<String, dynamic>;

MonetizationConfig _parse(Map<String, dynamic> json, {bool strict = true, List<String>? skipped}) =>
    MonetizationConfigLoader.parse(jsonEncode(json), strict: strict, onSkip: skipped?.add);

class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);

  final String? text;

  @override
  Future<ByteData> load(String key) async {
    if (text == null) throw StateError('không có $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text!)));
  }
}

/// Mọi chuỗi en/vi trong file (tên, mô tả).
Iterable<Map<String, dynamic>> _titles(Object? node) sync* {
  if (node is Map<String, dynamic>) {
    if (node.containsKey('en') && node.containsKey('vi')) yield node;
    for (final v in node.values) {
      yield* _titles(v);
    }
  } else if (node is List) {
    for (final v in node) {
      yield* _titles(v);
    }
  }
}

void main() {
  group('monetization.json thật', () {
    final cfg = MonetizationConfigLoader.parse(_raw, strict: true);

    test('vật phẩm: đủ 3 loại, giá/ảnh khớp bản dự phòng trong code, tên theo đặc tả', () {
      expect([for (final b in cfg.boosters) b.id], BoosterId.values);
      for (final f in BoosterData.fallback) {
        final b = cfg.booster(f.id);
        expect(b.gemPrice, f.gemPrice, reason: f.id.name);
        expect(b.art, f.art, reason: f.id.name);
      }
      expect({for (final b in cfg.boosters) b.id: b.gemPrice},
          {BoosterId.fullCase: 8, BoosterId.patience: 6, BoosterId.ovenBoost: 8});
      expect(cfg.booster(BoosterId.fullCase).name('vi'), 'Tủ đầy bánh');
      expect(cfg.booster(BoosterId.patience).name('en'), 'Patient customers');
      expect(cfg.booster(BoosterId.ovenBoost).name('vi'), 'Lò ×2');
    });

    test('gói IAP: đúng thứ tự cửa hàng V2, giá/loại/nội dung khớp IapCatalog.v2, không có gói V1', () {
      expect([for (final p in cfg.products) p.id], [for (final p in IapCatalog.v2) p.id]);
      for (final p in IapCatalog.v2) {
        final q = cfg.product(p.id);
        expect(q.displayPrice, p.displayPrice, reason: p.id.name);
        expect(q.kind, p.kind, reason: p.id.name);
        expect(q.reward, p.reward, reason: p.id.name);
        expect(q.name('en'), isNotEmpty);
        expect(q.name('vi'), isNotEmpty);
        expect(q.desc('vi'), isNotEmpty);
      }
      expect(cfg.product(IapProductId.starterPack).reward,
          const Reward(coins: 8000, gems: 120, boosters: {BoosterId.fullCase: 3, BoosterId.patience: 3, BoosterId.ovenBoost: 3}));
      expect(cfg.product(IapProductId.gemsL).reward.gems, 1000);
      // Gói V1 ẩn vẫn tra được (trao / quyền sở hữu cũ).
      expect(cfg.product(IapProductId.pantryM).reward.coins, 1800);
      expect(cfg.product(IapProductId.decorSetSeaside).kind, IapKind.oneTime);
    });

    test('thẻ mùa: 20 bậc, điểm cộng dồn tăng dần, mỗi bậc có thưởng miễn phí + cao cấp, 10 / 5 điểm', () {
      final s = cfg.season!;
      expect(s.tiers, hasLength(20));
      expect(s.pointsPerNewStar, 10);
      expect(s.pointsPerWin, 5);
      expect(s.end.isAfter(s.start), isTrue);
      expect(s.start.isUtc, isFalse);
      for (var i = 0; i < s.tiers.length; i++) {
        expect(s.tiers[i].free.isEmpty, isFalse, reason: 'bậc ${i + 1}');
        expect(s.tiers[i].premium.isEmpty, isFalse, reason: 'bậc ${i + 1}');
        if (i > 0) expect(s.tiers[i].points, greaterThan(s.tiers[i - 1].points));
      }
      expect(s.tierFor(0), 0);
      expect(s.tierFor(s.tiers.first.points), 1);
      expect(s.tierFor(1 << 20), 20);
      expect([for (final t in s.tiers) t.premium.frame].whereType<String>(), hasLength(2));
      expect(s.name('vi'), isNotEmpty);
    });

    test('chuỗi en/vi: không rỗng, tiếng Việt có dấu, không dùng ký tự ★', () {
      final titles = _titles(_json()).toList();
      expect(titles.length, greaterThanOrEqualTo(3 * 2 + 7 * 2 + 1));
      final viDiacritics = RegExp('[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
          caseSensitive: false);
      for (final t in titles) {
        for (final lang in const ['en', 'vi']) {
          final v = t[lang] as String;
          expect(v.trim(), isNotEmpty);
          expect(v.contains('★'), isFalse, reason: v);
        }
        expect(viDiacritics.hasMatch(t['vi'] as String), isTrue, reason: 'thiếu dấu: ${t['vi']}');
      }
    });
  });

  group('loader chặt', () {
    void bad(void Function(Map<String, dynamic> j) edit, String msg) {
      final j = _json();
      edit(j);
      expect(() => _parse(j), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(msg))));
    }

    test('lỗi ghi rõ chỗ', () {
      bad((j) => (j['boosters'] as List).removeAt(1), 'thiếu vật phẩm "patience"');
      bad((j) => ((j['boosters'] as List)[0] as Map)['gemPrice'] = 0, 'gemPrice');
      bad((j) => ((j['boosters'] as List)[0] as Map)['id'] = 'magic', 'vật phẩm "magic" không tồn tại');
      bad((j) => (j['boosters'] as List).add((j['boosters'] as List).first), 'trùng id');
      bad((j) => ((j['boosters'] as List)[0] as Map)['price'] = 3, 'trường lạ');
      bad((j) => (j['season'] as Map)['start'] = '2026-10-15T00:00:00Z', 'giờ máy');
      bad((j) => (j['season'] as Map)['end'] = '2026-01-01T00:00:00', 'phải sau start');
      bad((j) => (j['season'] as Map)['end'] = 'mai', 'ISO');
      bad((j) => (((j['season'] as Map)['tiers'] as List)[3] as Map)['points'] = 1, 'tăng dần');
      bad((j) => (((j['season'] as Map)['tiers'] as List)[0] as Map)['free'] = {'boosters': {'magic': 1}}, '"magic"');
      bad((j) => (((j['season'] as Map)['tiers'] as List)[0] as Map)['free'] = <String, dynamic>{}, 'rỗng');
      bad((j) => ((j['products'] as List)[0] as Map)['kind'] = 'oneTime', 'phải là "consumable"');
      bad((j) => (j['products'] as List).add({'id': 'pantryS', 'price': r'$0.99', 'kind': 'consumable'}), 'ẩn');
      bad((j) => ((j['products'] as List)[0] as Map).remove('reward'), 'phần thưởng');
      bad((j) => j['seasons'] = [], 'trường lạ');
    });

    test('JSON hỏng / gốc không phải object → ném cả ở chế độ khoan dung', () {
      expect(() => MonetizationConfigLoader.parse('{', strict: false), throwsFormatException);
      expect(() => MonetizationConfigLoader.parse('[]', strict: false), throwsFormatException);
    });
  });

  group('loader khoan dung', () {
    test('vật phẩm hỏng → bản dự phòng; gói hỏng bị bỏ; mùa hỏng → không có mùa; ghi lý do', () {
      final j = _json();
      ((j['boosters'] as List)[1] as Map)['gemPrice'] = 'sáu';
      ((j['products'] as List)[0] as Map)['kind'] = 'season';
      (j['season'] as Map)['end'] = '2020-01-01T00:00:00';
      final skipped = <String>[];
      final cfg = _parse(j, strict: false, skipped: skipped);
      expect(skipped, hasLength(4)); // giá, thiếu patience, gói, mùa
      expect({for (final b in cfg.boosters) b.id}, BoosterId.values.toSet());
      expect(cfg.booster(BoosterId.patience).gemPrice, 6);
      expect(cfg.products.map((p) => p.id), isNot(contains(IapProductId.gemsS)));
      expect(cfg.product(IapProductId.gemsS).reward.gems, 80); // vẫn trao theo danh mục code
      expect(cfg.season, isNull);
    });

    test('previousSeasons: tra được theo id; trùng id bị bỏ', () {
      final j = _json();
      final old = Map<String, dynamic>.of(j['season'] as Map<String, dynamic>)
        ..['id'] = 's0_summer'
        ..['start'] = '2026-06-01T00:00:00'
        ..['end'] = '2026-09-01T00:00:00';
      j['previousSeasons'] = [old, old];
      final skipped = <String>[];
      final cfg = _parse(j, strict: false, skipped: skipped);
      expect(cfg.previousSeasons.map((s) => s.id), ['s0_summer']);
      expect(cfg.seasonById('s0_summer')?.tiers, hasLength(20));
      expect(cfg.seasonById(cfg.season!.id), same(cfg.season));
      expect(cfg.seasonById('nope'), isNull);
      expect(skipped.single, contains('trùng id mùa'));
    });
  });

  group('loadOrEmpty', () {
    test('thiếu asset / JSON hỏng → cấu hình rỗng (giá dự phòng, cửa hàng code, không mùa)', () async {
      for (final text in [null, '{oops']) {
        final cfg = await MonetizationConfigLoader.loadOrEmpty(_Bundle(text), strict: true);
        expect(cfg.isEmpty, isTrue);
        expect(cfg.season, isNull);
        expect(cfg.booster(BoosterId.fullCase).gemPrice, 8);
        expect(cfg.products.map((p) => p.id), [for (final p in IapCatalog.v2) p.id]);
      }
    });

    test('asset tốt → nạp đủ', () async {
      final cfg = await MonetizationConfigLoader.loadOrEmpty(_Bundle(_raw), strict: true);
      expect(cfg.isEmpty, isFalse);
      expect(cfg.season?.tiers, hasLength(20));
    });
  });
}
