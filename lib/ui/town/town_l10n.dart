import '../../core/branch/staff.dart';
import '../../core/city/mai_look.dart';
import '../../l10n/gen/app_localizations.dart';

/// Ánh xạ khoá `nameKey` / id món (core) → chuỗi đã dịch. Switch tường minh, không reflection; khoá lạ → trả
/// chính khoá (không ném lỗi giữa lúc chơi).
String cityText(AppLocalizations l, String key) {
  switch (key) {
    case 'townStreetName':
      return l.townStreetName;
    case 'citySeaMarketName':
      return l.citySeaMarketName;
    case 'townHomeShop':
      return l.townHomeShop;
    case 'townLotForSale':
      return l.townLotForSale;
    case 'cityRealtyName':
      return l.cityRealtyName;
    case 'cityParkName':
      return l.cityParkName;
    case 'cityRestaurantName':
      return l.cityRestaurantName;
    case 'citySalonName':
      return l.citySalonName;
    case 'townComingSoon':
      return l.townComingSoon;
    case 'townOpening':
      return l.townOpening;
    case 'dishFishSoup':
      return l.dishFishSoup;
    case 'dishOmeletteRice':
      return l.dishOmeletteRice;
    case 'dishVeggieCurry':
      return l.dishVeggieCurry;
    case 'dishSeafoodNoodles':
      return l.dishSeafoodNoodles;
    case 'hairPonytail':
      return l.hairPonytail;
    case 'hairBob':
      return l.hairBob;
    case 'hairBun':
      return l.hairBun;
    case 'hairTwinTails':
      return l.hairTwinTails;
    case 'hairColorChestnut':
      return l.hairColorChestnut;
    case 'hairColorCaramel':
      return l.hairColorCaramel;
    case 'hairColorBlack':
      return l.hairColorBlack;
    case 'hairColorStrawberry':
      return l.hairColorStrawberry;
  }
  return key;
}

/// Tên kiểu tóc.
String hairText(AppLocalizations l, MaiHair h) => switch (h) {
  MaiHair.ponytail => l.hairPonytail,
  MaiHair.bob => l.hairBob,
  MaiHair.bun => l.hairBun,
  MaiHair.twinTails => l.hairTwinTails,
};

/// Tên màu tóc.
String hairColorText(AppLocalizations l, MaiHairColor c) => switch (c) {
  MaiHairColor.chestnut => l.hairColorChestnut,
  MaiHairColor.caramel => l.hairColorCaramel,
  MaiHairColor.black => l.hairColorBlack,
  MaiHairColor.strawberry => l.hairColorStrawberry,
};

/// Tên nhân viên chi nhánh theo id; id lạ → trả chính id.
String staffName(AppLocalizations l, String staffId) => switch (staffId) {
  'ami' => l.charAmi,
  'hanh' => l.charHanh,
  'biscuit' => l.charBiscuit,
  'nutmeg' => l.charNutmeg,
  'cocoa' => l.charCocoa,
  'maple' => l.charMaple,
  _ => staffId,
};

/// Tên vai nhân viên.
String staffRoleText(AppLocalizations l, StaffRole r) => switch (r) {
  StaffRole.server => l.staffRoleServer,
  StaffRole.baker => l.staffRoleBaker,
  StaffRole.manager => l.staffRoleManager,
};
