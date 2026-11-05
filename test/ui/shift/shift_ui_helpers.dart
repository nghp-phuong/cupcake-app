import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/city/city_day.dart';
import 'package:sugarleaf_bakery/core/city/city_game.dart';
import 'package:sugarleaf_bakery/core/city/city_wallet.dart';
import 'package:sugarleaf_bakery/core/city/player_level.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/services/ad_service.dart';
import 'package:sugarleaf_bakery/core/shift/shift_host.dart';
import 'package:sugarleaf_bakery/core/shift/shift_session.dart';
import 'package:sugarleaf_bakery/core/theme.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';
import 'package:sugarleaf_bakery/ui/shift/shift_layer.dart';

final kShiftNow = DateTime(2026, 11, 4, 10);

/// Số đo thô cho [order] mà `Scoring.evaluate` chấm đúng [stars] sao (1..5) — chép từ
/// `test/core/shift/shift_test_helpers.dart` (gói test tạm không có thư mục đó).
BakeOutcome outcomeFor(Order order, int stars) {
  final r = order.recipeData;
  final placed = <ToppingId, int>{};
  for (final t in order.toppings) {
    placed[t.topping] = (placed[t.topping] ?? 0) + t.count;
  }
  final wrongBox = BoxType.values.firstWhere((b) => b != order.box);
  return BakeOutcome(
    wrongMouldDrops: 0,
    mixTurns: r.mixTurns.toDouble(),
    bakeRelease: stars <= 1 ? 1.0 : r.bakeTarget,
    frostCoverage: switch (stars) {
      5 => 1.0,
      4 => 0.6,
      _ => 0.3,
    },
    toppingsPlaced: stars <= 2 ? const {} : placed,
    boxChosen: stars <= 3 ? wrongBox : order.box,
  );
}

/// Thành phố ở cấp [level] (hoặc [xp] nếu có), ngày thứ [day] (hôm nay, không lăn ngày), mốc "Mở mới!" [recipeSeen].
CityGame shiftGame({int level = 1, int? xp, int day = 1, int? recipeSeen, bool fullBuff = false}) {
  final g = CityGame(
    wallet: CityWallet(
      xp: xp ?? PlayerLevel.xpToReach(level),
      dayNumber: day,
      dayKey: cityDateKey(kShiftNow),
      fullBuff: fullBuff,
    ),
    clock: () => kShiftNow,
  )..refreshDay();
  if (recipeSeen != null) g.markRecipeSeen(recipeSeen);
  return g;
}

ShiftSession openShift(CityGame g, [int seed = 1]) => ShiftSession(game: g, random: math.Random(seed));

/// Đưa khách hiện tại tới `result` với [stars] sao (như cảnh 3D + trạm làm bánh đã chạy).
ShiftServed serve(ShiftSession s, int stars) {
  s.customerArrived();
  s.startBaking();
  return s.completeBake(outcomeFor(s.current.order, stars))!;
}

/// Phục vụ hết khách với [stars] sao → `finished`.
void serveAll(ShiftSession s, int stars) {
  while (s.phase != ShiftPhase.finished) {
    serve(s, stars);
    s.next();
  }
}

class FakeShiftHost implements ShiftLayerHost {
  final baking = <bool>[];
  int closed = 0;

  @override
  void setBaking(bool on) => baking.add(on);

  @override
  void close() => closed++;
}

/// Quảng cáo giả: presenter đếm số lần hiện, xong ngay.
class AdLog {
  int shown = 0;

  FakeAdService service(CityGame game) => FakeAdService(
        game,
        duration: Duration.zero,
        presenter: (context, duration) async => shown++,
      );
}

/// Quảng cáo thưởng luôn không xem hết.
class DecliningAds extends FakeAdService {
  DecliningAds(super.ledger) : super(duration: Duration.zero, presenter: _noop);

  static Future<void> _noop(BuildContext context, Duration duration) async {}

  @override
  Future<bool> showRewarded(BuildContext context, AdPlacement placement) async => false;
}

/// Dựng [ShiftLayer] trong `Stack` phủ màn [size] (như Stack của `Town3dView`); dưới cùng là lớp "cảnh 3D" đếm chạm
/// vào [below].
Future<void> pumpShiftLayer(
  WidgetTester tester, {
  required ShiftSession session,
  required CityGame game,
  required ShiftLayerHost host,
  required AdService ads,
  String locale = 'en',
  Size size = const Size(1280, 720),
  ValueNotifier<int>? below,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(locale: Locale(locale), useGoogleFonts: false),
      home: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => below?.value++,
            ),
          ),
          Positioned.fill(child: ShiftLayer(session: session, host: host, ads: ads, game: game)),
        ],
      ),
    ),
  );
  await tester.pump();
}

/// Chuỗi l10n của [locale].
Future<AppLocalizations> shiftL10n(String locale) => AppLocalizations.delegate.load(Locale(locale));
