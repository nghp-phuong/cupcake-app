import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_model.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/talk_picker.dart';

String _t(dynamic l) => '';

TalkStory _story(String id, Set<String> cast, {TalkCondition? when}) => TalkStory(id,
    cast: cast, when: when, start: 'a', nodes: {'a': TalkNode('a', lines: [TalkLine(TalkRole.mai, _t)])});

void main() {
  final hoa = _story('owl', {'hoa'});
  final squirrel = _story('nut', {'regular_04'}, when: (w) => w.doneEvents.contains('lastCake'));
  final mochi = _story('belly', {'mochi'}, when: (w) => w.present.contains('mochi'));
  final stories = [hoa, squirrel, mochi];
  const world = TalkWorld();

  test('Mai nói chuyện với khách có truyện chưa xem: ra truyện', () {
    final l = TalkLedger();
    final p = l.pick(guestId: 'hoa', byMai: true, stories: stories, world: world, now: 0);
    expect(p.kind, TalkPickKind.story);
    expect(p.story, same(hoa));
  });

  test('truyện chạy 1 lần mỗi phiên; lần sau là chuyện phiếm', () {
    final l = TalkLedger();
    l.finishStory('owl', 'hoa', 1);
    expect(l.storySeen('owl'), isTrue);
    final p = l.pick(guestId: 'hoa', byMai: true, stories: stories, world: world, now: 100);
    expect(p.kind, TalkPickKind.smallTalk);
    expect(p.heartsGranted, 1);
  });

  test('điều kiện when: truyện sau sự kiện / chỉ khi có Mochi', () {
    final l = TalkLedger();
    expect(l.storyFor('regular_04', stories, world), isNull);
    expect(l.storyFor('regular_04', stories, const TalkWorld(doneEvents: {'lastCake'})), same(squirrel));
    expect(l.storyFor('mochi', stories, world), isNull);
    expect(l.storyFor('mochi', stories, const TalkWorld(present: {'mochi'})), same(mochi));
  });

  test('khách không có truyện: chuyện phiếm +1♥, hồi chiêu 45 s mỗi khách', () {
    final l = TalkLedger(rng: math.Random(1));
    var p = l.pick(guestId: 'g1', byMai: true, stories: stories, world: world, now: 0);
    expect(p.kind, TalkPickKind.smallTalk);
    expect(p.heartsGranted, 1);
    expect(p.openIndex >= 0 && p.openIndex < TalkLedger.maiOpeners, isTrue);
    expect(p.replyIndex >= 0 && p.replyIndex < TalkLedger.guestReplies, isTrue);
    p = l.pick(guestId: 'g1', byMai: true, stories: stories, world: world, now: 44);
    expect(p.heartsGranted, 0); // còn hồi chiêu nhưng vẫn nói chuyện được
    p = l.pick(guestId: 'g1', byMai: true, stories: stories, world: world, now: 45);
    expect(p.heartsGranted, 1);
    p = l.pick(guestId: 'g2', byMai: true, stories: stories, world: world, now: 46);
    expect(p.heartsGranted, 1); // khách khác không bị ảnh hưởng
  });

  test('nhân viên khác Mai: luôn chuyện phiếm (kể cả khách có truyện), tối đa 1♥ mỗi khách / 60 s', () {
    final l = TalkLedger();
    var p = l.pick(guestId: 'hoa', byMai: false, stories: stories, world: world, now: 0);
    expect(p.kind, TalkPickKind.smallTalk);
    expect(p.heartsGranted, 1);
    p = l.pick(guestId: 'hoa', byMai: false, stories: stories, world: world, now: 59);
    expect(p.heartsGranted, 0);
    p = l.pick(guestId: 'hoa', byMai: false, stories: stories, world: world, now: 60);
    expect(p.heartsGranted, 1);
    expect(l.storySeen('owl'), isFalse);
  });

  test('trần 3♥ mỗi khách mỗi phiên', () {
    final l = TalkLedger();
    expect(l.finishStory('owl', 'hoa', 2), 2);
    var total = l.heartsGiven('hoa');
    expect(total, 2);
    var p = l.pick(guestId: 'hoa', byMai: true, stories: stories, world: world, now: 0);
    expect(p.heartsGranted, 1);
    expect(l.heartsGiven('hoa'), 3);
    p = l.pick(guestId: 'hoa', byMai: true, stories: stories, world: world, now: 100);
    expect(p.heartsGranted, 0);
    expect(l.grantHearts('hoa', 5), 0);
    expect(l.grantHearts('khac', 5), 3);
    total = l.heartsGiven('khac');
    expect(total, 3);
  });

  test('reset xoá sổ', () {
    final l = TalkLedger()
      ..finishStory('owl', 'hoa', 3)
      ..reset();
    expect(l.storySeen('owl'), isFalse);
    expect(l.heartsGiven('hoa'), 0);
  });
}
