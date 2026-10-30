"""Video kể chuyện 15s 9:16 "Cuốn sổ của bà" (vi / en): clip Veo, lời Mai, nhạc piano chậm.

Chạy: python tool/marketing/make_story.py [vi] [en]
Cần imageio-ffmpeg; nếu thiếu: python -m pip install --target tool/marketing/.pylib imageio-ffmpeg
Cảnh 4 dùng clips/story4_mai_baking_veo.mp4 nếu có (giây bắt đầu: biến môi trường BAKE_START, mặc định 4.0),
không có thì dùng tạm clip cupcake.
"""
import math
import os
import subprocess
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".pylib"))
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = r"D:\flutter_app\cupcake app"
MK = os.path.join(ROOT, r"docs\marketing")
CLIPS = os.path.join(MK, "clips")
FRAMES = os.path.join(MK, "frames")
ASSETS = os.path.join(ROOT, "assets")
FONTS = os.path.join(ROOT, r"tool\screens\fonts")
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS, SR = 1080, 1920, 30, 48000
CREAM = (255, 244, 230)
INK = (90, 62, 54)
TOTAL = 15.0
XF = 0.4  # chồng mờ giữa hai cảnh

LINES = {
    "vi": ["Bà để lại cho mình\ncuốn sổ công thức này.",
           "Nhiều trang còn bỏ trống…\nnhưng mình không vội.",
           "Ông Hòa mang đến một trang\nbà gửi lại năm xưa.",
           "Mình làm lại chiếc bánh ấy,\ntheo nét chữ của bà.",
           "Từ hôm nay,\nmình sẽ viết tiếp."],
    "en": ["Grandma left me\nthis recipe book.",
           "Many pages are still blank…\nbut I'm in no hurry.",
           "Mr. Hoa brought a page\nGrandma left with him long ago.",
           "I baked it again,\nfollowing her handwriting.",
           "From today,\nI'll write the next page."],
}
# (loại, nguồn, giây bắt đầu trong nguồn, bắt đầu, kết thúc)
SEG = [("clip", "shot2_mai_veo.mp4", 0.4, 0.0, 3.5),
       ("clip", "shot2_mai_veo.mp4", 4.6, 3.5, 6.5),
       ("clip", "story3_hoa_page_veo.mp4", 2.0, 6.5, 9.5),
       ("clip", "story4_mai_baking_veo.mp4", float(os.environ.get("BAKE_START", "4.0")), 9.5, 12.5)
       if os.path.exists(os.path.join(CLIPS, "story4_mai_baking_veo.mp4"))
       else ("clip", "shot1_cupcake_veo.mp4", 0.3, 9.5, 12.5),
       ("clip", "story5_mai_evening_veo.mp4", float(os.environ.get("EVE_START", "3.6")), 12.5, 15.0)]

# Bản Seedance (mặc định khi đủ clip clips/story_s1_sd.mp4 … s5): cùng nét vẽ với phần mở đầu "về quê".
# Đặt VEO=1 để dùng lại các clip Veo ở trên.
SD = [("story_s1_sd.mp4", 1.5), ("story_s2_sd.mp4", 2.0), ("story_s3_sd.mp4", 1.5), ("story_s4_sd.mp4", 2.0),
      ("story_s5_sd.mp4", 0.2)]
if os.environ.get("VEO") != "1" and all(os.path.exists(os.path.join(CLIPS, f)) for f, _ in SD):
    SEG = [("clip", f, s0, a, b) for (f, s0), (_, _, _, a, b) in zip(SD, SEG)]

# Bản dài (STORY=25): thêm phần mở đầu "về quê" — văn phòng Hà Nội, xe khách, gác mái nhà bà.
# Mỗi cảnh dùng clip clips/story_nX.mp4 nếu đã có, chưa có thì dùng ảnh frames/story_nX_*.png chuyển động máy quay.
LONG = os.environ.get("STORY") == "25"
INTRO = [("n1", "story_n1_office.png", 3.5), ("n2", "story_n2_bus.png", 3.0), ("n3", "story_n3_attic.png", 3.5)]
OFF = sum(d for *_, d in INTRO) if LONG else 0.0
if LONG:
    LINES["vi"] = ["Ở Hà Nội,\nngày nào cũng là deadline.",
                   "Một ngày, mình xin nghỉ…\nvà về quê.",
                   "Dọn gác mái nhà bà,\nmình tìm thấy…",
                   "…cuốn sổ công thức\nbà viết tay."] + LINES["vi"][1:]
    LINES["en"] = ["In Hanoi,\nevery day was a deadline.",
                   "One day, I took a break…\nand went home.",
                   "Clearing Grandma's attic,\nI found…",
                   "…her handwritten\nrecipe book."] + LINES["en"][1:]
    intro, t = [], 0.0
    for key, img, d in INTRO:
        clip = f"story_{key}.mp4"
        intro.append(("clip", clip, float(os.environ.get(f"{key.upper()}_START", "0.5")), t, t + d)
                     if os.path.exists(os.path.join(CLIPS, clip)) else ("image", img, 0, t, t + d))
        t += d
    SEG = intro + [(k, s, s0, a + OFF, b + OFF) for k, s, s0, a, b in SEG]
    TOTAL += OFF


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def crop916(img):
    img = img.convert("RGB")
    cw = round(img.height * W / H)
    x = (img.width - cw) // 2
    return img.crop((x, 0, x + cw, img.height)).resize((W, H), Image.LANCZOS)


def sprite(path, height):
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    return im.resize((round(im.width * height / im.height), height), Image.LANCZOS)


def put(canvas, spr, cx, bottom):
    canvas.alpha_composite(spr, (round(cx * W - spr.width / 2), round(bottom - spr.height)))


def paper(w, h, angle, open_book=False):
    """Trang giấy cũ vẽ tay (hoặc cuốn sổ mở) để đặt vào cảnh tĩnh."""
    pad = 20
    im = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if open_book:
        d.rounded_rectangle((pad - 10, pad - 10, pad + w + 10, pad + h + 10), 14, fill=(122, 78, 52, 255))
        for x0 in (pad, pad + w // 2 + 4):
            d.rounded_rectangle((x0, pad, x0 + w // 2 - 4, pad + h), 8, fill=(250, 238, 214, 255),
                                outline=(150, 110, 80, 255), width=3)
        for i in range(6):  # dòng chữ mờ trang trái, trang phải còn trống
            y = pad + 26 + i * (h - 50) // 6
            d.line((pad + 16, y, pad + w // 2 - 20, y), fill=(170, 130, 100, 150), width=3)
        d.line((pad + w // 2, pad, pad + w // 2, pad + h), fill=(150, 110, 80, 255), width=4)
    else:
        d.rectangle((pad, pad, pad + w, pad + h), fill=(246, 230, 196, 255), outline=(160, 120, 85, 255), width=3)
        for i in range(7):
            y = pad + 22 + i * (h - 40) // 7
            d.line((pad + 14, y, pad + w - 14 - (i % 3) * 20, y), fill=(160, 115, 85, 170), width=3)
    im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow.paste((90, 62, 54, 90), mask=im.split()[3])
    out = Image.new("RGBA", (im.width + 20, im.height + 20), (0, 0, 0, 0))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)), (10, 14))
    out.alpha_composite(im, (0, 0))
    return out


def build_story3():
    c = crop916(Image.open(os.path.join(ASSETS, r"art\shop\shop_base.webp"))).convert("RGBA")
    put(c, sprite(os.path.join(ASSETS, r"characters\hoa_smile.webp"), 900), 0.29, 1760)
    put(c, sprite(os.path.join(ASSETS, r"characters\mai_smile.webp"), 860), 0.73, 1760)
    pg = paper(150, 190, 8)
    c.alpha_composite(pg, (W // 2 - pg.width // 2, 1180))
    return c.convert("RGB")


def build_story5():
    base = crop916(Image.open(os.path.join(ASSETS, r"art\scenes\story_grandma_kitchen.webp")))
    # buổi tối: tối và ngả tím ở rìa, quầng đèn vàng cam ấm ở giữa
    arr = np.asarray(base, dtype=np.float32) / 255
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H * 0.55) / (H * 0.5)) ** 2)
    lamp = np.clip(1.15 - r, 0, 1)[..., None]
    dark = arr * np.array([0.55, 0.5, 0.62])
    warm = np.clip(arr * np.array([1.08, 0.92, 0.72]) + np.array([0.06, 0.03, 0]), 0, 1)
    c = Image.fromarray((np.clip(dark * (1 - lamp) + warm * lamp, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    put(c, sprite(os.path.join(ASSETS, r"characters\mai_joy.webp"), 980), 0.5, 1760)
    return c.convert("RGB")


def kenburns(img, t, z1=1.08, focus=(0.5, 0.55)):
    z = 1 + (z1 - 1) * t
    cw, ch = W / z, H / z
    x0 = min(max(focus[0] * W - cw / 2, 0), W - cw)
    y0 = min(max(focus[1] * H - ch / 2, 0), H - ch)
    return img.crop((x0, y0, x0 + cw, y0 + ch)).resize((W, H), Image.LANCZOS)


def diary(img, text, alpha):
    """Phụ đề kiểu nhật ký: khung kem mờ bo tròn, chữ nâu."""
    if alpha <= 0:
        return img
    f = font("Nunito-w700.ttf", 54)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    b = d.multiline_textbbox((0, 0), text, font=f, align="center", spacing=14)
    tw, th = b[2] - b[0], b[3] - b[1]
    cx, cy = W / 2, 1470
    a = int(255 * alpha)
    d.rounded_rectangle((cx - tw / 2 - 46, cy - th / 2 - 34, cx + tw / 2 + 46, cy + th / 2 + 34), 34,
                        fill=(255, 248, 238, int(a * 0.86)))
    d.multiline_text((cx - tw / 2 - b[0], cy - th / 2 - b[1]), text, font=f, fill=INK + (a,), align="center",
                     spacing=14)
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


TITLE = {  # Fredoka không có dấu tiếng Việt (ệ) nên dòng tiếng Việt dùng Nunito
    "vi": [("Tiệm bánh", "Nunito-w900.ttf", 66, 1420, (185, 128, 90)),
           ("Sugarleaf", "Fredoka-w600.ttf", 120, 1530, (244, 154, 176))],
    "en": [("Sugarleaf", "Fredoka-w600.ttf", 120, 1440, (244, 154, 176)),
           ("Bakery", "Fredoka-w600.ttf", 76, 1550, (185, 128, 90))],
}


def title(img, alpha, lang):
    if alpha <= 0:
        return img
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a = int(255 * alpha)
    for txt, fname, size, cy, col in TITLE[lang]:
        f = font(fname, size)
        b = d.textbbox((0, 0), txt, font=f, stroke_width=10)
        x, y = (W - (b[2] - b[0])) / 2 - b[0], cy - (b[3] - b[1]) / 2 - b[1]
        d.text((x, y), txt, font=f, fill=col + (a,), stroke_width=10, stroke_fill=CREAM + (a,))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def render_video(lang, out_path):
    clips = {}
    for kind, src, *_ in SEG:
        if kind == "clip" and src not in clips:
            g = imageio_ffmpeg.read_frames(os.path.join(CLIPS, src))
            m = next(g)
            clips[src] = ([Image.frombytes("RGB", m["size"], f) for f in g], m["fps"])
    stills = {"story3": build_story3(), "story5": build_story5()} if any(s[0] == "still" for s in SEG) else {}
    for kind, src, *_ in SEG:
        if kind == "image":
            stills[src] = crop916(Image.open(os.path.join(FRAMES, src)))

    def seg_frame(i, t):
        kind, src, s0, s, e = SEG[i]
        lt = t - s
        if kind == "clip":
            frames, fps = clips[src]
            img = frames[min(int((s0 + lt) * fps), len(frames) - 1)].resize((W, H), Image.LANCZOS)
        else:
            img = kenburns(stills[src], lt / (e - s))
        a = smooth(lt / 0.5) * smooth((e - s - lt) / 0.35 + (1 if i == len(SEG) - 1 else 0))
        img = diary(img, LINES[lang][i], a if i < len(SEG) - 1 else smooth(lt / 0.5) * smooth((1.5 - lt) / 0.25))
        if i == len(SEG) - 1:
            img = title(img, smooth((lt - 1.55) / 0.5), lang)
        return img

    w = imageio_ffmpeg.write_frames(out_path, (W, H), fps=FPS, codec="libx264", pix_fmt_out="yuv420p",
                                    quality=8, macro_block_size=8)
    w.send(None)
    for n in range(round(TOTAL * FPS)):
        t = n / FPS
        i = max(k for k in range(len(SEG)) if SEG[k][3] <= t)
        img = seg_frame(i, t)
        if i > 0 and t - SEG[i][3] < XF:  # chồng mờ với cảnh trước
            prev = seg_frame(i - 1, t)
            img = Image.blend(prev, img, smooth((t - SEG[i][3]) / XF))
        if t < 0.5:
            img = Image.blend(Image.new("RGB", (W, H), CREAM), img, smooth(t / 0.5))
        w.send(np.asarray(img, dtype=np.uint8).tobytes())
    w.close()


# ---------- âm thanh ----------
def read_audio(name, start, dur):
    tmp = os.path.join(HERE, "_a.wav")
    r = subprocess.run([FF, "-y", "-loglevel", "error", "-ss", str(start), "-t", str(dur), "-i",
                        os.path.join(CLIPS, name), "-vn", "-ac", "2", "-ar", str(SR), "-f", "wav", tmp])
    if r.returncode != 0:  # clip không có tiếng (vd. Seedance 1.0 Fast)
        return np.zeros((int(dur * SR), 2), np.float32)
    with wave.open(tmp) as f:
        a = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    os.remove(tmp)
    return a.reshape(-1, 2)


def tone(freq, dur, amp, decay):
    t = np.arange(int(dur * SR)) / SR
    env = np.exp(-t * decay) * np.minimum(1, t * 80)
    w = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t) + 0.08 * np.sin(6 * np.pi * freq * t)
    return (w * env * amp).astype(np.float32)


def add(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[: j - i, None] if sig.ndim == 1 else sig[: j - i]


def render_audio(path):
    """Piano chậm 66 BPM: F–C–Dm–Bb rải nốt, giai điệu thưa."""
    buf = np.zeros((int(TOTAL * SR), 2), np.float32)
    beat = 60 / 66
    chords = [[174.61, 220.0, 261.63], [130.81, 164.81, 196.0], [146.83, 174.61, 220.0], [116.54, 146.83, 174.61]]
    mel = [523.25, 440.0, 392.0, 440.0, 349.23, 392.0, 440.0, 523.25]
    t, k = 0.0, 0
    while t < TOTAL:
        ch = chords[(k // 4) % 4]
        if k % 4 == 0:
            add(buf, tone(ch[0] / 2, 3.0, 0.11, 1.0), t)
        add(buf, tone(ch[k % 3] * 2, 1.8, 0.045, 1.8), t)
        if k % 2 == 1:
            add(buf, tone(mel[(k // 2) % len(mel)] * 2, 1.6, 0.03, 2.2), t + beat * 0.02)
        t += beat
        k += 1
    for key in range(len(SEG)):
        kind, src, s0, s, e = SEG[key]
        if kind == "clip":
            a = read_audio(src, s0, e - s)
            fade = np.minimum(1, np.minimum(np.arange(len(a)), np.arange(len(a))[::-1]) / (0.3 * SR))
            add(buf, a * fade[:, None] * 0.45, s)
    add(buf, tone(1567.98, 1.4, 0.07, 3), OFF + 6.6)  # chuông cửa khi ông Hòa ghé
    add(buf, tone(2093.0, 1.2, 0.035, 3.5), OFF + 6.68)
    for i in range(5):  # lấp lánh nhẹ khi hiện tên tiệm
        add(buf, tone(1318.5 * (1.12 ** i), 1.0, 0.03, 4), OFF + 13.7 + i * 0.09)
    if LONG:  # đoạn Hà Nội: nhạc gần như im, chỉ có tiếng mưa; nhạc lên dần khi Mai về quê
        n1 = INTRO[0][2]
        env = np.interp(np.arange(len(buf)) / SR, [0, n1 - 0.3, n1 + 1.2, TOTAL - 1.2, TOTAL], [0.12, 0.12, 1, 1, 0])
        rng = np.random.default_rng(7)
        rain = np.convolve(rng.standard_normal(int((n1 + 0.6) * SR)), np.ones(12) / 12, "same").astype(np.float32)
        rain *= np.interp(np.arange(len(rain)) / SR, [0, 0.6, n1 - 0.3, n1 + 0.6], [0, 1, 1, 0]).astype(np.float32)
        buf *= env[:, None]
        add(buf, rain * 0.05, 0)
    else:
        env = np.interp(np.arange(len(buf)) / SR, [0, 0.8, TOTAL - 1.2, TOTAL], [0, 1, 1, 0])
        buf *= env[:, None]
    buf = buf / max(1e-6, np.abs(buf).max()) * 0.8
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((buf * 32767).astype(np.int16).tobytes())


def main():
    wav = os.path.join(HERE, "_story_audio.wav")
    render_audio(wav)
    for lang in sys.argv[1:] or ["vi", "en"]:
        vid = os.path.join(HERE, f"_story_{lang}.mp4")
        render_video(lang, vid)
        out = os.path.join(MK, f"sugarleaf_story_{round(TOTAL)}s_{lang}.mp4")
        subprocess.run([FF, "-y", "-loglevel", "error", "-i", vid, "-i", wav, "-c:v", "copy",
                        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", str(SR), "-c:a", "aac", "-b:a", "192k",
                        "-shortest", "-movflags", "+faststart", out], check=True)
        os.remove(vid)
        print(out)
    os.remove(wav)


if __name__ == "__main__":
    main()
