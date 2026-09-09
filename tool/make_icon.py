"""Generate the GPS UTC Clock launcher-icon source art into assets/icon/.

Needs Pillow (`pip install pillow`). After running this, regenerate the
platform icons with `dart run flutter_launcher_icons`.
"""
import math
from PIL import Image, ImageDraw

MINT = (0, 229, 160, 255)
MINT_DIM = (0, 229, 160, 110)
BG = (11, 15, 14, 255)
BG2 = (17, 24, 22, 255)

def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

def radial_bg(size):
    img = Image.new("RGBA", (size, size), BG)
    px = img.load()
    cx = cy = size / 2
    maxd = math.hypot(cx, cy)
    for y in range(size):
        for x in range(0, size, 1):
            d = math.hypot(x - cx, y - cy) / maxd
            px[x, y] = lerp(BG2, BG, min(1.0, d * 1.15))
    return img

def draw_art(size, scale):
    """Clock + orbiting satellite, centred, artwork spanning `scale` of the frame."""
    S = 4
    W = size * S
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = cy = W / 2
    R = W * scale / 2 * 0.74  # clock face radius

    # ---- orbit ring + satellite on its own layer, then rotate ----
    orb = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    od = ImageDraw.Draw(orb)
    rx, ry = R * 1.40, R * 0.60
    ow = max(6, int(R * 0.055))
    od.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=MINT_DIM, width=ow)
    # satellite body at the right vertex of the ellipse
    sx, sy = cx + rx, cy
    b = R * 0.15
    od.rounded_rectangle([sx - b, sy - b, sx + b, sy + b], radius=b * 0.35, fill=MINT)
    pw, ph = R * 0.26, R * 0.10
    gap = R * 0.06
    od.rectangle([sx - b - gap - pw, sy - ph, sx - b - gap, sy + ph], fill=MINT)
    od.rectangle([sx + b + gap, sy - ph, sx + b + gap + pw, sy + ph], fill=MINT)
    orb = orb.rotate(38, resample=Image.BICUBIC, center=(cx, cy))
    layer.alpha_composite(orb)

    # ---- clock face ----
    fw = max(8, int(R * 0.085))
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=MINT, width=fw)

    # ticks
    for i in range(12):
        a = math.radians(i * 30 - 90)
        major = (i % 3 == 0)
        r_out = R * 0.98
        r_in = R * (0.74 if major else 0.85)
        tw = int(R * (0.075 if major else 0.045))
        x1, y1 = cx + r_out * math.cos(a), cy + r_out * math.sin(a)
        x2, y2 = cx + r_in * math.cos(a), cy + r_in * math.sin(a)
        d.line([x1, y1, x2, y2], fill=MINT, width=tw)

    # hands: hour -> 12, minute -> 4
    def hand(angle_deg, length, width):
        a = math.radians(angle_deg - 90)
        x = cx + length * math.cos(a)
        y = cy + length * math.sin(a)
        d.line([cx, cy, x, y], fill=MINT, width=int(width))
        d.ellipse([x - width/2, y - width/2, x + width/2, y + width/2], fill=MINT)

    hand(0, R * 0.46, R * 0.10)      # hour
    hand(120, R * 0.70, R * 0.072)   # minute

    # centre hub
    hub = R * 0.11
    d.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=MINT)
    d.ellipse([cx - hub*0.4, cy - hub*0.4, cx + hub*0.4, cy + hub*0.4], fill=BG)

    return layer.resize((size, size), Image.LANCZOS)

def build(path, size, with_bg, scale):
    if with_bg:
        base = radial_bg(size).convert("RGBA")
        base.alpha_composite(draw_art(size, scale))
        base.convert("RGB").save(path)
    else:
        draw_art(size, scale).save(path)
    print("wrote", path)

build("assets/icon/icon.png", 1024, True, 0.82)
build("assets/icon/icon_foreground.png", 1024, False, 0.62)
build("assets/icon/icon_maskable.png", 1024, True, 0.62)
