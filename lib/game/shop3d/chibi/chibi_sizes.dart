import 'dart:math' as math;

import 'chibi_mesh.dart';
import 'chibi_rig.dart';

/// Kích thước nhân vật chibi trong cảnh so với chủ tiệm Mai — Dart thuần (docs/v3/character-cute-review.md, mục B).
///
/// Mọi nhân vật (dựng sẵn và 15 khách thường) được dựng ở kích thước gốc (~Mai), rồi [ChibiSizes.fit] đưa về chiều cao
/// trong cảnh theo bảng [ChibiSizes.table]: **thú nhỏ hơn người**, nhưng đầu thú vẫn giữ ~0,38–0,42 chiều cao Mai để mặt
/// đọc được. Cách làm: phóng **phần dưới** (thân + tay + chân + đồ cầm tay, mọi thứ dưới khớp cổ) và **phần đầu** (đầu,
/// mắt, tai / đuôi tóc) bằng hai hệ số khác nhau — đầu thu ít, thân thu nhiều — rồi nới thân / tay / chân theo bề ngang
/// (dáng "quả trứng" mập, không như que tăm dưới cái đầu to). Khung xương dời theo, nên chuyển động, ngồi ghế, cầm đồ
/// vẫn khớp. Thú bốn chân (mèo Mochi): phóng đều theo chiều cao khi ngồi.
///
/// Số đo trong bảng tính tới **đỉnh sọ** (không tai, không mũ, không búi / gạc); tai dài (thỏ, cáo, corgi, mèo) cộng
/// thêm trên đó — các hệ số đã chọn sao cho chiều cao cả tai rơi vào khoảng của bảng B.

/// Kích thước một nhân vật so với Mai: [height] = đỉnh sọ, [head] = chiều cao đầu (cằm → đỉnh sọ). Mèo bốn chân:
/// [height] = chiều cao khi ngồi (gồm tai), [head] bỏ qua.
class ChibiSize {
  const ChibiSize(this.height, this.head);

  final double height, head;
}

abstract final class ChibiSizes {
  /// Đỉnh sọ của Mai (m). Có tóc / khăn bandana → ~1,29 m.
  static const double maiHeight = 1.24;

  /// Tâm mắt ở ~0,47 chiều cao đầu tính từ cằm (quy chuẩn A2: 0,50–0,55 tính từ đỉnh) → ước đỉnh sọ khi nhân vật
  /// không khai `ChibiRigSpec.crownY`.
  static const double eyeFromChin = 0.47;

  /// Nới ngang thân / tay / chân tối đa khi đầu thu ít hơn thân.
  static const double maxWiden = 1.28;

  /// Mặc định cho id chưa có trong bảng (thú vừa).
  static const ChibiSize fallback = ChibiSize(0.68, 0.40);

  // Nhóm (đỉnh sọ, đầu) so với Mai.
  static const _mai = ChibiSize(1.0, 0.5);
  static const _large = ChibiSize(0.80, 0.42);
  static const _mediumTallEars = ChibiSize(0.64, 0.39);
  static const _medium = ChibiSize(0.69, 0.40);
  static const _star = ChibiSize(0.71, 0.41);

  /// Bảng B: mọi id dựng sẵn + 15 khách thường. Thú lớn 0,80–0,85, thú vừa 0,70–0,75, thú nhỏ 0,60–0,65 (hamster
  /// 0,55–0,60), Linh thân 0,60 (cả tai ~0,75), Mochi ~0,25 khi ngồi; Linh / Hòa / Rosa ≥ 0,75 tính cả tai / búi.
  static const Map<String, ChibiSize> table = {
    'mai': _mai,
    // Thú lớn.
    'staff_bao': _large,
    'staff_bao_fest': _large,
    'vip_01': ChibiSize(0.74, 0.41), // + gạc ngắn → ~0,85
    'regular_09': _large,
    'regular_12': _large,
    'regular_13': _large,
    'regular_14': ChibiSize(0.78, 0.42), // + bờm mây → ~0,85
    // Thú vừa, tai nhọn cao (cáo, corgi, mèo, shiba): đỉnh sọ thấp hơn để cả tai ~0,75.
    'staff_nora': _mediumTallEars,
    'staff_nora_fest': _mediumTallEars,
    'staff_theo': ChibiSize(0.62, 0.39),
    'staff_hanh': _mediumTallEars,
    'regular_00': _mediumTallEars,
    'regular_05': _mediumTallEars,
    'regular_06': _mediumTallEars,
    'regular_08': _mediumTallEars,
    // Thú vừa, tai tròn / cụp.
    'staff_ami': _medium,
    'kenji': ChibiSize(0.67, 0.40),
    'vip_02': _medium,
    'regular_02': _medium,
    'regular_07': _medium,
    'regular_10': _medium,
    'regular_11': _medium,
    // Nhân vật nổi bật: không dưới 0,75 tính cả tai / búi.
    'hoa': _star,
    'vip_00': ChibiSize(0.70, 0.41),
    'linh': ChibiSize(0.60, 0.39),
    // Thú nhỏ.
    'regular_03': ChibiSize(0.61, 0.38),
    'regular_04': ChibiSize(0.58, 0.37),
    'regular_01': ChibiSize(0.56, 0.37),
    // Mèo bốn chân: chiều cao khi ngồi (gồm tai).
    'mochi': ChibiSize(0.25, 0),
  };

  /// Kích thước của [id] (id lạ → [fallback]).
  static ChibiSize of(String id) => table[id] ?? fallback;

  /// Đỉnh sọ ở tư thế nghỉ của [m] (khai báo hoặc ước theo mắt).
  static double crownOf(ChibiModel m) {
    final r = m.rig;
    return r.crownY ?? r.neckY + (r.eyeY - r.neckY) / eyeFromChin;
  }

  /// Đưa [m] về kích thước trong cảnh theo [of] (đã đưa rồi thì trả nguyên).
  static ChibiModel fit(ChibiModel m) {
    if (m.fitted) return m;
    final size = of(m.id);
    if (m.rig.quadruped) {
      final s = size.height * maiHeight / sittingHeight(m);
      return _rebuild(m, lower: s, head: s, widen: 1, gait: _gait(m.gait, s, 1));
    }
    final r = m.rig;
    final skull = crownOf(m) - r.neckY;
    final sH = size.head * maiHeight / skull;
    final sLo = (size.height - size.head) * maiHeight / r.neckY;
    final widen = math.sqrt(sH / sLo).clamp(1.0, maxWiden);
    return _rebuild(m, lower: sLo, head: sH, widen: widen, gait: _gait(m.gait, sLo, sH / sLo));
  }

  /// Chiều cao khi ngồi (thú bốn chân): đỉnh cao nhất của lưới ở tư thế ngồi trên hai chân sau (thân ngả
  /// [quadSitAngle], hông hạ để chân trước vẫn chạm sàn, đầu ngẩng bù — như `ChibiActor`). Người: [ChibiModel.height].
  static double sittingHeight(ChibiModel m) {
    final s = m.rig;
    if (!s.quadruped) return m.height;
    final a = quadSitAngle;
    final l = s.shoulderZ - s.hindZ, hh = s.shoulderY - s.hipY;
    final pose = ChibiPose()
      ..lean = -a
      ..bob = -(l * math.sin(a) + hh * (math.cos(a) - 1))
      ..headNod = a * 0.92 - 0.05;
    final rig = ChibiRig(s)..compute(pose);
    var top = 0.0;
    for (final e in m.meshes.entries) {
      final w = rig[e.key];
      final p = e.value.positions;
      for (var k = 0; k < p.length; k += 3) {
        final (_, y, _) = ChibiM4.transformPoint(w, p[k], p[k + 1], p[k + 2]);
        if (y > top) top = y;
      }
    }
    return top;
  }

  /// Góc ngả thân khi mèo ngồi (khớp `ChibiActor.quadSitAngle`).
  static const double quadSitAngle = 0.78;

  /// Dáng đi theo chân mới: bước ngắn lại theo [lower] (nhịp nhanh hơn), tốc độ giảm ít, lạch bạch và nhún nhiều hơn
  /// một chút; đầu to hơn vai ([boost] > 1) thì giơ tay thấp hơn khi vui / vẫy.
  static ChibiGait _gait(ChibiGait g, double lower, double boost) {
    final k = lower.clamp(0.2, 1.5);
    final short = (1 - k).clamp(0.0, 1.0);
    return ChibiGait(
      speed: g.speed * math.pow(k, 0.3).toDouble(),
      legSwing: g.legSwing * (1 + 0.15 * short),
      armSwing: g.armSwing * (1 + 0.2 * short),
      stride: g.stride * math.pow(k, 0.85).toDouble(),
      waddle: g.waddle * (1 + 0.8 * short),
      bob: g.bob * k,
      lean: g.lean,
      cane: g.cane,
      armUp: boost <= 1.05 ? g.armUp : math.min(g.armUp ?? 2.55, 2.55 - (boost - 1.05) * 1.4).clamp(1.85, 2.55),
    );
  }

  static ChibiModel _rebuild(
    ChibiModel m, {
    required double lower,
    required double head,
    required double widen,
    required ChibiGait gait,
  }) {
    final r = m.rig;
    final lw = lower * widen;
    final tail = m.extraKind == ChibiExtraKind.tail;
    final meshes = <ChibiPart, ChibiMesh>{
      for (final e in m.meshes.entries)
        e.key: switch (e.key) {
          ChibiPart.head || ChibiPart.eyes => e.value.scaled(head, head, head),
          ChibiPart.extra when !tail => e.value.scaled(head, head, head),
          _ => e.value.scaled(lw, lower, lw),
        },
    };
    final neckY = r.neckY * lower, neckZ = r.neckZ * lw;
    final crown = crownOf(m);
    final hold = r.hold;
    final rig = ChibiRigSpec(
      hipY: r.hipY * lower,
      legX: r.legX * lw,
      neckY: neckY,
      shoulderX: r.shoulderX * lw,
      shoulderY: r.shoulderY * lower,
      eyeY: neckY + (r.eyeY - r.neckY) * head,
      eyeZ: neckZ + (r.eyeZ - r.neckZ) * head,
      extraX: r.extraX * (tail ? lw : head),
      extraY: tail ? r.extraY * lower : neckY + (r.extraY - r.neckY) * head,
      extraZ: tail ? r.extraZ * lw : neckZ + (r.extraZ - r.neckZ) * head,
      seatDrop: r.seatDrop * lower,
      neckZ: neckZ,
      hindZ: r.hindZ * lw,
      shoulderZ: r.shoulderZ * lw,
      quadruped: r.quadruped,
      hold: hold?.at(hold.x * lw, hold.y * lower, hold.z * lw),
      crownY: neckY + (crown - r.neckY) * head,
    );
    return ChibiModel(
        id: m.id, meshes: meshes, rig: rig, gait: gait, extraKind: m.extraKind, radius: m.radius * lw, fitted: true);
  }
}
