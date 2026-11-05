import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/weather.dart';

void main() {
  group('Weather', () {
    test('ngày 1–4 tạnh, ngày 5 mưa', () {
      for (var d = -2; d <= 4; d++) {
        expect(Weather.isRainy(d), isFalse, reason: 'ngày $d');
      }
      expect(Weather.isRainy(5), isTrue);
      expect(Weather.isRainy(6), isFalse);
    });

    test('từ ngày 6 theo công thức, không bao giờ mưa hai ngày liền', () {
      for (var d = 6; d <= 400; d++) {
        final formula = (d * 37 + 11) % 4 == 0;
        final expected = formula && !Weather.isRainy(d - 1);
        expect(Weather.isRainy(d), expected, reason: 'ngày $d');
        if (Weather.isRainy(d)) expect(Weather.isRainy(d - 1), isFalse, reason: 'ngày $d');
      }
    });

    test('khoảng 25% trên 400 ngày, gọi lại ra cùng kết quả', () {
      final first = [for (var d = 1; d <= 400; d++) Weather.isRainy(d)];
      final second = [for (var d = 1; d <= 400; d++) Weather.isRainy(d)];
      expect(second, first);
      final rainy = first.where((r) => r).length;
      expect(rainy / 400, closeTo(0.25, 0.03));
    });
  });
}
