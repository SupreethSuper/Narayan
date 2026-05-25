# Image-Based Filter Verification Guide

## Overview
This guide explains how to verify your convolution filter designs by converting images to hex values, feeding them through your SystemVerilog design, and converting the results back to images.

## Workflow

```
Original Image
    ↓
[Convert to Hex] (image_hex_converter.py --mode img2hex)
    ↓
Hex Values (SVTestbench)
    ↓
[SystemVerilog Simulation] (scratchpad_image_tb.sv)
    ↓
Output Hex Values (CSV)
    ↓
[Convert to Image] (image_hex_converter.py hex2img)
    ↓
Output Image
    ↓
[Compare] (image_hex_converter.py --mode compare)
```

## Step-by-Step Instructions

### Prerequisites
```bash
pip install Pillow numpy
```

### Step 1: Generate or Prepare Test Image

**Option A: Generate test image automatically**
```bash
python image_hex_converter.py --mode generate --pattern gradient --width 64 --height 64 --output input_image.png
```

Available patterns:
- `gradient` - Rainbow gradient (good for debugging)
- `solid` - Red/Green/Blue blocks
- `checkerboard` - Black and white checkerboard

**Option B: Use existing image**
```bash
# Just make sure image is PNG, JPG, or other standard format
# Image will be resized to match your ROWS x COLS parameters
```

### Step 2: Convert Image to Hex

```bash
python image_hex_converter.py --mode img2hex --input input_image.png --output test_vectors.sv
```

This generates:
- `test_vectors.sv` - SV arrays with hex values
- Console output showing first 10 pixels in hex format

**Output format:**
```systemverilog
localparam int IMG_WIDTH = 64;
localparam int IMG_HEIGHT = 64;
localparam int TOTAL_PIXELS = 4096;

logic [7:0] test_red [0:4095] = '{
    8'h00, 8'h04, 8'h08, 8'h0C, ...
};

logic [7:0] test_green [0:4095] = '{
    8'h00, 8'h04, 8'h08, 8'h0C, ...
};

logic [7:0] test_blue [0:4095] = '{
    8'h00, 8'h04, 8'h08, 8'h0C, ...
};
```

### Step 3: Run Simulation

Compile and simulate with your testbench:

```bash
# In ModelSim or your simulator
do {.\sim_runner.do}
# Or manually:
vlog -sv scratchpad_image_tb.sv
vsim -c scratchpad_image_tb
```

The testbench will generate output CSV files:
- `output_rgb.csv` - RGB test output
- `output_bw.csv` - Black/white test output

**CSV Format:**
```
row,col,red,green,blue
0,0,FF,FF,FF
0,1,FE,FE,FE
0,2,FD,FD,FD
...
```

### Step 4: Convert Output Hex Back to Image

```bash
python image_hex_converter.py --mode hex2img --input output_rgb.csv --output output_image.png --width 64 --height 64
```

This creates `output_image.png` from your simulation hex output.

### Step 5: Compare Results

```bash
python image_hex_converter.py --mode compare --input input_image.png --output output_image.png
```

**Output:**
```
[COMPARISON RESULTS]
Mean Squared Error: 0.00
Max Difference: 0
Dimensions match: True
```

For filters that should pass data through unchanged, MSE should be ~0.
For filters with modifications, you can see exactly how much changed.

## Automation Script

Create a batch file to automate the entire flow:

**run_filter_test.bat** (Windows):
```batch
@echo off
echo [1/5] Generating test image...
python image_hex_converter.py --mode generate --pattern gradient --width 64 --height 64 --output test_input.png

echo [2/5] Converting image to hex...
python image_hex_converter.py --mode img2hex --input test_input.png --output test_vectors.sv

echo [3/5] Running simulation...
vsim -c -do "do {./sim_runner.do}" scratchpad_image_tb

echo [4/5] Converting simulation output back to image...
python image_hex_converter.py --mode hex2img --input output_rgb.csv --output test_output.png --width 64 --height 64

echo [5/5] Comparing results...
python image_hex_converter.py --mode compare --input test_input.png --output test_output.png

echo All done!
```

**run_filter_test.sh** (Linux/Mac):
```bash
#!/bin/bash

echo "[1/5] Generating test image..."
python3 image_hex_converter.py --mode generate --pattern gradient --width 64 --height 64 --output test_input.png

echo "[2/5] Converting image to hex..."
python3 image_hex_converter.py --mode img2hex --input test_input.png --output test_vectors.sv

echo "[3/5] Running simulation..."
vsim -c -do "do {./sim_runner.do}" scratchpad_image_tb

echo "[4/5] Converting simulation output back to image..."
python3 image_hex_converter.py --mode hex2img --input output_rgb.csv --output test_output.png --width 64 --height 64

echo "[5/5] Comparing results..."
python3 image_hex_converter.py --mode compare --input test_input.png --output test_output.png

echo "All done!"
```

## Understanding Hex Format

RGB values are represented as 8-bit (or configurable) hex:
- `0x00` = 0 (black)
- `0x80` = 128 (50% intensity)
- `0xFF` = 255 (full intensity)

Example: `#FF8040` in image format becomes:
- Red: `FF` (255)
- Green: `80` (128)
- Blue: `40` (64)

## Troubleshooting

### Image dimensions don't match
Make sure your test image dimensions match `NAR_MAT_ROWS` and `NAR_MAT_COLS`. The converter will resize if needed but crop might occur.

### Hex values look wrong
- Check that image is in RGB mode (not grayscale, CMYK, etc.)
- Verify bits per channel matches your design (`--bits` parameter)
- Check image file isn't corrupted

### Simulation doesn't generate output CSV
- Verify the testbench calls `write_output_matrix()`
- Check simulation completes without errors
- Make sure output file path is writable

### Output image is completely wrong
- Verify simulation ran correctly (check .wdb file)
- Check matrix dimensions in comparison
- Verify hex-to-image bit depth matches original image

## Example: Testing a Gaussian Blur Filter

```bash
# 1. Create test image with sharp edges
python image_hex_converter.py --mode generate --pattern checkerboard --output blur_test.png

# 2. Convert to hex (Python shows you the values)
python image_hex_converter.py --mode img2hex --input blur_test.png --output blur_vectors.sv

# 3. Run simulation with 3x3 Gaussian blur filter
# (Modify your filter design and testbench accordingly)
# vsim ...

# 4. Convert output back
python image_hex_converter.py --mode hex2img --input output_rgb.csv --output blur_result.png --width 64 --height 64

# 5. Compare - you should see blurred edges!
python image_hex_converter.py --mode compare --input blur_test.png --output blur_result.png

# MSE > 0 shows the filter modified the image (as expected)
```

## Notes

- **Color Bit Depth**: Currently using 8-bit per channel (0-255). For different widths, use `--bits` parameter.
- **Performance**: Very large images (>512x512) may slow simulation. Keep test images reasonably sized.
- **Matrix Broadcasts**: Current `scratchpad` module broadcasts single input to all matrix positions. For filters, you'll need stream data through sequentially.

## File Locations

After running the verification flow:
```
project/
├── input_image.png               # Original test image
├── test_vectors.sv               # Hex vectors for testbench
├── output_rgb.csv                # Simulation output (CSV)
├── output_image.png              # Reconstructed image
└── image_hex_converter.py         # Conversion tool
```

