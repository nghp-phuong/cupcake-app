import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_model.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_runner.dart';

/// Chuỗi giả: runner không được gọi nó (ném lỗi nếu bị gọi).
String _boom(dynamic l) => throw StateError('runner không được gọi TalkText');

TalkLine _line(TalkRole who, {TalkLine? alt, TalkAnim? anim}) => TalkLine(who, _boom, alt: alt, anim: anim);

TalkChoice _choice(String next, {TalkOutcome outcome = const TalkOutcome(), TalkText? alt}) =>
    TalkChoice(_boom, next, outcome: outcome, altLabel: alt);

/// Mẫu như T1: L1 L2 L3 → [C1 | C2] → R1 | R2 → L4.
TalkStory _t1() => TalkStory(
      't1',
      cast: const {'hoa'},
      start: 'n0',
      nodes: {
        'n0': TalkNode('n0', lines: [
          _line(TalkRole.hoa),
          _line(TalkRole.mai),
          _line(TalkRole.hoa),
        ], choices: [
          _choice('r1', outcome: const TalkOutcome(hearts: 1)),
          _choice('r2', outcome: const TalkOutcome(hearts: 1, coins: 5)),
        ]),
        'r1': TalkNode('r1', lines: [_line(TalkRole.hoa)], next: 'end'),
        'r2': TalkNode('r2', lines: [_line(TalkRole.hoa)], next: 'end'),
        'end': TalkNode('end', lines: [_line(TalkRole.mai)]),
      },
    );

void main() {
  group('đi qua truyện', () {
    test('câu → câu → câu → lựa chọn → nhánh → câu cuối → xong, không gọi TalkText', () {
      final r = TalkRunner(_t1());
      final order = <TalkRole>[];
      while (r.phase == TalkPhase.line) {
        order.add(r.line!.who);
        r.advance();
      }
      expect(order, [TalkRole.hoa, TalkRole.mai, TalkRole.hoa]);
      expect(r.phase, TalkPhase.choice);
      expect(r.line, isNull);
      expect(r.choices.length, 2);
      r.choose(1);
      expect(r.phase, TalkPhase.line);
      expect(r.line!.who, TalkRole.hoa); // R2
      r.advance();
      expect(r.line!.who, TalkRole.mai); // L4 chạy sau cả hai nhánh
      r.advance();
      expect(r.finished, isTrue);
      expect(r.totals.hearts, 1);
      expect(r.totals.coins, 5);
      expect(r.choicesMade, 1);
    });

    test('nhánh C1 cũng về L4', () {
      final r = TalkRunner(_t1())
        ..skip()
        ..choose(0);
      expect(r.line!.who, TalkRole.hoa);
      r.advance();
      expect(r.line!.who, TalkRole.mai);
      r.advance();
      expect(r.finished, isTrue);
      expect(r.totals.hearts, 1);
      expect(r.totals.coins, 0);
    });

    test('advance không làm gì ở pha lựa chọn / đã xong', () {
      final r = TalkRunner(_t1())..skip();
      r.advance();
      r.advance();
      expect(r.phase, TalkPhase.choice);
      r.choose(0);
      while (!r.finished) {
        r.advance();
      }
      r.advance();
      expect(r.finished, isTrue);
    });

    test('choose sai pha / sai chỉ số: lỗi', () {
      final r = TalkRunner(_t1());
      expect(() => r.choose(0), throwsStateError);
      r.skip();
      expect(() => r.choose(2), throwsRangeError);
      expect(() => r.choose(-1), throwsRangeError);
      expect(r.phase, TalkPhase.choice);
    });
  });

  group('skip: không bao giờ bỏ qua lựa chọn', () {
    test('từ đầu: dừng ở lựa chọn kế tiếp, chưa cộng kết quả', () {
      final r = TalkRunner(_t1())..skip();
      expect(r.phase, TalkPhase.choice);
      expect(r.totals.hearts, 0);
      expect(r.choicesMade, 0);
    });

    test('đang ở lựa chọn: skip không chọn hộ', () {
      final r = TalkRunner(_t1())
        ..skip()
        ..skip()
        ..skip();
      expect(r.phase, TalkPhase.choice);
      expect(r.choicesMade, 0);
    });

    test('sau lựa chọn: skip nhảy tới cuối', () {
      final r = TalkRunner(_t1())
        ..skip()
        ..choose(1)
        ..skip();
      expect(r.finished, isTrue);
      expect(r.totals.coins, 5);
    });

    test('truyện không có lựa chọn: skip tới cuối', () {
      final s = TalkStory('chat', cast: const {'x'}, start: 'a', nodes: {
        'a': TalkNode('a', lines: [_line(TalkRole.mai), _line(TalkRole.a)], next: 'b'),
        'b': TalkNode('b', lines: [_line(TalkRole.a)]),
      });
      final r = TalkRunner(s)..skip();
      expect(r.finished, isTrue);
    });

    test('hai lựa chọn liên tiếp: skip dừng ở từng lựa chọn', () {
      final s = TalkStory('two', cast: const {'x'}, start: 'a', nodes: {
        'a': TalkNode('a', lines: [_line(TalkRole.mai)], choices: [_choice('b', outcome: const TalkOutcome(hearts: 1))]),
        'b': TalkNode('b', lines: [_line(TalkRole.a)], choices: [_choice('', outcome: const TalkOutcome(coins: 2))]),
      });
      final r = TalkRunner(s)..skip();
      expect(r.phase, TalkPhase.choice);
      r.choose(0);
      r.skip();
      expect(r.phase, TalkPhase.choice); // lựa chọn thứ hai vẫn còn
      r.choose(0);
      expect(r.finished, isTrue);
      expect(r.totals.hearts, 1);
      expect(r.totals.coins, 2);
    });
  });

  group('cộng dồn kết quả', () {
    test('hearts, coins cộng; mood ghi đè theo vai; leave, joinQueue hợp; effect nối đuôi', () {
      final s = TalkStory('q', cast: const {'a', 'b'}, start: 'a', nodes: {
        'a': TalkNode('a', choices: [
          _choice('b',
              outcome: const TalkOutcome(
                  hearts: 2,
                  coins: 10,
                  mood: {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.pout},
                  leave: {TalkRole.b},
                  joinQueue: {TalkRole.a},
                  effect: TalkSideEffect.randomWinner)),
        ]),
        'b': TalkNode('b', lines: [_line(TalkRole.mai)], choices: [
          _choice('',
              outcome: const TalkOutcome(
                  hearts: 1,
                  coins: 5,
                  mood: {TalkRole.b: TalkMood.happy},
                  joinQueue: {TalkRole.b},
                  effect: TalkSideEffect.signCrooked)),
        ]),
      });
      final r = TalkRunner(s);
      expect(r.phase, TalkPhase.choice); // node đầu không có câu → vào thẳng lựa chọn
      r.choose(0);
      r.skip();
      r.choose(0);
      expect(r.finished, isTrue);
      final t = r.totals;
      expect(t.hearts, 3);
      expect(t.coins, 15);
      expect(t.mood, {TalkRole.a: TalkMood.happy, TalkRole.b: TalkMood.happy});
      expect(t.leave, {TalkRole.b});
      expect(t.joinQueue, {TalkRole.a, TalkRole.b});
      expect(t.effects, [TalkSideEffect.randomWinner, TalkSideEffect.signCrooked]);
    });

    test('TalkTotals.add với outcome rỗng không đổi gì', () {
      final t = TalkTotals()..add(const TalkOutcome());
      expect(t.hearts, 0);
      expect(t.effects, isEmpty);
    });
  });

  group('chế độ alt (Q3: không có ông Hòa)', () {
    TalkStory q3() => TalkStory('tart', cast: const {'a', 'b'}, start: 'n', nodes: {
          'n': TalkNode('n', choices: [_choice('r', alt: _boom)], lines: [_line(TalkRole.mai)]),
          'r': TalkNode('r', lines: [
            _line(TalkRole.hoa, alt: _line(TalkRole.mai)),
            _line(TalkRole.a),
          ]),
        });

    test('dùng câu và nhãn thay thế khi useAlt', () {
      final alt = TalkRunner(q3(), useAlt: true)..skip();
      expect(alt.choices[0].altLabel, isNotNull);
      expect(identical(alt.labelOf(0), alt.choices[0].altLabel), isTrue);
      alt.choose(0);
      expect(alt.line!.who, TalkRole.mai);
      alt.advance();
      expect(alt.line!.who, TalkRole.a); // câu không có alt giữ nguyên

      final normal = TalkRunner(q3())..skip();
      expect(identical(normal.labelOf(0), normal.choices[0].label), isTrue);
      normal.choose(0);
      expect(normal.line!.who, TalkRole.hoa);
    });
  });

  group('node rỗng, dữ liệu hỏng', () {
    test('node không có câu chuyển tiếp thẳng sang node kế', () {
      final s = TalkStory('skipEmpty', cast: const {'x'}, start: 'a', nodes: {
        'a': const TalkNode('a', next: 'b'),
        'b': TalkNode('b', lines: [_line(TalkRole.mai)]),
      });
      final r = TalkRunner(s);
      expect(r.line!.who, TalkRole.mai);
      r.advance();
      expect(r.finished, isTrue);
    });

    test('vòng node rỗng không treo', () {
      final s = TalkStory('loop', cast: const {'x'}, start: 'a', nodes: {
        'a': const TalkNode('a', next: 'b'),
        'b': const TalkNode('b', next: 'a'),
      });
      expect(() => TalkRunner(s), throwsStateError);
    });

    test('node không tồn tại: lỗi rõ ràng', () {
      final s = TalkStory('bad', cast: const {'x'}, start: 'zzz', nodes: const {});
      expect(() => TalkRunner(s), throwsStateError);
    });
  });

  group('TalkStory.validate', () {
    test('truyện đúng: không lỗi', () {
      expect(_t1().validate(), isEmpty);
    });

    test('phát hiện node không tới được, next gãy, lựa chọn trỏ hỏng, thiếu node đầu', () {
      final s = TalkStory('bad', cast: const {'x'}, start: 'a', nodes: {
        'a': TalkNode('a', lines: [_line(TalkRole.mai)], choices: [_choice('ghost')]),
        'orphan': TalkNode('orphan', lines: [_line(TalkRole.mai)], next: 'ghost2'),
      });
      final e = s.validate();
      expect(e.any((m) => m.contains('ghost')), isTrue);
      expect(e.any((m) => m.contains('ghost2')), isTrue);
      expect(e.any((m) => m.contains('orphan') && m.contains('không tới được')), isTrue);
      final noStart = TalkStory('n', cast: const {'x'}, start: 'q', nodes: const {});
      expect(noStart.validate().any((m) => m.contains('thiếu node bắt đầu')), isTrue);
    });
  });
}
