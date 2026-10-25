#!/usr/bin/env python3
"""Makes pictures of a car for every direction, drawn as a small 3D model.

The only picture it takes is the car seen from above, with its front pointing
up (assets/car.png). Everything else is drawn here:

  * a low-poly car (roof, rear window, windshield, hood, front and rear faces
    and the two sides), with proportions taken from that picture;
  * the picture from above is put on the roof, the glass and the hood, cut in
    the pieces that each one covers, so what you see from above stays as it is;
  * the sides, the front and the rear are drawn here: doors, windows, wheels
    with rims, mirror, headlights, grille, tail lights and number plates;
  * a soft shadow on the ground.

Each direction is rendered with the camera tilted (default 45 degrees, like the
map when it follows the car) and saved as car_000.png, car_005.png, ...
Pick the one for the direction the car faces ON THE SCREEN: the direction it
drives minus the direction the map is turned to.

Usage:  python3 tool/make_car_sprites.py [--step 5] [--tilt 45]
Needs Pillow:  pip install pillow
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "car.png"
OUTPUT = ROOT / "assets" / "car_3d"

CANVAS = 192   # size of every picture, in pixels (64 logical pixels at 3x)
SUPER = 3      # it is drawn this many times bigger and shrunk, to smooth edges
CAR_PIXELS = 128  # length of the car on the picture when seen from above

# The car, in meters. Front is +y, right is +x, up is +z.
L, W, H = 3.47, 1.52, 1.50

# The picture from above is wider than the body because of the mirrors. These
# are the columns the body covers, at the scale of the picture (113 x 212).
BODY_COLUMNS = (9, 101)

# The side view of the car: points (y, z) from the rear bottom, around the top
# and back down the front. The corners of the top pieces are on this line.
PROFILE = [
    (0.05, 0.22), (0.05, 0.95), (0.55, 1.50), (2.00, 1.50), (2.60, 1.00),
    (3.35, 0.82), (3.47, 0.70), (3.47, 0.26), (3.30, 0.22),
]

# The pieces seen from above: (rear y, rear z, front y, front z).
TOP_PIECES = [
    (0.05, 0.95, 0.55, 1.50),   # rear window
    (0.55, 1.50, 2.00, 1.50),   # roof
    (2.00, 1.50, 2.60, 1.00),   # windshield
    (2.60, 1.00, 3.35, 0.82),   # hood
    (3.35, 0.82, 3.47, 0.70),   # nose
]

BODY = (244, 245, 247)
GLASS = (32, 40, 52)
DARK = (34, 36, 40)
SILVER = (192, 196, 203)

LIGHT = (-0.45, -0.30, 0.84)   # where the light comes from, on the screen


# ---------------------------------------------------------------- the textures

def px(value, scale):
    return round(value * scale)


def gradient_overlay(size, top, bottom):
    """A vertical shade from `top` to `bottom` opacity of black."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        alpha = round(top + (bottom - top) * t)
        draw.line([(0, y), (size[0], y)], fill=(0, 0, 0, alpha))
    return layer


def side_texture():
    """The right side of the car, with the front towards the right."""
    s = 420
    size = (px(L, s), px(H, s))

    def at(y, z):
        return (px(y, s), size[1] - px(z, s))

    body = Image.new("RGBA", size, (0, 0, 0, 0))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([at(y, z) for y, z in PROFILE], fill=255)

    paint = Image.new("RGBA", size, BODY + (255,))
    paint = Image.alpha_composite(paint, gradient_overlay(size, 0, 70))
    body.paste(paint, (0, 0), mask)
    d = ImageDraw.Draw(body)

    # Dark bumpers and sill.
    d.polygon([at(0.05, 0.22), at(0.05, 0.50), at(0.40, 0.50), at(0.40, 0.22)], fill=DARK)
    d.polygon([at(3.10, 0.22), at(3.10, 0.50), at(3.47, 0.50), at(3.47, 0.26)], fill=DARK)
    d.polygon([at(0.40, 0.22), at(0.40, 0.36), at(3.10, 0.36), at(3.10, 0.22)], fill=(70, 72, 78))

    # Windows, with a pillar between them.
    window = [(0.62, 1.04), (0.74, 1.42), (1.96, 1.42), (2.46, 1.04)]
    d.polygon([at(y, z) for y, z in window], fill=GLASS)
    d.line([at(0.74, 1.42), at(1.96, 1.42)], fill=(150, 154, 160), width=4)
    d.polygon([at(1.20, 1.04), at(1.20, 1.43), at(1.32, 1.43), at(1.32, 1.04)], fill=BODY)
    # A soft reflection on the glass.
    d.polygon([at(0.80, 1.38), at(1.02, 1.38), at(0.86, 1.08), at(0.70, 1.08)], fill=(70, 82, 100))
    d.polygon([at(1.44, 1.38), at(1.68, 1.38), at(1.40, 1.08), at(1.28, 1.08)], fill=(70, 82, 100))

    # Doors: seams, handles and the mirror.
    for y in (0.60, 1.26, 2.12):
        d.line([at(y, 0.38), at(y, 1.04)], fill=(196, 200, 206), width=3)
    d.line([at(0.60, 1.04), at(2.46, 1.04)], fill=(190, 194, 200), width=3)
    for y in (1.02, 1.74):
        d.rounded_rectangle([at(y, 0.93)[0], at(y, 0.93)[1], at(y + 0.16, 0.89)[0], at(y + 0.16, 0.89)[1] + 6], 4, fill=(150, 154, 160))
    d.polygon([at(2.44, 1.10), at(2.60, 1.10), at(2.62, 0.98), at(2.46, 0.96)], fill=BODY, outline=(120, 124, 130))

    # Lights at both ends.
    d.polygon([at(3.40, 0.78), at(3.47, 0.70), at(3.47, 0.60), at(3.34, 0.62)], fill=(255, 236, 170), outline=(120, 120, 120))
    d.polygon([at(0.05, 0.98), at(0.15, 0.98), at(0.15, 0.66), at(0.05, 0.70)], fill=(200, 24, 36))

    # Wheels: dark arch, tire, rim with spokes, hub.
    for wy in (0.78, 2.70):
        cx, cy = at(wy, 0.345)
        for radius, color in ((0.405, (14, 14, 16)), (0.345, (24, 24, 27)), (0.225, SILVER), (0.20, (222, 225, 230))):
            r = px(radius, s)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        for k in range(5):
            angle = math.radians(72 * k + 18)
            d.line([(cx, cy), (cx + math.cos(angle) * px(0.20, s), cy - math.sin(angle) * px(0.20, s))], fill=(112, 116, 124), width=6)
        r = px(0.06, s)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(90, 94, 100))
    # The part of the arch below the tire is cut by the ground line.

    # A thin outline so the shape reads well.
    d.line([at(y, z) for y, z in PROFILE + [PROFILE[0]]], fill=(110, 115, 124), width=4)
    return body


def front_texture():
    s = 400
    size = (px(W, s), px(0.42, s))   # z from 0.28 to 0.70
    img = Image.new("RGBA", size, BODY + (255,))
    img = Image.alpha_composite(img, gradient_overlay(size, 0, 60))
    d = ImageDraw.Draw(img)
    w, h = size
    # Grille and air intake.
    d.rounded_rectangle([w * 0.32, h * 0.10, w * 0.68, h * 0.50], 10, fill=DARK)
    for k in range(1, 4):
        y = h * (0.10 + 0.10 * k)
        d.line([(w * 0.33, y), (w * 0.67, y)], fill=(120, 124, 130), width=4)
    d.rounded_rectangle([w * 0.18, h * 0.62, w * 0.82, h * 0.88], 12, fill=DARK)
    # Number plate.
    d.rectangle([w * 0.42, h * 0.60, w * 0.58, h * 0.78], fill=(238, 238, 232), outline=(80, 80, 80))
    # Headlights.
    for x0, x1 in ((0.05, 0.28), (0.72, 0.95)):
        d.rounded_rectangle([w * x0, h * 0.08, w * x1, h * 0.46], 14, fill=(250, 238, 190), outline=(110, 110, 110), width=4)
        d.ellipse([w * (x0 + 0.05), h * 0.14, w * (x0 + 0.13), h * 0.38], fill=(255, 255, 255))
    d.rectangle([0, 0, w - 1, h - 1], outline=(120, 124, 132), width=3)
    return img


def rear_texture():
    s = 400
    size = (px(W, s), px(0.73, s))   # z from 0.22 to 0.95
    img = Image.new("RGBA", size, BODY + (255,))
    img = Image.alpha_composite(img, gradient_overlay(size, 0, 60))
    d = ImageDraw.Draw(img)
    w, h = size
    # Tail lights.
    for x0, x1 in ((0.04, 0.26), (0.74, 0.96)):
        d.rounded_rectangle([w * x0, h * 0.10, w * x1, h * 0.50], 10, fill=(206, 26, 38), outline=(110, 20, 28), width=4)
        d.rectangle([w * (x0 + 0.03), h * 0.22, w * (x1 - 0.03), h * 0.30], fill=(255, 176, 170))
    # Number plate and a badge.
    d.rectangle([w * 0.38, h * 0.50, w * 0.62, h * 0.70], fill=(238, 238, 232), outline=(80, 80, 80))
    d.ellipse([w * 0.47, h * 0.24, w * 0.53, h * 0.34], fill=SILVER)
    # Bumper.
    d.rectangle([0, h * 0.74, w, h], fill=DARK)
    d.rectangle([0, 0, w - 1, h - 1], outline=(120, 124, 132), width=3)
    return img


# ------------------------------------------------------------------- rendering

def solve_homography(src, dst):
    """Coefficients that map points of `dst` to points of `src` (for PIL)."""
    matrix, vector = [], []
    for (x, y), (u, v) in zip(dst, src):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        vector.append(u)
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        vector.append(v)

    n = 8
    rows = [matrix[i] + [vector[i]] for i in range(n)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(rows[r][col]))
        rows[col], rows[pivot] = rows[pivot], rows[col]
        for r in range(n):
            if r != col:
                factor = rows[r][col] / rows[col][col]
                rows[r] = [a - factor * b for a, b in zip(rows[r], rows[col])]
    return [rows[i][n] / rows[i][i] for i in range(n)]


class Camera:
    def __init__(self, heading, tilt, scale):
        self.yaw = math.radians(heading)
        self.tilt = math.radians(tilt)
        self.scale = scale

    def rotate(self, p):
        x, y, z = p
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return (x * c + y * s, -x * s + y * c, z)

    def project(self, p):
        x, y, z = self.rotate(p)
        # The model is centered on the car; the screen center is the canvas
        # center. Up on the screen is north, and height lifts things up.
        sx = x
        sy = -(y * math.cos(self.tilt) + z * math.sin(self.tilt))
        return (CANVAS * SUPER / 2 + sx * self.scale,
                CANVAS * SUPER / 2 + 14 * SUPER + sy * self.scale)

    def depth(self, p):
        x, y, z = self.rotate(p)
        return -y * math.sin(self.tilt) + z * math.cos(self.tilt)

    def faces_camera(self, normal):
        nx, ny, nz = self.rotate(normal)
        return -ny * math.sin(self.tilt) + nz * math.cos(self.tilt) > 1e-6

    def shade(self, normal):
        nx, ny, nz = self.rotate(normal)
        length = math.sqrt(sum(c * c for c in LIGHT))
        lit = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / length
        return 0.80 + 0.26 * max(0.0, lit)


def normalize(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


def make_faces(top_image, textures):
    """Every face as (corners, normal, texture, texture corners)."""
    side_right, side_left, front, rear = textures
    half = W / 2
    cy = L / 2  # center the car on y = 0
    faces = []

    # Sides. Corners go: rear-bottom, front-bottom, front-top, rear-top.
    sw, sh = side_right.size
    faces.append(([(half, 0 - cy, 0), (half, L - cy, 0), (half, L - cy, H), (half, 0 - cy, H)],
                  (1, 0, 0), side_right, [(0, sh), (sw, sh), (sw, 0), (0, 0)]))
    faces.append(([(-half, L - cy, 0), (-half, 0 - cy, 0), (-half, 0 - cy, H), (-half, L - cy, H)],
                  (-1, 0, 0), side_left, [(0, sh), (sw, sh), (sw, 0), (0, 0)]))

    # The pieces seen from above, each with its slice of the picture.
    iw, ih = top_image.size
    for ya, za, yb, zb in TOP_PIECES:
        top = (L - yb) / L * ih
        bottom = (L - ya) / L * ih
        piece = top_image.crop((0, round(top), iw, max(round(top) + 1, round(bottom))))
        normal = normalize((0, -(zb - za), yb - ya))
        corners = [(-half, ya - cy, za), (half, ya - cy, za), (half, yb - cy, zb), (-half, yb - cy, zb)]
        pw, ph = piece.size
        faces.append((corners, normal, piece, [(0, ph), (pw, ph), (pw, 0), (0, 0)]))

    # Front and rear faces.
    fw, fh = front.size
    faces.append(([(-half, L - cy, 0.28), (half, L - cy, 0.28), (half, L - cy, 0.70), (-half, L - cy, 0.70)],
                  (0, 1, 0), front, [(0, fh), (fw, fh), (fw, 0), (0, 0)]))
    rw, rh = rear.size
    faces.append(([(half, 0.05 - cy, 0.22), (-half, 0.05 - cy, 0.22), (-half, 0.05 - cy, 0.95), (half, 0.05 - cy, 0.95)],
                  (0, -1, 0), rear, [(0, rh), (rw, rh), (rw, 0), (0, 0)]))
    return faces


def tint(image, factor):
    r, g, b, a = image.split()
    scale = lambda band: band.point(lambda v: min(255, round(v * factor)))
    return Image.merge("RGBA", (scale(r), scale(g), scale(b), a))


def render(faces, heading, tilt, top_scale):
    camera = Camera(heading, tilt, top_scale * SUPER)
    size = (CANVAS * SUPER, CANVAS * SUPER)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))

    # Shadow of the footprint on the ground.
    half = W / 2
    foot = [(-half, -L / 2, 0), (half, -L / 2, 0), (half, L / 2, 0), (-half, L / 2, 0)]
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    outline = [(x + 5 * SUPER, y + 7 * SUPER) for x, y in (camera.project(p) for p in foot)]
    ImageDraw.Draw(shadow).polygon(outline, fill=(0, 0, 0, 105))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(5 * SUPER)))

    # The faces that look at the camera, from the farthest to the closest.
    visible = [f for f in faces if camera.faces_camera(f[1])]
    visible.sort(key=lambda f: sum(camera.depth(p) for p in f[0]) / 4)
    for corners, normal, texture, texture_corners in visible:
        screen = [camera.project(p) for p in corners]
        coefficients = solve_homography(texture_corners, screen)
        warped = texture.transform(size, Image.PERSPECTIVE, coefficients, Image.BICUBIC)
        canvas = Image.alpha_composite(canvas, tint(warped, camera.shade(normal)))

    return canvas.resize((CANVAS, CANVAS), Image.LANCZOS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--step", type=int, default=5, help="degrees between pictures")
    parser.add_argument("--tilt", type=float, default=45, help="camera tilt it is made for")
    args = parser.parse_args()

    top_image = Image.open(SOURCE).convert("RGBA")
    top_image = top_image.crop((BODY_COLUMNS[0], 0, BODY_COLUMNS[1], top_image.height))
    right = side_texture()
    textures = (right, right.transpose(Image.FLIP_LEFT_RIGHT), front_texture(), rear_texture())
    faces = make_faces(top_image, textures)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for old in OUTPUT.glob("car_*.png"):
        old.unlink()

    scale = CAR_PIXELS / L
    count = 0
    for heading in range(0, 360, args.step):
        render(faces, heading, args.tilt, scale).save(
            OUTPUT / f"car_{heading:03d}.png", optimize=True
        )
        count += 1
    print(f"{count} pictures in {OUTPUT}")


if __name__ == "__main__":
    main()
