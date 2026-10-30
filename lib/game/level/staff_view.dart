import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../core/staff/staff.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/game_paint.dart';
import 'level_characters.dart';
import 'level_layout.dart';
import 'shop_figure.dart';

/// Trạng thái một nhân viên mà cảnh tiệm vẽ, chép từ `LevelSession.staff` mỗi khung (đối tượng tái dùng) — test đưa
/// dữ liệu giả lập thẳng vào đây.
class StaffPose {
  StaffPose(this.member, {this.progress = 0, this.working, this.targetCustomer, this.actions = 0});

  StaffMember member;

  /// 0..1 tới lần làm tiếp (thợ bánh: tiến độ mẻ).
  double progress;

  /// Món thợ bánh đang làm (null = rảnh / tủ không còn chỗ).
  RecipeId? working;

  /// Khách thu ngân / phục vụ sắp bán (id khách).
  int? targetCustomer;
  int actions;
}

/// Vị trí (x, đáy khung, tỉ lệ) của một khách trong cảnh, null nếu khách đã rời cảnh.
typedef CustomerSpot = (double, double, double)? Function(int id);

class _StaffFigure extends ShopFigure {
  StaffRole role = StaffRole.cashier;
  String character = '';

  /// Thứ tự trong cùng vai trò (thợ bánh: làn).
  int lane = 0;

  double x = 0, floor = 0;
  bool placed = false;
  bool moving = false;
  double clock = 0;

  /// Còn cười chừng này giây (vừa bán / vừa xong mẻ).
  double smile = 0;

  double progress = 0;
  RecipeId? working;

  /// Ảnh thường (neutral, smile) rồi ảnh trang phục lễ hội (neutral, smile).
  final List<ui.Image?> images = List<ui.Image?>.filled(4, null);
  int imagesGen = -1;

  /// Trang phục lễ hội đang bật (GĐ6): dùng ảnh `<character>_fest_*` nếu có.
  bool festive = false;
  String festCharacter = '';

  int get expr => smile > 0 ? LevelCharacters.smile : LevelCharacters.neutral;

  @override
  ui.Image? get image {
    final gen = LevelCharacters.generation;
    if (imagesGen != gen) {
      imagesGen = gen;
      images[0] = LevelCharacters.cached(character, LevelCharacters.neutral);
      images[1] = LevelCharacters.cached(character, LevelCharacters.smile);
      images[2] = festive ? LevelCharacters.cached(festCharacter, LevelCharacters.neutral) : null;
      images[3] = festive ? LevelCharacters.cached(festCharacter, LevelCharacters.smile) : null;
      if (images[0] == null && !LevelCharacters.isMissing(character, LevelCharacters.neutral)) {
        LevelCharacters.preload([(character, LevelCharacters.neutral), (character, LevelCharacters.smile)], urgent: true);
      }
      if (festive && images[2] == null && !LevelCharacters.isMissing(festCharacter, LevelCharacters.neutral)) {
        LevelCharacters.preload([(festCharacter, LevelCharacters.neutral), (festCharacter, LevelCharacters.smile)], urgent: true);
      }
    }
    final s = expr == LevelCharacters.smile ? 1 : 0;
    // Trang phục lễ hội: có ảnh lễ hội (nét mặt nào cũng được) thì dùng bộ đó, không lẫn với ảnh thường. Thiếu nét
    // mặt này: dùng nét còn lại; thiếu cả hai → không vẽ hình (vòng tiến độ vẫn vẽ).
    if (festive) {
      final f = images[2 + s] ?? images[2] ?? images[3];
      if (f != null) return f;
    }
    return images[s] ?? images[0] ?? images[1];
  }

  /// Đầu (gốc hiệu ứng: xu bay, bánh bay).
  Offset get head => Offset(drawX, top + height * 0.16);

  /// Tâm vòng tiến độ trên đầu.
  Offset get ring => Offset(drawX, top - LevelLayout.staffRingLift);
}

/// Nhân viên đã thuê trong sân tiệm (GĐ4): thu ngân sau quầy cạnh máy tính tiền, thợ bánh góc sau bên trái (vòng
/// tiến độ + món đang làm trên đầu), phục vụ đi giữa chỗ đứng chờ (sau bàn phải) và khách được phục vụ. Quản lý không
/// xuất hiện trong màn.
///
/// Hình nhân viên xếp độ sâu chung với khách / bàn ghế / cây ([figures], vẽ ở `ShopView`); lớp này chỉ tính vị trí,
/// nét mặt và vẽ phần phủ ([paintOverlays]: vòng tiến độ). Không cấp phát mỗi khung (đối tượng hình tái dùng).
class StaffView {
  StaffView({required this.customerSpot});

  /// Tra vị trí khách (phục vụ đi tới khách).
  final CustomerSpot customerSpot;

  final List<_StaffFigure> _all = [];

  /// Hình đang vẽ (bỏ quản lý), theo thứ tự `session.staff`.
  final List<ShopFigure> figures = [];

  /// Chỉ số `session.staff` → hình (null = không vẽ: quản lý).
  final List<_StaffFigure?> _byIndex = [];

  /// Có thu ngân trong cảnh (bong bóng khách đặc biệt lật sang trái).
  bool hasCashier = false;

  final Map<RecipeId, CakeVisual> _visuals = {};

  int get count => figures.length;

  void reset() {
    _byIndex.clear();
    figures.clear();
    for (final f in _all) {
      f.placed = false;
    }
    hasCashier = false;
  }

  /// Id ảnh trang phục lễ hội của nhân vật [character] (`assets/characters/<character>_fest_<expr>.webp`).
  static String festCharacter(String character) => '${character}_fest';

  /// Như [spritesFor] nhưng ảnh trang phục lễ hội (thiếu file → coi là thiếu, nhân viên dùng ảnh thường).
  static List<(String, int)> festSpritesFor(Iterable<StaffMember> members) => [
        for (final (id, e) in spritesFor(members)) (festCharacter(id), e),
      ];

  /// Id ảnh nhân vật cần nạp cho [members] (bỏ quản lý), cả hai nét mặt.
  static List<(String, int)> spritesFor(Iterable<StaffMember> members) => [
        for (final m in members)
          if (m.role != StaffRole.manager) (m.character, LevelCharacters.neutral),
        for (final m in members)
          if (m.role != StaffRole.manager) (m.character, LevelCharacters.smile),
      ];

  _StaffFigure _figureAt(int k) {
    while (_all.length <= k) {
      _all.add(_StaffFigure());
    }
    return _all[k];
  }

  /// Đồng bộ với [poses] (thứ tự cố định của `session.staff`) và tính vị trí khung này. [festive]: trang phục lễ
  /// hội đang bật.
  void update(double dt, List<StaffPose> poses, {bool festive = false}) {
    _byIndex.length = poses.length;
    figures.clear();
    hasCashier = false;
    var cashiers = 0, bakers = 0, waiters = 0, used = 0;
    for (var i = 0; i < poses.length; i++) {
      final p = poses[i];
      final m = p.member;
      if (m.role == StaffRole.manager) {
        _byIndex[i] = null;
        continue;
      }
      final f = _figureAt(used++);
      if (f.character != m.character || f.role != m.role || !f.placed) {
        f
          ..character = m.character
          ..festCharacter = festCharacter(m.character)
          ..role = m.role
          ..imagesGen = -1
          ..placed = false
          ..smile = 0
          ..clock = 0;
        if (LevelCharacters.cached(m.character, LevelCharacters.neutral) == null) {
          LevelCharacters.preload([(m.character, LevelCharacters.neutral), (m.character, LevelCharacters.smile)], urgent: true);
        }
      }
      if (f.festive != festive) {
        f
          ..festive = festive
          ..imagesGen = -1;
      }
      f
        ..depthKey = -1 - i
        ..progress = p.progress.clamp(0.0, 1.0)
        ..working = p.working;
      switch (m.role) {
        case StaffRole.cashier:
          f.lane = cashiers++;
          hasCashier = true;
          _place(f, dt, LevelLayout.cashierX - f.lane * LevelLayout.cashierLaneGap, LevelLayout.counterFloor, LevelLayout.counterScale);
          f.depth = LevelLayout.cashierDepth;
        case StaffRole.baker:
          f.lane = bakers++;
          final x = LevelLayout.bakerX[f.lane % 2] + (f.lane ~/ 2) * 26;
          _place(f, dt, x, LevelLayout.floorFor(LevelLayout.bakerScale), LevelLayout.bakerScale);
          f.depth = f.scale;
        case StaffRole.waiter:
          f.lane = waiters++;
          _walk(f, dt, p.targetCustomer);
          f.depth = f.scale;
        case StaffRole.manager:
          break;
      }
      if (f.smile > 0) f.smile = math.max(0, f.smile - dt);
      f.clock = f.moving ? f.clock + dt : 0;
      final h = LevelLayout.customerHeight * f.scale;
      final bob = f.moving ? -(math.sin(f.clock * 9)).abs() * 4 * f.scale : 0.0;
      f
        ..height = h
        ..top = f.floor - h + bob
        ..drawX = f.x
        ..alpha = 1;
      _byIndex[i] = f;
      figures.add(f);
    }
  }

  /// Đứng yên ở chỗ cố định.
  void _place(_StaffFigure f, double dt, double x, double floor, double scale) {
    f
      ..x = x
      ..floor = floor
      ..scale = scale
      ..moving = false
      ..placed = true;
  }

  /// Phục vụ: tới cạnh khách [target] (đang chờ trong hàng) nếu có, không thì về chỗ đứng chờ. Đi đều (không giật khi
  /// khách trong hàng dồn lên), tỉ lệ / đáy khung đổi cùng nhịp quãng đường.
  void _walk(_StaffFigure f, double dt, int? target) {
    final home = LevelLayout.waiterHomeX - f.lane * 44;
    var gx = home, gs = LevelLayout.waiterScale;
    final spot = target == null ? null : customerSpot(target);
    if (spot != null) {
      final (cx, _, cs) = spot;
      final side = cx + LevelLayout.waiterBeside * cs > 1240 ? -1 : 1;
      gx = cx + side * LevelLayout.waiterBeside * cs;
      gs = cs + LevelLayout.waiterAhead;
    }
    final gf = LevelLayout.floorFor(gs);
    if (!f.placed) {
      f
        ..x = home
        ..scale = LevelLayout.waiterScale
        ..floor = LevelLayout.floorFor(LevelLayout.waiterScale)
        ..placed = true;
    }
    final dx = gx - f.x;
    final d = dx.abs();
    final stepPx = LevelLayout.waiterSpeed * f.scale * dt;
    if (d <= stepPx) {
      f
        ..x = gx
        ..scale = approach(f.scale, gs, dt, speed: 10)
        ..floor = approach(f.floor, gf, dt, speed: 10)
        ..moving = false;
    } else {
      final k = stepPx / d;
      f
        ..x += dx * k
        ..scale += (gs - f.scale) * k
        ..floor += (gf - f.floor) * k
        ..moving = true;
    }
  }

  // ------------------------------------------------------------------ Sự kiện

  _StaffFigure? _at(int staffIndex) =>
      staffIndex >= 0 && staffIndex < _byIndex.length ? _byIndex[staffIndex] : null;

  /// Gốc hiệu ứng của nhân viên [staffIndex] (đầu); không vẽ (quản lý / chưa đồng bộ) → null.
  Offset? headOf(int staffIndex) => _at(staffIndex)?.head;

  /// Tâm vòng tiến độ của thợ [staffIndex] (gốc bánh bay vào tủ).
  Offset? ringOf(int staffIndex) => _at(staffIndex)?.ring;

  /// Nhân viên vừa bán / vừa xong mẻ: cười một lúc.
  void cheer(int staffIndex, {double sec = 1.2}) => _at(staffIndex)?.smile = sec;

  /// Nét mặt hiện tại của nhân viên [staffIndex] (test).
  int? expressionOf(int staffIndex) => _at(staffIndex)?.expr;

  /// Độ sâu xếp thứ tự vẽ của nhân viên [staffIndex] (test).
  double? depthOf(int staffIndex) => _at(staffIndex)?.depth;

  /// Khung ảnh của nhân viên [staffIndex] (test).
  Rect? frameOf(int staffIndex) {
    final f = _at(staffIndex);
    if (f == null) return null;
    final w = f.height * 0.75;
    return Rect.fromLTWH(f.drawX - w / 2, f.top, w, f.height);
  }

  /// Vòng tiến độ (cả vùng món) của thợ [staffIndex] (test).
  Rect? ringRectOf(int staffIndex) {
    final f = _at(staffIndex);
    return f == null || f.role != StaffRole.baker ? null : Rect.fromCircle(center: f.ring, radius: LevelLayout.staffRingRadius + 3);
  }

  // ------------------------------------------------------------------ Vẽ

  /// Vòng tiến độ + món đang làm trên đầu thợ bánh (vẽ sau mặt tủ, trước bong bóng gọi món).
  void paintOverlays(Canvas canvas) {
    const r = LevelLayout.staffRingRadius;
    for (final s in figures) {
      final f = s as _StaffFigure;
      if (f.role != StaffRole.baker) continue;
      final working = f.working;
      if (working == null) continue;
      final c = f.ring;
      paintShadow(canvas, c.translate(0, r + 2), r * 0.8, 3, alpha: 0.14);
      // Đĩa giấy viền mực + rãnh, cung bạc hà chạy theo chiều kim đồng hồ.
      canvas.drawCircle(c, r + 2, fill(SLColors.paper));
      canvas.drawCircle(c, r + 2, stroke(SLColors.ink, 1.6));
      canvas.drawCircle(c, r - 1, softStroke(SLColors.paperShade, 4.5));
      if (f.progress > 0) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r - 1), -math.pi / 2, math.pi * 2 * f.progress, false,
            softStroke(AppColors.mint, 4.5));
      }
      _paintCake(canvas, Rect.fromCircle(center: c, radius: r - 4.5), working);
    }
  }

  void _paintCake(Canvas canvas, Rect r, RecipeId recipe) {
    final image = ArtSprites.cake(recipe).image;
    if (image != null) {
      drawArt(canvas, image, r);
    } else {
      CakeArt.paint(canvas, r, _visuals[recipe] ??= CakeVisual.recipe(recipe));
    }
  }
}
