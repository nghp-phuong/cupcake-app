import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sugarleaf_bakery/game/bake_session_view.dart';

import '../../core/app_scope.dart';
import '../../core/art/art_sprites.dart';
import '../../core/art/customer_art.dart';
import '../../core/day_controller.dart';
import '../../core/l10n_lookup.dart';
import '../../core/models/bake.dart';
import '../../core/models/customer.dart';
import '../../core/models/ids.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/currency_bar.dart';
import '../common/dialogs.dart';
import '../common/navigation.dart';
import '../common/shop_scene.dart';
import '../common/speech_bubble.dart';
import '../common/sugar_button.dart';
import '../common/sugar_screen.dart';
import '../sugarleaf/sugarleaf.dart';
import 'mochi_visit.dart';
import 'order_ticket.dart';
import 'rain_overlay.dart';
import 'result_card.dart';
import 'story_overlay.dart';

enum _Phase { story, intro, order, baking, result, mochi }

/// Ngày kinh doanh: (1) cảnh truyện → (2) giới thiệu ngày → (3) khách gọi món → (4) làm bánh
/// (`BakeSessionView`) → (5) thẻ kết quả → … hết khách → tổng kết. Ngày mưa: cảnh tiệm phủ lớp mưa, và mèo Mochi
/// ghé một lần (pha `mochi`) sau khách giữa ngày, trước khi khách sau vào.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, this.random});

  /// Test truyền Random có seed.
  final math.Random? random;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DayController? _controller;
  _Phase _phase = _Phase.intro;
  BakeOutcome? _outcome;
  BakeResult? _result;
  int _bakeAttempt = 0;
  bool _remakeLine = false;
  bool _busy = false;
  bool _leaving = false;

  /// Đã chốt ngày và đang sang tổng kết: chặn bấm đúp/thoát/làm lại.
  bool _finishing = false;
  Set<StationId> _tutorialFor = const {};
  Timer? _introTimer;

  /// Lời dẫn "lần đầu gặp Mochi" — chốt lúc Mochi đến (sau pet/rest `mochiVisits` tăng).
  bool _mochiFirstVisit = false;

  /// Ảnh cảnh tiệm (nền + đồ trang trí đang đặt) và nét mặt khách hôm nay đã nạp xong, hoặc đã hết [_artWait].
  /// Trước đó nền là giấy dán tường và ảnh khách ở màn giới thiệu để trống — không thoáng hiện cảnh tiệm / nhân
  /// vật vẽ bằng code vài trăm ms. Không chặn luồng ngày (hẹn giờ, chạm vẫn chạy như cũ).
  bool _artReady = false;
  Timer? _artTimer;

  /// Chờ ảnh tối đa chừng này; quá hạn thì vẽ hình code dự phòng như cũ.
  static const _artWait = Duration(milliseconds: 1200);

  DayController get _day => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final state = AppScope.read(context).state;
    _controller = DayController(state: state, random: widget.random);
    // Nạp sẵn (không chặn) ảnh cảnh tiệm + đồ trang trí đang đặt và mọi nét mặt khách của ngày trong lúc chiếu
    // truyện/giới thiệu ngày; cảnh tiệm chỉ hiện khi đã có ảnh (hoặc hết [_artWait]).
    final equipped = state.equippedDecor;
    _artReady = ShopScene.usesArt(equipped) &&
        _day.customers.every((c) => CustomerImage.hasSprite(c, CustomerMood.neutral));
    final art = Future.wait([
      ArtSprites.preloadDay(equippedDecor: equipped, rainy: _day.isRainy),
      CustomerArt.preload(_day.customers),
    ]);
    if (!_artReady) {
      unawaited(art.then((_) => _markArtReady()));
      _artTimer = Timer(_artWait, _markArtReady);
    }
    if (_day.isRainy) unawaited(CustomerArt.preloadMochi());
    if (_day.pendingScene != null) {
      _phase = _Phase.story;
    } else {
      _startIntro();
    }
  }

  void _markArtReady() {
    _artTimer?.cancel();
    if (!mounted || _artReady) return;
    setState(() => _artReady = true);
  }

  @override
  void dispose() {
    _artTimer?.cancel();
    _introTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startIntro() {
    _phase = _Phase.intro;
    _introTimer?.cancel();
    _introTimer = Timer(const Duration(milliseconds: 2400), _toOrder);
  }

  void _onStoryFinished() {
    _day.markSceneShown();
    setState(_startIntro);
  }

  void _toOrder() {
    _introTimer?.cancel();
    if (!mounted || _phase != _Phase.intro) return;
    setState(() {
      _phase = _Phase.order;
      _remakeLine = false;
    });
  }

  void _startBaking() {
    final seen = AppScope.read(context).state.tutorialSeen;
    setState(() {
      _tutorialFor = StationId.values.toSet().difference(seen);
      _bakeAttempt++;
      _phase = _Phase.baking;
    });
  }

  void _onBaked(BakeOutcome outcome) {
    if (!mounted || _phase != _Phase.baking) return;
    final result = _day.evaluate(outcome);
    final audio = AppScope.read(context).audio;
    result.stars >= 3 ? audio.success() : audio.fail();
    setState(() {
      _outcome = outcome;
      _result = result;
      _phase = _Phase.result;
    });
  }

  Future<void> _remake() async {
    final result = _result;
    if (_busy || _finishing || _leaving || result == null || !_day.canRemake(result)) return;
    setState(() => _busy = true);
    final services = AppScope.read(context);
    var watched = false;
    try {
      watched = await services.ads.showRewarded(context, AdPlacement.remake);
    } catch (e) {
      debugPrint('DayScreen: quảng cáo làm lại lỗi ($e)');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!watched) {
      showToast(context, AppLocalizations.of(context).adsLimitReached, success: false);
      return;
    }
    _day.markRemakeUsed();
    setState(() {
      _result = null;
      _outcome = null;
      _remakeLine = true;
      _phase = _Phase.order;
    });
  }

  void _next() {
    final result = _result;
    if (_busy || _finishing || _leaving || result == null) return;
    _day.commit(result);
    if (_day.isFinished) {
      _finishing = true;
      final summary = _day.finishDay();
      Navigator.of(context).pushReplacementNamed(AppRoutes.summary, arguments: DaySummaryArgs(summary));
      return;
    }
    // Ngày mưa: Mochi ghé ngay sau khách giữa ngày, trước khi khách sau vào.
    final mochi = _day.shouldShowMochi;
    if (mochi) _mochiFirstVisit = _day.isFirstMochiVisit;
    setState(() {
      _result = null;
      _outcome = null;
      _remakeLine = false;
      _phase = mochi ? _Phase.mochi : _Phase.order;
    });
  }

  void _petMochi() {
    final gift = _day.petMochi();
    if (gift == null || !mounted) return;
    AppScope.read(context).audio.success();
    showToast(context, AppLocalizations.of(context).mochiGift(gift.coins, gift.gems));
  }

  void _restMochi() => _day.restMochi();

  void _onMochiLeft() {
    if (!mounted || _phase != _Phase.mochi || _leaving || _finishing) return;
    setState(() => _phase = _Phase.order);
  }

  Future<void> _confirmExit() async {
    if (_leaving || _busy || _finishing) return;
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.dayExitConfirmTitle,
      body: l.dayExitConfirmBody,
      titleColor: SLColors.butter,
    );
    if (!ok || !mounted || _finishing) return;
    _leaving = true;
    // Kết quả đã hiện nhưng chưa bấm "khách tiếp theo" → vẫn ghi để giữ xu đã kiếm.
    final pending = _result;
    if (_phase == _Phase.result && pending != null && !_day.isFinished) _day.commit(pending);
    goToMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    // Ngày mưa ở quầy (không phải cảnh truyện / giới thiệu ngày): cửa sổ nhuộm trời mưa + lớp mưa.
    final rainy = _day.isRainy && _phase != _Phase.story && _phase != _Phase.intro;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      // Khung không Material: nền kem + SLScope (chữ mực nâu, font nội dung). Toast/hộp thoại đi qua Overlay.
      child: ColoredBox(
        color: SLColors.cream,
        child: SLScope(
          child: _phase == _Phase.baking
            ? Stack(
                children: [
                  Positioned.fill(
                    child: BakeSessionView(
                      key: ValueKey('bake-${_day.index}-$_bakeAttempt'),
                      order: _day.currentOrder,
                      modifiers: _day.modifiers,
                      onComplete: _onBaked,
                      tutorialFor: _tutorialFor,
                      onTutorialShown: state.markTutorialSeen,
                    ),
                  ),
                  // Nút thoát khi đang làm bánh (web không có phím Back): góc trên trái, ngay dưới thanh 6 bước
                  // (y 0–72), ngoài vùng vé đơn/gợi ý/nút Xong ở cột phải và ngoài các vật thể của trạm.
                  Positioned(
                    left: 16,
                    top: 84,
                    child: SLButton.icon(
                      icon: 'exit',
                      tooltip: AppLocalizations.of(context).dayExitConfirmTitle,
                      size: 48,
                      onPressed: _confirmExit,
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: _artReady
                        ? ShopBackdrop(equipped: state.equippedDecor, rainy: rainy)
                        : const RepaintBoundary(child: WallpaperBackdrop()),
                  ),
                  // Mưa ngoài cửa sổ (dưới khách/vé đơn). Không có trong cây widget lúc làm bánh.
                  if (rainy) Positioned.fill(child: RainOverlay(key: const ValueKey('rain'), equipped: state.equippedDecor)),
                  ..._phaseLayers(context),
                ],
              ),
        ),
      ),
    );
  }

  List<Widget> _phaseLayers(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.story:
        return [
          Positioned.fill(
            child: StoryOverlay(scene: _day.pendingScene!, onFinished: _onStoryFinished),
          ),
        ];
      case _Phase.intro:
        return [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toOrder,
              child: _DayIntro(
                dayNumber: _day.dayNumber,
                customers: _day.customers,
                rainy: _day.isRainy,
                showCustomers: _artReady,
              ),
            ),
          ),
        ];
      case _Phase.order:
        final order = _day.currentOrder;
        final customer = _day.currentCustomer;
        final line = _remakeLine ? l.dayRemakeLine : l.orderLineText(order.line, l.recipeName(order.recipe));
        return [
          Positioned(
            left: 170,
            top: 140,
            child: _CustomerEntrance(key: ValueKey('customer-${_day.index}'), customer: customer),
          ),
          Positioned(
            left: 130,
            top: 76,
            width: 480,
            child: SpeechBubble(key: ValueKey('line-${_day.index}-$_remakeLine'), text: line, tailX: 0.4),
          ),
          Positioned(
            left: 170,
            top: 506,
            width: 340,
            child: Center(child: _NameTag(customer: customer)),
          ),
          // Vé giấy ghim trên quầy (cao 420 như khung cũ: y 84–504, không đè khách/nút).
          Positioned(
            left: 640,
            top: 84,
            width: 580,
            child: OrderTicket(order: order, customer: customer),
          ),
          Positioned(
            left: 780,
            top: 532,
            width: 300,
            child: SugarButton(
              label: l.dayStartBaking,
              leading: SLArtIcon(ArtSprites.cake(RecipeId.birthdayCake), 'cake_slice', size: 34),
              color: SLColors.strawberry,
              height: 76,
              fontSize: 26,
              radius: 24,
              onPressed: _startBaking,
            ),
          ),
          _hud(context),
        ];
      case _Phase.result:
        final result = _result!;
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
                order: _day.currentOrder,
                customer: _day.currentCustomer,
                outcome: _outcome!,
                result: result,
                canRemake: _day.canRemake(result),
                busy: _busy,
                onNext: _next,
                onRemake: _remake,
              ),
            ),
          ),
          _hud(context),
        ];
      case _Phase.mochi:
        return [
          Positioned.fill(
            child: MochiVisit(
              key: ValueKey('mochi-${_day.dayNumber}'),
              firstVisit: _mochiFirstVisit,
              onPet: _petMochi,
              onRest: _restMochi,
              onDone: _onMochiLeft,
            ),
          ),
          _hud(context),
        ];
      case _Phase.baking:
        return const [];
    }
  }

  Widget _hud(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context).state;
    return Positioned(
      left: 20,
      right: 20,
      top: 10,
      height: 56,
      child: Row(
        children: [
          // Nhãn giấy vàng bơ "Khách N/M" (dán băng dính như nhãn xu bên cạnh).
          SLTopBarItem(
            value: l.dayCustomerProgress(math.min(_day.index + 1, _day.total), _day.total),
            icon: 'customer',
            color: SLColors.butter,
            seed: 0xC057,
          ),
          const SizedBox(width: 12),
          CurrencyChip.coins(state.coins, height: 48),
          if (_phase == _Phase.mochi) ...[const SizedBox(width: 12), CurrencyChip.gems(state.gems, height: 48)],
          const Spacer(),
          SLButton.icon(
            icon: 'exit',
            tooltip: l.dayExitConfirmTitle,
            size: 52,
            onPressed: _confirmExit,
          ),
        ],
      ),
    );
  }
}

/// Màn mở đầu ngày: băng "Ngày N", số khách, hàng hình khách sắp đến.
class _DayIntro extends StatelessWidget {
  const _DayIntro({required this.dayNumber, required this.customers, this.rainy = false, this.showCustomers = true});

  final int dayNumber;
  final List<Customer> customers;

  /// false = ảnh khách chưa nạp xong: ảnh polaroid để trống (giấy) thay vì hình code.
  final bool showCustomers;

  /// Ngày mưa: nền mặt tiền tiệm dưới mưa (chưa nạp → cảnh tiệm bên dưới) + nhãn "Ngày mưa".
  final bool rainy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduceMotion = slReduceMotion(context);
    // Tờ giấy dán băng dính hai góc; dải vải "Ngày N" đè lên mép trên.
    final paper = SLPaperCard(
      attach: SLAttach.tapeCorners,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(32, 58, 32, 28),
      seed: 0xDA71,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rainy) ...[
            SLChip(label: l.dayRainy, icon: 'raindrop', selected: true, color: _rainBlue),
            const SizedBox(height: 14),
          ],
          Text(
            l.dayCustomersToday(customers.length),
            textAlign: TextAlign.center,
            style: SLTextStyles.of(context).label.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 16),
          // Khách sắp đến: ảnh polaroid nhỏ nghiêng so le, nảy vào lần lượt (một lần).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < customers.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SLBounceIn(
                    delay: Duration(milliseconds: 180 + 90 * i),
                    child: SLPaperCard(
                      tilt: i.isEven ? -0.05 : 0.04,
                      radius: 6,
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                      seed: 0x1D0 + i,
                      // Ảnh vẽ tay toàn thân: phóng 1.6 lần, đầu sát mép trên, thấy tới ngang eo.
                      child: showCustomers
                          ? CustomerImage(
                              customer: customers[i],
                              width: 72,
                              height: 96,
                              clipBottom: 24,
                              spriteZoom: 1.6,
                              spriteDy: -8,
                            )
                          : const SizedBox(width: 72, height: 72),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final card = ColoredBox(
      color: const Color(0x405A3E36),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.scale(scale: t, child: child),
          child: SizedBox(
            width: 640,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(padding: const EdgeInsets.only(top: 40), child: paper),
                Positioned(
                  top: 0,
                  child: SLNameTag(
                    l.dayStartTitle(dayNumber),
                    icon: rainy ? 'umbrella' : 'sun',
                    color: rainy ? SLColors.mint : SLColors.butter,
                    height: 80,
                    fontSize: 40,
                    maxWidth: 520,
                    seed: 0xDA72,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!rainy) return card;
    return Stack(
      fit: StackFit.expand,
      children: [const SceneBackdrop(scene: ArtScene.rainyDay), card],
    );
  }

  /// Xanh mưa nhạt của nhãn "Ngày mưa" (chữ mực trên nền này > 9:1).
  static const _rainBlue = Color(0xFFD6E4EE);
}

/// Khách bước vào từ bên trái tới quầy.
class _CustomerEntrance extends StatelessWidget {
  const _CustomerEntrance({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: slReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(-420 * t, 0),
        child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
      ),
      // Ảnh vẽ tay toàn thân (480×640, đỉnh đầu ~7% ảnh): vẽ 1:1 (phóng 1.6 lần) để đầu to gần bằng hình code;
      // đỉnh đầu ở y ~165 màn hình (dưới bong bóng thoại), cắt ở mép mặt quầy của cảnh tiệm vẽ tay (y ~486;
      // hình code dự phòng có mặt quầy y 486–512) để khách đứng sau quầy.
      child: CustomerImage(
        customer: customer,
        width: 300,
        height: 400,
        clipBottom: 54,
        spriteZoom: 1.6,
        spriteDy: -23,
      ),
    );
  }
}

/// Bảng tên khách dưới quầy: tấm ván gỗ sáng đóng đinh + nhãn VIP/khách quen.
class _NameTag extends StatelessWidget {
  const _NameTag({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final badge = customerBadge(l, customer);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SLNameTag(
            l.customerName(customer),
            style: SLNameTagStyle.wood,
            height: 46,
            fontSize: 22,
            maxWidth: 240,
            seed: 0x7A6 + customer.appearanceSeed,
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge],
      ],
    );
  }
}
