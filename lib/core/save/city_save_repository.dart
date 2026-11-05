/// Nơi đọc / ghi save v3 (một chuỗi JSON) và đọc save v2 cũ. Save v2 CHỈ ĐỌC: không có hàm ghi hay xoá khoá v2.
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

abstract class CitySaveRepository {
  Future<String?> readV3();
  Future<void> writeV3(String d);

  /// Chuỗi save v2 (khoá cũ `sugarleaf_save_v1`); null = không có.
  Future<String?> readV2();

  /// Chép chuỗi v3 hỏng sang chỗ dự phòng, không đè bản dự phòng đã có.
  Future<void> backupCorrupt(String d);
}

/// shared_preferences **API cũ** (`SharedPreferences.getInstance()`; Android: SharedPreferences, web: localStorage).
/// Không dùng `SharedPreferencesAsync`: trên Android nó lưu ở chỗ khác nên không thấy save v2.
class PrefsCitySaveRepository implements CitySaveRepository {
  PrefsCitySaveRepository();

  static const v3Key = 'sugarleaf_save_v3';

  /// Bản dự phòng đầu tiên; các lần sau thêm hậu tố thời điểm (ms) để không đè.
  static const corruptKey = 'sugarleaf_save_v3_corrupt';

  /// Khoá của save v2 (tên lịch sử từ v1). Chỉ đọc.
  static const v2Key = 'sugarleaf_save_v1';

  Future<SharedPreferences>? _prefs;

  /// Lỗi khi lấy instance → bỏ Future đã nhớ để lần sau thử lại.
  Future<SharedPreferences> get _instance {
    final cached = _prefs;
    if (cached != null) return cached;
    final future = SharedPreferences.getInstance();
    _prefs = future;
    return future.catchError((Object e) {
      if (identical(_prefs, future)) _prefs = null;
      throw e;
    });
  }

  @override
  Future<String?> readV3() async => (await _instance).getString(v3Key);

  @override
  Future<void> writeV3(String d) async {
    if (!await (await _instance).setString(v3Key, d)) {
      throw StateError('Không ghi được $v3Key');
    }
  }

  @override
  Future<String?> readV2() async => (await _instance).getString(v2Key);

  @override
  Future<void> backupCorrupt(String d) async {
    final prefs = await _instance;
    var target = corruptKey;
    var ms = DateTime.now().millisecondsSinceEpoch;
    while (prefs.containsKey(target)) {
      target = '${corruptKey}_${ms++}';
    }
    if (!await prefs.setString(target, d)) {
      throw StateError('Không ghi được $target');
    }
  }
}

/// Lưu trong bộ nhớ: `?save=memory` (thử nhanh, không đụng save thật) và test.
class MemoryCitySaveRepository implements CitySaveRepository {
  MemoryCitySaveRepository({this.v3, this.v2});

  /// Chuỗi v3 / v2 đang lưu (null = chưa có).
  String? v3;
  String? v2;

  /// Các bản dự phòng đã chép (cũ → mới).
  final List<String> backups = [];

  /// Số lần ghi v3 thành công.
  int writeCount = 0;

  /// true → [readV3] / [readV2] ném lỗi.
  bool failRead = false;

  /// true → [writeV3] ném lỗi (không đổi [v3]).
  bool failWrite = false;

  /// Khác null → [writeV3] chờ Future này xong mới ghi (giả lập bộ nhớ chậm).
  Completer<void>? writeGate;

  @override
  Future<String?> readV3() async {
    if (failRead) throw StateError('failRead');
    return v3;
  }

  @override
  Future<void> writeV3(String d) async {
    final gate = writeGate;
    if (gate != null) await gate.future;
    if (failWrite) throw StateError('failWrite');
    v3 = d;
    writeCount++;
  }

  @override
  Future<String?> readV2() async {
    if (failRead) throw StateError('failRead');
    return v2;
  }

  @override
  Future<void> backupCorrupt(String d) async {
    backups.add(d);
  }
}
