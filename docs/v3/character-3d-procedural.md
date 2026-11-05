# Nhân vật 3D dựng bằng code (V3) — đặc tả bản thử

Ngày 03/11/2026. Chủ dự án không nạp credit Tripo, cho phép thử (1) nhân vật 3D do Flutter/thư viện dựng bằng code,
(2) nhân vật hoạt hình khác — miễn **di chuyển được và đẹp, thu hút**. Trưởng phòng chọn: **thú chibi low-poly dựng bằng
code** (giữ đặc điểm nhân vật cũ), và để so sánh, **Mai giữ dạng người chibi** cũng dựng bằng code.

## Phong cách
- Chibi tròn trịa, đầu to (~40–45% chiều cao), thân ngắn, tay chân ngắn mập, không ngón tay (bàn tay tròn).
- Low-poly vừa phải, đổ bóng mềm như cảnh tiệm; màu ấm, pastel theo bảng màu dự án; không viền đen.
- Mặt: mắt hạt đậu đen bóng (có chấm sáng trắng nhỏ), má hồng tròn, miệng nhỏ (chữ "ω" hoặc cung) — mặt là phần
  quyết định "dễ thương", ưu tiên làm kỹ. Chớp mắt (mắt dẹt lại) mỗi 2,5–5 s ngẫu nhiên.
- Chiều cao: người lớn chibi ~1,25–1,35 m (thấp hơn người thật để dễ thương, nhưng vẫn nhô trên quầy 0,95 m rõ ràng).

## 4 nhân vật thử
| id | Dạng | Đặc điểm giữ lại từ bản 2D |
|---|---|---|
| `mai` | **Người chibi** (chủ tiệm) | tóc nâu ấm buộc đuôi ngựa thấp, khăn bandana hồng dâu, kẹp tóc hình lá xanh, áo blouse kem xắn tay, tạp dề vàng bơ có túi, quần be, giày vải trắng, đồng hồ da nâu, má hồng |
| `linh` | **Thỏ trắng** | hai tai thỏ dài dựng (gợi hai búi tóc) có kẹp dâu + kẹp sao vàng, hoodie tím lavender có dây rút, váy xếp ly trắng, giày pastel đế dày, khuyên tai tim hồng, ba lô nhỏ hình thỏ (có thể đơn giản) |
| `hoa` | **Cú già** (ông Hòa) | lông nâu xám, chùm lông mày trắng (gợi ria trắng), kính tròn gọng vàng, mũ beret len nâu, áo gile len xanh xô thơm, nơ đỏ sẫm, dây đồng hồ quả quýt vàng, chống gậy gỗ, dáng đi chậm |
| `staff_nora` | **Cáo đỏ** (thu ngân) | lông nâu đỏ, mõm/ngực kem, chóp đuôi kem, kẹp tóc bạc hà trên tai, tàn nhang (chấm nhỏ trên má), áo sọc hồng–kem, tạp dề bạc hà có bảng tên trơn (không chữ), lắc tay bạc |

## Quyết định 03/11: Mai là người, mọi nhân vật khác là thú chibi
Bảng chuyển đổi (giữ trang phục, phụ kiện, màu của bản 2D trong `docs/design/character-prompts.md` và ảnh
`assets/characters/<id>_neutral.webp`; đặc điểm tóc chuyển thành lông/tai/bờm tương ứng):

| id | Thú | Đặc điểm giữ |
|---|---|---|
| `kenji` | gấu trúc đỏ | tóc đen rối → chỏm lông, kính vuông đen, mũ bucket be, áo khoác field olive, áo thun trắng, jean đậm, khuyên bạc một tai, máy ảnh film |
| `vip_00` bà Rosa | mèo Ba Tư trắng bạc | lông búi cao kiểu tóc, blazer nhung mận, hai chuỗi ngọc trai, trâm vàng, váy dài sang trọng; viền vàng VIP |
| `vip_01` | hươu đực (gạc nhỏ) | lông vuốt ngược, kính gọng vàng mảnh, blazer nhung lục bảo, ghim cài vàng, ria gọn |
| `vip_02` | cừu non quý cô | lông xoăn màu hạt dẻ, mũ rộng vành kem gắn hoa nhỏ, áo choàng ngắn đỏ rượu, váy kem, găng tay |
| `staff_bao` | gấu nâu | mũ thợ bánh trắng nhỏ, áo trắng xắn tay, tạp dề caramel dính bột, khăn giắt dây tạp dề, cây cán bột |
| `staff_theo` | chó corgi | nơ hồng dâu, gile vàng bơ, tạp dề ngắn kem, khay gỗ tròn có tách trà |
| `staff_ami` | gấu trúc (panda) | búi cao cài bút chì gỗ, mái lệch, áo kem cộc tay, tạp dề hồng dâu, găng nướng bạc hà ở túi, guốc trắng, khay 3 bánh bao |
| `staff_hanh` | mèo mướp xám | búi thấp có sợi bạc, kính tròn đồi mồi, khuyên ngọc trai, cardigan xanh xô thơm, váy xếp ly caramel, đồng hồ vàng, bìa kẹp hồ sơ + bút chì |
| `staff_bao_fest`, `staff_nora_fest` | (như bản thường) | trang phục lễ hội theo ảnh `assets/characters/staff_*_fest_neutral.webp` |
| `mochi` | mèo (đi 4 chân) | theo ảnh `mochi_neutral.webp`; mèo thật dạng chibi, đi bốn chân, đuôi dựng, ghé ngày mưa |
| `regular_00` | mèo trắng, chóp tai nhuộm hồng | mũ len pastel, hoodie bạc hà, quần jean nhạt, giày trắng, khuyên tim, tai nghe trắng ở cổ |
| `regular_01` | chuột hamster | nơ to pastel trên đầu, tàn nhang, váy yếm jean nhạt trên áo sọc pastel, tất trắng, ba lô nhỏ |
| `regular_02` | chó cocker spaniel | tai dài gợn sóng nâu → mật ong, áo croptop pastel, cardigan dài kem, jean cạp cao, khuyên vàng tròn, dây chuyền, kẹp sao |
| `regular_03` | nhím | gai ngắn kiểu pixie, kính tròn đồi mồi, áo thun kem in cupcake, quần ống rộng, kẹp sao, túi tote |
| `regular_04` | sóc | đuôi to, hai bím, mũ bucket pastel, áo khoác jean nhạt, váy dài bay, kẹp dâu, tàn nhang |
| `regular_05` | chó shiba | mũ lưỡi trai pastel, áo thun trắng in mặt trời, quần short kaki, đồng hồ da, tai nghe ở cổ |
| `regular_06` | mèo đen, một vệt lông xanh mòng két | hoodie xám, jean đen, khuyên bạc một tai, dây chuyền mảnh |
| `regular_07` | gấu koala | kính vuông nâu, áo sọc xanh navy–kem, quần chino be, đồng hồ da, ba lô vải nhỏ |
| `regular_08` | mèo xiêm | lông dài thẳng sẫm, mũ beret pastel, áo sọc Breton kem–hồng, váy midi, khuyên giọt, nơ kẹp |
| `regular_09` | voi nhỏ (bà ~50) | búi thấp gọn, kính đọc sách vàng có dây, cardigan hồng đất, áo kem, váy dài, khuyên ngọc trai, trâm nhỏ |
| `regular_10` | chó poodle xám (lông uốn) | kính tròn đỏ rượu, áo len cổ lọ vàng mù tạt, quần ống rộng, khăn len |
| `regular_11` | thỏ tai cụp màu be | mũ cói rộng vành, áo lụa kem, khăn lụa hồng, quần linen, chuỗi ngọc trai |
| `regular_12` | chó schnauzer | ria gọn, kính vuông, blazer navy, áo trắng cà vạt đỏ rượu, quần xám, đồng hồ kim loại, cao |
| `regular_13` | hải mã | ria rậm + răng nanh ngắn, mũ beret navy, áo len hoa văn Fair Isle kem, quần nhung nâu, khăn len |
| `regular_14` | sư tử già | bờm = râu quai nón, kính gọng vàng mảnh, áo cổ lọ than, măng tô lạc đà mở, quần sẫm |

## Chuyển động (thủ tục, không cần file animation)
- **Đi**: chân đánh ±25–30°, tay đánh ngược chân, thân nhún 2 lần/chu kỳ, lắc nhẹ trái phải (lạch bạch), đầu nảy trễ một
  chút; tốc độ ~0,9 m/s (ông Hòa 0,6 m/s, gậy chạm đất theo nhịp). Quay người mượt theo hướng đi.
- **Đứng**: thở (co giãn thân 2%), chớp mắt, tai/đuôi đung đưa nhẹ (thú), thỉnh thoảng nghiêng đầu.
- **Vui** (sau khi mua bánh): nhảy nhỏ + hai tay giơ lên. **Ngồi**: ngồi trên ghế, chân đung đưa.
- Bản thử: khách đi theo vòng cửa → hàng chờ → quầy (đứng chờ vài giây, nhảy vui) → bàn (ngồi) → ra cửa, lặp lại;
  Nora đứng sau quầy thu ngân (đứng + thỉnh thoảng vẫy tay chào); Mai đi lại trong bếp giữa lò và bàn trộn.
