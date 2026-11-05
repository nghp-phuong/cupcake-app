import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/quarrel_events.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_model.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_picker.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_runner.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_stories.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

/// Mọi đường đi từ node bắt đầu tới cuối: số câu thoại và số lựa chọn trên từng đường.
List<({int lines, int choices})> _paths(TalkStory s) {
  final out = <({int lines, int choices})>[];
  void walk(String id, int lines, int choices, int depth) {
    expect(depth < 50, isTrue, reason: '${s.id}: vòng lặp');
    final n = s.nodes[id]!;
    final l = lines + n.lines.length;
    if (n.choices.isNotEmpty) {
      for (final c in n.choices) {
        if (c.next == TalkNode.endId) {
          out.add((lines: l, choices: choices + 1));
        } else {
          walk(c.next, l, choices + 1, depth + 1);
        }
      }
      return;
    }
    final nx = n.next;
    if (nx == null || nx == TalkNode.endId) {
      out.add((lines: l, choices: choices));
    } else {
      walk(nx, l, choices, depth + 1);
    }
  }

  walk(s.start, 0, 0, 0);
  return out;
}

/// Gọi mọi TalkText của truyện (câu, câu alt, nhãn, nhãn alt) và kiểm tra chuỗi khác rỗng.
void _expectAllTextsResolve(TalkStory s, AppLocalizations l) {
  void check(TalkText t, String what) {
    final v = t(l);
    expect(v.isNotEmpty, isTrue, reason: '${s.id} $what rỗng');
  }

  for (final n in s.nodes.values) {
    for (final line in n.lines) {
      check(line.text, '${n.id} câu');
      if (line.alt != null) check(line.alt!.text, '${n.id} câu alt');
    }
    for (final c in n.choices) {
      check(c.label, '${n.id} nhãn');
      if (c.altLabel != null) check(c.altLabel!, '${n.id} nhãn alt');
    }
  }
}

void main() {
  final locales = [const Locale('vi'), const Locale('en')];

  group('8 mẩu chuyện T1–T8', () {
    test('đủ 8 truyện, id không trùng, validate() không lỗi', () {
      expect(TalkStories.all.length, 8);
      expect(TalkStories.all.map((s) => s.id).toSet().length, 8);
      for (final s in TalkStories.all) {
        expect(s.validate(), isEmpty, reason: s.id);
      }
    });

    test('mỗi nhánh 4–8 câu thoại và 1–2 lựa chọn; mỗi truyện có đúng 2 nhánh', () {
      for (final s in TalkStories.all) {
        final paths = _paths(s);
        expect(paths.length, 2, reason: s.id);
        for (final p in paths) {
          expect(p.lines >= 4 && p.lines <= 8, isTrue, reason: '${s.id}: ${p.lines} câu');
          expect(p.choices >= 1 && p.choices <= 2, isTrue, reason: '${s.id}: ${p.choices} lựa chọn');
        }
      }
    });

    test('cast và điều kiện mở khoá', () {
      final byId = {for (final s in TalkStories.all) s.id: s};
      expect(byId['owl']!.cast, {'hoa'});
      expect(byId['sketch']!.cast, {'linh'});
      expect(byId['cloud']!.cast, {'kenji'});
      expect(byId['secret']!.cast, {'vip_00'});
      expect(byId['belly']!.cast, {'mochi'});
      expect(byId['fish']!.cast, {'regular_13'});
      expect(byId['nut']!.cast, {'regular_04'});
      expect(byId['cheeks']!.cast, {'regular_01'});
      const none = TalkWorld();
      expect(byId['owl']!.availableIn(none), isTrue);
      expect(byId['belly']!.availableIn(none), isFalse);
      expect(byId['belly']!.availableIn(const TalkWorld(present: {'mochi'})), isTrue);
      expect(byId['fish']!.availableIn(const TalkWorld(doneEvents: {'lastCake'})), isFalse);
      expect(byId['fish']!.availableIn(const TalkWorld(doneEvents: {'tart'})), isTrue);
      for (final id in ['nut', 'cheeks']) {
        expect(byId[id]!.availableIn(none), isFalse);
        expect(byId[id]!.availableIn(const TalkWorld(doneEvents: {'lastCake'})), isTrue);
      }
    });

    test('kết quả từng lựa chọn đúng bảng đặc tả', () {
      // (id, [hearts, coins] của C1, [hearts, coins] của C2)
      const expected = {
        'owl': ([1, 0], [1, 5]),
        'sketch': ([1, 0], [2, 0]),
        'cloud': ([1, 5], [1, 0]),
        'secret': ([1, 15], [2, 0]),
        'belly': ([1, 0], [1, 0]),
        'fish': ([1, 5], [1, 0]),
        'nut': ([1, 0], [2, 0]),
        'cheeks': ([1, 5], [1, 0]),
      };
      for (final s in TalkStories.all) {
        final choices = s.nodes[s.start]!.choices;
        final (c1, c2) = expected[s.id]!;
        expect([choices[0].outcome.hearts, choices[0].outcome.coins], c1, reason: s.id);
        expect([choices[1].outcome.hearts, choices[1].outcome.coins], c2, reason: s.id);
        final eff = choices.map((c) => c.outcome.effect).toList();
        expect(eff, s.id == 'belly' ? [null, TalkSideEffect.mochiChaseYarn] : [null, null], reason: s.id);
      }
    });

    test('chạy hết bằng runner (cả hai lựa chọn) và cộng đúng', () {
      for (final s in TalkStories.all) {
        for (var i = 0; i < 2; i++) {
          final r = TalkRunner(s)..skip();
          expect(r.phase, TalkPhase.choice, reason: s.id);
          r.choose(i);
          r.skip();
          expect(r.finished, isTrue, reason: s.id);
          expect(r.totals.hearts >= 1, isTrue, reason: s.id);
        }
      }
    });

    for (final locale in locales) {
      test('mọi chuỗi gọi được (${locale.languageCode}) và khác rỗng', () {
        final l = lookupAppLocalizations(locale);
        for (final s in TalkStories.all) {
          _expectAllTextsResolve(s, l);
        }
      });
    }
  });

  group('chuyện phiếm và tên người nói', () {
    test('số câu khớp TalkLedger', () {
      expect(TalkSmallTalk.maiOpeners.length, TalkLedger.maiOpeners);
      expect(TalkSmallTalk.guestReplies.length, TalkLedger.guestReplies);
      expect(TalkSmallTalk.staffOpeners.keys.toSet(), {'staff_nora', 'staff_bao', 'staff_theo'});
    });

    test('build: Mai và nhân viên khác, validate sạch, 2 câu', () {
      for (final byMai in [true, false]) {
        for (var o = 0; o < TalkLedger.maiOpeners; o++) {
          for (var r = 0; r < TalkLedger.guestReplies; r++) {
            final s = TalkSmallTalk.build(byMai: byMai, staffId: 'staff_bao', openIndex: o, replyIndex: r);
            expect(s.validate(), isEmpty);
            final run = TalkRunner(s);
            expect(run.line!.who, byMai ? TalkRole.mai : TalkRole.staff);
            run.advance();
            expect(run.line!.who, TalkRole.a);
            run.advance();
            expect(run.finished, isTrue);
          }
        }
      }
      // Nhân viên chưa có câu mở riêng (Ami) dùng câu của Mai.
      final ami = TalkSmallTalk.build(byMai: false, staffId: 'staff_ami', openIndex: 1, replyIndex: 0);
      expect(ami.validate(), isEmpty);
    });

    test('tên người nói có đủ và gọi được', () {
      const ids = [
        'mai', 'hoa', 'linh', 'kenji', 'vip_00', 'mochi', 'staff_nora', 'staff_bao', 'staff_theo', //
        'regular_04', 'regular_01', 'regular_05', 'regular_06', 'regular_13', 'regular_14',
      ];
      expect(TalkNames.ids.toSet(), ids.toSet());
      for (final locale in locales) {
        final l = lookupAppLocalizations(locale);
        for (final id in ids) {
          expect(TalkNames.of(id)!(l).isNotEmpty, isTrue, reason: '$id ${locale.languageCode}');
        }
      }
      expect(TalkNames.of('khong_co'), isNull);
    });

    test('mọi câu chuyện phiếm gọi được', () {
      for (final locale in locales) {
        final l = lookupAppLocalizations(locale);
        for (final t in [
          ...TalkSmallTalk.maiOpeners,
          ...TalkSmallTalk.guestReplies,
          ...TalkSmallTalk.staffOpeners.values,
        ]) {
          expect(t(l).isNotEmpty, isTrue);
        }
      }
    });
  });

  group('3 sự kiện gây gổ', () {
    test('đủ Q1–Q3, id khớp QuarrelDirector, validate() không lỗi', () {
      expect(QuarrelEvents.byId.keys.toList(), ['lastCake', 'first', 'tart']);
      expect(QuarrelEvents.all.length, 3);
      for (final s in QuarrelEvents.all) {
        expect(s.validate(), isEmpty, reason: s.id);
      }
    });

    test('cast đúng cặp khách', () {
      expect(QuarrelEvents.lastCake.cast, {'regular_04', 'regular_01'});
      expect(QuarrelEvents.first.cast, {'regular_05', 'regular_06'});
      expect(QuarrelEvents.tart.cast, {'regular_13', 'regular_14'});
    });

    test('mỗi sự kiện đúng 3 lựa chọn, mỗi lựa chọn có kết quả; mỗi nhánh có câu thoại', () {
      for (final s in QuarrelEvents.all) {
        final node = s.nodes[s.start]!;
        expect(node.choices.length, 3, reason: s.id);
        expect(node.lines.length >= 4, isTrue, reason: s.id);
        for (final c in node.choices) {
          final o = c.outcome;
          final meaningful = o.hearts != 0 ||
              o.coins != 0 ||
              o.mood.isNotEmpty ||
              o.leave.isNotEmpty ||
              o.joinQueue.isNotEmpty ||
              o.effect != null;
          expect(meaningful, isTrue, reason: '${s.id} → ${c.next}');
          expect(s.nodes[c.next]!.lines.isNotEmpty, isTrue);
        }
        for (final p in _paths(s)) {
          expect(p.choices, 1, reason: s.id);
        }
      }
    });

    test('kết quả đúng đặc tả', () {
      TalkOutcome o(TalkStory s, int i) => s.nodes[s.start]!.choices[i].outcome;
      // Q1
      var q = QuarrelEvents.lastCake;
      expect([o(q, 0).hearts, o(q, 0).coins], [2, 10]);
      expect(o(q, 0).joinQueue, {TalkRole.a, TalkRole.b});
      expect([o(q, 1).hearts, o(q, 1).coins], [1, 10]);
      expect(o(q, 1).effect, TalkSideEffect.randomWinner);
      expect([o(q, 2).hearts, o(q, 2).coins], [3, 20]);
      expect(o(q, 2).effect, TalkSideEffect.delayedEnter);
      final rb = q.nodes['rb']!.lines.map((l) => l.who).toList();
      expect(rb, [TalkRole.mai, TalkRole.winner, TalkRole.loser]);
      // Q2
      q = QuarrelEvents.first;
      expect([o(q, 0).hearts, o(q, 0).coins, o(q, 0).effect], [1, 0, TalkSideEffect.signCrooked]);
      expect([o(q, 1).hearts, o(q, 1).coins, o(q, 1).effect], [2, 5, TalkSideEffect.catTip]);
      expect([o(q, 2).hearts, o(q, 2).coins, o(q, 2).effect], [3, 0, TalkSideEffect.crowdLaughs]);
      for (var i = 0; i < 3; i++) {
        expect(o(q, i).joinQueue, {TalkRole.a, TalkRole.b});
      }
      // Q3
      q = QuarrelEvents.tart;
      expect([o(q, 0).hearts, o(q, 0).coins], [3, 30]);
      expect([o(q, 1).hearts, o(q, 1).coins, o(q, 1).effect], [0, 10, TalkSideEffect.glareAtEachOther]);
      expect(o(q, 1).mood, {TalkRole.a: TalkMood.pout, TalkRole.b: TalkMood.pout});
      expect([o(q, 2).hearts, o(q, 2).coins], [2, 10]);
      expect(o(q, 2).joinQueue, {TalkRole.a});
      expect(o(q, 2).leave, {TalkRole.b});
      expect(q.nodes[q.start]!.choices[2].altLabel, isNotNull);
    });

    test('Q3: không Hòa → dùng nhãn C Alt và câu Mai giả giọng', () {
      final normal = TalkRunner(QuarrelEvents.tart)..skip();
      final alt = TalkRunner(QuarrelEvents.tart, useAlt: true)..skip();
      expect(identical(normal.labelOf(2), QuarrelEvents.tart.nodes['n0']!.choices[2].label), isTrue);
      expect(identical(alt.labelOf(2), QuarrelEvents.tart.nodes['n0']!.choices[2].altLabel), isTrue);
      normal.choose(2);
      alt.choose(2);
      expect(normal.line!.who, TalkRole.hoa);
      expect(alt.line!.who, TalkRole.mai);
    });

    test('chạy hết bằng runner từng lựa chọn, cộng đúng', () {
      for (final s in QuarrelEvents.all) {
        for (var i = 0; i < 3; i++) {
          for (final useAlt in [false, true]) {
            final r = TalkRunner(s, useAlt: useAlt)..skip();
            r.choose(i);
            r.skip();
            expect(r.finished, isTrue, reason: '${s.id}/$i');
            final expected = s.nodes[s.start]!.choices[i].outcome;
            expect(r.totals.hearts, expected.hearts);
            expect(r.totals.coins, expected.coins);
          }
        }
      }
    });

    for (final locale in locales) {
      test('mọi chuỗi gọi được (${locale.languageCode}) và khác rỗng', () {
        final l = lookupAppLocalizations(locale);
        for (final s in QuarrelEvents.all) {
          _expectAllTextsResolve(s, l);
        }
      });
    }
  });
}
