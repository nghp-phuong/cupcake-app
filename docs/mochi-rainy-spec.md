# Đặc tả: Ngày mưa và mèo Mochi (sau alpha, 2026-10-28)

Mục tiêu: dùng ảnh `scenes/rainy_day` và 4 nét mặt Mochi đã duyệt. Thêm một khoảnh khắc ấm áp ngắn, không làm
khó người chơi. Không đổi chấm điểm, kinh tế cốt lõi hay luồng 6 trạm.

## Thời tiết
- **Thuần, xác định theo số ngày.** Lưu/nạp lại phải ra cùng kết quả; không dùng `Random()` của phiên.
  - Ngày 5 luôn mưa, là lần đầu gặp Mochi.
  - Từ ngày 6: mưa khi `(day * 37 + 11) % 4 == 0`, khoảng 25% số ngày.
  - Không bao giờ mưa hai ngày liền nhau. Nếu ngày trước mưa thì ngày này tạnh.
  - Ngày 1–4 không mưa.
- Cài trong `lib/core`, ví dụ `Weather.isRainy(int day)`. `DayController` có `bool get isRainy`.

## Ngày mưa trông thế nào
- **Giới thiệu ngày:** nền là `ArtScene.rainyDay`, ribbon có thêm nhãn "Ngày mưa".
- **Quầy gọi món:** giữ tiệm như cũ, phủ một lớp mưa nhẹ.
  - Vệt mưa mảnh, xiên, màu xanh xám nhạt, rơi chậm, khoảng 40 vệt; chỉ vẽ trong vùng cửa sổ hoặc phía trên quầy.
  - Toàn khung tối đi khoảng 8%.
  - Vẽ bằng một `CustomPainter` có `RepaintBoundary`, không tạo `Paint` mỗi frame.
- Tổng kết ngày không đổi, chỉ thêm dòng "Ngày mưa".

## Mochi ghé tiệm
- **Mỗi ngày mưa Mochi ghé đúng 1 lần,** sau khi phục vụ xong khách thứ `total ~/ 2`, tức lúc bấm "Khách tiếp"
  trên thẻ kết quả, trước khi khách sau vào. Không bao giờ chen vào giữa lúc làm bánh.
- **Các bước:**
  1. **Đến:** Mochi bước vào từ cửa (trượt + nảy nhẹ) với nét mặt **sad**, ướt mưa. Bong bóng thoại hiện lời dẫn.
     - Lần đầu: "Một chú mèo nhỏ ướt sũng trú mưa trước cửa tiệm…"
     - Các lần sau: "Mochi lại ghé trú mưa!"
  2. **Chạm** → nét mặt **neutral**, lời: "Mochi nhìn bạn, đuôi khẽ ve vẩy."
  3. **Hai nút:**
     - **"Vuốt ve"** → nét mặt **joy**, vài trái tim nhỏ bay lên, nhận quà, lời: "Mochi rừ rừ vui vẻ!"
     - **"Để Mochi nghỉ"** → nét mặt **smile**, lời: "Mochi cuộn tròn ngủ bên lò sưởi."
  4. **Chạm tiếp** → Mochi rời đi, khách tiếp theo vào như bình thường.
- **Quà khi vuốt ve:** +30 xu. Lần vuốt ve đầu tiên trong đời game thêm +5 đá quý.
  - Hiện bằng toast/huy hiệu quà theo kiểu đang dùng.
  - Không quảng cáo, không bắt buộc.
- Mochi không gọi món, không ảnh hưởng sao, tip hay tiến độ ngày. Không có trong danh sách đơn của tổng kết.
- **Lưu game:**
  - `mochiVisits` (int): số lần đã gặp.
  - `mochiPets` (int): số lần vuốt ve.
  - `lastMochiDay` (int): chặn nhận quà 2 lần trong một ngày khi thoát ra vào lại.
  - Save cũ thiếu khoá thì mặc định 0.
  - Thoát giữa ngày rồi vào lại: nếu `lastMochiDay == day` thì Mochi không ghé nữa.

## Chia việc
| Người | Việc |
|---|---|
| dev-core | `Weather`, `DayController.isRainy`, thời điểm Mochi ghé (`mochiVisitAfterIndex`, `shouldShowMochi`), `GameState.petMochi()` / `restMochi()` cộng quà + lưu, các trường lưu, test `test/core` |
| localizer | Khoá chuỗi en/vi: `dayRainy`, `mochiName`, `mochiArriveFirst`, `mochiArriveAgain`, `mochiLook`, `mochiPet`, `mochiRest`, `mochiPetThanks`, `mochiNap`, `mochiGift` (có tham số xu/đá quý), `summaryRainyDay` |
| dev-ui | Nền ngày mưa ở giới thiệu ngày, lớp mưa ở quầy, overlay Mochi (`CustomerArt.paintMochi`, `ArtSprites` / `CharacterSprites`), nút, hiệu ứng tim, dòng tổng kết, test `test/ui` |

## Tiêu chí xong
- Ngày 5 hiện ngày mưa, Mochi ghé sau khách giữa ngày. Vuốt ve cộng đúng quà một lần.
- Lưu/nạp không làm Mochi ghé lại hay cho quà lại.
- en/vi không tràn chữ.
- `flutter analyze` sạch, toàn bộ `flutter test` qua.
