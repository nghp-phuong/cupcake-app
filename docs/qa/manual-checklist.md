# Sugarleaf Bakery V2 — Checklist kiểm thử trên điện thoại thật

Dùng cho người test cầm máy thật. Đánh dấu `[x]` khi đạt; không đạt thì ghi mã lỗi / ghi chú ngay dưới dòng.
Liên quan: `docs/qa/test-plan.md` (phạm vi, tiêu chí), `docs/qa/test-cases.md` (ID chi tiết trong ngoặc).

**Thông tin lượt test**
- Người test: ________ · Ngày: ________ · Bản build: ________ (Cài đặt → phiên bản)
- Máy: ________ · Android: ____ · Độ phân giải (ngang): ________ · RAM: ____ · Tai thỏ/đục lỗ: có / không
- Loại máy: [ ] chuẩn 16:9 (1280×720 / 1920×1080) [ ] dài 20:9 (vd. 3200×1440) [ ] tablet [ ] máy yếu (RAM ≤ 3 GB)

> Lưu ý: quảng cáo và mua hàng hiện là **giả lập** ("Chế độ thử"). Mục 9 và 10 chỉ chạy khi có bản build nối SDK thật
> (AdMob + Google Play Billing). Game **chưa có rung** và **chưa có file âm thanh** (chỉ tiếng click hệ thống) — mục 7 ghi nhận hiện trạng.

---

## 1. Cài đặt và lần mở đầu
- [ ] Cài APK / từ track kiểm thử thành công, icon và tên app đúng
- [ ] Lần đầu mở: cảnh mở đầu chạy mượt (~22 s), có nút **Bỏ qua** luôn hiện (SMK-02, SMK-03)
- [ ] Hết cảnh mở đầu / Bỏ qua → vào thẳng thẻ Sẵn sàng L1 (không qua bản đồ)
- [ ] Đóng hẳn rồi mở lại: intro ngắn ~4 s, chạm bất kỳ vào bản đồ ngay (SMK-04)
- [ ] Không có màn trắng/đen kéo dài khi mở; thời gian tới khung đầu: ____ s (mục tiêu < 4 s, máy yếu < 6 s)

## 2. Cảm giác chơi (L1–L10 tối thiểu, thêm 2–3 màn mỗi chương sau nếu có tiến trình)
- [ ] Hướng dẫn L1 dễ hiểu: tay chỉ đúng chỗ, chữ đọc kịp, không bị kẹt bước nào (GP-30)
- [ ] Hướng dẫn L2 (combo) và L3 (kiên nhẫn) hiện đúng lúc, không chặn thao tác
- [ ] Chạm khách để bán: phản hồi tức thì, khách rời vui, xu bay lên
- [ ] Khách không có món: khách lắc nhẹ, hiểu là "tủ không có"
- [ ] Vòng kiên nhẫn đổi màu dễ nhận (bạc hà → vàng → đỏ)
- [ ] Combo: thấy rõ hệ số, cảm giác thưởng khi bán liên tục
- [ ] Trạm Khuôn: chọn khuôn rõ ràng, chọn sai có phản hồi
- [ ] Trạm Trộn: xoay ngón quanh âu tự nhiên, không bị trượt nhận sai
- [ ] Trạm Lò: kim dễ canh, vùng vàng đủ rộng để thấy công bằng; cháy có cảnh báo
- [ ] Trạm Kem: quẹt theo đường gợi ý mượt, không lag nét
- [ ] Trạm Topping / Hộp: chạm hũ, hộp chính xác, không chạm nhầm
- [ ] Khách đặc biệt (Hòa, Linh, Kenji, VIP, bà Rosa): dễ nhận ra, cảnh truyện ấm áp, 6 trạm rõ ràng; câu nhận xét chỉ đúng trạm chưa đạt
- [ ] Màn kéo dài cảm nhận 2–4 phút; giờ cao điểm có cảm giác dồn dập nhưng không bất công
- [ ] Nhân viên (Nora, Bảo, Theo, Ami) làm việc nhìn thấy được, không che khách/tủ/bong bóng
- [ ] Màn kết quả: sao, xu, khách hài lòng/bỏ đi, combo cao nhất dễ đọc

## 3. Độ khó (ghi kết quả thật của người test)
| Màn | Lần thử tới khi thắng | Sao | Cảm nhận (dễ / vừa / khó / quá khó) |
|---|---|---|---|
| L1 | | | |
| L3 (mục tiêu xu 650) | | | |
| L5 (khách 24/28/29) | | | |
| L10 (đơn đặc biệt 2/3/4) | | | |
| L12 / L20 | | | |
| L33 / L40 | | | |
| L48 / L50 | | | |
- [ ] Không màn nào phải thử > 5 lần với người chơi bình thường
- [ ] Đủ 16 sao để mở chương 2 sau một lượt chương 1 mà không phải cày nhiều (PRG-05)
- [ ] Người mới hiểu vì sao thua (thiếu khách/xu/đơn) qua màn kết quả
- [ ] L10: có bị bỏ lượt khách đặc biệt (toast) vì phục vụ chưa đủ khách không? Ghi lại: ________

## 4. Tiến trình, mở khoá, kinh tế
- [ ] Thắng L5 → thẻ "Mở khoá mới!" + chấm đỏ nút Nâng cấp; "Xem" mở đúng thẻ (PRG-09)
- [ ] Mua Kệ bánh nhiều tầng (4200 xu) → tủ thêm ô, thấy kệ trong tiệm (PRG-10)
- [ ] Thuê Nora (L10, 5000 xu), nâng chỉ số trừ đúng giá (PRG-16, PRG-17)
- [ ] Bếp rộng (L22) hiện "Sắp có" (PRG-14)
- [ ] Quà đăng nhập và nhiệm vụ ngày nhận được, số đúng (ECO-09, ECO-10)
- [ ] Thu nhập vắng nhà (đã thuê Cô Hạnh): đóng app ≥ 10 phút → hộp "Khi bạn vắng nhà" đúng số, Nhận cộng 1 lần (ECO-11)
- [ ] Không thấy giá nào "không bao giờ mua nổi" hoặc "rẻ vô nghĩa" trong lúc chơi bình thường

## 5. Lưu dữ liệu
- [ ] Thắng một màn → vuốt tắt app → mở lại: sao, xu còn (SMK-07)
- [ ] Mua đồ → bấm Home → buộc dừng trong Cài đặt hệ thống → mở lại: đồ còn (SAV-02)
- [ ] Tắt app giữa màn: mở lại không cộng xu lượt dở, không hỏng lưu (SAV-11)
- [ ] Cài đè bản mới lên bản cũ: tiến trình còn (SAV-16)
- [ ] (Nếu có bản V1 cũ) cài V2 đè: hộp "Chào mừng trở lại", +500 xu +20 kim cương, L1–L(ngày−1) 2★ (SAV-07)
- [ ] Xoá dữ liệu trong Cài đặt → ván mới, intro dài hiện lại (SAV-12)

## 6. Giao diện, màn hình, ngôn ngữ
- [ ] Màn 16:9: khung vừa khít, không viền (UI-01)
- [ ] Màn 20:9: viền kem hai bên đều nhau, nội dung không bị cắt (UI-02)
- [ ] Tai thỏ/đục lỗ: không che HUD, nút ⏸, xu, nút Bỏ qua (UI-04)
- [ ] Thanh điều hướng cử chỉ / 3 nút: vuốt mép không vô tình thoát màn; Back hoạt động đúng từng màn (UI-13)
- [ ] Xoay máy: luôn ngang, lật 180° được (UI-05)
- [ ] Tiếng Việt: dấu hiển thị đúng ở mọi font, không tràn chữ ở bản đồ, thẻ Sẵn sàng, Nâng cấp, Sổ công thức, cửa hàng, Thẻ mùa (UI-09)
- [ ] Tiếng Anh: tương tự
- [ ] Số có phân tách hàng nghìn đúng ngôn ngữ (en 1,800 / vi 1.800) (UI-11)
- [ ] Ảnh vẽ tay sắc nét ở màn độ phân giải cao, nhân vật đúng tỉ lệ với tiệm (UI-15)
- [ ] Bật "Xoá hiệu ứng động": intro ngắn lại, không lia/hạt (UI-16)
- [ ] Cỡ chữ hệ thống lớn nhất: bố cục không vỡ (ghi nhận: chữ không phóng) (UI-17)

## 7. Âm thanh và rung (hiện trạng)
- [ ] Âm thanh bật: có tiếng click hệ thống khi bán / chạm / chuông intro; tắt trong Cài đặt → im lặng
- [ ] Máy để chế độ im lặng / rung: game không phát tiếng
- [ ] Rung: **không có** (đúng hiện trạng code) — ghi ý kiến người test có cần rung không: ________
- [ ] Nghe nhạc nền ứng dụng khác (Spotify…) khi mở game: nhạc ngoài không bị ngắt vô lý

## 8. Quảng cáo và mua hàng giả lập (bản hiện tại)
- [ ] Cửa hàng có nhãn "Chế độ thử"; 7 gói đúng giá ($0.99 / $4.99 / $9.99 / $1.99 / $3.99 / $2.99 / $4.99) (ADS-13)
- [ ] Mua giả lập có hộp xác nhận, Huỷ không mua (ADS-14)
- [ ] Quảng cáo giả ~2 s không đóng được bằng Back, xong trao thưởng đúng 1 lần (ADS-01)
- [ ] +30 giây chỉ hỏi khi hết giờ mà chưa đạt 1★ (GP-27)
- [ ] Interstitial chỉ khi rời màn kết quả, mỗi 3 lượt, từ sau L5; **không bao giờ** khi đang chơi / hướng dẫn / intro (ADS-09, ADS-12)
- [ ] Sau 12 lượt rewarded trong ngày: nút ẩn/mờ, toast "Hôm nay đã hết lượt nhận thưởng" (ADS-06)
- [ ] Bỏ quảng cáo: hết interstitial, vẫn xem rewarded được (ADS-16)
- [ ] Khôi phục giao dịch trong Cài đặt hoạt động (ADS-20)

## 9. Quảng cáo thật (chỉ khi có build nối SDK — dùng ID quảng cáo thử của nhà cung cấp, thiết bị thử)
- [ ] Rewarded tải được; xem hết → nhận thưởng; đóng sớm → **không** thưởng, có thông báo
- [ ] Không tải được quảng cáo (máy bay / không có quảng cáo) → nút báo rõ, không treo, không mất lượt
- [ ] Interstitial đúng tần suất và đúng chỗ như mục 8; không che thao tác đang dở
- [ ] Quảng cáo không phát tiếng khi máy im lặng (theo SDK); quay lại game không mất âm/hình
- [ ] Nội dung quảng cáo phù hợp 13+ (không nội dung người lớn) — kiểm cấu hình xếp hạng nội dung

## 10. Mua hàng thật (chỉ khi có Google Play Billing — tài khoản **license tester**, thẻ thử)
- [ ] Tài khoản test đã thêm ở Play Console → License testing; cài từ track kiểm thử nội bộ
- [ ] Giá hiển thị theo tiền tệ địa phương lấy từ Play (không dùng chuỗi "$" cứng)
- [ ] Mua gói kim cương (tiêu hao) bằng "Test card, always approves" → nhận đúng 80 / 450 / 1000, mua lại được
- [ ] "Test card, always declines" → báo lỗi, không trao, không trừ
- [ ] Huỷ ở hộp thanh toán → không trao
- [ ] Thanh toán chậm / đơn chờ (slow test card) → trao khi hoàn tất, không trao 2 lần
- [ ] Gói một lần (Khởi đầu, Bỏ quảng cáo, Trang phục) không mua lại được; gỡ cài → cài lại → Khôi phục giao dịch trả quyền
- [ ] Hoàn tiền từ Play Console → quyền bị thu hồi theo chính sách (cần PO quyết)
- [ ] Thẻ mùa chỉ mua được khi mùa đang diễn ra

## 11. Gián đoạn và đa nhiệm
- [ ] Cuộc gọi đến khi đang chơi → màn tự tạm dừng; cúp máy → Tiếp tục chơi được (EDG-07)
- [ ] Bấm Home giữa màn → mở lại từ đa nhiệm: hộp Tạm dừng, giờ không trôi
- [ ] Chuyển app khi đang làm 6 trạm đơn đặc biệt → quay lại không mất đơn, kim lò không chạy ngầm (EDG-08)
- [ ] Chuyển app khi đang xem quảng cáo giả → thưởng 1 lần (EDG-09)
- [ ] Khoá màn hình ở intro / thẻ Sẵn sàng / bản đồ → mở lại không crash (EDG-10)
- [ ] Kéo thanh thông báo xuống giữa màn → không tính là vắng nhà, game không lỗi
- [ ] Chế độ chia đôi màn hình / cửa sổ nổi: game hiển thị khung ngang hợp lý hoặc từ chối gọn gàng
- [ ] Hệ thống giết app khi ở nền lâu (mở nhiều app nặng) → mở lại vào intro ngắn, dữ liệu còn

## 12. Mạng
- [ ] Chế độ máy bay từ đầu: app chạy đầy đủ (font, ảnh đóng gói sẵn) (EDG-11)
- [ ] Mất mạng giữa màn: không ảnh hưởng
- [ ] (Bản SDK thật) mất mạng khi bấm xem quảng cáo / mua: báo lỗi rõ, không trao sai

## 13. Máy yếu (RAM ≤ 3 GB)
- [ ] Khởi động nguội: ____ s (mục tiêu < 6 s)
- [ ] FPS giờ cao điểm chương 4–5 (20+ khách, nhân viên): ____ (mục tiêu ≥ 30) (PRF-04)
- [ ] Chuyển bản đồ chương 1 → 5, mở intro dài: không văng app (PRF-07)
- [ ] Chơi 10 màn liên tiếp: RAM đầu ____ MB / cuối ____ MB (tăng ≤ 15%) (PRF-06)
- [ ] Không ANR ("Ứng dụng không phản hồi") khi lưu, khi mở cửa hàng, khi kết quả
- [ ] Máy không nóng quá sau 30 phút; pin tiêu hao ____ % (PRF-09)

## 14. Trường hợp biên
- [ ] Bấm liên tục nút level / Mua / Thuê / Màn tiếp: chỉ 1 lần có hiệu lực (EDG-01..03)
- [ ] Chạm 2–3 ngón cùng lúc vào khách, vừa xoay trộn vừa chạm: không bán trùng, không treo (EDG-04)
- [ ] Bấm loạn lúc hết giờ chuyển sang kết quả: không crash, kết quả 1 lần (EDG-05)
- [ ] Xu 0, kim cương 0: không mua được, báo thiếu, vẫn chơi được (EDG-16)
- [ ] Chỉnh ngày máy +1 ngày: quà đăng nhập / lượt quảng cáo reset (ghi nhận cho PO) (EDG-13)
- [ ] Chỉnh giờ máy lùi khi đã thuê quản lý: không cộng xu bất thường (EDG-14)
- [ ] Xem quảng cáo nhận vật phẩm → Bắt đầu → Thoát trước khi bán: vật phẩm vào kho (ghi nhận lỗ hổng tiềm năng) (EDG-12)

## 15. Kết luận lượt test
- [ ] Không crash trong cả lượt (số crash: ____)
- [ ] Không mất dữ liệu lưu
- [ ] Không quảng cáo xen kẽ trong lúc chơi
- Đánh giá chung: [ ] Đạt [ ] Đạt có điều kiện [ ] Không đạt
- Ghi chú / lỗi đã tạo: ________________________________________________
