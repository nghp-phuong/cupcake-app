part of 'level_session.dart';

/// Chạy kịch bản hướng dẫn trong một lượt chơi (chỉ [LevelSession] tạo + gọi). Không cấp phát trong [_update] /
/// [_sync]; không rút số ngẫu nhiên (nhịp khách y như khi không có hướng dẫn, trừ lúc bước dừng giờ).
///
/// - `basics` (L1, tuần tự): bán cho khách đầu tiên → tủ còn ≤ 1 cái (hoặc [bakeHintAfterSec] giây sau khi bán mà chưa
///   làm mẻ nào — có thợ bánh giữ tủ đầy): chạm thẻ bánh → theo mẻ vừa làm qua Khuôn, Trộn, Lò (chỉ hiện khi kim gần
///   vạch), Kem, Topping, Hộp → mẻ vào tủ: xong (phát `tutorialDone` ngay) + lời chúc (bước phụ, tự ẩn 3 s). Người chơi
///   làm trước (đã bán trước khi bước Bán kịp hiện, đã có mẻ trong bếp, đã qua trạm) → bỏ qua bước đó. Huỷ mẻ giữa
///   chừng → quay lại bước thẻ bánh.
/// - `combo` (L2, hai bước độc lập): combo lên 2 → chỉ ô combo; khách đứng quầy muốn món mới của level → chỉ khách.
/// - `patience` (L3): khách đứng quầy đầu tiên dưới 50% kiên nhẫn → chỉ vòng kiên nhẫn (bắt buộc); khách đầu tiên bỏ
///   đi → nhắc, không dừng giờ (tuỳ chọn: không xảy ra vẫn xong kịch bản).
class _Tutorial implements TutorialRunner {
  _Tutorial._(this.id, this._s);

  /// null nếu [id] không phải kịch bản đã biết.
  static _Tutorial? _create(String id, LevelSession s) => TutorialSteps.of(id).isEmpty ? null : _Tutorial._(id, s);

  /// Bước Lò hiện khi kim còn cách vạch chuẩn chừng này (≈ 1 s ở lò 7 s).
  static const ovenHintLead = 0.10;

  /// L1: đã xong bước Bán chừng này giây (thời gian màn chơi, kể cả lúc dừng giờ) mà chưa làm mẻ nào → nhắc thẻ bánh
  /// dù tủ còn nhiều.
  static const bakeHintAfterSec = 20.0;

  /// Dưới tỉ lệ kiên nhẫn này → bước vòng kiên nhẫn (L3).
  static const patienceHintBelow = 0.5;

  @override
  final String id;
  final LevelSession _s;

  TutorialStep? _current;
  double _shownFor = 0;
  bool _finished = false;
  int? _customer;
  RecipeId? _recipe;

  // basics: chỉ số bước kế tiếp trong `TutorialSteps.of(basics)` + mẻ đang theo.
  int _index = 0;
  Batch? _batch;

  /// Giây đã trôi từ khi xong bước Bán (chỉ đếm lúc `_index == 1`).
  double _sinceSell = 0;

  // combo / patience: bước đã xong (đã hiện rồi ẩn).
  bool _comboDone = false;
  bool _varietyDone = false;
  bool _ringDone = false;
  bool _walkoutDone = false;
  int _walkoutCustomer = -1;

  // ------------------------------------------------------------------ TutorialRunner

  @override
  TutorialStep? get current => _current;

  @override
  double get shownFor => _shownFor;

  @override
  bool get finished => _finished;

  @override
  int? get targetCustomer {
    final id = _customer;
    if (_current == null || id == null) return null;
    return _s.customer(id) == null ? null : id;
  }

  @override
  RecipeId? get targetRecipe => _current == null ? null : _recipe;

  @override
  MouldType? get targetMould => identical(_current, TutorialSteps.basicsMould) ? _batch?.correctMould : null;

  @override
  int? get targetOven {
    if (!identical(_current, TutorialSteps.basicsOven)) return null;
    final oven = _batch?.oven ?? -1;
    return oven >= 0 ? oven : null;
  }

  @override
  ToppingId? get targetTopping => identical(_current, TutorialSteps.basicsTopping) ? _batch?.correctTopping : null;

  @override
  BoxType? get targetBox => identical(_current, TutorialSteps.basicsBox) ? _batch?.correctBox : null;

  // ------------------------------------------------------------------ Gọi từ LevelSession

  /// Bước đang hiện có dừng giờ / khách / kiên nhẫn không.
  bool get _blocking => _current?.blocking ?? false;

  /// Mỗi bước logic (kể cả khi bước đang dừng giờ), sau khi khách + bếp đã chạy.
  void _update(double h) {
    final step = _current;
    if (step != null) {
      _shownFor += h;
      final hide = step.autoHide;
      if (hide != null && _shownFor + 1e-9 >= hide.inMicroseconds / 1e6) _completeCurrent();
    }
    if (_index == 1) _sinceSell += h;
    _sync();
  }

  /// Người chơi vừa bán (không tính nhân viên).
  void _onPlayerSold() {
    if (identical(_current, TutorialSteps.basicsSell)) {
      _completeCurrent();
    } else if (id == TutorialIds.basics && _index == 0) {
      // Bán trước khi bước Bán kịp hiện (vd. thao tác chen giữa một bước logic): coi như đã xong bước này.
      _index = 1;
    }
  }

  /// Khách vãng lai [c] hết kiên nhẫn bỏ đi.
  void _onWalkout(LevelCustomer c) {
    if (id == TutorialIds.patience && !_walkoutDone && _walkoutCustomer < 0) _walkoutCustomer = c._id;
  }

  /// Hết giờ: bước thông tin đang hiện coi như đã xem (L2/L3: bước bắt buộc cuối → kịch bản xong).
  void _onTimeUp() {
    if (_current?.autoHide != null) _completeCurrent();
  }

  /// Chạm để ẩn bước thông tin; false nếu bước hiện tại không ẩn được bằng chạm.
  bool _dismiss() {
    if (_current?.dismissible != true) return false;
    _completeCurrent();
    _sync();
    return true;
  }

  // ------------------------------------------------------------------ Nội bộ

  void _show(TutorialStep step, {int? customer, RecipeId? recipe}) {
    _current = step;
    _shownFor = 0;
    _customer = customer;
    _recipe = recipe;
    _s._emit(const SessionEvent(SessionEventType.tutorialStep));
    _s._bumpHud();
  }

  /// Ẩn bước hiện tại mà không tính là xong một bước có điều kiện riêng (bước Bếp: trạng thái mẻ tự quyết).
  void _hide() {
    if (_current == null) return;
    _current = null;
    _shownFor = 0;
    _customer = null;
    _recipe = null;
    _s._bumpHud();
  }

  void _completeCurrent() {
    final step = _current;
    if (step == null) return;
    _hide();
    if (identical(step, TutorialSteps.basicsSell)) {
      _index = math.max(_index, 1);
    } else if (identical(step, TutorialSteps.basicsDone)) {
      _index = 9;
    } else if (identical(step, TutorialSteps.comboMeter)) {
      _comboDone = true;
    } else if (identical(step, TutorialSteps.comboVariety)) {
      _varietyDone = true;
    } else if (identical(step, TutorialSteps.patienceRing)) {
      _ringDone = true;
    } else if (identical(step, TutorialSteps.patienceWalkout)) {
      _walkoutDone = true;
      _walkoutCustomer = -1;
    }
    if (!_finished && _requiredDone) _finish();
  }

  bool get _requiredDone => switch (id) {
        // Mẻ vào tủ (bước 8) là xong; lời chúc chỉ là bước phụ.
        TutorialIds.basics => _index >= 8,
        TutorialIds.combo => _comboDone && _varietyDone,
        TutorialIds.patience => _ringDone,
        _ => true,
      };

  void _finish() {
    if (_finished) return;
    _finished = true;
    _s._emit(const SessionEvent(SessionEventType.tutorialDone));
    _s._bumpHud();
  }

  /// Đánh giá lại: bước hiện tại còn đúng không, có bước mới cần hiện không.
  void _sync() {
    if (_s._over) return;
    switch (id) {
      case TutorialIds.basics:
        _syncBasics();
      case TutorialIds.combo:
        _syncCombo();
      case TutorialIds.patience:
        _syncPatience();
    }
  }

  void _syncBasics() {
    // Tối đa vài vòng (bỏ qua bước người chơi đã làm trước) — không lặp vô hạn.
    for (var guard = 0; guard < 4; guard++) {
      if (_index >= 9) return;
      if (_index == 0) {
        if (_current != null) return;
        final c = _sellableAtCounter();
        if (c != null) _show(TutorialSteps.basicsSell, customer: c._id, recipe: _s._wantInCase(c));
        return;
      }
      if (_index == 1) {
        final existing = _playerBatch();
        if (existing != null) {
          // Người chơi đã bắt đầu mẻ trước khi được nhắc.
          if (identical(_current, TutorialSteps.basicsBake)) _hide();
          _batch = existing;
          _index = 2;
          continue;
        }
        if (_current != null) return;
        final r = _s.level.menu.first;
        if (_s._kitchen._prep == null && (_s._case.countOf(r) <= 1 || _sinceSell + 1e-9 >= bakeHintAfterSec)) {
          _show(TutorialSteps.basicsBake, recipe: r);
        }
        return;
      }
      if (_index <= 7) {
        final b = _batch;
        if (b == null || (!_inKitchen(b) && b._result == null)) {
          // Mẻ bị huỷ → quay lại bước thẻ bánh (hiện ngay, không chờ tủ vơi).
          _hide();
          _batch = null;
          _index = 1;
          if (_playerBatch() == null && _s._kitchen._prep == null) {
            _show(TutorialSteps.basicsBake, recipe: _s.level.menu.first);
            return;
          }
          continue;
        }
        final want = _kitchenStep(b);
        if (want < 0) {
          // Mẻ đã vào tủ: phần bắt buộc xong ngay (thoát trong lúc lời chúc còn hiện vẫn được lưu).
          _hide();
          _index = 8;
          _finish();
          continue;
        }
        if (want > _index) _index = want;
        final steps = TutorialSteps.of(TutorialIds.basics);
        final step = want == _index && _kitchenStepVisible(b, want) ? steps[want] : null;
        if (!identical(_current, step)) {
          _hide();
          if (step != null) _show(step, recipe: b.recipe);
        }
        return;
      }
      // _index == 8: mẻ đã lên tủ (đã phát `tutorialDone`) → lời chúc.
      if (_current == null) _show(TutorialSteps.basicsDone, recipe: _batch?.recipe ?? _s.level.menu.first);
      return;
    }
  }

  /// Chỉ số bước Bếp (2..7) ứng với trạng thái mẻ; −1 nếu mẻ đã vào tủ.
  int _kitchenStep(Batch b) => switch (b._stage) {
        BatchStage.mould => 2,
        BatchStage.mix => 3,
        BatchStage.waitingOven || BatchStage.baking => 4,
        BatchStage.ovenDone || BatchStage.frost => 5,
        BatchStage.topping => 6,
        BatchStage.box => 7,
        BatchStage.waitingCase => _inKitchen(b) ? 7 : -1,
      };

  /// Bước Bếp [step] có nên hiện lúc này (mẻ đang đúng ở trạm đó; Lò: chỉ khi kim gần vạch).
  bool _kitchenStepVisible(Batch b, int step) => switch (step) {
        2 => b._stage == BatchStage.mould,
        3 => b._stage == BatchStage.mix,
        4 => b._stage == BatchStage.baking && b._ovenProgress >= b.bakeTarget - ovenHintLead,
        5 => b._stage == BatchStage.frost,
        6 => b._stage == BatchStage.topping,
        7 => b._stage == BatchStage.box,
        _ => false,
      };

  void _syncCombo() {
    if (_current != null) return;
    if (!_comboDone && _s._combo >= 2) {
      _show(TutorialSteps.comboMeter);
      return;
    }
    if (!_varietyDone) {
      final r = _varietyRecipe;
      if (r == null) {
        // Level một món: không có gì để chỉ.
        _varietyDone = true;
        if (_requiredDone) _finish();
        return;
      }
      final counter = _s._counter;
      for (var i = 0; i < counter.length; i++) {
        final c = counter[i];
        if (c != null && c.canBuy && c.want == r) {
          _show(TutorialSteps.comboVariety, customer: c._id, recipe: r);
          return;
        }
      }
    }
  }

  /// Món "thứ 2" của L2: món mới của level nếu khác món đầu menu, không thì món thứ 2 của menu.
  RecipeId? get _varietyRecipe {
    final menu = _s.level.menu;
    final fresh = _s.level.newRecipe;
    if (fresh != null && fresh != menu.first && menu.contains(fresh)) return fresh;
    return menu.length > 1 ? menu[1] : null;
  }

  void _syncPatience() {
    if (_current != null) return;
    if (!_ringDone) {
      final counter = _s._counter;
      for (var i = 0; i < counter.length; i++) {
        final c = counter[i];
        if (c != null && c.canBuy && c.patienceFrac < patienceHintBelow) {
          _show(TutorialSteps.patienceRing, customer: c._id, recipe: c.want);
          return;
        }
      }
    }
    if (!_walkoutDone && _walkoutCustomer >= 0) {
      _show(TutorialSteps.patienceWalkout, customer: _walkoutCustomer);
    }
  }

  /// Khách đứng quầy đầu tiên mua được ngay (tủ có món khách muốn).
  LevelCustomer? _sellableAtCounter() {
    final counter = _s._counter;
    for (var i = 0; i < counter.length; i++) {
      final c = counter[i];
      if (c != null && c.canBuy && _s._wantInCase(c) != null) return c;
    }
    return null;
  }

  /// Mẻ của người chơi đang trong bếp (ưu tiên mẻ đi xa nhất); null nếu bếp trống.
  Batch? _playerBatch() {
    final k = _s._kitchen;
    if (k._finish != null) return k._finish;
    for (final b in k._ovens) {
      if (b != null) return b;
    }
    return k._prep;
  }

  bool _inKitchen(Batch b) {
    final k = _s._kitchen;
    if (identical(k._prep, b) || identical(k._finish, b)) return true;
    for (final o in k._ovens) {
      if (identical(o, b)) return true;
    }
    return false;
  }

  @override
  String toString() => 'TutorialRunner($id, ${_current?.id ?? '—'}${_finished ? ', xong' : ''})';
}
