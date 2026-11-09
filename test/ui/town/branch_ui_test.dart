
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/city_branches.dart';
import 'package:sugarleaf_bakery/core/branch/staff.dart';
import 'package:sugarleaf_bakery/core/city/city_config.dart';
import 'package:sugarleaf_bakery/core/constants.dart';
import 'package:sugarleaf_bakery/ui/shop3d/shop3d_toasts.dart';
import 'package:sugarleaf_bakery/ui/town/branch_double_chip.dart';
import 'package:sugarleaf_bakery/ui/town/branch_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/minimap.dart';
import 'package:sugarleaf_bakery/ui/town/realty_sheet.dart';
import 'package:sugarleaf_bakery/ui/town/town_map_sheet.dart';

import 'town_test_helpers.dart';

final _district = CityConfig.alpha.districts.first;

BranchView _view({
  String lotId = 's1',
  int level = 1,
  int till = 300,
  int cap = 1200,
  bool full = false,
  int? nextCost = 2000,
  int? nextLevelReq = 5,
  int slots = 1,
}) => BranchView(
  lotId: lotId,
  branchNo: _district.branchNumber(lotId),
  level: level,
  till: till,
  cap: cap,
  ratePerHour: 150,
  slots: slots,
  fullIn: const Duration(hours: 6, minutes: 30),
  full: full,
  nextCost: nextCost,
  nextLevelReq: nextCost == null ? null : nextLevelReq,
  nextRatePerHour: nextCost == null ? null : 188,
  nextCap: nextCost == null ? null : 1500,
);

BranchSheet _branch({
  BranchView? view,
  List<StaffMember> staff = const [],
  int coins = 10000,
  int level = 20,
  bool clockBehind = false,
  VoidCallback? onCollect,
  VoidCallback? onUpgrade,
  ValueChanged<String>? onHire,
  ValueChanged<String>? onDismiss,
  VoidCallback? onClose,
}) => BranchSheet(
  view: view ?? _view(),
  staff: staff,
  coins: coins,
  playerLevel: level,
  clockBehind: clockBehind,
  onCollect: onCollect ?? () {},
  onUpgrade: onUpgrade ?? () {},
  onHire: onHire ?? (_) {},
  onDismiss: onDismiss ?? (_) {},
  onClose: onClose ?? () {},
);

RealtySheet _realty({
  Set<String> owned = const {},
  int coins = 100000,
  int level = 15,
  ValueChanged<String>? onBuy,
  VoidCallback? onClose,
}) => RealtySheet(
  district: _district,
  owned: owned,
  coins: coins,
  playerLevel: level,
  onBuy: onBuy ?? (_) {},
  onClose: onClose ?? () {},
);

bool _enabled(WidgetTester t, String key) => t.widget<Shop3dPillButton>(find.byKey(ValueKey(key))).onPressed != null;

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 80, scrollable: find.byType(Scrollable).first);
  await t.pump();
}

/// Vẽ [child] (đặt trong RepaintBoundary có [key]) ra ảnh và trả về hàm đọc màu điểm ảnh.
Future<Color Function(Offset)> _pixels(WidgetTester t, GlobalKey key) async {
  late ByteData data;
  late int width;
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    width = img.width;
    data = (await img.toByteData())!;
  });
  return (p) {
    final i = (p.dy.round() * width + p.dx.round()) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  };
}

void main() {
  group('RealtySheet', () {
    testWidgets('3 dòng; khoá / của bạn / thiếu xu; nút Mua mờ đúng lý do (en)', (tester) async {
      // Cấp 10: s1 và s3 mở, s4 khoá. Đã có s1; s3 giá 20000 mà chỉ có 9000 xu.
      await pumpTown(tester, [_realty(owned: {'s1'}, coins: 9000, level: 10)]);
      final l = await l10n('en');
      expect(find.text(l.realtyLotN(1)), findsOneWidget);
      expect(find.text(l.realtyLotN(2)), findsOneWidget);
      expect(find.text(l.realtyLotN(3)), findsOneWidget);
      expect(find.text(l.realtyOwned), findsOneWidget);
      expect(find.text(l.townLotLocked(15)), findsOneWidget);
      expect(find.text(l.cityNotEnoughCoins), findsOneWidget);
      expect(find.text('8,000'), findsOneWidget, reason: 'giá lô có dấu tách nghìn');
      expect(find.text('20,000'), findsOneWidget);
      expect(find.text(l.branchIncome(150)), findsOneWidget);
      expect(find.text(l.branchTillCap(1200)), findsOneWidget);
      expect(find.byKey(const ValueKey('buy-s1')), findsNothing, reason: 'lô đã mua không còn nút Mua');
      expect(_enabled(tester, 'buy-s3'), isFalse);
      expect(_enabled(tester, 'buy-s4'), isFalse);
    });

    testWidgets('Mua → xác nhận → onBuy; Huỷ thì không gọi (vi)', (tester) async {
      final bought = <String>[];
      await pumpTown(tester, [_realty(onBuy: bought.add)], locale: 'vi');
      final vi = await l10n('vi');
      expect(_enabled(tester, 'buy-s3'), isTrue);

      await tester.tap(find.byKey(const ValueKey('buy-s3')));
      await tester.pump();
      expect(find.text(vi.realtyConfirmTitle), findsOneWidget);
      expect(find.text(vi.realtyConfirmBody(20000)), findsOneWidget);
      expect(bought, isEmpty);

      await tester.tap(find.byKey(const ValueKey('confirm-cancel')));
      await tester.pump();
      expect(find.text(vi.realtyConfirmTitle), findsNothing);
      expect(bought, isEmpty);

      await tester.tap(find.byKey(const ValueKey('buy-s3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-ok')));
      await tester.pump();
      expect(bought, ['s3']);
      expect(find.text(vi.realtyConfirmTitle), findsNothing);
    });

    testWidgets('Esc, chạm ra ngoài, nút X đều đóng; Esc khi đang xác nhận chỉ đóng xác nhận', (tester) async {
      var closed = 0;
      await pumpTown(tester, [_realty(onClose: () => closed++)]);
      final l = await l10n('en');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closed, 1);

      await tester.tapAt(const Offset(60, 360));
      await tester.pump();
      expect(closed, 2);

      await tester.tap(find.byKey(const ValueKey('panel-close')));
      await tester.pump();
      expect(closed, 3);

      await tester.tap(find.byKey(const ValueKey('buy-s1')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closed, 3);
      expect(find.text(l.realtyConfirmTitle), findsNothing);
    });
  });

  group('BranchSheet', () {
    testWidgets('Két: nút thu chỉ bật khi ≥ 1 xu; đầy rồi; đầy sau (en)', (tester) async {
      var collected = 0;
      await pumpTown(tester, [_branch(view: _view(till: 0), onCollect: () => collected++)]);
      final l = await l10n('en');
      expect(find.text(l.branchTill), findsOneWidget);
      expect(find.text(l.branchIncome(150)), findsOneWidget);
      expect(find.text(l.branchFullIn(l.offlineDurationHoursMinutes(6, 30))), findsOneWidget);
      expect(_enabled(tester, 'collect'), isFalse);

      await pumpTown(tester, [_branch(view: _view(till: 1200, full: true), onCollect: () => collected++)]);
      expect(find.text(l.branchTillFull), findsOneWidget);
      expect(find.text(l.branchCollect(1200)), findsOneWidget);
      expect(_enabled(tester, 'collect'), isTrue);
      await tester.tap(find.byKey(const ValueKey('collect')));
      expect(collected, 1);
    });

    testWidgets('ghi chú giờ máy lùi chỉ hiện khi clockBehind (vi)', (tester) async {
      final vi = await l10n('vi');
      await pumpTown(tester, [_branch()], locale: 'vi');
      expect(find.text(vi.branchClockBehind), findsNothing);
      expect(find.textContaining(vi.branchFullIn('').trim()), findsOneWidget);
      await pumpTown(tester, [_branch(clockBehind: true)], locale: 'vi');
      expect(find.text(vi.branchClockBehind), findsOneWidget);
      // Két tạm nghỉ: không hứa "Đầy sau …".
      expect(find.textContaining(vi.branchFullIn('').trim()), findsNothing);
    });

    testWidgets('Hết chỗ: chỉ gợi ý "cấp 3 có thêm chỗ" khi lô dưới cấp 3', (tester) async {
      final l = await l10n('en');
      const two = [
        StaffMember(id: 'ami', lotId: 's1', since: 0),
        StaffMember(id: 'hanh', lotId: 's1', since: 0),
      ];
      await pumpTown(tester, [_branch(view: _view(level: 3, slots: 2), staff: two, level: 20)]);
      expect(find.text('${l.branchStaff} · ${l.branchSlots(2, 2)}'), findsOneWidget);
      expect(find.text(l.branchNoSlot), findsNothing);
    });

    testWidgets('Nâng cấp: lý do thiếu cấp / thiếu xu / nâng được / tối đa', (tester) async {
      final l = await l10n('en');
      var upgraded = 0;

      await pumpTown(tester, [_branch(level: 3)]); // cần cấp 5
      final card = find.byKey(const ValueKey('card-upgrade'));
      expect(find.descendant(of: card, matching: find.text(l.branchNeedMaiLevel(5))), findsOneWidget);
      expect(find.text(l.branchNextLevel(2, 188)), findsOneWidget);
      expect(_enabled(tester, 'upgrade'), isFalse);

      await pumpTown(tester, [_branch(coins: 1999)]);
      expect(find.descendant(of: card, matching: find.text(l.cityNotEnoughCoins)), findsOneWidget);
      expect(_enabled(tester, 'upgrade'), isFalse);

      await pumpTown(tester, [_branch(coins: 2000, onUpgrade: () => upgraded++)]);
      expect(find.text(l.branchUpgrade(2000)), findsOneWidget);
      expect(_enabled(tester, 'upgrade'), isTrue);
      await tester.tap(find.byKey(const ValueKey('upgrade')));
      expect(upgraded, 1);

      await pumpTown(tester, [_branch(view: _view(level: 5, nextCost: null))]);
      expect(find.text(l.commonMax), findsOneWidget);
      expect(find.byKey(const ValueKey('upgrade')), findsNothing);
    });

    testWidgets('Nhân viên: hết chỗ, thuê, lô khác, khoá cấp', (tester) async {
      final l = await l10n('en');
      final hired = <String>[];
      final staff = [
        const StaffMember(id: 'ami', lotId: 's1', since: 0),
        const StaffMember(id: 'hanh', lotId: 's3', since: 0),
      ];
      await pumpTown(tester, [_branch(staff: staff, level: 8, onHire: hired.add)]);
      expect(find.text('${l.branchStaff} · ${l.branchSlots(1, 1)}'), findsOneWidget);
      await _scrollTo(tester, find.text(l.branchNoSlot));
      expect(find.text(l.branchNoSlot), findsOneWidget);
      await _scrollTo(tester, find.text(l.branchWorksAt(2)));
      expect(find.text(l.branchWorksAt(2)), findsOneWidget);
      await _scrollTo(tester, find.byKey(const ValueKey('hire-biscuit')));
      expect(_enabled(tester, 'hire-biscuit'), isFalse, reason: 'hết chỗ');

      // Còn chỗ: Biscuit thuê được, Cocoa (cấp 12) bị khoá bởi cấp Mai 8.
      await pumpTown(tester, [_branch(level: 8, onHire: hired.add)]);
      await _scrollTo(tester, find.byKey(const ValueKey('hire-biscuit')));
      expect(_enabled(tester, 'hire-biscuit'), isTrue);
      await tester.tap(find.byKey(const ValueKey('hire-biscuit')));
      expect(hired, ['biscuit']);
      await _scrollTo(tester, find.byKey(const ValueKey('hire-cocoa')));
      expect(_enabled(tester, 'hire-cocoa'), isFalse);
      expect(find.text(l.branchNeedMaiLevel(12)), findsOneWidget);
      expect(find.text(l.branchHire(3500)), findsWidgets);
    });

    testWidgets('Cho nghỉ có xác nhận và nêu số xu hoàn 50%; Huỷ / Esc không gọi', (tester) async {
      final l = await l10n('en');
      final gone = <String>[];
      final staff = [const StaffMember(id: 'ami', lotId: 's1', since: 0)];
      await pumpTown(tester, [_branch(staff: staff, onDismiss: gone.add)]);
      await _scrollTo(tester, find.byKey(const ValueKey('dismiss-ami')));
      expect(
        find.descendant(of: find.byKey(const ValueKey('staff-ami')), matching: find.text(l.staffEffectBonus(20))),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('dismiss-ami')));
      await tester.pump();
      expect(find.text(l.branchDismissConfirm('Ami', 1750)), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l.branchDismissConfirm('Ami', 1750)), findsNothing);
      expect(gone, isEmpty);

      await tester.tap(find.byKey(const ValueKey('dismiss-ami')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-ok')));
      await tester.pump();
      expect(gone, ['ami']);
    });
  });

  group('Minimap / bản đồ lớn', () {
    const size = Size(480, 320); // quận 48×32 m → 10 px/m
    Offset center(String id) => TownMapPainter.lotRect(_district, _district.lot(id), size).deflate(1).center;

    Widget painted(GlobalKey key, TownBranchMarks? marks) => Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(
          size: size,
          child: CustomPaint(
            painter: TownMapPainter(
              district: _district,
              maiPos: ValueNotifier(Offset.zero),
              branches: marks,
            ),
          ),
        ),
      ),
    );

    testWidgets('lô đã mua tô màu nhấn s1/s3/s4; không có marks thì giữ màu cũ', (tester) async {
      final key = GlobalKey();
      await pumpTown(tester, [painted(key, null)]);
      var px = await _pixels(tester, key);
      for (final id in ['s1', 's3', 's4']) {
        expect(px(center(id)), townLotColor(LotKind.branch), reason: id);
      }

      await pumpTown(tester, [painted(key, const TownBranchMarks(owned: {'s1', 's3', 's4'}))]);
      px = await _pixels(tester, key);
      expect(px(center('s1')), AppColors.strawberry);
      expect(px(center('s3')), AppColors.mint);
      expect(px(center('s4')), AppColors.butter);
    });

    testWidgets('huy hiệu đồng xu chỉ ở lô két đầy', (tester) async {
      final key = GlobalKey();
      await pumpTown(tester, [painted(key, const TownBranchMarks(owned: {'s1', 's3'}, full: {'s3'}))]);
      final px = await _pixels(tester, key);
      Offset badge(String id) =>
          TownBranchMarks.coinBounds(TownMapPainter.lotRect(_district, _district.lot(id), size).deflate(1)).center;
      expect(px(badge('s3')), const Color(0xFFFFC857));
      expect(px(badge('s1')), AppColors.strawberry);
    });

    testWidgets('TownMinimap vẽ lại khi marks đổi', (tester) async {
      final key = GlobalKey();
      final marks = ValueNotifier(TownBranchMarks.none);
      addTearDown(marks.dispose);
      final pos = ValueNotifier(Offset.zero);
      addTearDown(pos.dispose);
      await pumpTown(tester, [
        Center(
          child: RepaintBoundary(
            key: key,
            child: TownMinimap(district: _district, maiPos: pos, onTap: () {}, branches: marks, width: 480),
          ),
        ),
      ]);
      var px = await _pixels(tester, key);
      expect(px(center('s1')), townLotColor(LotKind.branch));
      marks.value = const TownBranchMarks(owned: {'s1'});
      await tester.pump();
      px = await _pixels(tester, key);
      expect(px(center('s1')), AppColors.strawberry);
    });

    testWidgets('bản đồ lớn ghi "Cấp L" cho lô đã mua, không ghi "đã mở" cho lô đó', (tester) async {
      final l = await l10n('en');
      await pumpTown(tester, [
        TownMapSheet(
          district: _district,
          maiPos: ValueNotifier(Offset.zero),
          playerLevel: 15,
          branches: const TownBranchMarks(owned: {'s1'}, levels: {'s1': 3}, full: {'s1'}),
          onClose: () {},
        ),
      ]);
      expect(find.text(l.cityMaiLevel(3)), findsOneWidget);
      expect(find.text(l.townLotUnlocked), findsNWidgets(2), reason: 's3, s4 chưa mua');
    });
  });

  group('BranchDoubleChip', () {
    testWidgets('chạm gọi onTap; tự ẩn sau visibleFor và gọi onExpired', (tester) async {
      var taps = 0, expired = 0;
      await pumpTown(tester, [
        Center(
          child: BranchDoubleChip(
            coins: 1200,
            visibleFor: const Duration(seconds: 2),
            onTap: () => taps++,
            onExpired: () => expired++,
          ),
        ),
      ]);
      final l = await l10n('en');
      expect(find.textContaining(l.offlineDouble), findsOneWidget);
      expect(tester.getSize(find.byType(BranchDoubleChip)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(BranchDoubleChip));
      expect(taps, 1);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byType(BranchDoubleChip), findsOneWidget);
      expect(find.textContaining(l.offlineDouble), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining(l.offlineDouble), findsNothing);
      expect(expired, 1);
    });
  });

  group('Vùng chạm và tràn chữ', () {
    const sizes = [Size(1280, 720), Size(1600, 720), Size(800, 360)];

    testWidgets('nút ≥ 48 dp', (tester) async {
      await pumpTown(tester, [_branch(staff: const [StaffMember(id: 'ami', lotId: 's1', since: 0)])]);
      for (final k in ['collect', 'upgrade', 'panel-close']) {
        final r = tester.getRect(find.byKey(ValueKey(k)));
        expect(r.height, greaterThanOrEqualTo(48), reason: k);
        expect(r.width, greaterThanOrEqualTo(48), reason: k);
      }
      await _scrollTo(tester, find.byKey(const ValueKey('dismiss-ami')));
      expect(tester.getSize(find.byKey(const ValueKey('dismiss-ami'))).height, greaterThanOrEqualTo(48));
      await pumpTown(tester, [_realty()]);
      expect(tester.getSize(find.byKey(const ValueKey('buy-s1'))).height, greaterThanOrEqualTo(48));
    });

    for (final locale in ['en', 'vi']) {
      for (final size in sizes) {
        testWidgets('không tràn: $locale ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
          final staff = [
            const StaffMember(id: 'ami', lotId: 's1', since: 0),
            const StaffMember(id: 'hanh', lotId: 's3', since: 0),
          ];
          // Bảng chi nhánh: cuộn hết, rồi mở xác nhận cho nghỉ.
          await pumpTown(
            tester,
            [_branch(view: _view(slots: 2), staff: staff, level: 20, clockBehind: true)],
            locale: locale,
            size: size,
          );
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
          await tester.pump();
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
          await tester.pump();
          await _scrollTo(tester, find.byKey(const ValueKey('dismiss-ami')));
          await tester.tap(find.byKey(const ValueKey('dismiss-ami')));
          await tester.pump();
          expect(find.byKey(const ValueKey('confirm-ok')), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Bảng địa ốc: có panel xác nhận.
          await pumpTown(tester, [_realty(owned: {'s1'}, coins: 9000, level: 10)], locale: locale, size: size);
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await pumpTown(tester, [_realty()], locale: locale, size: size);
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('buy-s1')));
          await tester.pump();
          expect(find.byKey(const ValueKey('confirm-ok')), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Bản đồ lớn có "Cấp L".
          await pumpTown(
            tester,
            [
              TownMapSheet(
                district: _district,
                maiPos: ValueNotifier(Offset.zero),
                playerLevel: 15,
                branches: const TownBranchMarks(owned: {'s1', 's3'}, levels: {'s1': 5, 's3': 2}, full: {'s1'}),
                onClose: () {},
              ),
            ],
            locale: locale,
            size: size,
          );
          expect(tester.takeException(), isNull);

          // Chip x2 với số xu lớn.
          await pumpTown(
            tester,
            [Align(alignment: Alignment.bottomRight, child: BranchDoubleChip(coins: 1234567, onTap: () {}))],
            locale: locale,
            size: size,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('số xu có dấu tách nghìn theo ngôn ngữ (vi dùng dấu chấm)', (tester) async {
    await pumpTown(tester, [_realty()], locale: 'vi');
    expect(find.text('8.000'), findsOneWidget);
    await pumpTown(tester, [_branch(view: _view(till: 1234, cap: 12000))], locale: 'vi');
    expect(find.text('1.234 / 12.000'), findsOneWidget);
  });
}
