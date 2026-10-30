import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';
import 'package:sugarleaf_bakery/game/level/level_play_view.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/cake_art.dart';
import '../../core/catalog.dart';
import '../../core/game_state.dart';
import '../../core/l10n_lookup.dart';
import '../../core/level/level.dart';
import '../../core/models/bake.dart';
import '../../core/models/customer.dart';
import '../../core/models/ids.dart';
import '../../core/models/order.dart';
import '../../core/routes.dart';
import '../../core/scoring.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/speech_bubble.dart';
import '../common/staff_portrait.dart';
import '../common/sugar_button.dart';
import '../day/order_ticket.dart';
import '../day/result_card.dart';
import '../common/navigation.dart';
import '../day/story_overlay.dart';
import '../sugarleaf/sugarleaf.dart';
import 'booster_row.dart';
import 'level_common.dart';

enum _Phase { intro, ready, playing, specialStory, specialOrder, specialBaking, specialResult, outro }

enum _PauseChoice { resume, restart, quit }

/// Một lượt chơi level (V2): (cảnh truyện mở màn) → thẻ "Sẵn sàng" → chơi (`LevelPlayView` + HUD) → hết giờ →
/// (hỏi "+30 giây") → (cảnh truyện kết khi thắng) → `LevelResultScreen`. Đơn đặc biệt: cảnh truyện của khách → vé
/// đơn → `BakeSessionView` 6 trạm → `ResultCard` → về cảnh chơi. Kết quả chỉ cộng vào ván ĐÚNG MỘT LẦN; thoát giữa
/// chừng (tạm dừng → Thoát / Chơi lại) không cộng gì.
class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key, required this.levelId, this.random});

  final int levelId;

  /// Test truyền Random có seed.
  final math.Random? random;

  /// Số giây cộng thêm khi xem quảng cáo lúc hết giờ.
  static const extraTimeSec = 30;

  /// Đồng hồ HUD chuyển đỏ + nhịp khi còn dưới chừng này giây.
  static const lowTimeSec = 15;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  LevelSession? _session;
  late final AppLifecycleListener _lifecycle;
  _Phase _phase = _Phase.ready;

  /// Đã hết giờ, đang hỏi +30 giây / chốt kết quả.
  bool _ending = false;

  /// Đã gọi `finish` + `applyLevelResult` (chỉ một lần).
  bool _applied = false;

  /// Đã rời màn (chơi lại / thoát / sang kết quả): chặn mọi thao tác sau đó.
  bool _leaving = false;
  bool _pauseOpen = false;
  bool _busy = false;
  LevelResult? _result;

  /// Tiến trình vừa đổi khi chốt kết quả (bản đồ chạy hoạt cảnh khi quay về).
  LevelProgressDelta? _delta;

  /// Số lượt ghé đặc biệt bị bỏ đã báo; lượt ghé đặc biệt sắp tới ở lần dựng HUD trước (để biết ai vừa bị bỏ).
  int _seenSkipped = 0;
  SpecialVisit? _watchedVisit;

  // Đơn đặc biệt đang làm (giữa beginSpecial và finishSpecial/cancelSpecial).
  int? _specialId;
  Order? _specialOrder;
  Customer? _specialLook;
  StorySceneId? _specialScene;
  BakeOutcome? _specialOutcome;
  BakeResult? _specialResult;
  int _bakeAttempt = 0;
  Set<StationId> _tutorialFor = const {};

  // Vật phẩm hỗ trợ chọn trên thẻ "Sẵn sàng" (từ L4): chỉ trừ khi bấm "Bắt đầu" (thoát ở thẻ không mất).
  final Set<BoosterId> _boosters = {};

  /// Đã xem quảng cáo "1 miễn phí" lượt này (nút ẩn sau một lần, dù xem xong hay không).
  bool _boosterAdUsed = false;
  bool _boosterAdCredit = false;
  bool _boosterAdBusy = false;
  final LayerLink _boosterLink = LayerLink();

  /// Chuỗi đã dịch cho câu hướng dẫn trong màn (cập nhật khi đổi ngôn ngữ; [_tutorialText] đọc lúc vẽ).
  AppLocalizations? _l;

  LevelSession get _s => _session!;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onAppHidden);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l = AppLocalizations.of(context);
    if (_session != null) return;
    final services = AppScope.read(context);
    final state = services.state;
    // Level không tồn tại hoặc chưa mở (vd. mở thẳng đường dẫn trên web) → không dựng, về bản đồ.
    if (!services.levels.hasLevel(widget.levelId) || !state.isLevelUnlocked(widget.levelId)) return;
    final level = services.levels.level(widget.levelId);
    _session = _newSession(level);
    final intro = level.introScene;
    _phase = intro != null && !state.seenScenes.contains(intro) ? _Phase.intro : _Phase.ready;
  }

  /// Dựng session của lượt (đang dừng tới khi bấm "Bắt đầu") + nghe HUD. [boosters]: vật phẩm đã trả lúc bấm
  /// "Bắt đầu" (hiệu ứng nằm trong session — tủ đầy dựng lúc khởi tạo — nên khi có vật phẩm thì dựng lại session).
  LevelSession _newSession(LevelData level, {Set<BoosterId> boosters = const {}}) {
    final services = AppScope.read(context);
    final state = services.state;
    final s = LevelSession(
      level: level,
      defaults: services.levels.defaults,
      modifiers: state.bakeModifiers,
      decorTipBonusPct: state.decorTipBonusPct,
      // Mở rộng tiệm + thiết bị đã mua áp cho lượt này (kệ bánh tầng, lò thứ 2, khay lớn…).
      setup: state.shopSetup,
      boosters: boosters,
      random: widget.random,
      // Hướng dẫn lần đầu (L1–L3): chỉ khi chưa xong; xong → sự kiện `tutorialDone` → lưu.
      tutorialActive: level.tutorial != null && !state.isTutorialDone(level.tutorial!),
    )..paused = true; // tới khi bấm "Bắt đầu"
    s.hudRevision.addListener(_onHud);
    _watchedVisit = s.nextSpecialVisit;
    return s;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    final s = _session;
    if (s != null) {
      s.hudRevision.removeListener(_onHud);
      s.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ Mở màn

  void _onIntroFinished() {
    final intro = _s.level.introScene;
    if (intro != null) AppScope.read(context).state.markSceneSeen(intro);
    if (!mounted || _phase != _Phase.intro) return;
    setState(() => _phase = _Phase.ready);
  }

  void _start() {
    if (_phase != _Phase.ready || _leaving) return;
    final services = AppScope.read(context);
    final state = services.state;
    if (_showBoosters) {
      if (_boosters.isNotEmpty) {
        final chosen = Set.of(_boosters);
        if (!state.consumeBoosters(chosen, adFree: _adFreeBooster)) {
          // Kim cương / kho đổi giữa chừng (hiếm): báo, giữ thẻ Sẵn sàng.
          _notEnoughGems();
          return;
        }
        // Dựng lại session với vật phẩm (chưa chạy khung nào: bỏ session cũ không mất gì).
        final old = _s;
        old.hudRevision.removeListener(_onHud);
        _session = _newSession(old.level, boosters: chosen);
        // `LevelPlayView` gắn session mới ở lần dựng kế (`attachSession`): bỏ session cũ sau khung hình đó.
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      state.markBoosterIntroSeen();
    }
    services.audio.tap();
    _s.paused = false;
    setState(() => _phase = _Phase.playing);
  }

  // ------------------------------------------------------------------ Vật phẩm hỗ trợ (thẻ Sẵn sàng)

  /// Hàng vật phẩm chỉ có từ L4 (L1–L3 đang hướng dẫn) và khi có dữ liệu vật phẩm.
  bool get _showBoosters => GameState.boostersAvailableFor(_s.level.id) && _boosterData.isNotEmpty;

  List<BoosterData> get _boosterData => AppScope.read(context).state.boosterCatalog;

  BoosterId? get _adFreeBooster {
    final state = AppScope.read(context).state;
    return pickAdFreeBooster(
      adCredit: _boosterAdCredit,
      selected: [for (final b in _boosterData) if (_boosters.contains(b.id)) b],
      owned: state.boosterCount,
    );
  }

  /// Số kim cương cần cho các ô [ids] (ô có trong kho = 0; ô trả bằng quảng cáo = 0).
  int _gemCost(Set<BoosterId> ids) {
    final state = AppScope.read(context).state;
    final selected = [for (final b in _boosterData) if (ids.contains(b.id)) b];
    final free = pickAdFreeBooster(adCredit: _boosterAdCredit, selected: selected, owned: state.boosterCount);
    return state.boosterGemCost(ids, adFree: free);
  }

  void _toggleBooster(BoosterId id) {
    if (_phase != _Phase.ready || _leaving) return;
    if (_boosters.contains(id)) {
      setState(() => _boosters.remove(id));
      return;
    }
    final next = {..._boosters, id};
    if (_gemCost(next) > AppScope.read(context).state.gems) {
      _notEnoughGems();
      return;
    }
    setState(() => _boosters.add(id));
  }

  /// Vừa có lượt quảng cáo mà chưa ô đang chọn nào phải trả kim cương (chưa chọn gì / toàn đồ trong kho) → tự chọn ô
  /// đắt nhất chưa chọn còn phải trả kim cương, để lượt miễn phí không bị bỏ phí. Gọi trong setState.
  void _autoPickAdFree() {
    final state = AppScope.read(context).state;
    final paying = [
      for (final b in _boosterData)
        if (_boosters.contains(b.id) && state.boosterCount(b.id) == 0) b,
    ];
    if (paying.isNotEmpty) return;
    BoosterData? best;
    for (final b in _boosterData) {
      if (_boosters.contains(b.id) || state.boosterCount(b.id) > 0) continue;
      if (best == null || b.gemPrice > best.gemPrice) best = b;
    }
    if (best != null) _boosters.add(best.id);
  }

  /// Không đủ kim cương: báo rồi mở cửa hàng (quay lại vẫn ở thẻ Sẵn sàng, lựa chọn còn nguyên).
  void _notEnoughGems() {
    final services = AppScope.read(context);
    services.audio.fail();
    showToast(context, AppLocalizations.of(context).commonNotEnoughGems, success: false);
    Navigator.of(context).pushNamed(AppRoutes.store);
  }

  Future<void> _watchBoosterAd() async {
    if (_boosterAdUsed || _boosterAdBusy || _phase != _Phase.ready || _leaving) return;
    final services = AppScope.read(context);
    if (!services.ads.canShowRewarded()) {
      showToast(context, AppLocalizations.of(context).adsLimitReached, success: false);
      return;
    }
    setState(() => _boosterAdBusy = true);
    var watched = false;
    try {
      watched = await services.ads.showRewarded(context, AdPlacement.booster);
    } catch (e) {
      debugPrint('LevelScreen: quảng cáo vật phẩm lỗi ($e)');
    }
    if (!mounted) return;
    setState(() {
      _boosterAdBusy = false;
      if (watched) {
        _boosterAdUsed = true;
        _boosterAdCredit = true;
        _autoPickAdFree();
      }
    });
    if (watched) {
      services.audio.success();
    } else {
      showToast(context, AppLocalizations.of(context).adsLimitReached, success: false);
    }
  }

  // ------------------------------------------------------------------ Trong màn

  void _onHud() {
    final s = _s;
    if (s.specialsSkipped > _seenSkipped) {
      // Lượt ghé đặc biệt bị bỏ (quá hạn chưa đủ khách): báo nhẹ với tên khách của lượt đang chờ trước đó.
      _seenSkipped = s.specialsSkipped;
      final who = _watchedVisit?.who;
      if (who != null) scheduleMicrotask(() => _toastSkipped(who));
    }
    _watchedVisit = s.nextSpecialVisit;
    if (s.isOver && !_ending && !_leaving && _phase == _Phase.playing) {
      // Thông báo có thể tới giữa khung hình của Flame: xử lý ngoài lượt hiện tại.
      scheduleMicrotask(_onTimeUp);
    }
  }

  void _toastSkipped(SpecialWho who) {
    if (!mounted || _leaving) return;
    final l = AppLocalizations.of(context);
    showToast(context, l.levelSpecialSkipped(specialWhoName(l, who)), success: false);
  }

  void _onEvent(SessionEvent e) {
    if (!mounted) return;
    final audio = AppScope.read(context).audio;
    switch (e.type) {
      case SessionEventType.sold:
        audio.success();
      case SessionEventType.walkedOut:
      case SessionEventType.burnt:
        audio.fail();
      case SessionEventType.tutorialDone:
        final id = _s.tutorial?.id;
        if (id != null) AppScope.read(context).state.markTutorialDone(id);
      default:
        break;
    }
  }

  /// Câu hướng dẫn theo id bước (`TutorialSteps`) — `LevelPlayView` gọi lúc vẽ bong bóng; id lạ → rỗng.
  String _tutorialText(String step) {
    final l = _l;
    if (l == null) return '';
    return switch (step) {
      'basicsSell' => l.lvlTutServe,
      'basicsBake' => l.lvlTutBake,
      'basicsMould' => l.lvlTutMould,
      'basicsMix' => l.lvlTutMix,
      'basicsOven' => l.lvlTutOven,
      'basicsFrost' => l.lvlTutFrost,
      'basicsTopping' => l.lvlTutTopping(_tutorialToppings()),
      'basicsBox' => l.lvlTutBox,
      'basicsDone' => l.lvlTutCaseReady,
      'comboMeter' => l.lvlTutCombo,
      'comboVariety' => l.lvlTutNewTreat,
      'patienceRing' => l.lvlTutPatience,
      'patienceWalkout' => l.lvlTutWalkout,
      _ => '',
    };
  }

  /// Số lần chạm hũ của mẻ hướng dẫn (đơn chuẩn của món đang chỉ; mặc định 3).
  int _tutorialToppings() {
    final s = _session;
    final recipe = s?.tutorial?.targetRecipe;
    if (s == null || recipe == null) return 3;
    final toppings = s.standardOrder(recipe).toppings;
    return toppings.isEmpty ? 3 : toppings.first.count;
  }

  void _onAppHidden() {
    if (_phase == _Phase.playing && !_ending) _openPause();
  }

  Future<void> _openPause() async {
    if (_pauseOpen || _leaving || _ending || _phase != _Phase.playing) return;
    _pauseOpen = true;
    _s.paused = true;
    final choice = await showSugarDialog<_PauseChoice>(
      context,
      dismissible: false,
      builder: (ctx) => _PauseDialog(session: _s, onChoice: (c) => Navigator.of(ctx).pop(c)),
    );
    _pauseOpen = false;
    if (!mounted || _leaving) return;
    switch (choice ?? _PauseChoice.resume) {
      case _PauseChoice.resume:
        if (_phase == _Phase.playing && !_ending) _s.paused = false;
      case _PauseChoice.restart:
        _leaving = true;
        _refundUnusedBoosters();
        Navigator.of(context).pushReplacementNamed(AppRoutes.level, arguments: LevelArgs(widget.levelId));
      case _PauseChoice.quit:
        _leaving = true;
        _refundUnusedBoosters();
        goToMenu(context);
    }
  }

  /// Bỏ lượt (Thoát / Chơi lại) trước lần bán đầu tiên: vật phẩm đã dùng trả lại vào kho. Đã bán → không hoàn
  /// (hộp tạm dừng đã báo trước).
  void _refundUnusedBoosters() {
    final s = _s;
    if (s.boosters.isEmpty || s.hasSold) return;
    AppScope.read(context).state.refundBoosters(s.boosters);
    showToast(context, AppLocalizations.of(context).levelBoostersRefunded);
  }

  void _onBack() {
    switch (_phase) {
      case _Phase.playing:
        _openPause();
      case _Phase.intro:
      case _Phase.ready:
        if (_leaving) return;
        _leaving = true;
        goToMenu(context);
      case _Phase.specialOrder:
        _specialLater();
      case _Phase.specialBaking:
        _confirmSpecialExit();
      case _Phase.specialStory:
      case _Phase.specialResult:
      case _Phase.outro:
        break;
    }
  }

  // ------------------------------------------------------------------ Hết giờ

  Future<void> _onTimeUp() async {
    if (_ending || _leaving || !mounted || !_s.isOver) return;
    setState(() => _ending = true);
    final services = AppScope.read(context);
    final s = _s;
    if (s.starsNow == 0 && s.canAddTime && services.ads.canShowRewarded()) {
      final want = await showSugarDialog<bool>(
        context,
        dismissible: false,
        builder: (ctx) => _ExtraTimeDialog(onChoice: (v) => Navigator.of(ctx).pop(v)),
      );
      if (!mounted || _leaving) return;
      if (want ?? false) {
        setState(() => _busy = true);
        var watched = false;
        try {
          watched = await services.ads.showRewarded(context, AdPlacement.extraTime);
        } catch (e) {
          debugPrint('LevelScreen: quảng cáo +30 giây lỗi ($e)');
        }
        if (!mounted || _leaving) return;
        _busy = false;
        if (watched) {
          s.addTime(LevelScreen.extraTimeSec);
          s.paused = false;
          setState(() => _ending = false);
          return;
        }
        showToast(context, AppLocalizations.of(context).adsLimitReached, success: false);
      }
    }
    _finishLevel();
  }

  /// Chốt kết quả (cộng vào ván một lần), chiếu cảnh kết nếu thắng và chưa xem, rồi sang màn kết quả.
  void _finishLevel() {
    if (_applied || _leaving || !mounted) return;
    final state = AppScope.read(context).state;
    final r = _s.finish();
    _applied = true;
    _result = r;
    _delta = state.applyLevelResult(r);
    final outro = _s.level.outroScene;
    if (r.won && outro != null && !state.seenScenes.contains(outro)) {
      setState(() {
        _busy = false;
        _phase = _Phase.outro;
      });
      return;
    }
    _toResult();
  }

  void _onOutroFinished() {
    final outro = _s.level.outroScene;
    if (outro != null) AppScope.read(context).state.markSceneSeen(outro);
    _toResult();
  }

  void _toResult() {
    final r = _result;
    if (_leaving || r == null || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.levelResult, arguments: LevelResultArgs(r, progress: _delta));
  }

  // ------------------------------------------------------------------ Đơn đặc biệt

  void _onSpecialTap(int id) {
    if (_phase != _Phase.playing || _ending || _leaving || _pauseOpen) return;
    final c = _s.customer(id);
    if (c == null || !c.isSpecial) return;
    // Lượt ghé tái dùng đối tượng khách: chép giá trị trước.
    final look = c.look;
    final scene = c.visit?.scene;
    final order = _s.beginSpecial(id);
    if (order == null) return;
    final seen = AppScope.read(context).state.seenScenes;
    AppScope.read(context).audio.tap();
    setState(() {
      _specialId = id;
      _specialOrder = order;
      _specialLook = look;
      _specialScene = scene != null && !seen.contains(scene) ? scene : null;
      _specialOutcome = null;
      _specialResult = null;
      _phase = _specialScene != null ? _Phase.specialStory : _Phase.specialOrder;
    });
  }

  void _onSpecialStoryFinished() {
    final scene = _specialScene;
    if (scene != null) AppScope.read(context).state.markSceneSeen(scene);
    if (!mounted || _phase != _Phase.specialStory) return;
    setState(() => _phase = _Phase.specialOrder);
  }

  void _startSpecialBaking() {
    if (_phase != _Phase.specialOrder || _leaving) return;
    final seen = AppScope.read(context).state.tutorialSeen;
    setState(() {
      _tutorialFor = StationId.values.toSet().difference(seen);
      _bakeAttempt++;
      _phase = _Phase.specialBaking;
    });
  }

  void _onSpecialBaked(BakeOutcome outcome) {
    final order = _specialOrder;
    final look = _specialLook;
    if (!mounted || _phase != _Phase.specialBaking || order == null || look == null) return;
    final result = Scoring.evaluate(
      order: order,
      customer: look,
      outcome: outcome,
      modifiers: _s.modifiers,
      decorTipBonusPct: _s.decorTipBonusPct,
    );
    final audio = AppScope.read(context).audio;
    result.stars >= 3 ? audio.success() : audio.fail();
    setState(() {
      _specialOutcome = outcome;
      _specialResult = result;
      _phase = _Phase.specialResult;
    });
  }

  void _finishSpecial() {
    final id = _specialId;
    final result = _specialResult;
    if (_phase != _Phase.specialResult || id == null || result == null || _leaving) return;
    _s.finishSpecial(id, result);
    _clearSpecial();
  }

  /// "Để sau" ở vé đơn: khách vẫn đợi ở chỗ đặc biệt, giờ chạy tiếp.
  void _specialLater() {
    final id = _specialId;
    if (id == null || _leaving) return;
    _s.cancelSpecial(id);
    _clearSpecial();
  }

  Future<void> _confirmSpecialExit() async {
    if (_phase != _Phase.specialBaking || _leaving) return;
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.levelSpecialQuitTitle,
      body: l.levelSpecialQuitBody,
      titleColor: SLColors.butter,
    );
    if (!ok || !mounted || _phase != _Phase.specialBaking) return;
    _specialLater();
  }

  void _clearSpecial() {
    setState(() {
      _specialId = null;
      _specialOrder = null;
      _specialLook = null;
      _specialScene = null;
      _specialOutcome = null;
      _specialResult = null;
      _phase = _Phase.playing;
    });
  }

  // ------------------------------------------------------------------ Dựng

  @override
  Widget build(BuildContext context) {
    final session = _session;
    // Level không tồn tại (vd. mở thẳng đường dẫn trên web) hoặc levels.json nạp lỗi (cấu hình rỗng) → bản đồ.
    if (session == null) return const LevelRedirect();
    final baking = _phase == _Phase.specialBaking;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: ColoredBox(
        color: SLColors.cream,
        child: SLScope(
          child: Stack(
            children: [
              // Cảnh chơi luôn nằm trong cây (giữ trạng thái Flame). Lúc làm đơn đặc biệt: Offstage để không vẽ.
              // Vòng lặp Flame (GameLoop tự tạo Ticker, không theo TickerMode) vẫn chạy, nhưng an toàn vì
              // `beginSpecial` đặt `session.paused = true` → `advance` không làm gì tới `finishSpecial`/`cancelSpecial`.
              Positioned.fill(
                child: Offstage(
                  offstage: baking,
                  child: IgnorePointer(
                    ignoring: _phase != _Phase.playing || _ending,
                    child: LevelPlayView(
                      session: session,
                      festiveOutfits: AppScope.of(context).state.outfitsEnabled,
                      onSpecialTap: _onSpecialTap,
                      onEvent: _onEvent,
                      tutorialText: _tutorialText,
                    ),
                  ),
                ),
              ),
              if (_phase == _Phase.playing)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  // y 0–64 + nhãn điều kiện khách đặc biệt dưới thanh mục tiêu (vùng trống không chặn chạm).
                  height: 96,
                  child: ValueListenableBuilder<int>(
                    valueListenable: session.hudRevision,
                    builder: (context, _, _) => _LevelHud(session: session, onPause: _openPause),
                  ),
                ),
              ..._phaseLayers(context, session),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phaseLayers(BuildContext context, LevelSession session) {
    final l = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.intro:
        return [
          Positioned.fill(
            child: StoryOverlay(scene: Catalog.storyScene(session.level.introScene!), onFinished: _onIntroFinished),
          ),
        ];
      case _Phase.ready:
        return [
          Positioned.fill(
            child: _ReadyCard(
              session: session,
              onStart: _start,
              boosters: _showBoosters
                  ? BoosterRow(
                      boosters: _boosterData,
                      selected: _boosters,
                      adFree: _adFreeBooster,
                      adCredit: _boosterAdCredit,
                      onToggle: _toggleBooster,
                      link: _boosterLink,
                    )
                  : null,
              boosterAd: _showBoosters && !_boosterAdUsed
                  ? BoosterAdButton(busy: _boosterAdBusy, onPressed: _watchBoosterAd)
                  : null,
              introLink: _showBoosters && !AppScope.of(context).state.boosterIntroSeen ? _boosterLink : null,
            ),
          ),
          Positioned(
            left: 20,
            top: 14,
            child: SLButton.icon(icon: 'back', tooltip: l.commonBack, size: 56, onPressed: _onBack),
          ),
        ];
      case _Phase.playing:
        if (!_ending) return const [];
        return [
          const Positioned.fill(child: ColoredBox(color: Color(0x405A3E36))),
          Positioned(
            left: 0,
            right: 0,
            top: 120,
            child: Center(
              child: SLBounceIn(
                child: SLNameTag(
                  l.levelTimeUp,
                  icon: 'clock',
                  color: SLColors.butter,
                  height: 80,
                  fontSize: 40,
                  maxWidth: 520,
                  seed: 0x7140,
                ),
              ),
            ),
          ),
          if (_busy) const Positioned.fill(child: AbsorbPointer()),
        ];
      case _Phase.specialStory:
        return [
          Positioned.fill(
            child: StoryOverlay(scene: Catalog.storyScene(_specialScene!), onFinished: _onSpecialStoryFinished),
          ),
        ];
      case _Phase.specialOrder:
        final order = _specialOrder!;
        final customer = _specialLook!;
        return [
          const Positioned.fill(child: ColoredBox(color: Color(0x595A3E36))),
          Positioned(
            left: 170,
            top: 140,
            child: CustomerImage(
              customer: customer,
              width: 300,
              height: 400,
              clipBottom: 54,
              spriteZoom: 1.6,
              spriteDy: -23,
            ),
          ),
          Positioned(
            left: 130,
            top: 76,
            width: 480,
            child: SpeechBubble(text: l.orderLineText(order.line, l.recipeName(order.recipe)), tailX: 0.4),
          ),
          Positioned(
            left: 640,
            top: 84,
            width: 580,
            child: OrderTicket(order: order, customer: customer),
          ),
          Positioned(
            left: 640,
            top: 532,
            width: 580,
            child: Row(
              children: [
                Expanded(
                  child: SLButton(
                    label: l.levelSpecialLater,
                    variant: SLButtonVariant.secondary,
                    height: 76,
                    fontSize: 22,
                    onPressed: _specialLater,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SugarButton(
                    label: l.dayStartBaking,
                    leading: SLArtIcon(ArtSprites.cake(order.recipe), 'cake_slice', size: 34),
                    color: SLColors.strawberry,
                    height: 76,
                    fontSize: 26,
                    radius: 24,
                    onPressed: _startSpecialBaking,
                  ),
                ),
              ],
            ),
          ),
        ];
      case _Phase.specialBaking:
        return [
          Positioned.fill(
            child: BakeSessionView(
              key: ValueKey('level-bake-$_specialId-$_bakeAttempt'),
              order: _specialOrder!,
              modifiers: session.modifiers,
              onComplete: _onSpecialBaked,
              tutorialFor: _tutorialFor,
              onTutorialShown: AppScope.read(context).state.markTutorialSeen,
              ovenLevel: AppScope.read(context).state.ovenLevel,
            ),
          ),
          // Nút bỏ đơn: góc trên trái, dưới thanh 6 bước (như màn ngày V1).
          Positioned(
            left: 16,
            top: 84,
            child: SLButton.icon(
              icon: 'exit',
              tooltip: l.levelSpecialQuitTitle,
              size: 48,
              onPressed: _confirmSpecialExit,
            ),
          ),
        ];
      case _Phase.specialResult:
        return [
          const Positioned.fill(child: ColoredBox(color: Color(0x595A3E36))),
          Positioned(
            left: 280,
            top: 160,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Transform.scale(scale: t, child: child),
              child: ResultCard(
                order: _specialOrder!,
                customer: _specialLook!,
                outcome: _specialOutcome!,
                result: _specialResult!,
                canRemake: false,
                onNext: _finishSpecial,
                onRemake: () {},
              ),
            ),
          ),
        ];
      case _Phase.outro:
        return [
          Positioned.fill(
            child: StoryOverlay(scene: Catalog.storyScene(session.level.outroScene!), onFinished: _onOutroFinished),
          ),
        ];
    }
  }
}

// ==================================================================== HUD

/// "m:ss" (số, không phụ thuộc ngôn ngữ).
String _clock(double seconds) {
  final s = seconds.ceil().clamp(0, 99 * 60);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// HUD y 0–64: ⏸ | đồng hồ (+ "Giờ cao điểm!") | thanh mục tiêu + 3 vạch sao | xu trong màn | combo ×N.
/// Chỉ dựng lại khi `hudRevision` đổi; vòng combo tự vẽ lại (không dựng lại cây).
class _LevelHud extends StatelessWidget {
  const _LevelHud({required this.session, required this.onPause});

  final LevelSession session;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final left = session.timeLeft;
    final low = left < LevelScreen.lowTimeSec;
    final reduce = slReduceMotion(context);
    Widget clock = SLTopBarItem(
      value: _clock(left),
      icon: 'clock',
      color: low ? SLColors.dangerSoft : SLColors.paper,
      semanticLabel: _clock(left),
      minWidth: 112,
      seed: 0xC10C,
    );
    if (low && !reduce) {
      // Nhịp một lần mỗi giây (khoá theo giây còn lại), không lặp vô hạn.
      clock = TweenAnimationBuilder<double>(
        key: ValueKey('tick-${left.ceil()}'),
        tween: Tween(begin: 1.14, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: clock,
      );
    }
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SLButton.icon(
              icon: 'pause',
              iconChild: const _PauseGlyph(),
              tooltip: l.levelPause,
              size: 52,
              onPressed: onPause,
            ),
            const SizedBox(width: 10),
            clock,
            if (session.isRush) ...[
              const SizedBox(width: 8),
              SLBadge.label(l.levelRush, icon: 'flame', color: SLColors.dangerSoft, sparkle: true),
            ],
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GoalBar(goal: session.level.goal, value: session.goalValue),
                if (_specialCondition(context, session) case final text?)
                  IgnorePointer(child: _ConditionNote(text: text, met: session.served >= session.nextSpecialVisit!.afterServed)),
              ],
            ),
            const Spacer(),
            SLTopBarItem(
              value: formatInt(context, session.coins),
              leading: const CoinIcon(size: 32),
              semanticLabel: l.commonCoins(session.coins),
              minWidth: 110,
              seed: 0xC015,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: session.combo >= 2
                  ? _ComboChip(session: session, key: ValueKey('combo-${session.combo}'))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu tượng tạm dừng: hai vạch mực bo tròn tô vàng bơ (bộ icon SL chưa có "pause").
class _PauseGlyph extends StatelessWidget {
  const _PauseGlyph();

  @override
  Widget build(BuildContext context) {
    Widget bar(int seed) => SizedBox(
          width: 8,
          height: 22,
          child: SLSurface(
            spec: SLSurfaceSpec(shape: const SLRoundRect(3), material: SLMaterial.wash, color: SLColors.butter, seed: seed),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [bar(0x9A51), const SizedBox(width: 6), bar(0x9A52)],
    );
  }
}

/// Tên khách đặc biệt theo `who` (bạn quen: tên nhân vật; VIP: "Khách VIP").
String specialWhoName(AppLocalizations l, SpecialWho who) => switch (who) {
      SpecialWho.hoa => l.charHoa,
      SpecialWho.linh => l.charLinh,
      SpecialWho.kenji => l.charKenji,
      SpecialWho.vip => l.customerVip,
    };

/// Điều kiện của lượt ghé đặc biệt sắp tới (chỉ khi cần phục vụ đủ khách trước): "Ông Hòa ghé nếu phục vụ 12/23
/// khách trước 1:30" — mốc giờ quy ra thời gian còn lại trên đồng hồ (thời lượng − `bySec`). null → không hiện.
String? _specialCondition(BuildContext context, LevelSession session) {
  final visit = session.nextSpecialVisit;
  if (visit == null || visit.afterServed <= 0) return null;
  final l = AppLocalizations.of(context);
  final who = specialWhoName(l, visit.who);
  final served = math.min(session.served, visit.afterServed);
  final by = visit.bySec;
  if (by == null) return l.levelSpecialConditionNoTime(who, served, visit.afterServed);
  return l.levelSpecialCondition(who, served, visit.afterServed, _clock(math.max(0.0, session.duration - by)));
}

/// Mẩu giấy nhỏ dưới thanh mục tiêu (bạc hà nhạt khi đã đủ khách).
class _ConditionNote extends StatelessWidget {
  const _ConditionNote({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _GoalBar.width + 42),
        child: SLPaperCard(
          color: met ? SLColors.mintLight : SLColors.butterLight,
          radius: 10,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          seed: 0xC0DE,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              key: const ValueKey('level-special-condition'),
              maxLines: 1,
              style: SLTextStyles.of(context).caption.copyWith(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2),
            ),
          ),
        ),
      );
}

/// Thanh mục tiêu: biểu tượng loại mục tiêu + ống tiến độ có 3 vạch sao (sao sáng khi đạt mốc). Ống chia đoạn
/// (0→mốc 1: 55%, mỗi đoạn sau 22,5%) để 3 vạch luôn cách đều, dễ đọc dù các mốc sát nhau.
class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.goal, required this.value});

  final LevelGoal goal;
  final int value;

  static const width = 340.0;
  static const _marks = [0.55, 0.775, 1.0];

  double _fraction(int v) {
    final s = goal.stars;
    if (v <= 0) return 0;
    if (v >= s[2]) return 1;
    if (v < s[0]) return _marks[0] * v / s[0];
    final i = v < s[1] ? 0 : 1;
    return _marks[i] + (_marks[i + 1] - _marks[i]) * (v - s[i]) / (s[i + 1] - s[i]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final next = goal.stars.firstWhere((s) => s > value, orElse: () => goal.stars.last);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _goalIcon(goal.type, 34),
        const SizedBox(width: 8),
        SizedBox(
          width: width,
          height: 54,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 2,
                child: SLProgressBar(
                  value: _fraction(value),
                  color: SLColors.butter,
                  height: 26,
                  label: l.levelGoalProgress(value, next),
                  seed: 0x60A1,
                ),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: width * _marks[i] - 13,
                  top: 26,
                  child: StarIcon(size: 26, filled: value >= goal.stars[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Biểu tượng của loại mục tiêu (xu / khách / đơn đặc biệt).
Widget _goalIcon(GoalType type, double size) => switch (type) {
      GoalType.coins => CoinIcon(size: size),
      GoalType.customers => SLIcon('customer', size: size),
      GoalType.specialOrders => SLIcon('ticket', size: size),
    };

/// "Combo ×1,3" + vòng thời gian còn lại của cửa sổ combo (vẽ lại mỗi khung bằng ticker riêng, không dựng lại).
class _ComboChip extends StatelessWidget {
  const _ComboChip({super.key, required this.session});

  final LevelSession session;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLBounceIn(
      child: SLTopBarItem(
        value: l.levelCombo(formatDecimal1(context, session.comboMult)),
        leading: _ComboRing(session: session),
        minWidth: 140,
        seed: 0xC0B0,
        color: SLColors.butterLight,
      ),
    );
  }
}

class _ComboRing extends StatefulWidget {
  const _ComboRing({required this.session});

  final LevelSession session;

  @override
  State<_ComboRing> createState() => _ComboRingState();
}

class _ComboRingState extends State<_ComboRing> with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      _frame.value++;
      if (widget.session.comboTimeLeft <= 0) _ticker.stop();
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 30,
        child: CustomPaint(painter: _RingPainter(widget.session, _frame)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.session, Listenable repaint) : super(repaint: repaint);

  final LevelSession session;

  @override
  void paint(Canvas canvas, Size size) {
    final window = session.tuning.comboWindowSec;
    final t = window <= 0 ? 0.0 : (session.comboTimeLeft / window).clamp(0.0, 1.0);
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawOval(rect, Paint()..color = SLColors.paperShade);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = t < 0.3 ? SLColors.bad : SLColors.strawberry
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = SLColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.session != session;
}

// ==================================================================== Hộp thoại

class _PauseDialog extends StatelessWidget {
  const _PauseDialog({required this.session, required this.onChoice});

  final LevelSession session;
  final ValueChanged<_PauseChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final level = session.level;
    return SLDialog(
      title: l.levelPauseTitle,
      titleColor: SLColors.butter,
      width: 600,
      actions: [
        SLButton(
          label: l.levelQuit,
          icon: 'exit',
          variant: SLButtonVariant.secondary,
          width: 160,
          onPressed: () => onChoice(_PauseChoice.quit),
        ),
        SLButton(
          label: l.levelReplay,
          icon: 'reset',
          color: SLColors.butter,
          width: 170,
          onPressed: () => onChoice(_PauseChoice.restart),
        ),
        SLButton(
          label: l.commonContinue,
          icon: 'forward',
          color: SLColors.mint,
          width: 190,
          onPressed: () => onChoice(_PauseChoice.resume),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l.levelNumber(level.id)} · ${level.titleFor(levelLang(context))}',
            textAlign: TextAlign.center,
            style: styles.title.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(l.levelPauseBody, textAlign: TextAlign.center, style: styles.body.copyWith(fontSize: 19)),
          const SizedBox(height: 12),
          _GoalBar(goal: level.goal, value: session.goalValue),
          // Đã dùng vật phẩm: báo trước Thoát / Chơi lại có hoàn hay không (hoàn khi chưa bán cái nào).
          if (session.boosters.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              key: const ValueKey('level-pause-boosters'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SLIcon(session.hasSold ? 'warning' : 'info', size: 26),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    session.hasSold ? l.levelPauseBoosterLost : l.levelPauseBoosterRefund,
                    textAlign: TextAlign.center,
                    style: styles.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: session.hasSold ? SLColors.badDeep : SLColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExtraTimeDialog extends StatelessWidget {
  const _ExtraTimeDialog({required this.onChoice});

  final ValueChanged<bool> onChoice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLDialog(
      title: l.levelExtraTimeTitle(LevelScreen.extraTimeSec),
      titleColor: SLColors.butter,
      titleIcon: 'clock',
      actions: [
        SLButton(
          label: l.levelExtraTimeNo,
          variant: SLButtonVariant.secondary,
          width: 170,
          onPressed: () => onChoice(false),
        ),
        SLButton(
          label: l.levelExtraTimeWatch(LevelScreen.extraTimeSec),
          icon: 'play_video',
          color: SLColors.mint,
          width: 280,
          onPressed: () => onChoice(true),
        ),
      ],
      child: Text(
        l.levelExtraTimeBody,
        textAlign: TextAlign.center,
        style: SLTextStyles.of(context).body.copyWith(fontSize: 20, height: 1.35),
      ),
    );
  }
}

// ==================================================================== Thẻ "Sẵn sàng"

/// Một mốc sao: mẩu giấy nhỏ mang [stars] ngôi sao + giá trị cần đạt (mốc 1★ tô vàng bơ = mốc thắng).
class _Milestone extends StatelessWidget {
  const _Milestone({required this.stars, required this.value});

  final int stars;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SLPaperCard(
      color: stars == 1 ? SLColors.butterLight : SLColors.paper,
      radius: 14,
      tilt: stars.isEven ? 0.01 : -0.01,
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      seed: 0x57A0 + stars,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < stars; i++) const StarIcon(size: 24),
          const SizedBox(width: 6),
          Text(
            formatInt(context, value),
            style: SLTextStyles.of(context).number.copyWith(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

/// Thẻ trước khi chơi: dải "Màn N", tên level, mục tiêu + 3 mốc sao, thời gian, các món trong thực đơn, nút
/// "Bắt đầu", dòng nhỏ tóm tắt tiệm của lượt (số ô tủ · số lò · bánh mỗi khay — theo đồ đã mua) + hàng chân dung nhỏ
/// các nhân viên sẽ làm trong màn. Cảnh chơi phía sau đứng yên (session đang dừng).
class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.session, required this.onStart, this.boosters, this.boosterAd, this.introLink});

  final LevelSession session;
  final VoidCallback onStart;

  /// Hàng chọn vật phẩm hỗ trợ (từ L4); null = không có. Có hàng này → thẻ gọn lại (bánh nhỏ hơn) cho vừa khung.
  final Widget? boosters;

  /// Nút "Xem quảng cáo: 1 miễn phí" đặt bên trái nút "Bắt đầu"; null = không có (đã dùng lượt này / chưa tới L4).
  final Widget? boosterAd;

  /// Neo của chú thích giới thiệu vật phẩm lần đầu; null = không hiện.
  final LayerLink? introLink;

  LevelData get level => session.level;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final goal = level.goal;
    // Nhân viên làm trong màn (quản lý chỉ lo thu nhập khi vắng nhà, không làm trong màn).
    final staff = [
      for (final m in session.setup.staff)
        if (m.role != StaffRole.manager) m,
    ];
    final goalText = switch (goal.type) {
      GoalType.coins => l.levelGoalCoins(goal.target),
      GoalType.customers => l.levelGoalCustomers(goal.target),
      GoalType.specialOrders => l.levelGoalSpecials(goal.target),
    };
    final compact = boosters != null;
    final cake = compact ? 60.0 : 84.0;
    final gap = compact ? 8.0 : 14.0;
    final paper = SLPaperCard(
      attach: SLAttach.tapeCorners,
      radius: 30,
      padding: EdgeInsets.fromLTRB(32, compact ? 44 : 54, 32, compact ? 18 : 24),
      seed: 0x8EAD + level.id,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            level.titleFor(levelLang(context)),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: styles.heading.copyWith(fontSize: compact ? 28 : 32, height: 1.15),
          ),
          SizedBox(height: gap),
          // Mục tiêu (mốc 1★) + thời gian.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _goalIcon(goal.type, 32),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${l.levelGoalLabel}: $goalText',
                  maxLines: 2,
                  style: styles.label.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(width: 24),
              const SLIcon('clock', size: 30),
              const SizedBox(width: 6),
              Text(
                _clock(level.durationSec.toDouble()),
                semanticsLabel: '${l.levelTimeLabel} ${_clock(level.durationSec.toDouble())}',
                style: styles.number.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          // Màn dạy vòng kiên nhẫn (L3) là màn đầu tiên tính theo xu: nhắc rõ trên thẻ.
          if (level.tutorial == TutorialIds.patience && goal.type == GoalType.coins) ...[
            const SizedBox(height: 6),
            Text(
              l.levelReadyCoinsHint,
              key: const ValueKey('level-ready-coins-hint'),
              textAlign: TextAlign.center,
              style: styles.caption.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
            ),
          ],
          SizedBox(height: compact ? 8 : 12),
          // 3 mốc sao.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _Milestone(stars: i + 1, value: goal.stars[i]),
                ),
            ],
          ),
          SizedBox(height: gap),
          Text(
            l.levelMenuLabel,
            style: styles.caption.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final r in level.menu)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 112,
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CakeImage(visual: CakeVisual.recipe(r), recipe: r, size: cake),
                            if (r == level.newRecipe)
                              Positioned(right: -10, top: -6, child: SLBadge.label(l.levelNewBadge, color: SLColors.mint)),
                          ],
                        ),
                        Text(
                          l.recipeName(r),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: styles.caption.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  key: const ValueKey('level-ready-shop'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SLIcon('storefront', size: 24, color: SLColors.inkSoft),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        [
                          l.levelShopCase(session.displayCase.slots),
                          l.levelShopOvens(session.tuning.ovens),
                          l.levelShopTray(session.tuning.batchSize),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SLColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (staff.isNotEmpty) ...[
                const SizedBox(width: 18),
                _ReadyStaff(staff: staff),
              ],
            ],
          ),
          if (boosters != null) ...[
            const SizedBox(height: 8),
            boosters!,
          ],
          SizedBox(height: compact ? 10 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (boosterAd != null) ...[boosterAd!, const SizedBox(width: 16)],
              SLButton(
                label: l.levelStart,
                icon: 'forward',
                color: SLColors.strawberry,
                width: 300,
                height: compact ? 64 : 72,
                fontSize: 28,
                onPressed: onStart,
              ),
            ],
          ),
        ],
      ),
    );
    return ColoredBox(
      color: const Color(0x405A3E36),
      child: Center(
        child: SLBounceIn(
          child: SizedBox(
            width: 720,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(padding: const EdgeInsets.only(top: 36), child: paper),
                Positioned(
                  top: 0,
                  child: SLNameTag(
                    l.levelNumber(level.id),
                    icon: level.isSpecial ? 'star' : 'storefront',
                    color: level.isSpecial ? SLColors.strawberry : SLColors.butter,
                    height: 72,
                    fontSize: 34,
                    maxWidth: 480,
                    seed: 0x8EAE,
                  ),
                ),
                // Lần đầu có vật phẩm (L4): bong bóng giới thiệu bám bên phải hàng vật phẩm.
                if (introLink != null) Positioned(left: 0, top: 0, child: BoosterIntroBubble(link: introLink!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hàng chân dung tròn nhỏ các nhân viên làm trong màn (nhãn "Phụ bạn màn này" + cận mặt từ ảnh `smile`; tên ở
/// tooltip / nhãn đọc màn hình).
class _ReadyStaff extends StatelessWidget {
  const _ReadyStaff({required this.staff});

  final List<StaffMember> staff;

  static const _d = 46.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final config = AppScope.of(context).state.unlockConfig;
    final lang = levelLang(context);
    String nameOf(StaffMember m) => config.staffById(m.id)?.name(lang) ?? m.id;
    return Semantics(
      key: const ValueKey('level-ready-staff'),
      label: l.levelReadyStaffNames(staff.map(nameOf).join(', ')),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.levelReadyStaff,
              style: styles.caption.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: SLColors.inkSoft),
            ),
            const SizedBox(width: 6),
            for (final m in staff)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SLTooltip(
                  message: nameOf(m),
                  child: SizedBox.square(
                    dimension: _d,
                    child: SLSurface(
                      spec: SLSurfaceSpec(
                        shape: const SLCircle(),
                        material: SLMaterial.wash,
                        color: SLColors.mintLight,
                        inkWidth: 1.8,
                        seed: slSeed(content: m.id, salt: 0x8EB0),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: SLHandClip(
                        seed: slSeed(content: m.id, salt: 0x8EB1),
                        child: StaffPortrait(
                          key: ValueKey('level-ready-staff-${m.id}'),
                          character: staffCharacterArt(AppScope.of(context).state, m.character),
                          width: _d - 6,
                          height: _d - 6,
                          shown: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
