import numpy as np
from PIL import Image
import sys
import os
import re

def mif_to_grayscale_image(mif_file_name, output_image_name=None, resolution=[640, 480]):
    """
    Convert a grayscale .mif file back to a PNG image
    
    Args:
        mif_file_name     - Name of the .mif file to read
        output_image_name - Name for output PNG (default: adds _output.png to input name)
        resolution        - [width, height] of the image
    """
    
    image_width, image_height = resolution
    
    # Parse MIF file
    print(f"Reading MIF file: {mif_file_name}")
    
    width = None
    depth = None
    pixels = {}
    
    with open(mif_file_name, 'r') as f:
        in_content = False
        
        for line in f:
            line = line.strip()
            
            # Parse header
            if line.startswith("WIDTH"):
                width = int(re.search(r'\d+', line).group())
            elif line.startswith("DEPTH"):
                depth = int(re.search(r'\d+', line).group())
            elif "BEGIN" in line:  # Handle both "CONTENT BEGIN" and "BEGIN"
                in_content = True
            elif line.startswith("END") or line == "END;":
                break
            elif in_content and ':' in line:
                # Parse data line: "address : value;" or "address:value;"
                parts = line.replace(';', '').split(':')
                if len(parts) == 2:
                    try:
                        addr = int(parts[0].strip(), 16)
                        value = int(parts[1].strip(), 16)
                        pixels[addr] = value
                    except ValueError:
                        # Skip lines that can't be parsed as hex
                        continue
    
    print(f"MIF Info: WIDTH={width}, DEPTH={depth}")
    print(f"Loaded {len(pixels)} pixels")
    
    # Create image array
    img_array = np.zeros((image_height, image_width), dtype=np.uint8)
    
    # Fill image array from pixel data
    for addr, value in pixels.items():
        if addr < image_width * image_height:
            # Convert linear address to (row, col)
            # Fixed: Use image_width for proper row-major addressing
            row = addr // image_width
            col = addr % image_width
            img_array[row, col] = value
    
    # Create PIL Image
    img = Image.fromarray(img_array, mode='L')  # 'L' mode for grayscale
    
    # Generate output filename
    if output_image_name is None:
        name, _ = os.path.splitext(mif_file_name)
        output_image_name = f"{name}_output.png"
    
    # Save image
    img.save(output_image_name)
    print(f"Successfully saved image to {output_image_name}")
    print(f"Image size: {image_width}x{image_height}")
    
    return img


def mif_to_rgb_image(mif_file_name, output_image_name=None, RGB_format=[8,8,8], resolution=[640, 480]):
    """
    Convert an RGB .mif file back to a PNG image
    
    Args:
        mif_file_name     - Name of the .mif file to read
        output_image_name - Name for output PNG (default: adds _output.png to input name)
        RGB_format        - [R_bits, G_bits, B_bits] format
        resolution        - [width, height] of the image
    """
    
    image_width, image_height = resolution
    
    # Parse MIF file
    print(f"Reading MIF file: {mif_file_name}")
    
    width = None
    depth = None
    pixels = {}
    
    with open(mif_file_name, 'r') as f:
        in_content = False
        
        for line in f:
            line = line.strip()
            
            # Parse header
            if line.startswith("WIDTH"):
                width = int(re.search(r'\d+', line).group())
            elif line.startswith("DEPTH"):
                depth = int(re.search(r'\d+', line).group())
            elif line.startswith("CONTENT BEGIN"):
                in_content = True
            elif line.startswith("END"):
                break
            elif in_content and ':' in line:
                # Parse data line: "address:value;"
                parts = line.replace(';', '').split(':')
                if len(parts) == 2:
                    addr = int(parts[0].strip(), 16)
                    value = int(parts[1].strip(), 16)
                    pixels[addr] = value
    
    print(f"MIF Info: WIDTH={width}, DEPTH={depth}")
    print(f"Loaded {len(pixels)} pixels")
    
    # Create image array
    img_array = np.zeros((image_height, image_width, 3), dtype=np.uint8)
    
    # Extract RGB bit positions
    R_bits, G_bits, B_bits = RGB_format
    B_mask = (1 << B_bits) - 1
    G_mask = (1 << G_bits) - 1
    R_mask = (1 << R_bits) - 1
    
    # Scale factors to convert back to 8-bit
    R_scale = 256 / (2 ** R_bits)
    G_scale = 256 / (2 ** G_bits)
    B_scale = 256 / (2 ** B_bits)
    
    # Fill image array from pixel data
    for addr, pixel_value in pixels.items():
        if addr < image_width * image_height:
            # Convert linear address to (row, col)
            row = addr // image_width
            col = addr % image_width
            
            # Extract RGB components
            B = (pixel_value) & B_mask
            G = (pixel_value >> B_bits) & G_mask
            R = (pixel_value >> (B_bits + G_bits)) & R_mask
            
            # Scale back to 8-bit and store
            img_array[row, col, 0] = int(R * R_scale)
            img_array[row, col, 1] = int(G * G_scale)
            img_array[row, col, 2] = int(B * B_scale)
    
    # Create PIL Image
    img = Image.fromarray(img_array, mode='RGB')
    
    # Generate output filename
    if output_image_name is None:
        name, _ = os.path.splitext(mif_file_name)
        output_image_name = f"{name}_output.png"
    
    # Save image
    img.save(output_image_name)
    print(f"Successfully saved image to {output_image_name}")
    print(f"Image size: {image_width}x{image_height}")
    
    return img


if __name__ == "__main__":
    # Example usage
    if len(sys.argv) > 1:
        mif_file = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else None
        
        # Try to detect if it's RGB or grayscale from WIDTH
        with open(mif_file, 'r') as f:
            for line in f:
                if line.startswith("WIDTH"):
                    width = int(re.search(r'\d+', line).group())
                    if width == 8:
                        print("Detected grayscale format (8-bit)")
                        mif_to_grayscale_image(mif_file, output_file)
                    else:
                        print(f"Detected RGB format ({width}-bit)")
                        mif_to_rgb_image(mif_file, output_file)
                    break
    else:
        # Default: convert output_image.mif from your testbench
        print("Converting output_image.mif to PNG...")
        mif_to_grayscale_image("laplacian.mif", "laplacian.png")