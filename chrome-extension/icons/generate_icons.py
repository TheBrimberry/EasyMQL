#!/usr/bin/env python3
"""
Generate PNG icons for EasyMQL Chrome Extension.
Uses only Python built-in modules (no PIL/Pillow required).

Icon design: Dark blue circle (#2563eb) with a white polyline
representing an upward-trending stock chart line.
"""

import struct
import zlib
import math
import os


# ---------------------------------------------------------------------------
# Low-level PNG writer (built-in modules only)
# ---------------------------------------------------------------------------

def make_png(width, height, pixels):
    """
    Create a PNG file from raw RGBA pixel data.
    pixels: list of (r, g, b, a) tuples, row-major, length = width * height
    Returns bytes of the complete PNG file.
    """
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack('>I', len(data)) + c + crc

    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'

    # IHDR: width, height, bit_depth=8, color_type=6 (RGBA)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = chunk(b'IHDR', ihdr_data)

    # IDAT: raw image data with filter byte 0 (None) per row
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter: None
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw.extend([r, g, b, a])
    compressed = zlib.compress(bytes(raw), 9)
    idat = chunk(b'IDAT', compressed)

    # IEND
    iend = chunk(b'IEND', b'')

    return signature + ihdr + idat + iend


# ---------------------------------------------------------------------------
# Drawing primitives (anti-aliased on RGBA buffer)
# ---------------------------------------------------------------------------

def blend_pixel(pixels, width, height, x, y, r, g, b, a):
    """Alpha-composite (r,g,b,a) onto pixel at (x,y)."""
    if 0 <= x < width and 0 <= y < height:
        idx = y * width + x
        br, bg, bb, ba = pixels[idx]
        sa = a / 255.0
        da = ba / 255.0
        out_a = sa + da * (1 - sa)
        if out_a > 0:
            out_r = int((r * sa + br * da * (1 - sa)) / out_a)
            out_g = int((g * sa + bg * da * (1 - sa)) / out_a)
            out_b = int((b * sa + bb * da * (1 - sa)) / out_a)
            out_ai = min(255, int(out_a * 255))
            pixels[idx] = (out_r, out_g, out_b, out_ai)


def fill_circle(pixels, width, height, cx, cy, radius, r, g, b, a=255):
    """Draw a filled anti-aliased circle."""
    for py in range(height):
        for px in range(width):
            dx = px + 0.5 - cx
            dy = py + 0.5 - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist <= radius - 0.7:
                blend_pixel(pixels, width, height, px, py, r, g, b, a)
            elif dist <= radius + 0.7:
                coverage = max(0.0, min(1.0, (radius + 0.7 - dist) / 1.4))
                aa = int(a * coverage)
                blend_pixel(pixels, width, height, px, py, r, g, b, aa)


def draw_thick_line(pixels, width, height, x0, y0, x1, y1, thickness, r, g, b, a=255):
    """Draw an anti-aliased thick line segment."""
    dx = x1 - x0
    dy = y1 - y0
    length = math.sqrt(dx * dx + dy * dy)
    if length < 0.001:
        return

    pad = thickness + 2
    min_x = max(0, int(min(x0, x1) - pad))
    max_x = min(width - 1, int(max(x0, x1) + pad))
    min_y = max(0, int(min(y0, y1) - pad))
    max_y = min(height - 1, int(max(y0, y1) + pad))

    half = thickness / 2.0

    for py in range(min_y, max_y + 1):
        for px in range(min_x, max_x + 1):
            cx_p = px + 0.5 - x0
            cy_p = py + 0.5 - y0
            t = (cx_p * dx + cy_p * dy) / (length * length)
            t = max(0.0, min(1.0, t))
            proj_x = x0 + t * dx - (px + 0.5)
            proj_y = y0 + t * dy - (py + 0.5)
            dist = math.sqrt(proj_x * proj_x + proj_y * proj_y)

            if dist <= half - 0.5:
                blend_pixel(pixels, width, height, px, py, r, g, b, a)
            elif dist <= half + 0.5:
                coverage = max(0.0, min(1.0, (half + 0.5 - dist)))
                aa_val = int(a * coverage)
                blend_pixel(pixels, width, height, px, py, r, g, b, aa_val)


def draw_polyline(pixels, width, height, points, thickness, r, g, b, a=255):
    """Draw a connected series of line segments with rounded joints."""
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        draw_thick_line(pixels, width, height, x0, y0, x1, y1, thickness, r, g, b, a)
    # Draw circles at joints for smooth connections
    joint_r = thickness / 2.0
    for px_f, py_f in points:
        for py in range(max(0, int(py_f - joint_r - 1)), min(height, int(py_f + joint_r + 2))):
            for px in range(max(0, int(px_f - joint_r - 1)), min(width, int(px_f + joint_r + 2))):
                dist = math.sqrt((px + 0.5 - px_f) ** 2 + (py + 0.5 - py_f) ** 2)
                if dist <= joint_r - 0.5:
                    blend_pixel(pixels, width, height, px, py, r, g, b, a)
                elif dist <= joint_r + 0.5:
                    coverage = max(0.0, min(1.0, (joint_r + 0.5 - dist)))
                    aa_val = int(a * coverage)
                    blend_pixel(pixels, width, height, px, py, r, g, b, aa_val)


# ---------------------------------------------------------------------------
# Icon rendering
# ---------------------------------------------------------------------------

def generate_icon(size):
    """
    Generate an icon at the given size.
    Returns a list of (r,g,b,a) tuples.
    """
    pixels = [(0, 0, 0, 0)] * (size * size)

    # Background: filled blue circle
    cx = size / 2.0
    cy = size / 2.0
    radius = size / 2.0 - 0.5

    fill_circle(pixels, size, size, cx, cy, radius, 0x25, 0x63, 0xEB)

    # Chart polyline: stock chart going up
    margin = 0.18
    chart_left = margin
    chart_right = 1.0 - margin
    chart_top = 0.25
    chart_bottom = 0.72

    # Normalized points for the chart (upward trending stock line)
    norm_points = [
        (0.00, 0.55),
        (0.18, 0.70),
        (0.35, 0.45),
        (0.50, 0.60),
        (0.65, 0.30),
        (0.82, 0.15),
        (1.00, 0.25),
    ]

    cw = chart_right - chart_left
    ch = chart_bottom - chart_top
    points = []
    for nx, ny in norm_points:
        px = (chart_left + nx * cw) * size
        py = (chart_top + ny * ch) * size
        points.append((px, py))

    thickness = max(1.2, size / 16.0 * 1.5)

    draw_polyline(pixels, size, size, points, thickness, 255, 255, 255)

    # Small arrowhead at the end of the last segment
    last_x, last_y = points[-2]
    end_x, end_y = points[-1]
    seg_dx = end_x - last_x
    seg_dy = end_y - last_y
    seg_len = math.sqrt(seg_dx * seg_dx + seg_dy * seg_dy)
    if seg_len > 0:
        ndx = seg_dx / seg_len
        ndy = seg_dy / seg_len
        arrow_len = size * 0.08
        px_n = -ndy
        py_n = ndx
        tip_x, tip_y = end_x, end_y
        base_x = tip_x - ndx * arrow_len
        base_y = tip_y - ndy * arrow_len
        wing1 = (base_x + px_n * arrow_len * 0.6, base_y + py_n * arrow_len * 0.6)
        wing2 = (base_x - px_n * arrow_len * 0.6, base_y - py_n * arrow_len * 0.6)
        arrow_thick = max(1.0, thickness * 0.7)
        draw_thick_line(pixels, size, size, tip_x, tip_y, wing1[0], wing1[1],
                        arrow_thick, 255, 255, 255)
        draw_thick_line(pixels, size, size, tip_x, tip_y, wing2[0], wing2[1],
                        arrow_thick, 255, 255, 255)

    return pixels


def main():
    sizes = [16, 32, 48, 128]
    out_dir = os.path.dirname(os.path.abspath(__file__))

    for size in sizes:
        print(f"Generating icon{size}.png ...")
        pixels = generate_icon(size)
        png_data = make_png(size, size, pixels)
        path = os.path.join(out_dir, f"icon{size}.png")
        with open(path, 'wb') as f:
            f.write(png_data)
        print(f"  -> {path} ({len(png_data)} bytes)")

    print("\nAll icons generated successfully.")


if __name__ == '__main__':
    main()
