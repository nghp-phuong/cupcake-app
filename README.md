# Sugarleaf Bakery (alpha)

Game mô phỏng tiệm bánh ngọt 2D, cozy, chỉ chơi ngang màn hình (khung tham chiếu 1280×720).
Flutter 3.32 + Flame. Đích: Android và web. Quy tắc dự án: xem `CLAUDE.md`; đặc tả alpha: `docs/alpha-spec.md`.

## Lệnh
```
flutter pub get                    # cũng sinh lib/l10n/gen/ từ lib/l10n/*.arb
flutter analyze
flutter test
flutter build web --release        # xem trước: build/web (cần máy chủ tĩnh, không mở bằng file://)
flutter build apk --debug
```

## Cấu trúc
- `lib/main.dart`, `lib/app.dart`: khởi động, khoá hướng ngang, `SugarleafApp` (AppScope → MaterialApp → RefFrame).
- `lib/core/`: mô hình dữ liệu, `Catalog`, `Economy`, `Scoring`, `OrderGenerator`, `GameState` (lưu tự động
  bất đồng bộ, debounce 300ms, khoá `sugarleaf_save_v1`), `DayController`, dịch vụ quảng cáo/IAP/âm thanh giả lập,
  `l10n_lookup.dart`, hình vẽ bằng code ở `lib/core/art/`.
- `lib/game/`: Flame, 6 trạm làm bánh (chỉ đo số thô, chấm điểm ở `core/scoring.dart`).
- `lib/ui/`: các màn hình Flutter.
- `lib/l10n/*.arb`: chuỗi en (nguồn) + vi. `lib/l10n/gen/` là file sinh, không sửa tay.

## Ràng buộc
- Mọi màn bố cục theo toạ độ cố định 1280×720 (`RefFrame` co giãn + letterbox màu kem).
- Không chặn luồng UI bằng I/O; lưu game bất đồng bộ.
- Quảng cáo/IAP alpha là giả lập: không SDK, không trừ tiền thật.
- Test dựng app phải truyền `useGoogleFonts: false` (không gọi mạng).
