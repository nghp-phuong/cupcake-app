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
- `cupcakeVanilla` — `A vanilla cupcake in a pastel pink paper liner, swirl of vanilla buttercream, rainbow sprinkles and one fresh strawberry on top.`
- `cupcakeChocolate` — `A chocolate cupcake in a brown paper liner, glossy chocolate ganache swirl, chocolate chips and a red cherry on top.`
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

## Số lượng ước tính
Bánh 10 · khuôn 7 · bột 7 · đế 10 · kem 6 · topping 8 · hộp 6 · dụng cụ/lò/biểu tượng 17 · tiệm 1 + 4 + 6 · bếp 7 · màn
khác 5 · Mochi 4 ≈ **98 ảnh**. Gói miễn phí của Gemini cho khoảng 55 ảnh mỗi lượt (đặt lại sau khoảng 1 giờ), nên cần
khoảng 2 lượt.

Ghi chú khi đưa vào game: đế bánh, kem, topping là các lớp chồng lên nhau trong `CakeArt`. Trạng thái nướng chưa tới /
cháy, độ phủ kem và vị trí topping vẫn do code điều khiển. Giữ hình vẽ code làm dự phòng như với nhân vật.
