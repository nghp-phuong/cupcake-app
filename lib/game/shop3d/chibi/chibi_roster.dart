import 'dart:math' as math;

import '../shop3d_layout.dart';
import 'chibi_actor.dart';
import 'chibi_characters.dart';
import 'chibi_rig.dart';
import 'chibi_sizes.dart';

/// Danh sách đăng ký nhân vật chibi + màn xếp hàng (lineup) để duyệt nhân vật — Dart thuần.
///
/// [ChibiRoster] gom mọi nhân vật theo nhóm (đội tiệm, VIP, khách quen, khách thường). Nhân vật dựng sẵn trong
/// `chibi_characters.dart` có ở [ChibiRoster.builtIn]; thư viện khác (ví dụ 15 khách thường) đăng ký thêm qua
/// **chỗ nối [ChibiRoster.register]** (danh sách [ChibiRoster.extra]) trước khi dựng cảnh — file này không import
/// thư viện đó. [ChibiLineup] xếp các nhân vật đã chọn thành hàng trên sàn, mặt hướng camera, đứng thở / chớp mắt,
/// thỉnh thoảng vẫy tay / nhảy vui (mèo: ngồi, liếm chân).

/// Một nhân vật đăng ký: id, nhóm, hàm dựng.
class ChibiRosterEntry {
  const ChibiRosterEntry(this.id, this.group, this.build);

  final String id;

  /// Nhóm ([ChibiRoster.staff], [ChibiRoster.vip], [ChibiRoster.friends], [ChibiRoster.regulars] hoặc tên khác).
  final String group;
  final ChibiModel Function() build;
}

abstract final class ChibiRoster {
  static const staff = 'staff';
  static const vip = 'vip';
  static const friends = 'friends';
  static const regulars = 'regulars';

  /// Bộ lọc "tất cả" của [select].
  static const all = 'all';

  /// Nhân vật dựng sẵn: đội tiệm, VIP, khách quen.
  static final List<ChibiRosterEntry> builtIn = List.unmodifiable([
    for (final id in ChibiCharacters.staffIds) ChibiRosterEntry(id, staff, () => ChibiCharacters.build(id)),
    for (final id in ChibiCharacters.vipIds) ChibiRosterEntry(id, vip, () => ChibiCharacters.build(id)),
    for (final id in ChibiCharacters.friendIds) ChibiRosterEntry(id, friends, () => ChibiCharacters.build(id)),
  ]);

  /// CHỖ NỐI: nhân vật đăng ký thêm từ thư viện khác (ví dụ khách thường, nhóm [regulars]). Thêm bằng [register].
  static final List<ChibiRosterEntry> extra = [];

  /// Đăng ký thêm nhân vật (trùng id với mục đã có thì thay mục cũ). Gọi trước khi dựng cảnh / màn xếp hàng.
  static void register(Iterable<ChibiRosterEntry> entries) {
    for (final e in entries) {
      extra.removeWhere((x) => x.id == e.id);
      extra.add(e);
    }
  }

  /// Mọi nhân vật (dựng sẵn trước, đăng ký thêm sau; mục đăng ký trùng id thay mục dựng sẵn).
  static List<ChibiRosterEntry> get entries {
    final ids = {for (final e in extra) e.id};
    return [
      for (final e in builtIn)
        if (!ids.contains(e.id)) e,
      ...extra,
    ];
  }

  /// Mục có id [id]; null nếu không có.
  static ChibiRosterEntry? byId(String id) {
    for (final e in entries.reversed) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Chọn nhân vật theo [filter]: null / rỗng / `1` / `all` = tất cả; còn lại là danh sách tên nhóm hoặc id, cách nhau
  /// bởi `|` hoặc `,` (ví dụ `staff`, `vip|friends`, `mochi`, `kenji,vip_00`). Giữ thứ tự của danh sách đăng ký, không
  /// lặp.
  static List<ChibiRosterEntry> select(String? filter) {
    final f = filter?.trim() ?? '';
    final list = entries;
    if (f.isEmpty || f == '1' || f == all) return list;
    final keys = {
      for (final k in f.split(RegExp(r'[|,]')))
        if (k.trim().isNotEmpty) k.trim(),
    };
    return [
      for (final e in list)
        if (keys.contains(e.group) || keys.contains(e.id)) e,
    ];
  }
}

/// Vị trí camera gợi ý cho màn xếp hàng: điểm nhìn ([x], [y], [z]), khoảng cách, góc nghiêng (rad), yaw = 0 (nhìn
/// từ phía +z, cùng hướng mặt nhân vật).
typedef ChibiLineupCamera = ({double x, double y, double z, double distance, double pitch});

/// Màn xếp hàng: các nhân vật đứng thành hàng trên sàn khu khách (bỏ bàn ghế cho sàn trống), mặt hướng +z. Nhân vật
/// được đưa về kích thước trong cảnh ([ChibiSizes.fit]) — thú nhỏ hơn Mai.
abstract final class ChibiLineup {
  /// Khoảng cách giữa hai nhân vật trong một hàng (m) — vừa hai đầu thú to (đầu ~0,55 m) cạnh nhau.
  static const double spacing = 0.72;

  /// Tối đa số nhân vật một hàng (10 × 0,72 m ≈ 6,5 m + lệch nửa ô, vừa phòng 10 m, tránh ổ mèo và chậu cây).
  static const int maxPerRow = 10;

  /// Khoảng cách giữa hai hàng (m): 3 hàng [rowGap], 2 hàng [twoRowGap]; hàng sau lệch nửa ô để mặt không bị đầu hàng
  /// trước che. Nhiều hàng hơn thì dồn lại trong [depthMax].
  static const double rowGap = 1.45;
  static const double twoRowGap = 1.5;
  static const double depthMax = 2.9;

  /// Tâm khối xếp hàng trên sàn (giữa khu khách, sau bục trước quầy; lệch trái một chút để tránh ổ mèo sát tường phải).
  static const double centerX = -0.2;
  static const double centerZ = 2.15;

  static double _gap(int rows) => switch (rows) {
        <= 1 => rowGap,
        2 => twoRowGap,
        _ => math.min(rowGap, depthMax / (rows - 1)),
      };

  /// Số hàng và số người mỗi hàng cho [count] nhân vật (chia đều).
  static (int rows, int perRow) grid(int count) {
    if (count <= 0) return (0, 0);
    final rows = (count + maxPerRow - 1) ~/ maxPerRow;
    return (rows, (count + rows - 1) ~/ rows);
  }

  /// Vị trí (x, z) của người thứ [i] trong [count] người. Hàng 0 ở sau cùng (gần tủ kính), hàng cuối gần camera.
  static (double, double) slot(int i, int count) {
    final (rows, perRow) = grid(count);
    final r = i ~/ perRow;
    final inRow = r == rows - 1 ? count - r * perRow : perRow;
    final c = i - r * perRow;
    final stagger = rows > 1 && r.isOdd ? -spacing / 2 : 0.0;
    final x = centerX + (c - (inRow - 1) / 2) * spacing + stagger;
    final z = centerZ + (r - (rows - 1) / 2) * _gap(rows);
    return (x, z);
  }

  /// Kịch bản tại chỗ (không đi lại), mặt hướng camera: người — đứng thở / chớp mắt, thỉnh thoảng vẫy tay, nhảy vui;
  /// thú bốn chân — ngồi (tự liếm chân), đứng dậy, vẫy chân, liếm chân.
  static List<ChibiStep> idleLoop(ChibiModel model) => model.rig.quadruped
      ? const [
          ChibiStep.act(ChibiAction.rest, 6, jitter: 3, faceYaw: 0),
          ChibiStep.act(ChibiAction.stand, 2.5, jitter: 1.5, faceYaw: 0),
          ChibiStep.act(ChibiAction.wave, 2.2, faceYaw: 0),
          ChibiStep.act(ChibiAction.groom, 3, jitter: 1, faceYaw: 0),
        ]
      : const [
          ChibiStep.act(ChibiAction.stand, 6, jitter: 5, faceYaw: 0),
          ChibiStep.act(ChibiAction.wave, 1.6, faceYaw: 0),
          ChibiStep.act(ChibiAction.stand, 5, jitter: 4, faceYaw: 0),
          ChibiStep.act(ChibiAction.happy, 1.3, faceYaw: 0),
        ];

  /// Dựng các nhân vật [entries] thành hàng (đưa về kích thước trong cảnh). [models]: model dựng sẵn theo id (dùng
  /// lại, khỏi dựng lại).
  static List<ChibiActor> build(List<ChibiRosterEntry> entries, {Map<String, ChibiModel>? models}) {
    final n = entries.length;
    return [
      for (var i = 0; i < n; i++)
        () {
          final e = entries[i];
          final m = ChibiSizes.fit(models?[e.id] ?? e.build());
          final (x, z) = slot(i, n);
          return ChibiActor(m, idleLoop(m),
              x: x, z: z, yaw: 0, seed: 101 + i * 17, startStep: i % 2 == 0 ? 0 : 2, floor: Shop3dLayout.floorHeightAt);
        }(),
    ];
  }

  /// Lề thêm (m, tổng hai bên) của khung camera — chừa chỗ cột nút debug ~80 px ở mép phải.
  static const double sideMargin = 0.9;

  /// Camera nhìn trọn [count] nhân vật (khung 16:9, góc dọc [fovDeg]); một nhân vật thấp (mèo) thì nhìn cận.
  static ChibiLineupCamera camera(int count, {double fovDeg = 40, double aspect = 16 / 9, bool small = false}) {
    if (count <= 0) return (x: centerX, y: 0.6, z: centerZ, distance: 6, pitch: 0.4);
    final (rows, perRow) = grid(count);
    final (_, zBack) = slot(0, count);
    final (_, zFront) = slot(count - 1, count);
    final zc = (zBack + zFront) / 2;
    if (count == 1) {
      return small
          ? (x: slot(0, 1).$1, y: 0.18, z: zc, distance: 1.2, pitch: 0.34)
          : (x: slot(0, 1).$1, y: 0.6, z: zc, distance: 2.1, pitch: 0.3);
    }
    final halfH = math.tan(fovDeg * math.pi / 360);
    final halfW = halfH * aspect;
    // Lề hai bên rộng (+ [sideMargin]) để cột nút debug góc phải không che nhân vật ngoài cùng.
    final width = (perRow - 1) * spacing + (rows > 1 ? spacing / 2 : 0) + 0.9 + sideMargin;
    final depth = (rows - 1) * _gap(rows);
    final dist = math.max(width / 2 / halfW, 1.4 / halfH / 2) + depth * 0.6;
    // Nhiều hàng: nhìn dốc hơn để chân hàng sau (và nhãn id dưới chân) không bị đầu hàng trước che.
    return (x: centerX, y: rows > 1 ? 0.5 : 0.42, z: zc, distance: dist, pitch: rows > 1 ? 0.82 : 0.3);
  }
}
