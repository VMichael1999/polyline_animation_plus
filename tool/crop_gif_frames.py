"""Crops every PNG frame of a folder to a box given as fractions of its size.

Usage: crop_gif_frames.py <frames dir> <x0> <y0> <x1> <y1>
"""
import glob, sys
from PIL import Image
d, x0, y0, x1, y1 = sys.argv[1], *map(float, sys.argv[2:6])
for f in sorted(glob.glob(f"{d}/f_*.png")):
    im = Image.open(f); w, h = im.size
    im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1))).save(f)
