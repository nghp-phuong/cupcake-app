import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_mesh.dart';

/// Mọi tam giác ngược chiều kim đồng hồ nhìn từ phía pháp tuyến đỉnh (mặt trước của Filament), pháp tuyến đơn vị,
/// chỉ số hợp lệ.
void _expectWellFormed(Shop3dMesh m) {
  final p = m.positions, n = m.normals;
  expect(p.length, n.length);
  expect(m.indices.length % 3, 0);
  for (var v = 0; v < m.vertexCount; v++) {
    final l = math.sqrt(n[3 * v] * n[3 * v] + n[3 * v + 1] * n[3 * v + 1] + n[3 * v + 2] * n[3 * v + 2]);
    expect(l, closeTo(1, 1e-5), reason: 'normal $v');
  }
  for (var t = 0; t < m.indices.length; t += 3) {
    final a = m.indices[t], b = m.indices[t + 1], c = m.indices[t + 2];
    for (final i in [a, b, c]) {
      expect(i, lessThan(m.vertexCount));
    }
    final e1 = [for (var k = 0; k < 3; k++) p[3 * b + k] - p[3 * a + k]];
    final e2 = [for (var k = 0; k < 3; k++) p[3 * c + k] - p[3 * a + k]];
    final g = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
    var dot = 0.0;
    for (final i in [a, b, c]) {
      dot += g[0] * n[3 * i] + g[1] * n[3 * i + 1] + g[2] * n[3 * i + 2];
    }
    expect(dot, greaterThan(0), reason: 'triangle ${t ~/ 3} winding');
  }
}

void main() {
  group('Shop3dMeshBuilder', () {
    test('hộp: 24 đỉnh, 12 tam giác, đúng hộp bao, mặt hướng ra ngoài', () {
      final m = (Shop3dMeshBuilder()..addBox(1, 2, 3, 2, 4, 6)).build();
      expect(m.vertexCount, 24);
      expect(m.triangleCount, 12);
      expect([m.minX, m.minY, m.minZ, m.maxX, m.maxY, m.maxZ], [0, 0, 0, 2, 4, 6]);
      _expectWellFormed(m);
      // Pháp tuyến hướng ra: (đỉnh − tâm) · pháp tuyến > 0.
      for (var v = 0; v < m.vertexCount; v++) {
        final d = (m.positions[3 * v] - 1) * m.normals[3 * v] +
            (m.positions[3 * v + 1] - 2) * m.normals[3 * v + 1] +
            (m.positions[3 * v + 2] - 3) * m.normals[3 * v + 2];
        expect(d, greaterThan(0));
      }
    });

    test('hộp xoay: hộp bao khớp halfX / halfZ của Shop3dPart', () {
      const part = Shop3dPart.box(Shop3dColor.cream, 0, 0, 0, 2, 1, 1, rotY: math.pi / 6);
      final m = (Shop3dMeshBuilder()..addPart(part)).build();
      expect(m.minX, closeTo(part.minX, 1e-5));
      expect(m.maxX, closeTo(part.maxX, 1e-5));
      expect(m.minZ, closeTo(part.minZ, 1e-5));
      expect(m.maxZ, closeTo(part.maxZ, 1e-5));
      _expectWellFormed(m);
    });

    test('trụ: có nắp phẳng, hộp bao đúng, mặt hướng ra ngoài', () {
      const part = Shop3dPart.cyl(Shop3dColor.cream, 1, 0.5, -1, 0.9, 0.04);
      final m = (Shop3dMeshBuilder()..addPart(part)).build();
      expect(m.minY, closeTo(0.5, 1e-6));
      expect(m.maxY, closeTo(0.54, 1e-6));
      expect(m.maxX - m.minX, closeTo(0.9, 1e-5));
      _expectWellFormed(m);
      final segs = Shop3dMeshBuilder.cylinderSegments(0.9);
      // thân 2·segs + 2 nắp × segs tam giác
      expect(m.triangleCount, 4 * segs);
      // nắp trên: mọi đỉnh ở y max có tam giác pháp tuyến +y
      var up = 0;
      for (var v = 0; v < m.vertexCount; v++) {
        if (m.normals[3 * v + 1] > 0.99) up++;
      }
      expect(up, segs + 1);
    });

    test('nón cụt: bán kính đáy / đỉnh đúng, pháp tuyến thân nghiêng lên, đỉnh 0 = nón nhọn không nắp trên', () {
      const part = Shop3dPart.cone(Shop3dColor.butter, 0, 1, 0, 0.4, 0.1, 0.2);
      expect(part.sx, 0.4);
      expect(part.topScale, closeTo(0.25, 1e-12));
      final m = (Shop3dMeshBuilder()..addPart(part)).build();
      _expectWellFormed(m);
      expect(m.minX, closeTo(-0.2, 1e-6));
      expect(m.maxX, closeTo(0.2, 1e-6));
      expect(m.minY, closeTo(1, 1e-6));
      expect(m.maxY, closeTo(1.2, 1e-6));
      var topR = 0.0;
      for (var v = 0; v < m.vertexCount; v++) {
        if ((m.positions[3 * v + 1] - 1.2).abs() < 1e-6) {
          topR = math.max(topR, math.sqrt(math.pow(m.positions[3 * v], 2) + math.pow(m.positions[3 * v + 2], 2)));
        }
      }
      expect(topR, closeTo(0.05, 1e-6));
      // nón nhọn: không tam giác suy biến, ít tam giác hơn trụ cùng cỡ (bỏ nắp trên)
      final cone = (Shop3dMeshBuilder()..addCylinder(0, 0, 0, 0.4, 0.2, topScale: 0)).build();
      final cyl = (Shop3dMeshBuilder()..addCylinder(0, 0, 0, 0.4, 0.2)).build();
      _expectWellFormed(cone);
      expect(cone.triangleCount, lessThan(cyl.triangleCount));
    });

    test('lăng trụ: thang / tam giác (cờ đuôi nheo, mái dốc), hộp bao khớp Shop3dPart kể cả khi xoay', () {
      for (final part in const [
        Shop3dPart.prism(Shop3dColor.mint, 1, 2, 3, 0.4, 0.3, 0.1),
        Shop3dPart.prism(Shop3dColor.mint, 1, 2, 3, 0.4, 0.3, 0.1, bottomScale: 0),
        Shop3dPart.prism(Shop3dColor.mint, 1, 2, 3, 0.5, 0.2, 0.16, rotY: math.pi / 2, topScale: 0),
        Shop3dPart.prism(Shop3dColor.mint, 1, 2, 3, 0.4, 0.3, 0.1, rotY: 0.4, bottomScale: 0.6),
      ]) {
        final m = (Shop3dMeshBuilder()..addPart(part)).build();
        _expectWellFormed(m);
        expect(m.minY, closeTo(part.minY, 1e-6));
        expect(m.maxY, closeTo(part.maxY, 1e-6));
        expect(m.minX, greaterThanOrEqualTo(part.minX - 1e-6));
        expect(m.maxX, lessThanOrEqualTo(part.maxX + 1e-6));
        expect(m.minZ, greaterThanOrEqualTo(part.minZ - 1e-6));
        expect(m.maxZ, lessThanOrEqualTo(part.maxZ + 1e-6));
      }
      // tam giác: 2 mặt đầu × 1 + 3 mặt bên × 2
      final flag = (Shop3dMeshBuilder()..addPrism(0, 0, 0, 0.2, 0.25, 0.01, bottomScale: 0)).build();
      expect(flag.triangleCount, 8);
      expect(flag.minY, closeTo(-0.125, 1e-9));
    });

    test('diềm sóng: cạnh trên phẳng, cung xuống đúng độ sâu, mặt hướng ra ngoài', () {
      const part = Shop3dPart.scallop(Shop3dColor.strawberry, 0, 2.0, 4, 0.16, 0.07, 0.012);
      final m = (Shop3dMeshBuilder()..addPart(part)).build();
      _expectWellFormed(m);
      expect(m.maxY, closeTo(2.07, 1e-6));
      expect(m.minY, closeTo(2.0, 1e-6));
      expect(m.maxX - m.minX, closeTo(0.16, 1e-6));
    });

    test('cầu: bỏ tam giác suy biến ở cực, hộp bao ≈ đường kính', () {
      final m = (Shop3dMeshBuilder()..addSphere(0, 1, 0, 0.5)).build();
      final (lat, lon) = Shop3dMeshBuilder.sphereBands(0.5);
      expect(m.triangleCount, 2 * lat * lon - 2 * lon);
      expect(m.maxY - m.minY, closeTo(0.5, 1e-5));
      _expectWellFormed(m);
    });

    test('đĩa: pháp tuyến +y, tam giác nhìn từ trên là ngược chiều kim đồng hồ', () {
      final m = buildDisc(0, 0.03, 0, 0.6);
      _expectWellFormed(m);
      expect(m.minY, closeTo(0.03, 1e-6));
      expect(m.maxY, closeTo(0.03, 1e-6));
    });

    test('billboard: đáy y = 0, cao đúng, UV v = 0 ở mép trên', () {
      final (pos, nrm, uv, idx) = buildBillboardQuad(0.5, 1.6);
      expect(pos.length, 12);
      expect(idx, [0, 1, 2, 0, 2, 3]);
      for (var v = 0; v < 4; v++) {
        expect(nrm[3 * v + 2], 1);
        final y = pos[3 * v + 1];
        expect(uv[2 * v + 1], y == 0 ? 1 : 0);
      }
      expect(pos.reduce(math.max), closeTo(1.6, 1e-6));
    });
  });

  group('buildMeshesBySurface', () {
    test('mặt đục gộp theo độ nhám (màu ở màu đỉnh), trong suốt theo (màu, alpha); tổng tam giác bằng tổng từng khối', () {
      final parts = Shop3dLayout.props.firstWhere((p) => p.id == 'pastryCase').parts;
      final meshes = buildMeshesBySurface(parts);
      expect(meshes.keys.toSet(), {
        const Shop3dSurfaceKey.opaque(Shop3dSurface.matte),
        Shop3dSurfaceKey.of(Shop3dColor.glass.argb, Shop3dLayout.glassAlpha),
      });
      var tris = 0;
      for (final p in parts) {
        tris += (Shop3dMeshBuilder()..addPart(p)).build().triangleCount;
      }
      expect(meshes.values.fold<int>(0, (s, m) => s + m.triangleCount), tris);
      final glass = meshes.keys.singleWhere((k) => k.transparent);
      expect(glass.tint, const Shop3dMaterialKey(0xFFCFEFF2, Shop3dLayout.glassAlpha));
      expect(glass.surface.roughness, 0.15);
      for (final m in meshes.values) {
        _expectWellFormed(m);
      }
    });

    test('màu đỉnh: đúng màu tuyến tính + alpha của từng khối, theo đúng thứ tự đỉnh', () {
      const a = Shop3dPart.box(Shop3dColor.strawberry, 0, 0, 0, 1, 1, 1);
      const b = Shop3dPart.cyl(Shop3dColor.mint, 2, 0, 0, 0.5, 1);
      const c = Shop3dPart.ball(Shop3dColor.butter, 4, 0, 0, 0.3, alpha: 0.5);
      final na = (Shop3dMeshBuilder()..addPart(a)).build().vertexCount;
      final nb = (Shop3dMeshBuilder()..addPart(b)).build().vertexCount;
      final m = (Shop3dMeshBuilder()
            ..addPart(a)
            ..addPart(b)
            ..addPart(c))
          .build();
      expect(m.colors.length, m.vertexCount * 4);
      void expectColor(int v, Shop3dPart p) {
        final k = Shop3dMaterialKey.of(p);
        expect(m.colors[4 * v], closeTo(k.linearR, 1e-6));
        expect(m.colors[4 * v + 1], closeTo(k.linearG, 1e-6));
        expect(m.colors[4 * v + 2], closeTo(k.linearB, 1e-6));
        expect(m.colors[4 * v + 3], closeTo(p.alpha, 1e-6));
      }

      expectColor(0, a);
      expectColor(na - 1, a);
      expectColor(na, b);
      expectColor(na + nb - 1, b);
      expectColor(m.vertexCount - 1, c);
      // Không qua addPart (đĩa, hộp tự thêm): trắng.
      final disc = buildDisc(0, 0, 0, 1);
      expect(disc.colors.every((x) => x == 1), isTrue);
    });

    test('độ nhám giữ như khi mỗi màu một material', () {
      expect(Shop3dSurface.of(Shop3dColor.cream.argb, 1), Shop3dSurface.matte);
      expect(Shop3dSurface.of(Shop3dColor.steel.argb, 1), Shop3dSurface.steel);
      expect(Shop3dSurface.of(Shop3dColor.glass.argb, 0.3), Shop3dSurface.glass);
      expect(Shop3dSurface.of(Shop3dColor.butter.argb, 0.85), Shop3dSurface.clear);
      for (final c in Shop3dColor.backdrop) {
        expect(Shop3dSurface.of(c.argb, 1), Shop3dSurface.backdrop, reason: c.name);
      }
      expect(Shop3dSurface.backdrop.unlit, isTrue);
      expect(Shop3dSurface.matte.unlit, isFalse);
      expect(Shop3dSurface.matte.roughness, 0.85);
      expect(Shop3dSurface.steel.roughness, 0.45);
      expect(Shop3dSurface.clear.roughness, 0.3);
      expect(Shop3dSurfaceKey.of(Shop3dColor.cream.argb, 1), Shop3dSurfaceKey.of(Shop3dColor.mint.argb, 1));
      expect(Shop3dSurfaceKey.of(Shop3dColor.cream.argb, 0.7) == Shop3dSurfaceKey.of(Shop3dColor.mint.argb, 0.7),
          isFalse);
    });
  });

  test('Shop3dMaterialKey: màu tuyến tính', () {
    const k = Shop3dMaterialKey(0xFFFFFFFF, 1);
    expect(k.linearR, closeTo(1, 1e-9));
    const half = Shop3dMaterialKey(0xFF808080, 1);
    expect(half.linearG, closeTo(math.pow(128 / 255, 2.2), 1e-9));
    expect(const Shop3dMaterialKey(0xFF000000, 0.5).transparent, isTrue);
    expect(const Shop3dMaterialKey(1, 1), const Shop3dMaterialKey(1, 1));
  });
}
