"""Build the launcher-icon assets from the hand-made source art.

Input : assets/icon/source_icon.png  (square, art already composed on a dark card
                                      with a thin white margin/rounded corners)
Output: assets/icon/icon.png             full-bleed, corners filled (iOS + legacy Android)
        assets/icon/icon_foreground.png  padded, transparent  (Android adaptive foreground)

Needs Pillow (`pip install pillow`). After running this, regenerate the platform
icons with `dart run flutter_launcher_icons`.
"""

from PIL import Image, ImageDraw

SRC = "assets/icon/source_icon.png"
BG = (13, 23, 29)  # #0D171D — the dark card colour in the source art
SIZE = 1024
MARGIN = 58  # px of white border to crop off the source before scaling


def rounded_mask(size, radius_frac):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * radius_frac), fill=255
    )
    return m


def main():
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    card = src.crop((MARGIN, MARGIN, w - MARGIN, h - MARGIN))

    # Full-bleed icon: fill the frame with the card colour, drop the (cropped)
    # art in through a gently rounded mask to erase the source's white corners.
    # The OS applies its own mask on top.
    base = Image.new("RGB", (SIZE, SIZE), BG)
    base.paste(card.resize((SIZE, SIZE), Image.LANCZOS), (0, 0), rounded_mask(SIZE, 0.09))
    base.save("assets/icon/icon.png")

    # Adaptive foreground: shrink into the safe zone on a transparent canvas.
    # adaptive_icon_background is set to the same BG so the card edge is seamless.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    s = int(SIZE * 0.82)
    art = card.convert("RGBA").resize((s, s), Image.LANCZOS)
    off = (SIZE - s) // 2
    fg.paste(art, (off, off), rounded_mask(s, 0.12))
    fg.save("assets/icon/icon_foreground.png")

    print("wrote assets/icon/icon.png and assets/icon/icon_foreground.png")


if __name__ == "__main__":
    main()
