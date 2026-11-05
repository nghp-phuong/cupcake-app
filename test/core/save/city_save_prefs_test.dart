import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save/city_save.dart';
import 'package:sugarleaf_bakery/core/save/city_save_repository.dart';
import 'package:sugarleaf_bakery/core/save/city_save_store.dart';

DateTime _clock() => DateTime(2026, 11, 4, 10);

final _v2 = jsonEncode({
  'v': 2,
  'coins': 99999,
  'lang': 'vi',
  'sound': false,
  'introSeen': true,
  'removeAds': true,
  'iap': ['removeAds'],
});

void main() {
  test('tên khoá', () {
    expect(PrefsCitySaveRepository.v3Key, 'sugarleaf_save_v3');
    expect(PrefsCitySaveRepository.corruptKey, 'sugarleaf_save_v3_corrupt');
    expect(PrefsCitySaveRepository.v2Key, 'sugarleaf_save_v1');
  });

  test('§2.5-19 Prefs: ghi đúng khoá v3, khoá v2 không đổi', () async {
    SharedPreferences.setMockInitialValues({
      PrefsCitySaveRepository.v2Key: _v2,
      'sugarleaf_save_v1_corrupt': 'cũ',
      'khac': 'giu',
    });
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};

    final store = await CitySaveStore.load(
      PrefsCitySaveRepository(),
      clock: _clock,
    );
    expect(store.source, CitySaveSource.importedV2);
    final raw = prefs.getString(PrefsCitySaveRepository.v3Key);
    expect(raw, isNotNull);
    final s = CitySave.decode(jsonDecode(raw!)).save;
    expect(s.language, LanguagePref.vi);
    expect(s.migratedFrom, 2);

    store.attachAutosave();
    store.game.wallet.addXp(5);
    await store.flush();
    expect(
      CitySave.decode(
        jsonDecode(prefs.getString(PrefsCitySaveRepository.v3Key)!),
      ).save.xp,
      5,
    );
    await store.resetAll();
    store.dispose();

    // Mọi khoá cũ y nguyên; chỉ thêm khoá v3.
    for (final e in before.entries) {
      expect(prefs.get(e.key), e.value, reason: e.key);
    }
    expect(prefs.getKeys(), {...before.keys, PrefsCitySaveRepository.v3Key});

    // Lần sau đọc v3, không nhập lại v2.
    final again = await CitySaveStore.load(
      PrefsCitySaveRepository(),
      clock: _clock,
    );
    expect(again.source, CitySaveSource.v3);
    expect(prefs.getString(PrefsCitySaveRepository.v2Key), _v2);
  });

  test(
    'Prefs: v3 hỏng → bản dự phòng đầu không bị đè, lần sau thêm hậu tố',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsCitySaveRepository.v3Key: '{hỏng 1',
        PrefsCitySaveRepository.v2Key: _v2,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsCitySaveRepository();
      final s1 = await CitySaveStore.load(repo, clock: _clock);
      expect(s1.source, CitySaveSource.recovered);
      expect(prefs.getString(PrefsCitySaveRepository.corruptKey), '{hỏng 1');
      expect(prefs.getString(PrefsCitySaveRepository.v2Key), _v2);

      await prefs.setString(PrefsCitySaveRepository.v3Key, '{hỏng 2');
      await CitySaveStore.load(repo, clock: _clock);
      expect(prefs.getString(PrefsCitySaveRepository.corruptKey), '{hỏng 1');
      final extra = prefs
          .getKeys()
          .where((k) => k.startsWith('${PrefsCitySaveRepository.corruptKey}_'))
          .toList();
      expect(extra, hasLength(1));
      expect(prefs.getString(extra.single), '{hỏng 2');
      expect(prefs.getString(PrefsCitySaveRepository.v2Key), _v2);
    },
  );

  test('Prefs: chưa có gì → không ghi khoá nào', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await CitySaveStore.load(
      PrefsCitySaveRepository(),
      clock: _clock,
    );
    expect(store.source, CitySaveSource.fresh);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
