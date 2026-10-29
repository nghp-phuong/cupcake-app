import 'package:shared_preferences/shared_preferences.dart';

/// Nơi lưu một chuỗi JSON của ván chơi.
abstract class SaveRepository {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();

  /// Chép chuỗi lưu hỏng sang chỗ dự phòng (không đè bản dự phòng đã có) trước khi ván mới ghi đè.
  Future<void> backupCorrupt(String data);
}

/// Lưu bằng shared_preferences (Android: SharedPreferences, web: localStorage).
class PrefsSaveRepository implements SaveRepository {
  PrefsSaveRepository();

  static const key = 'sugarleaf_save_v1';

  /// Bản dự phòng đầu tiên; các lần hỏng sau đặt thêm hậu tố thời điểm (ms) để không đè.
  static const corruptKey = 'sugarleaf_save_v1_corrupt';

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
  Future<String?> read() async => (await _instance).getString(key);

  @override
  Future<void> write(String data) async {
    await (await _instance).setString(key, data);
  }

  @override
  Future<void> clear() async {
    await (await _instance).remove(key);
  }

  @override
  Future<void> backupCorrupt(String data) async {
    final prefs = await _instance;
    final target = prefs.containsKey(corruptKey) ? '${corruptKey}_${DateTime.now().millisecondsSinceEpoch}' : corruptKey;
    await prefs.setString(target, data);
  }
}

/// Lưu trong bộ nhớ — dùng cho test.
class MemorySaveRepository implements SaveRepository {
  MemorySaveRepository([String? initial]) : data = initial;

  /// Chuỗi đang lưu (null = chưa có).
  String? data;

  /// Các bản dự phòng đã chép (cũ → mới).
  final List<String> backups = [];

  /// Số lần `write` được gọi (test kiểm autosave).
  int writeCount = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async {
    this.data = data;
    writeCount++;
  }

  @override
  Future<void> clear() async {
    data = null;
  }

  @override
  Future<void> backupCorrupt(String data) async {
    backups.add(data);
  }
}
