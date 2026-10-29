# Sugarleaf Bakery (tên tạm)

Game mô phỏng tiệm bánh ngọt 2D, phong cách cozy, Android (Google Play), toàn cầu. Người chơi: nữ 16–35 tuổi.
Tên app, tên nhân vật, hình ảnh đều là thiết kế nguyên bản — không dùng tên/nhân vật/UI của app khác (đặc biệt
Good Coffee, Great Coffee / Good Pizza, Great Pizza của TapBlaze), không ghi "Ghibli" trong app hay store.

## Công nghệ
- Flutter 3.32 (`C:\Users\Admin\Documents\flutter_windows_3.32.8-stable\flutter\bin\flutter`) + Flame cho các trạm làm bánh.
- **Chỉ chạy ngang màn hình (landscape)**: khóa hướng trong `main.dart` (SystemChrome) và `AndroidManifest.xml`
  (`android:screenOrientation="sensorLandscape"`). Thiết kế theo khung tham chiếu 1280×720, co giãn theo tỉ lệ.
- Đích build: Android (APK) và web (để xem nhanh khi chưa có máy thật).
- Giai đoạn alpha chưa có ảnh vẽ tay: mọi hình (bánh, lò, tiệm, nhân vật) vẽ bằng code (CustomPainter / Flame
  shapes) theo bảng màu bên dưới, gom ở một chỗ để sau thay bằng sprite.

## Lệnh
```
flutter pub get
flutter analyze
flutter test
flutter build web --release        # xem trước: build/web
flutter build apk --debug
```

## Cấu trúc và khu vực
| Thư mục | Nội dung | Người sửa |
|---|---|---|
| `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `lib/core/**`, `android/`, `web/`, `test/core/**` | Khởi động, theme, mô hình dữ liệu, danh mục món/nguyên liệu/khách, kinh tế, lưu game (shared_preferences), dịch vụ quảng cáo/IAP (alpha: giả lập), điều hướng | `dev-core` |
| `lib/game/**`, `test/game/**` | Flame: 6 trạm làm bánh, chấm điểm, phản hồi của khách | `dev-game` |
| `lib/ui/**`, `test/ui/**` | Màn hình Flutter: menu chính, tiệm/ngày kinh doanh, tổng kết ngày, nâng cấp, trang trí, sổ công thức, nhiệm vụ ngày, quà đăng nhập, hội thoại truyện, cửa hàng, cài đặt | `dev-ui` |
| `lib/l10n/*.arb` | Chuỗi giao diện (gen-l10n) | `localizer` |
| `store/**` | Nội dung Google Play | `aso` |

Ngôn ngữ giao diện: **en** (mặc định, nguồn), **vi**. Mọi chuỗi hiển thị đi qua `AppLocalizations`, không viết cứng.

## Thiết kế game (tóm tắt GDD)
- **Một ngày** 3–5 phút: 4–6 khách gọi món → làm bánh → phục vụ → tiền + tip + sao → tổng kết ngày → nâng cấp.
  Không có năng lượng.
- **6 trạm**: (1) chọn khuôn/đế (kéo thả), (2) trộn bột (xoay ngón tay đủ vòng), (3) nướng (nhấn giữ, thả trong vùng
  vàng: ±5% hoàn hảo, ±15% được), (4) phủ kem (vẽ theo đường gợi ý, tính % phủ), (5) trang trí topping (kéo thả, đúng
  loại/số lượng), (6) đóng hộp. Trọng số: nướng 30, kem 25, trang trí 25, trộn 10, hộp 10 → 1–5★.
- **USP**: sau khi phục vụ, khách nói rõ trạm nào chưa đạt ("Bánh hơi cháy!").
- **Món giai đoạn đầu (18)**: cupcake vani/chocolate/red velvet, muffin việt quất, bánh kem dâu, bánh kem matcha,
  bánh sinh nhật tầng, cheesecake, croissant, pain au chocolat, macaron, éclair, madeleine, tart trứng, tart trái cây,
  pie táo, bánh Trung thu (mùa), Bûche de Noël (mùa). Alpha cần ít nhất 8–10 món chơi được.
- **Tiến trình**: cấp tiệm 1–15 (alpha), mỗi cấp mở công thức/nguyên liệu; lò 5 cấp (nới vùng hoàn hảo); dụng cụ;
  trang trí theo bộ (+% tip); khách VIP; sổ công thức 3★.
- **Truyện**: chủ tiệm Mai về thị trấn ven biển tiếp quản tiệm của bà, tìm lại sổ công thức. Khách quen: ông Hòa
  (tart trứng), Linh (macaron), Kenji (đơn "theo cảm xúc"), bà Rosa (VIP, bánh cưới), mèo Mochi (ngày mưa).
- **Giữ chân**: 3 nhiệm vụ ngày, quà đăng nhập 7 ngày.
- **Kiếm tiền (alpha: giả lập, chưa nối SDK thật)**: rewarded (x2 tiền cuối ngày, nguyên liệu hiếm, làm lại bánh hỏng —
  chỉ khi người chơi bấm, tối đa 8/ngày); interstitial chỉ ở tổng kết ngày, từ ngày 4, tối đa 1 lần/2 ngày, không bao
  giờ giữa lúc làm bánh; không banner trong lúc chơi. IAP: gói khởi đầu, gói nguyên liệu S/M/L, bộ trang trí, xóa
  quảng cáo.

## Bảng màu
kem `#FFF4E6` · hồng dâu `#F49AB0` · bạc hà `#A8DCC8` · vàng bơ `#FFD27A` · nâu caramel `#B9805A` ·
chữ chocolate `#5A3E36` · đúng `#7BC47F` · sai `#E86A5C`. Font: Fredoka (tiêu đề), Nunito (nội dung) qua google_fonts
hoặc đóng gói sẵn. Nút bo 16–20px, viền nâu 2px, bóng mềm.

## Quy tắc
- Không commit/push/deploy khi chưa được chủ dự án đồng ý.
- Không chặn luồng UI bằng I/O; lưu game bất đồng bộ.
- Đối tượng 13+, không nhắm trẻ dưới 13 (chính sách Families của Google Play).
