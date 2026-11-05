import '../../../l10n/gen/app_localizations.dart';

/// Mô hình dữ liệu hội thoại V3 (docs/v3/interaction-spec.md mục 2.4). Dart thuần: chỉ giữ **hàm lấy chuỗi** từ
/// `AppLocalizations`, không gọi nó — chuỗi được lấy ở lớp giao diện. Dữ liệu truyện (`talk_stories.dart`,
/// `quarrel_events.dart`) viết riêng sau khi có khoá l10n.

typedef TalkText = String Function(AppLocalizations l);

/// Người nói. `a` / `b` = khách 1 / 2 của truyện; `hoa` = ông Hòa nói vọng ra; `narrator` = dẫn truyện; `staff` =
/// nhân viên đang điều khiển khi không phải Mai. `winner` / `loser` = người thắng / thua trong lựa chọn có
/// [TalkSideEffect.randomWinner] (lớp nối ánh xạ về `a` / `b` sau khi bốc thăm).
enum TalkRole { mai, a, b, staff, hoa, narrator, winner, loser }

/// Diễn xuất kèm một câu thoại.
enum TalkAnim { happy, surprised, pout, argue, wave, laugh, nod, shrug }

/// Tâm trạng khách sau lựa chọn.
enum TalkMood { neutral, happy, surprised, pout }

/// Hiệu ứng đặc biệt cho lớp nối thực thi (cảnh / sự kiện).
enum TalkSideEffect {
  /// T5: len lăn ra 1,5 m, Mochi chạy theo.
  mochiChaseYarn,

  /// Q1 B: chọn ngẫu nhiên người thắng (vào tiệm), người thua phụng phịu bỏ về.
  randomWinner,

  /// Q1 C: cả hai chờ 30 s trước cửa rồi mới vào tiệm.
  delayedEnter,

  /// Q2 A: tấm biển "mở cửa" bị lệch.
  signCrooked,

  /// Q2 B: mèo để lại tiền tip.
  catTip,

  /// Q2 C: các khách trong 3 m cười theo (`react`).
  crowdLaughs,

  /// Q3 B: hai bác vào tiệm nhưng vẫn lườm nhau (phụng phịu 10 s).
  glareAtEachOther,
}

/// Kết quả của một lựa chọn.
class TalkOutcome {
  const TalkOutcome({
    this.hearts = 0,
    this.coins = 0,
    this.mood = const {},
    this.leave = const {},
    this.joinQueue = const {},
    this.effect,
  });

  /// Thiện cảm ♥ và xu thử (chỉ tính trong phiên).
  final int hearts;
  final int coins;

  /// Tâm trạng đặt cho từng vai.
  final Map<TalkRole, TalkMood> mood;

  /// Vai bỏ đi (phụng phịu rời vỉa hè) / vai vào tiệm.
  final Set<TalkRole> leave;
  final Set<TalkRole> joinQueue;
  final TalkSideEffect? effect;
}

class TalkLine {
  const TalkLine(this.who, this.text, {this.anim, this.alt});

  final TalkRole who;
  final TalkText text;
  final TalkAnim? anim;

  /// Câu thay thế khi chạy ở chế độ "alt" (vd. Q3: Hòa nói vọng ra ↔ Mai giả giọng ông Hòa khi Hòa không có trong
  /// cảnh). null = dùng chính câu này.
  final TalkLine? alt;
}

class TalkChoice {
  const TalkChoice(this.label, this.next, {this.outcome = const TalkOutcome(), this.altLabel});

  final TalkText label;

  /// Id node kế tiếp; [TalkNode.endId] (rỗng) = kết thúc.
  final String next;
  final TalkOutcome outcome;

  /// Nhãn thay thế ở chế độ "alt" (vd. Q3: C ↔ CAlt).
  final TalkText? altLabel;
}

/// Một đoạn: các câu thoại lần lượt, rồi hoặc có lựa chọn ([choices]) hoặc sang [next] hoặc kết thúc.
class TalkNode {
  const TalkNode(this.id, {this.lines = const [], this.choices = const [], this.next});

  /// Id node đặc biệt trong `next` = kết thúc hội thoại.
  static const String endId = '';

  final String id;
  final List<TalkLine> lines;
  final List<TalkChoice> choices;

  /// Node kế tiếp khi không có lựa chọn; null / [endId] = kết thúc.
  final String? next;
}

/// Điều kiện mở truyện, đánh giá trên [TalkWorld].
typedef TalkCondition = bool Function(TalkWorld world);

/// Những gì truyện cần biết về thế giới hiện tại: ai đang có trong cảnh, sự kiện nào đã xong.
class TalkWorld {
  const TalkWorld({this.present = const {}, this.doneEvents = const {}});

  /// Id nhân vật có trong cảnh (`mochi`, `hoa`…).
  final Set<String> present;

  /// Id sự kiện gây gổ đã kết thúc trong phiên (`lastCake`, `first`, `tart`).
  final Set<String> doneEvents;
}

class TalkStory {
  const TalkStory(this.id, {required this.cast, required this.start, required this.nodes, this.when});

  final String id;

  /// Id nhân vật được truyện này gắn vào (khách nói chuyện, hoặc hai khách của sự kiện).
  final Set<String> cast;
  final TalkCondition? when;
  final String start;
  final Map<String, TalkNode> nodes;

  bool availableIn(TalkWorld w) => when == null || when!(w);

  /// Kiểm tra dữ liệu: node bắt đầu có, mọi `next` trỏ tới node có thật, mọi node tới được từ [start], lựa chọn nào
  /// cũng có kết quả hợp lệ. Trả danh sách lỗi (rỗng = tốt).
  List<String> validate() {
    final errors = <String>[];
    if (!nodes.containsKey(start)) errors.add('$id: thiếu node bắt đầu "$start"');
    for (final e in nodes.entries) {
      final n = e.value;
      if (n.id != e.key) errors.add('$id: node "${e.key}" mang id "${n.id}"');
      if (n.choices.isNotEmpty && n.next != null && n.next != TalkNode.endId) {
        errors.add('$id: node "${n.id}" vừa có lựa chọn vừa có next');
      }
      for (final c in n.choices) {
        if (c.next != TalkNode.endId && !nodes.containsKey(c.next)) {
          errors.add('$id: node "${n.id}" có lựa chọn trỏ tới "${c.next}" không tồn tại');
        }
      }
      final nx = n.next;
      if (nx != null && nx != TalkNode.endId && !nodes.containsKey(nx)) {
        errors.add('$id: node "${n.id}" có next "$nx" không tồn tại');
      }
      if (n.lines.isEmpty && n.choices.isEmpty && (nx == null || nx == TalkNode.endId)) {
        errors.add('$id: node "${n.id}" rỗng');
      }
    }
    final reach = <String>{};
    final stack = <String>[start];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (id == TalkNode.endId || !reach.add(id)) continue;
      final n = nodes[id];
      if (n == null) continue;
      for (final c in n.choices) {
        stack.add(c.next);
      }
      if (n.next != null) stack.add(n.next!);
    }
    for (final nodeId in nodes.keys) {
      if (!reach.contains(nodeId)) errors.add('$id: node "$nodeId" không tới được');
    }
    return errors;
  }
}
