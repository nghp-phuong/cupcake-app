import 'package:flutter/foundation.dart';

/// Đồ hoạ đã dựng sẵn (Picture + Path) nằm trong cache; [dispose] giải phóng khi bị đẩy ra.
abstract interface class SLCachedArt {
  void dispose();
}

/// Cache LRU giới hạn số mục (LinkedHashMap: cuối = dùng gần nhất). Đếm trúng/trượt và thời gian dựng.
class SLLru<K, V extends SLCachedArt> {
  SLLru(this.maxEntries);

  final int maxEntries;
  final _map = <K, V>{};
  int hits = 0;
  int misses = 0;

  /// Tổng micro giây đã dùng để dựng các mục bị trượt.
  int buildMicros = 0;

  int get length => _map.length;

  bool containsKey(K key) => _map.containsKey(key);

  /// Lấy mục [key]; chưa có thì gọi [build] (đo thời gian), thêm vào và đẩy mục cũ nhất ra nếu đầy.
  V obtain(K key, V Function() build) {
    final hit = _map.remove(key);
    if (hit != null) {
      hits++;
      _map[key] = hit;
      return hit;
    }
    misses++;
    final sw = Stopwatch()..start();
    final value = build();
    buildMicros += sw.elapsedMicroseconds;
    _map[key] = value;
    while (_map.length > maxEntries) {
      _map.remove(_map.keys.first)!.dispose();
    }
    return value;
  }

  void clear() {
    for (final v in _map.values) {
      v.dispose();
    }
    _map.clear();
    hits = 0;
    misses = 0;
    buildMicros = 0;
  }
}

/// Hai cache dùng chung của bộ SL*: khung/nền (viền run tay + màu nước) và icon vẽ bằng code.
abstract final class SLPaintCache {
  /// Mỗi cache giữ tối đa chừng này hình (khoảng vài chục KB/hình — Picture chỉ là danh sách lệnh vẽ).
  static const maxEntries = 128;

  static final surfaces = SLLru<Object, SLCachedArt>(maxEntries);
  static final icons = SLLru<Object, SLCachedArt>(maxEntries);

  /// Tóm tắt cho thanh hiệu năng của Gallery.
  static String describe() {
    String one(String name, SLLru<Object, SLCachedArt> c) {
      final avg = c.misses == 0 ? 0 : c.buildMicros / c.misses / 1000;
      return '$name ${c.length}/$maxEntries · hit ${c.hits} · miss ${c.misses} · dựng TB ${avg.toStringAsFixed(2)} ms';
    }

    return '${one('khung', surfaces)}  |  ${one('icon', icons)}';
  }

  @visibleForTesting
  static void debugClear() {
    surfaces.clear();
    icons.clear();
  }
}
