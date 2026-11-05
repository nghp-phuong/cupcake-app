import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_regulars.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';

/// 15 khách thường dạng thú chibi (V3): dữ liệu lưới, số entity / tam giác, chiều cao, màu. Dart thuần — không import
/// thermion (xem docs/v3/thermion-api-notes.md mục 9.4).

const _ids = [
  'regular_00',
  'regular_01',
  'regular_02',
  'regular_03',
  'regular_04',
  'regular_05',
  'regular_06',
  'regular_07',
  'regular_08',
  'regular_09',
  'regular_10',
  'regular_11',
  'regular_12',
  'regular_13',
  'regular_14',
];

/// Đỉnh cao nhất của bộ phận đầu (tính cả tai, mũ).
double _headTop(ChibiModel m) => m.rig.neckY + m.meshes[ChibiPart.head]!.maxY;

/// Chiều cao đầu ước từ khoảng cách cổ → tâm mắt (tâm mắt cách đỉnh đầu 0,50–0,55 chiều cao đầu → cách cằm ~0,475).
double _headHeight(ChibiModel m) => (m.rig.eyeY - m.rig.neckY) / 0.475;

/// Màu trung bình (tuyến tính) của cả nhân vật, trọng số theo số đỉnh.
List<double> _meanColor(ChibiModel m) {
  final sum = [0.0, 0.0, 0.0];
  var n = 0;
  for (final me in m.meshes.values) {
    for (var v = 0; v < me.vertexCount; v++) {
      for (var c = 0; c < 3; c++) {
        sum[c] += me.colors[4 * v + c];
      }
      n++;
    }
  }
  return [for (final s in sum) s / n];
}

void main() {
  final models = ChibiRegulars.buildAll();

  group('ChibiRegulars: danh mục', () {
    test('đủ 15 id regular_00 … regular_14, đúng thứ tự, không trùng id với bốn nhân vật mẫu', () {
      expect(ChibiRegulars.ids, _ids);
      expect([for (final m in models) m.id], _ids);
      expect([for (final m in ChibiRegulars.all) m.id], _ids);
      expect(_ids.toSet().length, 15);
      expect(_ids.toSet().intersection(ChibiCharacters.ids.toSet()), isEmpty);
    });

    test('byId trả đúng model trong all; id lạ → ArgumentError; build dựng bản mới', () {
      for (final id in _ids) {
        expect(ChibiRegulars.byId(id).id, id);
        expect(identical(ChibiRegulars.byId(id), ChibiRegulars.all[_ids.indexOf(id)]), isTrue);
        expect(ChibiRegulars.build(id).id, id);
      }
      expect(identical(ChibiRegulars.all, ChibiRegulars.all), isTrue);
      expect(() => ChibiRegulars.byId('regular_15'), throwsArgumentError);
      expect(() => ChibiRegulars.build('mai'), throwsArgumentError);
    });

    test('dựng hai lần cho lưới giống hệt (xác định)', () {
      for (final id in _ids) {
        final a = ChibiRegulars.build(id), b = ChibiRegulars.build(id);
        expect(a.triangleCount, b.triangleCount, reason: id);
        expect(a.height, b.height, reason: id);
        for (final part in a.meshes.keys) {
          expect(a.meshes[part]!.positions, b.meshes[part]!.positions, reason: '$id $part');
        }
      }
    });
  });

  group('ChibiRegulars: lưới', () {
    for (final m in models) {
      test(
        '${m.id}: lưới hợp lệ — hữu hạn, pháp tuyến đơn vị, màu 0..1, chỉ số trong khoảng, không tam giác suy biến',
        () {
          for (final e in m.meshes.entries) {
            final me = e.value;
            final tag = '${m.id} ${e.key.name}';
            expect(me.triangleCount, greaterThan(0), reason: tag);
            expect(me.positions.length, me.normals.length, reason: tag);
            expect(me.colors.length, me.vertexCount * 4, reason: tag);
            for (final v in me.positions) {
              expect(v.isFinite, isTrue, reason: '$tag vị trí');
            }
            for (var v = 0; v < me.vertexCount; v++) {
              final nx = me.normals[3 * v], ny = me.normals[3 * v + 1], nz = me.normals[3 * v + 2];
              expect(nx.isFinite && ny.isFinite && nz.isFinite, isTrue, reason: '$tag pháp tuyến');
              expect(nx * nx + ny * ny + nz * nz, closeTo(1, 1e-2), reason: '$tag pháp tuyến đơn vị');
              for (var c = 0; c < 4; c++) {
                final x = me.colors[4 * v + c];
                expect(x.isNaN, isFalse, reason: '$tag màu NaN');
                expect(x, inInclusiveRange(0.0, 1.0), reason: '$tag màu');
              }
              expect(me.colors[4 * v + 3], 1.0, reason: '$tag alpha');
            }
            for (var t = 0; t < me.triangleCount; t++) {
              final a = me.indices[3 * t], b = me.indices[3 * t + 1], c = me.indices[3 * t + 2];
              expect(math.max(a, math.max(b, c)), lessThan(me.vertexCount), reason: '$tag chỉ số');
              expect(a != b && b != c && a != c, isTrue, reason: '$tag tam giác trùng đỉnh');
              final p = me.positions;
              final e1x = p[3 * b] - p[3 * a], e1y = p[3 * b + 1] - p[3 * a + 1], e1z = p[3 * b + 2] - p[3 * a + 2];
              final e2x = p[3 * c] - p[3 * a], e2y = p[3 * c + 1] - p[3 * a + 1], e2z = p[3 * c + 2] - p[3 * a + 2];
              final gx = e1y * e2z - e1z * e2y, gy = e1z * e2x - e1x * e2z, gz = e1x * e2y - e1y * e2x;
              expect(gx * gx + gy * gy + gz * gz, greaterThan(0), reason: '$tag tam giác suy biến');
            }
            // Hộp bao khớp với đỉnh (hộp tính bằng double, đỉnh lưu float32).
            for (var v = 0; v < me.vertexCount; v++) {
              expect(me.positions[3 * v], inInclusiveRange(me.minX - 1e-5, me.maxX + 1e-5), reason: tag);
              expect(me.positions[3 * v + 1], inInclusiveRange(me.minY - 1e-5, me.maxY + 1e-5), reason: tag);
              expect(me.positions[3 * v + 2], inInclusiveRange(me.minZ - 1e-5, me.maxZ + 1e-5), reason: tag);
            }
            expect(me.maxX - me.minX, lessThan(1.1), reason: '$tag quá rộng');
            expect(me.maxZ - me.minZ, lessThan(1.1), reason: '$tag quá sâu');
          }
        },
      );

      test('${m.id}: số entity ≤ 8 (đủ thân, đầu, mắt, hai tay, hai chân) và tam giác trong giới hạn', () {
        for (final part in const [
          ChibiPart.body,
          ChibiPart.head,
          ChibiPart.eyes,
          ChibiPart.armL,
          ChibiPart.armR,
          ChibiPart.legL,
          ChibiPart.legR,
        ]) {
          expect(m.meshes.containsKey(part), isTrue, reason: '${m.id} thiếu ${part.name}');
        }
        expect(m.entityCount, inInclusiveRange(7, 8));
        // Số tam giác phụ thuộc phân đoạn thích ứng của ChibiMeshBuilder (detail 1 → ~2,5k, detail 2 → ~7–10k).
        expect(m.triangleCount, inInclusiveRange(1800, 11500));
        expect(m.triangleCount, m.meshes.values.fold<int>(0, (s, e) => s + e.triangleCount));
      });

      test('${m.id}: bộ phận phụ khớp với extraKind', () {
        expect(m.meshes.containsKey(ChibiPart.extra), m.extraKind != ChibiExtraKind.none);
        if (m.extraKind == ChibiExtraKind.tail) {
          expect(m.rig.extraY, lessThan(m.rig.neckY), reason: 'đuôi gắn thân: khớp thấp hơn cổ');
        }
        if (m.extraKind == ChibiExtraKind.ears) {
          expect(m.rig.extraY, greaterThan(m.rig.neckY), reason: 'tai gắn đầu: khớp cao hơn cổ');
        }
      });

      test('${m.id}: tỉ lệ cute, khung xương và chân chạm sàn', () {
        const s = ChibiCharacters.scale;
        // Tính cả tai / mũ / đuôi dựng; thân ngắn, chân ngắn (đầu ~49% chiều cao tới đỉnh đầu).
        expect(m.height, inInclusiveRange(1.1, 1.7));
        final top = _headTop(m);
        expect(top, inInclusiveRange(1.1, 1.5), reason: 'đỉnh đầu');
        // Đầu 48–50% chiều cao (cho sai số mắt / tai / bờm: 45–54%).
        final headH = _headHeight(m);
        expect(headH / (m.rig.neckY + headH), inInclusiveRange(0.45, 0.54), reason: 'tỉ lệ đầu');
        expect(m.rig.neckY, greaterThan(m.rig.hipY));
        expect(m.rig.shoulderY, inInclusiveRange(m.rig.hipY, m.rig.neckY));
        expect(m.rig.hipY, inInclusiveRange(0.15 * s, 0.3 * s), reason: 'hông thấp (chân ngắn)');
        expect(m.rig.neckY - m.rig.hipY, lessThan(0.4 * s), reason: 'thân ngắn');
        // Đáy chân (toạ độ thế giới) sát sàn, giày không chìm; bàn chân to tròn.
        for (final part in const [ChibiPart.legL, ChibiPart.legR]) {
          final (_, py, _) = m.rig.pivotOf(part);
          final leg = m.meshes[part]!;
          expect(py + leg.minY, closeTo(0, 0.02), reason: '${m.id} ${part.name}');
          expect(leg.maxX - leg.minX, greaterThan(0.17), reason: '${m.id} ${part.name} bàn chân to');
        }
        // Tay mập tới hông, hơi dang: đáy bàn tay ngang tầm hông, bàn tay lệch ra ngoài vai.
        for (final part in const [ChibiPart.armL, ChibiPart.armR]) {
          final (_, py, _) = m.rig.pivotOf(part);
          final arm = m.meshes[part]!;
          expect(py + arm.minY, lessThanOrEqualTo(m.rig.hipY + 0.12 * s), reason: '${m.id} ${part.name} tay tới hông');
          expect(arm.maxX - arm.minX, greaterThan(0.15), reason: '${m.id} ${part.name} tay mập');
        }
        // Mắt nằm trong khoảng đầu và nhô ra trước; đường chớp mắt cắt ngang lưới mắt; hai mắt to, gần nhau.
        final eyes = m.meshes[ChibiPart.eyes]!;
        expect(m.rig.eyeY, inInclusiveRange(m.rig.neckY, top));
        expect(m.rig.eyeZ, greaterThan(0.1));
        expect(eyes.minY, lessThan(0));
        expect(eyes.maxY, greaterThan(0));
        expect(
          eyes.maxX - eyes.minX,
          inInclusiveRange(0.33, 0.45),
          reason: '${m.id} mắt to, cách nhau ~1,1 bề rộng mắt',
        );
        expect(m.radius, inInclusiveRange(0.25 * s, 0.35 * s));
        expect(m.gait.speed, inInclusiveRange(0.5, 1.0));
      });

      test('${m.id}: màu sáng pastel — gần như không có đỉnh đen / tối thui', () {
        var dark = 0, total = 0;
        for (final me in m.meshes.values) {
          for (var v = 0; v < me.vertexCount; v++) {
            final mx = math.max(me.colors[4 * v], math.max(me.colors[4 * v + 1], me.colors[4 * v + 2]));
            if (mx < 0.03) dark++;
            total++;
          }
        }
        // Chỉ mắt (+ chút miệng) mới sẫm; không quần áo / lông đen thuần.
        expect(dark / total, lessThan(0.1), reason: m.id);
      });

      test('${m.id}: màu đa dạng — có ít nhất 5 màu khác nhau, không NaN', () {
        final colors = <int>{};
        for (final me in m.meshes.values) {
          for (var v = 0; v < me.vertexCount; v++) {
            final r = me.colors[4 * v], g = me.colors[4 * v + 1], b = me.colors[4 * v + 2];
            expect(r.isNaN || g.isNaN || b.isNaN, isFalse);
            colors.add(((r * 31).round() << 10) | ((g * 31).round() << 5) | (b * 31).round());
          }
        }
        expect(colors.length, greaterThanOrEqualTo(5), reason: m.id);
      });
    }
  });

  group('ChibiRegulars: so với nhau và với mẫu', () {
    test('chiều cao đỉnh đầu (tai / mũ) khác nhau giữa các con', () {
      final tops = {for (final m in models) m.id: _headTop(m)};
      expect(tops.values.map((t) => (t * 100).round()).toSet().length, greaterThanOrEqualTo(8));
    });

    test('đầu to, thân vừa — cùng tỉ lệ cho cả 15 con (kích thước loài do nơi gọi áp thêm)', () {
      for (final m in models) {
        final h = m.meshes[ChibiPart.head]!;
        // Chiều ngang đầu (kể cả tai / mũ vành rộng) không quá nhỏ / quá to.
        expect(h.maxX - h.minX, inInclusiveRange(0.5, 1.0), reason: m.id);
        // Thân (ellipsoid bụng tròn): vai rộng ~0,4–0,5 m sau scale.
        final b = m.meshes[ChibiPart.body]!;
        expect(b.maxX - b.minX, inInclusiveRange(0.35, 0.8), reason: m.id);
      }
    });

    test('mỗi con có màu trung bình khác nhau (không trùng bóng dáng màu với nhau)', () {
      final means = [for (final m in models) _meanColor(m)];
      for (var i = 0; i < means.length; i++) {
        for (var j = i + 1; j < means.length; j++) {
          final d = math.sqrt(
            [for (var c = 0; c < 3; c++) math.pow(means[i][c] - means[j][c], 2)].reduce((a, b) => a + b),
          );
          expect(d, greaterThan(0.004), reason: '${_ids[i]} vs ${_ids[j]}');
        }
      }
    });

    test('số tam giác khác nhau giữa các con (mỗi con dựng riêng, không dùng chung một khuôn)', () {
      expect(models.map((m) => m.triangleCount).toSet().length, greaterThanOrEqualTo(13));
    });
  });
}
