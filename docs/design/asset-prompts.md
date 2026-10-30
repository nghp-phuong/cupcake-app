# Prompt tạo ảnh cho bánh, đồ vật, tiệm, bếp (Gemini)

Cùng phong cách với nhân vật (`character-prompts.md`): vẽ tay ấm áp kiểu phim hoạt hình, màu nước + gouache, viền nâu ấm
mảnh. Không ghi tên hãng phim hay hoạ sĩ nào trong prompt. Danh mục lấy từ `lib/core/models/ids.dart` và
`lib/core/catalog.dart`.

Có hai loại ảnh:
- **Đồ vật (sprite)**: nền trắng trơn để tách nền tự động như nhân vật. Lưu `assets/art/<nhóm>/<id>.webp`, nền trong suốt.
- **Cảnh (nền)**: khung 16:9, không người, không chữ. Lưu `assets/art/scenes/<id>.webp`, 1280×720.

Mỗi nhóm nên tạo trong **một cuộc trò chuyện**: tạo món đầu tiên, các món sau thêm câu
`Same art style, lighting, outline and scale as the previous image.` để cả bộ đồng nhất.

## Khối phong cách

**OBJECT** (dán trước mỗi prompt đồ vật):
```
Create an image. Game item illustration for a cozy 2D bakery game. Hand-painted anime film look: soft gouache and
watercolor textures, gentle warm-brown hand-drawn outline, muted warm palette (cream, strawberry pink, mint, butter
yellow, caramel), soft warm light from the upper left, appetizing and heartwarming. Single object, centered, seen from a
slightly elevated three-quarter front view, filling about 80% of the frame. Plain solid pure white background, no cast
shadow, no table, no text, no watermark, no border. Square 1:1 image. Object:
```

**SCENE** (dán trước mỗi prompt cảnh):
```
Create an image. Background illustration for a cozy 2D bakery game, landscape 16:9. Hand-painted anime film look: soft
gouache and watercolor textures, gentle warm-brown linework, muted warm palette (cream, strawberry pink, mint, butter
yellow, caramel), warm late-afternoon sunlight, nostalgic seaside-town mood, rich but uncluttered details. No people, no
animals, no text, no signs with letters, no watermark, no border. Scene:
```

**TILE** (giấy dán tường, sàn — ô lặp liền mạch):
```
Create an image. Seamless tileable texture for a cozy 2D bakery game, edges must wrap perfectly. Hand-painted gouache
and watercolor look, muted warm palette, flat even lighting, no objects, no text, no border. Square 1:1 image. Pattern:
```

Ảnh chờ duyệt được lưu ở `docs/design/art-preview/<nhóm>/<id>.webp` (chưa đưa vào `assets/`); trang duyệt là
`docs/design/sugarleaf-characters.html`.

## 1. Bánh thành phẩm — `assets/art/cakes/` (10)
Dùng cho sổ công thức, vé đơn, thẻ kết quả, tổng kết ngày.
- `cupcakeVanilla` — `A vanilla cupcake in a pastel pink paper liner, swirl of vanilla buttercream, rainbow sprinkles only, no fruit.` (làm lại 2026-10-29: topping chuẩn của món là sprinkles, ảnh cũ có quả dâu làm người chơi hiểu nhầm)
- `cupcakeChocolate` — `A chocolate cupcake in a brown paper liner, glossy chocolate ganache swirl covered only with rainbow sprinkles, no cherry, no chips.` (làm lại 2026-10-29, khớp topping chuẩn sprinkles)
- `muffinBlueberry` — `A golden blueberry muffin in a cream paper cup with a domed cracked top, bursting blueberries, a light dusting of sugar.`
- `eggTart` — `A Portuguese-style egg tart: flaky golden pastry shell, glossy yellow custard with a few caramelized spots.`
- `strawberryCake` — `A small round strawberry shortcake: white sponge layers, strawberry cream, fresh halved strawberries on top and in the layers.`
- `macaron` — `Three French macarons stacked slightly offset: strawberry pink, vanilla cream and matcha green, smooth shells and ruffled feet, cream filling.`
- `redVelvetCupcake` — `A red velvet cupcake in a white paper liner, thick cream cheese frosting swirl, a few red velvet crumbs and a sugar pearl on top.`
- `matchaCake` — `A slice-free whole small matcha cake: soft green sponge, matcha cream coating, mint leaves and white sugar pearls on top.`
- `cheesecake` — `A small round New York cheesecake with a golden graham crust, smooth cream top, a few blueberries and a mint leaf.`
- `birthdayCake` — `A two-tier birthday cake with vanilla cream, pink piped borders, colorful sprinkles, strawberries and three small lit candles.`

## 2. Các bước làm bánh — dùng ở 6 trạm
### 2a. Khuôn rỗng — `assets/art/moulds/` (7)
- `cupcakeLiner` — `An empty pastel pink pleated paper cupcake liner.`
- `muffinCup` — `An empty tall cream paper muffin cup (tulip style).`
- `tartShell` — `An empty fluted golden tart shell made of raw pastry, in a small metal tart tin.`
- `roundPan` — `An empty round silver cake pan, seen from a three-quarter view.`
- `macaronMat` — `An empty silicone macaron baking mat with printed circle guides, on a small baking tray.`
- `springformPan` — `An empty silver springform cheesecake pan with its side clasp.`
- `tallPan` — `An empty tall round cake pan for a layered birthday cake.`

### 2b. Bột đã trộn trong âu — `assets/art/batter/` (7)
Prompt chung: `A cream ceramic mixing bowl seen from above at a slight angle, filled with smooth <loại> batter, a wooden spoon resting on the rim.`
- `vanilla` (pale vanilla), `chocolate` (rich chocolate), `redVelvet` (deep red velvet), `matcha` (soft green matcha),
  `butter` (golden butter pastry dough, a ball of dough instead of batter), `almond` (pale almond meringue for macarons),
  `cheese` (thick creamy cheesecake filling).

### 2c. Đế bánh đã nướng — `assets/art/baked/` (7)
Chỉ vẽ trạng thái **nướng chuẩn**; chín tới / cháy làm bằng tô màu trong code (đậm hơn hoặc nhạt hơn) để tiết kiệm ảnh.
- `cupcakeLiner` — `A plain baked vanilla cupcake base without frosting in a pink liner, golden domed top.` (thêm bản `cupcakeLiner_chocolate`, `cupcakeLiner_redVelvet`)
- `muffinCup` — `A plain baked muffin base without topping in a cream tulip cup.`
- `tartShell` — `A baked golden tart shell filled with smooth unglazed custard.`
- `roundPan` — `A plain round baked sponge cake without frosting, golden top.` (thêm bản `roundPan_matcha`)
- `macaronMat` — `Six plain baked macaron shells on a mat, no filling yet.`
- `springformPan` — `A plain baked cheesecake with golden crust, smooth top, no toppings.`
- `tallPan` — `Two plain stacked round sponge cake layers, no frosting.`

### 2d. Kem phủ — `assets/art/frosting/` (6)
Biểu tượng chọn kem (túi bắt kem hoặc chén kem). Lớp kem trên bánh vẫn vẽ bằng code theo nét người chơi, dùng màu và vân lấy từ ảnh này.
Prompt chung: `A canvas piping bag with a star tip, filled with <loại>, a small swirl of the same cream piped next to the tip.`
- `vanillaCream` (ivory vanilla buttercream), `chocolateGanache` (glossy dark chocolate ganache), `strawberryCream`
  (pastel pink strawberry cream with tiny seeds), `matchaCream` (soft green matcha cream), `creamCheese` (thick white
  cream cheese frosting), `custard` (glossy pale yellow custard; use a small ceramic cup with a spoon instead of a piping bag).

### 2e. Topping — `assets/art/toppings/` (8)
Mỗi topping một ảnh nhỏ, nhìn từ trên xuống chéo nhẹ để đặt lên bánh.
- `sprinkles` — `A small scattered pile of colorful rainbow sprinkles.`
- `strawberry` — `One fresh strawberry with green leaves, glossy.`
- `cherry` — `One glossy red cherry with a stem.`
- `chocolateChips` — `A few dark chocolate chips.`
- `blueberry` — `Three fresh blueberries with a soft bloom.`
- `mintLeaf` — `A sprig of two fresh mint leaves.`
- `sugarPearl` — `A few shiny white and gold sugar pearls.`
- `candle` — `One thin pastel striped birthday candle with a small warm flame.`

### 2f. Hộp — `assets/art/boxes/` (6)
Mỗi loại 2 ảnh: `<id>_open` (nắp mở, trong rỗng) và `<id>_closed` (đã gói).
- `small` — `A small cream paper pastry box for one cupcake, with a pink ribbon and a small leaf-shaped sticker.`
- `cake` — `A square cake box in kraft paper with a clear window on the lid and twine.`
- `gift` — `A pastel mint gift box with a big strawberry-pink satin bow.`
Với bản mở: `…, lid open, empty inside, no ribbon tied.`

## 3. Dụng cụ, lò, biểu tượng — `assets/art/items/`
- `tool_whisk` — `A balloon whisk with a wooden handle.` / `tool_pipingBag` — `A canvas piping bag with a brass star tip.` / `tool_tongs` — `Small silver pastry tongs.`
- `oven_1` … `oven_5` — 5 cấp lò, cùng góc nhìn, ngày càng đẹp:
  1. `A small old cream enamel oven with a round window and two knobs, slightly worn.`
  2. `The same oven repainted mint green, polished brass knobs.`
  3. `A wider two-door mint oven with a temperature dial and a small clock.`
  4. `A vintage butter-yellow deluxe oven with brass trim, glass window and a warming shelf.`
  5. `A grand caramel-and-cream bakery deck oven with brass details, three glass doors and a warm glow inside.`
- `bowl` — `An empty cream ceramic mixing bowl with a strawberry-pink rim stripe.`
- `coin` — `A shiny gold coin embossed with a small cupcake.` / `gem` — `A faceted pink heart-cut gem with a soft sparkle.`
- `star_on` — `A plump golden star with a soft glow.` / `star_off` — `The same star shape, empty, in pale cream with a dashed outline.`
- `ticket` — `A blank cream paper order ticket with a torn top edge and a little strawberry pin, nothing written on it.`
- `book` — `A worn leather recipe notebook tied with a ribbon, a dried flower tucked inside.` (sổ công thức của bà)
- `gift_daily` — `A small wicker basket with a ribbon, filled with wrapped treats.` (quà đăng nhập)
- Bổ sung 2026-10-29 (thay vật vẽ bằng code). Với các ảnh sau cuộc trò chuyện đầu, mở đầu bằng
  `This must be a hand-painted illustration, NOT a photo, in the exact same style as the … image above.` rồi dán lại cả
  khối OBJECT — chỉ ghi "same style" thì Gemini từng trả ảnh chụp thật.
  - `baking_tray` — `A rectangular steel baking tray lined with a sheet of cream parchment paper, two small rounded side handles, completely empty, soft brushed-steel shading with warm highlights, a wide flat object that fills the frame width, seen from a fairly high angle so the inside of the tray is clearly visible.`
  - `plate_serving` — `An empty round porcelain cake plate, ivory white with a thin hand-painted mint-green rim and a ring of tiny strawberry-pink dots, reading as a wide ellipse, soft watercolor blue-grey shading inside the plate, no food.`
  - `pantry_sack` — `A plump slumped burlap flour sack, full, tied at the neck with a strawberry-pink ribbon bow, the open neck shows a little white flour, a small stitched star patch sewn on the front, a few specks of flour dusted on the fabric, visible woven burlap texture.`
  - `no_ads_badge` (nhìn thẳng) — `A round cream paper badge like a sticker, in its center a little rounded pastel-pink TV screen with a cream play-button triangle, crossed by one bold soft hand-painted coral-red diagonal brush stroke, a tiny mint leaf sticker at the badge corner, slightly curled paper edge.`
  - `boxes/cake_open` (làm lại, có lề) — `A cube-shaped cream-white paper pastry box (not kraft brown) with its lid flipped open upward and backward, empty inside, and a big U-shaped cut-out opening in the front panel that starts at the top edge and goes down about two thirds of the panel, so the cream inner walls and the empty inside floor are visible through the opening (see-through, not a white panel). … fills only about 70% of the frame with a generous white margin on every side.`
- `narrator_book` — người kể chuyện trong truyện (thay cuốn sổ vẽ bằng code; trong game không còn nhân vật vẽ code):
  `An old family recipe journal lying open, worn brown leather cover with soft edges, slightly yellowed cream pages with
  small hand-painted sketches of a strawberry cupcake and a little leaf, a few faint wavy lines suggesting handwriting but
  absolutely no readable letters or words, a pink floral ribbon bookmark trailing out, a pressed dried flower tucked
  between the pages, gentle sparkles of nostalgia around it.`

## 4. Tiệm — `assets/art/shop/`
Cảnh nền cố định một góc nhìn để đặt đồ trang trí lên. Tạo `shop_base` trước, các món trang trí tạo riêng (nền trắng) để
đặt lên đúng ô: tường, sàn, quầy, cửa sổ, cây.
- `shop_base` (SCENE) — `Interior of a small cozy bakery seen straight on from the customer side. A wooden display counter across the lower third with a glass case of pastries, the back wall plain warm cream plaster, a large empty window on the right, a wooden floor, hanging warm lamps, shelves with jars, a small chalkboard without writing. Leave the wall and floor plain so patterns can be added.`
- Giấy dán tường và sàn: ô vuông liền mạch (seamless tile, 1:1, không vật thể):
  - `wallpaperStripes` — `Seamless tileable wallpaper pattern: soft vertical cream and strawberry-pink stripes, hand-painted watercolor texture.`
  - `wallpaperFloral` — `Seamless tileable wallpaper pattern: small mint leaves and tiny pink flowers on cream, hand-painted.`
  - `floorCheckered` — `Seamless tileable floor tiles: cream and caramel checkerboard, top-down, soft watercolor texture.`
  - `floorHerringbone` — `Seamless tileable floor: warm honey wood herringbone parquet, top-down.`
- Đồ trang trí (OBJECT, nền trắng):
  - `counterFlowers` — `A small glass jar vase of pink and white wildflowers.`
  - `counterCakeStand` — `A tall glass cake stand with a dome, holding a strawberry cake.`
  - `windowCurtains` — `A pair of tied-back cream curtains with a pink scalloped valance, for a shop window (no window, only curtains).`
  - `windowSeaView` — `A wide wooden-framed shop window showing a sunny turquoise sea, a lighthouse and seagulls.`
  - `plantFern` — `A lush fern in a terracotta pot.`
  - `plantLemonTree` — `A small potted lemon tree with ripe lemons in a woven basket pot.`

## 5. Bếp — 6 trạm làm bánh, `assets/art/scenes/` (SCENE)
Cùng một gian bếp, mỗi trạm là một góc mặt bàn nhìn từ trên xuống chéo, chừa trống phần giữa để game đặt khuôn/âu/bánh.
- `kitchen_overview` — `A cozy bakery kitchen behind the shop: wooden worktop, open shelves with jars of flour and sugar, copper pans, a window with sea light, herbs in pots.`
- `station_mould` — `Close view of a floured wooden worktop, empty center area; at the edges a stack of paper liners, tart tins and cake pans.`
- `station_mix` — `Close view of a wooden worktop, empty center for a mixing bowl; around it eggs, a flour sack, a sugar jar, a whisk.`
- `station_bake` — `Front view of a warm vintage oven built into tiled kitchen wall, oven door closed with a glowing window, a temperature dial, oven mitts hanging.`
- `station_frost` — `Close view of a marble decorating table with a turntable in the empty center, piping bags and spatulas around the edges.`
- `station_topping` — `Close view of a light wooden table, empty center, small bowls of strawberries, sprinkles, blueberries and mint around the edges.`
- `station_box` — `Close view of a packing counter with kraft paper, ribbons, stickers and twine around an empty center area.`

## 6. Màn khác (SCENE)
- `menu_bg` — `A charming small bakery storefront on a sloping seaside street at golden hour, striped awning, flower boxes, the sea and a lighthouse in the distance. Leave the sky area calm for a title.`
- `story_town` — `A quiet seaside town street with pastel houses, a tram line and the harbor, warm evening light.`
- `story_grandma_kitchen` — `An old dusty bakery kitchen being reopened: sheets over furniture, sunlight through dusty windows, an old recipe book on the table.`
- `day_summary_bg` — `The bakery interior at closing time, chairs up, warm lamp light, a tray of leftover pastries on the counter.`
- `rainy_day` — `The bakery window on a rainy day seen from outside, warm light inside, raindrops on the glass.`
- Mèo **Mochi** (nhân vật, dùng khối STYLE trong `character-prompts.md` nhưng thay câu toàn thân bằng `a small cat, whole body visible`): `A round fluffy cream-and-caramel cat with a tiny strawberry-pink collar bell, sitting politely, slightly wet fur from the rain.` — 4 nét mặt như nhân vật.

## 7. V2 · Giai đoạn 1 — màn chơi theo level
Thay các hình đang vẽ bằng code trong `lib/game/level/` (tủ kính động, bong bóng gọi món, huy hiệu khách đặc biệt, hũ
topping). Chờ duyệt ở `docs/design/art-preview/level/`.
- `shop_base_empty` (SCENE, **sửa ảnh**: tải `assets/art/shop/shop_base.webp` lên cùng prompt) — `Edit this image: keep
  everything exactly the same (camera, counter, walls, lamps, window, colors, linework) but make the glass display case
  completely empty: no pastries, no plates, no price tags inside, only clean glass and empty shelves.` Lưu
  `assets/art/shop/shop_base_empty.webp` 1280×720 — để tủ kính động không phải che bánh vẽ sẵn.
- `display_case` (OBJECT, khung 16:9 thay cho 1:1) — `A wide empty bakery glass display case seen straight from the
  front: caramel wooden base with simple panels, curved clear glass front and top with soft white reflections, one empty
  glass shelf in the middle, nothing inside. Very wide and low proportions, about 2.6 times wider than tall. Landscape
  16:9 image.` Hiển thị ~430×165 px tham chiếu.
- `thought_bubble` (OBJECT) — `An empty cream-white thought bubble with a soft warm-brown hand-drawn outline and two tiny
  trailing dots at the lower left, slightly puffy cloud edge, nothing inside.` Hiển thị ~80×80.
- `special_badge` (OBJECT) — `A small round butter-yellow badge with a plump golden star in the center, thin caramel rim,
  tiny sparkle on the edge.` Hiển thị ~32×32.
- `topping_jar` (OBJECT) — `An empty small round glass jar with a cork lid and a strawberry-pink ribbon around the neck,
  clear glass with soft reflections.` Hiển thị ~80×96; game vẽ topping bên trong.

## 8. V2 · Giai đoạn 2 — bản đồ chương, `assets/art/map/` (SCENE)
Cùng một cuộc trò chuyện để đồng bộ; chương sau thêm `Same art style, palette, linework, camera height and bird's-eye
three-quarter view as the previous image`. Đường đi và nút level do game vẽ theo `mapPos` trong `levels.json`, nên prompt
yêu cầu chừa khoảng trống. Lưu 1280×720, xoá dấu ✦ của Gemini ở góc dưới phải.
- `chapter_1` — `An illustrated storybook map of the quiet old corner of a small seaside town, seen from a high bird's-eye
  three-quarter view, soft morning light. Grandma's tiny bakery cottage with a pink striped awning sits at the lower left;
  around it a few pastel cottages with flower gardens, a vegetable patch, a little bridge over a stream, an orchard and a
  meadow climbing gently toward a small hill on the right with a windmill; the sea and a lighthouse along the top edge.
  Keep large calm open areas of grass and soft dirt between the buildings (no continuous road), because a dotted path with
  level markers will be drawn on top. Top strip of the image should be calm sky or sea.`
- `chapter_2` — `The busy heart of the same seaside town in warm late-afternoon light: a cobblestone market square with
  colorful striped market stall awnings (empty stalls, no people), a fountain in the middle, café tables with umbrellas,
  flower carts, bunting flags strung between houses, a tram stop, the harbor with small fishing boats along the top edge
  and the sea beyond. Grandma's bakery now appears a bit bigger at the lower left with outdoor tables. Keep calm open plaza
  areas between the buildings.`

## Số lượng ước tính
Bánh 10 · khuôn 7 · bột 7 · đế 10 · kem 6 · topping 8 · hộp 6 · dụng cụ/lò/biểu tượng 17 · tiệm 1 + 4 + 6 · bếp 7 · màn
khác 5 · Mochi 4 ≈ **98 ảnh**. Gói miễn phí của Gemini cho khoảng 55 ảnh mỗi lượt (đặt lại sau khoảng 1 giờ), nên cần
khoảng 2 lượt.

Ghi chú khi đưa vào game: đế bánh, kem, topping là các lớp chồng lên nhau trong `CakeArt`. Trạng thái nướng chưa tới /
cháy, độ phủ kem và vị trí topping vẫn do code điều khiển. Giữ hình vẽ code làm dự phòng như với nhân vật.

## 9. V2 · Giai đoạn 3 — mở rộng tiệm, `assets/art/level/` (OBJECT)
Khối OBJECT nhưng đổi góc nhìn thành `seen almost straight from the front at eye level with only a very slight top view`
cho khớp phối cảnh cảnh tiệm. Tách nền trắng (cả vùng trắng khép kín như lòng lưng ghế).
- `case_stand` (mở rộng `case_stand`, L5) — `An empty small two-tier wooden cake display stand for a bakery counter: a
  caramel wooden base, two round light-wood shelves stacked on a slim central post, the lower shelf wider than the upper
  one, a small scalloped cream paper doily on each shelf, a tiny strawberry-pink ribbon tied at the post. Both shelves are
  completely empty and flat so pastries can be placed on them later.` Lưu cạnh dài 360 px.
- `cafe_table` (mở rộng `cafe_tables`, L18) — `A small round café bistro table set for a cozy bakery: one round light
  caramel wooden table on a single pedestal leg, with a tiny cream lace cloth in the middle and a little glass vase holding
  one pink flower, and two matching wooden chairs with rounded backs and strawberry-pink seat cushions, one chair on the
  left side and one on the right side of the table, both facing the table. Nothing else.` Lưu cạnh dài 420 px.

## 10. V2 · Giai đoạn 5 — cảnh mở đầu, hướng dẫn
Cùng một cuộc trò chuyện. Cảnh dùng khối SCENE (bỏ câu "warm late-afternoon sunlight", thay bằng ánh sáng sớm); đồ vật
dùng khối OBJECT với "seen straight from the front". Lưu cảnh 1280×720 (che dấu ✦ góc dưới phải), đồ vật tách nền.
- `scenes/intro_kitchen` — `The old bakery kitchen at early sunrise. On the left a rounded red-brick bread oven with a softly glowing fire inside and a few golden loaves on a wooden peel at its mouth. In the middle a big wooden worktable dusted with flour, a mixing bowl, a rolling pin and a basket of fresh croissants. On the right a tall window with the sea and a lighthouse in pale morning light; warm golden sunbeams slant diagonally through the window across the room with floating dust motes. Copper pans on the wall, jars on shelves. Keep the area just above the oven mouth calm and plain (steam will be animated there).`
- `scenes/intro_door` — `Inside the same small bakery, looking straight at the front entrance in soft early-morning light. In the center a wooden shop door painted soft mint with a large glass window pane in its upper half, through which a quiet cobblestone street, pastel houses and a glimpse of the sea glow in the sunrise. The glass of the door is completely clear and EMPTY: no sign hanging on it, no bell above it, only a small brass hook at the top center of the glass and a small empty curled brass bracket above the door frame. On the left of the door a potted plant and a small wooden bench; on the right a coat rack with an apron and a framed watercolor of a cupcake. Warm wooden floor. Leave clear space on the left side of the door where a person could stand.`
- `level/open_sign` — `A small rectangular wooden hanging shop sign with rounded corners, hanging from a short twisted jute rope that forms a triangle above it. The front face of the board is a smooth, completely blank cream-painted panel with a thin caramel wooden frame and a tiny painted strawberry-pink heart in each bottom corner. Absolutely no words or letters on it.` (chữ "Mở cửa"/"Open" do game vẽ)
- `level/door_bell` — `A small polished brass shop-door bell hanging from a short curved brass hanger with a little curl at the top, a tiny round clapper visible under the bell's rim, a thin strawberry-pink ribbon bow tied where the bell meets the hanger. The bell hangs straight down, seen from the front.`
- `level/tutorial_hand` — `A friendly cartoon pointing hand used as a tutorial cursor in a game: a soft peach-skinned hand with the index finger pointing straight up and slightly to the upper left, the other fingers gently curled, a small cream knitted sleeve cuff at the wrist with a tiny strawberry-pink stripe. Clean, simple and readable at small size, thick warm-brown outline.`
- `level/logo_emblem` — `A round emblem badge for a cozy bakery game logo: a cream circular badge with a scalloped caramel-brown edge, in the middle a plump strawberry cupcake with swirled pink frosting and a single fresh mint-green leaf sprouting from the top of the frosting, two tiny butter-yellow sparkles beside it, a soft strawberry-pink ribbon banner curving across the bottom of the badge left completely blank.`
Lưu ý: `scenes/menu_bg.webp` (V1) có chữ "THE DAILY CRUMB" trên biển tiệm — không dùng trong V2; nếu cần lại thì tạo bản không chữ.

## 11. V2 · Giai đoạn 8 — 8 món mới, bản đồ và truyện chương 3–5
Khối OBJECT cho mọi đồ vật (một cuộc trò chuyện cho cả nhóm món), khối SCENE cho bản đồ và nền truyện. Đặc tả:
`docs/v2/phase8-spec.md`.

### 11a. Bánh thành phẩm — `cakes/` (8)
- `croissant` — `A golden flaky butter croissant with visible layers, glossy egg-washed top, a few toasted almond flakes and a light dusting of powdered sugar.`
- `painAuChocolat` — `A rectangular golden flaky pain au chocolat with two dark chocolate bars peeking out of both ends, glossy top, a light dusting of powdered sugar.`
- `madeleine` — `Three small golden shell-shaped French madeleines with ridged tops and a little hump, dusted with powdered sugar, two white sugar pearls.`
- `eclair` — `A long golden choux pastry éclair with a glossy dark chocolate glaze on top, a little custard visible at one end, toasted almond flakes and a few rainbow sprinkles.`
- `fruitTart` — `A round fruit tart: golden fluted pastry shell filled with glossy custard, topped with neatly arranged strawberries, blueberries, kiwi slices and a mint sprig.`
- `applePie` — `A round golden apple pie with a woven lattice crust, glossy apple filling showing between the strips, a light dusting of powdered sugar and a mint leaf.`
- `mooncake` — `A round golden-brown baked mooncake with an embossed flower pattern on top, one cut wedge showing smooth lotus paste filling, a few white sesame seeds, on a small square of parchment.`
- `bucheDeNoel` — `A Bûche de Noël yule log cake: rolled chocolate sponge covered in chocolate ganache with bark-like lines, a spiral visible at the cut end, small white meringue mushrooms, a red cherry, mint leaves and a snowy dusting of powdered sugar.`

### 11b. Khuôn rỗng — `moulds/` (6)
- `pastryTray` — `An empty rectangular metal baking tray lined with parchment paper, for croissants.`
- `shellMould` — `An empty metal madeleine tin with twelve shell-shaped ridged cavities.`
- `eclairTray` — `An empty baking tray with parchment paper printed with six long oval piping guides for éclairs.`
- `piePan` — `An empty round fluted ceramic pie dish in cream with a caramel rim.`
- `mooncakeMould` — `An empty wooden mooncake press mould with a round carved flower pattern cavity and a handle.`
- `logPan` — `An empty flat rectangular jelly-roll baking pan lined with parchment, for a rolled log cake.`

### 11c. Bột trong âu — `batter/` (3), prompt chung như §2b
- `laminated` (a folded rectangle of layered butter pastry dough on a floured wooden board with a rolling pin, instead of a bowl),
  `choux` (glossy smooth pale-yellow choux paste), `mooncake` (a ball of smooth golden mooncake dough beside a ball of lotus paste).

### 11d. Đế nướng — `baked/<recipeId>` (8), như §2c: bánh đã nướng, chưa phủ/chưa trang trí
- `croissant` (three plain golden croissants on parchment), `painAuChocolat` (three plain rectangular pastries on parchment),
  `madeleine` (golden madeleines still in the shell tin), `eclair` (four plain hollow golden choux fingers on parchment),
  `fruitTart` (a baked fluted tart shell filled with plain custard), `applePie` (a baked lattice apple pie in the cream
  dish, no sugar), `mooncake` (four plain embossed mooncakes on a tray), `bucheDeNoel` (a plain rolled chocolate sponge
  log with spiral end, no ganache).

### 11e. Kem / nhân — `frosting/` (3), như §2d
- `butterGlaze` (a small pastry brush in a cup of glossy golden butter egg glaze), `appleFilling` (a small ceramic bowl of
  glossy cinnamon apple filling with a spoon), `lotusPaste` (a small ceramic bowl of smooth tan lotus seed paste with a spoon).

### 11f. Topping — `toppings/` (5), như §2e
- `almondFlakes` (a few toasted almond flakes), `powderedSugar` (a small mound of powdered sugar with a tiny sieve),
  `kiwi` (two round kiwi slices), `sesame` (a small pile of white sesame seeds), `meringueMushroom` (two small white meringue mushrooms).

### 11g. Bản đồ — `map/` (3), như §8 (cùng cuộc trò chuyện với chapter_1/2 nếu còn)
- `chapter_3` — `The green garden edge of the same seaside town in fresh spring morning light: the bakery's back garden with flower beds, a greenhouse and a garden shed at the lower left, an apple orchard, beehives, a winding stream with stepping stones, wildflower meadows, a little chapel on a hill, the sea along the top edge. Keep large calm open grassy areas for a dotted path.`
- `chapter_4` — `The old hillside quarter of the same seaside town at golden hour, seen from above: steep tiled rooftops, Grandma's bakery now with a second floor and a balcony at the lower left, stone staircases, a library, a clock tower, a bridge over a ravine, a viewpoint terrace with benches, the harbor and sea along the top edge. Keep calm open terraces and lawns for a dotted path.`
- `chapter_5` — `The seaside promenade of the same town during a festival at dusk: a long boardwalk along the beach, paper lanterns and string lights, festival stalls with striped awnings (empty, no people), a small stage, a pier with a Ferris wheel, Grandma's bakery with a festival stall at the lower left, the sea and a few lantern boats along the top edge. Keep calm open sand and boardwalk areas for a dotted path.`

### 11h. Nền truyện — `scenes/` (3), khối SCENE
- `story_garden` — `The back garden of the little bakery in morning light: flower beds, a small wooden garden shed with its door half open showing old crates and a dusty recipe box, a watering can, an apple tree, the sea glimpsed over a low stone wall.`
- `story_attic` — `A cozy sunlit attic room above the bakery: sloped wooden beams, a round window over the sea, an old trunk with bundles of letters tied with ribbon, a small writing desk with an open handwritten recipe notebook (no readable text), dried flowers, a rocking chair.`
- `story_festival` — `The seaside promenade at dusk during the town festival: paper lanterns in pink, butter yellow and mint strung overhead, a festival stall with a striped awning and trays of pastries, a pier and the calm sea with lantern boats, soft warm glow.` (bỏ câu "late-afternoon sunlight", thay "warm dusk light")
