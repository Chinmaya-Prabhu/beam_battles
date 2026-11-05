"""Cuts the 12-piece UI sheets (art/ui_sheets/NN.png, transparent) into trimmed pieces:
art/ui/NN/<index>_<name>.png. Pieces are found by shape, not by grid: solid pixels are grouped into blobs
(a small dilation keeps sparkles with their object), the 12 biggest are kept and read left to right,
top to bottom. Each is cropped with a small margin at full resolution."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAMES = {
    "01": "cash power ki star click clock padlock shield steal trophy crown gloves",
    "02": "shop base rebirth auto goals index gift settings close back plus check",
    "03": "pill_gold pill_green pill_red pill_grey tile_gold tile_blue window card bar_track bar_fill bubble dot",
    "04": "vip double_cash double_power auto_train fast_steal server_luck power_boost shield cash_small cash_large stand_now starter",
    "05": "common uncommon rare epic legendary mythic secret golden diamond rainbow huge tag",
    "06": "cloth wood stone iron steel gold chakra seastone diamond gravity locked unknown",
    "07": "rookie trainee fighter super elite master ultra god rebirth laurel wins thief",
    "08": "deflect smash smash_charged orb ring vs pip_empty pip_full grade_s grade_a grade_b portrait",
    "09": "hand arrow_down arrow_right gift gift_open chest chest_open burst confetti sparkles alert beacon",
    "10": "hub blossom ninja pirate walled locked portal boss guardian dragon soon colosseum",
}
MARGIN = 6
DILATE = {"01": 3}  # sheets whose pieces sit close together

def pieces(img, dilate=10):
    alpha = np.array(img.getchannel("A"))
    solid = alpha > 40
    grown = ndimage.binary_dilation(solid, iterations=dilate)
    labels, count = ndimage.label(grown)
    boxes = ndimage.find_objects(labels)
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    keep = sorted(range(count), key=lambda i: -sizes[i])[:12]
    found = []
    for i in keep:
        ys, xs = boxes[i]
        found.append((xs.start, ys.start, xs.stop, ys.stop))
    # Reading order: group into rows by vertical centre, then left to right.
    found.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows = [found[k:k + 4] for k in range(0, len(found), 4)]
    return [b for row in rows for b in sorted(row, key=lambda b: b[0])]


def main():
    for sheet, names in NAMES.items():
        img = Image.open(os.path.join(ROOT, "art/ui_sheets", sheet + ".png")).convert("RGBA")
        out = os.path.join(ROOT, "art/ui", sheet)
        os.makedirs(out, exist_ok=True)
        boxes = pieces(img, DILATE.get(sheet, 10))
        if len(boxes) != 12:
            print("WARNING", sheet, "found", len(boxes), "pieces")
        for i, (name, box) in enumerate(zip(names.split(), boxes)):
            x0, y0, x1, y1 = box
            # The dilation already adds ~10 px; trim back to visible pixels plus a margin.
            crop = img.crop((x0, y0, x1, y1))
            tight = crop.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            if tight:
                x0, y0, x1, y1 = x0 + tight[0], y0 + tight[1], x0 + tight[2], y0 + tight[3]
            box = (max(0, x0 - MARGIN), max(0, y0 - MARGIN), min(img.width, x1 + MARGIN), min(img.height, y1 + MARGIN))
            img.crop(box).save(os.path.join(out, f"{i + 1:02d}_{name}.png"))
    print("done")


if __name__ == "__main__":
    sys.exit(main())
