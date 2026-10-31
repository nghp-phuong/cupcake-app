# Sugarleaf Bakery V2 — Kế hoạch kiểm thử (Test Plan)

Nhánh: `v2` · Ngày lập: 30/10/2026 · Người lập: QA · Bản build: `0.1.0-alpha` (nhãn trong Cài đặt) / `1.0.0+1` (pubspec)

Tài liệu đi kèm: `docs/qa/test-cases.md` (bộ test case), `docs/qa/manual-checklist.md` (checklist trên điện thoại thật).
Nguồn đối chiếu: `CLAUDE.md`, `docs/v2/phase0..8-spec.md`, `docs/v2/phase7-balance.md`, `assets/config/levels.json`,
`unlocks.json`, `monetization.json`, mã nguồn `lib/core`, `lib/game`, `lib/ui`, test có sẵn trong `test/`, `tool/simulate.dart`.

---

## 1. Phạm vi kiểm thử

| # | Nhóm | Nội dung chính | Tiền tố ID |
|---|---|---|---|
| 1 | Smoke | Cài, mở app, intro dài/ngắn, bản đồ, vào L1, chơi hết màn, màn kết quả, lưu và mở lại | `SMK` |
| 2 | Gameplay trong màn | Tủ kính, khách vãng lai, hàng chờ, kiên nhẫn, combo, bếp nhanh 6 trạm, lò, khách đặc biệt (Hòa, Linh, Kenji, VIP/bà Rosa), mục tiêu + 3 sao, +30 giây, tạm dừng, hướng dẫn L1–L3, vật phẩm hỗ trợ, nhân viên trong màn | `GP` |
| 3 | Tiến trình & mở khoá | Mở level tuần tự, mở chương bằng tổng sao + qua màn cuối chương, mốc mở khoá trong `unlocks.json`, thiết bị nhiều cấp, nhân viên, Bí quyết của bà, thông báo "Mở khoá mới!", chấm đỏ | `PRG` |
| 4 | Kinh tế & cân bằng | Công thức xu/tip/combo, giá mở khoá, kim cương kiếm trong game, nhiệm vụ ngày, quà đăng nhập, thu nhập vắng nhà, mô phỏng 50 màn (`tool/simulate.dart`) | `ECO` |
| 5 | Lưu dữ liệu | Autosave, lưu khi vào nền, JSON hỏng, trường hỏng, bản lưu mới hơn, quy đổi v1 → v2, reset, tắt app đột ngột | `SAV` |
| 6 | Quảng cáo & IAP | Rewarded (+30 giây, ×2 xu, ×2 vắng nhà, vật phẩm miễn phí, +1 kim cương), giới hạn 12/ngày, interstitial, IAP giả lập (7 gói), khôi phục giao dịch, thẻ mùa | `ADS` |
| 7 | Giao diện & đa ngôn ngữ | en/vi, chuyển ngôn ngữ, chữ tràn, định dạng số, màn ngang 1280×720 và các tỉ lệ khác, letterbox, tai thỏ, giảm chuyển động, nút Back Android | `UI` |
| 8 | Hiệu năng | 20–25 khách + 10 nhân viên giả lập, FPS, thời gian khởi động, bộ nhớ, rò rỉ sau 10 màn liên tiếp, máy yếu | `PRF` |
| 9 | Trường hợp biên | Bấm liên tục / nhiều ngón, bấm khi chuyển cảnh, xoay máy, cuộc gọi đến, chuyển app, mất mạng, đổi giờ máy, xu/kim cương = 0 và rất lớn | `EDG` |

## 2. Ngoài phạm vi

- SDK quảng cáo thật (AdMob…) và Google Play Billing thật: **chưa tích hợp** (`FakeAdService`, `FakeIapService`; `pubspec.yaml`
  không có SDK). Các mục "quảng cáo thật / mua hàng thật" trong `manual-checklist.md` chỉ chạy khi có bản build nối SDK.
- iOS / App Store (dự án chỉ nhắm Android + web xem trước).
- Âm thanh thật (chưa có file âm thanh; `FakeAudioService` chỉ phát tiếng click hệ thống) — chỉ kiểm bật/tắt và không lỗi.
- Rung (haptic): code chưa có (`grep HapticFeedback|vibrat` trong `lib/` = 0 kết quả) — ghi nhận, không kiểm.
- Nội dung Google Play (`store/**`), chính sách quyền riêng tư, kiểm định Families (đối tượng 13+, đã ghi ở CLAUDE.md).
- Chế độ "ngày" V1 (đã gỡ ở GĐ2), Mochi ngày mưa theo V1 (chỉ kiểm cảnh `mochi1` ở L23).
- Kiểm thử bảo mật / chống gian lận phía máy chủ (game không có máy chủ).
- Mục "Sắp có": `kitchen_2`, `staff_training`, `rare_decor` — chỉ kiểm hiển thị "Sắp có" và không mua được.

## 3. Môi trường

| Loại | Cấu hình | Dùng cho |
|---|---|---|
| Máy dev Windows | Flutter 3.32.8 (`C:\Users\Admin\Documents\flutter_windows_3.32.8-stable\flutter\bin\flutter`) | `flutter analyze`, `flutter test`, `tool/simulate.dart` |
| Web xem trước | `flutter build web --release` → `build/web`, Chrome desktop, cửa sổ 1280×720 và 1920×1080 | Smoke nhanh, UI, ngôn ngữ |
| Android máy khá | Android 13–15, màn 20:9 (vd. 3200×1440 hoặc 2400×1080), có tai thỏ/đục lỗ | Thủ công toàn bộ, hiệu năng |
| Android máy chuẩn | Android 11–12, màn 16:9 1280×720 hoặc 1920×1080 | UI khung tham chiếu, hiệu năng trung bình |
| Android máy yếu | RAM 2–3 GB, Android 9–10, GPU yếu (vd. Helio P22 / Snapdragon 4xx) | FPS, khởi động, bộ nhớ |
| Máy tính bảng | 4:3 hoặc 16:10 (vd. 2000×1200) | Letterbox, bố cục |
| Tài khoản | Google Play license tester + track kiểm thử nội bộ (khi có SDK thật) | Mua hàng thật / quảng cáo thử |

**Cỡ màn hình — chuyển từ mô tả PO sang hướng ngang:** game khoá ngang (`main.dart`: `landscapeLeft/Right`;
`AndroidManifest.xml`: `sensorLandscape`) và vẽ trong khung 1280×720 co giãn giữ tỉ lệ (`lib/core/ref_frame.dart`).
PO ghi cỡ dọc 720×1280 và 1440×3200 → QA kiểm ở **1280×720 (16:9, khớp khung, không viền)** và **3200×1440 (20:9, viền kem hai
bên trái/phải)**; thêm 2400×1080, 1920×1080, 2000×1200 (16:10) và 2048×1536 (4:3, viền trên/dưới). Xem mục 9 "Cần BA/PO xác nhận".

## 4. Chiến lược

### 4.1 Tự động (chạy mỗi lần thay đổi: `flutter analyze` + `flutter test`)

| Tầng | Cái gì | Ở đâu | Vì sao tự động |
|---|---|---|---|
| Unit (Dart thuần) | `LevelSession` (kiên nhẫn, hàng, combo, xu, lò, đặc biệt, +30 giây, kết thúc), `GameState` (tiến trình, mở khoá, mua, nhân viên, vắng nhà, vật phẩm, interstitial, IAP, mùa), loader cấu hình chặt/khoan dung, lưu/đọc/quy đổi | `test/core/*` có sẵn (level_session, level_progress, unlock, staff, monetization, save, save_migration, booster_*, tutorial…) + `test/core/qa_*` (đang viết) | Logic tất định, có seed, đổi số là phát hiện ngay; chạy vài giây |
| Widget | Bản đồ, thẻ Sẵn sàng, HUD, tạm dừng, màn kết quả, cửa hàng, Nâng cấp (3 tab), Cài đặt, intro, hộp vắng nhà, chống bấm đúp, tiếng Việt không tràn | `test/ui/*` + `test/ui/qa_*` | Luồng điều hướng và trạng thái nút kiểm được bằng `WidgetTester` với `MemorySaveRepository`, `FakeAdService` |
| Game (Flame) | Vẽ tiệm theo `ShopSetup`, nhân viên, vật phẩm, lớp hướng dẫn, perf step+paint | `test/game/*` + `test/game/qa_*` | Kiểm toạ độ mục tiêu, ngân sách khung (25 khách: < 8 ms; 25 khách + 10 nhân viên: < 1 ms) |
| Integration | Mở app → intro → L1 → chơi bằng bot → kết quả → bản đồ → khởi động lại giữ tiến trình | `integration_test/` (đang viết) | Chạy trên máy thật / emulator qua `flutter test integration_test`, bắt lỗi ghép tầng |
| Mô phỏng cân bằng | 200 người chơi giả × 3 kỹ năng × 50 màn | `tool/simulate.dart`, `test/core/simulate_test.dart`, `level_balance_test`, `progression_sim_test`, `booster_balance_test` | Số liệu thắng lần đầu / mốc mua / xu dư không thể đo tay |

### 4.2 Thủ công (máy thật) và lý do

| Mảng | Vì sao không tự động được |
|---|---|
| Cảm giác chơi, độ khó cảm nhận, nhịp 2–4 phút | Chủ quan; bot không thay được người (chạm ngón tay, phản xạ) |
| Thao tác cảm ứng thật: xoay trộn bột, quẹt kem, nhiều ngón, chạm nhanh | Cử chỉ giả lập trong test không tái hiện độ trễ cảm ứng, tay che màn |
| FPS, giật, nhiệt, pin, bộ nhớ trên máy yếu | Phụ thuộc GPU/thiết bị; cần Flutter DevTools / `adb shell dumpsys gfxinfo` |
| Vòng đời Android: cuộc gọi đến, chuyển app, khoá màn, bị hệ thống giết app, mất mạng | Cần hệ điều hành thật |
| Tai thỏ, viền cong, thanh điều hướng cử chỉ, tỉ lệ 20:9 / 4:3 | Phụ thuộc phần cứng |
| Quảng cáo thật, mua thật (license tester), hoàn tiền, đơn chờ | Cần SDK thật + tài khoản Play (chưa có) |
| Chất lượng ảnh vẽ tay, chữ tiếng Việt có dấu, cắt chữ | Đánh giá bằng mắt |

### 4.3 Thứ tự chạy cho một bản build ứng viên
1. `flutter analyze` (0 lỗi) → `flutter test` (100% qua) → `flutter test tool/simulate.dart` (0 lệch mục tiêu).
2. Build `flutter build apk --debug` (và release khi có ký) → smoke `SMK-*` trên 2 máy.
3. Test case P1 thủ công → P2 → `manual-checklist.md` → P3 khi còn thời gian.

## 5. Tiêu chí vào / ra

**Vào (bắt đầu một vòng test):**
- Build cài được trên máy Android thật; `flutter analyze` sạch; `flutter test` qua toàn bộ.
- Cấu hình `levels.json` (50 màn, 5 chương), `unlocks.json`, `monetization.json` nạp được (không rơi về cấu hình rỗng).
- Có ghi chú thay đổi của bản build.

**Ra (đạt để phát hành alpha/closed test):**
- 100% test case P1 đạt; ≥ 95% P2 đạt; không lỗi mức Nghiêm trọng/Chặn còn mở (crash, mất dữ liệu lưu, kẹt tiến trình,
  trừ tiền/kim cương sai, quảng cáo xen kẽ lúc đang chơi).
- Mô phỏng 50 màn: thắng lần đầu chương 1–5 trong dung sai mục tiêu (≈ 82 / 70 / 63 / 62 / 61% với `average`, ±8 điểm), không
  màn nào < 45%, không màn nào kẹt > 5%, mốc mua trễ ≤ 3 màn (dụng cụ ≤ 4).
- Hiệu năng: ≥ 55 FPS trung bình trong màn có 20+ khách trên máy chuẩn; ≥ 30 FPS trên máy yếu; khởi động nguội < 4 s (máy chuẩn);
  bộ nhớ không tăng quá 15% sau 10 màn liên tiếp.
- Mọi chuỗi hiển thị có đủ en + vi, không tràn ở 1280×720.

## 6. Rủi ro

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Quảng cáo/IAP mới giả lập: khi nối SDK thật, luồng lỗi (không có quảng cáo, mạng chậm, huỷ thanh toán, đơn chờ) chưa từng được kiểm | Cao | Test lại toàn bộ nhóm ADS khi có SDK; thêm case "không tải được quảng cáo" |
| Hoàn vật phẩm khi Thoát/Chơi lại trước lần bán đầu: vật phẩm nhận bằng quảng cáo vẫn được +1 vào kho (`game_state.dart:2079–2089`, `level_screen.dart:395–400`) → có thể "nuôi" kho bằng quảng cáo (tối đa 12/ngày) | Trung bình | Case `EDG-12`, cần PO quyết |
| Đồng hồ máy quyết định giới hạn quảng cáo/ngày, nhiệm vụ, quà đăng nhập, thẻ mùa, vắng nhà → chỉnh giờ máy để gian lận | Trung bình | Case `EDG-13..15`; vắng nhà đã chặn đồng hồ lùi |
| Thẻ mùa `s1_seaside_autumn` hết hạn 15/12/2026 theo giờ máy; sau đó không còn mùa (`previousSeasons` rỗng) | Trung bình | Case `ADS-18`, `ADS-19` |
| Mô phỏng 50 màn dùng bot; người mới (`newbie`) chương 5 chỉ ~55% thắng lần đầu, đủ sao mở chương 2–5 chỉ 50–60% | Trung bình | Thử chơi thật nhóm người mới (checklist), `phase7-balance.md` §8.5 |
| Khung 1280×720 tắt phóng chữ hệ thống (`ref_frame.dart:24` `TextScaler.noScaling`) → người cần chữ to không phóng được | Thấp | Ghi nhận khả năng tiếp cận |
| Máy yếu: nhiều ảnh webp lớn (nhân vật, bản đồ, intro) → giật lúc nạp, tràn bộ nhớ | Trung bình | `PRF-*`, checklist máy yếu |
| Xu không có trần trên (`game_state.dart:434`), web dùng số JS (an toàn tới 2^53) | Thấp | `EDG-17`, `EDG-18` |
| `CLAUDE.md` của dự án còn mô tả V1 (một ngày, rewarded 8/ngày, interstitial từ ngày 4) — dễ đối chiếu sai | Thấp | Mục 8 dưới, đề nghị cập nhật |

## 7. Lịch và nguồn lực (đề xuất)
| Việc | Thời lượng |
|---|---|
| Chạy tự động + mô phỏng | 0.5 ngày |
| Smoke + P1 thủ công (2 máy) | 1.5 ngày |
| P2/P3 + checklist máy thật (3–4 máy) | 2 ngày |
| Hồi quy sau sửa lỗi | 1 ngày |

## 8. Điểm code khác mô tả PO

| # | Mô tả PO | Code / cấu hình thực tế | Vị trí |
|---|---|---|---|
| 1 | "Mở rộng bếp L22" | `kitchen_2` chỉ có hiệu ứng `prepSlots` thuộc nhóm `reserved` (chưa áp) → hiện **"Sắp có"**, không mua được, không có tác dụng | `assets/config/unlocks.json:35`; `lib/core/unlock/unlock_config.dart:45–52`, `:155–162` |
| 2 | "Quản lý + offline L32" | Đúng L32, nhưng còn thêm nhiều mốc PO không nêu: `case_stand` L5, `oven_2` L12, `staff_baker_2` L28, `garden` L30, `floor_2` L35, `recipe_secrets` L41, `staff_training` L41 (Sắp có), `rare_decor` L45 (Sắp có) + 7 thiết bị nhiều cấp | `assets/config/unlocks.json:4–90`, `:91–145` |
| 3 | "Phục vụ L25" | Thuê được từ L25 **chỉ khi đã mua `cafe_tables`** (L18) | `assets/config/unlocks.json:163`; `lib/core/game_state.dart:1320–1328` |
| 4 | "Mở chương bằng tổng sao" | Cần **cả hai**: đã qua màn cuối chương trước **và** tổng sao ≥ `starsToUnlock` (0 / 16 / 28 / 40 / 53) | `lib/core/game_state.dart:1226–1235`; `assets/config/levels.json:6–15` |
| 5 | "Khách đặc biệt (Hòa, Linh, Kenji, VIP)" | Có thêm bà Rosa (VIP `look: vip_00`) ở L33, L50; VIP không ghi `look` chỉ ra `vip_01`/`vip_02`. Một số lượt ghé có điều kiện `afterServed`/`bySec` (L10) → **có thể bị bỏ** nếu phục vụ chưa đủ khách | `assets/config/levels.json:114–119`, `:382`, `:579`; `lib/core/level/level_session.dart:485–500`, `:593` |
| 6 | "Mục tiêu + 3 sao" | 3 loại mục tiêu: `coins`, `customers`, `specialOrders` (L10). `specialOrders` chỉ đếm đơn đạt **≥ 3★**; thắng ⇔ đạt mốc 1★; đạt 3★ sớm **không** kết thúc màn | `lib/core/level/level_session.dart:215–216`, `:372–376`, `:1184–1187` |
| 7 | "Rung" | **Không có** rung/haptic trong code | `lib/` (không có `HapticFeedback`) |
| 8 | "Âm thanh" | Chưa có file âm thanh; chỉ tiếng click hệ thống khi bật âm | `lib/core/services/audio_service.dart:12–37` |
| 9 | "Rewarded (+30 giây, ×2 xu, ×2 offline)" | Có thêm: 1 vật phẩm miễn phí ở thẻ Sẵn sàng, +1 kim cương ở cửa hàng; giới hạn chung **12/ngày lịch** (CLAUDE.md ghi 8) | `lib/core/economy.dart:11`, `:27`; `docs/v2/phase6-spec.md:21–29` |
| 10 | "+30 giây" | Chỉ hỏi khi **hết giờ mà chưa đạt 1★**, 1 lần/lượt, còn lượt rewarded | `lib/ui/level/level_screen.dart:429`; `lib/core/level/level_session.dart:1171–1181` |
| 11 | "Interstitial" | Chỉ khi rời màn kết quả, 1 lần mỗi **3 lượt chơi xong**, chỉ khi đã qua **L5**; không hiện nếu vừa xem rewarded ở màn đó, vừa mở chương, đã mua Bỏ quảng cáo (CLAUDE.md còn ghi "từ ngày 4, 1 lần/2 ngày") | `lib/core/economy.dart:15–16`; `lib/core/game_state.dart:2002–2017`; `lib/ui/level/level_result_screen.dart:95–116` |
| 12 | "Booster" | Chỉ từ **L4** (L1–L3 là hướng dẫn); quà 1 `patience` khi tới L4; mỗi loại tối đa 1/lượt; trả kho → kim cương; hoàn vào kho nếu Thoát/Chơi lại trước lần bán đầu (kể cả trả bằng quảng cáo) | `lib/core/monetization/booster.dart:35–51`; `lib/core/game_state.dart:2066–2089` |
| 13 | "IAP test" | Giả lập hoàn toàn, nhãn "Chế độ thử"; 7 gói ($0.99–$9.99); không SDK, không cần mạng | `lib/core/services/iap_service.dart:28–70`; `assets/config/monetization.json:263–383` |
| 14 | "Intro dài lần đầu có Bỏ qua, các lần sau ngắn" | Đúng; dài ~22 s (giảm chuyển động ~10 s), sau intro dài vào **thẳng L1** (không qua bản đồ); intro ngắn 4 s, chạm để vào bản đồ. Người chơi quy đổi từ V1 không thấy intro dài | `lib/ui/intro/intro_screen.dart:27–30`, `:170–188`; `lib/ui/intro/short_intro_screen.dart:17`; `lib/core/game_state.dart:858–860` |
| 15 | "10 nhân viên" (hiệu năng) | Game chỉ có **5** nhân viên; 10 chỉ là giả lập trong test perf | `assets/config/unlocks.json:146–187`; `test/game/level_staff_test.dart:362` |
| 16 | "UI vẽ tay màu nước" | Ảnh vẽ tay (Gemini) cho nhân vật/bánh/cảnh; khung, nút, icon vẽ bằng code (bộ Sugarleaf `lib/ui/sugarleaf/`), thiếu ảnh → vẽ code dự phòng (trừ nhân vật) | `pubspec.yaml` mục `assets`; `lib/ui/sugarleaf/paint/` |
| 17 | Chỉ chạy ngang | Hướng đã khoá, nhưng nếu khung bị dọc (web, chia màn hình) vẫn vẽ khung ngang kèm lời nhắc xoay máy | `lib/core/ref_frame.dart:42–56` |
| 18 | Bí quyết của bà | `phase8-spec.md` ghi +8/16/25%, cấu hình thật **+5/10/15%** (chủ dự án chốt giữ ở `phase7-balance.md` §8.6) — tài liệu đặc tả lệch cấu hình | `docs/v2/phase8-spec.md:92`; `assets/config/unlocks.json:79–81` |
| 19 | Kim cương kiếm trong game | +1 khi lần đầu 3★ một màn, +12 khi lần đầu qua màn cuối chương (đặc tả GĐ6 gợi ý +2/+15) | `lib/core/economy.dart:20–21` |
| 20 | Phiên bản | Cài đặt hiện `0.1.0-alpha`, pubspec `1.0.0+1` | `lib/ui/common/format.dart:5`; `pubspec.yaml:19` |
| 21 | Nhãn chương / màn | L1–L10 theo đặc tả GĐ1 nhưng mốc sao đã cân lại (L1: 6/8/10 khách, đặc tả 5/7/9) | `assets/config/levels.json:19`; `docs/v2/phase1-spec.md:116` |

## 9. Cần BA/PO xác nhận

1. **Cỡ màn hình:** PO ghi 720×1280 và 1440×3200 (dọc). Game chỉ ngang → QA dùng 1280×720 và 3200×1440. Có cần thêm tỉ lệ
   nào (gập, 4:3 tablet)? Viền kem hai bên ở 20:9 có chấp nhận được hay muốn trải nền tràn viền?
2. **Mở rộng bếp L22** đang "Sắp có" (không mua được). Giữ vậy cho bản phát hành, hay phải làm `prepSlots` trước khi ra mắt?
3. **Rung**: có yêu cầu rung (bán được, khách bỏ đi, bánh cháy) không? Hiện chưa có.
4. **Âm thanh**: phát hành alpha khi chỉ có tiếng click hệ thống có được không?
5. **Hoàn vật phẩm nhận bằng quảng cáo** khi Thoát/Chơi lại trước lần bán đầu → +1 vào kho: chủ ý hay lỗ hổng?
6. **Mở chương**: xác nhận luật hai điều kiện (qua màn cuối chương trước + đủ sao), mốc 16/28/40/53.
7. **Giới hạn rewarded 12/ngày** (CLAUDE.md còn ghi 8) và **interstitial mỗi 3 lượt từ sau L5** (CLAUDE.md: từ ngày 4, 1 lần/2 ngày) —
   bản nào đúng? Đề nghị cập nhật CLAUDE.md theo V2.
8. **Bí quyết của bà** +5/10/15% (cấu hình) hay +8/16/25% (đặc tả GĐ8)?
9. **Hiệu năng**: chuẩn chấp nhận FPS / thời gian khởi động / RAM cho máy yếu (QA đề xuất ≥ 30 FPS, < 6 s, < 400 MB).
10. **Thẻ mùa** hết hạn 15/12/2026: có mùa kế tiếp không? Không có thì nút Thẻ mùa hiển thị gì sau ngày đó?
11. **Chỉnh giờ máy** để reset lượt quảng cáo/quà/nhiệm vụ: chấp nhận (game offline) hay cần chặn?
12. **Phóng chữ hệ thống** bị tắt trong khung 1280×720 — chấp nhận về khả năng tiếp cận?
13. **Màn đặc biệt L10** có lượt ghé bị bỏ nếu chưa đủ khách (`afterServed`/`bySec`) — người chơi chậm có thể không đủ 2 đơn để
    thắng. Có cần thông báo rõ hơn hay nới điều kiện?
14. **Số phiên bản** hiển thị: `0.1.0-alpha` hay theo pubspec?
15. **Đường quay lại sau intro dài**: vào thẳng L1 (không thấy bản đồ trước) — đúng ý PO?
