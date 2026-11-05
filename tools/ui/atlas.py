"""Packs the UI pieces the game uses (art/ui/NN/*.png) into upload-ready atlases in art/atlas/, and writes
their rectangles to src/shared/UIAtlasRects.lua. Icon atlases are a 5x5 grid of 204 px cells (each icon
fitted and centred); the frames atlas keeps frames at full size (shelf-packed) for sharp 9-slicing, with a
SliceCenter per frame. Also exports the 11 store icons at 512x512 for the Creator Dashboard (art/store_icons)."""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(ROOT, "art/ui")

ICONS = [
    "01/cash", "01/power", "01/ki", "01/padlock", "01/clock",
    "02/shop", "02/base", "02/rebirth", "02/auto", "02/close",
    "07/rookie", "07/trainee", "07/fighter", "07/super", "07/elite",
    "07/master", "07/ultra", "07/god", "08/deflect", "08/smash",
    "08/smash_charged", "08/vs", "08/pip_empty", "08/pip_full", "08/grade_s",
]
MORE = [
    "08/grade_a", "08/grade_b", "10/hub", "10/blossom", "10/ninja",
    "10/pirate", "10/walled", "04/vip", "04/double_cash", "04/double_power",
    "04/auto_train", "04/fast_steal", "04/server_luck", "04/power_boost", "04/shield",
    "04/cash_small", "04/cash_large", "04/stand_now", "09/hand", "09/arrow_down",
    "09/gift", "09/gift_open", "09/chest", "09/chest_open", "09/confetti",
]
FRAMES = [
    "03/pill_gold", "03/pill_green", "03/pill_red", "03/pill_grey", "03/tile_gold", "03/tile_blue",
    "03/window", "03/card", "03/bar_track", "03/bar_fill", "03/bubble",
]
# Hand-made icons straight from art/ui/*.png (not the numbered sheets): cut to their outline and packed
# into their own atlas (512 px cells).
EXTRA = ["bag", "index"]
STORE = ["vip", "double_cash", "double_power", "auto_train", "fast_steal", "server_luck",
         "power_boost", "shield", "cash_small", "cash_large", "stand_now"]


def load(ref):
    sheet, name = ref.split("/")
    for fn in os.listdir(os.path.join(UI, sheet)):
        if fn[3:-4] == name:
            return Image.open(os.path.join(UI, sheet, fn)).convert("RGBA")
    raise SystemExit("missing " + ref)


def grid_atlas(refs, path, rects, atlas_name, cell=204, pad=8):
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for i, ref in enumerate(refs):
        im = load(ref)
        im.thumbnail((cell - pad * 2, cell - pad * 2), Image.LANCZOS)
        cx, cy = (i % 5) * cell, (i // 5) * cell
        x, y = cx + (cell - im.width) // 2, cy + (cell - im.height) // 2
        atlas.alpha_composite(im, (x, y))
        rects[ref.split("/")[1] if ref.split("/")[1] not in rects else ref.replace("/", "_")] = (atlas_name, x, y, im.width, im.height, None)
    atlas.save(path)


def frames_atlas(refs, path, rects):
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    x = y = shelf = 0
    for ref in refs:
        im = load(ref)
        if im.width > 480:
            im.thumbnail((480, 480), Image.LANCZOS)
        if x + im.width > 1024:
            x, y, shelf = 0, y + shelf + 4, 0
        atlas.alpha_composite(im, (x, y))
        name = ref.split("/")[1]
        w, h = im.size
        if name.startswith("pill") or name.startswith("bar"):
            inset = (h // 2, h // 2 - 2)  # round ends stay round; stretch the middle
        elif name == "bubble":
            inset = (int(h * 0.42), int(h * 0.36))
        else:
            inset = (int(min(w, h) * 0.3), int(min(w, h) * 0.3))
            if name == "window":
                inset = (int(w * 0.18), 84)  # the blue header band and its navy line end at row 81
        # SliceCenter, relative to the piece: Rect(x0, y0, x1, y1).
        slice_ = (inset[0], inset[1], w - inset[0], h - inset[1])
        if name == "window":
            slice_ = (inset[0], inset[1], w - inset[0], 190)  # the cream bottom edge starts at row 197
        rects[name] = ("frames", x, y, w, h, slice_)
        x += w + 4
        shelf = max(shelf, h)
    atlas.save(path)


def store_icons():
    out = os.path.join(ROOT, "art/store_icons")
    os.makedirs(out, exist_ok=True)
    for name in STORE:
        im = load("04/" + name)
        im.thumbnail((400, 400), Image.LANCZOS)
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((512 - im.width) // 2, (512 - im.height) // 2))
        canvas.save(os.path.join(out, name + ".png"))


def extra_atlas(names, path, rects, cell=512, pad=12):
    atlas = Image.new("RGBA", (cell * 2, cell * ((len(names) + 1) // 2)), (0, 0, 0, 0))
    for i, name in enumerate(names):
        im = Image.open(os.path.join(UI, name + ".png")).convert("RGBA")
        im = im.crop(im.getbbox())  # cut away the empty margin
        im.thumbnail((cell - pad * 2, cell - pad * 2), Image.LANCZOS)
        cx, cy = (i % 2) * cell, (i // 2) * cell
        x, y = cx + (cell - im.width) // 2, cy + (cell - im.height) // 2
        atlas.alpha_composite(im, (x, y))
        rects[name] = ("extra", x, y, im.width, im.height, None)
    atlas.save(path)


def beam_strip(path):
    """The guide beam's texture: the chevron strip (art/ui/tutorial_guide_arrows.png). A Beam stretches an
    image's width across the beam and repeats its height along it, so the strip is turned upright with the
    chevrons pointing down the tile, toward Attachment1 (the target)."""
    im = Image.open(os.path.join(UI, "tutorial_guide_arrows.png")).convert("RGBA")
    im = im.rotate(-90, expand=True)  # > pointing right becomes v pointing down
    im.resize((128, 512), Image.LANCZOS).save(path)


def lua(rects):
    lines = [
        "-- Generated by tools/ui/atlas.py. Do not edit by hand: re-run it after changing the art.",
        "-- [name] = { atlas, x, y, w, h, slice (x0, y0, x1, y1) or nil }",
        "return {",
    ]
    for name in sorted(rects):
        atlas, x, y, w, h, s = rects[name]
        sl = ("{ %d, %d, %d, %d }" % s) if s else "nil"
        lines.append('\t%s = { "%s", %d, %d, %d, %d, %s },' % (name, atlas, x, y, w, h, sl))
    lines.append("}")
    with open(os.path.join(ROOT, "src/shared/UIAtlasRects.lua"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    out = os.path.join(ROOT, "art/atlas")
    os.makedirs(out, exist_ok=True)
    rects = {}
    grid_atlas(ICONS, os.path.join(out, "anime_clash_icons.png"), rects, "icons")
    grid_atlas(MORE, os.path.join(out, "anime_clash_more.png"), rects, "more")
    frames_atlas(FRAMES, os.path.join(out, "anime_clash_frames.png"), rects)
    extra_atlas(EXTRA, os.path.join(out, "anime_clash_extra.png"), rects)
    beam_strip(os.path.join(out, "anime_clash_beam.png"))
    store_icons()
    lua(rects)
    print(len(rects), "rects")


if __name__ == "__main__":
    main()
