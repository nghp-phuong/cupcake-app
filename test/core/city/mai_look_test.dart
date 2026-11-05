import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';

void main() {
  test('mặc định', () {
    expect(MaiLook.defaults.hair, MaiHair.ponytail);
    expect(MaiLook.defaults.hairColor, MaiHairColor.chestnut);
    expect(const MaiLook(), MaiLook.defaults);
  });

  test('toJson/fromJson khứ hồi mọi tổ hợp', () {
    for (final h in MaiHair.values) {
      for (final c in MaiHairColor.values) {
        final look = MaiLook(hair: h, hairColor: c);
        expect(MaiLook.fromJson(look.toJson()), look);
      }
    }
  });

  test('khoá lạ / thiếu / sai kiểu → mặc định', () {
    expect(MaiLook.fromJson({}), MaiLook.defaults);
    expect(
      MaiLook.fromJson({'hair': 'mohawk', 'hairColor': 'neon'}),
      MaiLook.defaults,
    );
    expect(MaiLook.fromJson({'hair': 5, 'hairColor': null}), MaiLook.defaults);
    expect(
      MaiLook.fromJson({'hair': 'bob', 'hairColor': 'neon'}),
      const MaiLook(hair: MaiHair.bob),
    );
  });

  test('copyWith, ==, hashCode', () {
    final a = MaiLook.defaults.copyWith(hair: MaiHair.bun);
    expect(a.hair, MaiHair.bun);
    expect(a.hairColor, MaiHairColor.chestnut);
    expect(a.copyWith(hairColor: MaiHairColor.black).hair, MaiHair.bun);
    expect(a.copyWith(), a);
    expect(a == MaiLook.defaults, isFalse);
    expect(a.hashCode, const MaiLook(hair: MaiHair.bun).hashCode);
  });

  test('SalonPrices.priceFor', () {
    const base = MaiLook.defaults;
    expect(SalonPrices.priceFor(base, base), 0);
    expect(SalonPrices.priceFor(base, base.copyWith(hair: MaiHair.bob)), 300);
    expect(
      SalonPrices.priceFor(base, base.copyWith(hairColor: MaiHairColor.black)),
      200,
    );
    expect(
      SalonPrices.priceFor(
        base,
        const MaiLook(hair: MaiHair.bun, hairColor: MaiHairColor.caramel),
      ),
      500,
    );
  });
}
