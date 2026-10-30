# Sugarleaf Bakery · Video kể chuyện ~25 giây — "Về quê" + "Cuốn sổ của bà" (9:16)

Bản mở rộng của [story-15s-recipe-book.md](story-15s-recipe-book.md): thêm phần mở đầu kể vì sao Mai về quê. Vẫn là
video kể chuyện nhẹ nhàng, không quảng cáo, lời Mai dạng nhật ký.

## Trạng thái

- Đã xuất `sugarleaf_story_25s_vi.mp4` và `sugarleaf_story_25s_en.mp4` (25 s, 1080×1920).
- Ảnh khung đầu N1–N3 tạo bằng Gemini: `frames/story_n1_office.png`, `story_n2_bus.png`, `story_n3_attic.png`.
- N1–N3 là clip Dreamina Seedance 1.0 Fast (60 credit/clip, không có tiếng), tạo từ ảnh đã vẽ lại cho khớp thiết kế
  gốc `mai_neutral` (mắt chấm nhỏ không ánh sáng, tóc mái lệch, đuôi tóc buộc thấp ngắn):
  `frames/story_n1_office_v2.png`, `story_n2_bus_v2.png`, `story_n3_attic_v2.png`. Bản ảnh đầu tiên (không có `_v2`)
  bị lệch nhân vật, không dùng nữa.
- Cảnh 1–5 cũng đã làm lại bằng Seedance 1.0 Fast cho cùng nét vẽ: `clips/story_s1_sd.mp4` … `story_s5_sd.mp4`
  (khung đầu: `frames/shot3_mai_kitchen.png` cho cảnh 1–2, `story3_hoa_page.png`, `story4_mai_baking.png`,
  `story5_mai_evening.png`). Script tự dùng các clip này; đặt `$env:VEO = "1"` để quay về bản Veo cũ.
  Cảnh 5 chỉ lấy 0,2–2,7 s vì nửa sau clip Mai ngồi lên mặt bàn. Clip có watermark "Dreamina AI"
  góc dưới phải (giữ nguyên, không bật tuỳ chọn bỏ watermark).
- Xuất lại:
  ```
  $env:STORY = "25"; python tool\marketing\make_story.py vi en
  ```

## Cốt truyện

Mai làm văn phòng ở Hà Nội. Ngày nào cũng deadline, đêm nào cũng tăng ca, đến mức quên cả cảm giác được thở chậm. Một
ngày, Mai xin nghỉ phép, bắt xe về thị trấn ven biển nơi bà từng sống. Dọn dẹp căn nhà cũ, Mai leo lên gác mái và tình cờ
tìm thấy trong chiếc rương gỗ cuốn sổ công thức viết tay của bà — nhiều trang còn bỏ trống. Ông Hòa, khách quen của bà,
mang đến một trang bà gửi lại năm xưa. Mai làm lại chiếc bánh ấy, rồi quyết định ở lại, viết tiếp những trang còn trống.

## Storyboard

| # | Thời gian | Hình ảnh | Lời Mai (VI) | English | Nguồn |
|---|---|---|---|---|---|
| N1 | 0–3,5s | Đêm, văn phòng ở Hà Nội: Mai (đồ công sở) gục bên laptop giữa chồng giấy, mưa và đèn thành phố ngoài cửa kính, Mai xoa thái dương, thở dài | Ở Hà Nội, ngày nào cũng là deadline. | In Hanoi, every day was a deadline. | **Mới** |
| N2 | 3,5–6,5s | Sáng, trên xe khách: Mai tựa đầu vào cửa kính, biển hiện ra, Mai mở mắt và khẽ mỉm cười | Một ngày, mình xin nghỉ… và về quê. | One day, I took a break… and went home. | **Mới** |
| N3 | 6,5–10s | Gác mái nhà bà: nắng xiên qua ô cửa tròn, bụi bay, Mai mở rương gỗ, lấy ra cuốn sổ da, thổi bụi | Dọn gác mái nhà bà, mình tìm thấy… | Clearing Grandma's attic, I found… | **Mới** |
| 1 | 10–13,5s | Mai lật cuốn sổ trong bếp cũ | …cuốn sổ công thức bà viết tay. | …her handwritten recipe book. | `shot2_mai_veo.mp4` |
| 2 | 13,5–16,5s | Mai ôm sổ, mỉm cười | Nhiều trang còn bỏ trống… nhưng mình không vội. | Many pages are still blank… but I'm in no hurry. | `shot2_mai_veo.mp4` |
| 3 | 16,5–19,5s | Ông Hòa trao trang giấy cũ | Ông Hòa mang đến một trang bà gửi lại năm xưa. | Mr. Hoa brought a page Grandma left with him long ago. | `story3_hoa_page_veo.mp4` |
| 4 | 19,5–22,5s | Mai rắc bột, khuấy bột | Mình làm lại chiếc bánh ấy, theo nét chữ của bà. | I baked it again, following her handwriting. | `story4_mai_baking_veo.mp4` |
| 5 | 22,5–25s | Tối, Mai viết vào sổ; hiện "Tiệm bánh Sugarleaf" | Từ hôm nay, mình sẽ viết tiếp. | From today, I'll write the next page. | `story5_mai_evening_veo.mp4` |

Âm thanh: N1 tiếng mưa, tiếng gõ phím, nhạc gần như im; N2 nhạc piano bắt đầu, tiếng xe êm, hải âu; N3 tiếng gỗ kẽo kẹt,
nắp rương mở; từ cảnh 1 giữ như bản 15 giây.

## Nhân vật Mai ở phần mở đầu

Cùng gương mặt và kiểu tóc với thiết kế gốc (`assets/characters/mai_*.webp`) nhưng **chưa đeo khăn dâu và tạp dề** — đó
là dấu hiệu Mai chưa "thành" chủ tiệm:
- N1: tóc nâu buộc thấp gọn, kẹp lá nhỏ, áo sơ mi kem, cardigan xám nhạt, thẻ nhân viên đeo cổ, đồng hồ da.
- N2–N3: tóc nâu buộc thấp, kẹp lá, áo len mỏng màu kem, quần jeans; N3 thêm khăn dâu buộc tạm để dọn nhà (nối sang hình
  ảnh chủ tiệm).

## Prompt ảnh khung đầu (Gemini, đính kèm `assets/characters/mai_neutral.webp` làm ảnh tham chiếu nhân vật)

Khối phong cách chung:
```
Hand-painted 2D cozy storybook illustration, soft watercolor and gouache texture, thin warm-brown hand-inked outlines, gentle paper grain, warm muted palette of cream, strawberry pink, mint, butter yellow and caramel. Vertical 9:16 composition. Keep the young woman exactly like the attached reference: same face, tiny dot eyes, rosy cheeks, small line mouth, warm brown hair in a low ponytail, small green leaf hair clip, about 6.5 heads tall with adult proportions. No text, no letters, no logos, no watermark.
```

**N1 · văn phòng Hà Nội ban đêm** → `frames/story_n1_office.png`
```
[STYLE] Late at night in a small modern office in Hanoi. The young woman, Mai, sits at a cluttered desk lit by the cold blue glow of a laptop, stacks of paper files and sticky notes around her, a cold cup of coffee. She wears a cream blouse, a light grey cardigan, an employee ID lanyard and a brown leather wristwatch; her ponytail is a little messy. She looks exhausted, rubbing her temple. Behind her a big window with rain streaks and blurred city lights and motorbike light trails. Cool blue-grey tones with small warm accents. Medium shot, she is in the lower half of the frame.
```

**N2 · trên xe khách về quê** → `frames/story_n2_bus.png`
```
[STYLE] Early morning inside a coach bus. Mai sits by the window, head resting against the glass, eyes closed, wearing a soft cream knit sweater; a small backpack on her lap. Outside the window a calm turquoise sea, a coastal road and a small lighthouse far away under soft golden sunrise light. Warm, gentle, hopeful mood. Medium close-up from inside the bus, window on the right.
```

**N3 · gác mái nhà bà** → `frames/story_n3_attic.png`
```
[STYLE] A dusty wooden attic of an old seaside house. Warm sunbeams slant through a small round window, dust motes float in the light. Old wooden beams, a rocking chair under a cloth, stacked cardboard boxes, a vintage suitcase. Mai, in a cream knit sweater with a strawberry-pink headscarf tied loosely for cleaning, kneels beside an open old wooden chest and holds a worn brown leather recipe book with both hands, looking at it with surprise and tenderness. Nostalgic, quiet, magical. Medium shot, full body visible.
```

## Prompt video (Kling, Image to Video, 9:16, 5 s; khung đầu = ảnh N1/N2/N3)

Negative prompt chung:
```
text, letters, words, watermark, logo, subtitles, photorealistic, 3D render, CGI, extra fingers, deformed hands, distorted face, face morphing, flicker, jitter, warping background, fast cuts
```

**N1**
```
Hand-painted 2D storybook animation, watercolor and gouache texture, warm-brown hand-inked outlines; the style and colors stay exactly as in the input image. Late night office. Mai slowly rubs her temple, closes her eyes and lets out a long tired sigh, her shoulders dropping; the laptop screen flickers softly, rain streaks run down the window and the blurred city lights shimmer. Very slow push-in. Quiet, heavy, tired mood. Consistent face and outfit.
```

**N2**
```
Hand-painted 2D storybook animation, watercolor and gouache texture, warm-brown hand-inked outlines; the style and colors stay exactly as in the input image. Inside a gently moving coach bus at sunrise. The sea and coastline glide past the window, golden light flickers across Mai's face. She slowly opens her eyes, looks out at the sea and a small soft smile appears. Strands of hair move slightly. Slow gentle camera drift. Calm, hopeful. Consistent face and outfit.
```

**N3**
```
Hand-painted 2D storybook animation, watercolor and gouache texture, warm-brown hand-inked outlines; the style and colors stay exactly as in the input image. Sunbeams through the small round attic window, dust motes glittering. Mai gently blows the dust off the old leather book; a soft puff of dust sparkles in the light; she opens the cover slightly and her face lights up with a tender, surprised smile. Slow push-in. Nostalgic, quiet, magical. Consistent face and outfit.
```
