"""Builds the store and badge icons that have no hand-cut art yet, from the game's own UI sprites
(art/atlas, rectangles in src/shared/UIAtlasRects.lua): a sprite centred on a glowing disc in the item's
colour, 512 x 512 on transparent, in the same sticker style as art/products/*.png.

    python3 tools/ids/icons.py      # writes art/products/<Key>.png (missing ones only) and art/badges/<Key>.png

Never overwrites an existing art/products file (those are hand-cut); badge icons are always rebuilt.
"""
import math
import os
import re

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ATLAS = os.path.join(ROOT, "art", "atlas")
RECTS = os.path.join(ROOT, "src", "shared", "UIAtlasRects.lua")
FILES = {"icons": "anime_clash_icons.png", "more": "anime_clash_more.png", "frames": "anime_clash_frames.png"}
SIZE = 512

RAINBOW = "rainbow"
# Store items without art: key -> (sprite, colour, extra)
PRODUCTS = {
    "Floor2": ("base", (255, 200, 60), "stack"),
    "BeamKamehameha": ("smash_charged", (60, 180, 255), None),
    "BeamHellfire": ("smash_charged", (230, 40, 10), None),
    "BeamChidori": ("smash_charged", (130, 120, 255), None),
    "BeamCursed": ("smash_charged", (150, 40, 200), None),
    "BeamGoldenGod": ("smash_charged", (255, 205, 40), None),
    "BeamPrism": ("smash_charged", RAINBOW, None),
    "MarketT1": ("shop", (176, 92, 255), None),
    "MarketT2": ("shop", (255, 196, 40), None),
    "MarketT3": ("shop", (255, 130, 40), None),
    "MarketT4": ("shop", (255, 56, 72), None),
    "MarketT5": ("shop", RAINBOW, None),
}
# Badges (Config.Badges): key -> (sprite, colour)
BADGES = {
    "Welcome": ("hub", (110, 200, 255)),
    "FirstWin": ("vs", (255, 120, 60)),
    "Blossom": ("blossom", (255, 150, 200)),
    "Ninja": ("ninja", (255, 150, 40)),
    "Pirate": ("pirate", (60, 160, 255)),
    "Walled": ("walled", (170, 120, 80)),
    "FirstSecret": ("god", RAINBOW),
    "FirstSteal": ("fast_steal", (255, 70, 90)),
    "Rebirth": ("rebirth", (255, 205, 40)),
    "FullBase": ("base", (90, 220, 120)),
}


def rects():
    out = {}
    for m in re.finditer(r'(\w+) = \{ "(\w+)", (\d+), (\d+), (\d+), (\d+)', open(RECTS).read()):
        out[m.group(1)] = (m.group(2), *map(int, m.groups()[2:]))
    return out


def sprite(name, cache={}):
    atlas, x, y, w, h = rects()[name]
    if atlas not in cache:
        cache[atlas] = Image.open(os.path.join(ATLAS, FILES[atlas])).convert("RGBA")
    return cache[atlas].crop((x, y, x + w, y + h))


def hue(t):
    # A rainbow colour at t (0..1).
    r = 0.5 + 0.5 * math.cos(2 * math.pi * (t + 0.0))
    g = 0.5 + 0.5 * math.cos(2 * math.pi * (t + 1 / 3))
    b = 0.5 + 0.5 * math.cos(2 * math.pi * (t + 2 / 3))
    return int(80 + 175 * r), int(80 + 175 * g), int(80 + 175 * b)


def disc(color):
    """A glowing disc: soft halo, a dark rim, a radial fill (rainbow for Secret things), and rays."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    c = SIZE // 2
    base = color if color != RAINBOW else (255, 255, 255)
    halo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((24, 24, SIZE - 24, SIZE - 24), fill=(*base, 170))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(18)))
    draw = ImageDraw.Draw(img)
    draw.ellipse((44, 44, SIZE - 44, SIZE - 44), fill=(40, 22, 50, 255))  # the rim
    fill = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = fill.load()
    inner = c - 58
    for yy in range(SIZE):
        for xx in range(SIZE):
            d = math.hypot(xx - c, yy - c)
            if d <= inner:
                k = d / inner
                if color == RAINBOW:
                    r, g, b = hue((math.atan2(yy - c, xx - c) / (2 * math.pi)) % 1)
                else:
                    r, g, b = color
                light = 1.35 - 0.6 * k  # brighter centre
                px[xx, yy] = (min(255, int(r * light)), min(255, int(g * light)), min(255, int(b * light)), 255)
    img.alpha_composite(fill)
    # Rays from the centre, light and subtle.
    rays = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for i in range(12):
        a0 = i * math.pi / 6
        a1 = a0 + math.pi / 18
        pts = [(c, c), (c + inner * math.cos(a0), c + inner * math.sin(a0)), (c + inner * math.cos(a1), c + inner * math.sin(a1))]
        rd.polygon(pts, fill=(255, 255, 255, 46))
    img.alpha_composite(rays)
    return img


def place(img, spr, scale, dx=0, dy=0):
    w, h = spr.size
    k = scale / max(w, h)
    spr = spr.resize((int(w * k), int(h * k)), Image.LANCZOS)
    # A soft drop shadow under the sprite.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mask = spr.split()[3].point(lambda a: int(a * 0.55))
    x, y = (SIZE - spr.width) // 2 + dx, (SIZE - spr.height) // 2 + dy
    shadow.paste((0, 0, 0, 255), (x + 6, y + 10), mask)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    img.alpha_composite(spr, (x, y))


def build(name, color, extra=None):
    img = disc(color)
    spr = sprite(name)
    if extra == "stack":  # Floor 2: one base over another
        place(img, spr, 230, dy=50)
        place(img, spr, 230, dy=-60)
    else:
        place(img, spr, 300)
    return img


def main():
    out = os.path.join(ROOT, "art", "products")
    for key, (name, color, extra) in PRODUCTS.items():
        path = os.path.join(out, key + ".png")
        if os.path.exists(path):
            continue
        build(name, color, extra).save(path)
        print("made", os.path.relpath(path, ROOT))
    out = os.path.join(ROOT, "art", "badges")
    os.makedirs(out, exist_ok=True)
    for key, (name, color) in BADGES.items():
        path = os.path.join(out, key + ".png")
        build(name, color).save(path)
        print("made", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
