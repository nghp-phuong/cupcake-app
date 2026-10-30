import 'dart:math' as math;

import '../level/level.dart';
import '../unlock/unlock_config.dart';
import 'progression_sim.dart';
import 'sim_runner.dart';

/// Bảng cân bằng GĐ7 (Dart thuần, không I/O) từ kết quả [simulatePersona]: mỗi màn, mỗi mốc mở khoá, tổng kết chương,
/// danh sách lệch mục tiêu; CSV; gợi ý mốc sao cho màn nháp (`SIM_CALIBRATE`).

/// Mục tiêu GĐ7 (người chơi `average`).
abstract final class SimTargets {
  /// Tỉ lệ thắng lần đầu trung bình chương 1 / chương 4.
  static const chapter1FirstWin = 0.80, chapter4FirstWin = 0.60;

  /// GĐ8: chương 3 / chương 5 (± [tolerance]).
  static const chapter3FirstWin = 0.62, chapter5FirstWin = 0.57;

  /// GĐ8: xu còn lại sau màn cuối (sau lần mua sắm cuối, gồm Bí quyết của bà) khi vắng nhà ≥ [surplusOfflineHours]
  /// giờ mỗi màn — không quá mức này (chỗ tiêu xu chương 5 hút đủ xu dư).
  static const maxEndSurplus = 60000, surplusOfflineHours = 8;

  /// Dung sai tỉ lệ thắng (điểm %).
  static const tolerance = 0.08;

  /// Mốc mua được trong ≤ chừng này màn sau khi mở (trung vị).
  static const maxLag = 3;

  /// Mua ngay lúc mở mà xu còn lại > chừng này × giá → quá rẻ.
  static const cheapSurplus = 2.0;

  /// Tỉ lệ thắng lần đầu mục tiêu theo chương khi sinh mốc 1★ ([BalanceReport.calibrateStars]). Chương 2 (giữa khoảng
  /// [chapter2FirstWin]) chỉ dùng mốc 1★ gợi ý, giữ 2★ / 3★ cân theo `level_balance_test`.
  static const draftFirstWin = {2: 0.71, 3: 0.62, 4: 0.60, 5: 0.57};

  /// Tỉ lệ thắng lần đầu riêng của vài màn khi sinh mốc 1★ (phần lệch bù vào các màn mục tiêu xu khác cùng chương).
  /// L12 (ra mắt bánh sinh nhật) phụ thuộc đồ nhiều nhất: người chơi `average` thường chơi L12 khi chưa thuê thu ngân
  /// (thuê sau L12), còn người mới có đủ "bộ đồ kỳ vọng" của `level_balance_test` thì thắng cao hơn hẳn — hạ 1★ cho L12 ≈ 71%
  /// (≈ 3800–4000 xu) thì người mới (đồ kỳ vọng) thắng 74–84%, bot 0.3 thắng 50–56%, vượt khung `level_balance_test`.
  /// Giữ L12 ≈ 50% (trên sàn 45%), phần thiếu bù vào các màn khác của chương.
  static const levelFirstWin = {12: 0.50};

  /// Chương 2 thắng lần đầu trong khoảng này (nằm giữa chương 1 ~80% và chương 4 ~60%).
  static const chapter2FirstWin = (min: 0.68, max: 0.74);

  /// Không màn nào của các chương [floorChapters] có tỉ lệ thắng lần đầu dưới mức này (chương 2 từng có L12 12%).
  static const minLevelFirstWin = 0.45;

  /// GĐ8: sàn p của màn mục tiêu xu khi sinh mốc 1★ (trước 0.40). Màn đếm khách dễ hơn chương (mốc nguyên) kéo p của màn
  /// xu xuống; sàn 0.52 giữ mọi màn xu ≥ ~50% dù dao động theo seed (L48 từng 49%).
  static const minCalibratedFirstWin = 0.52;
  static const floorChapters = {2, 3, 4, 5};

  /// % người chơi đủ sao mở chương ngay khi vừa qua hết chương trước lần đầu (không chơi lại lấy sao): mục tiêu ≈ 70–85%.
  /// Sao là số nguyên nên tỉ lệ nhảy bậc — chương 2 chỉ có 16★ → 87% hoặc 17★ → 57% — cho phép tới 88%.
  static const starGate = (min: 0.70, max: 0.88);

  /// Tỉ lệ đủ sao nhắm tới khi gợi ý `starsToUnlock` ([BalanceReport.suggestStarGates]).
  static const starGateTarget = 0.78;

  /// Trễ tối đa (màn, trung vị): dụng cụ sau khi mở; nâng nhân viên lên cấp 2 sau khi thuê được nhân viên đó.
  static const maxToolLag = 4, maxStaffUpgradeLag = 3;

  /// Phân vị của bot `good` cho mốc 2★ / 3★ khi sinh mốc sao.
  static const twoStarQuantile = 0.35, threeStarQuantile = 0.75;
}

/// Nhóm mốc mở khoá trong bảng. [maxLag]: trễ tối đa (null = không bán, không tính). [checkCheap]: "mua ngay mà dư
/// > 2 × giá" tính là lệch; dụng cụ / nâng nhân viên cấp 2 cố ý rẻ (GĐ7) nên chỉ báo cáo (△).
enum MilestoneGroup {
  expansion('mở rộng', SimTargets.maxLag, true),
  staff('nhân viên', SimTargets.maxLag, true),
  equipment('thiết bị', SimTargets.maxLag, true),
  tool('dụng cụ', SimTargets.maxToolLag, false),
  staffUpgrade('nâng NV', SimTargets.maxStaffUpgradeLag, false),
  comingSoon('sắp có', null, false);

  const MilestoneGroup(this.label, this.maxLag, this.checkCheap);
  final String label;
  final int? maxLag;
  final bool checkCheap;

  /// Tính vào mục tiêu trễ.
  bool get evaluated => maxLag != null;
}

/// Một mốc: mục mở khoá / cấp thiết bị / nâng chỉ số nhân viên lên cấp 2 (mở = level thuê được nhân viên đó).
class Milestone {
  const Milestone(this.key, this.group, this.level, this.price);

  final String key;
  final MilestoneGroup group;
  final int level;
  final int price;
}

class LevelRow {
  const LevelRow({
    required this.id,
    required this.chapter,
    required this.coinsAvg,
    required this.coinsMedian,
    required this.coinsCum,
    required this.firstWin,
    required this.tries,
    required this.stuck,
    required this.stars,
    required this.staffShare,
  });

  final int id, chapter;
  final double coinsAvg, coinsMedian, coinsCum, firstWin, tries, stuck, stars, staffShare;
}

class MilestoneRow {
  const MilestoneRow({
    required this.milestone,
    required this.medianAt,
    required this.lag,
    required this.missing,
    required this.surplus,
    required this.flag,
  });

  final Milestone milestone;

  /// Trung vị "số level đã qua lúc mua" (chưa mua hết game → tính `level cuối + 1`); null = quá nửa số lượt chưa mua.
  final double? medianAt;

  /// [medianAt] − level mở (null như trên).
  final double? lag;

  /// Số lượt chưa mua hết game.
  final int missing;

  /// Trung vị xu còn lại ngay sau khi mua (chỉ các lượt mua ngay lúc mở); null nếu không có.
  final double? surplus;

  /// '' (đạt) · 'trễ' · 'quá rẻ' ('' với mục sắp có).
  final String flag;

  /// Lệch mục tiêu: trễ quá [MilestoneGroup.maxLag], hoặc quá rẻ ở nhóm [MilestoneGroup.checkCheap].
  bool get failed => flag == 'trễ' || (flag == 'quá rẻ' && milestone.group.checkCheap);

  /// Lệch chỉ báo cáo: dụng cụ / nâng nhân viên mua ngay mà dư > 2 × giá.
  bool get soft => flag.isNotEmpty && !failed;
}

class ChapterRow {
  const ChapterRow({
    required this.chapter,
    required this.levels,
    required this.firstWin,
    required this.tries,
    required this.stuck,
    required this.coinsEnd,
    required this.starsAvg,
    required this.gems,
    required this.starGate,
    this.starsBefore,
    this.starsToUnlock = 0,
  });

  final int chapter;
  final List<int> levels;
  final double firstWin, tries, stuck, coinsEnd, starsAvg, gems;

  /// % lượt chơi đủ tổng sao mở chương này lúc qua level cuối chương trước (chương đầu: 1).
  final double starGate;

  /// Trung vị tổng sao lúc qua level cuối chương trước (chương đầu: null) / số sao cần để mở chương.
  final double? starsBefore;
  final int starsToUnlock;
}

double _avg(Iterable<num> xs) => xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

/// Phân vị [q] (0..1) nội suy tuyến tính.
double simQuantile(List<num> xs, double q) {
  if (xs.isEmpty) return 0;
  final s = [for (final x in xs) x.toDouble()]..sort();
  final pos = (s.length - 1) * q.clamp(0.0, 1.0);
  final lo = pos.floor(), hi = pos.ceil();
  return s[lo] + (s[hi] - s[lo]) * (pos - lo);
}

/// Mốc (bội của [unit]) mà tỉ lệ giá trị ≥ mốc gần [p] nhất (bằng nhau → mốc cao hơn). Rỗng → 0.
int simThresholdFor(List<int> values, double p, {int unit = 1}) {
  if (values.isEmpty) return 0;
  final candidates = {for (final v in values) (v / unit).ceil() * unit};
  var best = 0;
  var bestErr = double.infinity;
  for (final t in candidates) {
    final err = (values.where((v) => v >= t).length / values.length - p).abs();
    if (err < bestErr - 1e-12 || ((err - bestErr).abs() <= 1e-12 && t > best)) {
      best = t;
      bestErr = err;
    }
  }
  return best;
}

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

class BalanceReport {
  BalanceReport({
    required this.levels,
    required this.unlocks,
    required this.options,
    required this.runs,
    this.boosterRuns = const {},
  }) : milestones = _milestones(levels, unlocks);

  final LevelConfig levels;
  final UnlockConfig unlocks;
  final SimOptions options;
  final Map<SimPersona, List<SimRun>> runs;

  /// Bảng "với vật phẩm" (`SIM_BOOSTERS=1`).
  final Map<SimPersona, List<SimRun>> boosterRuns;
  final List<Milestone> milestones;

  int get lastLevel => levels.levels.last.id;

  static List<Milestone> _milestones(LevelConfig levels, UnlockConfig unlocks) {
    final last = levels.levels.last.id;
    final out = <Milestone>[
      for (final u in unlocks.unlocks)
        if (u.level < last)
          Milestone(
            u.id,
            u.comingSoon
                ? MilestoneGroup.comingSoon
                : (u.kind == UnlockKind.staff ? MilestoneGroup.staff : MilestoneGroup.expansion),
            u.level,
            u.price,
          ),
      for (final e in unlocks.equipment)
        for (var k = 2; k <= e.maxTier; k++)
          if (e.tier(k).level < last)
            Milestone(
              UnlockKeys.equipment(e.id, k),
              simNewEquipment.contains(e.id) ? MilestoneGroup.equipment : MilestoneGroup.tool,
              e.tier(k).level,
              e.tier(k).price,
            ),
      for (final d in unlocks.staff)
        if ((unlocks.unlock(d.id)?.level ?? last) < last)
          for (final stat in StaffStat.values)
            if (d.priceTo(stat, 2) != null)
              Milestone(
                simStaffKey(d.id, stat, 2),
                MilestoneGroup.staffUpgrade,
                unlocks.unlock(d.id)!.level,
                d.priceTo(stat, 2)!,
              ),
    ];
    final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])]
      ..sort((a, b) => a.$2.level != b.$2.level ? a.$2.level.compareTo(b.$2.level) : a.$1.compareTo(b.$1));
    return [for (final e in indexed) e.$2];
  }

  // ------------------------------------------------------------------ Bảng

  List<LevelRow> levelRows(List<SimRun> rs) {
    final out = <LevelRow>[];
    var cum = 0.0;
    for (final l in levels.levels) {
      final stats = [for (final r in rs) r.levels[l.id]].whereType<SimLevelStat>().toList();
      if (stats.isEmpty) break;
      final coins = [for (final s in stats) s.coins];
      final avg = _avg(coins);
      cum += avg;
      final served = stats.fold<int>(0, (a, s) => a + s.served);
      final staff = stats.fold<int>(0, (a, s) => a + s.staffSales);
      out.add(
        LevelRow(
          id: l.id,
          chapter: l.chapter,
          coinsAvg: avg,
          coinsMedian: simQuantile(coins, 0.5),
          coinsCum: cum,
          firstWin: _avg([for (final s in stats) s.firstWin ? 1 : 0]),
          tries: _avg([for (final s in stats) s.plays]),
          stuck: _avg([for (final s in stats) s.stuck ? 1 : 0]),
          stars: _avg([for (final s in stats) s.stars]),
          staffShare: served == 0 ? 0 : staff / served,
        ),
      );
    }
    return out;
  }

  List<MilestoneRow> milestoneRows(List<SimRun> rs) {
    final last = lastLevel;
    return [
      for (final m in milestones)
        () {
          final at = [for (final r in rs) r.boughtAt[m.key] ?? last + 1];
          final missing = at.where((a) => a > last).length;
          final median = missing * 2 > rs.length ? null : simQuantile(at, 0.5);
          final lag = median == null ? null : median - m.level;
          final instant = [
            for (final r in rs)
              if (r.boughtAt[m.key] == m.level && r.coinsLeftAfterBuy[m.key] != null) r.coinsLeftAfterBuy[m.key]!,
          ];
          final surplus = instant.isEmpty ? null : simQuantile(instant, 0.5);
          var flag = '';
          final maxLag = m.group.maxLag;
          if (maxLag != null) {
            if (lag == null || lag > maxLag) {
              flag = 'trễ';
            } else if (lag < 0.5 && surplus != null && surplus > SimTargets.cheapSurplus * m.price) {
              flag = 'quá rẻ';
            }
          }
          return MilestoneRow(milestone: m, medianAt: median, lag: lag, missing: missing, surplus: surplus, flag: flag);
        }(),
    ];
  }

  List<ChapterRow> chapterRows(List<SimRun> rs) {
    final rows = levelRows(rs);
    final out = <ChapterRow>[];
    for (final c in levels.chapters) {
      final ids = [for (final l in levels.levelsInChapter(c.id)) l.id];
      final inChapter = [
        for (final r in rows)
          if (r.chapter == c.id) r,
      ];
      if (inChapter.isEmpty) continue;
      final lastId = inChapter.last.id;
      final prev = levels.previousChapter(c.id);
      final prevLast = prev == null ? null : levels.levelsInChapter(prev.id).last.id;
      final starsBefore = prevLast == null ? null : [for (final r in rs) r.levels[prevLast]?.totalStarsAfter ?? 0];
      out.add(
        ChapterRow(
          chapter: c.id,
          levels: ids,
          firstWin: _avg([for (final r in inChapter) r.firstWin]),
          tries: _avg([for (final r in inChapter) r.tries]),
          stuck: _avg([for (final r in inChapter) r.stuck]),
          coinsEnd: _avg([for (final r in rs) r.levels[lastId]!.coinsAfter]),
          starsAvg: _avg([for (final r in inChapter) r.stars]),
          gems: _avg([
            for (final r in rs) [for (final id in ids) r.levels[id]?.gems ?? 0].fold<int>(0, (a, b) => a + b),
          ]),
          starGate: starsBefore == null ? 1 : _avg([for (final t in starsBefore) t >= c.starsToUnlock ? 1 : 0]),
          starsBefore: starsBefore == null ? null : simQuantile(starsBefore, 0.5),
          starsToUnlock: c.starsToUnlock,
        ),
      );
    }
    return out;
  }

  /// Xu TB còn lại sau màn cuối (sau lần mua sắm cuối) — chỉ khi vắng nhà ≥ [SimTargets.surplusOfflineHours] giờ/màn và
  /// có đủ 5 chương; không thì null.
  double? endSurplus(List<SimRun> rs) =>
      options.offlineHours >= SimTargets.surplusOfflineHours && levels.chapters.length >= 5 && rs.isNotEmpty
          ? _avg([for (final r in rs) r.coinsLeft])
          : null;

  /// GĐ8 (chủ dự án chọn): mục tiêu thắng lần đầu theo chương (và % đủ sao mở chương đi kèm) chỉ đo ở chế độ mặc định
  /// như GĐ7. Vắng nhà > 0 giờ/màn → các mục này chuyển sang [softIssues] (chỉ tham khảo, không tính lệch).
  bool get _chapterTargetsCounted => options.offlineHours <= 0;

  /// Lệch mục tiêu (người chơi `average`; không chạy `average` → dùng người chơi đầu tiên có trong [runs]).
  ///
  /// [rateSlack] / [lagSlack]: dung sai thêm cho các mục tiêu dạng khoảng (chương 2, sàn mỗi màn, % đủ sao) và trễ mốc —
  /// cho lần chạy ít người chơi giả (`simulate_test`); bảng đầy đủ dùng 0.
  List<String> deviations({double rateSlack = 0, double lagSlack = 0}) {
    final persona = runs.containsKey(SimPersona.average) ? SimPersona.average : runs.keys.first;
    final rs = runs[persona]!;
    final out = <String>[if (_chapterTargetsCounted) ..._chapterTargetIssues(persona, rs, rateSlack)];
    void need(bool ok, String what) {
      if (!ok) out.add('[${persona.name}] $what');
    }

    final surplus = endSurplus(rs);
    if (surplus != null) {
      need(
        surplus <= SimTargets.maxEndSurplus,
        'xu dư sau L$lastLevel (vắng nhà ${options.offlineHours} giờ/màn, sau mua sắm cuối) '
        '${surplus.toStringAsFixed(0)} > ${SimTargets.maxEndSurplus}',
      );
    }
    for (final l in levelRows(rs)) {
      if (SimTargets.floorChapters.contains(l.chapter)) {
        need(
          l.firstWin >= SimTargets.minLevelFirstWin - rateSlack,
          'L${l.id} thắng lần đầu ${_pct(l.firstWin)} < ${_pct(SimTargets.minLevelFirstWin)}',
        );
      }
    }
    for (final m in milestoneRows(rs)) {
      final withinSlack = m.flag == 'trễ' && m.lag != null && m.lag! <= m.milestone.group.maxLag! + lagSlack;
      if (m.failed && !withinSlack) out.add('[${persona.name}] ${_milestoneIssue(m)}');
    }
    return out;
  }

  /// Mục tiêu theo chương: thắng lần đầu chương 1–5, thứ tự chương, % đủ sao mở chương.
  List<String> _chapterTargetIssues(SimPersona persona, List<SimRun> rs, double rateSlack) {
    final out = <String>[];
    final ch = {for (final c in chapterRows(rs)) c.chapter: c};
    const tol = SimTargets.tolerance;
    void need(bool ok, String what) {
      if (!ok) out.add('[${persona.name}] $what');
    }

    final c1 = ch[1]?.firstWin, c4 = ch[4]?.firstWin;
    if (c1 != null) {
      need(
        (c1 - SimTargets.chapter1FirstWin).abs() <= tol,
        'chương 1 thắng lần đầu ${_pct(c1)} (mục tiêu ${_pct(SimTargets.chapter1FirstWin)} ± ${_pct(tol)})',
      );
    }
    if (c4 != null) {
      need(
        (c4 - SimTargets.chapter4FirstWin).abs() <= tol,
        'chương 4 thắng lần đầu ${_pct(c4)} (mục tiêu ${_pct(SimTargets.chapter4FirstWin)} ± ${_pct(tol)})',
      );
    }
    for (final (c, target) in const [(3, SimTargets.chapter3FirstWin), (5, SimTargets.chapter5FirstWin)]) {
      final v = ch[c]?.firstWin;
      if (v == null) continue;
      need((v - target).abs() <= tol, 'chương $c thắng lần đầu ${_pct(v)} (mục tiêu ${_pct(target)} ± ${_pct(tol)})');
    }
    final c2 = ch[2]?.firstWin;
    if (c2 != null) {
      const r = SimTargets.chapter2FirstWin;
      need(
        c2 >= r.min - rateSlack && c2 <= r.max + rateSlack,
        'chương 2 thắng lần đầu ${_pct(c2)} (mục tiêu ${_pct(r.min)}–${_pct(r.max)})',
      );
    }
    for (final c in ch.values) {
      if (c.starsBefore == null) continue;
      const g = SimTargets.starGate;
      need(
        c.starGate >= g.min - rateSlack && c.starGate <= g.max + rateSlack,
        'chương ${c.chapter}: ${_pct(c.starGate)} đủ ${c.starsToUnlock}★ để mở ngay khi qua chương trước '
        '(mục tiêu ${_pct(g.min)}–${_pct(g.max)}, sao TV ${c.starsBefore!.toStringAsFixed(0)})',
      );
    }
    if (c1 != null && c4 != null) {
      for (final c in [2, 3]) {
        final v = ch[c]?.firstWin;
        if (v == null) continue;
        need(v <= c1 + tol && v >= c4 - tol, 'chương $c thắng lần đầu ${_pct(v)} không nằm giữa chương 1 và chương 4');
      }
      final c5 = ch[5]?.firstWin;
      if (c5 != null) need(c5 <= c4 + tol, 'chương 5 thắng lần đầu ${_pct(c5)} > chương 4 (${_pct(c4)})');
    }
    return out;
  }

  /// Lệch nhẹ, không tính mục tiêu (người chơi `average`): thứ tự chương lệch nhưng còn trong dung sai; mốc ở nhóm chỉ
  /// báo cáo (dụng cụ, nâng nhân viên) trễ > 3 màn / quá rẻ. GĐ8: vắng nhà > 0 giờ/màn → thêm lệch mục tiêu theo chương
  /// (chỉ tham khảo, xem [_chapterTargetsCounted]).
  List<String> softIssues() {
    final persona = runs.containsKey(SimPersona.average) ? SimPersona.average : runs.keys.first;
    final rs = runs[persona]!;
    final ch = {for (final c in chapterRows(rs)) c.chapter: c.firstWin};
    final c1 = ch[1], c4 = ch[4];
    return [
      if (!_chapterTargetsCounted)
        for (final d in _chapterTargetIssues(persona, rs, 0))
          '$d — chỉ tham khảo: vắng nhà ${options.offlineHours} giờ/màn, mục tiêu theo chương chỉ đo ở chế độ mặc định',
      if (c1 != null && c4 != null) ...[
        for (final c in [2, 3])
          if (ch[c] != null && (ch[c]! > c1 || ch[c]! < c4))
            '[${persona.name}] chương $c thắng lần đầu ${_pct(ch[c]!)} nằm ngoài khoảng chương 4–chương 1 '
                '(${_pct(c4)}–${_pct(c1)}), còn trong dung sai ${_pct(SimTargets.tolerance)}',
        if (ch[5] != null && ch[5]! > c4)
          '[${persona.name}] chương 5 thắng lần đầu ${_pct(ch[5]!)} > chương 4 (${_pct(c4)}), còn trong dung sai',
      ],
      for (final m in milestoneRows(rs))
        if (m.soft) '[${persona.name}] ${_milestoneIssue(m)}',
    ];
  }

  static String _milestoneIssue(MilestoneRow m) {
    final lag = m.lag == null
        ? 'quá nửa số lượt chưa mua'
        : 'trễ ${m.lag!.toStringAsFixed(1)} màn (tối đa ${m.milestone.group.maxLag})';
    final surplus = m.surplus == null ? '' : ', xu dư ${m.surplus!.toStringAsFixed(0)}';
    return 'mốc ${m.milestone.key} (${m.milestone.group.label}, mở sau L${m.milestone.level}, '
        'giá ${m.milestone.price}): ${m.flag} — $lag$surplus';
  }

  // ------------------------------------------------------------------ In

  String text() {
    final b = StringBuffer();
    b.writeln(
      'Mô phỏng cân bằng L1→L$lastLevel — ${options.runs} người chơi giả / kỹ năng, seed ${options.seed}, '
      'thua tối đa ${options.maxTries} lần/màn, vắng nhà ${options.offlineHours} giờ/màn, không quảng cáo / IAP',
    );
    for (final p in runs.keys) {
      final rs = runs[p]!;
      b
        ..writeln()
        ..writeln('=== ${p.name} ===')
        ..writeln()
        ..writeln('1. Mỗi màn')
        ..writeln('màn  | ch | xu TB  | xu TV  | xu tích luỹ | thắng lần 1 | lần thử | kẹt  | sao TB | NV bán');
      for (final r in levelRows(rs)) {
        b.writeln(
          'L${'${r.id}'.padRight(3)} | ${'${r.chapter}'.padLeft(2)} | '
          '${r.coinsAvg.toStringAsFixed(0).padLeft(6)} | ${r.coinsMedian.toStringAsFixed(0).padLeft(6)} | '
          '${r.coinsCum.toStringAsFixed(0).padLeft(11)} | ${_pct(r.firstWin).padLeft(11)} | '
          '${r.tries.toStringAsFixed(2).padLeft(7)} | ${_pct(r.stuck).padLeft(4)} | '
          '${r.stars.toStringAsFixed(2).padLeft(6)} | ${_pct(r.staffShare).padLeft(6)}',
        );
      }
      b
        ..writeln()
        ..writeln(
          '2. Mốc mở khoá (✗: trễ > ${SimTargets.maxLag} màn (dụng cụ > ${SimTargets.maxToolLag}, nâng NV '
          'cấp 2 > ${SimTargets.maxStaffUpgradeLag}, tính từ màn thuê được), hoặc mua ngay lúc mở mà còn dư > '
          '${SimTargets.cheapSurplus.toStringAsFixed(0)} × giá; △: dụng cụ / nâng NV mua ngay mà dư > '
          '${SimTargets.cheapSurplus.toStringAsFixed(0)} × giá — cố ý rẻ, chỉ báo cáo)',
        )
        ..writeln(_milestoneHeader);
      for (final m in milestoneRows(rs)) {
        b.writeln(_milestoneLine(m));
      }
      b
        ..writeln()
        ..writeln('3. Tổng kết chương')
        ..writeln(_chapterHeader);
      for (final c in chapterRows(rs)) {
        b.writeln(_chapterLine(c));
      }
      final left = _avg([for (final r in rs) r.coinsLeft]);
      b.writeln('xu còn lại sau L$lastLevel (sau mua sắm cuối, gồm Bí quyết của bà): ${left.toStringAsFixed(0)}');
    }
    if (boosterRuns.isNotEmpty) {
      b
        ..writeln()
        ..writeln(
          'Với vật phẩm (người chơi không trả tiền: dùng vật phẩm có trong kho, hết thì mua bằng kim cương kiếm '
          'trong game) — tổng kết chương',
        )
        ..writeln('kỹ năng | $_chapterHeader | vật phẩm/màn');
      for (final p in boosterRuns.keys) {
        final rs = boosterRuns[p]!;
        for (final c in chapterRows(rs)) {
          final used = _avg([
            for (final id in c.levels) _avg([for (final r in rs) r.levels[id]?.boostersUsed ?? 0]),
          ]);
          b.writeln('${p.name.padRight(7)} | ${_chapterLine(c)} | ${used.toStringAsFixed(2).padLeft(12)}');
        }
      }
    }
    final dev = deviations();
    b
      ..writeln()
      ..writeln('4. Lệch mục tiêu (${dev.length})');
    if (dev.isEmpty) b.writeln('— không có');
    for (final d in dev) {
      b.writeln('✗ $d');
    }
    final soft = softIssues();
    if (soft.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Tham khảo — lệch nhẹ / nhóm ưu tiên thấp, không tính mục tiêu (${soft.length})');
      for (final d in soft) {
        b.writeln('△ $d');
      }
    }
    return b.toString();
  }

  static const _milestoneHeader =
      'mốc                         | nhóm      | mở sau L | giá   | màn TV mua | trễ  | chưa mua | xu dư TV |';

  String _milestoneLine(MilestoneRow m) {
    final ms = m.milestone;
    return '${ms.key.padRight(27)} | ${ms.group.label.padRight(9)} | ${'${ms.level}'.padLeft(8)} | '
        '${'${ms.price}'.padLeft(5)} | ${(m.medianAt == null ? '—' : m.medianAt!.toStringAsFixed(1)).padLeft(10)} | '
        '${(m.lag == null ? '—' : m.lag!.toStringAsFixed(1)).padLeft(4)} | ${'${m.missing}'.padLeft(8)} | '
        '${(m.surplus == null ? '' : m.surplus!.toStringAsFixed(0)).padLeft(8)} | '
        '${m.failed
            ? '✗ ${m.flag}'
            : m.soft
            ? '△ ${m.flag}'
            : (ms.group == MilestoneGroup.comingSoon ? '(không bán)' : '')}';
  }

  static const _chapterHeader =
      'ch | màn     | thắng lần 1 TB | lần thử TB | kẹt TB | sao TB | xu cuối chương | '
      'kim cương | đủ sao mở | sao TV / cần';

  String _chapterLine(ChapterRow c) =>
      '${'${c.chapter}'.padLeft(2)} | ${'L${c.levels.first}–${c.levels.last}'.padRight(7)} | '
      '${_pct(c.firstWin).padLeft(14)} | ${c.tries.toStringAsFixed(2).padLeft(10)} | ${_pct(c.stuck).padLeft(6)} | '
      '${c.starsAvg.toStringAsFixed(2).padLeft(6)} | ${c.coinsEnd.toStringAsFixed(0).padLeft(14)} | '
      '${c.gems.toStringAsFixed(1).padLeft(9)} | ${_pct(c.starGate).padLeft(9)} | '
      '${(c.starsBefore == null ? '—' : '${c.starsBefore!.toStringAsFixed(0)} / ${c.starsToUnlock}').padLeft(12)}';

  // ------------------------------------------------------------------ CSV

  /// CSV mỗi màn (mọi kỹ năng).
  String levelsCsv() {
    final b = StringBuffer(
      'skill,level,chapter,coins_avg,coins_median,coins_cum,first_win,tries,stuck,stars,'
      'staff_share\n',
    );
    for (final p in runs.keys) {
      for (final r in levelRows(runs[p]!)) {
        b.writeln(
          [
            p.name,
            r.id,
            r.chapter,
            r.coinsAvg.toStringAsFixed(1),
            r.coinsMedian.toStringAsFixed(1),
            r.coinsCum.toStringAsFixed(1),
            r.firstWin.toStringAsFixed(4),
            r.tries.toStringAsFixed(3),
            r.stuck.toStringAsFixed(4),
            r.stars.toStringAsFixed(3),
            r.staffShare.toStringAsFixed(4),
          ].join(','),
        );
      }
    }
    return b.toString();
  }

  /// CSV mốc mở khoá (mọi kỹ năng).
  String milestonesCsv() {
    final b = StringBuffer('skill,key,group,level,price,median_at,lag,missing,surplus_median,flag\n');
    for (final p in runs.keys) {
      for (final m in milestoneRows(runs[p]!)) {
        b.writeln(
          [
            p.name,
            m.milestone.key,
            m.milestone.group.name,
            m.milestone.level,
            m.milestone.price,
            m.medianAt?.toStringAsFixed(1) ?? '',
            m.lag?.toStringAsFixed(1) ?? '',
            m.missing,
            m.surplus?.toStringAsFixed(0) ?? '',
            m.flag,
          ].join(','),
        );
      }
    }
    return b.toString();
  }

  /// CSV tổng kết chương (mọi kỹ năng; `boosters` = 1 cho bảng với vật phẩm).
  String chaptersCsv() {
    final b = StringBuffer(
      'skill,boosters,chapter,first_win,tries,stuck,coins_end,stars,gems,star_gate,'
      'stars_median_before,stars_to_unlock\n',
    );
    for (final (table, flag) in [(runs, 0), (boosterRuns, 1)]) {
      for (final p in table.keys) {
        for (final c in chapterRows(table[p]!)) {
          b.writeln(
            [
              p.name,
              flag,
              c.chapter,
              c.firstWin.toStringAsFixed(4),
              c.tries.toStringAsFixed(3),
              c.stuck.toStringAsFixed(4),
              c.coinsEnd.toStringAsFixed(0),
              c.starsAvg.toStringAsFixed(3),
              c.gems.toStringAsFixed(1),
              c.starGate.toStringAsFixed(4),
              c.starsBefore?.toStringAsFixed(1) ?? '',
              c.starsToUnlock,
            ].join(','),
          );
        }
      }
    }
    return b.toString();
  }

  // ------------------------------------------------------------------ Sinh mốc sao

  /// `starsToUnlock` gợi ý cho mỗi chương có chương trước: số sao mà tỉ lệ người chơi `average` (không chạy `average` →
  /// người chơi đầu tiên) có đủ ngay khi vừa qua level cuối chương trước gần [SimTargets.starGateTarget] nhất (lượt chơi
  /// đầu, không chơi lại lấy sao). Kèm tỉ lệ đủ sao và trung vị tổng sao lúc đó.
  Map<int, ({int stars, double share, double median})> suggestStarGates() {
    final persona = runs.containsKey(SimPersona.average) ? SimPersona.average : runs.keys.first;
    final rs = runs[persona]!;
    final out = <int, ({int stars, double share, double median})>{};
    for (final c in levels.chapters) {
      final prev = levels.previousChapter(c.id);
      if (prev == null) continue;
      final last = levels.levelsInChapter(prev.id).last.id;
      final stars = [for (final r in rs) r.levels[last]?.totalStarsAfter ?? 0];
      final t = simThresholdFor(stars, SimTargets.starGateTarget);
      out[c.id] = (stars: t, share: stars.where((v) => v >= t).length / stars.length, median: simQuantile(stars, 0.5));
    }
    return out;
  }

  /// Mốc sao gợi ý cho các level có id > [fromLevel] (chương 3–5), theo công thức (trước GĐ8 ghi ở `_note` của bản nháp):
  /// 1★ = mốc (bội của 10 xu; khách / đơn: số nguyên) mà tỉ lệ lượt đầu của `average` đạt mốc gần p nhất (tức phân vị
  /// 1 − p), p = [SimTargets.draftFirstWin] theo chương. Màn mục tiêu khách / đơn đặc biệt (số nguyên, phân bố hẹp) và
  /// màn có p riêng ([SimTargets.levelFirstWin]) đặt trước; phần lệch so với p của chúng bù đều vào các màn mục tiêu xu
  /// còn lại cùng chương (p' kẹp [SimTargets.minCalibratedFirstWin]–0.85) để TB chương ≈ p.
  /// 2★ / 3★ = phân vị [SimTargets.twoStarQuantile] / [SimTargets.threeStarQuantile] của `good`; mỗi mốc ≥ mốc trước
  /// × 1.04 (và + 1 đơn vị). Cần chạy cả `average` và `good`.
  Map<int, List<int>> calibrateStars(int fromLevel) {
    final avg = runs[SimPersona.average], good = runs[SimPersona.good];
    if (avg == null || good == null) throw StateError('SIM_CALIBRATE cần chạy cả average và good');
    List<int> values(List<SimRun> rs, int id) => [for (final r in rs) r.levels[id]?.firstGoalValue ?? 0];
    final out = <int, List<int>>{};
    for (final c in levels.chapters) {
      final draft = [
        for (final l in levels.levelsInChapter(c.id))
          if (l.id > fromLevel) l,
      ];
      if (draft.isEmpty) continue;
      final p = SimTargets.draftFirstWin[c.id] ?? SimTargets.chapter4FirstWin;
      final coinLevels = [
        for (final l in draft)
          if (l.goal.type == GoalType.coins) l,
      ];
      final fixed = [
        for (final l in draft)
          if (l.goal.type != GoalType.coins || SimTargets.levelFirstWin.containsKey(l.id)) l,
      ];
      coinLevels.removeWhere(fixed.contains);
      var others = 0.0;
      for (final l in fixed) {
        final v = values(avg, l.id);
        final coins = l.goal.type == GoalType.coins;
        final t = math.max(1, simThresholdFor(v, SimTargets.levelFirstWin[l.id] ?? p, unit: coins ? 10 : 1));
        others += v.where((x) => x >= t).length / v.length;
        out[l.id] = [t];
      }
      final pCoins = coinLevels.isEmpty
          ? p
          : ((p * draft.length - others) / coinLevels.length).clamp(SimTargets.minCalibratedFirstWin, 0.85).toDouble();
      for (final l in coinLevels) {
        out[l.id] = [math.max(1, simThresholdFor(values(avg, l.id), pCoins, unit: 10))];
      }
      for (final l in draft) {
        final coins = l.goal.type == GoalType.coins;
        int round(double v) => coins ? (v / 10).round() * 10 : v.round();
        final unit = coins ? 10 : 1;
        final g = values(good, l.id);
        final s1 = out[l.id]!.first;
        final s2 = math.max(round(simQuantile(g, SimTargets.twoStarQuantile)), round(s1 * 1.04) + unit);
        final s3 = math.max(round(simQuantile(g, SimTargets.threeStarQuantile)), round(s2 * 1.04) + unit);
        out[l.id] = [s1, s2, s3];
      }
    }
    return {
      for (final l in levels.levels)
        if (out.containsKey(l.id)) l.id: out[l.id]!,
    };
  }
}
