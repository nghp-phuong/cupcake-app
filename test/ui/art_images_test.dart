import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/ui/common/art.dart';
import 'package:sugarleaf_bakery/ui/common/shop_scene.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

Widget _icons() => const MaterialApp(
  home: Row(
    children: [
      ArtIcon(ArtSprites.book, fallback: Icons.menu_book_rounded),
      CoinIcon(),
      StarIcon(filled: false),
    ],
  ),
);

void main() {
  tearDown(ArtSprites.debugReset);

  testWidgets('ảnh vẽ tay đã nạp → ArtIcon vẽ ảnh thay cho icon Material', (tester) async {
    ArtSprites.debugReset();
    // Nạp ảnh thật phải chạy trong runAsync (giải mã ảnh cần vòng lặp thật).
    await tester.runAsync(() => ArtSprites.preload([ArtSprites.book, ArtSprites.shopBase]));
    await tester.pumpWidget(_icons());
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byType(SLIcon), findsNothing);
    expect(find.byType(SLArtIcon), findsOneWidget); // sách: ArtIcon vẽ qua SLArtIcon (ảnh, không SLIcon).
    expect(find.byType(ArtImage), findsNWidgets(2)); // xu + sao.
    expect(ShopScene.usesArt(const {}), isTrue);
  });

  testWidgets('chưa nạp ảnh → icon vẽ bằng code (không dùng Material Icons), cảnh tiệm vẽ bằng ShopArt', (tester) async {
    ArtSprites.debugReset();
    await tester.pumpWidget(_icons());
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(tester.widget<SLIcon>(find.byType(SLIcon)).id, 'book');
    expect(ShopScene.usesArt(const {DecorSlot.plant: DecorId.plantFern}), isFalse);
  });

  testWidgets('đĩa dưới bánh: có ảnh plate_serving → vẽ ảnh; chưa nạp → bản vẽ code, không lỗi', (tester) async {
    const plate = MaterialApp(home: Center(child: SizedBox(width: 196, height: 44, child: SLPlate())));
    ArtSprites.debugReset();
    // Nạp ảnh thật trước khi dựng (ảnh xếp hàng trong lúc dựng sẽ nạp ở fake async, không xong).
    await tester.runAsync(() => ArtSprites.preload([SLPlate.art]));
    expect(SLPlate.art.image, isNotNull);
    await tester.pumpWidget(plate);
    expect(tester.takeException(), isNull);
    ArtSprites.debugReset();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(plate);
    expect(tester.takeException(), isNull);
  });
}
