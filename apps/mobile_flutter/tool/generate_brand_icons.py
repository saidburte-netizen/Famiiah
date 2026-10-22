"""Generate Fam launcher icons from the design's 512-unit mark geometry.

Outputs (committed, copied into the generated android/ project by
tool/setup_android.sh):
  assets/branding/app_icon.png                    1024 master
  assets/branding/android/mipmap-*/ic_launcher.png
  assets/branding/android/mipmap-*/ic_launcher_round.png
  assets/branding/android/mipmap-*/ic_launcher_foreground.png
"""

import os
from PIL import Image, ImageDraw

OUT = "assets/branding"
ANDROID = os.path.join(OUT, "android")
SS = 4  # supersampling factor for geometry

ROYAL_LIFT = (47, 104, 238)
ROYAL_MID = (18, 58, 156)
MIDNIGHT = (6, 21, 56)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    """Diagonal three-stop gradient, built small then upscaled (smooth)."""
    n = 256
    small = Image.new("RGB", (n, n))
    px = small.load()
    for y in range(n):
        for x in range(n):
            t = ((x / (n - 1)) + (y / (n - 1))) / 2
            if t < 0.5:
                px[x, y] = lerp(ROYAL_LIFT, ROYAL_MID, t / 0.5)
            else:
                px[x, y] = lerp(ROYAL_MID, MIDNIGHT, (t - 0.5) / 0.5)
    return small.resize((size, size), Image.BICUBIC)


def mark_layer(size):
    """The white F, window grid, door and baseline on transparency (AA)."""
    S = size * SS
    u = S / 512.0
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([166 * u, 110 * u, 352 * u, 188 * u], radius=16 * u, fill=WHITE)
    d.rectangle([166 * u, 118 * u, 236 * u, 398 * u], fill=WHITE)
    d.rounded_rectangle([166 * u, 230 * u, 324 * u, 288 * u], radius=16 * u, fill=WHITE)
    for wx in (180, 206):
        for wy in (210, 258, 306):
            d.rounded_rectangle(
                [wx * u, wy * u, (wx + 16) * u, (wy + 22) * u],
                radius=3 * u,
                fill=(29, 78, 216, 97),
            )
    d.rounded_rectangle([188 * u, 350 * u, 214 * u, 398 * u], radius=4 * u, fill=(10, 34, 96, 230))
    d.rounded_rectangle([134 * u, 392 * u, 378 * u, 404 * u], radius=6 * u, fill=WHITE)
    return layer.resize((size, size), Image.LANCZOS)


def draw_mark(size, background=True):
    layer = mark_layer(size)
    if not background:
        return layer

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * SS - 1, size * SS - 1], radius=round(118 / 512 * size * SS), fill=255
    )
    mask = mask.resize((size, size), Image.LANCZOS)
    out.paste(gradient(size), (0, 0), mask)

    d = ImageDraw.Draw(out)
    inset = 8 / 512 * size
    d.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=110 / 512 * size,
        outline=(255, 255, 255, 56),
        width=max(1, round(3 / 512 * size)),
    )
    out.alpha_composite(layer)
    return out


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(" ", path, img.size)


os.makedirs(ANDROID, exist_ok=True)
write(draw_mark(1024), os.path.join(OUT, "app_icon.png"))

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

for dens, px in DENSITIES.items():
    base = os.path.join(ANDROID, f"mipmap-{dens}")
    os.makedirs(base, exist_ok=True)
    write(draw_mark(px), os.path.join(base, "ic_launcher.png"))

    mark = draw_mark(px)
    circle = Image.new("L", (px * SS, px * SS), 0)
    ImageDraw.Draw(circle).ellipse([0, 0, px * SS - 1, px * SS - 1], fill=255)
    circle = circle.resize((px, px), Image.LANCZOS)
    round_img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    round_img.paste(mark, (0, 0), circle)
    write(round_img, os.path.join(base, "ic_launcher_round.png"))

    fg_px = round(px * 108 / 48)
    mark_px = round(fg_px * 0.66)
    inner = draw_mark(mark_px)
    fg = Image.new("RGBA", (fg_px, fg_px), (0, 0, 0, 0))
    fg.alpha_composite(inner, ((fg_px - mark_px) // 2, (fg_px - mark_px) // 2))
    write(fg, os.path.join(base, "ic_launcher_foreground.png"))

print("done")
