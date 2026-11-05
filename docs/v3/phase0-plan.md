# Sugarleaf Bakery V3 — chuyển từ 2D sang 3D: kế hoạch

Ngày 02/11/2026. Nhánh `v3` (worktree `D:\flutter_app\cupcake app v3`), tách từ `v2` commit `6ec56d8`. Thư mục v2
(`D:\flutter_app\cupcake app`, nhánh `v2`) giữ nguyên.

## Quyết định của chủ dự án
- **Engine: Flutter + Thermion (Filament).** Giữ logic, UI, l10n, test của v2; chỉ cảnh tiệm thành 3D.
  Nếu giai đoạn (a) không đạt 30 FPS trên máy Android tầm trung → cân nhắc Godot 4 (chỉ mất phần cảnh 3D).
- **Nhân vật: ảnh 2D Gemini đặt trong cảnh 3D** (billboard luôn quay về camera), dùng lại 88 ảnh có sẵn.
- **Flutter riêng cho v3:** 3.47.9 ở `D:\flutter_sdk\flutter_3.47\flutter\bin\flutter` (Thermion cần native assets /
  `hooks`, Dart ≥ 3.10). v2 vẫn dùng Flutter 3.32.

## Giữ nguyên từ v2
- `lib/core/**`: `LevelSession` (tick 30 Hz, `SpawnCurve` khách dày dần), tủ kính, bếp nhanh, combo, mục tiêu/3 sao,
  `levels.json` 50 màn / 5 chương, `unlocks.json` (mở rộng tiệm, thiết bị), nhân viên, thu nhập offline, booster,
  lưu game + migration, 18 món, chấm điểm.
- Quảng cáo / IAP giả lập (`ad_service`, `iap_service`, `monetization_config`) — giữ chỗ như v2.
- UI Flutter: bản đồ chương, HUD, kết quả, cửa hàng, nâng cấp, nhân viên, cài đặt, bộ SL*, l10n en/vi.
- 6 trạm đầy đủ (Flame, 2D) cho đơn đặc biệt — mở dạng lớp phủ trên cảnh 3D.

## Làm lại cho 3D
- Cảnh tiệm (`lib/game/level/shop_view.dart`, `kitchen_view.dart`) → không gian 3D: bếp, tủ kính, quầy thu ngân,
  khu khách ngồi.
- `ShopLayout` (mở rộng theo level) → bật/tắt vật thể 3D thay cho lớp ảnh.
- Khách / nhân viên đi theo đường trong 3D (cửa → hàng chờ → quầy → bàn).
- Camera 360°: một ngón xoay, chụm phóng to/thu nhỏ, chạm đúp về góc mặc định; giới hạn góc nghiêng và khoảng cách
  để không xuyên sàn/tường.
- Chạm vật thể 3D (raycast / chiếu toạ độ) thay cho chạm ảnh.

## Giai đoạn
| GĐ | Nội dung | Kết thúc |
|---|---|---|
| a | Nâng Flutter, thêm Thermion; tiệm low-poly dựng bằng code (khối cơ bản, bảng màu ấm); ánh sáng mềm; camera 360° có giới hạn; vài khách billboard đứng mẫu; đồng hồ FPS | **Bản chạy thử (APK + web) gửi chủ dự án, chờ duyệt** |
| b | Nối `LevelSession` vào cảnh 3D: khách đi, hàng chờ, bán từ tủ, bếp nhanh, nhân viên, mở rộng tiệm | Chơi được chương 1 |
| c | HUD + màn v2, bóng thoại trên khách, hạt lấp lánh, xu bay | `/quality-gate` |
| d | Gộp mesh, texture atlas, tắt bóng trên máy yếu; 25 khách + 10 nhân viên ≥ 30 FPS | Đo trên máy thật |
