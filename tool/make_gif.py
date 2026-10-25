#!/usr/bin/env python3
"""Turns a folder of PNG frames into a small GIF. Usage: make_gif.py <frames dir> <out.gif> <fps> [colors]"""
import glob
import sys

from PIL import Image

frames_dir, out, fps = sys.argv[1], sys.argv[2], float(sys.argv[3])
colors = int(sys.argv[4]) if len(sys.argv) > 4 else 96
files = sorted(glob.glob(f"{frames_dir}/f_*.png"))
frames = [Image.open(f).convert("RGB") for f in files]

# One palette for the whole animation keeps the colors steady between frames.
sample = Image.new("RGB", (frames[0].width, frames[0].height * min(len(frames), 20)))
for i, f in enumerate(frames[:: max(1, len(frames) // 20)][:20]):
    sample.paste(f, (0, i * f.height))
palette = sample.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE)
quantized = [f.quantize(palette=palette, dither=Image.NONE) for f in frames]

quantized[0].save(
    out,
    save_all=True,
    append_images=quantized[1:],
    duration=round(1000 / fps),
    loop=0,
    optimize=True,
    disposal=1,
)
print(f"{len(frames)} frames, {frames[0].size}, {round(__import__('os').path.getsize(out) / 1e6, 2)} MB")
