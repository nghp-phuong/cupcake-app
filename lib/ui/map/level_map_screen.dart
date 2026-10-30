import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sugarleaf_bakery/game/level/level_game.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/catalog.dart';
import '../../core/game_state.dart';
import '../../core/level/level.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/navigation.dart';
import '../level/level_common.dart';
import '../menu/login_gift_dialog.dart';
import '../menu/quests_dialog.dart';
import '../season/season_pass_screen.dart';
import '../sugarleaf/sugarleaf.dart';
import '../ui_routes.dart';
import '../upgrades/unlock_notice.dart';
import '../upgrades/upgrades_screen.dart' show UpgradesArgs;
import 'map_art.dart';
import 'map_node.dart';
import 'offline_dialog.dart';

/// Bước của hoạt cảnh tiến trình (lớp vẽ đè trên bản đồ).
enum _Fx { none, wait, stars, lock }

/// Màn chính (`AppRoutes.menu`): bản đồ chương. Mỗi chương một trang ngang (vuốt hoặc nút ‹ ›), mở sẵn ở chương chứa
/// level đang tới. Trang: tranh thị trấn (`assets/art/map/<mapArt>.webp`, thiếu → nền vẽ code), đường đi nét đứt
/// nối các nút level theo `mapPos`, nút level tròn (số, 3 sao, khoá, đang tới nhịp nhẹ + lá cờ; level ★ to hơn).
/// Chương khoá: phủ mờ + ổ khoá + số sao cần / đang có (+ gợi ý chơi lại level ít sao). Thanh trên: sao, xu, đá
/// quý, tên chương, nút Nhiệm vụ / Quà / Sổ công thức / Nâng cấp / Trang trí / Cửa hàng / Cài đặt.
///
/// Về từ màn kết quả (`goToMenu(reveal: …)`, hoặc sau chuỗi "Chơi lại" / "Màn tiếp" — hàng chờ gộp) → hoạt cảnh: sao
/// mới bay vào nút, ổ khoá của level kế rơi xuống, cuộn tới chương có level mới; mở chương mới → hộp thoại
/// "Chương N đã mở!", rồi thẻ "Mở khoá mới!" nếu các lượt đó làm mục mua sắm mới khả dụng (`newUnlocks`; "Xem" → màn
/// Nâng cấp đúng tab/thẻ). Nút Nâng cấp mang chấm đỏ khi còn mục khả dụng chưa xem (`unseenUnlocks`). Hàng hộp thoại
/// khi vào bản đồ: lời chào → "Khi bạn vắng nhà" (cũng kiểm lại khi app quay lại từ nền) → quà đăng nhập → hoạt cảnh
/// / thông báo. Hoạt cảnh chạy
/// trên lớp riêng (AnimatedBuilder cục bộ); bản đồ chỉ dựng lại ở các mốc của hoạt cảnh, không dựng lại mỗi khung.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  /// Hộp quà đăng nhập chỉ tự mở 1 lần mỗi phiên chạy app (khi còn quà chưa nhận hôm nay).
  static bool giftShownThisSession = false;

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> with SingleTickerProviderStateMixin {
  PageController? _pages;

  /// Trang (chỉ số chương) đang xem: thanh trên + nút ‹ › nghe riêng, không dựng lại cả bản đồ.
  final ValueNotifier<int> _page = ValueNotifier<int>(0);

  /// Đang mở một màn con: chặn bấm đúp push hai màn chồng nhau.
  bool _navigating = false;

  /// Đổi → nút "đang tới" nhịp lại (mỗi lần vào / quay về bản đồ).
  int _pulseKey = 0;

  // ------------------------------------------------------------------ Hoạt cảnh tiến trình
  late final AnimationController _fx = AnimationController(vsync: this);
  _Fx _fxStep = _Fx.none;
  bool _revealing = false;

  /// Trong lúc hoạt cảnh: level vừa chơi vẫn hiện số sao cũ, level vừa mở vẫn khoá, chương vừa mở vẫn phủ mờ.
  final Map<int, int> _starsOverride = {};
  final Set<int> _lockedOverride = {};
  final Set<int> _veiledChapters = {};

  /// Nút vừa đổi (sao đáp / mở khoá) nảy một lần: (level, lượt).
  (int, int)? _pop;
  LevelData? _fxLevel;
  int _fxFrom = 0;
  int _fxTo = 0;

  @override
  void initState() {
    super.initState();
    menuReturns.addListener(_onMenuReturn);
    _lifecycle = AppLifecycleListener(onResume: _onAppResumed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pages != null) return;
    final services = AppScope.read(context);
    final i = _chapterIndexOfLevel(services.levels, services.state.currentLevelId);
    _page.value = i;
    _pages = PageController(initialPage: i);
    _precacheNeighbours(i);
  }

  /// Nạp sẵn (không chặn) ảnh bản đồ của chương [i] và hai chương kề bên — cùng provider với [_MapBackground] nên
  /// chuyển trang hiện ảnh ngay, không thấy nền dự phòng vài giây. Ảnh thiếu → bỏ qua êm.
  void _precacheNeighbours(int i) {
    final chapters = AppScope.read(context).levels.chapters;
    for (final k in [i, i + 1, i - 1]) {
      if (k < 0 || k >= chapters.length || !_precached.add(k)) continue;
      unawaited(precacheImage(mapImageProvider(chapters[k]), context, onError: (_, _) {}));
    }
  }

  final Set<int> _precached = {};

  @override
  void dispose() {
    menuReturns.removeListener(_onMenuReturn);
    _lifecycle.dispose();
    _fx.dispose();
    _pages?.dispose();
    _page.dispose();
    super.dispose();
  }

  /// `goToMenu` đưa bản đồ trở lại trên cùng (vd. từ màn kết quả).
  void _onMenuReturn() => WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());

  /// Vào (hoặc quay lại) bản đồ: làm mới ngày lịch rồi chạy hàng hộp thoại chờ ([_runQueue]). Bản đồ chưa ở trên
  /// cùng → để mọi thứ nằm chờ (không lấy ra), lần vào sau chạy.
  void _onEnter() {
    if (!mounted) return;
    final services = AppScope.read(context);
    final state = services.state;
    state.refreshDaily();
    setState(() => _pulseKey++);
    final config = services.levels;
    if (config.hasLevel(state.currentLevelId)) {
      // Nạp sẵn (không chặn) ảnh của level đang tới (+ nhân viên đã thuê) để thẻ "Sẵn sàng" có cảnh ngay.
      final setup = state.shopSetup;
      unawaited(
        LevelGame.preloadFor(
          config.level(state.currentLevelId),
          ovenLevel: setup.ovenArtLevel,
          staff: setup.staff,
        ),
      );
    }
    if (!_onTop || _revealing || _queueBusy) return;
    unawaited(_runQueue());
  }

  bool get _onTop => mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  /// Đang chạy hàng hộp thoại: chặn chạy chồng khi `_onEnter` gọi lại (quay về bản đồ, app quay lại từ nền).
  bool _queueBusy = false;

  /// Hàng hộp thoại của bản đồ, lần lượt (mỗi hộp đóng mới tới hộp sau; bản đồ bị che giữa chừng → dừng, lần vào
  /// sau chạy tiếp phần còn chờ): lời chào người chơi V1 → "Khi bạn vắng nhà" → quà đăng nhập → thẻ mùa vừa kết
  /// thúc (đã tự nhận thưởng) → hoạt cảnh tiến trình + thẻ "Mở khoá mới!". "Xem" của thẻ mở màn Nâng cấp sau khi hàng xong.
  Future<void> _runQueue() async {
    if (_queueBusy) return;
    _queueBusy = true;
    UpgradesArgs? open;
    try {
      final state = AppScope.read(context).state;
      // Người chơi V1 vừa quy đổi: lời chào + quà (một lần). Phiên khoá ghi → quà không lưu được, không chào
      // (tránh chào lại mỗi lần mở app).
      if (state.welcomeGiftPending && !state.savesLocked) {
        await _showWelcome();
        if (!mounted || !_onTop) return;
      }
      if (state.pendingOffline != null) {
        await showOfflineDialog(context);
        if (!mounted || !_onTop) return;
      }
      if (state.pendingLoginReward != null && !LevelMapScreen.giftShownThisSession) {
        LevelMapScreen.giftShownThisSession = true;
        await showLoginGiftDialog(context);
        if (!mounted || !_onTop) return;
      }
      if (state.seasonAutoClaim != null) {
        await showSeasonEndedDialog(context);
        if (!mounted || !_onTop) return;
      }
      if (hasMapReveal) open = await _revealThenNotify(takeMapReveals());
    } finally {
      _queueBusy = false;
    }
    if (open != null && mounted) await _push(AppRoutes.upgrades, arguments: open);
  }

  Future<void> _showWelcome() async {
    AppScope.read(context).audio.success();
    await showSLDialog<void>(context, builder: (_) => const _WelcomeBackDialog());
    if (!mounted) return;
    AppScope.read(context).state.ackWelcomeGift();
  }

  // ------------------------------------------------------------------ App quay lại từ nền

  late final AppLifecycleListener _lifecycle;

  /// App quay lại từ nền: main.dart đã ghi mốc khi app ẩn (`markActive`) và tính lại thu nhập vắng nhà
  /// (`refreshOffline`, bộ nghe đăng ký trước nên chạy trước) → chạy hàng hộp thoại nếu bản đồ đang ở trên cùng
  /// (hiện "Khi bạn vắng nhà" khi đủ điều kiện). Màn khác đang mở → để lần vào bản đồ sau.
  void _onAppResumed() {
    Future.microtask(() {
      if (!_onTop || _revealing || _queueBusy) return;
      unawaited(_runQueue());
    });
  }

  Future<void> _push(String route, {Object? arguments}) async {
    if (_navigating || _revealing) return;
    _navigating = true;
    try {
      await Navigator.of(context).pushNamed(route, arguments: arguments);
    } finally {
      _navigating = false;
    }
    // Màn level bị thay bằng màn kết quả thì future xong khi bản đồ chưa ở trên cùng → để `_onMenuReturn` lo.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _onEnter();
  }

  void _openLevel(int levelId) {
    final state = AppScope.read(context).state;
    if (!state.isLevelUnlocked(levelId)) {
      showToast(context, AppLocalizations.of(context).mapLevelLocked, success: false);
      return;
    }
    _push(AppRoutes.level, arguments: LevelArgs(levelId));
  }

  // ------------------------------------------------------------------ Trang

  static int _chapterIndexOfLevel(LevelConfig config, int levelId) {
    if (!config.hasLevel(levelId)) return 0;
    final chapter = config.level(levelId).chapter;
    return math.max(0, config.chapters.indexWhere((c) => c.id == chapter));
  }

  Future<void> _goToPage(int index, {required bool reduce}) async {
    final pages = _pages;
    if (pages == null || !pages.hasClients || pages.page == index.toDouble()) return;
    if (reduce) {
      pages.jumpToPage(index);
      return;
    }
    await pages.animateToPage(index, duration: const Duration(milliseconds: 520), curve: Curves.easeInOut);
  }

  void _step(int delta) {
    final config = AppScope.read(context).levels;
    final target = math.min(math.max(_page.value + delta, 0), math.max(config.chapters.length - 1, 0));
    if (target != _page.value) unawaited(_goToPage(target, reduce: slReduceMotion(context)));
  }

  // ------------------------------------------------------------------ Hoạt cảnh

  /// Chạy một bước của lớp hoạt cảnh (theo ticker → test chờ được bằng pumpAndSettle). Tắt hiệu ứng → bỏ qua.
  Future<void> _run(_Fx step, Duration duration, {required bool reduce}) async {
    if (reduce) return;
    _fxStep = step;
    _fx.duration = duration;
    await _fx.forward(from: 0).orCancel;
  }

  /// Chạy hoạt cảnh cho các lượt chơi đang chờ (đã gộp theo level, theo thứ tự chơi): lần lượt từng level — sao
  /// bay vào nút, ổ khoá level kế rơi (cuộn tới chương của nó), chương mới bỏ phủ mờ. Xong → hộp thoại
  /// "Chương N đã mở!" cho mỗi chương vừa mở.
  Future<void> _playReveal(List<LevelProgressDelta> reveals) async {
    final config = AppScope.read(context).levels;
    LevelData? levelOf(int? id) => id != null && config.hasLevel(id) ? config.level(id) : null;
    final steps = [
      for (final d in reveals)
        if (config.hasLevel(d.levelId)) d,
    ];
    final newChapters = <int>{
      for (final d in steps)
        if (d.unlockedChapter case final c?) c,
    };
    // Lượt không đổi gì (thua, không thêm sao) không cần hoạt cảnh.
    final shown = [
      for (final d in steps)
        if (d.newStars > d.oldStars || levelOf(d.unlockedLevel) != null || d.unlockedChapter != null) d,
    ];
    if (steps.isEmpty || _revealing) return;
    final reduce = slReduceMotion(context);
    if (shown.isEmpty) {
      await _goToPage(_chapterIndexOfLevel(config, steps.last.levelId), reduce: reduce);
      return;
    }
    setState(() {
      _revealing = true;
      for (final d in shown) {
        if (d.newStars > d.oldStars) _starsOverride[d.levelId] = d.oldStars;
        final unlocked = levelOf(d.unlockedLevel);
        if (unlocked != null) _lockedOverride.add(unlocked.id);
        if (d.unlockedChapter case final c?) _veiledChapters.add(c);
      }
    });
    var popGen = 0;
    try {
      for (var k = 0; k < shown.length; k++) {
        final d = shown[k];
        final level = config.level(d.levelId);
        final gained = d.newStars > d.oldStars;
        final unlocked = levelOf(d.unlockedLevel);
        final newChapter = d.unlockedChapter;
        await _goToPage(_chapterIndexOfLevel(config, level.id), reduce: reduce);
        // Chờ màn kết quả mờ hẳn (lượt đầu) / nghỉ nhịp giữa các level.
        await _run(_Fx.wait, const Duration(milliseconds: 260), reduce: reduce);
        if (gained) {
          _fxLevel = level;
          _fxFrom = d.oldStars;
          _fxTo = d.newStars;
          final count = d.newStars - d.oldStars;
          await _run(_Fx.stars, Duration(milliseconds: _starFlyMs + _starStaggerMs * (count - 1)), reduce: reduce);
          if (!mounted) return;
          setState(() {
            _fxStep = _Fx.none;
            _starsOverride.remove(level.id);
            _pop = (level.id, ++popGen);
          });
          await _run(_Fx.wait, const Duration(milliseconds: 260), reduce: reduce);
        }
        if (unlocked != null) await _goToPage(_chapterIndexOfLevel(config, unlocked.id), reduce: reduce);
        if (!mounted) return;
        if (newChapter != null) {
          setState(() => _veiledChapters.remove(newChapter));
          await _run(_Fx.wait, _veilFade + const Duration(milliseconds: 60), reduce: reduce);
          if (!mounted) return;
        }
        if (unlocked != null) {
          _fxLevel = unlocked;
          setState(() {
            _lockedOverride.remove(unlocked.id);
            _pop = (unlocked.id, ++popGen);
          });
          await _run(_Fx.lock, const Duration(milliseconds: 720), reduce: reduce);
        }
      }
    } on TickerCanceled {
      return; // màn bị gỡ giữa chừng
    } finally {
      if (mounted) {
        setState(() {
          _fxStep = _Fx.none;
          _fxLevel = null;
          _starsOverride.clear();
          _lockedOverride.clear();
          _veiledChapters.clear();
          _revealing = false;
          _pulseKey++;
        });
      }
    }
    for (final id in newChapters) {
      if (!mounted) return;
      final chapter = config.chapter(id);
      if (chapter == null) continue;
      AppScope.read(context).audio.success();
      await showSLDialog<void>(context, builder: (_) => _ChapterUnlockedDialog(chapter: chapter));
    }
  }

  /// Hoạt cảnh tiến trình (+ hộp mở chương) rồi thẻ "Mở khoá mới!" cho mọi mục vừa khả dụng trong các lượt đó.
  /// "Xem" → trả tham số mở màn Nâng cấp đúng tab/thẻ; "Để sau" → null (chấm đỏ của nút Nâng cấp còn theo
  /// `unseenUnlocks` tới khi mở màn Nâng cấp).
  Future<UpgradesArgs?> _revealThenNotify(List<LevelProgressDelta> reveals) async {
    final ids = <String>[
      for (final d in reveals) ...d.newUnlocks,
    ];
    await _playReveal(reveals);
    if (ids.isEmpty || !mounted || _revealing) return null;
    return showUnlockNotice(context, ids);
  }

  static const _starFlyMs = 760;
  static const _starStaggerMs = 170;
  static const _veilFade = Duration(milliseconds: 520);

  // ------------------------------------------------------------------ Dựng

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final state = services.state;
    final config = services.levels;
    final chapters = config.chapters;
    final lang = levelLang(context);
    final reduce = slReduceMotion(context);

    final Widget body;
    if (chapters.isEmpty) {
      // levels.json nạp lỗi (cấu hình rỗng): nền vẽ code + lời nhắn; thanh trên vẫn dùng được.
      body = Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: MapPaperBackdrop(seed: 0xA9A0))),
          Center(
            child: SizedBox(
              width: 560,
              child: SLPaperCard(
                attach: SLAttach.tapeCorners,
                radius: 24,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                seed: 0xA9A1,
                child: Text(
                  l.mapLoadError,
                  textAlign: TextAlign.center,
                  style: SLTextStyles.of(context).body.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      body = PageView.builder(
        controller: _pages,
        itemCount: chapters.length,
        onPageChanged: (i) {
          _page.value = i;
          _precacheNeighbours(i);
        },
        itemBuilder: (context, i) {
          final chapter = chapters[i];
          final chapterOpen = state.isChapterUnlocked(chapter.id) && !_veiledChapters.contains(chapter.id);
          return _ChapterPage(
            key: ValueKey('map-chapter-${chapter.id}'),
            chapter: chapter,
            nodes: _nodesFor(state, config, chapter),
            locked: !chapterOpen,
            veil: chapterOpen
                ? null
                : _LockedChapterInfo.of(state, config, chapter, lang: lang),
            veilFade: reduce ? Duration.zero : _veilFade,
            pulseKey: _pulseKey,
            pop: _pop,
            onLevel: _openLevel,
            levelLabel: (n) => n.state == MapNodeState.locked
                ? l.mapLevelLockedLabel(n.level.id)
                : l.mapLevelLabel(n.level.id, n.stars),
          );
        },
      );
    }

    return ColoredBox(
      color: SLColors.cream,
      child: SLScope(
        child: AbsorbPointer(
          absorbing: _revealing,
          child: Stack(
            children: [
              Positioned.fill(child: body),
              // Lớp hoạt cảnh: sao bay vào nút / ổ khoá rơi (chỉ vẽ lại lớp này mỗi khung).
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(animation: _fx, builder: (context, _) => _fxLayer(context)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 100,
                child: _MapTopBar(
                  state: state,
                  chapters: chapters,
                  page: _page,
                  onOpen: (route) => _push(route),
                ),
              ),
              if (chapters.length > 1)
                ValueListenableBuilder<int>(
                  valueListenable: _page,
                  builder: (context, page, _) => Stack(
                    children: [
                      if (page > 0)
                        Positioned(
                          left: 14,
                          top: 330,
                          child: SLButton.icon(
                            key: const ValueKey('map-prev'),
                            icon: 'back',
                            tooltip: l.mapPrevChapter,
                            size: 60,
                            onPressed: () => _step(-1),
                          ),
                        ),
                      if (page < chapters.length - 1)
                        Positioned(
                          right: 14,
                          top: 330,
                          child: SLButton.icon(
                            key: const ValueKey('map-next'),
                            icon: 'forward',
                            tooltip: l.mapNextChapter,
                            size: 60,
                            onPressed: () => _step(1),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_NodeVm> _nodesFor(GameState state, LevelConfig config, ChapterData chapter) {
    final current = state.currentLevelId;
    final out = <_NodeVm>[];
    for (final level in config.levelsInChapter(chapter.id)) {
      final locked = !state.isLevelUnlocked(level.id) || _lockedOverride.contains(level.id);
      final stars = locked ? 0 : (_starsOverride[level.id] ?? state.levelRecord(level.id)?.stars ?? 0).clamp(0, 3);
      final nodeState = locked
          ? MapNodeState.locked
          : stars > 0
              ? MapNodeState.completed
              : MapNodeState.open;
      out.add(_NodeVm(level, nodeState, stars, current: level.id == current && nodeState == MapNodeState.open));
    }
    return out;
  }

  /// Lớp hoạt cảnh theo bước hiện tại và `_fx.value`.
  Widget _fxLayer(BuildContext context) {
    final level = _fxLevel;
    if (level == null || _fxStep == _Fx.none || _fxStep == _Fx.wait) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final special = level.isSpecial;
        final center = Offset(level.mapPos.dx * size.width, level.mapPos.dy * size.height);
        final v = _fx.value;
        final children = <Widget>[];
        if (_fxStep == _Fx.stars) {
          final count = _fxTo - _fxFrom;
          final totalMs = _starFlyMs + _starStaggerMs * (count - 1);
          final end = MapNodeGeometry.star(special);
          for (var k = 0; k < count; k++) {
            final idx = _fxFrom + k;
            final t = ((v * totalMs - _starStaggerMs * k) / _starFlyMs).clamp(0.0, 1.0);
            if (t <= 0) continue;
            final e = Curves.easeInOutCubic.transform(t);
            final from = Offset(size.width / 2 + (idx - 1) * 84, size.height * 0.42);
            final to = center + MapNodeGeometry.starOffset(idx, special);
            final ctrl = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 150);
            final p = _bezier(from, ctrl, to, e);
            final starSize = 72 + (end - 72) * e;
            final appear = Curves.easeOutBack.transform((t * 4).clamp(0.0, 1.0));
            children.add(
              Positioned(
                left: p.dx - starSize / 2,
                top: p.dy - starSize / 2,
                child: Transform.rotate(
                  angle: (1 - e) * math.pi,
                  child: Transform.scale(scale: appear, child: StarIcon(size: starSize)),
                ),
              ),
            );
          }
        } else if (_fxStep == _Fx.lock) {
          final d = MapNodeGeometry.disc(special);
          final lock = (special ? d - 14 : d) * 0.46;
          final fall = Curves.easeIn.transform(v);
          children.add(
            Positioned(
              left: center.dx - lock / 2 + 18 * v,
              top: center.dy - lock / 2 + 90 * fall,
              child: Opacity(
                opacity: (1 - v * v).clamp(0.0, 1.0),
                child: Transform.rotate(angle: 0.9 * fall, child: SLIcon('lock', size: lock, color: SLColors.inkSoft)),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }

  static Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }
}

/// Dữ liệu hiển thị một nút level.
class _NodeVm {
  const _NodeVm(this.level, this.state, this.stars, {required this.current});

  final LevelData level;
  final MapNodeState state;
  final int stars;
  final bool current;
}

// ==================================================================== Trang chương

/// Một trang chương: nền (ảnh hoặc vẽ code) + đường đi + các nút level; chương khoá → phủ mờ + thẻ ổ khoá (mờ dần
/// khi vừa mở). Nền và đường đi nằm trong RepaintBoundary riêng (vẽ một lần).
class _ChapterPage extends StatelessWidget {
  const _ChapterPage({
    super.key,
    required this.chapter,
    required this.nodes,
    required this.locked,
    required this.veil,
    required this.veilFade,
    required this.pulseKey,
    required this.pop,
    required this.onLevel,
    required this.levelLabel,
  });

  final ChapterData chapter;
  final List<_NodeVm> nodes;
  final bool locked;
  final _LockedChapterInfo? veil;
  final Duration veilFade;
  final int pulseKey;
  final (int, int)? pop;
  final ValueChanged<int> onLevel;
  final String Function(_NodeVm) levelLabel;

  int get _seed => 0xA9A0 + chapter.id * 131;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        Offset at(LevelData l) => Offset(l.mapPos.dx * size.width, l.mapPos.dy * size.height);
        final reached = nodes.where((n) => n.state != MapNodeState.locked).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: RepaintBoundary(child: _MapBackground(chapter: chapter, seed: _seed))),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: MapTrail(
                    points: [for (final n in nodes) at(n.level)],
                    done: math.max(0, reached - 1),
                    seed: _seed + 1,
                  ),
                ),
              ),
            ),
            for (final n in nodes) _positioned(n, at(n.level)),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: veilFade,
                child: veil == null
                    ? const SizedBox.shrink(key: ValueKey('open'))
                    : _LockedChapterVeil(key: ValueKey('veil-${chapter.id}'), info: veil!, onLevel: onLevel),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _positioned(_NodeVm n, Offset center) {
    final special = n.level.isSpecial;
    final box = MapNodeGeometry.box(special);
    final disc = MapNodeGeometry.discCenter(special);
    final popKey = pop != null && pop!.$1 == n.level.id ? pop : null;
    return Positioned(
      left: center.dx - disc.dx,
      top: center.dy - disc.dy,
      width: box.width,
      height: box.height,
      child: MapLevelNode(
        key: ValueKey('map-level-${n.level.id}'),
        levelId: n.level.id,
        state: n.state,
        stars: n.stars,
        special: special,
        current: n.current,
        semanticLabel: levelLabel(n),
        pulseKey: pulseKey,
        popKey: popKey,
        onPressed: () => onLevel(n.level.id),
      ),
    );
  }
}

/// Ảnh bản đồ của [chapter] (giải mã tối đa 1600 px ngang) — dùng chung cho nền trang và nạp sẵn.
ImageProvider mapImageProvider(ChapterData chapter) =>
    ResizeImage(AssetImage(chapter.mapAssetPath), width: 1600, policy: ResizeImagePolicy.fit);

/// Nền trang chương: ảnh `assets/art/map/<mapArt>.webp` (giải mã tối đa 1600 px ngang); đang nạp / thiếu ảnh →
/// nền giấy vẽ code.
class _MapBackground extends StatelessWidget {
  const _MapBackground({required this.chapter, required this.seed});

  final ChapterData chapter;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final fallback = MapPaperBackdrop(seed: seed);
    return Image(
      image: mapImageProvider(chapter),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) => frame == null && !sync ? fallback : child,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

// ==================================================================== Chương khoá

/// Điều kiện mở một chương khoá: qua level cuối chương trước + đủ sao; gợi ý level ít sao để chơi lại.
class _LockedChapterInfo {
  const _LockedChapterInfo({
    required this.chapter,
    required this.title,
    required this.need,
    required this.have,
    required this.previousChapter,
    required this.previousDone,
    required this.replay,
  });

  final ChapterData chapter;
  final String title;
  final int need;
  final int have;
  final int? previousChapter;
  final bool previousDone;

  /// Level đã qua nhưng chưa đủ 3★ (ít sao trước), tối đa 3.
  final List<(int, int)> replay;

  static _LockedChapterInfo of(GameState state, LevelConfig config, ChapterData chapter, {required String lang}) {
    final idx = config.chapters.indexWhere((c) => c.id == chapter.id);
    final prev = idx > 0 ? config.chapters[idx - 1] : null;
    final prevLevels = prev == null ? const <LevelData>[] : config.levelsInChapter(prev.id);
    final prevDone = prevLevels.isEmpty || (state.levelRecord(prevLevels.last.id)?.completed ?? false);
    final replay = <(int, int)>[
      for (final l in config.levels)
        if (l.chapter != chapter.id && state.isLevelUnlocked(l.id))
          if (state.levelRecord(l.id) case final r? when r.completed && r.stars < 3) (l.id, r.stars),
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    return _LockedChapterInfo(
      chapter: chapter,
      title: chapter.titleFor(lang),
      need: chapter.starsToUnlock,
      have: state.totalStars,
      previousChapter: prev?.id,
      previousDone: prevDone,
      replay: replay.take(3).toList(),
    );
  }
}

/// Phủ mờ trang chương khoá + thẻ giấy: ổ khoá, "Chương N chưa mở", điều kiện (qua chương trước, "Cần X ★ — bạn có
/// Y ★"), thiếu sao → gợi ý chơi lại các level ít sao (bấm → mở level).
class _LockedChapterVeil extends StatelessWidget {
  const _LockedChapterVeil({super.key, required this.info, required this.onLevel});

  final _LockedChapterInfo info;
  final ValueChanged<int> onLevel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final enoughStars = info.have >= info.need;
    final line = styles.body.copyWith(fontSize: 20, fontWeight: FontWeight.w800);
    return Stack(
      children: [
        // Chặn chạm vào nút của chương khoá.
        const Positioned.fill(child: AbsorbPointer(child: ColoredBox(color: Color(0xC7FFF4E6)))),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 70),
            child: SizedBox(
              width: 600,
              child: SLPaperCard(
                attach: SLAttach.tapeCorners,
                radius: 26,
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
                seed: 0x10C0 + info.chapter.id,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SLIconDisc('lock', size: 92, color: SLColors.paperShade, iconScale: 0.6, seed: 0x10C7),
                    const SizedBox(height: 10),
                    Text(
                      l.mapChapterLockedTitle(info.chapter.id),
                      key: const ValueKey('map-chapter-locked'),
                      textAlign: TextAlign.center,
                      style: styles.title.copyWith(fontSize: 28),
                    ),
                    Text(
                      info.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.label.copyWith(fontSize: 19, color: SLColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    if (!info.previousDone && info.previousChapter != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SLIcon('pin', size: 28),
                          const SizedBox(width: 8),
                          Flexible(child: Text(l.mapChapterNeedFinish(info.previousChapter!), style: line)),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StarIcon(size: 30, filled: enoughStars),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l.mapChapterNeedStars(info.need, info.have),
                            key: const ValueKey('map-chapter-need-stars'),
                            style: line.copyWith(color: enoughStars ? SLColors.goodDeep : SLColors.ink),
                          ),
                        ),
                      ],
                    ),
                    if (!enoughStars && info.replay.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const SLRule(thickness: 2, echo: SLRuleEcho.partial, seed: 0x10C8),
                      const SizedBox(height: 8),
                      Text(
                        l.mapChapterReplayHint,
                        textAlign: TextAlign.center,
                        style: styles.body.copyWith(fontSize: 18, color: SLColors.inkSoft, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final (id, stars) in info.replay)
                            SLButton(
                              key: ValueKey('map-replay-$id'),
                              label: l.levelNumber(id),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [for (var i = 0; i < 3; i++) StarIcon(size: 18, filled: i < stars)],
                              ),
                              semanticLabel: l.mapLevelLabel(id, stars),
                              color: SLColors.butterLight,
                              height: 52,
                              fontSize: 18,
                              onPressed: () => onLevel(id),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================================================================== Thanh trên

/// Thanh trên của bản đồ (cao ~92, nổi trên tranh, lót dải kem mờ cho dễ đọc): nhãn sao / xu / đá quý bên trái,
/// băng giấy tên chương đang xem ở giữa, 7 nút tròn có nhãn nhỏ bên phải. Không hiện cấp tiệm / XP.
class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.state, required this.chapters, required this.page, required this.onOpen});

  final GameState state;
  final List<ChapterData> chapters;
  final ValueListenable<int> page;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final questReady = state.quests.any((q) => !q.claimed && q.progress >= Catalog.quest(q.type).target);
    final stars = state.totalStars;
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD9FFF4E6), Color(0x00FFF4E6)],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SLTopBarItem(
                  key: const ValueKey('map-total-stars'),
                  value: formatInt(context, stars),
                  leading: const StarIcon(size: 32),
                  semanticLabel: l.mapStarsTotal(stars),
                  minWidth: 96,
                  seed: 0x57A2,
                ),
              ),
              const SizedBox(width: 14),
              const Padding(padding: EdgeInsets.only(top: 4), child: CurrencyBar()),
              Expanded(
                child: chapters.isEmpty
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<int>(
                        valueListenable: page,
                        builder: (context, i, _) {
                          final c = chapters[i.clamp(0, chapters.length - 1)];
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SLNameTag(
                                '${l.levelChapterLabel(c.id)} · ${c.titleFor(levelLang(context))}',
                                key: const ValueKey('map-chapter-title'),
                                icon: 'book',
                                color: SLColors.butter,
                                height: 54,
                                fontSize: 21,
                                maxWidth: 360,
                                seed: 0xC4A0 + c.id,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              _MapAction(
                label: l.mapQuestsShort,
                tooltip: l.menuQuests,
                icon: 'quest_board',
                badge: questReady,
                onPressed: () => showQuestsDialog(context),
              ),
              _MapAction(
                label: l.mapGiftShort,
                tooltip: l.menuLoginGift,
                icon: 'gift',
                iconChild: const SLArtIcon(ArtSprites.giftDaily, 'gift', size: 32),
                badge: state.pendingLoginReward != null,
                onPressed: () => showLoginGiftDialog(context),
              ),
              _MapAction(
                label: l.menuRecipeBook,
                icon: 'book',
                iconChild: const SLArtIcon(ArtSprites.book, 'book', size: 32),
                onPressed: () => onOpen(AppRoutes.recipes),
              ),
              _MapAction(
                key: const ValueKey('map-upgrades'),
                label: l.menuUpgrades,
                icon: 'oven',
                iconChild: SLArtIcon(ArtSprites.oven(state.shopSetup.ovenArtLevel), 'oven', size: 32),
                // Mục mua sắm mới khả dụng chưa xem (tắt khi mở màn Nâng cấp).
                badge: state.unseenUnlocks.isNotEmpty,
                onPressed: () => onOpen(AppRoutes.upgrades),
              ),
              _MapAction(label: l.menuDecor, icon: 'decor_chair', onPressed: () => onOpen(AppRoutes.decor)),
              _MapAction(
                key: const ValueKey('map-season'),
                label: l.mapSeasonShort,
                tooltip: l.seasonTitle,
                icon: 'ticket',
                iconChild: const AssetArt(
                  kSeasonTicketAsset,
                  width: 36,
                  fallback: SLArtIcon(ArtSprites.ticket, 'ticket', size: 32),
                ),
                // Thưởng thẻ mùa chờ nhận / thông báo hết mùa chưa xem.
                badge: seasonHasPending(state),
                onPressed: () => onOpen(UiRoutes.season),
              ),
              _MapAction(label: l.menuStore, icon: 'shop_bag', onPressed: () => onOpen(AppRoutes.store)),
              _MapAction(label: l.menuSettings, icon: 'settings', onPressed: () => onOpen(AppRoutes.settings)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nút tròn của thanh trên + nhãn nhỏ bên dưới (viền giấy cho dễ đọc trên tranh). [badge] = chấm báo có việc chờ.
class _MapAction extends StatelessWidget {
  const _MapAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconChild,
    this.badge = false,
  });

  /// Nhãn ngắn dưới nút.
  final String label;

  /// Tên đầy đủ (tooltip + nhãn đọc màn hình); null → [label].
  final String? tooltip;
  final String icon;
  final Widget? iconChild;
  final bool badge;
  final VoidCallback onPressed;

  static const width = 76.0;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return Container(
      width: width,
      margin: const EdgeInsets.only(left: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SLButton.icon(
            icon: icon,
            iconChild: iconChild,
            tooltip: tooltip ?? label,
            size: 54,
            badge: badge ? const SLBadge.dot() : null,
            onPressed: onPressed,
          ),
          const SizedBox(height: 2),
          // Chạm vào nhãn cũng mở (nút tròn đã mang nhãn đọc màn hình).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            excludeFromSemantics: true,
            child: ExcludeSemantics(
              child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: styles.caption.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  shadows: const [
                    Shadow(color: SLColors.paper, blurRadius: 2),
                    Shadow(color: SLColors.paper, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================== Mở chương

/// "Chương N đã mở!": dải tiêu đề vàng bơ, đĩa cửa tiệm + lấp lánh, tên chương, lời mời, nút "Đi thôi!".
class _ChapterUnlockedDialog extends StatelessWidget {
  const _ChapterUnlockedDialog({required this.chapter});

  final ChapterData chapter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    return SLDialog(
      key: const ValueKey('map-chapter-unlocked'),
      title: l.mapChapterUnlockedTitle(chapter.id),
      titleIcon: 'confetti',
      titleColor: SLColors.butter,
      width: 600,
      actions: [
        SLButton(
          label: l.mapChapterUnlockedGo,
          icon: 'forward',
          color: SLColors.strawberry,
          width: 240,
          height: 64,
          fontSize: 24,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          const Stack(
            clipBehavior: Clip.none,
            children: [
              SLIconDisc('storefront', size: 104, color: SLColors.mintLight, seed: 0xC4A9),
              Positioned(right: -18, top: -6, child: SLSparkle(size: 30)),
              Positioned(left: -16, bottom: 4, child: SLSparkle(size: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chapter.titleFor(levelLang(context)),
            textAlign: TextAlign.center,
            style: styles.heading.copyWith(fontSize: 32, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(l.mapChapterUnlockedBody, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Lời chào người chơi V1 (một lần sau khi quy đổi bản lưu): tiệm có diện mạo mới + quà xu / đá quý đã cộng.
class _WelcomeBackDialog extends StatelessWidget {
  const _WelcomeBackDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final number = SLTextStyles.of(context).number.copyWith(fontSize: 26, fontWeight: FontWeight.w900);
    return SLDialog(
      key: const ValueKey('map-welcome-back'),
      title: l.mapWelcomeTitle,
      titleIcon: 'heart',
      titleColor: SLColors.strawberryLight,
      width: 640,
      actions: [
        SLButton(
          label: l.mapChapterUnlockedGo,
          icon: 'forward',
          color: SLColors.strawberry,
          width: 240,
          height: 64,
          fontSize: 24,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          const Stack(
            clipBehavior: Clip.none,
            children: [
              SLIconDisc('storefront', size: 96, color: SLColors.mintLight, seed: 0xC4AA),
              Positioned(right: -18, top: -6, child: SLSparkle(size: 30)),
              Positioned(left: -16, bottom: 4, child: SLSparkle(size: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.mapWelcomeBody(GameState.welcomeGiftCoins, GameState.welcomeGiftGems),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 40),
              const SizedBox(width: 6),
              Text('+${formatInt(context, GameState.welcomeGiftCoins)}', style: number),
              const SizedBox(width: 28),
              const GemIcon(size: 40),
              const SizedBox(width: 6),
              Text('+${formatInt(context, GameState.welcomeGiftGems)}', style: number),
            ],
          ),
        ],
      ),
    );
  }
}
