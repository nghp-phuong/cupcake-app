import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/orbit_camera.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_actors.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Ảnh thử [w]×[h]: trong suốt, trừ hình chữ nhật [l,t,r,b) màu [rgb] alpha [a].
Shop3dRgbaImage _img(int w, int h, int l, int t, int r, int b, {List<int> rgb = const [200, 100, 50], int a = 255}) {
  final p = Uint8List(w * h * 4);
  for (var y = t; y < b; y++) {
    for (var x = l; x < r; x++) {
      final i = (y * w + x) * 4;
      p
        ..[i] = rgb[0]
        ..[i + 1] = rgb[1]
        ..[i + 2] = rgb[2]
        ..[i + 3] = a;
    }
  }
  return Shop3dRgbaImage(w, h, p);
}

void main() {
  group('Shop3dActors', () {
    test('ảnh mọi nhân vật mẫu có trong assets/characters', () {
      for (final a in Shop3dActors.all) {
        expect(File(a.assetPath).existsSync(), isTrue, reason: a.assetPath);
      }
    });

    test('id duy nhất; ~5 khách đứng + 2 khách bên bàn (cafe_tables) + 2 nhân viên', () {
      expect(Shop3dActors.all.map((a) => a.id).toSet().length, Shop3dActors.all.length);
      final base = Shop3dActors.actorsFor(const {});
      expect(base.where((a) => a.role == Shop3dActorRole.customer).length, 5);
      expect(base.where((a) => a.role == Shop3dActorRole.staff).length, 2);
      final withTables = Shop3dActors.actorsFor(const {Shop3dRequires.cafeTables});
      expect(withTables.length, base.length + 2);
      expect(Shop3dActors.actorsFor(Shop3dRequires.all).length, Shop3dActors.all.length);
    });

    test('nhân vật đứng trong phòng, không chồng lên vật thể (bề ngang ~0,55 m)', () {
      const half = 0.27;
      final room = Shop3dLayout.room;
      for (final a in Shop3dActors.all) {
        expect(a.x - half, greaterThan(room.minX), reason: a.id);
        expect(a.x + half, lessThan(room.maxX), reason: a.id);
        expect(a.z - half, greaterThan(room.minZ), reason: a.id);
        expect(a.z + half, lessThan(room.maxZ), reason: a.id);
        for (final prop in Shop3dLayout.propsFor(Shop3dRequires.all)) {
          if (prop.flat) continue;
          for (final part in prop.parts) {
            if (part.minY > Shop3dLayout.personHeight) continue; // đèn thả trên đầu
            // Tấm billboard xoay theo camera: coi người là hình vuông nửa cạnh [half] quanh chân.
            final overlap =
                a.x + half > part.minX && a.x - half < part.maxX && a.z + half > part.minZ && a.z - half < part.maxZ;
            expect(overlap, isFalse, reason: '${a.id} vs ${prop.id}');
          }
        }
      }
      // Hai nhân vật cách nhau đủ để tấm billboard không cắt nhau ở mọi góc xoay.
      final all = Shop3dActors.all;
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final d = math.sqrt(math.pow(all[i].x - all[j].x, 2) + math.pow(all[i].z - all[j].z, 2));
          expect(d, greaterThan(2 * half), reason: '${all[i].id} - ${all[j].id}');
        }
      }
    });

    test('billboardYaw = yaw của camera quỹ đạo; mặt tấm hướng về camera', () {
      final c = OrbitCameraController();
      for (final yaw in [-3.0, -1.2, 0.0, 0.4, 2.0, 3.1]) {
        c.setView(yaw: yaw);
        final y = Shop3dActors.billboardYaw(c.eye, c.target);
        expect(math.cos(y - c.yaw), closeTo(1, 1e-9));
        // pháp tuyến (sin y, 0, cos y) cùng hướng với (eye − target) trên mặt ngang
        final dx = c.eye.x - c.target.x, dz = c.eye.z - c.target.z;
        expect(math.sin(y) * dx + math.cos(y) * dz, greaterThan(0));
      }
    });

    test('tỉ lệ: thân người 561 px = 1,6 m (cao gấp ~1,7 quầy 0,95 m)', () {
      final img = _img(10, 561, 0, 0, 10, 561);
      expect(img.heightMeters(), closeTo(Shop3dLayout.personHeight, 1e-9));
      expect(img.heightMeters() / 0.95, greaterThan(1.6));
    });
  });

  group('Shop3dSprite', () {
    test('alphaBounds bỏ điểm mờ dưới ngưỡng; ảnh trống → null', () {
      final img = _img(20, 30, 4, 5, 12, 25);
      // vệt bóng mờ dưới chân
      img.pixels[(28 * 20 + 8) * 4 + 3] = 10;
      final b = Shop3dSprite.alphaBounds(img)!;
      expect([b.left, b.top, b.right, b.bottom], [4, 5, 12, 25]);
      expect(Shop3dSprite.alphaBounds(_img(4, 4, 0, 0, 0, 0)), isNull);
    });

    test('crop: nới viền trên / trái / phải, đáy giữ nguyên (chân chạm sàn)', () {
      final img = _img(20, 30, 4, 5, 12, 25);
      final c = Shop3dSprite.crop(img, Shop3dSprite.alphaBounds(img)!, pad: 2);
      expect(c.width, 8 + 4);
      expect(c.height, 20 + 2);
      // hàng cuối của ảnh cắt là hàng cuối có alpha
      final last = (c.height - 1) * c.width * 4;
      expect(c.pixels[last + 2 * 4 + 3], 255);
      // điểm góc trên-trái là phần nới (trong suốt)
      expect(c.pixels[3], 0);
    });

    test('bleedEdges: điểm trong suốt kề bên lấy màu, alpha vẫn 0', () {
      final img = _img(5, 1, 2, 0, 3, 1, rgb: const [10, 20, 30]);
      Shop3dSprite.bleedEdges(img, passes: 1);
      expect(img.pixels.sublist(4, 8), [10, 20, 30, 0]); // x = 1
      expect(img.pixels.sublist(12, 16), [10, 20, 30, 0]); // x = 3
      expect(img.pixels.sublist(0, 4), [0, 0, 0, 0]); // x = 0: cách 2 điểm, 1 vòng chưa tới
    });

    test('unpremultiply', () {
      final p = Uint8List.fromList([50, 100, 0, 128, 7, 7, 7, 0, 1, 2, 3, 255]);
      Shop3dSprite.unpremultiply(p);
      expect(p.sublist(0, 4), [100, 199, 0, 128]);
      expect(p.sublist(4), [7, 7, 7, 0, 1, 2, 3, 255]);
    });

    test('mipChain: đủ mức tới 1×1, kích thước đúng, màu không lẫn điểm trong suốt', () {
      final img = _img(13, 6, 0, 0, 1, 6, rgb: const [240, 10, 10]);
      final mips = Shop3dSprite.mipChain(img);
      expect(mips.length, Shop3dSprite.mipLevelCount(13, 6));
      expect(mips.length, 4);
      expect([for (final m in mips) (m.width, m.height)], [(13, 6), (6, 3), (3, 1), (1, 1)]);
      // mức 1, ô (0,0) gồm 2 điểm đỏ + 2 điểm trong suốt (màu đen): màu vẫn đỏ, alpha ~½
      final l1 = mips[1].pixels;
      expect(l1.sublist(0, 3), [240, 10, 10]);
      expect(l1[3], closeTo(128, 1));
      expect(Shop3dSprite.mipChain(img, maxLevels: 2).length, 2);
    });

    test('prepare: cắt + loang trên ảnh thật 480×640 → khung gần với vùng nhân vật', () {
      final img = _img(480, 640, 152, 46, 333, 604);
      final out = Shop3dSprite.prepare(img)!;
      expect(out.width, 333 - 152 + 4);
      expect(out.height, 604 - 46 + 2);
      expect(out.heightMeters(), closeTo(1.6, 0.02));
    });
  });
}
