import 'dart:math' as math;

import 'talk_model.dart';

/// Luật chọn truyện khi nói chuyện với khách (docs/v3/interaction-spec.md mục 2.4, "Luật chọn truyện") và sổ thiện cảm
/// trong phiên. Dart thuần; thời gian [now] là giây, đồng hồ chạy liên tục.
///
/// - Mỗi khách có tối đa 1 truyện, mỗi truyện chạy 1 lần mỗi phiên (đánh dấu khi xong: [TalkLedger.finishStory]).
/// - Khách đã xem truyện / không có truyện: chuyện phiếm — Mai nói 1 câu mở + khách đáp ngẫu nhiên, +1♥, hồi chiêu
///   45 s mỗi khách; nhân viên khác Mai: câu mở riêng + câu đáp ngẫu nhiên, tối đa 1♥ mỗi khách / 60 s.
/// - Nói chuyện cộng tối đa 3♥ mỗi khách mỗi phiên (sự kiện gây gổ không tính vào trần này).

enum TalkPickKind { story, smallTalk }

class TalkPick {
  const TalkPick.story(TalkStory this.story)
      : kind = TalkPickKind.story,
        heartsGranted = 0,
        openIndex = 0,
        replyIndex = 0;

  const TalkPick.smallTalk({required this.heartsGranted, required this.openIndex, required this.replyIndex})
      : kind = TalkPickKind.smallTalk,
        story = null;

  final TalkPickKind kind;

  /// Truyện được chọn ([TalkPickKind.story]).
  final TalkStory? story;

  /// Chuyện phiếm: số ♥ được cộng ngay (0 hoặc 1, đã tính hồi chiêu và trần 3♥).
  final int heartsGranted;

  /// Chuyện phiếm: chỉ số câu mở của Mai (trong [TalkLedger.maiOpeners]) và câu đáp của khách (trong
  /// [TalkLedger.guestReplies]). Nhân viên khác Mai có câu mở riêng nên bỏ qua [openIndex].
  final int openIndex;
  final int replyIndex;
}

class TalkLedger {
  TalkLedger({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  static const int heartCapPerGuest = 3;
  static const double maiSmallTalkCooldown = 45;
  static const double staffHeartCooldown = 60;

  /// Số câu mở của Mai và số câu đáp của khách trong dữ liệu chuyện phiếm (smallTalkMai1..2, smallTalkReply1..3).
  static const int maiOpeners = 2, guestReplies = 3;

  final Set<String> _seenStories = {};
  final Map<String, int> _hearts = {};
  final Map<String, double> _lastMaiSmall = {};
  final Map<String, double> _lastStaffHeart = {};

  bool storySeen(String storyId) => _seenStories.contains(storyId);

  int heartsGiven(String guestId) => _hearts[guestId] ?? 0;

  /// Truyện chưa xem của [guestId] trong [stories] (cast chứa khách và điều kiện `when` đúng), theo thứ tự danh sách.
  TalkStory? storyFor(String guestId, List<TalkStory> stories, TalkWorld world) {
    for (final s in stories) {
      if (_seenStories.contains(s.id)) continue;
      if (!s.cast.contains(guestId) || !s.availableIn(world)) continue;
      return s;
    }
    return null;
  }

  /// Chọn nội dung khi [byMai] (true = Mai, false = nhân viên khác) nói chuyện với [guestId]. Mai có truyện chưa
  /// xem → truyện; còn lại → chuyện phiếm (♥ đã cộng và ghi hồi chiêu).
  TalkPick pick({
    required String guestId,
    required bool byMai,
    required List<TalkStory> stories,
    required TalkWorld world,
    required double now,
  }) {
    if (byMai) {
      final s = storyFor(guestId, stories, world);
      if (s != null) return TalkPick.story(s);
    }
    var hearts = 0;
    if (byMai) {
      final last = _lastMaiSmall[guestId];
      if (last == null || now - last >= maiSmallTalkCooldown) {
        _lastMaiSmall[guestId] = now;
        hearts = grantHearts(guestId, 1);
      }
    } else {
      final last = _lastStaffHeart[guestId];
      if (last == null || now - last >= staffHeartCooldown) {
        _lastStaffHeart[guestId] = now;
        hearts = grantHearts(guestId, 1);
      }
    }
    return TalkPick.smallTalk(
        heartsGranted: hearts, openIndex: _rng.nextInt(maiOpeners), replyIndex: _rng.nextInt(guestReplies));
  }

  /// Cộng [requested] ♥ cho [guestId] nhưng không vượt trần 3♥ mỗi khách mỗi phiên; trả số ♥ thực nhận.
  int grantHearts(String guestId, int requested) {
    if (requested <= 0) return 0;
    final have = _hearts[guestId] ?? 0;
    final granted = math.min(requested, math.max(0, heartCapPerGuest - have));
    _hearts[guestId] = have + granted;
    return granted;
  }

  /// Truyện [storyId] đã xong với [guestId], kết quả có [hearts] ♥: đánh dấu đã xem và trả số ♥ thực nhận (sau trần).
  int finishStory(String storyId, String guestId, int hearts) {
    _seenStories.add(storyId);
    return grantHearts(guestId, hearts);
  }

  void reset() {
    _seenStories.clear();
    _hearts.clear();
    _lastMaiSmall.clear();
    _lastStaffHeart.clear();
  }
}
