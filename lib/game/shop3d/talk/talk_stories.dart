import 'talk_model.dart';

/// Dữ liệu 8 mẩu chuyện Mai–khách (T1–T8), chuyện phiếm và bảng tên người nói
/// (docs/v3/interaction-spec.md mục 3). Chỉ giữ hàm lấy chuỗi từ `AppLocalizations`; lớp giao diện gọi khi hiển thị.
///
/// Quy ước vai: khách trong truyện luôn là [TalkRole.a] (tên lấy theo id trong [TalkNames]); Mai là [TalkRole.mai];
/// dẫn truyện là [TalkRole.narrator]. Truyện nối nhau theo mẫu: câu mở → lựa chọn → nhánh đáp → câu kết dùng chung.

TalkLine _l(TalkRole who, TalkText t, {TalkAnim? anim}) => TalkLine(who, t, anim: anim);

TalkChoice _c(TalkText label, String next, TalkOutcome outcome) => TalkChoice(label, next, outcome: outcome);

/// Tên người nói theo id nhân vật (id cast / id chibi).
abstract final class TalkNames {
  static final Map<String, TalkText> _names = {
    'mai': (l) => l.charMai,
    'hoa': (l) => l.charHoa,
    'linh': (l) => l.charLinh,
    'kenji': (l) => l.charKenji,
    'vip_00': (l) => l.charRosa,
    'mochi': (l) => l.mochiName,
    'staff_nora': (l) => l.charNora,
    'staff_bao': (l) => l.charBao,
    'staff_theo': (l) => l.charTheo,
    'regular_04': (l) => l.npcSquirrel,
    'regular_01': (l) => l.npcHamster,
    'regular_05': (l) => l.npcShiba,
    'regular_06': (l) => l.npcBlackCat,
    'regular_13': (l) => l.npcWalrus,
    'regular_14': (l) => l.npcLion,
  };

  /// Id có tên riêng.
  static Iterable<String> get ids => _names.keys;

  /// Hàm lấy tên của [id]; null nếu chưa có tên riêng.
  static TalkText? of(String id) => _names[id];
}

abstract final class TalkStories {
  /// T1 "Cú dậy sớm" — ông Hòa.
  static final TalkStory owl = TalkStory(
    'owl',
    cast: const {'hoa'},
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkHoaOwlL1),
        _l(TalkRole.mai, (l) => l.talkHoaOwlL2, anim: TalkAnim.surprised),
        _l(TalkRole.a, (l) => l.talkHoaOwlL3),
      ], choices: [
        _c((l) => l.talkHoaOwlC1, 'r1', const TalkOutcome(hearts: 1)),
        _c((l) => l.talkHoaOwlC2, 'r2', const TalkOutcome(hearts: 1, coins: 5)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkHoaOwlR1)], next: 'end'),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkHoaOwlR2, anim: TalkAnim.happy)], next: 'end'),
      'end': TalkNode('end', lines: [_l(TalkRole.mai, (l) => l.talkHoaOwlL4)]),
    },
  );

  /// T2 "Bức ký họa" — Linh.
  static final TalkStory sketch = TalkStory(
    'sketch',
    cast: const {'linh'},
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkLinhSketchL1),
        _l(TalkRole.mai, (l) => l.talkLinhSketchL2),
        _l(TalkRole.a, (l) => l.talkLinhSketchL3),
        _l(TalkRole.mai, (l) => l.talkLinhSketchL4, anim: TalkAnim.surprised),
        _l(TalkRole.a, (l) => l.talkLinhSketchL5, anim: TalkAnim.laugh),
      ], choices: [
        _c((l) => l.talkLinhSketchC1, 'r1', const TalkOutcome(hearts: 1)),
        _c((l) => l.talkLinhSketchC2, 'r2', const TalkOutcome(hearts: 2)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkLinhSketchR1, anim: TalkAnim.happy)]),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkLinhSketchR2, anim: TalkAnim.surprised)]),
    },
  );

  /// T3 "Đơn theo cảm xúc" — Kenji.
  static final TalkStory cloud = TalkStory(
    'cloud',
    cast: const {'kenji'},
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkKenjiCloudL1),
        _l(TalkRole.mai, (l) => l.talkKenjiCloudL2),
      ], choices: [
        _c((l) => l.talkKenjiCloudC1, 'r1', const TalkOutcome(hearts: 1, coins: 5)),
        _c((l) => l.talkKenjiCloudC2, 'r2', const TalkOutcome(hearts: 1)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkKenjiCloudR1, anim: TalkAnim.happy)], next: 'end'),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkKenjiCloudR2)], next: 'end'),
      'end': TalkNode('end', lines: [_l(TalkRole.a, (l) => l.talkKenjiCloudL3)]),
    },
  );

  /// T4 "Bí mật của quý bà" — bà Rosa (`vip_00`).
  static final TalkStory secret = TalkStory(
    'secret',
    cast: const {'vip_00'},
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkRosaSecretL1),
        _l(TalkRole.mai, (l) => l.talkRosaSecretL2),
        _l(TalkRole.a, (l) => l.talkRosaSecretL3, anim: TalkAnim.shrug),
        _l(TalkRole.mai, (l) => l.talkRosaSecretL4),
      ], choices: [
        _c((l) => l.talkRosaSecretC1, 'r1', const TalkOutcome(hearts: 1, coins: 15)),
        _c((l) => l.talkRosaSecretC2, 'r2', const TalkOutcome(hearts: 2)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkRosaSecretR1, anim: TalkAnim.happy)]),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkRosaSecretR2, anim: TalkAnim.happy)]),
    },
  );

  /// T5 "Cái bẫy bụng mèo" — Mochi (chỉ khi có Mochi trong cảnh).
  static final TalkStory belly = TalkStory(
    'belly',
    cast: const {'mochi'},
    when: (w) => w.present.contains('mochi'),
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkMochiBellyL1),
        _l(TalkRole.mai, (l) => l.talkMochiBellyL2),
        _l(TalkRole.narrator, (l) => l.talkMochiBellyL3),
        _l(TalkRole.mai, (l) => l.talkMochiBellyL4),
      ], choices: [
        _c((l) => l.talkMochiBellyC1, 'r1', const TalkOutcome(hearts: 1)),
        _c((l) => l.talkMochiBellyC2, 'r2',
            const TalkOutcome(hearts: 1, effect: TalkSideEffect.mochiChaseYarn)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.narrator, (l) => l.talkMochiBellyR1)], next: 'end'),
      'r2': TalkNode('r2', lines: [_l(TalkRole.narrator, (l) => l.talkMochiBellyR2)], next: 'end'),
      'end': TalkNode('end', lines: [_l(TalkRole.mai, (l) => l.talkMochiBellyL5)]),
    },
  );

  /// T6 "Con cá ngày càng to" — Bác Hải Mã (`regular_13`), mở sau Q3 (`tart`).
  static final TalkStory fish = TalkStory(
    'fish',
    cast: const {'regular_13'},
    when: (w) => w.doneEvents.contains('tart'),
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkWalrusFishL1),
        _l(TalkRole.mai, (l) => l.talkWalrusFishL2),
        _l(TalkRole.a, (l) => l.talkWalrusFishL3, anim: TalkAnim.laugh),
      ], choices: [
        _c((l) => l.talkWalrusFishC1, 'r1', const TalkOutcome(hearts: 1, coins: 5)),
        _c((l) => l.talkWalrusFishC2, 'r2', const TalkOutcome(hearts: 1)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkWalrusFishR1, anim: TalkAnim.shrug)], next: 'end'),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkWalrusFishR2)], next: 'end'),
      'end': TalkNode('end', lines: [_l(TalkRole.mai, (l) => l.talkWalrusFishL4)]),
    },
  );

  /// T7 "Trả bằng hạt dẻ" — Bạn Sóc (`regular_04`), mở sau Q1 (`lastCake`).
  static final TalkStory nut = TalkStory(
    'nut',
    cast: const {'regular_04'},
    when: (w) => w.doneEvents.contains('lastCake'),
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkSquirrelNutL1),
        _l(TalkRole.mai, (l) => l.talkSquirrelNutL2),
        _l(TalkRole.a, (l) => l.talkSquirrelNutL3),
        _l(TalkRole.a, (l) => l.talkSquirrelNutL4, anim: TalkAnim.happy),
      ], choices: [
        _c((l) => l.talkSquirrelNutC1, 'r1', const TalkOutcome(hearts: 1)),
        _c((l) => l.talkSquirrelNutC2, 'r2', const TalkOutcome(hearts: 2)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkSquirrelNutR1, anim: TalkAnim.happy)]),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkSquirrelNutR2, anim: TalkAnim.surprised)]),
    },
  );

  /// T8 "Má phồng" — Bé Hamster (`regular_01`), mở sau Q1 (`lastCake`).
  static final TalkStory cheeks = TalkStory(
    'cheeks',
    cast: const {'regular_01'},
    when: (w) => w.doneEvents.contains('lastCake'),
    start: 'n0',
    nodes: {
      'n0': TalkNode('n0', lines: [
        _l(TalkRole.a, (l) => l.talkHamsterCheeksL1),
        _l(TalkRole.mai, (l) => l.talkHamsterCheeksL2),
        _l(TalkRole.a, (l) => l.talkHamsterCheeksL3),
      ], choices: [
        _c((l) => l.talkHamsterCheeksC1, 'r1', const TalkOutcome(hearts: 1, coins: 5)),
        _c((l) => l.talkHamsterCheeksC2, 'r2', const TalkOutcome(hearts: 1)),
      ]),
      'r1': TalkNode('r1', lines: [_l(TalkRole.a, (l) => l.talkHamsterCheeksR1, anim: TalkAnim.happy)]),
      'r2': TalkNode('r2', lines: [_l(TalkRole.a, (l) => l.talkHamsterCheeksR2, anim: TalkAnim.laugh)]),
    },
  );

  /// Cả 8 truyện, theo thứ tự T1–T8 (đưa thẳng cho `TalkLedger.pick`).
  static final List<TalkStory> all = [owl, sketch, cloud, secret, belly, fish, nut, cheeks];
}

/// Chuyện phiếm: Mai (hoặc nhân viên khác) nói câu mở + khách đáp ngẫu nhiên. Số câu khớp
/// `TalkLedger.maiOpeners` / `guestReplies`.
abstract final class TalkSmallTalk {
  static final List<TalkText> maiOpeners = [(l) => l.smallTalkMai1, (l) => l.smallTalkMai2];

  static final List<TalkText> guestReplies = [
    (l) => l.smallTalkReply1,
    (l) => l.smallTalkReply2,
    (l) => l.smallTalkReply3,
  ];

  /// Câu mở riêng của từng nhân viên (Ami, Hạnh chưa có → dùng câu mở của Mai).
  static final Map<String, TalkText> staffOpeners = {
    'staff_nora': (l) => l.smallTalkNora,
    'staff_bao': (l) => l.smallTalkBao,
    'staff_theo': (l) => l.smallTalkTheo,
  };

  /// Dựng đoạn chuyện phiếm từ kết quả `TalkPick.smallTalk`: [byMai] = Mai nói; không thì nhân viên [staffId] (vai
  /// [TalkRole.staff]). [openIndex] / [replyIndex] lấy từ `TalkPick`.
  static TalkStory build({required bool byMai, String? staffId, required int openIndex, required int replyIndex}) {
    final TalkText opener = byMai
        ? maiOpeners[openIndex % maiOpeners.length]
        : (staffOpeners[staffId] ?? maiOpeners[openIndex % maiOpeners.length]);
    return TalkStory(
      'smallTalk',
      cast: const {},
      start: 'n0',
      nodes: {
        'n0': TalkNode('n0', lines: [
          _l(byMai ? TalkRole.mai : TalkRole.staff, opener),
          _l(TalkRole.a, guestReplies[replyIndex % guestReplies.length], anim: TalkAnim.happy),
        ]),
      },
    );
  }
}
