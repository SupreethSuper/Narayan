#!/usr/bin/env python3
"""
Image <-> Hex Converter for SystemVerilog Filter Verification
Converts images to/from hex values for testbench simulation
"""

import argparse
from PIL import Image
import numpy as np
from pathlib import Path
import csv

class ImageHexConverter:
    def __init__(self, bits_per_channel=8):
        self.bits_per_channel = bits_per_channel
        self.max_value = (1 << bits_per_channel) - 1

    def image_to_hex(self, image_path, output_sv_file=None):
        """
        Convert image to hex values and optionally generate SV testbench vectors

        Args:
            image_path: Path to input image
            output_sv_file: Optional path to write SV format vectors

        Returns:
            dict with image info and hex arrays
        """
        img = Image.open(image_path)
        print(f"[INFO] Loaded image: {image_path}")
        print(f"[INFO] Size: {img.size[0]}x{img.size[1]} pixels")
        print(f"[INFO] Mode: {img.mode}")

        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
            print(f"[INFO] Converted to RGB")

        # Get pixel data
        pixels = np.array(img, dtype=np.float32)
        height, width, channels = pixels.shape

        # Normalize to bit depth (with explicit float arithmetic)
        normalized = (pixels * self.max_value / 255.0).astype(np.uint8)

        result = {
            'width': width,
            'height': height,
            'red': normalized[:, :, 0],
            'green': normalized[:, :, 1],
            'blue': normalized[:, :, 2],
            'image_array': normalized
        }

        # Print hex values
        print(f"\n[HEX VALUES] - First 10 pixels:")
        print("Index\tRed\tGreen\tBlue")
        for i in range(min(10, width * height)):
            r = result['red'].flat[i]
            g = result['green'].flat[i]
            b = result['blue'].flat[i]
            print(f"{i}\t0x{r:02X}\t0x{g:02X}\t0x{b:02X}")

        if output_sv_file:
            self._write_sv_vectors(result, output_sv_file)

        return result

    def hex_to_image(self, csv_path, output_path, width, height):
        """
        Convert CSV hex values back to image

        Args:
            csv_path: Path to CSV file with row,col,red,green,blue format
            output_path: Where to save the image
            width: Image width
            height: Image height
        """
        # Initialize arrays
        red_array = np.zeros((height, width), dtype=np.uint8)
        green_array = np.zeros((height, width), dtype=np.uint8)
        blue_array = np.zeros((height, width), dtype=np.uint8)

        # Read CSV and populate arrays
        pixel_count = 0
        try:
            with open(csv_path, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    try:
                        row_idx = int(row['row'])
                        col_idx = int(row['col'])
                        red = int(row['red'], 16)
                        green = int(row['green'], 16)
                        blue = int(row['blue'], 16)
                        
                        if 0 <= row_idx < height and 0 <= col_idx < width:
                            red_array[row_idx, col_idx] = red
                            green_array[row_idx, col_idx] = green
                            blue_array[row_idx, col_idx] = blue
                            pixel_count += 1
                    except (ValueError, KeyError) as e:
                        print(f"[WARNING] Skipping malformed row: {row}")
                        continue
        except FileNotFoundError:
            print(f"[ERROR] CSV file not found: {csv_path}")
            return None

        print(f"[INFO] Read {pixel_count} pixels from {csv_path}")

        # Stack into RGB image
        rgb_array = np.stack([red_array, green_array, blue_array], axis=2)

        # Create and save image
        img = Image.fromarray(rgb_array, 'RGB')
        img.save(output_path)
        print(f"[INFO] Saved image: {output_path}")

        return img

    def _write_sv_vectors(self, image_data, output_file):
        """Write hex values in SystemVerilog testbench format"""
        width = image_data['width']
        height = image_data['height']

        with open(output_file, 'w') as f:
            f.write(f"// Auto-generated SV testbench vectors from image\n")
            f.write(f"// Image size: {width}x{height}\n\n")

            f.write(f"localparam int IMG_WIDTH = {width};\n")
            f.write(f"localparam int IMG_HEIGHT = {height};\n")
            f.write(f"localparam int TOTAL_PIXELS = {width * height};\n\n")

            # Flatten arrays
            red_flat = image_data['red'].flatten()
            green_flat = image_data['green'].flatten()
            blue_flat = image_data['blue'].flatten()

            # Write as arrays
            f.write(f"logic [7:0] test_red [0:{len(red_flat)-1}] = '{{\n")
            for i in range(0, len(red_flat), 16):
                chunk = red_flat[i:i+16]
                hex_str = ", ".join([f"8'h{val:02X}" for val in chunk])
                f.write(f"    {hex_str}" + ("" if i + 16 < len(red_flat) else ""))
                f.write(",\n" if i + 16 < len(red_flat) else "\n")
            f.write("};\n\n")

            f.write(f"logic [7:0] test_green [0:{len(green_flat)-1}] = '{{\n")
            for i in range(0, len(green_flat), 16):
                chunk = green_flat[i:i+16]
                hex_str = ", ".join([f"8'h{val:02X}" for val in chunk])
                f.write(f"    {hex_str}" + ("" if i + 16 < len(green_flat) else ""))
                f.write(",\n" if i + 16 < len(green_flat) else "\n")
            f.write("};\n\n")

            f.write(f"logic [7:0] test_blue [0:{len(blue_flat)-1}] = '{{\n")
            for i in range(0, len(blue_flat), 16):
                chunk = blue_flat[i:i+16]
                hex_str = ", ".join([f"8'h{val:02X}" for val in chunk])
                f.write(f"    {hex_str}" + ("" if i + 16 < len(blue_flat) else ""))
                f.write(",\n" if i + 16 < len(blue_flat) else "\n")
            f.write("};\n")

        print(f"[INFO] Generated SV vectors: {output_file}")

    def generate_test_image(self, width, height, output_path, pattern='gradient'):
        """Generate test images for verification"""
        if pattern == 'gradient':
            # Rainbow gradient
            img_array = np.zeros((height, width, 3), dtype=np.uint8)
            for y in range(height):
                for x in range(width):
                    img_array[y, x, 0] = int(255.0 * x / width)      # Red gradient (left to right)
                    img_array[y, x, 1] = int(255.0 * y / height)     # Green gradient (top to bottom)
                    img_array[y, x, 2] = int(255.0 * (1.0 - x/width))  # Blue gradient (right to left)

        elif pattern == 'solid':
            # Solid color blocks
            img_array = np.zeros((height, width, 3), dtype=np.uint8)
            h_block = height // 3
            img_array[0:h_block, :] = [255, 0, 0]        # Red
            img_array[h_block:2*h_block, :] = [0, 255, 0]  # Green
            img_array[2*h_block:, :] = [0, 0, 255]       # Blue

        elif pattern == 'checkerboard':
            # Checkerboard pattern
            img_array = np.zeros((height, width, 3), dtype=np.uint8)
            block_size = 8
            for y in range(height):
                for x in range(width):
                    if ((x // block_size) + (y // block_size)) % 2 == 0:
                        img_array[y, x] = [255, 255, 255]  # White
                    else:
                        img_array[y, x] = [0, 0, 0]        # Black

        img = Image.fromarray(img_array, 'RGB')
        img.save(output_path)
        print(f"[INFO] Generated test image ({pattern}): {output_path}")
        return img_array

    def compare_images(self, image1_path, image2_path):
        """Compare input and output images for filter verification"""
        img1 = Image.open(image1_path).convert('RGB')
        img2 = Image.open(image2_path).convert('RGB')

        arr1 = np.array(img1)
        arr2 = np.array(img2)

        if arr1.shape != arr2.shape:
            print(f"[ERROR] Image dimensions don't match: {arr1.shape} vs {arr2.shape}")
            return None

        # Calculate differences
        diff = np.abs(arr1.astype(int) - arr2.astype(int))
        mse = np.mean(diff**2)
        max_diff = np.max(diff)

        print(f"\n[COMPARISON RESULTS]")
        print(f"Mean Squared Error: {mse:.2f}")
        print(f"Max Difference: {max_diff}")
        print(f"Dimensions match: {arr1.shape == arr2.shape}")

        return {
            'mse': mse,
            'max_diff': max_diff,
            'diff_array': diff
        }


def main():
    parser = argparse.ArgumentParser(
        description='Convert images to/from hex for SystemVerilog filter testing'
    )

    parser.add_argument('--mode', choices=['img2hex', 'hex2img', 'generate', 'compare'],
                        required=True, help='Operation mode')
    parser.add_argument('--input', help='Input image file or CSV file')
    parser.add_argument('--output', help='Output file')
    parser.add_argument('--width', type=int, default=64, help='Image width (for hex2img)')
    parser.add_argument('--height', type=int, default=64, help='Image height (for hex2img)')
    parser.add_argument('--bits', type=int, default=8, help='Bits per channel')
    parser.add_argument('--pattern', choices=['gradient', 'solid', 'checkerboard'],
                        default='gradient', help='Test pattern (for generate)')

    args = parser.parse_args()

    converter = ImageHexConverter(bits_per_channel=args.bits)

    if args.mode == 'img2hex':
        if not args.input or not args.output:
            print("[ERROR] --input and --output required for img2hex mode")
            return
        converter.image_to_hex(args.input, args.output.replace('.png', '.sv'))
        print(f"[SUCCESS] Hex output file: {args.output.replace('.png', '.sv')}")

    elif args.mode == 'hex2img':
        if not args.input or not args.output:
            print("[ERROR] --input and --output required for hex2img mode")
            print("Usage: python image_hex_converter.py --mode hex2img --input output_rgb.csv --output result.png --width 64 --height 64")
            return
        converter.hex_to_image(args.input, args.output, args.width, args.height)
        print(f"[SUCCESS] Image output file: {args.output}")

    elif args.mode == 'generate':
        if not args.output:
            args.output = f'test_image_{args.pattern}.png'
        converter.generate_test_image(args.width, args.height, args.output, args.pattern)

    elif args.mode == 'compare':
        if not args.input or not args.output:
            print("[ERROR] --input and --output required for compare mode")
            return
        converter.compare_images(args.input, args.output)


if __name__ == '__main__':
    main()
