import 'dart:async';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../core/art/art_sprites.dart';
import '../../core/catalog.dart';
import '../../core/constants.dart';
import '../../core/level/level.dart';
import '../../core/models/ids.dart';
import '../../core/staff/staff.dart';
import '../../ui/sugarleaf/sl_theme.dart';
import '../components/effects.dart';
import '../components/game_paint.dart';
import 'booster_fx.dart';
import 'float_layer.dart';
import 'kitchen_view.dart';
import 'level_art.dart';
import 'level_characters.dart';
import 'level_labels.dart';
import 'level_layout.dart';
import 'shop_look.dart';
import 'shop_view.dart';
import 'staff_view.dart';
import 'topped_cakes.dart';
import 'tutorial_layer.dart';

/// Game Flame của một lượt chơi level: sân tiệm (khách, tủ kính) + bếp nhanh. Logic nằm ở [LevelSession]; game chỉ
/// gọi `advance` mỗi khung, rút sự kiện → hiệu ứng, vẽ và chuyển chạm thành hành động của session.
///
/// Không dùng component con của Flame cho phần vẽ: [step] / [paint] gọi thẳng các lớp vẽ (test chạy được mà không cần
/// gắn game vào cây widget). Con trỏ đến từ `Listener` của `LevelPlayView` (toạ độ khung 1280×720), như `BakeryGame`.
class LevelGame extends FlameGame {
  LevelGame(
      {required LevelSession session,
      this.onSpecialTap,
      this.onEvent,
      Map<DecorSlot, DecorId?> decor = const {},
      bool festiveOutfits = false})
      : _session = session,
        _decor = decor,
        _look = ShopLook.of(session, decor: decor),
        _boosts = boostsOf(session),
        _festive = festiveOutfits;

  LevelSession _session;
  LevelSession get session => _session;

  Map<DecorSlot, DecorId?> _decor;
  ShopLook _look;

  /// Đồ vẽ thêm theo `session.setup` (đồ đã mua) + đồ trang trí đã đặt.
  ShopLook get look => _look;

  /// Đồ trang trí đã đặt (ô quầy / cây được vẽ); đổi → dựng lại [look].
  set decor(Map<DecorSlot, DecorId?> d) {
    if (mapEquals(d, _decor)) return;
    _decor = d;
    _refreshLook();
  }

  void _refreshLook() {
    final next = ShopLook.of(_session, decor: _decor);
    if (next != _look) _look = next;
    unawaited(ArtSprites.preload(decorRefs(_look)));
  }

  /// Ảnh đồ trang trí cần cho [look].
  static List<ArtRef> decorRefs(ShopLook look) => [
        if (look.counterDecor case final d?) ArtSprites.decor(d),
        if (look.plantDecor case final d?) ArtSprites.decor(d),
      ];

  // ------------------------------------------------------------------ Vật phẩm hỗ trợ + trang phục (GĐ6)

  LevelBoosts _boosts;

  /// Vật phẩm giả lập thay cho `session` (test, ảnh kiểm tra).
  @visibleForTesting
  LevelBoosts? debugBoosts;

  /// Vật phẩm hỗ trợ đang dùng trong lượt (đọc một lần mỗi session).
  LevelBoosts get boosts => debugBoosts ?? _boosts;

  /// Cờ vẽ từ vật phẩm của [s] (bộ vật phẩm cố định cho cả lượt).
  static LevelBoosts boostsOf(LevelSession s) => LevelBoosts.of(s.boosters);

  bool _festive;

  /// Trang phục lễ hội của nhân viên đang bật: nhân viên dùng ảnh `<character>_fest_<expr>` (thiếu → ảnh thường).
  bool get festiveOutfits => _festive;
  set festiveOutfits(bool on) {
    if (on == _festive) return;
    _festive = on;
    if (on) unawaited(LevelCharacters.preload(StaffView.festSpritesFor(session.setup.staff), urgent: true));
  }

  /// Chạm khách đặc biệt đang chờ (ui mở đơn 6 trạm).
  ValueChanged<int>? onSpecialTap;

  /// Mỗi sự kiện session (âm thanh / rung ở ui).
  ValueChanged<SessionEvent>? onEvent;

  final CanvasText text = CanvasText();
  final EffectsLayer effects = EffectsLayer();
  late final ToppedCakes toppedCakes = ToppedCakes(() => artGeneration);
  late final FloatLayer floats = FloatLayer(text, topped: toppedCakes);
  late final ShopView shop = ShopView(this);
  late final KitchenView kitchen = KitchenView(this);
  late final TutorialLayer tutorial = TutorialLayer(this);
  late final BoosterFx boosterFx = BoosterFx(this);

  LevelLabels labels = LevelLabels.fallback;

  /// Đồng hồ hoạt cảnh (giây, chạy cả khi session dừng).
  double time = 0;

  /// Tăng mỗi khi `ArtSprites` nạp thêm ảnh (tủ kính ghi lại hình bánh).
  int artGeneration = 0;

  bool _wasBlocked = false;

  // ------------------------------------------------------------------ Nhân viên (GĐ4)

  final List<StaffPose> _poses = [];

  /// Nhân viên giả lập thay cho `session` (test: bố cục, perf 10 nhân viên).
  @visibleForTesting
  List<StaffPose>? debugStaffPoses;

  /// Nhân viên vẽ trong cảnh khung này, theo thứ tự (= `staffIndex` của sự kiện). Đối tượng tái dùng.
  List<StaffPose> get staffPoses => debugStaffPoses ?? _syncPoses();

  /// Chép `session.staff` (thứ tự = `staffIndex`) vào [_poses].
  List<StaffPose> _syncPoses() {
    final staff = session.staff;
    if (_poses.length > staff.length) _poses.length = staff.length;
    for (var i = 0; i < staff.length; i++) {
      final st = staff[i];
      if (i >= _poses.length) _poses.add(StaffPose(st.member));
      _poses[i]
        ..member = st.member
        ..progress = st.progress
        ..working = st.working
        ..targetCustomer = st.targetCustomer
        ..actions = st.actions;
    }
    return _poses;
  }

  // ------------------------------------------------------------------ Hướng dẫn L1–L3 (GĐ5)

  /// Bước hướng dẫn giả lập thay cho `session` (test: toạ độ mục tiêu, ảnh kiểm tra).
  @visibleForTesting
  TutorialPose? debugTutorial;

  final TutorialPose _tutorialPose = TutorialPose('', TutorialSpot.none);

  /// Bước hướng dẫn đang hiện ở khung này (null = không có), chép từ `session.tutorial`. Đối tượng tái dùng.
  TutorialPose? get tutorialPose => debugTutorial ?? _syncTutorial();

  TutorialPose? _syncTutorial() {
    final runner = session.tutorial;
    final step = runner?.current;
    if (runner == null || step == null) return null;
    final customer = runner.targetCustomer;
    var spot = tutorialSpotOf(step.target);
    // Khách đã rời cảnh (vd. bước "khách bỏ đi"): chỉ còn nhãn chữ, không chỉ nhầm sang khách khác.
    if ((spot == TutorialSpot.customer || spot == TutorialSpot.patienceRing) && customer == null) spot = TutorialSpot.none;
    return _tutorialPose
      ..step = step.id
      ..spot = spot
      ..customerId = customer
      ..recipe = runner.targetRecipe
      ..oven = runner.targetOven
      ..dismissible = step.dismissible
      ..exclusive = false;
  }

  /// `TutorialTarget` (core) → [TutorialSpot] (theo tên, không theo thứ tự enum).
  static TutorialSpot tutorialSpotOf(TutorialTarget t) => switch (t) {
        TutorialTarget.customer => TutorialSpot.customer,
        TutorialTarget.caseSlot => TutorialSpot.caseSlot,
        TutorialTarget.treatCard => TutorialSpot.treatCard,
        TutorialTarget.mould => TutorialSpot.mould,
        TutorialTarget.mix => TutorialSpot.mix,
        TutorialTarget.oven => TutorialSpot.oven,
        TutorialTarget.frost => TutorialSpot.frost,
        TutorialTarget.topping => TutorialSpot.topping,
        TutorialTarget.box => TutorialSpot.box,
        TutorialTarget.comboMeter => TutorialSpot.comboMeter,
        TutorialTarget.patienceRing => TutorialSpot.patienceRing,
        TutorialTarget.none => TutorialSpot.none,
      };

  /// Cấp ảnh lò (`oven_N`, 1..5): hàm chung `ShopSetup.ovenArtLevel` của `session.setup` (cùng công thức với bản đồ /
  /// nạp sẵn ở ui — nâng cấp lò nào cũng thấy lò đổi).
  int get ovenLevel => session.setup.ovenArtLevel;

  @override
  Color backgroundColor() => AppColors.cream;

  /// Đổi sang lượt chơi khác (ui dựng lại với session mới).
  void attachSession(LevelSession s) {
    if (identical(s, _session)) return;
    _session = s;
    _boosts = boostsOf(s);
    _refreshLook();
    shop.reset();
    kitchen.reset();
    tutorial.reset();
    _poses.clear();
    unawaited(preloadFor(s.level, ovenLevel: ovenLevel, decor: _decor, staff: s.setup.staff, festiveOutfits: _festive));
  }

  /// Chuỗi + font cho chữ vẽ trên canvas.
  void setLabels(LevelLabels l, {String? fontFamily, String? titleFontFamily, List<String>? titleFallback}) {
    labels = l;
    text
      ..fontFamily = fontFamily
      ..titleFontFamily = titleFontFamily
      ..titleFallback = titleFallback
      ..clear();
    kitchen.clearArt();
    tutorial.clearArt();
  }

  @override
  Future<void> onLoad() async {
    ArtSprites.changes.addListener(_onArt);
    unawaited(preloadFor(session.level, ovenLevel: ovenLevel, decor: _decor, staff: session.setup.staff, festiveOutfits: _festive));
  }

  void _onArt() => artGeneration++;

  /// id ảnh nhân vật có thể dùng cho lượt ghé [v] (khớp cách session dựng khách đặc biệt): bạn quen → id cố định;
  /// VIP có `look` → đúng ảnh đó; VIP không ghi `look` → session chọn ngẫu nhiên vip_01 / vip_02 nên nạp cả hai.
  static List<String> specialSprites(SpecialVisit v) => switch (v.who) {
        SpecialWho.hoa => const ['hoa'],
        SpecialWho.linh => const ['linh'],
        SpecialWho.kenji => const ['kenji'],
        SpecialWho.vip => switch (v.vipLookIndex) {
            final i? => ['vip_${i.toString().padLeft(2, '0')}'],
            null => const ['vip_01', 'vip_02'],
          },
      };

  /// Nạp sẵn (không chặn) ảnh của một level: nền tiệm (tủ trống), bong bóng / huy hiệu / hũ topping, bánh / đế nướng / bột của menu, khuôn, lò, hộp, topping, dụng
  /// cụ; ảnh nhân vật ở cỡ hiển thị (nét mặt thường trước, rồi vui / buồn / cười). Future xong khi mọi ảnh đã nạp hoặc
  /// được xác định là thiếu; không bao giờ báo lỗi.
  ///
  /// [decor]: đồ trang trí đã đặt (nạp ảnh ô quầy / cây). Ảnh kệ bánh tầng / bàn ghế nằm trong [LevelArt].
  /// [staff]: nhân viên đã thuê (`ShopSetup.staff`) — ảnh của họ nạp trước ảnh khách (có mặt ngay từ khung đầu).
  /// [festiveOutfits]: trang phục lễ hội đang bật → nạp ảnh `<character>_fest_*` của nhân viên trước ảnh thường.
  static Future<void> preloadFor(LevelData level,
      {int ovenLevel = 1,
      Map<DecorSlot, DecorId?> decor = const {},
      List<StaffMember> staff = const [],
      bool festiveOutfits = false}) {
    final recipes = [for (final r in level.menu) Catalog.recipe(r)];
    final specials = {for (final s in level.specials) ...specialSprites(s)};
    final regulars = [for (var i = 0; i < 15; i++) 'regular_${i.toString().padLeft(2, '0')}'];
    // Bộ nhớ chỉ giữ dàn nhân vật của màn này (khách thường + khách đặc biệt + nhân viên đã thuê).
    LevelCharacters.retainOnly({
      ...regulars,
      ...specials,
      for (final m in staff) m.character,
      if (festiveOutfits)
        for (final m in staff) StaffView.festCharacter(m.character),
    });
    return Future.wait([
      ArtSprites.preload([
        LevelArt.shopBase,
        for (final r in recipes) ArtSprites.cake(r.id),
        for (final r in recipes) ArtSprites.baked(r.mould, r.batter, recipe: r.id),
        for (final r in recipes) ArtSprites.batter(r.batter),
        ArtSprites.oven(ovenLevel),
        ArtSprites.coin,
        ArtSprites.starOn,
        ...ArtSprites.group(ArtGroup.moulds),
        ArtSprites.bowl,
        ArtSprites.tool(ToolId.whisk),
        ArtSprites.tool(ToolId.pipingBag),
        ArtSprites.tool(ToolId.tongs),
        ...ArtSprites.group(ArtGroup.toppings),
        ...ArtSprites.group(ArtGroup.boxes),
        ...decorRefs(ShopLook.resolve(caseSlots: level.caseSlots, decor: decor)),
      ]),
      LevelArt.preload(),
      LevelCharacters.preload([
        if (festiveOutfits) ...StaffView.festSpritesFor(staff),
        ...StaffView.spritesFor(staff),
        for (final id in [...specials, ...regulars]) (id, LevelCharacters.neutral),
        for (final e in const [LevelCharacters.joy, LevelCharacters.sad, LevelCharacters.smile])
          for (final id in [...specials, ...regulars]) (id, e),
      ]),
    ]);
  }

  @override
  void onRemove() {
    ArtSprites.changes.removeListener(_onArt);
    shop.dispose();
    kitchen.dispose();
    tutorial.dispose();
    boosterFx.dispose();
    toppedCakes.clear();
    floats.dispose();
    text.clear();
    super.onRemove();
  }

  // ------------------------------------------------------------------ Khung hình

  @override
  void update(double dt) {
    super.update(dt);
    step(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paint(canvas);
  }

  /// Một khung logic + hoạt cảnh.
  void step(double dt) {
    time += dt;
    final s = session;
    s.advance(dt);
    final blocked = s.paused || s.isOver;
    if (blocked && !_wasBlocked) kitchen.releaseAll();
    _wasBlocked = blocked;
    final events = s.drainEvents();
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      _show(e);
      onEvent?.call(e);
    }
    shop.update(dt);
    kitchen.update(dt);
    effects.update(dt);
    floats.update(dt);
    tutorial.update(dt);
  }

  /// Vẽ cả cảnh (khung 1280×720).
  void paint(Canvas canvas) {
    shop.paint(canvas);
    kitchen.paint(canvas);
    effects.render(canvas);
    floats.paint(canvas);
    tutorial.paint(canvas);
  }

  void _show(SessionEvent e) {
    switch (e.type) {
      case SessionEventType.sold:
      case SessionEventType.specialDone:
        final head = shop.headOf(e.customerId) ?? LevelLayout.caseGlass.topCenter;
        floats.coins(head.translate(0, 24), e.coins);
        effects.sparkle(head, count: 10, speed: 160);
        if (e.type == SessionEventType.specialDone) effects.hearts(head, count: 5);
        if (e.combo >= 2) floats.label(head.translate(70, 40), labels.combo(e.combo), color: SLColors.strawberryLight, delay: 0.15);
      case SessionEventType.staffSold:
        showStaffSold(e.staffIndex, e.customerId, e.coins, combo: e.combo);
      case SessionEventType.staffBatchReady:
        final recipe = e.recipe;
        if (recipe != null) showStaffBatch(e.staffIndex, recipe, e.stars);
      case SessionEventType.batchReady:
        final recipe = e.recipe;
        if (recipe == null) return;
        final from = LevelLayout.tile(LevelLayout.boxTile).center;
        final to = shop.cellCenterOf(recipe);
        floats.cake(from, to, recipe, topping: shop.newestToppingOf(recipe));
        floats.stars(to.translate(0, -30), e.stars, delay: 0.55);
        effects.sparkle(from, count: 8, speed: 140);
      case SessionEventType.caseFull:
        floats.label(LevelLayout.tile(LevelLayout.boxTile).topCenter.translate(0, 40), labels.caseFull, color: SLColors.dangerSoft);
        floats.label(LevelLayout.caseRect.topCenter.translate(0, 30), labels.caseFull, color: SLColors.dangerSoft);
        shop.shakeCase();
      case SessionEventType.burnt:
        effects.puff(_ovenTop(e.oven), const Color(0xFF7E746E), count: 7, size: 24, rise: 70);
      case SessionEventType.ovenReady:
        effects.sparkle(_ovenTop(e.oven).translate(0, 40), count: 8, speed: 120);
      case SessionEventType.rushStarted:
        floats.banner(labels.rushHour);
      case SessionEventType.specialArrived:
        effects.sparkle(const Offset(LevelLayout.specialX, 185), count: 14, speed: 180);
      case SessionEventType.walkedOut:
      case SessionEventType.specialLeft:
        final head = shop.headOf(e.customerId);
        if (head != null) effects.puff(head.translate(30, -20), const Color(0xFFB8C4D0), count: 3, size: 14, rise: 30);
      default:
        break;
    }
  }

  /// Nhân viên [staffIndex] vừa bán [coins] xu cho khách [customerId]: khách nhận bánh như khi người chơi bán (+xu,
  /// lấp lánh, combo), một đồng xu bay từ nhân viên lên ô xu HUD, nhân viên cười.
  void showStaffSold(int staffIndex, int customerId, int coins, {int combo = 0}) {
    final head = shop.headOf(customerId) ?? LevelLayout.caseGlass.topCenter;
    floats.coins(head.translate(0, 24), coins);
    effects.sparkle(head, count: 8, speed: 140);
    if (combo >= 2) floats.label(head.translate(70, 40), labels.combo(combo), color: SLColors.strawberryLight, delay: 0.15);
    final from = shop.staff.headOf(staffIndex);
    if (from != null) floats.coinFly(from.translate(0, 18), LevelLayout.hudCoins, delay: 0.1);
    shop.staff.cheer(staffIndex);
  }

  /// Thợ [staffIndex] xong mẻ [recipe] ([stars] sao): bánh bay từ vòng tiến độ vào ô tủ đúng món (hiệu ứng như mẻ của
  /// người chơi), thợ cười.
  void showStaffBatch(int staffIndex, RecipeId recipe, int stars) {
    final from = shop.staff.ringOf(staffIndex) ?? LevelLayout.caseGlass.topLeft;
    final to = shop.cellCenterOf(recipe);
    floats.cake(from, to, recipe, life: 0.7);
    floats.stars(to.translate(0, -30), stars, delay: 0.65);
    effects.sparkle(from, count: 6, speed: 110);
    shop.staff.cheer(staffIndex);
  }

  Offset _ovenTop(int oven) {
    final n = session.kitchen.ovens.length;
    return LevelLayout.ovenSlot(oven.clamp(0, n - 1), n).topCenter.translate(0, 20);
  }

  // ------------------------------------------------------------------ Con trỏ (toạ độ 1280×720)

  bool get _inputBlocked => session.paused || session.isOver;

  void pointerDown(int pointer, Offset p) {
    if (p.dy < LevelLayout.hudBottom || _inputBlocked) return;
    if (!tutorial.allowTap(p)) return;
    if (p.dy < LevelLayout.kitchenTop) {
      shop.pointerDown(p);
    } else {
      kitchen.pointerDown(pointer, p);
    }
  }

  void pointerMove(int pointer, Offset p) {
    if (_inputBlocked) return;
    kitchen.pointerMove(pointer, p);
  }

  void pointerUp(int pointer, Offset p) {
    if (_inputBlocked) {
      kitchen.pointerCancel(pointer);
      return;
    }
    kitchen.pointerUp(pointer, p);
  }

  void pointerCancel(int pointer) => kitchen.pointerCancel(pointer);

  /// Điểm chạm vào khách [id] (test).
  @visibleForTesting
  Offset? customerHitPoint(int id) => shop.hitPointOf(id);
}
