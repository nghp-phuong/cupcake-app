import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/constants.dart';
import 'package:sugarleaf_bakery/ui/common/panel.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

import 'sugarleaf/sl_test_helpers.dart';

/// Viền run tay của `Panel` theo seed CỐ ĐỊNH: giống nhau giữa các lần chạy (không lấy từ `hashCode`/`Object.hash`).
void main() {
  test('Panel.seedFor là hằng số (djb2 của "ARGB|bo góc"), không đổi theo lần chạy', () {
    expect(Panel.seedFor(Colors.white, 22), 0xB768A82A); // "4294967295|22.0"
    expect(Panel.seedFor(AppColors.cream, 26), 0x297EDFC6); // "4294964454|26.0"
  });

  testWidgets('dựng Panel hai lần (giả lập hai lần chạy) → SLPanel nhận cùng seed', (tester) async {
    final seeds = <int?>[];
    for (var run = 0; run < 2; run++) {
      await pumpSL(
        tester,
        (_) => Center(
          key: ValueKey(run), // cây khác nhau mỗi lần dựng.
          child: const Panel(width: 300, height: 120, child: Text('Hi')),
        ),
      );
      seeds.add(tester.widget<SLPanel>(find.byType(SLPanel)).seed);
    }
    expect(seeds, [0xB768A82A, 0xB768A82A]);

    await pumpSL(tester, (_) => const Center(child: Panel(seed: 7, child: Text('Hi'))));
    expect(tester.widget<SLPanel>(find.byType(SLPanel)).seed, 7);
  });

  test('lib/ui không lấy seed nét vẽ từ hashCode / Object.hash / identityHashCode / Random() không seed', () {
    final bad = RegExp(r'seed.*(\.hashCode|Object\.hash|identityHashCode)|(\.hashCode|Object\.hash|identityHashCode).*seed'
        r'|Painter\([^)]*\.hashCode|Random\(\)');
    for (final f in Directory('lib/ui').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Khoá cache (operator ==/hashCode của spec) được phép dùng Object.hash; chú thích bỏ qua.
        if (line.startsWith('int get hashCode') || line.startsWith('//')) continue;
        expect(bad.hasMatch(line), isFalse, reason: '${f.path}:${i + 1}: $line');
      }
    }
  });
}
