import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
from scipy.ndimage import convolve

def apply_kernel(image, kernel, name):
    """Apply a convolution kernel to an image"""
    # Convert to float for processing
    img_float = image.astype(float)
    
    # Apply convolution
    result = convolve(img_float, kernel, mode='constant', cval=0.0)

    # result = convolve(result, np.array([[-1, -2, -1],
    #                                     [ 0,  0,  0],
    #                                     [ 1,  2,  1]]), mode='constant', cval=0.0)

    # Clip to valid range
    result = np.clip(result, 0, 255).astype(np.uint8)
    
    return result

def test_all_kernels(image_path):
    """Test all kernels and display results"""
    
    # Load image and convert to grayscale
    img = Image.open(image_path).convert('L')
    img_array = np.array(img)
    
    # Define all kernels
    kernels = {
        'Original': np.array([[0, 0, 0],
                              [0, 1, 0],
                              [0, 0, 0]]),
        
        'Box Blur': np.array([[1, 1, 1],
                              [1, 1, 1],
                              [1, 1, 1]]) / 9.0,
        
        'Sharpen': np.array([[ 0, -1,  0],
                             [-1,  5, -1],
                             [ 0, -1,  0]]),

        'Edge (Aggressive)': np.array([[-1, -1, -1],
                                       [-1,  8, -1],
                                       [-1, -1, -1]]),
        
        'Edge (Laplacian)': np.array([[ 0, -1,  0],
                                      [-1,  4, -1],
                                      [ 0, -1,  0]]),
        
        'Edge (Gentle)': np.array([[ 0, -1,  0],
                                   [-1,  2, -1],
                                   [ 0, -1,  0]]),
        
        'Sobel X (Vertical Edges)': np.array([[-1, 0, 1],
                                              [-2, 0, 2],
                                              [-1, 0, 1]]),
        
        'Sobel Y (Horizontal Edges)': np.array([[-1, -2, -1],
                                                [ 0,  0,  0],
                                                [ 1,  2,  1]]),
        
        'Prewitt X': np.array([[-1, 0, 1],
                               [-1, 0, 1],
                               [-1, 0, 1]]),
        
        'Emboss': np.array([[-2, -1, 0],
                            [-1,  1, 1],
                            [ 0,  1, 2]]),
    }
    
    # Calculate grid size
    n_kernels = len(kernels)
    n_cols = 3
    n_rows = (n_kernels + n_cols - 1) // n_cols
    
    # Create figure
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(15, 5*n_rows))
    axes = axes.flatten()
    
    # Apply and display each kernel
    for idx, (name, kernel) in enumerate(kernels.items()):
        if name == 'Original':
            result = img_array
        else:
            result = apply_kernel(img_array, kernel, name)
        
        axes[idx].imshow(result, cmap='gray', vmin=0, vmax=255)
        axes[idx].set_title(name, fontsize=12, fontweight='bold')
        axes[idx].axis('off')
        
        # Save individual result
        # Image.fromarray(result).save(f"kernel_{name.replace(' ', '_').replace('(', '').replace(')', '')}.png")
        # print(f"Saved: kernel_{name.replace(' ', '_').replace('(', '').replace(')', '')}.png")
    
    # Hide unused subplots
    for idx in range(len(kernels), len(axes)):
        axes[idx].axis('off')
    
    plt.tight_layout()
    plt.savefig('all_kernels_comparison.png', dpi=150, bbox_inches='tight')
    print("\nSaved comparison image: all_kernels_comparison.png")
    plt.show()

def test_single_kernel(image_path, kernel_name):
    """Test a single kernel"""
    
    img = Image.open(image_path).convert('L')
    img_array = np.array(img)
    
    kernels = {
        'blur': np.array([[1, 1, 1],
                         [1, 1, 1],
                         [1, 1, 1]]) / 9.0,
        
        'sharpen': np.array([[ 0, -1,  0],
                            [-1,  5, -1],
                            [ 0, -1,  0]]),
        
        'edge_aggressive': np.array([[-1, -1, -1],
                                     [-1,  8, -1],
                                     [-1, -1, -1]]),
        
        'edge_gentle': np.array([[ 0, -1,  0],
                                [-1,  2, -1],
                                [ 0, -1,  0]]),
        
        'sobel_x': np.array([[-1, 0, 1],
                            [-2, 0, 2],
                            [-1, 0, 1]]),
        
        'sobel_y': np.array([[-1, -2, -1],
                            [ 0,  0,  0],
                            [ 1,  2,  1]]),
    }
    
    if kernel_name not in kernels:
        print(f"Unknown kernel: {kernel_name}")
        print(f"Available: {list(kernels.keys())}")
        return
    
    result = apply_kernel(img_array, kernels[kernel_name], kernel_name)
    
    # Display
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 6))
    
    ax1.imshow(img_array, cmap='gray')
    ax1.set_title('Original')
    ax1.axis('off')
    
    ax2.imshow(result, cmap='gray')
    ax2.set_title(f'{kernel_name}')
    ax2.axis('off')
    
    plt.tight_layout()
    plt.savefig(f'{kernel_name}_result.png', dpi=150)
    print(f"Saved: {kernel_name}_result.png")
    plt.show()

if __name__ == "__main__":
    test_all_kernels("real_test_images/present.jpg")