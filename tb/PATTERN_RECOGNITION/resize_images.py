import cv2
import sys

def resize_image(input_path, output_path=None, width=320, height=240):
    """
    Resize an image to specified dimensions.
    
    Args:
        input_path: Path to input image
        output_path: Path to save resized image (optional)
        width: Target width (default: 320)
        height: Target height (default: 240)
    """
    # Read the image
    img = cv2.imread(input_path)
    
    if img is None:
        print(f"Error: Could not load image from {input_path}")
        return False
    
    print(f"Original size: {img.shape[1]}x{img.shape[0]}")
    
    # Resize the image
    resized = cv2.resize(img, (width, height))
    
    print(f"Resized to: {resized.shape[1]}x{resized.shape[0]}")
    
    # Generate output path if not provided
    if output_path is None:
        # Add "_320x240" before the file extension
        parts = input_path.rsplit('.', 1)
        output_path = f"{parts[0]}_320x240.{parts[1]}"
    
    # Save the resized image
    cv2.imwrite(output_path, resized)
    print(f"Saved to: {output_path}")
    
    return True


if __name__ == "__main__":
    # Example usage
    if len(sys.argv) > 1:
        # Use command line argument
        input_image = sys.argv[1]
        output_image = sys.argv[2] if len(sys.argv) > 2 else None
    else:
        # Default example
        input_image = "real_test_images/not_present.jpg"
        output_image = "real_test_images/not_present.jpg"
    
    resize_image(input_image, output_image)