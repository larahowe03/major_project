module zebra_crossing_detector #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter W = 8
)(
    input logic clk,
    input logic rst_n,
    
    // Input from convolution filter (edge-detected pixels)
    input logic pixel_valid,
    input logic [W-1:0] edge_pixel,
    
    // Outputs
    output logic crossing_detected,
    output logic detection_valid,  // Pulses high when new detection is ready
    output logic [7:0] stripe_count,  // Number of stripes detected (for debugging)
    output logic [15:0] confidence    // Detection confidence score
);

    // ========================================================================
    // Position tracking
    // ========================================================================
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
        end else if (pixel_valid) begin
            if (x_pos == IMG_WIDTH - 1) begin
                x_pos <= '0;
                y_pos <= (y_pos == IMG_HEIGHT - 1) ? '0 : y_pos + 1;
            end else begin
                x_pos <= x_pos + 1;
            end
        end
    end
    
    // ========================================================================
    // Detection parameters
    // ========================================================================
    localparam EDGE_THRESHOLD = 8'd50;      // Pixel value above this = "is edge"
    localparam MIN_EDGES_PER_ROW = 80;      // Min edges to count as stripe row
    localparam MIN_STRIPES = 4;             // Min stripe rows for crossing
    localparam MAX_STRIPES = 15;            // Max stripe rows for crossing
    
    // Divide image into multiple scan regions to handle rotation
    localparam NUM_SCAN_LINES = 5;
    
    // ========================================================================
    // Multi-region analysis for rotation handling
    // ========================================================================
    
    // Scan lines at different heights to detect angled crossings
    logic [15:0] edge_count_per_scanline [0:NUM_SCAN_LINES-1];
    logic [$clog2(IMG_HEIGHT)-1:0] scan_y [0:NUM_SCAN_LINES-1];
    
    // Define scan line positions (spread across bottom 2/3 of image)
    initial begin
        scan_y[0] = IMG_HEIGHT * 1 / 3;
        scan_y[1] = IMG_HEIGHT * 2 / 5;
        scan_y[2] = IMG_HEIGHT * 1 / 2;
        scan_y[3] = IMG_HEIGHT * 3 / 5;
        scan_y[4] = IMG_HEIGHT * 2 / 3;
    end
    
    // ========================================================================
    // Diagonal stripe detection using column slices
    // ========================================================================
    
    // Divide width into vertical slices to detect diagonal patterns
    localparam NUM_SLICES = 8;
    localparam SLICE_WIDTH = IMG_WIDTH / NUM_SLICES;
    
    logic [11:0] edge_density_per_slice [0:NUM_SLICES-1];  // Edge count per vertical slice
    logic [$clog2(NUM_SLICES)-1:0] current_slice;
    
    assign current_slice = x_pos / SLICE_WIDTH;
    
    // ========================================================================
    // Edge density analysis (rotation-invariant)
    // ========================================================================
    
    logic [15:0] total_edges;
    logic [7:0] stripe_rows;
    logic [15:0] edges_in_row;
    
    logic in_roi;  // Are we in region of interest (bottom 2/3)?
    assign in_roi = (y_pos >= IMG_HEIGHT / 3);
    
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edges_in_row <= '0;
            stripe_rows <= '0;
            total_edges <= '0;
            crossing_detected <= 1'b0;
            detection_valid <= 1'b0;
            stripe_count <= '0;
            confidence <= '0;
            
            for (i = 0; i < NUM_SCAN_LINES; i = i + 1) begin
                edge_count_per_scanline[i] <= '0;
            end
            
            for (i = 0; i < NUM_SLICES; i = i + 1) begin
                edge_density_per_slice[i] <= '0;
            end
            
        end else begin
            detection_valid <= 1'b0;  // Default: pulse low
            
            if (pixel_valid) begin
                // Count edges in current position
                if (in_roi && edge_pixel > EDGE_THRESHOLD) begin
                    edges_in_row <= edges_in_row + 1;
                    total_edges <= total_edges + 1;
                    
                    // Update slice density
                    if (current_slice < NUM_SLICES)
                        edge_density_per_slice[current_slice] <= edge_density_per_slice[current_slice] + 1;
                    
                    // Update scan line counts
                    for (i = 0; i < NUM_SCAN_LINES; i = i + 1) begin
                        if (y_pos == scan_y[i])
                            edge_count_per_scanline[i] <= edge_count_per_scanline[i] + 1;
                    end
                end
                
                // End of row?
                if (x_pos == IMG_WIDTH - 1) begin
                    // Check if this row had enough edges to be a stripe
                    if (in_roi && edges_in_row > MIN_EDGES_PER_ROW) begin
                        stripe_rows <= stripe_rows + 1;
                    end
                    // Reset counter for next row
                    edges_in_row <= '0;
                end
                
                // End of frame?
                if (x_pos == IMG_WIDTH - 1 && y_pos == IMG_HEIGHT - 1) begin
                    // ====== Detection Algorithm ======
                    
                    // Method 1: Row-based detection (works for horizontal crossings)
                    logic method1_detect;
                    method1_detect = (stripe_rows >= MIN_STRIPES && stripe_rows <= MAX_STRIPES);
                    
                    // Method 2: Scan line analysis (works for angled crossings)
                    // Check if multiple scan lines have high edge density
                    logic [3:0] active_scanlines;
                    active_scanlines = 0;
                    for (i = 0; i < NUM_SCAN_LINES; i = i + 1) begin
                        if (edge_count_per_scanline[i] > 50)  // Threshold for "has edges"
                            active_scanlines = active_scanlines + 1;
                    end
                    logic method2_detect;
                    method2_detect = (active_scanlines >= 3);
                    
                    // Method 3: Slice distribution (checks for consistent pattern across width)
                    // For zebra crossing, expect similar edge density across slices
                    logic method3_detect;
                    logic [3:0] active_slices;
                    active_slices = 0;
                    for (i = 0; i < NUM_SLICES; i = i + 1) begin
                        if (edge_density_per_slice[i] > 100)  // Has significant edges
                            active_slices = active_slices + 1;
                    end
                    method3_detect = (active_slices >= 4);  // At least half the slices
                    
                    // Method 4: Overall edge density
                    logic method4_detect;
                    method4_detect = (total_edges > 2000 && total_edges < 15000);  // Reasonable range
                    
                    // Combine methods (at least 2 must agree)
                    logic [2:0] vote;
                    vote = {2'b0, method1_detect} + {2'b0, method2_detect} + 
                           {2'b0, method3_detect} + {2'b0, method4_detect};
                    
                    crossing_detected <= (vote >= 2);
                    
                    // Calculate confidence (0-255)
                    confidence <= {vote, 6'b0} + stripe_rows;  // Simple confidence metric
                    
                    // Output stripe count
                    stripe_count <= stripe_rows;
                    
                    // Signal that detection is ready
                    detection_valid <= 1'b1;
                    
                    // Reset for next frame
                    stripe_rows <= '0;
                    total_edges <= '0;
                    for (i = 0; i < NUM_SCAN_LINES; i = i + 1) begin
                        edge_count_per_scanline[i] <= '0;
                    end
                    for (i = 0; i < NUM_SLICES; i = i + 1) begin
                        edge_density_per_slice[i] <= '0;
                    end
                end
            end
        end
    end

endmodule


// ============================================================================
// Top-level module connecting convolution filter to zebra detector
// ============================================================================

module zebra_crossing_system #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,
    parameter W_FRAC = 0
)(
    input logic clk,
    input logic rst_n,
    
    // Input pixel stream (from camera)
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Edge detection kernel
    input logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
    
    // Detection outputs
    output logic crossing_detected,
    output logic detection_valid,
    output logic [7:0] stripe_count,
    
    // Optional: edge-detected image output
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data
);

    // ========================================================================
    // Instantiate convolution filter
    // ========================================================================
    convolution_filter #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .KERNEL_H(KERNEL_H),
        .KERNEL_W(KERNEL_W),
        .W(W),
        .W_FRAC(W_FRAC)
    ) edge_filter (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        .y_valid(y_valid),
        .y_ready(y_ready),
        .y_data(y_data),
        .kernel(kernel)
    );
    
    // ========================================================================
    // Instantiate zebra crossing detector
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W)
    ) detector (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(y_valid && y_ready),  // Connect to filter output
        .edge_pixel(y_data),
        .crossing_detected(crossing_detected),
        .detection_valid(detection_valid),
        .stripe_count(stripe_count)
    );

endmodule