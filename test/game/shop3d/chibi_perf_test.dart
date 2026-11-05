import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Chi phí cập nhật dàn chibi mỗi khung (phần Dart thuần của `Shop3dScene._updateChibis`) và số lệnh `setTransform` cần
/// gửi khi chỉ gửi bộ phận có ma trận đổi (số liệu ở docs/v3/thermion-api-notes.md mục 9.27). Thời gian chỉ để ghi lại
/// (máy test khác máy chơi), kiểm tra chỉ chặn trên rất rộng.
void main() {
  test('dàn mặc định (8 + Mochi): thời gian cập nhật Dart và tỉ lệ bộ phận có ma trận đổi mỗi khung', () {
    const dt = 1 / 60;
    const owned = {Shop3dRequires.cafeTables};
    final cast = ChibiCast.build(mochi: true);
    final director = ChibiDirector(cast);
    final parts = [
      for (final a in cast)
        [
          for (final p in ChibiPart.values)
            if (a.model.meshes.containsKey(p)) p,
        ],
    ];
    final total = parts.fold<int>(0, (s, l) => s + l.length);
    final sent = [for (final l in parts) Float64List(l.length * 16)..fillRange(0, l.length * 16, double.nan)];
    // Khởi động: 20 s kịch bản (khách vào, ngồi, nhân viên làm việc) — không đo.
    for (var t = 0.0; t < 20; t += dt) {
      director.update(dt, owned);
    }
    var changed = 0, frames = 0;
    final watch = Stopwatch()..start();
    for (var t = 0.0; t < 60; t += dt) {
      director.update(dt, owned);
      for (var i = 0; i < cast.length; i++) {
        final world = cast[i].rig.world;
        for (var j = 0; j < parts[i].length; j++) {
          final w = world[parts[i][j].index];
          var k = 0;
          while (k < 16 && sent[i][j * 16 + k] == w[k]) {
            k++;
          }
          if (k == 16) continue;
          sent[i].setRange(j * 16, j * 16 + 16, w);
          changed++;
        }
      }
      frames++;
    }
    watch.stop();
    final usPerFrame = watch.elapsedMicroseconds / frames;
    final perFrame = changed / frames;
    // ignore: avoid_print
    print('chibi: ${cast.length} actors, $total parts; Dart update ${usPerFrame.toStringAsFixed(0)} µs/frame (VM); '
        'setTransform needed ${perFrame.toStringAsFixed(1)} / $total per frame '
        '(${(100 - perFrame / total * 100).toStringAsFixed(0)} % skipped)');
    expect(perFrame, lessThanOrEqualTo(total));
    expect(perFrame, greaterThan(0));
    expect(usPerFrame, lessThan(8000));
  });
}
