import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sugarleaf.dart';

/// Tên mọi `Icons.xxx` trong các file Dart dưới [paths] (file hoặc thư mục).
Set<String> _materialIconsUsed(List<String> paths) {
  final re = RegExp(r'Icons\.([a-z][a-zA-Z0-9_]*)');
  final names = <String>{};
  for (final path in paths) {
    final files = FileSystemEntity.isDirectorySync(path)
        ? Directory(path).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
        : [File(path)];
    for (final f in files) {
      names.addAll(re.allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
    }
  }
  return names;
}

void main() {
  test('mọi id icon SL đều có hình vẽ bằng code (không hiện hình dự phòng vòng tròn + chữ cái)', () {
    for (final id in kSLIconIds) {
      expect(slIconHasDrawing(id), isTrue, reason: id);
    }
    expect(kSLIconIds.toSet().length, kSLIconIds.length, reason: 'id trùng');
  });

  test('bảng ánh xạ chỉ trỏ tới id có thật', () {
    for (final e in kSLIconForMaterial.entries) {
      expect(kSLIconIds, contains(e.value), reason: '${e.key} → ${e.value}');
    }
  });

  test('bảng ánh xạ phủ mọi Icons.* đang dùng trong lib/ui và màn làm bánh', () {
    final used = _materialIconsUsed(['lib/ui', 'lib/game/bake_session_view.dart'])
      ..remove('xxx'); // ví dụ trong chú thích.
    expect(used, isNotEmpty);
    // Tên → IconData: so theo tên trong mã nguồn bảng ánh xạ (IconData không giữ tên).
    final mapSource = File('lib/ui/sugarleaf/sl_icon_map.dart').readAsStringSync();
    final mapped = RegExp(r'Icons\.([a-z][a-zA-Z0-9_]*):').allMatches(mapSource).map((m) => m.group(1)!).toSet();
    expect(used.difference(mapped), isEmpty, reason: 'thiếu trong kSLIconForMaterial');
    expect(mapped.length, kSLIconForMaterial.length, reason: 'khoá trùng trong bảng');
  });

  test('slIconIdFor: có trong bảng → id; lạ → sparkle', () {
    expect(slIconIdFor(Icons.settings_rounded), 'settings');
    expect(slIconIdFor(Icons.menu_book_rounded), 'book');
    expect(slIconIdOrNull(Icons.airplanemode_active), isNull);
    expect(slIconIdFor(Icons.airplanemode_active), 'sparkle');
  });
}
