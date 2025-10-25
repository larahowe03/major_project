from PIL import Image
import os

def resize_image(input_path, output_path, width=None, height=None, scale=None, maintain_aspect=True):
    """
    Resize an image and save it
    
    Parameters:
    -----------
    input_path : str
        Path to input image
    output_path : str
        Path to save resized image
    width : int, optional
        Target width in pixels
    height : int, optional
        Target height in pixels
    scale : float, optional
        Scale factor (e.g., 0.5 for half size, 2.0 for double)
    maintain_aspect : bool
        If True, maintain aspect ratio when only width or height is specified
    """
    
    # Open the image
    img = Image.open(input_path)
    original_width, original_height = img.size
    
    print(f"Original size: {original_width}x{original_height}")
    
    # Calculate new dimensions
    if scale is not None:
        # Scale by factor
        new_width = int(original_width * scale)
        new_height = int(original_height * scale)
    elif width is not None and height is not None:
        # Both dimensions specified
        new_width = width
        new_height = height
    elif width is not None:
        # Only width specified
        new_width = width
        if maintain_aspect:
            new_height = int(original_height * (width / original_width))
        else:
            new_height = original_height
    elif height is not None:
        # Only height specified
        new_height = height
        if maintain_aspect:
            new_width = int(original_width * (height / original_height))
        else:
            new_width = original_width
    else:
        print("Error: Must specify width, height, or scale")
        return
    
    # Resize the image (LANCZOS is high quality)
    resized_img = img.resize((new_width, new_height), Image.LANCZOS)
    
    print(f"New size: {new_width}x{new_height}")
    
    # Save the resized image
    resized_img.save(output_path)
    print(f"Saved to: {output_path}")
    
    return resized_img

def batch_resize(input_folder, output_folder, width=None, height=None, scale=None):
    """
    Resize all images in a folder
    
    Parameters:
    -----------
    input_folder : str
        Folder containing input images
    output_folder : str
        Folder to save resized images
    width, height, scale : same as resize_image()
    """
    
    # Create output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)
    
    # Supported image formats
    supported_formats = ('.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tiff', '.webp')
    
    # Process all images in folder
    for filename in os.listdir(input_folder):
        if filename.lower().endswith(supported_formats):
            input_path = os.path.join(input_folder, filename)
            output_path = os.path.join(output_folder, filename)
            
            print(f"\nProcessing: {filename}")
            resize_image(input_path, output_path, width, height, scale)

# Example usage
if __name__ == "__main__":
    # Example 1: Resize to specific width (maintains aspect ratio)
    # resize_image("input.jpg", "output_800w.jpg", width=800)
    
    # Example 2: Resize to specific dimensions (stretches if needed)
    resize_image("real_test_images/not_present.png", "output_800x600.jpg", width=640, height=480, maintain_aspect=False)
    
    # Example 3: Scale by factor (50% size)
    # resize_image("input.jpg", "output_half.jpg", scale=0.5)
    
    # Example 4: Scale by factor (200% size)
    # resize_image("input.jpg", "output_double.jpg", scale=2.0)
    
    # Example 5: Batch resize all images in a folder
    # batch_resize("input_folder", "output_folder", width=1024)
    
    print("Uncomment the examples above and modify paths to use the script!")
    print("\nQuick usage:")
    print("  resize_image('input.jpg', 'output.jpg', width=800)  # Resize to 800px wide")
    print("  resize_image('input.jpg', 'output.jpg', scale=0.5)  # Half size")
    print("  batch_resize('my_images', 'resized', width=1024)    # Batch resize folder")