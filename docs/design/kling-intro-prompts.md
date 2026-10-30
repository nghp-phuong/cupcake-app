# Prompt Kling — video cảnh mở đầu (intro)

Dựng lại cảnh mở đầu GĐ5 (`docs/v2/phase5-spec.md` §2) thành video **~22 s, 16:9, 1280×720 trở lên**, gồm 4 shot ghép
lại. Mỗi shot tạo riêng trên Kling bằng **Image to Video**, khung đầu lấy từ ảnh có sẵn trong game, để màu, nét vẽ và nhân
vật khớp với phần còn lại của app.

**Khung ảnh đã ghép sẵn, chỉ cần tải lên:** thư mục `docs/design/kling/`
- `shot1_start.png`, `shot2_start.png`, `shot3_start.png`, `shot3_end.png`, `shot4_start.png`
- Đều cỡ 1280×720, bố cục giống hệt trong game.
- Dựng lại bằng `kling_frames.py` (scratchpad) nếu ảnh gốc đổi.

## Cài đặt chung
- Chế độ: **Image to Video**. Chọn Professional/High Quality nếu có. Tỉ lệ 16:9.
- Thời lượng: shot 1, 2, 4 chọn **5 s**; shot 3 chọn **10 s**.
- Creativity / Relevance: để thấp (~0.3–0.4) cho video bám sát ảnh đầu.
- Camera: dùng mục Camera Movement nếu có. Không có thì chuyển động máy đã ghi sẵn trong prompt.
- **Negative prompt**, dán vào mọi shot:
  ```
  text, letters, words, watermark, logo text, subtitles, signature, photorealistic, 3D render, CGI, glossy plastic look,
  extra fingers, deformed hands, distorted face, face morphing, flicker, jitter, warping background, fast cuts, dark
  horror mood, people other than the one woman
  ```
- Không ghi tên hãng phim, hoạ sĩ hay app khác vào prompt. Phong cách được tả bằng đặc điểm, theo quy tắc dự án.
- Chữ trên màn ("Mở cửa"/"Open", logo "Sugarleaf Bakery", phụ đề) **không cho Kling vẽ**. Lý do: video AI vẽ chữ hay sai,
  và game cần hai bản en/vi. Chữ sẽ chèn sau, lúc dựng (CapCut/Premiere) hoặc vẽ đè trong app.

### Khối STYLE (dán đầu mỗi prompt)
```
Hand-painted 2D anime film look, soft gouache and watercolor textures, gentle warm-brown hand-drawn linework, muted warm
palette of cream, strawberry pink, mint, butter yellow and caramel, soft warm early-morning light, cozy, nostalgic and
heartwarming. Smooth, slow, gentle motion; the painted style and colors stay exactly the same as the input image.
```

### Mô tả Mai (dán khi shot có Mai, giữ nguyên câu chữ để nhân vật nhất quán)
```
Mai, a cheerful young woman in her mid-20s with realistic adult proportions: warm brown hair in a soft low ponytail with a
few loose strands and a small leaf-shaped hair clip, a strawberry-pink bandana, a cream-white blouse with rolled sleeves
under a butter-yellow apron with a small pocket, light beige trousers, white canvas shoes, a little smudge of flour on her
nose.
```

---

## Shot 1 — Bếp buổi sáng (5 s)
- **Khung đầu:** `docs/design/kling/shot1_start.png` (= `scenes/intro_kitchen.webp`)
- **Camera:** zoom in chậm (khoảng 1.0 → 1.08), hơi trượt sang phải.
```
[STYLE] An old seaside bakery kitchen at sunrise, no people. The fire inside the red-brick bread oven flickers softly and
glows orange; thin wisps of white steam rise slowly from the oven mouth and curl away. Golden sunbeams slant through the
tall window and gently pulse in brightness; tiny dust motes drift and sparkle in the light. Outside the window the sea
shimmers and the lighthouse stands still. Everything else stays calm. Slow, steady camera push-in toward the oven with a
very slight pan to the right.
```

## Shot 2 — Tủ bánh của bà (5 s)
- **Khung đầu:** `docs/design/kling/shot2_start.png` (= `shop/shop_base.webp`)
- **Camera:** lia ngang trái → phải rồi đẩy nhẹ vào tủ kính.
```
[STYLE] Interior of a small cozy bakery, no people. The camera pans slowly from left to right along the shelves of jars and
the warm hanging lamps, then gently pushes in toward the glass display case full of pastries. The lamps sway very slightly
and glow; small soft sparkles glint across the curved glass of the case; the pastries stay perfectly still and unchanged.
Calm, inviting morning atmosphere.
```

## Shot 3 — Mai mở cửa tiệm (10 s)
- **Khung đầu:** `docs/design/kling/shot3_start.png` (cửa, biển trống, chuông, chưa có Mai).
- **Khung cuối (End Frame, nếu Kling cho chọn):** `docs/design/kling/shot3_end.png`. Mai (`mai_joy`) đứng bên phải
  cửa, tay cầm cupcake dâu, cười. Có khung cuối thì nhân vật giữ đúng mặt hơn nhiều.
- **Camera:** đứng yên, có thể đẩy vào rất nhẹ.
```
[STYLE] Inside the small bakery, looking at the mint-painted front door with a large glass pane; a quiet cobblestone
street and the sea glow in the sunrise outside. A small blank cream wooden sign hangs on the glass and a little brass bell
hangs above the door frame. [MAI] Mai walks in calmly from the right edge of the frame toward the door with a light,
happy step, carrying a small strawberry cupcake in her right hand, stops beside it, reaches up with her left hand and
turns the hanging sign around (it flips over and keeps its
blank face toward us). The brass bell above the door swings and rings gently, swaying a few times and settling. Mai
turns to the viewer, holds the cupcake in both hands at chest height and smiles warmly with her eyes closed. Camera stays steady with a very slow slight push-in. Natural walking
motion, consistent face and outfit for the whole shot.
```
Nếu Kling tạo người đi sai hoặc biến dạng mặt, cắt làm hai shot 5 s: (3a) Mai đi vào và dừng cạnh cửa; (3b) Mai lật biển,
chuông rung, Mai cười. Shot 3b lấy khung cuối của 3a làm khung đầu.

## Shot 4 — Huy hiệu logo (5 s)
- **Khung đầu:** `docs/design/kling/shot4_start.png`. Nền kem `#FFF4E6`, huy hiệu ở giữa, chừa trống phía dưới cho
  chữ "Sugarleaf Bakery" chèn sau. Dải ruy băng trên huy hiệu để trống.
```
[STYLE] A round cream bakery emblem with a strawberry cupcake, a fresh mint-green leaf and a blank pink ribbon banner on a soft
cream background; the ribbon stays blank.
The emblem gently scales up a little and settles; the mint leaf sways once as if in a breeze; small butter-yellow
sparkles twinkle around the badge and a few soft pink petals drift slowly down. Clean, calm, no other objects. The camera
does not move.
```

---

## Ghép và đưa vào game
1. Ghép 4 shot, chuyển cảnh **mờ chéo 400 ms**, tổng ~22 s. Chèn phụ đề GĐ5 (hai bản en và vi), chữ "Mở cửa"/"Open" lên
   biển ở shot 3, và chữ logo ở shot 4 bằng font Fredoka, viền nâu `#5A3E36`.
2. Xuất **2 file** `intro_en.mp4` và `intro_vi.mp4`:
   - Định dạng H.264, 1280×720, 30 fps.
   - Mỗi file khoảng ≤ 6 MB, để APK không nặng thêm nhiều.
   - Bỏ âm thanh, hoặc thêm nhạc nhẹ có bản quyền dùng được.
   - Bản không chữ giữ thêm làm tư liệu cho store/marketing.
3. Đưa vào app: hiện cảnh mở đầu vẽ bằng code (`lib/ui/intro/`). Muốn chạy video thay thế cần:
   - gói `video_player`;
   - lưu file ở `assets/video/`;
   - giữ nút Bỏ qua;
   - thiếu file hoặc lỗi phát → quay về cảnh code hiện tại.
   Đây là việc của dev-core (pubspec) và dev-ui (màn intro), làm khi đã có video duyệt.
