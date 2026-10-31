# Báo cáo lỗi QA — Sugarleaf Bakery, nhánh v2 (30/10/2026)

Gộp từ ba đợt test tự động (core, gameplay Flame, giao diện) và mô phỏng cân bằng 50 màn. Chi tiết từng lỗi (log đầy
đủ, bước chi tiết) ở `docs/qa/raw/core.md`, `raw/game.md`, `raw/ui.md`. Kế hoạch: `test-plan.md`; test case:
`test-cases.md`; checklist máy thật: `manual-checklist.md`.

## Cập nhật 31/10 — đã sửa 6 lỗi Major + lỗi hàng chờ

| ID | Trạng thái | Cách sửa |
|---|---|---|
| QA-01 | Đã sửa | Mốc hoạt động chỉ tiến (`game_state.dart` `_touchActive`): lặp 5 chu kỳ đổi giờ chỉ được 1 lần trần (9 600 xu thay vì ~48 000). Một lần tiến giờ vẫn ăn được một lần trần (không có giờ máy chủ). |
| QA-02 | Đã sửa | try/catch quanh `showRewarded` ở hộp vắng nhà và cửa hàng; 3 test mới (`qa_ads_test.dart`). |
| UI-01 | Đã sửa | Nới vùng chạm (hit test + semantics) ≥ 48 dp ở `SLPressable` qua `SLTapTarget` mới, hình nút giữ nguyên; ảnh 1280×720 giống từng byte trước/sau (35/35). Trong bếp/sân chơi chỉ nới semantics. |
| UI-03 | Đã sửa | Cờ `_confirming` đặt trước khi mở hộp xác nhận (cửa hàng, vé mùa). |
| UI-05 | Đã sửa | Khoảng nghỉ 400 ms + khớp bậc lúc dựng cho "Học bí quyết". |
| BAL-01 | Đã sửa | L7 `flexibleChance` 0.25→0.85, mốc sao [1515, 1930, 2060]: thắng lần đầu 66–71% (3 seed). Kéo theo L12 1★ 4380→4280 (L12 46%, sát sàn 45%). Sàn 45%/màn áp cả chương 1. |
| QA-03 (mới, chủ dự án báo) | Đã sửa | Khách thứ 2, 3 không dồn lên quầy: cảnh tiệm vẽ khách theo chỗ logic cố định. Giờ vẽ theo thứ tự lên quầy, dồn chỗ mượt 0,5 s (`lib/game/level/shop_view.dart`); 6 test mới; đã chơi thử trên web. |

Sau khi sửa: `flutter analyze` sạch; `flutter test` 929 qua, 13 skip (5 có sẵn + 8 test QA còn lỗi Minor/Trivial: UI-02,
UI-04, UI-06, UI-07, BUG-G01 ×2, BUG-CORE-01/02); mô phỏng `average` không lệch mục tiêu (seed 2 chương 2 còn 67,x%,
sát mục tiêu 68%). Còn lại: 6 lỗi Minor, 1 Trivial.

Cần PO xác nhận thêm: người chơi chỉ bán được cho khách đang đứng quầy (3 chỗ); nếu cả 3 muốn món tủ đang hết thì hàng
chờ đứng im tới khi có bánh hoặc có người bỏ đi.

## Cập nhật 31/10 (đợt 2) — đã sửa 6 lỗi Minor + 1 Trivial

| ID | Trạng thái | Cách sửa |
|---|---|---|
| UI-02 | Đã sửa | `RefFrame.frameRect`: khung 1280×720 luôn nằm trong vùng an toàn (`viewPadding`), co/dời ít nhất có thể; máy 19,5:9 có viền rộng hơn tai thỏ không đổi. Không tai thỏ → cây widget như cũ. |
| UI-04 | Đã sửa | `popDialogOnce` (`dialogs.dart`): chỉ pop khi route hộp còn hiện hành; áp cho hộp xác nhận, nút X của `SLDialog`, hộp Tạm dừng, +30 giây, vé mùa. |
| UI-06 | Đã sửa | `formatCompact`: thanh tiền từ 1 triệu rút gọn (1.2M / 1,2 Tr); nhãn đọc màn hình vẫn đủ số. |
| UI-07 | Đã sửa | `showRewardedFailedToast`: còn lượt → "Quảng cáo chưa xem xong…" (`adNotCompleted`), hết lượt thật → `adsLimitReached`. Hộp vắng nhà giờ cũng báo khi x2 thất bại. |
| BUG-G01 | Đã sửa | Trạm topping: chốt giữa lúc ngón khác đang nhấn/dời không gỡ hay làm rơi topping; huỷ con trỏ (cuộc gọi đến) khi đang dời → topping về chỗ cũ (`_restoreLifted`). |
| BUG-CORE-01 | Đã sửa | Mọi phép cộng xu/kim cương qua `GameState.walletAdd`, kẹp [0, 2^53−1]. |
| BUG-CORE-02 | Đã sửa | Đọc bản lưu kẹp xu/kim cương về [0, 2^53−1]; ∞ → trần, số âm → 0, NaN → mặc định. |

Sau khi sửa: `flutter analyze` sạch; `flutter test` 943 qua, 5 skip (có sẵn, không còn test QA-BUG nào bị skip);
`flutter build web --release` thành công. Chưa thử tai thỏ trên máy Android thật.

## Kết quả chạy (đợt QA 30/10, trước khi sửa)

| Hạng mục | Kết quả |
|---|---|
| `flutter analyze` | Sạch |
| `flutter test` toàn dự án | 906 qua, 19 skip (5 có sẵn + 14 test QA đánh dấu lỗi), 0 hỏng |
| Test QA mới | 223 test (core 89, gameplay 53, giao diện 81): 209 qua, 14 skip vì lỗi |
| Test lỗi chạy lại (`--run-skipped --dart-define=QA_RUN_BUGS=true`) | Đỏ đúng như báo cáo → lỗi tái hiện được |
| Bot chơi L1→L10 (headless) | Qua cả 10 màn lượt đầu, lưu/đọc lại khớp |
| `integration_test` trên thiết bị | **Chưa chạy**: dự án không có `windows/`, web không hỗ trợ integration test; cần máy Android |
| Mô phỏng 50 màn (`tool/simulate.dart`, 200 người chơi/kỹ năng) | Không kẹt màn nào; 1 màn quá khó (BAL-01) |
| Test case tài liệu | 168 (P1 79, P2 71, P3 18) |

Mức độ: **Critical 0 · Major 6 · Minor 6 · Trivial 1** (13 lỗi).

## Danh sách lỗi

| ID | Tiêu đề | Mức độ | Màn hình | Các bước tái hiện | Mong đợi | Thực tế | Ảnh/log | Gợi ý nguyên nhân |
|---|---|---|---|---|---|---|---|---|
| QA-01 | Đổi giờ máy để nhận thu nhập vắng nhà nhiều lần | Major | Hộp "Khi bạn vắng nhà" | Có quản lý (L32+). Tiến giờ máy vài giờ → mở app → Nhận → lùi giờ về → lặp | Mỗi khoảng thời gian thật chỉ được tính một lần | 5 chu kỳ trong vài giây thật được ~48.000 xu (quản lý cấp 1, x2 quảng cáo) | `qa_offline_test.dart` › 2 test "CẦN PO" | `lib/core/game_state.dart:1549-1568`: đồng hồ lùi → đặt lại mốc; nên giữ mốc = max(mốc cũ, bây giờ) |
| QA-02 | Quảng cáo thưởng lỗi làm kẹt hộp vắng nhà / nút cửa hàng | Major (khi nối SDK thật) | Hộp vắng nhà, Cửa hàng | SDK quảng cáo ném lỗi khi bấm "x2 (xem quảng cáo)" ở hộp vắng nhà | Báo lỗi, vẫn bấm Nhận được | Không có `try/catch`: `_busy` giữ true, nút Nhận và Back đều bị chặn, hộp không đóng bằng chạm nền → kẹt. Cửa hàng: nút xem quảng cáo kẹt ở "đang xem" | Kiểm bằng đọc code (giả lập hiện không ném lỗi) | `lib/ui/map/offline_dialog.dart:112`, `lib/ui/store/store_screen.dart:72`; `level_screen.dart:273,440` đã có `try` |
| UI-01 | Nút nhỏ hơn 48 dp trên máy thật | Major | Bản đồ, Cửa hàng, Cài đặt, Kết quả… | Máy 720×1600 @2 (800×360 dp) mở các màn | Vùng chạm ≥ 48 dp | Nút tròn thanh trên 27 dp, Quay lại 28 dp, "Mua" cao 24 dp; máy 1080×2400: 31–47 dp; tablet 43–45 dp | `qa_touch_targets_test.dart` › "vùng chạm trên máy thật" | `lib/core/ref_frame.dart:33-36` co cả khung 1280×720 theo dp; cỡ nút tính theo px tham chiếu |
| UI-03 | Bấm đúp "Mua" mở hai hộp xác nhận chồng nhau | Major | Cửa hàng, Vé mùa | Hai chạm "Mua" trên thẻ gói lọt cùng khung hình | Một hộp xác nhận | Hai hộp chồng nhau | `qa_edge_cases_test.dart` | `store_screen.dart:37-50`, `season_pass_screen.dart:86-100`: cờ `_buying` đặt sau `await showConfirmDialog` |
| UI-05 | "Học bí quyết" bấm đúp học 2 bậc, trừ xu 2 lần | Major | Sổ công thức › Bí quyết của bà | Qua L41, đủ xu → chạm đúp "Học" | Lên 1 bậc | Lên 2 bậc, trừ giá cả hai bậc, không xác nhận | `qa_edge_cases_test.dart` | `lib/ui/recipes/recipe_book_screen.dart:483-497`: không chống chạm đúp (thiết bị đã có, bí quyết chưa) |
| BAL-01 | Level 7 quá khó với người chơi trung bình | Major | Màn L7 "Chiều nhung đỏ" | `SIM_SKILL=average SIM_RUNS=200 flutter test tool/simulate.dart` | Thắng lần đầu 50–95% (L6 95%, L8 88%) | 28% (người chơi giỏi 89%); mô phỏng vẫn báo "0 lệch" | Bảng 1 của mô phỏng | Mục tiêu xu/mốc 1★ L7 trong `assets/config/levels.json:78`; `lib/core/sim/balance_report.dart:52` không áp sàn 45% cho chương 1 |
| UI-02 | Nút sát mép nằm dưới tai thỏ (máy 16:9) | Minor | Mọi màn có nút Quay lại, Bản đồ | Máy 1280×720 có padding trái/phải 48 | Nút tránh vùng tai thỏ | Quay lại ở x 20..76, nút bản đồ ở 1192..1268 bị che | `qa_touch_targets_test.dart` | `lib/core/ref_frame.dart:18-24` bỏ qua `MediaQuery.padding` |
| UI-04 | Hai chạm cùng khung hình ở hộp xác nhận đóng luôn màn bên dưới | Minor | Cửa hàng | Mua gói → ở hộp xác nhận chạm "Mua" hai lần trong cùng khung | Đóng mỗi hộp | Mua 1 lần, `pop` thứ hai đóng luôn Cửa hàng | `qa_edge_cases_test.dart` | `lib/ui/common/dialogs.dart:66,72` |
| UI-07 | Huỷ quảng cáo thưởng báo nhầm "đã hết lượt" | Minor (lộ khi có SDK) | Kết quả, Cửa hàng, Màn chơi | `showRewarded` trả `false` khi còn lượt (người chơi đóng sớm) | "Quảng cáo chưa xem xong nên chưa có thưởng" | "Hôm nay đã hết lượt nhận thưởng" | `qa_ads_test.dart` | `level_result_screen.dart:90`, `store_screen.dart:80`, `level_screen.dart:289,452`; cần khoá chuỗi mới |
| BUG-G01 | Topping bị gỡ/mất sau khi đã bấm Xong (đa chạm) | Minor | Bếp › trạm topping | Đặt 2 topping → ngón 1 giữ một topping → ngón 2 bấm Xong → nhấc ngón 1 | Giữ đủ 2 topping | Ghi 1 topping, khách có thể chê "thiếu topping" | `qa_bake_stations_test.dart` (2 test) | `lib/game/stations/topping_station.dart:138-143` (`done()` không xoá `_pressed`), `:98-115` không kiểm `isDone` |
| BUG-CORE-01 | Cộng xu/kim cương tràn int, số dư về 0 | Minor | Ví | Bản lưu xu gần 2^63 → kiếm thêm 100 xu | Giữ ở trần | Về 0 | `qa_save_test.dart` | `game_state.dart:1676, 1681, 1757` và các `_coins +=`; nên kẹp 2^53−1 |
| BUG-CORE-02 | Bản lưu xu 1e300 được nhận thành 2^63−1 | Minor | Đọc bản lưu | `fromJson({'coins':1e300})` → `addCoins(1)` | Kẹp/coi là trường hỏng | 2^63−1 rồi về 0 | `qa_save_test.dart` | `game_state.dart:434-435` |
| UI-06 | Thanh trên bản đồ tràn khi xu ≥ ~100 triệu | Trivial | Bản đồ | Xu 99 999 999 | Không tràn | RenderFlex tràn 25–48 px | `qa_screens_matrix_test.dart` | `lib/ui/map/level_map_screen.dart:922` |

## 5 lỗi cần sửa trước

1. **QA-01** — gian lận thu nhập vắng nhà bằng giờ máy (phá kinh tế, dễ lan trên mạng).
2. **QA-02** — kẹt hộp vắng nhà khi quảng cáo lỗi; phải sửa trước khi nối SDK quảng cáo thật.
3. **UI-01** — nút quá nhỏ trên điện thoại thật (gần như mọi máy 20:9).
4. **UI-03 + UI-05** — chạm đúp mua hai lần / mở hai hộp (liên quan tiền thật và xu).
5. **BAL-01** — L7 thắng lần đầu 28%, nằm ngay chương 1, dễ làm người chơi mới bỏ game.

## Đánh giá sẵn sàng Closed Testing (Google Play)

**Chưa sẵn sàng.** Lõi game ổn định: không có lỗi Critical, không crash trong test, không rò rỉ bộ nhớ, bot qua L1–10 và
mô phỏng 50 màn không kẹt. Nhưng trước khi lên Closed Testing cần:
- sửa 6 lỗi Major ở trên;
- quảng cáo và IAP vẫn là giả lập ("Chế độ thử"), chưa có SDK AdMob / Play Billing → chưa test được mua thật, khôi phục
  giao dịch, quảng cáo thật; nếu muốn lên sớm thì ẩn cửa hàng/quảng cáo hoặc nối bản test của SDK;
- chạy `integration_test` và `manual-checklist.md` trên ít nhất 2 máy Android thật (một máy yếu, một máy 20:9 có tai
  thỏ); chưa có số đo FPS/bộ nhớ/khởi động trên máy thật;
- chưa có âm thanh thật và rung (cần PO quyết có bắt buộc cho bản test không).

## Cần BA/PO xác nhận

Gộp từ `test-plan.md` §9 và các file `raw/`:
1. Game chỉ chạy ngang 1280×720; các cỡ dọc PO ghi (720×1280, 1440×3200) đã thử theo cỡ ngang tương ứng. Viền kem hai bên
   trên máy 20:9 có chấp nhận không?
2. Chuẩn vùng chạm 48 dp có bắt buộc không (nếu không, UI-01 hạ xuống Minor)? Có hỗ trợ máy 16:9 có tai thỏ không (UI-02)?
3. Mở rộng bếp L22, đào tạo nhân viên L41, trang trí hiếm L45 đang "Sắp có" — phát hành như vậy được không?
4. Lùi ngày hệ thống được thêm 12 lượt quảng cáo thưởng (kết hợp +1 kim cương/lượt) — có cần chặn không?
5. Vật phẩm nhận bằng quảng cáo được hoàn vào kho khi thoát trước lần bán đầu — chủ ý hay lỗ hổng?
6. Chấm điểm: sai hộp / trộn lệch / sai khuôn 2 lần vẫn 5★; sai hoặc thiếu topping vẫn 4★; không chấm "sai loại kem"
   (trạm kem chỉ tính % phủ); nướng trong vùng "được" nhưng lệch > 0.075 vẫn bị chê. Có đúng ý cân bằng không?
7. Khách đặc biệt bỏ đi không tính vào số khách bỏ đi — màn kết quả có cần hiện không?
8. Quảng cáo thưởng 12 lượt/ngày và interstitial mỗi 3 lượt từ sau L5 (CLAUDE.md còn ghi 8/ngày, "từ ngày 4, 1 lần/2 ngày").
9. Bí quyết của bà +5/10/15% (cấu hình) — `docs/v2/phase8-spec.md:92` còn ghi +8/16/25%.
10. Người chơi giỏi thắng lần đầu 88–99% (nhiều màn > 95%) — chấp nhận vì mục tiêu đo cho người chơi trung bình?
11. Xoá dữ liệu làm mất gói IAP đã mua; khôi phục giả lập trả 0 — khi nối Play Billing phải khôi phục từ cửa hàng.
12. Thẻ mùa hiện tại hết hạn 15/12/2026, chưa có mùa sau.
13. App tắt cỡ chữ hệ thống (`ref_frame.dart:24`) — có chấp nhận về khả năng tiếp cận không?
14. Số phiên bản: Cài đặt hiện `0.1.0-alpha`, pubspec `1.0.0+1`.
15. Sau intro dài vào thẳng L1 (không qua bản đồ); L10 chỉ đếm đơn đặc biệt từ 3★ — có cần báo rõ hơn không?
16. Ngưỡng hiệu năng cho máy yếu (QA đề xuất ≥ 30 FPS, khởi động < 6 s, bộ nhớ < 400 MB).
