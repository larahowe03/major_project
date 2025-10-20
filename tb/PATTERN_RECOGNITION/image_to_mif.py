import numpy as np
from PIL import Image
import os

def image_to_grayscale_mif(image_file_name, pixel_bits = 8, resolution = [640, 480]):
    """
    Converts a png to grayscale then saves as .mif file
    FIXED: Correct addressing using image_width instead of image_height
    
    Args:
        image_file_name - Name of the image file located within the local path
        pixel_bits      - Number of bits in the pixel 
        resolution      - 2-element list: resize the input image to (width, height) shape in pixels. Use None to instead use the input image shape.
    """

    img = Image.open(image_file_name)
    if resolution is not None and img.size != resolution:
        img = img.resize(resolution, Image.Resampling.LANCZOS)
    img_rgb = np.array(img.convert("RGB"))
    image_height, image_width, _ = img_rgb.shape
    
    # Save resized image for verification
    img.save("resized_image.png")
    print(f"Saved resized image as resized_image.png ({image_width}x{image_height})")

    scale_factor = 2**pixel_bits / 256

    scaled_img = img_rgb.astype(float).copy()
    gray_scale_img = (0.299 * scaled_img[:, :, 0] + 0.587 * scaled_img[:, :, 1] + 0.114 * scaled_img[:, :, 2]) * scale_factor
    gray_scale_img = gray_scale_img.astype(int)
   
    name, _ = os.path.splitext(image_file_name)

    # Write image data file (pixel indices)
    data_filename = f"image_grayscale.mif"
    print(f"\nWriting image data to {data_filename}")

    WIDTH = pixel_bits
    DEPTH = image_height * image_width

    with open(data_filename, 'w') as f:
        f.write(f"WIDTH={WIDTH};\n") 
        f.write(f"DEPTH={DEPTH};\n")
        f.write("ADDRESS_RADIX=HEX;\n")
        f.write("DATA_RADIX=HEX;\n")
        f.write("CONTENT BEGIN\n")
        
        for i in range(image_height):
            for j in range(image_width):
                pixel_value = gray_scale_img[i][j]
                # FIXED: Use image_width for correct row-major addressing
                address = i * image_width + j
                f.write(f"{address:X}:{pixel_value:02X};\n")
        
        f.write("END;\n")

    print(f"Successfully generated {data_filename}")
    print(f"\nImage dimensions: {image_width} x {image_height}")
    print(f"Total pixels: {DEPTH}")
    print(f"Memory usage: {DEPTH} words of width {WIDTH} = {round(DEPTH*WIDTH/1000)}kb")


# def image_to_rgb_mif(image_file_name, RGB_format = [8,8,8], resolution = [640, 480]):
#     """
#     Convert a png to intel .mif file 
#     FIXED: Correct addressing using image_width instead of image_height

#     Args:
#         image_file_name - Name of the image file located within the local path
#         RGB_format      - 1x3 array which contains the number of bits in the R,G and B values.
#         resolution      - 2-element list: resize the input image to (width, height) shape in pixels. Use None to instead use the input image shape.
#     """

#     img = Image.open(image_file_name)
#     if resolution is not None and img.size != resolution:
#         img = img.resize(resolution, Image.Resampling.LANCZOS)
#     img_rgb = np.array(img.convert("RGB"))
#     image_height, image_width, _ = img_rgb.shape

#     # Optional descale/upscale of RGB values
#     R_scale_factor = 2**(RGB_format[0])/256
#     G_scale_factor = 2**(RGB_format[1])/256
#     B_scale_factor = 2**(RGB_format[2])/256

#     scaled_img = img_rgb.astype(float).copy()
#     scaled_img[:, :, 0] *= R_scale_factor
#     scaled_img[:, :, 1] *= G_scale_factor
#     scaled_img[:, :, 2] *= B_scale_factor

#     scaled_img = scaled_img.astype(np.uint8)
#     name, _ = os.path.splitext(image_file_name)

#     # Write image data file (pixel indices)
#     data_filename = f"{name}.mif"
#     print(f"\nWriting image data to {data_filename}")

#     WIDTH = sum(RGB_format)
#     DEPTH = image_height * image_width

#     with open(data_filename, 'w') as f:
#         f.write(f"WIDTH={WIDTH};\n") 
#         f.write(f"DEPTH={DEPTH};\n")
#         f.write("ADDRESS_RADIX=HEX;\n")
#         f.write("DATA_RADIX=HEX;\n")
#         f.write("CONTENT BEGIN\n")
        
#         for i in range(image_height):
#             for j in range(image_width):
#                 pixel_matrix = scaled_img[i][j]
#                 pixel_value = (pixel_matrix[0] << (RGB_format[1] + RGB_format[2])) | (pixel_matrix[1] << RGB_format[2]) | pixel_matrix[2]
#                 # FIXED: Use image_width for correct row-major addressing
#                 address = i * image_width + j
#                 f.write(f"{address:X}:{pixel_value:02X};\n")
        
#         f.write("END;\n")

#     print(f"Successfully generated {data_filename}")
#     print(f"\nImage dimensions: {image_width} x {image_height}")
#     print(f"Total pixels: {DEPTH}")
#     print(f"Memory usage: {DEPTH} words of width {WIDTH} = {round(DEPTH*WIDTH/1000)}kb")


if __name__ == "__main__":
    image_to_grayscale_mif("original_image.png")