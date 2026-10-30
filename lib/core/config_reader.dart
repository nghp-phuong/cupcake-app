/// Đọc trường JSON có kiểm tra cho các file cấu hình (`levels.json`, `unlocks.json`); lỗi ghi
/// `nơi: trường "khoá": lý do` (ném [FormatException]).
library;

import 'models/ids.dart';

/// Đọc trường có kiểm tra; lỗi ghi `nơi: trường "khoá": lý do`.
class ConfigReader {
  ConfigReader(this.json, this.where);

  final Map<String, dynamic> json;
  final String where;

  Never fail(String key, String reason) => throw FormatException('$where: trường "$key": $reason');

  bool has(String key) => json[key] != null;

  Object _required(String key) => json[key] ?? fail(key, 'thiếu');

  int integer(String key, {int? min}) {
    final v = _required(key);
    if (v is! num || v != v.toInt()) fail(key, 'phải là số nguyên, có $v');
    final n = v.toInt();
    if (min != null && n < min) fail(key, 'phải ≥ $min, có $n');
    return n;
  }

  double number(String key, {double? min}) {
    final v = _required(key);
    if (v is! num) fail(key, 'phải là số, có $v');
    final d = v.toDouble();
    if (!d.isFinite) fail(key, 'không hữu hạn');
    if (min != null && d < min) fail(key, 'phải ≥ $min, có $d');
    return d;
  }

  String string(String key) {
    final v = _required(key);
    if (v is! String || v.isEmpty) fail(key, 'phải là chuỗi, có $v');
    return v;
  }

  bool boolean(String key) {
    final v = _required(key);
    if (v is! bool) fail(key, 'phải là true/false, có $v');
    return v;
  }

  Map<String, dynamic> object(String key) {
    final v = _required(key);
    if (v is! Map<String, dynamic>) fail(key, 'phải là object');
    return v;
  }

  List<dynamic> list(String key) {
    final v = _required(key);
    if (v is! List<dynamic>) fail(key, 'phải là mảng');
    return v;
  }

  /// {"en": "...", "vi": "..."} — cả hai bắt buộc, không rỗng.
  Map<String, String> title(String key) {
    final m = object(key);
    final out = <String, String>{};
    for (final lang in const ['en', 'vi']) {
      final v = m[lang];
      if (v is! String || v.trim().isEmpty) fail(key, 'thiếu bản "$lang"');
      out[lang] = v;
    }
    m.forEach((k, v) {
      if (!out.containsKey(k) && v is String) out[k] = v;
    });
    return Map.unmodifiable(out);
  }

  T enumValue<T extends Enum>(String key, List<T> values, {String what = 'giá trị'}) {
    final v = _required(key);
    return enumByName(values, v) ?? fail(key, '$what "$v" không tồn tại');
  }

  T? optionalEnum<T extends Enum>(String key, List<T> values, {String what = 'giá trị'}) {
    final v = json[key];
    if (v == null) return null;
    return enumByName(values, v) ?? fail(key, '$what "$v" không tồn tại');
  }

  /// Trường lạ (gõ sai tên) → lỗi; khoá bắt đầu bằng "_" là ghi chú, được bỏ qua.
  void rejectUnknown(Set<String> allowed) {
    for (final k in json.keys) {
      if (!k.startsWith('_') && !allowed.contains(k)) fail(k, 'trường lạ (gõ sai tên?)');
    }
  }
}
