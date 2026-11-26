"""Generate the 1024x1024 vibration app icon (no alpha, iOS marketing icon)."""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4096
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "vibration", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")

# ---------- background ----------
y, x = np.mgrid[0:S, 0:S].astype(np.float32)
cx, cy = S * 0.5, S * 0.46

top = np.array([119, 51, 68], dtype=np.float32)
bottom = np.array([25, 23, 22], dtype=np.float32)
t = (y / S)[..., None]
base = top[None, None, :] * (1.0 - t) + bottom[None, None, :] * t

r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (S * 0.72)
glow = np.clip(1.0 - r, 0.0, 1.0) ** 2
base += np.array([98, 40, 54], dtype=np.float32)[None, None, :] * glow[..., None] * 0.55

r2 = np.sqrt((x - S * 0.82) ** 2 + (y - S * 0.92) ** 2) / (S * 0.55)
g2 = np.clip(1.0 - r2, 0.0, 1.0) ** 2
base += np.array([194, 168, 120], dtype=np.float32)[None, None, :] * g2[..., None] * 0.18

base = np.clip(base, 0, 255)
img = Image.fromarray(base.astype(np.uint8), mode="RGB").convert("RGBA")

# ---------- glyph: concentric vibration arcs + core ----------
layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
draw = ImageDraw.Draw(layer)

core_r = S * 0.052
draw.ellipse(
    [cx - core_r, cy - core_r, cx + core_r, cy + core_r],
    fill=(244, 233, 210, 255),
)

arc_specs = [
    (0.135, 8.0, (236, 219, 188)),
    (0.205, 6.6, (194, 168, 120)),
    (0.280, 5.4, (168, 140, 95)),
    (0.360, 4.2, (194, 168, 120)),
]

for radius_f, width_f, color in arc_specs:
    radius = S * radius_f
    width = max(2, int(S * width_f / 1000.0))
    box = [cx - radius, cy - radius, cx + radius, cy + radius]
    for start, end in ((-62, 62), (118, 242)):
        draw.arc(box, start=start, end=end, fill=color + (255,), width=width)

# soft glow beneath the glyph
glow_layer = layer.filter(ImageFilter.GaussianBlur(radius=S * 0.018))
glow_layer = glow_layer.point(lambda v: v)
img = Image.alpha_composite(img, glow_layer)
img = Image.alpha_composite(img, layer)

# subtle top light sweep
sweep = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(sweep)
sdraw.ellipse([-S * 0.2, -S * 0.9, S * 1.2, S * 0.35], fill=(255, 255, 255, 26))
sweep = sweep.filter(ImageFilter.GaussianBlur(radius=S * 0.09))
img = Image.alpha_composite(img, sweep)

# vignette
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
dist = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S * 0.72)
vig = np.clip(1.0 - 0.55 * np.clip(dist - 0.45, 0, 1) ** 1.4, 0, 1)
arr = np.asarray(img.convert("RGB")).astype(np.float32) * vig[..., None]
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGB")

img = img.resize((1024, 1024), Image.LANCZOS)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, format="PNG", optimize=True)
print("wrote", os.path.abspath(OUT), img.size, img.mode)
