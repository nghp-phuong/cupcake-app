/// Diện mạo của Mai (kiểu tóc, màu tóc). Core không chứa màu: dev-game ánh xạ enum sang hình/màu.
library;

enum MaiHair { ponytail, bob, bun, twinTails }

enum MaiHairColor { chestnut, caramel, black, strawberry }

class MaiLook {
  final MaiHair hair;
  final MaiHairColor hairColor;

  const MaiLook({
    this.hair = MaiHair.ponytail,
    this.hairColor = MaiHairColor.chestnut,
  });

  /// Trông y hệt Mai hiện nay.
  static const MaiLook defaults = MaiLook();

  MaiLook copyWith({MaiHair? hair, MaiHairColor? hairColor}) =>
      MaiLook(hair: hair ?? this.hair, hairColor: hairColor ?? this.hairColor);

  Map<String, Object?> toJson() => {
    'hair': hair.name,
    'hairColor': hairColor.name,
  };

  /// Khoá lạ hoặc thiếu → mặc định.
  factory MaiLook.fromJson(Map<String, Object?> j) {
    final h = j['hair'];
    final c = j['hairColor'];
    return MaiLook(
      hair: MaiHair.values.firstWhere(
        (e) => e.name == h,
        orElse: () => defaults.hair,
      ),
      hairColor: MaiHairColor.values.firstWhere(
        (e) => e.name == c,
        orElse: () => defaults.hairColor,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MaiLook && other.hair == hair && other.hairColor == hairColor;

  @override
  int get hashCode => Object.hash(hair, hairColor);

  @override
  String toString() => 'MaiLook(${hair.name}, ${hairColor.name})';
}

class SalonPrices {
  static const int hairStyle = 300;
  static const int hairColor = 200;

  /// Đổi kiểu +300, đổi màu +200, không đổi → 0.
  static int priceFor(MaiLook from, MaiLook to) =>
      (from.hair != to.hair ? hairStyle : 0) +
      (from.hairColor != to.hairColor ? hairColor : 0);
}
