# Prompt tạo ảnh nhân vật (Gemini)

Dùng trong Gemini (gemini.google.com, chế độ tạo ảnh). Mỗi nhân vật một cuộc trò chuyện riêng:
1. Gửi **STYLE + mô tả nhân vật** → ảnh gốc "bình thường" (`neutral`).
2. Trong cùng cuộc trò chuyện, gửi lần lượt 3 câu sửa nét mặt → `smile`, `joy`, `sad`.

Không ghi tên hãng phim hay hoạ sĩ nào trong prompt: phong cách "phim hoạt hình vẽ tay ấm áp" được mô tả bằng đặc điểm
(quy tắc dự án, và để ảnh là thiết kế nguyên bản). Nền trắng trơn để tách nền tự động.

## STYLE (dán trước mỗi mô tả nhân vật)

```
Full-body character illustration for a cozy 2D bakery game. Hand-painted anime film look: soft gouache and watercolor
textures, gentle warm-brown hand-drawn linework, muted warm palette (cream, strawberry pink, mint, butter yellow,
caramel), soft warm afternoon light, nostalgic and heartwarming mood. Natural proportions about 6.5 heads tall,
standing and facing the viewer in a relaxed pose, the whole body from head to shoes visible with a small margin.
Simple gentle face: small dark eyes, soft rosy cheeks, small mouth. Plain solid pure white background, no floor
shadow, no scenery, no text, no watermark, no border. Exactly one character. Portrait 3:4 image.
```

## Câu sửa nét mặt (gửi sau ảnh gốc, cùng cuộc trò chuyện)

- smile: `Same character, keep the outfit, hair, accessories, pose, framing, size and white background exactly identical. Change only the face to a gentle warm closed-mouth smile.`
- joy: `Same character, keep everything else exactly identical. Change only the face to a delighted expression: eyes closed in happy upward arcs, open smiling mouth, slightly brighter blush.`
- sad: `Same character, keep everything else exactly identical. Change only the face to a sad expression: eyebrows tilted down at the outer ends, small downturned mouth, eyes glancing slightly down.`

## Nhân vật

Tên file: `assets/characters/<id>_<neutral|smile|joy|sad>.png`.

### Dàn chính
- **mai** — `A cheerful young woman in her mid-20s who runs a seaside bakery. Warm brown hair in a soft low ponytail with a few loose strands and a small leaf-shaped hair clip, a strawberry-pink bandana. Cream-white blouse with rolled sleeves under a butter-yellow apron with a small pocket, light beige trousers, white canvas shoes. Tiny gold stud earrings, a slim brown leather watch, a little smudge of flour on her nose. She holds a strawberry cupcake in both hands at chest height.`
- **hoa** — `A kind elderly Vietnamese gentleman around 70. Thin silver hair, neat white mustache, round gold-rimmed glasses, a brown wool beret. Cream shirt with a dark red bow tie under a sage-green knitted vest, brown trousers, polished brown shoes, a pocket-watch chain on the vest. He leans lightly on a wooden walking cane.`
- **linh** — `A playful young woman around 20. Black hair in two high space buns with a strawberry clip and a yellow star clip. Oversized lavender hoodie, pleated white skirt, chunky pastel sneakers. Small pink heart earrings, a pink digital watch, a little white bunny-shaped backpack on her shoulders.`
- **kenji** — `A relaxed young man around 25, a travel photographer. Messy black hair touching the nape, light stubble, square black glasses, a beige bucket hat. Olive field jacket over an off-white tee, dark straight jeans, worn canvas shoes. A small silver hoop earring on one ear, a dark digital watch. He holds a vintage film camera at waist height.`

### Khách thường (`regular_00` … `regular_14`)
- **regular_00** — `A young woman around 19 with a chin-length bob dyed with pastel pink tips, a pastel knitted beanie, a soft mint hoodie, light jeans, white sneakers, small heart earrings, white headphones around her neck.`
- **regular_01** — `A young woman around 18 with a high ponytail tied with a big pastel bow, freckles, a light denim overall dress over a pastel striped tee, white socks and sneakers, a pastel digital watch, a small backpack.`
- **regular_02** — `A young woman around 22 with long wavy brown hair fading to honey ombre ends, a pastel crop top under a long cream cardigan, high-waisted light jeans, gold hoop earrings, a thin pendant necklace, a small star hair clip.`
- **regular_03** — `A young woman around 21 with a short pixie cut, round tortoiseshell glasses, an oversized cream tee with a cute cupcake print, wide-leg jeans, a small silver stud earring, a star hair clip, a canvas tote bag.`
- **regular_04** — `A young woman around 20 with two low braids, a pastel bucket hat, a light denim jacket over a pastel top, a long flowy skirt, strawberry hair clip, small drop earrings, light freckles.`
- **regular_05** — `A young man around 20 with short tousled hair, a pastel baseball cap, a white graphic tee with a small sun print, khaki shorts, sneakers, a leather watch, headphones around his neck.`
- **regular_06** — `A young man around 22 with side-swept hair dyed with a teal streak, a soft grey hoodie, black jeans, a silver hoop earring on one ear, a thin chain necklace.`
- **regular_07** — `A young man around 23 with short curly hair, square brown glasses, a navy-and-cream striped tee, beige chinos, a leather watch, a small canvas backpack, light freckles.`
- **regular_08** — `A young woman around 24 with long straight dark hair, a pastel beret, a cream-and-pink striped Breton top, a midi skirt, small drop earrings, a thin pendant necklace, a bow hair clip.`
- **regular_09** — `A gentle woman in her early 50s with dark hair in a neat low bun, gold reading glasses on a chain, a dusty-rose knitted cardigan over a cream blouse, a long skirt, pearl earrings, a small brooch, a gold watch, soft smile lines.`
- **regular_10** — `A warm woman in her mid-50s with short permed salt-and-pepper hair, round burgundy glasses, a mustard turtleneck sweater, wide trousers, small drop earrings, a soft knitted scarf.`
- **regular_11** — `An elegant woman in her late 40s with a neat chin-length bob, a wide-brimmed straw sun hat, a cream silk blouse with a rose silk neck scarf, light linen trousers, gold stud earrings, a single strand of pearls.`
- **regular_12** — `A tidy man in his early 50s with neatly side-parted dark hair touched with grey, square glasses, a navy blazer over a white shirt with a burgundy tie, grey trousers, a metal watch, a neat mustache.`
- **regular_13** — `A friendly man in his late 50s with short salt-and-pepper hair, a navy beret, a cream Fair Isle patterned sweater, brown corduroy trousers, a leather watch, a knitted scarf, a small mustache.`
- **regular_14** — `A calm man in his early 50s with a full short beard, thin gold-rimmed glasses, a charcoal turtleneck, a camel overcoat open over it, dark trousers, a metal watch, soft smile lines.`

### Khách VIP (`vip_00` … `vip_02`)
- **vip_00** — `A graceful wealthy lady in her late 50s (Madame Rosa), silver-streaked hair in an elegant high updo, a deep plum velvet blazer over a cream blouse, a double strand of pearls, pearl earrings, a gold brooch, a gold watch, a long elegant skirt.`
- **vip_01** — `A distinguished gentleman in his 50s, dark hair slicked back with grey at the temples, thin gold-rimmed glasses, a deep emerald velvet blazer, white shirt, a gold lapel pin, a gold watch, a neat mustache.`
- **vip_02** — `A refined young lady around 24, long wavy chestnut hair, a wide cream sun hat decorated with small flowers, a burgundy short cape over a cream dress, pearl earrings, delicate gloves.`

### Làm lại vì đầu to (vip_01, regular_12)
Chủ dự án thấy hai nhân vật này đầu to hơn người, lệch tỉ lệ với các khách khác. Khi làm lại, thay câu tỉ lệ trong
khối STYLE (`Natural proportions about 6.5 heads tall, standing and facing…`) bằng:

`Realistic adult proportions about 7.5 heads tall: a SMALL head in natural proportion to the body, narrow face, long legs, normal adult shoulders; the head must never look oversized or chibi. Standing and facing the viewer in a relaxed pose, the whole body from head to shoes visible with a small margin, the figure filling most of the image height.`

Phần mô tả nhân vật thêm "tall" và giày:
- **vip_01** — `A distinguished tall gentleman in his 50s, dark hair slicked back with grey at the temples, thin gold-rimmed glasses, a deep emerald velvet blazer, white shirt, a gold lapel pin, a gold watch, a neat mustache, dark trousers, polished brown shoes.`
- **regular_12** — `A tidy tall man in his early 50s with neatly side-parted dark hair touched with grey, square glasses, a navy blazer over a white shirt with a burgundy tie, grey trousers, a metal watch, a neat mustache, brown leather shoes.`

### Nhân viên (V2 · GĐ4) — `staff_<id>_<neutral|smile>`
STYLE với câu tỉ lệ 7.5 đầu (mục "Làm lại vì đầu to"). Cả 5 người tạo trong **một** cuộc trò chuyện để đồng bộ: người
đầu dùng STYLE đầy đủ; người sau mở đầu bằng `Create a new image of a completely different character, in exactly the same
art style, proportions (about 7.5 heads tall, small head, never chibi), framing, size, lighting and plain pure white
background as the first image.` Nét `smile`: `Same character as the previous image (the <vai trò>), keep the outfit, hair,
<đồ cầm>, pose, framing, size and white background exactly identical. Change only the face to a delighted warm smile: eyes
gently curved, small open smiling mouth, slightly rosy cheeks.`
- **staff_nora** (thu ngân) — `A friendly young woman around 22 who works as the cashier of a small seaside bakery. Short wavy auburn bob with a mint-green hair clip, light freckles. Cream-and-pink striped shirt with rolled sleeves under a mint-green apron with a small blank name badge (no letters), light beige trousers, brown loafers, a thin silver bracelet. She holds a small paper pastry bag with both hands at waist height.`
- **staff_bao** (thợ bánh) — `A gentle tall young man around 27 who is the baker of a small seaside bakery. Short neat dark brown hair under a small white baker's cap, kind eyes, clean-shaven. White baker's jacket with sleeves rolled to the elbows, a caramel-brown apron with a little flour dusted on it, dark grey trousers, brown work shoes, a small towel tucked in the apron string. He holds a wooden rolling pin in both hands at waist height.`
- **staff_theo** (phục vụ) — `A cheerful slim young man around 20 who works as the waiter of a small seaside bakery café. Short curly light-brown hair, a few freckles. White shirt with a small strawberry-pink bow tie under a butter-yellow waistcoat, a short cream waist apron, dark beige trousers, brown sneakers. He carries a round wooden serving tray with one cup of tea on his right hand at shoulder height, left hand relaxed.`
- **staff_ami** (thợ bánh 2) — `A focused, kind young woman around 25 who is the second baker of a small seaside bakery. Black hair in a neat high bun held with a wooden pencil, short side bangs. Cream short-sleeved blouse under a strawberry-pink apron, a pair of quilted mint oven mitts hanging from the apron pocket, navy trousers rolled at the ankle, white clogs. She holds a small wooden tray with three round fresh buns in both hands at waist height.`
- **staff_hanh** (quản lý) — `A warm, capable Vietnamese woman in her mid-40s who is the manager of a small seaside bakery. Dark hair with a few silver strands in a neat low bun, thin round tortoiseshell glasses, small pearl earrings. A sage-green knitted cardigan over a cream blouse, a long caramel-brown pleated skirt, comfortable brown low-heeled shoes, a slim gold watch. She holds a wooden clipboard against her chest with one arm and a pencil in the other hand.`

Tách nền: vùng trắng từ mép + vùng trắng tinh khép kín lớn (> 900 px, ngưỡng 244) để bỏ khe tay; đặt vào khung 768×1024
rồi thu về 480×640 như các nhân vật khác.
