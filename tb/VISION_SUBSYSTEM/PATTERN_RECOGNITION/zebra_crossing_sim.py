import cv2
import numpy as np

test_img_path = "verilog_results/present_edge_aggressive.png"

test_img = cv2.imread(test_img_path, cv2.IMREAD_GRAYSCALE)

print(test_img.shape)

# Create a color image from grayscale
color_img = cv2.cvtColor(test_img, cv2.COLOR_GRAY2BGR)

# Going down the centre column
center_col = 640 // 2

num_stripes = 0

# Track consecutive black pixels
black_streak_start = None
min_stripe_length = 20  # Minimum number of consecutive black pixels to be considered a stripe

for row_idx, row in enumerate(test_img):
    if row[center_col] <= 5:
        # Mark the start of a black streak
        if black_streak_start is None:
            black_streak_start = row_idx
        
        # Turn this pixel green for now
        color_img[row_idx, center_col] = [0, 255, 0]
        
    else:
        # Check if we just ended a black streak
        if black_streak_start is not None:
            black_streak_length = row_idx - black_streak_start
            
            if black_streak_length >= min_stripe_length:
                # Turn the entire stripe red
                for i in range(black_streak_start, row_idx):
                    color_img[i, center_col] = [0, 0, 255]  # Red in BGR
                print(f"*** STRIPE detected! Rows {black_streak_start} to {row_idx - 1} (length: {black_streak_length}) - turned RED ***")
                num_stripes += 1
            
            # Reset streak tracker
            black_streak_start = None
        
        # Color bright pixels blue
        if row[center_col] >= 100:
            color_img[row_idx, center_col] = [255, 0, 0]

# Check for stripe at the end of the image
if black_streak_start is not None:
    black_streak_length = len(test_img) - black_streak_start
    if black_streak_length >= min_stripe_length:
        for i in range(black_streak_start, len(test_img)):
            color_img[i, center_col] = [0, 0, 255]  # Red in BGR
        print(f"*** STRIPE detected at end! Rows {black_streak_start} to {len(test_img) - 1} (length: {black_streak_length}) - turned RED ***")

# Save the new image
output_path = "present_edge_green_marked.png"
cv2.imwrite(output_path, color_img)
print(f"\nImage saved to: {output_path}")
print(num_stripes)