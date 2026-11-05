import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/mai_look.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';

/// Kiểu tóc / màu tóc của Mai (`buildMai`): mặc định = Mai cũ, 16 tổ hợp trong ngân sách, đổi kiểu chỉ đổi lưới.

bool _same(Float32List a, Float32List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  final base = ChibiCharacters.build(ChibiCharacters.mai);
  final combos = [
    for (final h in MaiHair.values)
      for (final c in MaiHairColor.values) MaiLook(hair: h, hairColor: c),
  ];

  test('MaiLook.defaults ra lưới y hệt ChibiCharacters.build(mai)', () {
    final m = buildMai(MaiLook.defaults);
    expect(m.triangleCount, base.triangleCount);
    expect(m.meshes.keys.toList(), base.meshes.keys.toList());
    for (final p in base.meshes.keys) {
      final a = m.meshes[p]!, b = base.meshes[p]!;
      expect(a.vertexCount, b.vertexCount, reason: p.name);
      expect(a.triangleCount, b.triangleCount, reason: p.name);
      expect(_same(a.positions, b.positions), isTrue, reason: p.name);
      expect(_same(a.colors, b.colors), isTrue, reason: p.name);
    }
    expect(m.extraKind, ChibiExtraKind.ponytail);
  });

  test('16 tổ hợp: <= 4100 tam giác, cùng bộ phận / khung xương / chiều cao, mặt + thân không đổi', () {
    expect(combos.length, 16);
    for (final look in combos) {
      final m = buildMai(look);
      final why = look.toString();
      expect(m.triangleCount, lessThanOrEqualTo(4100), reason: why);
      expect(m.entityCount, base.entityCount, reason: why);
      expect(m.meshes.keys.toList(), base.meshes.keys.toList(), reason: why);
      expect(m.extraKind, ChibiExtraKind.ponytail, reason: why);
      expect(m.rig.pivotOf(ChibiPart.extra), base.rig.pivotOf(ChibiPart.extra), reason: why);
      expect(m.rig.eyeY, base.rig.eyeY, reason: why);
      for (final p in [
        ChibiPart.eyes,
        ChibiPart.body,
        ChibiPart.armL,
        ChibiPart.armR,
        ChibiPart.legL,
        ChibiPart.legR,
      ]) {
        expect(_same(m.meshes[p]!.positions, base.meshes[p]!.positions), isTrue, reason: '$why ${p.name}');
      }
      final f = ChibiSizes.fit(m);
      expect(f.height, inInclusiveRange(1.25, 1.38), reason: why);
      expect(ChibiSizes.crownOf(f), closeTo(ChibiSizes.maiHeight, 1e-6), reason: why);
      // Không đỉnh nào là NaN.
      for (final p in m.meshes.values) {
        for (final v in p.positions) {
          expect(v.isFinite, isTrue, reason: why);
        }
      }
    }
  });

  test('mỗi kiểu tóc có lưới khác nhau; mỗi màu chỉ đổi màu đỉnh, không đổi hình', () {
    final heads = <MaiHair, Float32List>{};
    for (final h in MaiHair.values) {
      final m = buildMai(MaiLook(hair: h));
      heads[h] = m.meshes[ChibiPart.head]!.positions;
      final other = buildMai(MaiLook(hair: h, hairColor: MaiHairColor.strawberry));
      for (final p in m.meshes.keys) {
        expect(_same(m.meshes[p]!.positions, other.meshes[p]!.positions), isTrue, reason: '$h ${p.name}');
      }
      expect(_same(m.meshes[ChibiPart.extra]!.colors, other.meshes[ChibiPart.extra]!.colors), isFalse, reason: '$h');
    }
    for (final a in MaiHair.values) {
      for (final b in MaiHair.values) {
        if (a.index < b.index) {
          final ex = buildMai(MaiLook(hair: a)).meshes[ChibiPart.extra]!.positions;
          final ey = buildMai(MaiLook(hair: b)).meshes[ChibiPart.extra]!.positions;
          expect(_same(heads[a]!, heads[b]!) && _same(ex, ey), isFalse, reason: '$a vs $b');
        }
      }
    }
  });

  test('màu tóc: đen mềm không tuyền, 4 màu khác nhau', () {
    final rgb = [for (final c in MaiHairColor.values) maiHairRgb(c)];
    expect(rgb.toSet().length, 4);
    expect(maiHairRgb(MaiHairColor.chestnut), 0xA06A45);
    expect(maiHairRgb(MaiHairColor.black), isNot(0x000000));
  });
}
