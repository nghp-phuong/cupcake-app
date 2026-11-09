/// Nạp và tự lưu save v3 (docs/v3/city-gd2-spec.md §2.2–2.4).
///
/// Nạp: đọc v3 → không có thì nhập v2 (chỉ đọc khoá v2, không bao giờ ghi / xoá) → không có gì thì người mới (chưa ghi
/// cho tới lần thay đổi đầu tiên). Dữ liệu hỏng → mặc định + chép dự phòng, không ném. Không đọc được bộ nhớ hoặc save
/// do bản app mới hơn ghi (`v` > 3) → [CitySaveStore.locked]: cả phiên không ghi.
///
/// Tự lưu ([CitySaveStore.attachAutosave]): nghe ví, cài đặt, chi nhánh và [CityGame], gộp thay đổi trong
/// [CitySaveStore.autosaveDelay] rồi ghi bất đồng bộ; mỗi lúc chỉ một lần ghi, thay đổi trong lúc đang ghi được ghi
/// tiếp ngay sau đó. Ghi lỗi chỉ log (giữ dấu "chưa lưu" để lần sau thử lại).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../city/city_game.dart';
import 'city_save.dart';
import 'city_save_repository.dart';
import 'v2_import.dart';

enum CitySaveSource {
  /// Không có save nào: người mới.
  fresh,

  /// Đọc từ save v3.
  v3,

  /// Nhập từ save v2 (lần đầu chạy bản thành phố).
  importedV2,

  /// Save v3 hỏng (đã chép dự phòng): nhập v2 nếu có, không thì mặc định.
  recovered,
}

class CitySaveStore {
  CitySaveStore._(this._repo, this.game, this._clock);

  static const autosaveDelay = Duration(milliseconds: 300);

  final CitySaveRepository _repo;
  final DateTime Function() _clock;

  /// Trạng thái phiên; store không dispose nó.
  final CityGame game;

  CitySaveSource _source = CitySaveSource.fresh;
  bool _locked = false;
  List<String> _badFields = const [];

  Listenable? _changes;
  Timer? _timer;
  Future<void>? _writing;

  /// Trạng thái trong bộ nhớ khác bản đã ghi.
  bool _dirty = false;
  bool _disposed = false;

  CitySaveSource get source => _source;

  /// true → phiên này không ghi (save do bản app mới hơn ghi, hoặc không đọc được bộ nhớ); [resetAll] mở khoá.
  bool get locked => _locked;

  /// Trường save v3 hỏng lúc nạp (đã về mặc định, chuỗi gốc đã chép dự phòng).
  List<String> get badFields => _badFields;

  /// Nạp save (xem đầu file). Nhập từ v2 thì ghi v3 ngay trong hàm này (trước `runApp`); ghi lỗi vẫn chơi được, lần
  /// sau nhập lại. Cuối cùng gọi `CityGame.resume` (kiểm ngày lịch, bù két chi nhánh theo giờ máy). [mono]: đồng hồ
  /// đơn điệu của két (test).
  static Future<CitySaveStore> load(
    CitySaveRepository repo, {
    DateTime Function()? clock,
    Duration Function()? mono,
  }) async {
    final now = clock ?? DateTime.now;
    final store = CitySaveStore._(repo, CityGame(clock: now, mono: mono), now);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    game.restore(CitySave.fresh(_clock()));
    String? raw;
    try {
      raw = await _repo.readV3();
    } catch (e) {
      debugPrint(
        'CitySaveStore: không đọc được save v3, phiên này không ghi ($e)',
      );
      _locked = true;
      return;
    }

    var recovered = false;
    if (raw != null) {
      final decoded = _tryJson(raw);
      if (decoded is Map<String, dynamic>) {
        final r = CitySave.decode(decoded);
        game.restore(r.save);
        _source = CitySaveSource.v3;
        _badFields = r.bad;
        if (r.newer) {
          debugPrint(
            'CitySaveStore: save do bản app mới hơn ghi, phiên này không ghi',
          );
          _locked = true;
        }
        if (r.bad.isNotEmpty) {
          debugPrint(
            'CitySaveStore: trường hỏng dùng mặc định (${r.bad.join(', ')}), giữ bản dự phòng',
          );
          if (await _backup(raw)) _dirty = true;
        }
        _resume();
        return;
      }
      debugPrint('CitySaveStore: save v3 hỏng, giữ bản dự phòng');
      recovered = true;
      _source = CitySaveSource.recovered;
      if (await _backup(raw)) _dirty = true;
    }

    String? rawV2;
    try {
      rawV2 = await _repo.readV2();
    } catch (e) {
      // Không biết có v2 hay không: không ghi, kẻo bản v3 mặc định chặn lần nhập sau.
      debugPrint(
        'CitySaveStore: không đọc được save v2, phiên này không ghi ($e)',
      );
      _locked = true;
      return;
    }
    final v2 = rawV2 == null ? null : _tryJson(rawV2);
    if (v2 is Map<String, dynamic>) {
      game.restore(importV2(v2, now: _clock()));
      if (!recovered) _source = CitySaveSource.importedV2;
      try {
        await _repo.writeV3(_encode());
        _dirty = false;
      } catch (e) {
        debugPrint('CitySaveStore: chưa ghi được save v3 sau khi nhập v2 ($e)');
        _dirty = true;
      }
    } else if (rawV2 != null) {
      debugPrint('CitySaveStore: save v2 hỏng, bỏ qua (không động vào)');
    }
    _resume();
  }

  static Object? _tryJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _backup(String raw) async {
    try {
      await _repo.backupCorrupt(raw);
      return true;
    } catch (e) {
      debugPrint('CitySaveStore: không chép được bản dự phòng ($e)');
      return false;
    }
  }

  /// `CityGame.resume`; có gì đổi (ngày mới, két chi nhánh) → đánh dấu chưa lưu.
  void _resume() {
    var changed = false;
    void mark() => changed = true;
    final all = Listenable.merge([game, game.wallet, game.branches])
      ..addListener(mark);
    game.resume();
    all.removeListener(mark);
    if (changed) _dirty = true;
  }

  String _encode() => jsonEncode(game.toSave().toJson(_clock()));

  /// Bắt đầu tự lưu (gọi một lần, sau khi nạp và áp tham số debug).
  void attachAutosave() {
    if (_disposed || _changes != null) return;
    final changes = Listenable.merge([
      game.wallet,
      game.settings,
      game,
      game.branches,
    ]);
    changes.addListener(_onChange);
    _changes = changes;
  }

  void _onChange() {
    if (_disposed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () {
      _timer = null;
      unawaited(_writeAll());
    });
  }

  /// Một vòng ghi duy nhất tại một thời điểm; vòng đang chạy tự ghi tiếp nếu còn thay đổi.
  Future<void> _writeAll() => _writing ??= _drain();

  Future<void> _drain() async {
    // Nhường một nhịp: `_writing` được gán trước khi vòng có thể kết thúc (vòng xoá nó cùng lúc kiểm điều kiện).
    await Future<void>.value();
    try {
      while (_dirty && !_locked && !_disposed) {
        _dirty = false;
        try {
          await _repo.writeV3(_encode());
        } catch (e) {
          _dirty = true;
          debugPrint('CitySaveStore: lưu thất bại ($e)');
          break;
        }
      }
    } finally {
      _writing = null;
    }
  }

  /// Huỷ hẹn giờ, chờ lần ghi đang chạy, rồi ghi nếu còn dữ liệu chưa lưu. Gọi khi app ẩn / tạm dừng.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _writeAll();
  }

  /// Xoá dữ liệu (§2.4): về người mới **tại chỗ** (cùng các object game / ví / cài đặt / chi nhánh), giữ ngôn ngữ, âm
  /// thanh và đồ đã mua (`removeAds`, `iap`), `introSeen = false`, `levelSeen = 1`, xoá chi nhánh và nhân viên, mở khoá
  /// ghi rồi ghi bản v3 mặc định. Không xoá khoá (xoá thì lần sau lại nhập v2).
  Future<void> resetAll() {
    _timer?.cancel();
    _timer = null;
    final settings = game.settings;
    game.restore(
      CitySave.fresh(_clock()).copyWith(
        language: settings.language,
        sound: settings.sound,
        removeAds: game.removeAds,
        iap: game.iapOwned,
      ),
    );
    _locked = false;
    _dirty = true;
    return flush();
  }

  /// Ngừng tự lưu (không ghi thêm, kể cả [flush]); không dispose [game].
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _changes?.removeListener(_onChange);
    _changes = null;
  }
}
