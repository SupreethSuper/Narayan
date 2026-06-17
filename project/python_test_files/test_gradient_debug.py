#!/usr/bin/env python3
"""
Debug script to test gradient image generation and conversion
"""

from image_hex_converter import ImageHexConverter
import numpy as np
from PIL import Image

# Create converter instance
converter = ImageHexConverter(bits_per_channel=8)

# Test 1: Generate gradient image
print("=" * 60)
print("TEST 1: Generating gradient image...")
print("=" * 60)
test_img_path = 'test_gradient_debug.png'
converter.generate_test_image(64, 64, test_img_path, pattern='gradient')

# Test 2: Load and inspect the generated image
print("\n" + "=" * 60)
print("TEST 2: Inspecting generated image...")
print("=" * 60)
img = Image.open(test_img_path)
print(f"Image mode: {img.mode}")
print(f"Image size: {img.size}")

pixels = np.array(img)
print(f"Pixel array shape: {pixels.shape}")
print(f"Pixel dtype: {pixels.dtype}")
print(f"Pixel min: {pixels.min()}, max: {pixels.max()}")

# Print first few pixels
print("\nFirst 5x5 pixels (R, G, B):")
for y in range(min(5, pixels.shape[0])):
    for x in range(min(5, pixels.shape[1])):
        r, g, b = pixels[y, x, 0], pixels[y, x, 1], pixels[y, x, 2]
        print(f"({x},{y}): R={r:3d} G={g:3d} B={b:3d}  ", end="")
    print()

# Test 3: Convert to hex
print("\n" + "=" * 60)
print("TEST 3: Converting image to hex...")
print("=" * 60)
result = converter.image_to_hex(test_img_path, 'test_vectors_debug.sv')

print(f"\nResult arrays:")
print(f"Red array shape: {result['red'].shape}, min: {result['red'].min()}, max: {result['red'].max()}")
print(f"Green array shape: {result['green'].shape}, min: {result['green'].min()}, max: {result['green'].max()}")
print(f"Blue array shape: {result['blue'].shape}, min: {result['blue'].min()}, max: {result['blue'].max()}")

# Test 4: Check SV file was generated
print("\n" + "=" * 60)
print("TEST 4: Checking generated SV file...")
print("=" * 60)
with open('test_vectors_debug.sv', 'r') as f:
    sv_content = f.read()
    # Print first 500 characters
    print("SV file (first 500 chars):")
    print(sv_content[:500])
    print("\n...")

    # Count how many 8'h00 vs non-zero values
    zero_count = sv_content.count("8'h00")
    non_zero_count = sv_content.count("8'h") - zero_count
    print(f"\nZero values (8'h00) count: {zero_count}")
    print(f"Non-zero values count: {non_zero_count}")

print("\n" + "=" * 60)
print("DEBUG TEST COMPLETE")
print("=" * 60)
