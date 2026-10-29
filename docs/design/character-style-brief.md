# Brief vẽ lại nhân vật bằng ảnh tạo từ AI (fal.ai)

Chủ dự án chọn phong cách trong `reference/style-ref.webp`, **cột 1 ("bản anh chọn")**. Hình phải là ảnh minh hoạ thật
(raster), không phải vẽ bằng code. Công cụ: MCP `fal` (fal.ai, cài ở cấu hình user, đăng nhập qua `/mcp`).

## Phong cách
- Toàn thân, tỉ lệ người thật hơn chibi (khoảng 6–7 đầu), đứng thẳng, nhìn thẳng.
- Mắt chấm nhỏ màu nâu đậm, lông mày mảnh, má hồng tròn mềm, miệng nét nhỏ.
- Viền nâu ấm mảnh, hơi dày mỏng như vẽ tay; tô màu gần như phẳng, bóng rất nhẹ.
- Màu nhạt, ngả kem; nền kem trơn hoặc trong suốt; vân giấy nhẹ.
- Quần áo đời thường, có chi tiết (áo len bện thừng, đường may jean, giày vải, túi tote).
- Phụ kiện chủ dự án muốn giữ: kẹp tóc, mũ, kính, khuyên tai, đồng hồ. Trẻ: cá tính; trung niên: nhã nhặn.
- **Không** ghi "Ghibli" hay tên hãng phim/hoạ sĩ nào trong prompt (quy tắc dự án). Chỉ mô tả bằng đặc điểm.

## Cách giữ nhân vật đồng nhất
1. Tạo ảnh gốc "bình thường" toàn thân cho từng nhân vật (mô hình text-to-image).
2. Dùng ảnh gốc làm ảnh tham chiếu cho mô hình sửa ảnh có tham chiếu để ra 3 nét mặt còn lại (mỉm cười, vui = mắt
   cong vòng cung, buồn = lông mày cụp), giữ nguyên quần áo, tư thế, khung hình.
3. Cùng kích thước, cùng tư thế để thay qua lại trong game không bị giật.

## Danh sách (cùng mô tả trong `lib/core/art/characters/cast.dart`)
- Mai (chủ tiệm): tóc nâu buộc thấp, áo blouse + tạp dề vàng, khuyên nụ, đồng hồ da, cầm cupcake.
- Ông Hòa: ông cụ, tóc bạc mỏng, gile, mũ nồi, kính tròn gọng vàng.
- Linh: cô gái trẻ, hai búi tóc, hoodie, khuyên trái tim, đồng hồ điện tử.
- Kenji: nam trẻ, tóc rối, áo khoác, mũ bucket, kính vuông, khuyên vòng, cầm máy ảnh.
- 15 kiểu khách thường (9 trẻ, 6 trung niên) và 3 VIP: ảnh ở `assets/characters/regular_00..14_*` và `vip_00..02_*` (mô tả trong `character-prompts.md`). Không còn bản vẽ bằng code.

## Bước 1 (đang chờ): mẫu Mai để duyệt
- Mai × 4 nét mặt, lưu `docs/design/characters/mai_{neutral,smile,joy,sad}.png`.
- Trang duyệt `docs/design/characters-review.html` (một file, ảnh nhúng base64): ảnh mẫu phong cách, Mai bản code
  hiện tại, Mai bản mới 4 nét mặt; có nút Ổn / Cần sửa + ghi chú + "Sao chép nhận xét" như `sugarleaf-design.html`.
- Chủ dự án duyệt xong mới làm cả dàn và mới đưa vào game (thay `CustomerArt` bằng ảnh, giữ nguyên API).
