/// Kỷ lục của một level (lưu trong `progress.levels` của bản lưu v2).
class LevelRecord {
  const LevelRecord({this.stars = 0, this.best = 0, this.plays = 0, this.firstWin = false});

  /// 0..3, sao cao nhất từng đạt.
  final int stars;

  /// Giá trị mục tiêu cao nhất từng đạt (cùng đơn vị với mốc sao của level).
  final int best;

  /// Số lượt chơi đã kết thúc (thắng hay thua; thoát giữa chừng không tính).
  final int plays;

  /// Thắng ngay ở lượt chơi đầu tiên.
  final bool firstWin;

  /// Đã qua level (≥ 1★).
  bool get completed => stars > 0;

  LevelRecord copyWith({int? stars, int? best, int? plays, bool? firstWin}) => LevelRecord(
        stars: stars ?? this.stars,
        best: best ?? this.best,
        plays: plays ?? this.plays,
        firstWin: firstWin ?? this.firstWin,
      );

  Map<String, dynamic> toJson() => {'stars': stars, 'best': best, 'plays': plays, 'firstWin': firstWin};

  @override
  bool operator ==(Object other) =>
      other is LevelRecord &&
      other.stars == stars &&
      other.best == best &&
      other.plays == plays &&
      other.firstWin == firstWin;

  @override
  int get hashCode => Object.hash(stars, best, plays, firstWin);

  @override
  String toString() => 'LevelRecord(stars=$stars best=$best plays=$plays firstWin=$firstWin)';
}

/// Thay đổi tiến trình sau một lượt chơi (`GameState.applyLevelResult`) — UI dùng cho hoạt cảnh trên bản đồ.
class LevelProgressDelta {
  const LevelProgressDelta({
    required this.levelId,
    required this.oldStars,
    required this.newStars,
    required this.newBest,
    this.unlockedLevel,
    this.unlockedChapter,
    this.newUnlocks = const [],
    this.seasonPoints = 0,
    this.gems = 0,
    this.boosterGift = false,
  });

  final int levelId;

  /// Sao kỷ lục trước lượt này (0 nếu chưa qua).
  final int oldStars;

  /// Sao kỷ lục sau lượt này (= max(cũ, sao lượt này)).
  final int newStars;

  /// Vượt kỷ lục mục tiêu cũ (lượt chơi đầu tiên không tính là kỷ lục mới).
  final bool newBest;

  /// Level vừa mở khoá nhờ lượt này (id nhỏ nhất nếu nhiều); null nếu không có.
  final int? unlockedLevel;

  /// Chương vừa mở khoá nhờ lượt này; null nếu không có.
  final int? unlockedChapter;

  /// Mục vừa tới mốc level nhờ lượt này, theo level tăng dần (khoá `UnlockKeys`): id mục mở khoá (mở rộng, nhân viên
  /// "Sắp có"…) và cấp thiết bị mới `eq:<id>:<cấp>` (cấp chưa sở hữu). Rỗng nếu không có.
  final List<String> newUnlocks;

  /// Điểm thẻ mùa cộng ở lượt này (0 nếu không có mùa đang diễn ra).
  final int seasonPoints;

  /// Kim cương kiếm ở lượt này (lần đầu 3★ một level, hết chương, thành thạo món…).
  final int gems;

  /// Lượt này vừa mở vật phẩm hỗ trợ (tới L4): `BoosterEffects.introGift` ×1 đã vào kho.
  final bool boosterGift;

  /// Số sao mới thêm vào tổng (hoạt cảnh sao bay vào nút).
  int get gainedStars => newStars - oldStars;

  @override
  String toString() => 'LevelProgressDelta(L$levelId $oldStars→$newStars newBest=$newBest '
      'unlockedLevel=$unlockedLevel unlockedChapter=$unlockedChapter newUnlocks=$newUnlocks '
      'season+$seasonPoints gems+$gems${boosterGift ? ' boosterGift' : ''})';
}
