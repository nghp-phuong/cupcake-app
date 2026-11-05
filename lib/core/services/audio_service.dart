import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../city/city_settings.dart';

abstract class AudioService {
  void tap();
  void success();
  void fail();
}

/// Alpha chưa có file âm thanh: phát tiếng click hệ thống khi bật âm thanh (web có thể im lặng).
class FakeAudioService implements AudioService {
  FakeAudioService(this.settings);

  /// Bật / tắt âm thanh ([CitySettings.sound]).
  final CitySettings settings;

  void _click() {
    if (!settings.sound) return;
    try {
      SystemSound.play(SystemSoundType.click).catchError((Object e) {
        debugPrint('FakeAudioService: $e');
      });
    } catch (e) {
      // Chưa có binding (unit test thuần) → bỏ qua.
      debugPrint('FakeAudioService: $e');
    }
  }

  @override
  void tap() => _click();

  @override
  void success() => _click();

  @override
  void fail() => _click();
}
