"""Ghép ảnh khung đầu 9:16 (720x1280) cho các shot image-to-video."""
import os
from PIL import Image, ImageFilter

A = r"D:\flutter_app\cupcake app\assets"
OUT = r"D:\flutter_app\cupcake app\docs\marketing\frames"
W, H = 720, 1280
os.makedirs(OUT, exist_ok=True)


def bg(path, cx=0.5):
    im = Image.open(os.path.join(A, path)).convert("RGB")
    cw = round(im.height * W / H)
    x = round((im.width - cw) * cx)
    return im.crop((x, 0, x + cw, im.height)).resize((W, H), Image.LANCZOS)


def char(path, height):
    im = Image.open(os.path.join(A, path)).convert("RGBA")
    im = im.crop(im.getbbox())
    w = round(im.width * height / im.height)
    return im.resize((w, height), Image.LANCZOS)


def put(canvas, sprite, cx, bottom):
    x = round(cx * W - sprite.width / 2)
    y = round(bottom * H - sprite.height)
    # bóng mềm dưới chân
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", (sprite.width, 40), (90, 62, 54, 90))
    sh.paste(shadow, (x, y + sprite.height - 20), shadow)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(sprite, (x, y))


def save(canvas, name):
    canvas.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print(name)


# Shot 1: cupcake trên nền kem
c = Image.new("RGBA", (W, H), (255, 244, 230, 255))
put(c, char("art/cakes/cupcakeVanilla.webp", 620), 0.5, 0.78)
save(c, "shot1_cupcake.png")

# Shot 2: thị trấn
save(bg("art/scenes/story_town.webp").convert("RGBA"), "shot2_town.png")

# Shot 3: Mai trong bếp cũ
c = bg("art/scenes/story_grandma_kitchen.webp").convert("RGBA")
put(c, char("characters/mai_neutral.webp", 900), 0.5, 0.97)
save(c, "shot3_mai_kitchen.png")

# Shot 4: ông Hòa trong tiệm
c = bg("art/shop/shop_base.webp").convert("RGBA")
put(c, char("characters/hoa_smile.webp", 900), 0.5, 0.97)
save(c, "shot4_hoa_shop.png")

# Shot 6: Linh trong tiệm
c = bg("art/shop/shop_base.webp", 0.2).convert("RGBA")
put(c, char("characters/linh_joy.webp", 900), 0.5, 0.97)
save(c, "shot6_linh.png")

# Shot 7: Mai và Kenji
c = bg("art/shop/shop_base.webp", 0.8).convert("RGBA")
put(c, char("characters/mai_smile.webp", 760), 0.3, 0.97)
put(c, char("characters/kenji_smile.webp", 800), 0.72, 0.98)
save(c, "shot7_kenji_mai.png")

# Shot 8: Mochi ngày mưa
c = bg("art/scenes/rainy_day.webp").convert("RGBA")
put(c, char("characters/mochi_sad.webp", 380), 0.5, 0.92)
save(c, "shot8_mochi_rain.png")

# Shot 9: nền kết
save(bg("art/scenes/menu_bg.webp").convert("RGBA"), "shot9_end.png")
