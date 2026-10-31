import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/common/format.dart';

/// [formatCompact]: số trên thanh tiền tệ rút gọn từ 1 triệu (UI-06: thanh trên bản đồ tràn khi xu rất lớn).
Future<String> _fmt(WidgetTester tester, String lang, int value) async {
  late String out;
  await tester.pumpWidget(Localizations(
    locale: Locale(lang),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Builder(builder: (context) {
      out = formatCompact(context, value);
      return const SizedBox();
    }),
  ));
  return out;
}

void main() {
  testWidgets('dưới 1 triệu giữ đủ số', (tester) async {
    expect(await _fmt(tester, 'en', 999999), '999,999');
    expect(await _fmt(tester, 'vi', 999999), '999.999');
    expect(await _fmt(tester, 'en', 0), '0');
  });

  testWidgets('từ 1 triệu rút gọn theo ngôn ngữ', (tester) async {
    // vi: khoảng trắng không ngắt dòng (U+00A0) giữa số và đơn vị.
    for (final (lang, v, want) in [
      ('en', 1000000, '1M'),
      ('en', 1234567, '1.2M'),
      ('en', 99999999, '100M'),
      ('en', 999999999, '1B'),
      ('vi', 1234567, '1,2 Tr'),
      ('vi', 999999999, '1 T'),
    ]) {
      expect(await _fmt(tester, lang, v), want, reason: '$lang $v');
    }
  });
}
