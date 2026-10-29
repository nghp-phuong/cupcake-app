# Icon vẽ tay cần tạo thêm (Gemini) — Bước 2 làm lại UI

Thay 57 loại `Icons.*` của Material (xem `ui-survey.md`) bằng icon cùng phong cách màu nước với ảnh đã có. Trong app,
icon nằm ở `assets/art/icons/<id>.webp` (nền trong suốt, cạnh 192 px) và được nạp qua `ArtSprites.icon(id)`. Khi chưa
có ảnh, `SLIcon` tự vẽ hình dự phòng bằng code.

Không ghi tên hãng phim hay hoạ sĩ nào trong prompt.

## Cách tạo

Gemini không xuất được nền trong suốt. Vì vậy cách làm giống ảnh nhân vật và đồ vật:
1. Tạo trên nền trắng trơn.
2. Tách nền tự động.
3. Cắt sát hình, chừa lề 8%, rồi thu về 192×192 WebP.

Để tiết kiệm lượt tạo ảnh (mỗi tài khoản Gemini được khoảng 50 ảnh) và để cả bộ đồng nhất, nên **tạo theo tờ 3×3**: mỗi
ảnh 9 icon cách nhau rộng, sau đó tách theo vùng liền khối trên nền trắng. Icon có cạnh hiển thị ≤ 64 px nên ô khoảng
300 px là đủ nét. Cả 7 tờ nên tạo trong cùng một cuộc trò chuyện. Từ tờ thứ hai, thêm câu:
`Same icon style, line weight, palette and size as the previous sheet.`

Tờ nào lỗi (dính nhau, thiếu, sai thứ tự) thì tạo lại riêng từng icon bằng khối **ICON** đơn bên dưới.

## Khối phong cách

**ICON SHEET** (dán trước danh sách 9 icon):
```
Create an image. A sheet of 9 game UI icons for a cozy 2D bakery game, arranged in a clean 3 by 3 grid with wide equal
white gaps, each icon the same size and centered in its cell. Hand-painted look: soft watercolor fill with gentle
pigment bleeding toward the edges, a slightly wobbly warm dark-brown hand-drawn outline (#5A3E36) of even medium
thickness, muted warm palette (cream, strawberry pink, mint, butter yellow, caramel), simple chunky silhouettes that stay
readable at 32 pixels, soft light from the upper left, no cast shadow. Plain solid pure white background, no text, no
letters, no numbers, no watermark, no border, no grid lines. Square 1:1 image. Icons in reading order (left to right,
top to bottom):
```

**ICON** (một icon):
```
Create an image. A single game UI icon for a cozy 2D bakery game. Hand-painted look: soft watercolor fill with gentle
pigment bleeding toward the edges, a slightly wobbly warm dark-brown hand-drawn outline (#5A3E36) of even medium
thickness, muted warm palette (cream, strawberry pink, mint, butter yellow, caramel), a simple chunky silhouette readable
at 32 pixels, centered, filling about 75% of the frame, no cast shadow. Plain solid pure white background, no text, no
letters, no numbers, no watermark, no border. Square 1:1 image. Icon:
```

## Danh sách (58 icon, 7 tờ)

Dùng đúng thứ tự trong tờ để đặt tên file sau khi tách.

### Tờ 1 — Điều hướng
- 1 · `settings`: a cream cogwheel with a caramel center hole
- 2 · `close`: a strawberry-pink rounded X made of two soft brush strokes
- 3 · `back`: a mint rounded arrow pointing left
- 4 · `forward`: a mint rounded arrow pointing right
- 5 · `arrow_up`: a butter-yellow rounded arrow pointing up
- 6 · `arrow_down`: a butter-yellow rounded arrow pointing down
- 7 · `skip`: two small mint chevrons pointing right, side by side
- 8 · `exit`: a small wooden door slightly open with a mint arrow coming out
- 9 · `check`: a mint check mark brush stroke

### Tờ 2 — Trạng thái và cài đặt
- 10 · `lock`: a small caramel padlock
- 11 · `info`: a round mint badge with a small cream letter-free "i" shape (a dot above a short bar)
- 12 · `warning`: a butter-yellow rounded triangle with a short brown bar and dot
- 13 · `error`: a soft coral-red rounded circle with a short cream bar and dot
- 14 · `medal_max`: a gold medal on a strawberry ribbon with a tiny star
- 15 · `sound_on`: a cream speaker with two caramel sound waves
- 16 · `sound_off`: a cream speaker with a small strawberry X beside it
- 17 · `language`: a mint globe with soft latitude lines and a small speech bubble
- 18 · `phone`: a cream smartphone with a rounded screen, no text

### Tờ 3 — Cài đặt, quảng cáo, menu
- 19 · `trash`: a small cream bin with a caramel lid
- 20 · `reset`: a circular mint arrow looping back on itself
- 21 · `play_video`: a rounded strawberry screen with a cream play triangle
- 22 · `no_ads`: a rounded cream screen with a soft strawberry diagonal stripe across it
- 23 · `shop_bag`: a kraft paper shopping bag with a strawberry ribbon handle
- 24 · `basket`: a woven caramel wicker basket with a cream cloth
- 25 · `quest_board`: a small wooden notice board with two pinned paper notes, no writing
- 26 · `decor_chair`: a cute café chair with a mint cushion
- 27 · `slot_wallpaper`: a rolled sheet of wallpaper with a strawberry and cream stripe pattern

### Tờ 4 — Ô trang trí, game
- 28 · `slot_floor`: a small square of honey wooden floor planks
- 29 · `slot_counter`: a small wooden bakery counter
- 30 · `slot_window`: a small arched window with mint frame and cream curtains
- 31 · `slot_plant`: a small potted green plant in a terracotta pot
- 32 · `heart`: a plump strawberry-pink heart
- 33 · `vip`: a small gold crown with three round tips and pink gems
- 34 · `customer`: a simple head-and-shoulders silhouette in cream with a caramel outline
- 35 · `sun`: a butter-yellow sun with short rounded rays
- 36 · `umbrella`: an open mint umbrella with a caramel curved handle

### Tờ 5 — Thời tiết, Mochi, hiệu ứng
- 37 · `raindrop`: a single soft blue-grey raindrop
- 38 · `paw`: a cream cat paw print with pink pads
- 39 · `moon`: a butter-yellow crescent moon with a tiny star
- 40 · `flame`: a small warm orange flame with a butter-yellow core
- 41 · `sparkle`: a four-pointed butter-yellow sparkle with two tiny ones
- 42 · `trophy`: a small gold trophy cup with two handles
- 43 · `confetti`: a party popper bursting with pastel confetti
- 44 · `clock`: a round cream wall clock with caramel hands
- 45 · `tip_jar`: a small glass jar with a few gold coins inside, no label

### Tờ 6 — Khác
- 46 · `bulb`: a butter-yellow light bulb glowing softly
- 47 · `leaf_logo`: a single mint leaf with a curled stem
- 48 · `pin`: a round strawberry push pin seen from a three-quarter angle
- 49 · `plus`: a mint rounded plus sign made of two soft brush strokes
- 50 · `cake_slice`: a small slice of strawberry cream cake
- 51 · `book`: a closed recipe book with a strawberry-pink cover and a small mint leaf on it, no text
- 52 · `star`: a plump butter-yellow star
- 53 · `oven`: a small cream retro baking oven with a glass door glowing warm
- 54 · `gift`: a small gift box in mint with a strawberry ribbon bow

### Tờ 7 — Bổ sung ở Bước 3
- 55 · `tap`: a hand with the index finger tapping, cream skin tone, small motion arcs
- 56 · `storefront`: a tiny bakery storefront with a strawberry-and-cream striped awning, no sign text
- 57 · `coin`: a gold coin with a small leaf embossed in the center
- 58 · `ticket`: a small cream paper order ticket with a zigzag bottom edge and a pink pin, no writing
- 59–63 · Còn trống 5 ô. Có thể tạo lại icon xấu ở các tờ trước, hoặc thêm `minus` (a mint rounded minus sign) và
   `star_xp` (a small butter-yellow star with a sparkle).

Ghi chú: `book`, `star`, `oven`, `gift`, `coin` và `ticket` đã có ảnh vẽ tay lớn trong `assets/art/items/`. Icon ở đây là
bản đơn giản hơn để đọc rõ ở cỡ 24–32 px.

## Kiểm tra trước khi đưa vào app

- Thu nhỏ còn 32 px vẫn nhận ra được hình.
- Viền nâu cùng độ dày giữa các tờ. Không có chữ hay số; riêng `info`, `warning`, `error` chỉ có dấu chấm và vạch.
- Lưu ảnh vào `docs/design/art-preview/icons/` để chủ dự án duyệt trên `sugarleaf-characters.html`, như các ảnh đồ vật.
- Duyệt xong thì chép sang `assets/art/icons/` và khai báo thư mục trong `pubspec.yaml` (việc của dev-core).
