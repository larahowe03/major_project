import numpy as np
from PIL import Image
import sys
import os
import re

def mif_to_grayscale_image(mif_file_name, output_image_name=None, resolution=[640, 480]):    
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
            elif "BEGIN" in line:  
                in_content = True
            elif line.startswith("END") or line == "END;":
                break
            elif in_content and ':' in line:
                parts = line.replace(';', '').split(':')
                if len(parts) == 2:
                    try:
                        addr = int(parts[0].strip(), 16)
                        value = int(parts[1].strip(), 16)
                        pixels[addr] = value
                    except ValueError:
                        continue
    
    print(f"MIF Info: WIDTH={width}, DEPTH={depth}")
    print(f"Loaded {len(pixels)} pixels")
    
    # Create image array
    img_array = np.zeros((image_height, image_width), dtype=np.uint8)
    
    # Read data form mif
    for addr, value in pixels.items():
        if addr < image_width * image_height:
            row = addr // image_width
            col = addr % image_width
            img_array[row, col] = value
    
    # Create Image
    img = Image.fromarray(img_array, mode='L')  # 'L' mode for grayscale
        
    # Save image
    img.save(output_image_name)
    print(f"Successfully saved image to {output_image_name}")
    print(f"Image size: {image_width}x{image_height}")
    
    return img

if __name__ == "__main__":
    print("Converting output_image.mif to PNG...")
    mif_to_grayscale_image("verilog_results/blur_thresholded_image.mif", "verilog_results/blur_thresholded_image.png")