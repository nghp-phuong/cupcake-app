import 'talk_model.dart';

/// Dữ liệu 3 sự kiện gây gổ Q1–Q3 (docs/v3/interaction-spec.md mục 3). Lịch và trạng thái ở `quarrel_director.dart`.
///
/// Vai: [TalkRole.a] / [TalkRole.b] = hai khách của sự kiện (id trong `cast`, thứ tự A rồi B); [TalkRole.mai] = Mai
/// can ngăn; [TalkRole.winner] / [TalkRole.loser] = người thắng / thua sau [TalkSideEffect.randomWinner] (lớp nối bốc
/// thăm khi người chơi chọn rồi ánh xạ về a / b); [TalkRole.hoa] = ông Hòa nói vọng ra.
///
/// Sự kiện Q3 có nhánh thay thế khi không có ông Hòa trong cảnh: chạy bằng `TalkRunner(story, useAlt: true)`.

TalkLine _l(TalkRole who, TalkText t, {TalkAnim? anim, TalkLine? alt}) =>
    TalkLine(who, t, anim: anim, alt: alt);

abstract final class QuarrelEvents {
  /// Id nút lựa chọn trong node `choice` của mọi sự kiện: A, B, C theo thứ tự.
  static const String choiceNode = 'n0';

  /// Q1 "Chiếc cupcake dâu cuối cùng": A = Bạn Sóc, B = Bé Hamster.
  static final TalkStory lastCake = TalkStory(
    'lastCake',
    cast: const {'regular_04', 'regular_01'},
    start: choiceNode,
    nodes: {
      choiceNode: TalkNode(choiceNode, lines: [
        _l(TalkRole.a, (l) => l.quarrelLastCakeL1, anim: TalkAnim.argue),
        _l(TalkRole.b, (l) => l.quarrelLastCakeL2, anim: TalkAnim.argue),
        _l(TalkRole.a, (l) => l.quarrelLastCakeL3, anim: TalkAnim.argue),
        _l(TalkRole.mai, (l) => l.quarrelLastCakeL4),
      ], choices: [
        // A: chia đôi — cả hai vui, vào tiệm.
        TalkChoice((l) => l.quarrelLastCakeA, 'ra',
            outcome: const TalkOutcome(
              hearts: 2,
              coins: 10,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
            )),
        // B: oẳn tù tì — người thắng (ngẫu nhiên) vào tiệm, người thua phụng phịu bỏ về.
        TalkChoice((l) => l.quarrelLastCakeB, 'rb',
            outcome: const TalkOutcome(hearts: 1, coins: 10, effect: TalkSideEffect.randomWinner)),
        // C: mẻ mới — cả hai rất vui, chờ 30 s trước cửa rồi vào tiệm.
        TalkChoice((l) => l.quarrelLastCakeC, 'rc',
            outcome: const TalkOutcome(
              hearts: 3,
              coins: 20,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
              effect: TalkSideEffect.delayedEnter,
            )),
      ]),
      'ra': TalkNode('ra', lines: [
        _l(TalkRole.b, (l) => l.quarrelLastCakeRA1, anim: TalkAnim.happy),
        _l(TalkRole.a, (l) => l.quarrelLastCakeRA2, anim: TalkAnim.laugh),
      ]),
      'rb': TalkNode('rb', lines: [
        _l(TalkRole.mai, (l) => l.quarrelLastCakeRB1),
        _l(TalkRole.winner, (l) => l.quarrelLastCakeRB2, anim: TalkAnim.happy),
        _l(TalkRole.loser, (l) => l.quarrelLastCakeRB3, anim: TalkAnim.pout),
      ]),
      'rc': TalkNode('rc', lines: [
        _l(TalkRole.a, (l) => l.quarrelLastCakeRC1, anim: TalkAnim.surprised),
        _l(TalkRole.b, (l) => l.quarrelLastCakeRC2, anim: TalkAnim.happy),
      ]),
    },
  );

  /// Q2 "Ai đến trước?": A = Cậu Shiba, B = Bạn Mèo Mun.
  static final TalkStory first = TalkStory(
    'first',
    cast: const {'regular_05', 'regular_06'},
    start: choiceNode,
    nodes: {
      choiceNode: TalkNode(choiceNode, lines: [
        _l(TalkRole.a, (l) => l.quarrelFirstL1, anim: TalkAnim.argue),
        _l(TalkRole.b, (l) => l.quarrelFirstL2, anim: TalkAnim.argue),
        _l(TalkRole.a, (l) => l.quarrelFirstL3, anim: TalkAnim.argue),
        _l(TalkRole.b, (l) => l.quarrelFirstL4, anim: TalkAnim.argue),
        _l(TalkRole.mai, (l) => l.quarrelFirstL5),
      ], choices: [
        // A: vào cùng nhau, tấm biển "mở cửa" bị lệch.
        TalkChoice((l) => l.quarrelFirstA, 'ra',
            outcome: const TalkOutcome(
              hearts: 1,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
              effect: TalkSideEffect.signCrooked,
            )),
        // B: xem dấu chân — vào tiệm, mèo để lại tiền tip.
        TalkChoice((l) => l.quarrelFirstB, 'rb',
            outcome: const TalkOutcome(
              hearts: 2,
              coins: 5,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
              effect: TalkSideEffect.catTip,
            )),
        // C: kể chuyện cười — khách trong 3 m cười theo.
        TalkChoice((l) => l.quarrelFirstC, 'rc',
            outcome: const TalkOutcome(
              hearts: 3,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
              effect: TalkSideEffect.crowdLaughs,
            )),
      ]),
      'ra': TalkNode('ra', lines: [
        _l(TalkRole.a, (l) => l.quarrelFirstRA1),
        _l(TalkRole.b, (l) => l.quarrelFirstRA2),
        _l(TalkRole.narrator, (l) => l.quarrelFirstRA3, anim: TalkAnim.laugh),
      ]),
      'rb': TalkNode('rb', lines: [
        _l(TalkRole.mai, (l) => l.quarrelFirstRB1),
        _l(TalkRole.a, (l) => l.quarrelFirstRB2, anim: TalkAnim.shrug),
        _l(TalkRole.b, (l) => l.quarrelFirstRB3, anim: TalkAnim.happy),
      ]),
      'rc': TalkNode('rc', lines: [
        _l(TalkRole.a, (l) => l.quarrelFirstRC1, anim: TalkAnim.laugh),
        _l(TalkRole.b, (l) => l.quarrelFirstRC2, anim: TalkAnim.laugh),
      ]),
    },
  );

  /// Q3 "Tart trứng hay pie táo?": A = Bác Hải Mã, B = Bác Sư Tử. Lựa chọn C / RC1 có bản thay thế khi không có ông
  /// Hòa (`useAlt: true`).
  static final TalkStory tart = TalkStory(
    'tart',
    cast: const {'regular_13', 'regular_14'},
    start: choiceNode,
    nodes: {
      choiceNode: TalkNode(choiceNode, lines: [
        _l(TalkRole.a, (l) => l.quarrelTartL1, anim: TalkAnim.argue),
        _l(TalkRole.b, (l) => l.quarrelTartL2, anim: TalkAnim.argue),
        _l(TalkRole.a, (l) => l.quarrelTartL3, anim: TalkAnim.argue),
        _l(TalkRole.b, (l) => l.quarrelTartL4, anim: TalkAnim.argue),
        _l(TalkRole.mai, (l) => l.quarrelTartL5),
      ], choices: [
        // A: nếm thử mù — cả hai vui, vào tiệm.
        TalkChoice((l) => l.quarrelTartA, 'ra',
            outcome: const TalkOutcome(
              hearts: 3,
              coins: 30,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy},
              joinQueue: {TalkRole.a, TalkRole.b},
            )),
        // B: bắt tay — vào tiệm nhưng vẫn lườm nhau (phụng phịu 10 s).
        TalkChoice((l) => l.quarrelTartB, 'rb',
            outcome: const TalkOutcome(
              coins: 10,
              mood: {TalkRole.a: TalkMood.pout, TalkRole.b: TalkMood.pout},
              joinQueue: {TalkRole.a, TalkRole.b},
              effect: TalkSideEffect.glareAtEachOther,
            )),
        // C / CAlt: phân xử — Hải Mã vui vào tiệm, Sư Tử phồng má bỏ về.
        TalkChoice((l) => l.quarrelTartC, 'rc',
            altLabel: (l) => l.quarrelTartCAlt,
            outcome: const TalkOutcome(
              hearts: 2,
              coins: 10,
              mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.pout},
              joinQueue: {TalkRole.a},
              leave: {TalkRole.b},
            )),
      ]),
      'ra': TalkNode('ra', lines: [
        _l(TalkRole.a, (l) => l.quarrelTartRA1, anim: TalkAnim.surprised),
        _l(TalkRole.b, (l) => l.quarrelTartRA2, anim: TalkAnim.surprised),
        _l(TalkRole.a, (l) => l.quarrelTartRA3, anim: TalkAnim.laugh),
      ]),
      'rb': TalkNode('rb', lines: [
        _l(TalkRole.b, (l) => l.quarrelTartRB1, anim: TalkAnim.pout),
        _l(TalkRole.a, (l) => l.quarrelTartRB2, anim: TalkAnim.pout),
      ]),
      'rc': TalkNode('rc', lines: [
        _l(TalkRole.hoa, (l) => l.quarrelTartRC1,
            alt: _l(TalkRole.mai, (l) => l.quarrelTartRC1Alt, anim: TalkAnim.nod)),
        _l(TalkRole.a, (l) => l.quarrelTartRC2, anim: TalkAnim.happy),
        _l(TalkRole.b, (l) => l.quarrelTartRC3, anim: TalkAnim.pout),
      ]),
    },
  );

  /// Theo id sự kiện của `QuarrelDirector` (`lastCake`, `first`, `tart`).
  static final Map<String, TalkStory> byId = {'lastCake': lastCake, 'first': first, 'tart': tart};

  static final List<TalkStory> all = [lastCake, first, tart];
}
