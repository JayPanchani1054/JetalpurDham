"""Generates the original artwork, sample PDF and placeholder audio used by the
demo/preview build (preview/main_preview.dart).

Nothing here is a real photograph or recording of the temple: these are
illustrations so the app can be previewed before the temple uploads its own
content. Re-run with:

    python3 preview/tool/generate_demo_media.py
"""

import math
import os
import random
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'preview', 'demo_media')
FONTS = os.path.join(ROOT, 'assets', 'fonts')

SAFFRON = (194, 65, 12)
SAFFRON_BRIGHT = (234, 122, 30)
MAROON = (140, 28, 19)
GOLD = (245, 196, 81)
WHITE = (255, 255, 255)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(size, stops):
    w, h = size
    col = np.zeros((h, 3), dtype=np.float32)
    ys = np.linspace(0, 1, h)
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        m = (ys >= p0) & (ys <= p1)
        t = ((ys[m] - p0) / max(p1 - p0, 1e-6))[:, None]
        col[m] = np.array(c0) * (1 - t) + np.array(c1) * t
    arr = np.repeat(col[:, None, :], w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), 'RGB')


def glow(img, center, radius, color, alpha=140):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = center
    d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    base = img.convert('RGBA')
    base.alpha_composite(layer)
    return base.convert('RGB')


def shikhar(d, cx, base_y, w, h, fill, flag=True):
    d.rectangle([cx - w * 0.62, base_y - h * 0.05, cx + w * 0.62, base_y], fill=fill)
    wall_top = base_y - h * 0.36
    d.rectangle([cx - w * 0.5, wall_top, cx + w * 0.5, base_y - h * 0.05], fill=fill)
    d.rectangle([cx - w * 0.56, wall_top - h * 0.035, cx + w * 0.56, wall_top], fill=fill)
    top_y = base_y - h * 0.86
    sw = w * 0.42
    pts = []
    for i in range(41):
        t = i / 40
        y = wall_top - h * 0.035 - (wall_top - h * 0.035 - top_y) * t
        x = cx - sw * (1 - t ** 1.6) * (1 - 0.15 * math.sin(math.pi * t))
        pts.append((x, y))
    pts += [(2 * cx - x, y) for (x, y) in reversed(pts)]
    d.polygon(pts, fill=fill)
    d.ellipse([cx - w * 0.09, top_y - h * 0.035, cx + w * 0.09, top_y + h * 0.015], fill=fill)
    d.ellipse([cx - w * 0.05, top_y - h * 0.09, cx + w * 0.05, top_y - h * 0.025], fill=fill)
    if flag:
        pole_top = top_y - h * 0.2
        d.rectangle([cx - w * 0.008, pole_top, cx + w * 0.008, top_y - h * 0.08], fill=fill)
        d.polygon([(cx + w * 0.008, pole_top), (cx + w * 0.2, pole_top + h * 0.035),
                   (cx + w * 0.008, pole_top + h * 0.075)], fill=SAFFRON_BRIGHT)


def temple_complex(d, cx, base_y, scale, fill):
    shikhar(d, cx, base_y, 260 * scale, 420 * scale, fill)
    shikhar(d, cx - 230 * scale, base_y, 170 * scale, 280 * scale, fill, flag=False)
    shikhar(d, cx + 230 * scale, base_y, 170 * scale, 280 * scale, fill, flag=False)
    d.rectangle([cx - 340 * scale, base_y - 60 * scale, cx + 340 * scale, base_y], fill=fill)


def tree(d, cx, base_y, size, trunk, leaves, rng):
    d.polygon([(cx - size * 0.07, base_y), (cx - size * 0.04, base_y - size * 0.55),
               (cx + size * 0.04, base_y - size * 0.55), (cx + size * 0.07, base_y)], fill=trunk)
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, size * 0.42)
        x = cx + math.cos(a) * r * 1.2
        y = base_y - size * 0.72 + math.sin(a) * r * 0.6
        rr = rng.uniform(size * 0.12, size * 0.22)
        shade = lerp(leaves, (20, 40, 15), rng.uniform(0, 0.35))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=shade)


def diya(d, x, y, s):
    d.chord([x - s, y - s * 0.6, x + s, y + s * 0.6], 0, 180, fill=(150, 60, 20))
    d.ellipse([x - s * 0.18, y - s * 1.2, x + s * 0.18, y - s * 0.1], fill=(255, 200, 80))
    d.ellipse([x - s * 0.08, y - s * 0.9, x + s * 0.08, y - s * 0.3], fill=(255, 245, 200))


def save_jpg(img, name, quality=84):
    img.save(os.path.join(OUT, name), 'JPEG', quality=quality, optimize=True, progressive=True)


def save_thumb(img, name):
    t = img.copy()
    t.thumbnail((420, 420))
    save_jpg(t, name, quality=80)


SIZE = (1280, 720)


def sunset_sky(size=SIZE, warm=True):
    if warm:
        return vgradient(size, [(0, (60, 26, 60)), (0.45, (231, 111, 50)), (0.7, (250, 190, 110)), (1, (250, 214, 150))])
    return vgradient(size, [(0, (40, 90, 160)), (0.6, (150, 200, 235)), (1, (230, 240, 245))])


def place_nij_mandir():
    img = sunset_sky()
    img = glow(img, (640, 420), 260, (255, 210, 120))
    d = ImageDraw.Draw(img)
    temple_complex(d, 640, 640, 0.95, (70, 20, 20))
    d.rectangle([0, 640, 1280, 720], fill=(120, 60, 40))
    for i in range(9):
        diya(d, 260 + i * 95, 690, 14)
    return img


def place_vachanamrut():
    img = vgradient(SIZE, [(0, (255, 236, 205)), (1, (240, 200, 150))])
    d = ImageDraw.Draw(img)
    for i in range(7):
        x = 90 + i * 183
        d.rectangle([x, 120, x + 46, 600], fill=(170, 90, 50))
        d.rectangle([x - 12, 100, x + 58, 128], fill=(130, 60, 35))
    d.rectangle([0, 80, 1280, 104], fill=(130, 60, 35))
    d.rectangle([470, 470, 810, 560], fill=MAROON)
    d.rectangle([500, 420, 780, 476], fill=(200, 60, 40))
    d.polygon([(450, 300), (640, 200), (830, 300)], fill=(200, 120, 40))
    d.rectangle([520, 380, 760, 420], fill=GOLD)
    d.rectangle([0, 600, 1280, 720], fill=(225, 210, 190))
    for i in range(0, 1280, 80):
        d.line([(i, 600), (i - 200, 720)], fill=(205, 190, 170), width=3)
    return img


def place_ordo():
    img = sunset_sky(warm=False)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 560, 1280, 720], fill=(170, 140, 100))
    d.rectangle([330, 280, 950, 600], fill=(220, 180, 130))
    d.polygon([(300, 290), (640, 150), (980, 290)], fill=(150, 70, 40))
    d.rectangle([570, 400, 710, 600], fill=(110, 50, 30))
    d.ellipse([570, 340, 710, 470], fill=(110, 50, 30))
    for x in (400, 820):
        d.rectangle([x, 380, x + 70, 460], fill=(250, 210, 120))
        d.line([(x + 35, 380), (x + 35, 460)], fill=(110, 50, 30), width=5)
    rng = random.Random(3)
    tree(d, 1120, 600, 360, (70, 45, 30), (40, 110, 50), rng)
    return img


def place_yagna():
    img = vgradient(SIZE, [(0, (30, 12, 20)), (0.6, (110, 30, 20)), (1, (60, 20, 15))])
    img = glow(img, (640, 420), 300, (255, 140, 40), alpha=170)
    d = ImageDraw.Draw(img)
    for i, w in enumerate((520, 440, 360)):
        y = 560 - i * 34
        d.rectangle([640 - w / 2, y, 640 + w / 2, y + 34], fill=(150 - i * 20, 80, 50))
    rng = random.Random(5)
    for _ in range(60):
        x = 640 + rng.gauss(0, 70)
        h = rng.uniform(90, 230)
        wdt = rng.uniform(16, 40)
        c = lerp((255, 90, 20), (255, 230, 120), rng.random())
        d.polygon([(x - wdt, 470), (x, 470 - h), (x + wdt, 470)], fill=c)
    d.rectangle([0, 600, 1280, 720], fill=(50, 20, 15))
    return img


def place_sarovar():
    img = sunset_sky()
    d = ImageDraw.Draw(img)
    temple_complex(d, 900, 420, 0.5, (80, 30, 30))
    rng = random.Random(7)
    tree(d, 200, 430, 260, (60, 40, 30), (50, 90, 40), rng)
    water = vgradient((1280, 300), [(0, (230, 140, 80)), (1, (90, 60, 90))])
    img.paste(water, (0, 420))
    d = ImageDraw.Draw(img)
    for i in range(40):
        y = 440 + i * 7
        x = rng.uniform(0, 1280)
        d.line([(x, y), (x + rng.uniform(40, 160), y)], fill=(255, 210, 150), width=2)
    for i in range(5):
        d.rectangle([0, 600 + i * 24, 1280, 612 + i * 24], fill=(200, 170, 140))
    return img


def place_tree(seed, leaves):
    img = sunset_sky(warm=False)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 560, 1280, 720], fill=(150, 170, 90))
    rng = random.Random(seed)
    tree(d, 640, 600, 620, (80, 50, 30), leaves, rng)
    d.ellipse([400, 560, 880, 640], fill=(210, 190, 160))
    d.rectangle([420, 590, 860, 620], fill=(190, 170, 140))
    return img


def place_shivling():
    img = vgradient(SIZE, [(0, (255, 240, 220)), (1, (230, 200, 160))])
    img = glow(img, (640, 380), 220, (255, 220, 150))
    d = ImageDraw.Draw(img)
    d.ellipse([440, 470, 840, 560], fill=(60, 60, 70))
    d.polygon([(840, 515), (980, 530), (840, 545)], fill=(60, 60, 70))
    d.rounded_rectangle([560, 300, 720, 520], radius=80, fill=(40, 40, 50))
    d.line([(575, 360), (705, 360)], fill=WHITE, width=6)
    d.line([(575, 380), (705, 380)], fill=WHITE, width=6)
    d.line([(575, 400), (705, 400)], fill=WHITE, width=6)
    d.ellipse([627, 368, 653, 394], fill=(200, 30, 30))
    rng = random.Random(9)
    for _ in range(14):
        x = rng.uniform(470, 810)
        y = rng.uniform(480, 520)
        d.ellipse([x - 12, y - 8, x + 12, y + 8], fill=(60, 140, 60))
    for _ in range(10):
        x = rng.uniform(470, 810)
        y = rng.uniform(470, 515)
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(250, 170, 40))
    return img


def place_vastu():
    img = vgradient(SIZE, [(0, (90, 20, 25)), (1, (40, 10, 15))])
    img = glow(img, (640, 360), 260, (255, 200, 120), alpha=90)
    d = ImageDraw.Draw(img)
    d.rectangle([360, 160, 920, 600], outline=GOLD, width=8)
    d.rectangle([380, 180, 900, 580], fill=(120, 25, 35))
    for x in (520, 700):
        d.ellipse([x - 70, 300, x + 70, 520], fill=(150, 100, 60))
        d.ellipse([x - 52, 320, x + 52, 500], fill=(110, 70, 40))
        d.ellipse([x - 22, 330, x + 22, 360], fill=GOLD)
    d.rectangle([340, 600, 940, 640], fill=(150, 110, 60))
    return img


def album_photo(i):
    rng = random.Random(100 + i)
    kind = i % 6
    if kind == 0:  # temple lit up at night
        img = vgradient((1280, 853), [(0, (10, 10, 40)), (1, (60, 30, 60))])
        d = ImageDraw.Draw(img)
        temple_complex(d, 640, 780, 0.9, (50, 20, 25))
        for k in range(160):
            a = k / 160
            x = 640 + (a - 0.5) * 900
            y = 360 + abs(a - 0.5) * 520
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 220, 120))
        img = img.filter(ImageFilter.GaussianBlur(0.6))
    elif kind == 1:  # rows of diyas
        img = vgradient((1280, 853), [(0, (30, 10, 10)), (1, (90, 30, 15))])
        d = ImageDraw.Draw(img)
        for row in range(5):
            for col in range(12):
                x = 80 + col * 103 + (row % 2) * 50
                y = 220 + row * 130
                img2 = img
                diya(d, x, y, 26 + row * 3)
        img = glow(img, (640, 500), 380, (255, 160, 60), alpha=70)
    elif kind == 2:  # rangoli mandala
        img = Image.new('RGB', (1280, 853), (250, 240, 225))
        d = ImageDraw.Draw(img)
        cx, cy = 640, 426
        palette = [SAFFRON, MAROON, GOLD, (30, 120, 120), (200, 40, 110), (60, 90, 180)]
        for ring in range(7, 0, -1):
            r = ring * 55
            n = 8 + ring * 4
            col = palette[(ring + i) % len(palette)]
            for k in range(n):
                a = 2 * math.pi * k / n
                x, y = cx + r * math.cos(a), cy + r * math.sin(a)
                d.ellipse([x - 22, y - 22, x + 22, y + 22], fill=col)
            d.ellipse([cx - r + 30, cy - r + 30, cx + r - 30, cy + r - 30], outline=palette[ring % len(palette)], width=6)
    elif kind == 3:  # toran flags across the sky
        img = sunset_sky((1280, 853), warm=False)
        d = ImageDraw.Draw(img)
        for line in range(3):
            y0 = 120 + line * 160
            for k in range(26):
                x = k * 52
                y = y0 + math.sin(k / 26 * math.pi) * 60
                col = [SAFFRON_BRIGHT, (250, 210, 40), (220, 40, 60), (40, 150, 80)][(k + line) % 4]
                d.polygon([(x, y), (x + 46, y), (x + 23, y + 56)], fill=col)
        temple_complex(d, 640, 853, 0.8, (90, 40, 40))
    elif kind == 4:  # fireworks
        img = vgradient((1280, 853), [(0, (5, 5, 25)), (1, (30, 15, 45))])
        d = ImageDraw.Draw(img)
        for b in range(5):
            cx, cy = rng.uniform(150, 1130), rng.uniform(120, 450)
            col = [GOLD, (255, 120, 60), (120, 200, 255), (255, 90, 160), (160, 255, 140)][b]
            for k in range(36):
                a = 2 * math.pi * k / 36
                r = rng.uniform(90, 160)
                d.line([(cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=col, width=3)
        temple_complex(d, 640, 853, 0.6, (25, 10, 15))
        img = img.filter(ImageFilter.GaussianBlur(0.8))
    else:  # Vijay Stambh pillar with procession flags
        img = sunset_sky((1280, 853))
        d = ImageDraw.Draw(img)
        d.rectangle([600, 120, 680, 800], fill=(230, 210, 180))
        for k in range(8):
            y = 160 + k * 80
            d.rectangle([590, y, 690, y + 14], fill=GOLD)
        d.ellipse([590, 70, 690, 150], fill=GOLD)
        for k in range(14):
            x = 60 + k * 90
            h = rng.uniform(80, 140)
            d.ellipse([x - 18, 700 - h, x + 18, 664 - h + 36], fill=(60, 30, 30))
            d.rectangle([x - 22, 700 - h + 30, x + 22, 853], fill=(60, 30, 30))
            d.polygon([(x + 18, 600 - h), (x + 70, 615 - h), (x + 18, 630 - h)], fill=SAFFRON_BRIGHT)
    return img


def banner(kind):
    if kind == 'avsar':
        img = vgradient(SIZE, [(0, (110, 20, 15)), (1, (194, 65, 12))])
        img = glow(img, (640, 360), 300, (255, 200, 100), alpha=120)
        d = ImageDraw.Draw(img)
        for k in range(48):
            a = 2 * math.pi * k / 48
            d.line([(640, 360), (640 + 900 * math.cos(a), 360 + 900 * math.sin(a))], fill=(220, 120, 40), width=6)
        d.ellipse([440, 160, 840, 560], fill=(150, 35, 20), outline=GOLD, width=10)
        f = font('Poppins-Bold.ttf', 190)
        d.text((640, 340), '200', fill=GOLD, font=f, anchor='mm')
        d.text((640, 470), 'AVSAR', fill=WHITE, font=font('Poppins-SemiBold.ttf', 54), anchor='mm')
    elif kind == 'annakut':
        img = vgradient(SIZE, [(0, (255, 225, 180)), (1, (230, 150, 70))])
        d = ImageDraw.Draw(img)
        temple_complex(d, 640, 380, 0.55, (150, 60, 30))
        rng = random.Random(11)
        cols = [(250, 200, 60), (230, 90, 40), (250, 240, 220), (120, 60, 30), (240, 150, 40), (90, 150, 60)]
        for tier in range(5):
            w = 1100 - tier * 180
            y = 690 - tier * 62
            for k in range(int(w / 70)):
                x = 640 - w / 2 + k * 70 + 35
                c = cols[rng.randrange(len(cols))]
                d.ellipse([x - 32, y - 32, x + 32, y + 18], fill=c)
    else:  # katha
        img = vgradient(SIZE, [(0, (250, 235, 210)), (1, (220, 180, 130))])
        d = ImageDraw.Draw(img)
        d.polygon([(380, 200), (640, 90), (900, 200)], fill=MAROON)
        d.rectangle([400, 200, 880, 230], fill=GOLD)
        d.rectangle([470, 380, 810, 470], fill=MAROON)
        d.rectangle([540, 330, 740, 384], fill=(250, 220, 150))
        d.line([(640, 330), (640, 384)], fill=MAROON, width=4)
        for row in range(3):
            for k in range(16):
                x = 60 + k * 76 + (row % 2) * 38
                y = 560 + row * 55
                d.ellipse([x - 20, y - 46, x + 20, y - 6], fill=(70, 40, 40))
                d.rectangle([x - 26, y - 10, x + 26, y + 40], fill=[SAFFRON, (240, 240, 240), (200, 60, 60)][k % 3])
    return img


def panorama(warm):
    w, h = 4096, 2048
    img = vgradient((w, h), [(0, (90, 140, 210)), (0.47, (250, 210, 160) if warm else (210, 230, 245)), (0.5, (240, 200, 150)), (1, (150, 120, 90))])
    d = ImageDraw.Draw(img)
    rng = random.Random(21 if warm else 22)
    for k in range(6):
        cx = (k + 0.5) * w / 6
        if k % 2 == 0:
            temple_complex(d, cx, h * 0.52, 0.55, (150, 70, 45))
        else:
            tree(d, cx, h * 0.52, 420, (80, 50, 30), (50, 110, 50), rng)
    for k in range(0, w, 128):
        d.line([(k, h * 0.52), (k + (k - w / 2) * 0.8, h)], fill=(200, 175, 150), width=4)
    return img


def sample_pdf():
    pages = []
    title_gu = font('HindVadodara-Bold.ttf', 64)
    body_en = font('Poppins-Regular.ttf', 30)
    head_en = font('Poppins-SemiBold.ttf', 40)
    for n in range(1, 7):
        page = Image.new('RGB', (1240, 1754), (255, 251, 242))
        d = ImageDraw.Draw(page)
        d.rectangle([60, 60, 1180, 1694], outline=SAFFRON, width=6)
        d.rectangle([80, 80, 1160, 1674], outline=GOLD, width=2)
        d.text((620, 230), 'શ્રી સ્વામિનારાયણો વિજયતે', fill=MAROON, font=title_gu, anchor='mm')
        d.text((620, 340), f'Sample page {n} of 6', fill=SAFFRON, font=head_en, anchor='mm')
        lines = [
            'This is a sample PDF used only for the app preview.',
            'The temple uploads the real scriptures (Vachanamrut,',
            'Shikshapatri, Satsangi Jivan, Bhaktachintamani, ...)',
            'to Firebase Storage, and they appear in the Shastra',
            'library automatically.',
            '',
            'Try the reader: pinch to zoom, swipe between pages,',
            'tap the page number to jump to a page, and download',
            'the book to read it offline. The app remembers the',
            'page where you stopped.',
        ]
        y = 500
        for line in lines:
            d.text((140, y), line, fill=(40, 30, 20), font=body_en)
            y += 56
        d.text((620, 1600), f'— {n} —', fill=MAROON, font=head_en, anchor='mm')
        pages.append(page.resize((868, 1228), Image.LANCZOS))
    pages[0].save(os.path.join(OUT, 'sample_shastra.pdf'), save_all=True, append_images=pages[1:],
                  resolution=105, quality=80)


def tanpura(name, sa_hz, seconds=40, rate=22050):
    t = np.linspace(0, seconds, int(seconds * rate), endpoint=False)
    pa = sa_hz * 1.5
    sig = np.zeros_like(t)
    # Four strings plucked in the classic Pa–Sa–Sa–Sa(low) cycle, rich in harmonics.
    cycle = [(pa / 2, 0.0), (sa_hz, 0.6), (sa_hz, 1.2), (sa_hz / 2, 1.8)]
    period = 2.4
    for start in np.arange(0, seconds, period):
        for f0, off in cycle:
            t0 = start + off
            m = t >= t0
            tt = t[m] - t0
            env = np.exp(-tt / 2.2)
            tone = sum((0.6 / k) * np.sin(2 * np.pi * f0 * k * tt + k) for k in range(1, 9))
            sig[m] += env * tone
    sig += 0.08 * np.sin(2 * np.pi * sa_hz / 2 * t)
    fade = np.minimum(1, np.minimum(t / 2, (seconds - t) / 2))
    sig = sig * fade
    sig = sig / np.max(np.abs(sig)) * 0.6
    pcm = (sig * 32767).astype(np.int16)
    wav = os.path.join(OUT, name + '.wav')
    import wave
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '64k',
                    os.path.join(OUT, name + '.mp3')], check=True)
    os.remove(wav)


def main():
    os.makedirs(OUT, exist_ok=True)
    places = {
        'nij-mandir-revati-baldevji': place_nij_mandir(),
        'vachanamrut-sthan': place_vachanamrut(),
        'gangama-no-ordo': place_ordo(),
        'yagnashala-yagnabhumi': place_yagna(),
        'dev-sarovar': place_sarovar(),
        'prasadi-ni-borsali': place_tree(31, (40, 110, 50)),
        'prasadi-ni-amli': place_tree(37, (70, 120, 40)),
        'prasadi-nu-shivling': place_shivling(),
        'prasadi-vastu': place_vastu(),
    }
    for pid, img in places.items():
        save_jpg(img, f'place_{pid}.jpg')
    for i in range(12):
        img = album_photo(i)
        if i >= 6:
            # Second half: mirrored, warmer variations so no two photos repeat.
            img = ImageOps.mirror(img)
            tint = Image.new('RGB', img.size, (255, 170, 80))
            img = Image.blend(img, tint, 0.12)
        save_jpg(img, f'avsar_{i + 1:02d}.jpg')
        save_thumb(img, f'avsar_{i + 1:02d}_thumb.jpg')
    for kind in ('avsar', 'annakut', 'katha'):
        save_jpg(banner(kind), f'banner_{kind}.jpg')
    save_jpg(panorama(True), 'pano_nij_mandir.jpg', quality=80)
    save_jpg(panorama(False), 'pano_dev_sarovar.jpg', quality=80)
    sample_pdf()
    tanpura('tanpura_sa_c_sharp', 138.59)
    tanpura('tanpura_sa_d', 146.83)
    print('demo media written to', OUT)


if __name__ == '__main__':
    sys.exit(main())
