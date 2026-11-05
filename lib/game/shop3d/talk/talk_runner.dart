import 'talk_model.dart';

/// Máy trạng thái chạy một [TalkStory]: câu thoại → lựa chọn → node kế → … → kết thúc, cộng dồn kết quả. Dart thuần,
/// KHÔNG gọi [TalkText] (lớp giao diện lấy chuỗi bằng `line.text(l10n)`).
///
/// Quy tắc cứng: không bao giờ bỏ qua lựa chọn — [TalkRunner.skip] chỉ nhảy tới lựa chọn kế tiếp hoặc tới cuối.

enum TalkPhase {
  /// Đang ở một câu thoại ([TalkRunner.line]).
  line,

  /// Đang chờ người chơi chọn ([TalkRunner.choices]).
  choice,

  /// Đã xong.
  done,
}

/// Kết quả cộng dồn của các lựa chọn đã chọn. `mood` giữ giá trị mới nhất cho mỗi vai.
class TalkTotals {
  int hearts = 0;
  int coins = 0;
  final Map<TalkRole, TalkMood> mood = {};
  final Set<TalkRole> leave = {};
  final Set<TalkRole> joinQueue = {};
  final List<TalkSideEffect> effects = [];

  void add(TalkOutcome o) {
    hearts += o.hearts;
    coins += o.coins;
    mood.addAll(o.mood);
    leave.addAll(o.leave);
    joinQueue.addAll(o.joinQueue);
    final e = o.effect;
    if (e != null) effects.add(e);
  }
}

class TalkRunner {
  /// [useAlt]: dùng nhãn / câu thay thế (`altLabel`, `TalkLine.alt`) — vd. Q3 khi ông Hòa không có trong cảnh.
  TalkRunner(this.story, {this.useAlt = false}) {
    _enter(story.start);
  }

  final TalkStory story;
  final bool useAlt;

  /// Cộng dồn kết quả (đọc bất cứ lúc nào; đầy đủ khi [finished]).
  final TalkTotals totals = TalkTotals();

  TalkNode? _node;
  int _lineIdx = 0;
  TalkPhase _phase = TalkPhase.done;
  int _chosen = 0;

  /// Chống lặp vô hạn khi dữ liệu có vòng toàn node rỗng.
  static const int _maxHops = 1000;

  TalkPhase get phase => _phase;
  bool get finished => _phase == TalkPhase.done;
  TalkNode? get node => _node;

  /// Số lựa chọn đã chọn.
  int get choicesMade => _chosen;

  /// Câu thoại hiện tại (đã thay bằng `alt` nếu [useAlt] và có); null khi không ở pha [TalkPhase.line].
  TalkLine? get line {
    if (_phase != TalkPhase.line) return null;
    final l = _node!.lines[_lineIdx];
    return useAlt ? (l.alt ?? l) : l;
  }

  /// Các lựa chọn khi ở pha [TalkPhase.choice]; ngược lại rỗng.
  List<TalkChoice> get choices => _phase == TalkPhase.choice ? _node!.choices : const [];

  /// Nhãn của lựa chọn [i] (theo [useAlt]).
  TalkText labelOf(int i) {
    final c = choices[i];
    return useAlt ? (c.altLabel ?? c.label) : c.label;
  }

  /// Sang câu kế (hoặc vào lựa chọn / node kế / kết thúc). Không làm gì nếu không ở pha [TalkPhase.line].
  void advance() {
    if (_phase != TalkPhase.line) return;
    _lineIdx++;
    _settle();
  }

  /// Chọn lựa chọn [index] (chỉ ở pha [TalkPhase.choice]); cộng kết quả rồi sang node kế.
  void choose(int index) {
    if (_phase != TalkPhase.choice) {
      throw StateError('Không ở pha lựa chọn');
    }
    final list = _node!.choices;
    if (index < 0 || index >= list.length) throw RangeError.index(index, list, 'index');
    final c = list[index];
    totals.add(c.outcome);
    _chosen++;
    _enter(c.next);
  }

  /// Bỏ qua các câu thoại tới lựa chọn kế tiếp hoặc tới cuối. KHÔNG bỏ qua lựa chọn: đang ở pha lựa chọn thì không
  /// làm gì.
  void skip() {
    var guard = 0;
    while (_phase == TalkPhase.line) {
      advance();
      if (++guard > _maxHops * 10) throw StateError('Truyện ${story.id} lặp vô hạn');
    }
  }

  void _enter(String id) {
    if (id == TalkNode.endId) {
      _finish();
      return;
    }
    final n = story.nodes[id];
    if (n == null) {
      throw StateError('Truyện ${story.id}: không có node "$id"');
    }
    _node = n;
    _lineIdx = 0;
    _settle();
  }

  /// Xác định pha sau khi vào node / qua hết câu: còn câu → line; hết câu mà có lựa chọn → choice; không thì sang
  /// `next` hoặc kết thúc.
  void _settle() {
    var hops = 0;
    while (true) {
      final n = _node!;
      if (_lineIdx < n.lines.length) {
        _phase = TalkPhase.line;
        return;
      }
      if (n.choices.isNotEmpty) {
        _phase = TalkPhase.choice;
        return;
      }
      final nx = n.next;
      if (nx == null || nx == TalkNode.endId) {
        _finish();
        return;
      }
      final next = story.nodes[nx];
      if (next == null) throw StateError('Truyện ${story.id}: không có node "$nx"');
      if (++hops > _maxHops) throw StateError('Truyện ${story.id}: vòng node rỗng');
      _node = next;
      _lineIdx = 0;
    }
  }

  void _finish() {
    _phase = TalkPhase.done;
  }
}
