import 'dart:math' as math;
import 'dart:ui';

/// Toạ độ cố định của màn chơi level trong khung 1280×720 (HUD của ui vẽ đè ở y 0–64).
///
/// Sân tiệm: ảnh `shop/shop_base_empty` (1280×720, tủ kính trống) vẽ tỉ lệ 1:1, cắt dải ảnh y [shopArtTop]..
/// [shopArtTop]+440 vào y 0..440 → mọi toạ độ của tủ / quầy dưới đây = toạ độ trong ảnh − [shopArtTop].
abstract final class LevelLayout {
  static const double hudBottom = 64;
  static const double kitchenTop = 440;

  /// Vùng sân tiệm có thao tác (dưới HUD).
  static const Rect shop = Rect.fromLTRB(0, hudBottom, 1280, kitchenTop);
  static const Rect kitchen = Rect.fromLTRB(0, kitchenTop, 1280, 720);

  /// Dòng ảnh nền tiệm đặt ở y = 0.
  static const double shopArtTop = 96;

  // ------------------------------------------------------------------ Tủ kính + quầy

  /// Tủ kính bánh: ảnh `level/display_case` (792×363) vẽ thành tủ MỘT tầng (cắt bỏ dải kệ kính giữa ảnh), cao theo
  /// [caseArtScale], hai đầu cong giữ tỉ lệ, phần giữa kéo ngang cho đủ bề rộng; chân gỗ khuất sau bếp. Tủ này vẽ đè
  /// lên tủ nhỏ có sẵn trong ảnh nền (che kín, ảnh nền: x 435–849, nóc y 284) và lên khách đứng sau. Tủ to hơn tủ của
  /// ảnh nền để bánh to, nhìn rõ món + topping trên điện thoại: mép trái sát máy tính tiền, mép phải chừa chỗ kệ tầng.
  static const Rect caseRect = Rect.fromLTRB(416, 268, 920, kitchenTop);

  /// Tỉ lệ ảnh tủ (theo chiều cao; hai đầu cong cùng tỉ lệ).
  static const double caseArtScale = 0.8;

  /// Viền ngoài tủ (nóc gỗ + hai vách kính cong) — tủ vẽ code dự phòng khi chưa có ảnh.
  static final Path caseOutline = Path()
    ..moveTo(caseRect.left + 8, kitchenTop)
    ..lineTo(caseRect.left + 10, 352)
    ..cubicTo(caseRect.left + 12, 316, caseRect.left + 28, 282, caseRect.left + 74, 270)
    ..lineTo(caseRect.right - 74, 270)
    ..cubicTo(caseRect.right - 28, 282, caseRect.right - 12, 316, caseRect.right - 10, 352)
    ..lineTo(caseRect.right - 8, kitchenTop)
    ..close();

  /// Lòng kính (giữa hai vách, dưới nóc gỗ, tới mép trước sàn tủ) — các cột bánh nằm trong.
  static const Rect caseGlass = Rect.fromLTRB(440, 288, 896, 428);

  /// Đáy bánh hàng trước (trên sàn tủ). Hàng sau đứng lùi vào trong: đáy cao hơn [caseBackLift] × cạnh bánh, nhỏ đi
  /// [caseBackScale] → lộ nửa trên (phần topping) phía trên hàng trước.
  static const double caseFrontY = 424;
  static const double caseBackLift = 0.5;
  static const double caseBackScale = 0.92;

  /// Mặt sau quầy trái / phải trong ảnh (khách đứng sau quầy bị che từ đây xuống).
  static const double leftCounterTop = 358;
  static const double rightCounterTop = 342;

  /// Máy tính tiền trên quầy trái (ảnh: thân x 338–440, y 400–468; màn nhỏ phía trên x 352–398, y 383–400): che
  /// khách đứng sau.
  static const Rect register = Rect.fromLTRB(338, 304, 440, leftCounterTop);
  static const Rect registerDisplay = Rect.fromLTRB(352, 287, 398, 304);

  /// Vùng được vẽ khách: phía sau quầy trái (trừ máy tính tiền), cả cột tủ kính (vẽ lại tủ đè lên), phía sau quầy phải.
  static final Path customerClip = Path()
    ..addRect(Rect.fromLTRB(0, 0, register.right, registerDisplay.top))
    ..addRect(Rect.fromLTRB(0, registerDisplay.top, registerDisplay.left, register.top))
    ..addRect(Rect.fromLTRB(registerDisplay.right, registerDisplay.top, register.right, register.top))
    ..addRect(Rect.fromLTRB(0, register.top, register.left, leftCounterTop))
    ..addRect(Rect.fromLTRB(register.right, 0, 846, kitchenTop))
    ..addRect(const Rect.fromLTRB(846, 0, 1280, rightCounterTop));

  /// [customerClip] cho khung rộng (thế giới 1280 lệch [inset] = (W − 1280) / 2 trên màn): các dải bám mép trái / phải
  /// kéo thêm [inset] ra hai bên (khách hàng chờ / đi ra cửa thấy được tới mép màn). [inset] ≤ 0 → [customerClip].
  static Path customerClipFor(double inset) {
    if (inset <= 0) return customerClip;
    if (inset == _wideClipInset) return _wideClip!;
    _wideClipInset = inset;
    return _wideClip = Path()
      ..addRect(Rect.fromLTRB(-inset, 0, register.right, registerDisplay.top))
      ..addRect(Rect.fromLTRB(-inset, registerDisplay.top, registerDisplay.left, register.top))
      ..addRect(Rect.fromLTRB(registerDisplay.right, registerDisplay.top, register.right, register.top))
      ..addRect(Rect.fromLTRB(-inset, register.top, register.left, leftCounterTop))
      ..addRect(Rect.fromLTRB(register.right, 0, 846, kitchenTop))
      ..addRect(Rect.fromLTRB(846, 0, 1280 + inset, rightCounterTop));
  }

  static double _wideClipInset = 0;
  static Path? _wideClip;

  /// Chiều cao khung ảnh nhân vật (3:4) ở tỉ lệ 1 (khách ở quầy đứng ở [counterScale]).
  static const double customerHeight = 240;

  /// Tỉ lệ khách ở quầy / chỗ đặc biệt (và thu ngân): nhân vật cân với đồ đạc của ảnh nền (khung cao 348).
  static const double counterScale = 1.45;

  /// Đáy khung ảnh của khách ở quầy (chân khuất sau tủ / quầy): đỉnh khung y 91, ngực–thắt lưng (~50–56% khung)
  /// ngang nóc tủ (y 270) → lộ từ đầu tới ngực; bong bóng (đỉnh khung + 30 × tỉ lệ) nằm dưới HUD.
  static const double counterFloor = 439;

  /// Đáy khung ảnh của khách đặc biệt ở mép trái quầy (x [specialX], trái máy tính tiền nên không có tủ che): thấp hơn
  /// chỗ quầy → mặt quầy trái (y 358) cắt ngang hông (~68% khung), đầu vẫn dưới HUD.
  static const double specialFloor = 470;

  /// Khoảng cách tối đa giữa hai chỗ quầy: đủ cho bong bóng gọi món ([bubbleWidth]) nằm giữa mặt khách này và mặt
  /// khách bên phải.
  static const double counterGap = 190;

  /// Chỗ đứng quầy thứ [i] trong [n] chỗ (sau tủ kính, dàn trong ±[counterGap] quanh giữa tủ).
  static double counterX(int i, int n) {
    if (n <= 1) return caseRect.center.dx;
    final spacing = math.min(counterGap, counterGap * 2 / (n - 1));
    return caseRect.center.dx + (i - (n - 1) / 2) * spacing;
  }

  /// Chỗ khách đặc biệt (mép trái quầy, trước chậu cây; thân sát trái thu ngân).
  static const double specialX = 322;

  /// Hàng chờ (0 = đầu hàng, gần quầy) kéo về cửa bên phải, bắt đầu sau bong bóng của chỗ quầy cuối; xa hơn → nhỏ
  /// hơn, đứng cao hơn.
  static double queueX(int k) => math.min(1272.0, 1050 + queueGap * math.min(k, 3) + 6.0 * math.max(0, k - 3));
  static double queueScale(int k) => math.max(0.9, 1.2 - 0.06 * k);
  static double queueFloor(int k) => floorFor(queueScale(k));

  // ------------------------------------------------------------------ Đồ mua thêm (GĐ3)

  /// Kệ bánh tầng (ảnh `level/case_stand` 264×360) trên quầy phải, sát vách phải tủ kính; đáy chân kệ ở mép trước
  /// mặt quầy; đỉnh kệ dưới mép bong bóng của chỗ quầy cuối.
  static const Rect standRect = Rect.fromLTWH(926, 199, 140, 191);

  /// Trong ảnh kệ (tỉ lệ theo cao ảnh): mặt tầng trên / dưới (chỗ đáy bánh), nửa bề ngang mặt đĩa mỗi tầng (tỉ lệ
  /// theo ngang ảnh). Bánh tầng dưới (gần mắt hơn) vẽ đè lên mép đĩa tầng trên.
  static const double standUpperY = 0.312, standLowerY = 0.628;
  static const double standUpperHalfW = 0.40, standLowerHalfW = 0.47;

  /// Cạnh một cái bánh trên kệ tầng.
  static const double standCake = 60;

  /// Hai bộ bàn ghế (ảnh `level/cafe_table` 420×309): vẽ ở độ sâu [tableDepth] (như khách hàng chờ cùng tỉ lệ), đáy
  /// chân ở [tableFloor]; phần dưới khuất sau quầy. Trái: góc tường trái (sau quầy trái); phải: trước cửa sổ, phải kệ.
  static const double tableDepth = 1.0;
  static const double tableWidth = 188;
  static const double tableFloor = 376;
  static const List<double> tableX = [96, 1170];

  /// Cây trang trí (ảnh decor 512×512, chậu/giỏ ở đáy ảnh): chậu đặt trên quầy sau (bên trái máy tính tiền), giữa
  /// bàn trái và chỗ khách đặc biệt (khách đặc biệt đứng trước cây; tán lá lấn sau máy tính tiền bị che).
  static const Rect plantRect = Rect.fromLTWH(222, 178, 168, 168);
  static const double plantDepth = 1.05;

  /// Đồ trang trí quầy (bình hoa / bánh trong chuông kính, ảnh 512×512): trên quầy trái, ngay bên trái chậu cây —
  /// khung không chồng [plantRect] (đặt cả hai vẫn thấy rõ từng món).
  static const Rect counterDecorRect = Rect.fromLTWH(130, 288, 92, 92);

  /// Chỗ thứ [k] của hàng chờ: (x, tỉ lệ). Có kệ tầng → hàng lùi sang phải nhường chỗ kệ; có bàn ghế → khách chờ
  /// đứng quanh bàn phải (trái bàn, phải bàn, sau bàn) rồi dồn về cửa. Hai chỗ đầu (cùng hàng trước, gần cùng tỉ lệ)
  /// cách nhau ≥ [queueGap] để thấy rõ từng khách.
  static (double, double) queueSpot(int k, {bool stand = false, bool tables = false}) {
    if (tables) {
      if (k >= _tableQueue.length) return (math.min(1290.0, 1262 + 8.0 * (k - _tableQueue.length)), 0.9);
      return (stand ? _tableQueueStand : _tableQueue)[k];
    }
    if (stand) {
      // Ba chỗ đầu cách [standQueueGap] (kệ tới x 1066), từ chỗ thứ 4 dồn về cửa.
      if (k <= 2) return (1104 + standQueueGap * k, queueScale(k));
      return (math.min(1272.0, 1262 + 5.0 * (k - 3)), 0.9);
    }
    return (queueX(k), queueScale(k));
  }

  /// Khoảng cách giữa hai khách chờ đứng cạnh nhau ở hàng trước (≈ bề ngang thân ở tỉ lệ 1.2); có kệ tầng thì hàng
  /// chật hơn ([standQueueGap]).
  static const double queueGap = 70;
  static const double standQueueGap = 64;

  /// Chỗ chờ quanh bàn phải (bàn x 1076–1264): trái bàn, cạnh ghế trái (trước bàn), phải bàn, sau bàn, sau-trái.
  static const List<(double, double)> _tableQueue = [(1046, 1.2), (1118, 1.14), (1262, 1.1), (1176, 0.9), (1104, 0.88)];

  /// Như [_tableQueue] khi có kệ tầng (kệ tới x 1066): chỗ đầu lùi sang phải, chỗ thứ hai đứng trước ghế trái của bàn;
  /// hai chỗ sau bàn dời theo để lộ giữa các khách hàng trước.
  static const List<(double, double)> _tableQueueStand = [(1104, 1.2), (1170, 1.12), (1262, 1.1), (1214, 0.9), (1130, 0.88)];

  /// Đáy khung ảnh của khách đứng ở tỉ lệ [scale] (xa hơn → nhỏ hơn, cao hơn).
  static double floorFor(double scale) => 402 - (1.2 - scale) * 110;

  /// Cửa (ngoài mép phải khung).
  static const double doorX = 1360;

  /// Cửa khi khung rộng (vùng 1280 lệch [inset] trên màn): vẫn ngoài mép phải MÀN (= 1280 + [inset] + 80 trong toạ độ
  /// thế giới) → khách không hiện ra giữa màn.
  static double doorXFor(double inset) => doorX + math.max(0.0, inset);
  static const double doorScale = 0.8;
  static const double doorFloor = 350;

  /// Tâm thân bong bóng gọi món so với (tâm ngang, đỉnh khung ảnh) của khách, theo tỉ lệ 1 (nhân với tỉ lệ khách).
  static const Offset bubbleOffset = Offset(62, 30);

  /// Bán kính vòng kiên nhẫn (quanh ảnh món, trong thân bong bóng); vùng chạm bong bóng = bán kính này + 18.
  static const double bubbleRadius = 36;

  /// Bề ngang ảnh bong bóng ý nghĩ (320×270) khi vẽ (không theo tỉ lệ khách).
  static const double bubbleWidth = 134;

  /// Bong bóng của khách đặc biệt khi có thu ngân: lật sang trái đầu (phía cây) để không che mặt thu ngân.
  static const Offset bubbleOffsetLeft = Offset(-58, 30);

  // ------------------------------------------------------------------ Nhân viên (GĐ4)

  /// Biểu tượng đồng xu của ô xu trên HUD của ui (y 0–64): đích của đồng xu bay khi nhân viên bán. Ô xu canh mép phải
  /// cố định (x 1108, trái ô combo 150 px) và nở sang trái khi số dài; biểu tượng (32 px) nằm ở mép TRÁI nên di động
  /// theo số chữ số. Đo (Nunito 18 đậm): tâm biểu tượng x 1024 (≤ 3 chữ số), 1022 ("1,234"), 1011 ("12,345"), 1000
  /// ("123,456"), 984 ("1,234,567"). Lấy tâm của ca 4–6 chữ số → lệch ≤ 13 px (< bán kính 16) với 3–6 chữ số.
  static const Offset hudCoins = Offset(1011, 30);

  /// [hudCoins] khi khung rộng: HUD của ui bám mép phải khung W và lùi theo tai thỏ phải ([safeRight], đơn vị ref) nên
  /// ô xu dời W − 1280 − [safeRight] = 2 × [inset] − [safeRight] trên màn, tức + [inset] − [safeRight] trong toạ độ
  /// thế giới (thế giới đã lệch [inset]).
  static Offset hudCoinsFor(double inset, {double safeRight = 0}) {
    final dx = math.max(0.0, inset) - math.max(0.0, safeRight);
    return dx == 0 ? hudCoins : hudCoins.translate(dx, 0);
  }

  /// Thu ngân: sau quầy trái, ngay sau màn máy tính tiền (thân ~362–438, giữa khách đặc biệt và chỗ quầy đầu tiên),
  /// đứng ở [counterScale] như khách ở quầy → máy tính tiền che từ thắt lưng xuống. Xếp độ sâu ngay sau cây
  /// ([cashierDepth]): cây trên quầy và mọi khách ở quầy vẽ đè lên thu ngân.
  static const double cashierX = 400;
  static const double cashierDepth = plantDepth - 0.01;

  /// Thu ngân thứ hai trở đi (chỉ có ở test giả lập) lệch sang trái chừng này.
  static const double cashierLaneGap = 48;

  /// Thợ bánh (làn 1, làn 2): góc sau bên trái, dưới kệ tường, sau bàn trái (độ sâu < [tableDepth] → bàn ghế che
  /// chân); làn 2 cách bong bóng khách đặc biệt (lật trái) và mép trái chậu cây.
  static const List<double> bakerX = [58, 146];
  static const double bakerScale = 0.96;

  /// Phục vụ đứng chờ giữa bàn phải và cửa sổ (sau hàng chờ), tới cạnh khách được phục vụ rồi quay về.
  static const double waiterHomeX = 1196;
  static const double waiterScale = 1.0;

  /// Phục vụ đứng cạnh khách (lệch ngang theo tỉ lệ khách, nhích lên trước một chút để vẽ đè).
  static const double waiterBeside = 62;
  static const double waiterAhead = 0.015;

  /// Tốc độ đi của phục vụ (px/giây ở tỉ lệ 1).
  static const double waiterSpeed = 300;

  /// Vòng tiến độ trên đầu thợ bánh: bán kính, khoảng hở trên đỉnh khung ảnh.
  static const double staffRingRadius = 18;
  static const double staffRingLift = 4;

  // ------------------------------------------------------------------ Bếp nhanh

  /// Cột thẻ món.
  static const Rect cardsArea = Rect.fromLTRB(10, 452, 222, 712);

  /// Thẻ món thứ [i] trong [n] thẻ (1: một thẻ cao, 2: hai thẻ chồng, 3–4: lưới 2×2).
  static Rect cardRect(int i, int n) {
    const a = cardsArea;
    const gap = 6.0;
    if (n <= 1) return a;
    final h = (a.height - gap) / 2;
    if (n == 2) return Rect.fromLTWH(a.left, a.top + i * (h + gap), a.width, h);
    final w = (a.width - gap) / 2;
    return Rect.fromLTWH(a.left + (i % 2) * (w + gap), a.top + (i ~/ 2) * (h + gap), w, h);
  }

  static const double tileLeft = 232;
  static const double tileTop = 452;
  static const double tileWidth = 168;
  static const double tileHeight = 260;
  static const double tileGap = 6;

  /// Ô trạm thứ [i]: 0 Khuôn · 1 Trộn · 2 Lò · 3 Kem · 4 Topping · 5 Hộp.
  static Rect tile(int i) => Rect.fromLTWH(tileLeft + i * (tileWidth + tileGap), tileTop, tileWidth, tileHeight);

  static const int mouldTile = 0, mixTile = 1, ovenTile = 2, frostTile = 3, toppingTile = 4, boxTile = 5;

  /// Hàng lựa chọn thứ [k] (khuôn / hộp) trong ô [t]: 3 hàng cao 70.
  static Rect choiceRow(Rect t, int k) => Rect.fromLTWH(t.left + 6, t.top + 32 + k * 74.0, t.width - 12, 70);

  /// Lò thứ [i] trong [n] lò (chia đều chiều cao ô Lò).
  static Rect ovenSlot(int i, int n) {
    final t = tile(ovenTile);
    final h = (t.height - 30) / math.max(1, n);
    return Rect.fromLTWH(t.left + 4, t.top + 28 + i * h, t.width - 8, h);
  }

  /// Tâm âu trộn.
  static Offset bowlCenter() => tile(mixTile).topCenter.translate(0, 120);

  /// Nút huỷ mẻ đang chuẩn bị (góc dưới phải ô Trộn, dưới vòng khuấy): vùng chạm 64×64, hình tròn ~36.
  static Rect cancelPrep() {
    final t = tile(mixTile);
    return Rect.fromLTWH(t.right - 66, t.bottom - 66, 64, 64);
  }

  /// Bánh ở trạm kem (vùng quẹt).
  static Rect frostCake() => Rect.fromCenter(center: tile(frostTile).topCenter.translate(0, 102), width: 118, height: 118);

  /// Nút Xong ở trạm kem (vẽ cao 46, vùng chạm 64).
  static Rect frostDone() {
    final t = tile(frostTile);
    return Rect.fromLTWH(t.left + 14, t.bottom - 56, t.width - 28, 46);
  }

  /// Bánh ở trạm topping.
  static Rect toppingCake() => Rect.fromCenter(center: tile(toppingTile).topCenter.translate(0, 88), width: 104, height: 104);

  /// Hũ topping thứ [k] (2 hũ).
  static Rect toppingJar(int k) {
    final t = tile(toppingTile);
    final w = (t.width - 18) / 2;
    return Rect.fromLTWH(t.left + 6 + k * (w + 6), t.top + 164, w, 90);
  }
}
