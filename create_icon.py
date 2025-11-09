"""
Create a colorful storybook app icon
Run: python create_icon.py
"""

from PIL import Image, ImageDraw
import os
import math

# Create 1024x1024 icon
size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

center = size // 2

# Draw circular background with purple gradient
for i in range(480, 0, -2):
    progress = i / 480
    r = int(124 + (94 - 124) * progress)
    g = int(77 + (53 - 77) * progress)
    b = int(255 + (190 - 255) * progress)
    draw.ellipse(
        [center - i, center - i, center + i, center + i],
        fill=(r, g, b, 255)
    )

# Draw open book
book_width = 450
book_height = 350
book_x = center - book_width // 2
book_y = center - book_height // 2 + 50

# Left page
draw.rounded_rectangle(
    [book_x, book_y, book_x + book_width // 2 - 10, book_y + book_height],
    radius=15,
    fill=(255, 255, 255, 255)
)

# Right page
draw.rounded_rectangle(
    [book_x + book_width // 2 + 10, book_y, book_x + book_width, book_y + book_height],
    radius=15,
    fill=(255, 255, 255, 255)
)

# Center binding
draw.rectangle(
    [book_x + book_width // 2 - 10, book_y, book_x + book_width // 2 + 10, book_y + book_height],
    fill=(94, 53, 177, 255)
)

# Draw decorative lines on pages (text lines)
line_color = (200, 200, 200, 255)
for i in range(5):
    y_pos = book_y + 80 + i * 50
    # Left page lines
    draw.rectangle(
        [book_x + 30, y_pos, book_x + book_width // 2 - 40, y_pos + 3],
        fill=line_color
    )
    # Right page lines
    draw.rectangle(
        [book_x + book_width // 2 + 40, y_pos, book_x + book_width - 30, y_pos + 3],
        fill=line_color
    )

# Draw stars around the book
star_color = (230, 255, 0, 255)
star_positions = [
    (book_x - 50, book_y + 50),
    (book_x + book_width + 50, book_y + 50),
    (book_x - 30, book_y + book_height - 50),
    (book_x + book_width + 30, book_y + book_height - 50),
    (center, book_y - 80)
]

def draw_star(x, y, size):
    points = []
    for i in range(10):
        angle = math.pi * 2 * i / 10 - math.pi / 2
        radius = size if i % 2 == 0 else size * 0.4
        px = x + math.cos(angle) * radius
        py = y + math.sin(angle) * radius
        points.append((px, py))
    draw.polygon(points, fill=star_color)

for x, y in star_positions:
    draw_star(x, y, 25)

# Draw a small heart on the book cover
heart_x = center
heart_y = book_y + 40
heart_color = (255, 107, 107, 255)
draw.ellipse([heart_x - 25, heart_y - 15, heart_x, heart_y + 10], fill=heart_color)
draw.ellipse([heart_x, heart_y - 15, heart_x + 25, heart_y + 10], fill=heart_color)
draw.polygon([
    (heart_x - 25, heart_y),
    (heart_x, heart_y + 25),
    (heart_x + 25, heart_y)
], fill=heart_color)

# Save
output_path = os.path.join('assets', 'images', 'app_icon.png')
img.save(output_path, 'PNG')
print(f"✓ Icon saved to {output_path}")
print("\nNext step: flutter pub run flutter_launcher_icons")
