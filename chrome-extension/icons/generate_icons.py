#!/usr/bin/env python3
"""
Generate PNG icons for EasyMQL Chrome Extension.
Uses only built-in Python modules (no PIL/Pillow required).
Generates valid PNG files with a blue circle background and white stock chart polyline.
"""

import struct
import zlib
import math
import os

def create_png(width, height, pixels):
    """Create a PNG file from raw RGBA pixel data."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack('>I', len(data)) + c + crc

    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'

    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    ihdr = chunk(b'IHDR', ihdr_data)

    # IDAT chunk - pixel data with filter bytes
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # No filter for this row
        for x in range(width):
            idx = (y * width + x) * 4
            raw_data += bytes(pixels[idx:idx+4])

    compressed = zlib.compress(raw_data, 9)
    idat = chunk(b'IDAT', compressed)

    # IEND chunk
    iend = chunk(b'IEND', b'')

    return signature + ihdr + idat + iend


def draw_icon(size):
    """Draw the EasyMQL icon at the given size."""
    pixels = [0] * (size * size * 4)

    cx, cy = size / 2.0, size / 2.0
    radius = size / 2.0 - 0.5

    # Background color: #2563eb (dark blue)
    bg_r, bg_g, bg_b = 0x25, 0x63, 0xEB

    # Draw the blue circle background
    for y in range(size):
        for x in range(size):
            dx = x - cx + 0.5
            dy = y - cy + 0.5
            dist = math.sqrt(dx * dx + dy * dy)

            idx = (y * size + x) * 4

            if dist <= radius - 0.8:
                # Fully inside circle
                pixels[idx]     = bg_r
                pixels[idx + 1] = bg_g
                pixels[idx + 2] = bg_b
                pixels[idx + 3] = 255
            elif dist <= radius + 0.8:
                # Anti-aliased edge
                alpha = max(0.0, min(1.0, (radius + 0.8 - dist) / 1.6))
                pixels[idx]     = bg_r
                pixels[idx + 1] = bg_g
                pixels[idx + 2] = bg_b
                pixels[idx + 3] = int(alpha * 255)
            else:
                # Outside circle - transparent
                pixels[idx]     = 0
                pixels[idx + 1] = 0
                pixels[idx + 2] = 0
                pixels[idx + 3] = 0

    # Define the stock chart polyline points (normalized 0..1)
    # A line that dips, recovers, dips slightly, then goes up strongly
    chart_points = [
        (0.15, 0.55),
        (0.25, 0.60),
        (0.32, 0.50),
        (0.40, 0.65),
        (0.48, 0.45),
        (0.55, 0.55),
        (0.62, 0.40),
        (0.72, 0.50),
        (0.80, 0.30),
        (0.87, 0.25),
    ]

    # Scale points to pixel coordinates
    scaled_points = [(px * size, py * size) for (px, py) in chart_points]

    # Determine line thickness based on icon size
    if size <= 16:
        thickness = 1.5
    elif size <= 32:
        thickness = 2.0
    elif size <= 48:
        thickness = 2.8
    else:
        thickness = 4.5

    # Draw the white polyline with anti-aliasing
    def draw_line_segment(x0, y0, x1, y1, thickness, pixels, size):
        """Draw an anti-aliased line segment."""
        # Bounding box with padding
        pad = thickness + 2
        min_x = max(0, int(min(x0, x1) - pad))
        max_x = min(size - 1, int(max(x0, x1) + pad))
        min_y = max(0, int(min(y0, y1) - pad))
        max_y = min(size - 1, int(max(y0, y1) + pad))

        dx = x1 - x0
        dy = y1 - y0
        length = math.sqrt(dx * dx + dy * dy)
        if length < 0.001:
            return

        # Normal vector
        nx = -dy / length
        ny = dx / length

        half_t = thickness / 2.0

        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                px = x + 0.5
                py = y + 0.5

                # Project point onto line segment
                t = ((px - x0) * dx + (py - y0) * dy) / (length * length)
                t = max(0.0, min(1.0, t))

                # Closest point on segment
                closest_x = x0 + t * dx
                closest_y = y0 + t * dy

                # Distance from pixel to closest point
                dist = math.sqrt((px - closest_x) ** 2 + (py - closest_y) ** 2)

                if dist <= half_t + 0.8:
                    # Calculate alpha for anti-aliasing
                    if dist <= half_t - 0.8:
                        alpha = 1.0
                    else:
                        alpha = max(0.0, min(1.0, (half_t + 0.8 - dist) / 1.6))

                    idx = (y * size + x) * 4
                    # Only draw on the circle (where alpha > 0)
                    if pixels[idx + 3] > 0:
                        # Blend white line over blue background
                        existing_r = pixels[idx]
                        existing_g = pixels[idx + 1]
                        existing_b = pixels[idx + 2]

                        pixels[idx]     = int(existing_r * (1 - alpha) + 255 * alpha)
                        pixels[idx + 1] = int(existing_g * (1 - alpha) + 255 * alpha)
                        pixels[idx + 2] = int(existing_b * (1 - alpha) + 255 * alpha)

    # Draw each line segment of the polyline
    for i in range(len(scaled_points) - 1):
        x0, y0 = scaled_points[i]
        x1, y1 = scaled_points[i + 1]
        draw_line_segment(x0, y0, x1, y1, thickness, pixels, size)

    # Draw small circles at each point (dot markers) for larger sizes
    if size >= 48:
        dot_radius = thickness * 0.5
        for (px, py) in scaled_points:
            for y in range(max(0, int(py - dot_radius - 2)), min(size, int(py + dot_radius + 2))):
                for x in range(max(0, int(px - dot_radius - 2)), min(size, int(px + dot_radius + 2))):
                    dist = math.sqrt((x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2)
                    if dist <= dot_radius + 0.8:
                        alpha = 1.0 if dist <= dot_radius - 0.5 else max(0.0, (dot_radius + 0.8 - dist) / 1.3)
                        idx = (y * size + x) * 4
                        if pixels[idx + 3] > 0:
                            existing_r = pixels[idx]
                            existing_g = pixels[idx + 1]
                            existing_b = pixels[idx + 2]
                            pixels[idx]     = int(existing_r * (1 - alpha) + 255 * alpha)
                            pixels[idx + 1] = int(existing_g * (1 - alpha) + 255 * alpha)
                            pixels[idx + 2] = int(existing_b * (1 - alpha) + 255 * alpha)

    return pixels


def main():
    sizes = [16, 32, 48, 128]
    script_dir = os.path.dirname(os.path.abspath(__file__))

    for size in sizes:
        print(f"Generating icon{size}.png ({size}x{size})...")
        pixels = draw_icon(size)
        png_data = create_png(size, size, pixels)

        filepath = os.path.join(script_dir, f"icon{size}.png")
        with open(filepath, 'wb') as f:
            f.write(png_data)
        print(f"  -> Saved {filepath} ({len(png_data)} bytes)")

    print("\nAll icons generated successfully!")


if __name__ == '__main__':
    main()
