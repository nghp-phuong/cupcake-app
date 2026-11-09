/// Cấu hình thành phố V3: quận, lô đất, toạ độ (mét, hệ toạ độ của lớp phố).
library;

enum LotKind { home, branch, restaurant, salon, realty, park }

class LotDef {
  final String id;
  final LotKind kind;

  /// Tâm lô.
  final double x, z;

  /// Kích thước theo x, theo z.
  final double w, d;

  /// Điểm cửa (mép lô giáp vỉa hè).
  final double doorX, doorZ;

  /// 0 = cửa quay về +z; pi = quay về -z.
  final double yaw;
  final int price, requiresLevel;

  /// Xu/giờ ở cấp 1 của chi nhánh; 0 = không phải chi nhánh.
  final int baseIncome;

  /// Khoá AppLocalizations.
  final String nameKey;

  const LotDef({
    required this.id,
    required this.kind,
    required this.x,
    required this.z,
    required this.w,
    required this.d,
    required this.doorX,
    required this.doorZ,
    required this.yaw,
    required this.price,
    required this.requiresLevel,
    this.baseIncome = 0,
    required this.nameKey,
  });

  double get minX => x - w / 2;
  double get maxX => x + w / 2;
  double get minZ => z - d / 2;
  double get maxZ => z + d / 2;
}

class DistrictDef {
  final String id, nameKey;
  final double minX, maxX, minZ, maxZ;
  final double roadHalfWidth;
  final double sidewalkOuter;
  final double busX, busZ, spawnX, spawnZ;
  final List<LotDef> lots;

  const DistrictDef({
    required this.id,
    required this.nameKey,
    required this.minX,
    required this.maxX,
    required this.minZ,
    required this.maxZ,
    required this.roadHalfWidth,
    required this.sidewalkOuter,
    required this.busX,
    required this.busZ,
    required this.spawnX,
    required this.spawnZ,
    required this.lots,
  });

  /// Lô theo id; ném [StateError] nếu không có.
  LotDef lot(String id) => lots.firstWhere(
    (l) => l.id == id,
    orElse: () => throw StateError('Không có lô "$id" trong quận "${this.id}"'),
  );

  /// Lô đầu tiên thuộc loại [k], hoặc null.
  LotDef? lotOfKind(LotKind k) {
    for (final l in lots) {
      if (l.kind == k) return l;
    }
    return null;
  }
}

extension DistrictBranchNumber on DistrictDef {
  /// Số thứ tự chi nhánh: s1 = 1, s3 = 2, s4 = 3 (theo thứ tự các lô có `baseIncome > 0`); 0 nếu không phải chi nhánh.
  int branchNumber(String lotId) {
    var n = 0;
    for (final l in lots) {
      if (l.baseIncome <= 0) continue;
      n++;
      if (l.id == lotId) return n;
    }
    return 0;
  }
}

class CityConfig {
  final List<DistrictDef> districts;

  const CityConfig({required this.districts});

  static const double _lotW = 11;
  static const double _lotD = 10;
  static const double _pi = 3.141592653589793;

  static const CityConfig alpha = CityConfig(
    districts: [
      DistrictDef(
        id: 'bakery_street',
        nameKey: 'townStreetName',
        minX: -24,
        maxX: 24,
        minZ: -16,
        maxZ: 16,
        roadHalfWidth: 3,
        sidewalkOuter: 5.5,
        busX: -23,
        busZ: -4,
        spawnX: -6,
        spawnZ: -4.4,
        lots: [
          LotDef(
            id: 'n1',
            kind: LotKind.realty,
            x: -18,
            z: -10.5,
            w: _lotW,
            d: _lotD,
            doorX: -18,
            doorZ: -5.5,
            yaw: 0,
            price: 0,
            requiresLevel: 1,
            nameKey: 'cityRealtyName',
          ),
          LotDef(
            id: 'n2',
            kind: LotKind.home,
            x: -6,
            z: -10.5,
            w: _lotW,
            d: _lotD,
            doorX: -6,
            doorZ: -5.5,
            yaw: 0,
            price: 0,
            requiresLevel: 1,
            nameKey: 'townHomeShop',
          ),
          LotDef(
            id: 'n3',
            kind: LotKind.restaurant,
            x: 6,
            z: -10.5,
            w: _lotW,
            d: _lotD,
            doorX: 6,
            doorZ: -5.5,
            yaw: 0,
            price: 0,
            requiresLevel: 1,
            nameKey: 'cityRestaurantName',
          ),
          LotDef(
            id: 'n4',
            kind: LotKind.salon,
            x: 18,
            z: -10.5,
            w: _lotW,
            d: _lotD,
            doorX: 18,
            doorZ: -5.5,
            yaw: 0,
            price: 0,
            requiresLevel: 1,
            nameKey: 'citySalonName',
          ),
          LotDef(
            id: 's1',
            kind: LotKind.branch,
            x: -18,
            z: 10.5,
            w: _lotW,
            d: _lotD,
            doorX: -18,
            doorZ: 5.5,
            yaw: _pi,
            price: 8000,
            requiresLevel: 5,
            baseIncome: 150,
            nameKey: 'townLotForSale',
          ),
          LotDef(
            id: 's2',
            kind: LotKind.park,
            x: -6,
            z: 10.5,
            w: _lotW,
            d: _lotD,
            doorX: -6,
            doorZ: 5.5,
            yaw: _pi,
            price: 0,
            requiresLevel: 1,
            nameKey: 'cityParkName',
          ),
          LotDef(
            id: 's3',
            kind: LotKind.branch,
            x: 6,
            z: 10.5,
            w: _lotW,
            d: _lotD,
            doorX: 6,
            doorZ: 5.5,
            yaw: _pi,
            price: 20000,
            requiresLevel: 10,
            baseIncome: 250,
            nameKey: 'townLotForSale',
          ),
          LotDef(
            id: 's4',
            kind: LotKind.branch,
            x: 18,
            z: 10.5,
            w: _lotW,
            d: _lotD,
            doorX: 18,
            doorZ: 5.5,
            yaw: _pi,
            price: 45000,
            requiresLevel: 15,
            baseIncome: 400,
            nameKey: 'townLotForSale',
          ),
        ],
      ),
      // Quận 2: biên tạm, lô để trống (giai đoạn 5).
      DistrictDef(
        id: 'sea_market',
        nameKey: 'citySeaMarketName',
        minX: -24,
        maxX: 24,
        minZ: -16,
        maxZ: 16,
        roadHalfWidth: 3,
        sidewalkOuter: 5.5,
        busX: -23,
        busZ: -4,
        spawnX: -22,
        spawnZ: -4.4,
        lots: [],
      ),
    ],
  );

  /// Quận theo id; ném [StateError] nếu không có.
  DistrictDef district(String id) => districts.firstWhere(
    (d) => d.id == id,
    orElse: () => throw StateError('Không có quận "$id"'),
  );
}
