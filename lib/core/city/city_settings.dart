/// Cài đặt người chơi trong thành phố: ngôn ngữ, âm thanh. Lưu trong save v3 (`settings`); xoá dữ liệu vẫn giữ.
library;

import 'package:flutter/foundation.dart';

import '../models/ids.dart';

export '../models/ids.dart' show LanguagePref;

class CitySettings extends ChangeNotifier {
  CitySettings({LanguagePref language = LanguagePref.system, bool sound = true})
    : _language = language,
      _sound = sound;

  LanguagePref _language;
  bool _sound;

  LanguagePref get language => _language;
  bool get sound => _sound;

  /// Không đổi thì không notify.
  void setLanguage(LanguagePref v) {
    if (v == _language) return;
    _language = v;
    notifyListeners();
  }

  /// Không đổi thì không notify.
  void setSound(bool v) {
    if (v == _sound) return;
    _sound = v;
    notifyListeners();
  }
}
