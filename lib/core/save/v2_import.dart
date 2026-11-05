/// Nhập save v2 sang save v3 (docs/v3/city-gd2-spec.md §0, §2.3 bước 4). Hàm thuần: không đọc / ghi bộ nhớ.
library;

import '../models/ids.dart';
import 'city_save.dart';

/// Chỉ mang ngôn ngữ, âm thanh, `introSeen` (thiếu → false), `removeAds`, `iap` (các chuỗi khác rỗng, giữ cả id lạ);
/// phần còn lại là mặc định của người mới tại [now] (1500 xu, không quy đổi xu / XP / tiến trình 50 màn),
/// `migratedFrom: 2`. Trường sai kiểu → mặc định, không ném. Bản v1 còn nằm trong khoá v2 đọc cùng cách (các trường
/// trên trùng tên; v1 không có `introSeen` nên là false).
CitySave importV2(Map<String, dynamic> v2, {required DateTime now}) {
  final sound = v2['sound'];
  final introSeen = v2['introSeen'];
  final removeAds = v2['removeAds'];
  final iap = v2['iap'];
  return CitySave.fresh(now).copyWith(
    migratedFrom: 2,
    language:
        enumByName(LanguagePref.values, v2['lang']) ?? LanguagePref.system,
    sound: sound is bool ? sound : true,
    introSeen: introSeen is bool && introSeen,
    removeAds: removeAds is bool && removeAds,
    iap: {
      if (iap is List)
        for (final p in iap)
          if (p is String && p.isNotEmpty) p,
    },
  );
}
