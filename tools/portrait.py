"""Turns a portrait artwork on a paper background into one on a transparent
background, so it sits on the site's own paper with no visible rectangle.

    python tools/portrait.py source/portrait.webp assets/portrait.webp

The paper colour is read from the picture's corners. Every pixel is then split into
"how much ink is here" (the new transparency) and the ink's own colour, the way
colour-to-alpha works in an image editor: blacks, greys, reds and the white collar
all keep their look, and the paper disappears. The result is cropped to what is left.

Needs Pillow and NumPy. It prints the size and where the red sun's centre is; put
those in site.json as photoSize and photoFocus.
"""
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
rgb = np.asarray(Image.open(src).convert('RGB')).astype(np.float64) / 255.0
h, w = rgb.shape[:2]

# Paper = the average of the four corners.
k = 60
corners = np.concatenate([rgb[:k, :k], rgb[:k, -k:], rgb[-k:, :k], rgb[-k:, -k:]]).reshape(-1, 3)
paper = corners.mean(axis=0)

# Colour to alpha, channel by channel, taking the strongest claim.
darker = np.where(rgb < paper, (paper - rgb) / paper, 0.0)
lighter = np.where(rgb > paper, (rgb - paper) / (1.0 - paper), 0.0)
alpha = np.maximum(darker, lighter).max(axis=2)

# The paper has a faint grain; anything that weak is paper, not ink.
floor = 0.09
alpha = np.clip((alpha - floor) / (1.0 - floor), 0.0, 1.0)

# The colour that, laid over the paper at this alpha, gives back the original pixel.
safe = np.maximum(alpha, 1e-6)[..., None]
ink = np.clip((rgb - (1.0 - safe) * paper) / safe, 0.0, 1.0)

out = np.dstack([ink, alpha])
# Crop to the rows and columns that really hold ink (a stray speck does not count).
# A hairline that runs out past the picture is allowed to be cut by the margin.
solid = alpha > 0.5
ys = np.where(solid.sum(axis=1) >= 12)[0]
xs = np.where(solid.sum(axis=0) >= 12)[0]
pad = 48
top, bottom = max(ys.min() - pad, 0), min(ys.max() + pad, h - 1)
left, right = max(xs.min() - pad, 0), min(xs.max() + pad, w - 1)
out = out[top:bottom + 1, left:right + 1]

# Where the sun is: the centre of the strongly red area in the upper two thirds.
r, g, b = out[..., 0], out[..., 1], out[..., 2]
red = (r > 0.7) & (g < 0.25) & (b < 0.25) & (out[..., 3] > 0.8)
red[int(out.shape[0] * 0.62):] = False
ry, rx = np.where(red)
cols = np.where(red.sum(axis=0) > 0.25 * red.sum(axis=0).max())[0]
rows = np.where(red.sum(axis=1) > 0.25 * red.sum(axis=1).max())[0]
fx = (cols.min() + cols.max()) / 2 / out.shape[1] * 100
fy = (rows.min() + rows.max()) / 2 / out.shape[0] * 100

Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA').save(dst, 'WEBP', quality=78, alpha_quality=60, method=6)
print('paper', (paper * 255).round(1))
print('photoSize', [out.shape[1], out.shape[0]])
print('photoFocus', [round(float(fx), 1), round(float(fy), 1)])
