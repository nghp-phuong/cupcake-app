# QA gameplay Flame (lib/game) — ghi chép thô

Nhánh `v2`, ngày 2026-10-30. Người viết: QA (test tự động). Không sửa code game.

## Test đã thêm

| File | Nội dung | Số test |
|---|---|---|
| `test/game/qa_bake_stations_test.dart` | 6 trạm của đơn đặc biệt (`BakeryGame` chạy thật trong `GameWidget`, con trỏ toạ độ 1280×720): chơi chuẩn cả 18 món → 5★ không chê; từng trạm hỏng → lời chê chỉ đúng trạm (khuôn sai, trộn thiếu / quá, nướng mép hoàn hảo ±0.045, vùng "được" +0.12, chưa chín, cháy, kem 25%, topping thiếu / sai loại, sai hộp, hai trạm cùng hỏng); thao tác biên (ngón thứ hai, bấm loạn lúc chuyển trạm, Xong khi chưa đủ vòng, chạm nướng quá ngắn, kéo bánh liên tục lúc đóng nắp, Xong khi đang giữ topping) | 39 (37 đạt, 2 skip vì lỗi) |
| `test/game/qa_bake_session_edge_test.dart` | `BakeSessionView` bằng cử chỉ thật: app vào nền khi đang giữ nút nướng; đổi cỡ cửa sổ 4 lần giữa màn (thay cho xoay máy) | 2 |
| `test/game/qa_level_edge_test.dart` | Màn chơi level: bấm loạn 4 ngón 6000 sự kiện (kèm tạm dừng ngẫu nhiên) + kiểm bất biến bếp/tủ; hai ngón cùng khuấy; tạm dừng giữa lúc khuấy / quẹt kem; chạm liên tục hũ / lò / hộp; hết giờ giữa lúc khuấy; `attachSession` giữa lúc khuấy; `LevelPlayView` vào nền – quay lại; đổi cỡ cửa sổ 4 lần | 9 |
| `test/game/qa_perf_leak_test.dart` | Hiệu năng 25+ khách + 10 nhân viên + bếp do bot chơi (TB / p95 / p99 / max); 10 màn thật (levels.json 1–10) liên tiếp headless; 10 màn gắn/gỡ `LevelPlayView` (ticker, listener `ArtSprites.changes`, pool hình khách, chữ bay) | 3 |

Tổng: 53 test mới — 51 đạt, 2 skip có lý do `QA-BUG`. `flutter test test/game`: 192 đạt, 7 skip (2 của QA + 5 skip có sẵn), 0 lỗi.
`flutter analyze lib test/game`: sạch.

## Lỗi đã tái hiện

### BUG-G01 — Trạm topping: bấm Xong trong lúc một ngón đang giữ topping trên bánh → topping bị gỡ / mất sau khi đã chốt

| Mục | Nội dung |
|---|---|
| Mức độ | Minor |
| Màn hình | Làm bánh đơn đặc biệt (`BakeSessionView`) — trạm 5 Topping |
| Bước tái hiện | 1. Đặt 2 topping lên bánh. 2. Ngón 1 nhấn giữ lên một topping đã đặt (hoặc kéo nó > 12 px để dời chỗ). 3. Ngón 2 bấm nút **Xong** (nút Flutter nằm trên lớp `Listener` nên nhận được chạm thứ hai). 4. Nhấc ngón 1 trong 0.9 s hoạt cảnh mừng. |
| Mong đợi | Bấm Xong là chốt: số topping trên bánh giữ nguyên (2), kết quả `toppingsPlaced = {topping: 2}`. |
| Thực tế | Trường hợp nhấn giữ: nhấc ngón 1 vẫn chạy nhánh "chạm để gỡ" → còn 1 topping. Trường hợp đang dời chỗ: `done()` đặt `_dragging = null` nên topping đang cầm biến mất → còn 1. `BakeOutcome` gửi cho chấm điểm thiếu topping → khách có thể chê "thiếu topping" dù người chơi đã đặt đủ. |
| log | `Expected: an object with length of <2>  Actual: [Instance of 'PlacedTopping']  — đã bấm Xong nhưng nhấc ngón vẫn gỡ topping khỏi bánh`; `Expected: {ToppingId.strawberry: 2} Actual: {ToppingId.strawberry: 1} — topping đang cầm lúc bấm Xong bị xoá khỏi bánh` |
| Test | `qa_bake_stations_test.dart` › "topping: giữ ngón trên topping đã đặt…" và "topping: đang nhấc một topping đã đặt để dời chỗ…" (skip `QA-BUG … (BUG-G01)`) |
| Gợi ý nguyên nhân | `lib/game/stations/topping_station.dart:138-143` — `done()` chỉ xoá `_dragging`, không xoá `_pressed` và không trả topping đang dời về bánh; `pointerUp` (`:108-115`) / `pointerMove` (`:98-101`) không kiểm `isDone`. `BakeryGame.pointerUp` (`lib/game/bakery_game.dart:303-308`) chỉ nuốt ngón theo `_swallow` tính lúc chạm xuống nên ngón đã chạm trước khi bấm Xong vẫn tới trạm. Hướng sửa: trong `done()` đặt `_pressed = null`, nếu `_dragging` là topping nhấc từ bánh thì đặt lại chỗ cũ; hoặc các hàm con trỏ của trạm `return` khi `isDone`. |

Không tái hiện được lỗi nào khác ở 6 trạm, bếp nhanh, tạm dừng, vào nền, đổi cỡ, hay rò rỉ.

## Số đo hiệu năng (máy dev Windows, `flutter test`, headless — chỉ đo phía Dart: step + ghi lệnh vẽ vào PictureRecorder, không có raster GPU)

| Kịch bản | Kết quả |
|---|---|
| 25+ khách (tối thiểu 25, cuối 36) + 10 nhân viên + 2 lò, bot làm bếp, 1200 khung | step+paint TB **0.55–0.81 ms** · p95 **0.95–1.85 ms** · p99 **2.1–3.8 ms** · max 18–20 ms (lần chạy đầu sau khi dịch: TB 2.38 · p95 3.94 · p99 8.28 · max 102 ms) |
| Khung > 16.7 ms | 1/1200, luôn ở khung thứ 60 sau làm nóng, không trùng sự kiện session nào → nhiều khả năng GC / bộ đệm lần đầu của máy test |
| `level_play_perf_test` có sẵn (30 khách, để so) | TB 0.637 ms, max 13.2 ms |
| 10 màn thật liên tiếp (L1–L10, bot BotSkill 0.8, tới hết giờ hoặc 40 s) | TB step+paint mỗi màn (ms): 0.357 · 0.471 · 0.502 · 0.638 · 0.494 · 0.486 · 0.480 · 0.394 · 0.462 · 0.451 → không tăng dần |
| Bộ đệm ảnh qua 10 màn | ảnh nhân vật `LevelCharacters` 60→64→…→76 (giữ theo dàn của màn, `retainOnly`); ảnh `ArtSprites` 52→58 (có trần LRU) |
| 10 màn gắn / gỡ `LevelPlayView` | ticker khi chơi 1/1/…/1, sau khi gỡ 0 (gốc 0); listener `ArtSprites.changes` của game đã gỡ không còn nhận (artGeneration không đổi khi nạp ảnh mới); hình khách = số khách mỗi màn (pool trả đủ); `floats.liveCount` ≤ 64 |

Kết luận: không thấy dấu hiệu rò rỉ component / listener / ticker; thời gian khung ổn định qua 10 màn.

## Cần BA/PO xác nhận

1. **Vùng nướng "được" (±15%) vẫn bị chê.** Thả lệch 0.075–0.15 so với vạch cho điểm nướng 0.6–0.9, dưới ngưỡng `Scoring.goodThreshold` 0.9 → khách vẫn chê "hơi cháy" / "chưa chín" (test "nướng trong vùng được +0.12"). GDD chỉ ghi "±5% hoàn hảo, ±15% được" — có muốn thả trong vùng vàng mà vẫn bị chê không?
2. **Đổi cỡ cửa sổ giữa lúc đang kéo.** Flutter giữ phép biến đổi của lúc chạm xuống cho cả cử chỉ, nên nếu cửa sổ đổi cỡ (chia màn hình, gập máy) đúng lúc đang kéo khuôn / bánh thì điểm thả bị lệch (thả hụt, vật trượt về chỗ). Không lỗi, không tính sai; kéo lại được. App khoá ngang nên hiếm gặp — chấp nhận?
3. **Vào nền khi đang giữ nút nướng.** Flame tự dừng game khi vào nền (test đạt: kim lò đứng yên). Nhưng nếu hệ điều hành không gửi `PointerCancel` khi app vào nền và người chơi nhấc tay lúc app ở nền, khi quay lại kim lò sẽ tiếp tục chạy như đang giữ cho tới khi chạm lại hoặc cháy. Không tái hiện được trong test (phụ thuộc thiết bị) — cần thử tay trên Android thật.
4. **Bếp nhanh: nhấc tay sau ≥ 0.5 vòng là tự chốt mẻ** (điểm trộn 0.2, chê "trộn chưa đều"). Người chơi khuấy nửa vòng rồi nhấc để đổi tay sẽ bị chốt ngay — có đúng ý không?
5. **Trạm topping bắt buộc ≥ 1 topping mới bấm Xong được.** Mọi món hiện có topping nên chưa gây kẹt; nếu sau này có đơn không topping thì người chơi buộc phải đặt sai.
