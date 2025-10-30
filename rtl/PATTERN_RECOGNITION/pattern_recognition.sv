module pattern_recognition #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,
    parameter W_FRAC = 0,
    // Detection parameters
    parameter WHITE_THRESHOLD = 8'd180,
    parameter BLACK_THRESHOLD = 8'd75,
    parameter MIN_STRIPE_HEIGHT = 4,
    parameter MIN_ALTERNATIONS = 4,
    parameter MIN_COLUMNS_DETECTED = 20,
    parameter SCAN_STEP = 4
)(
    input logic clk,
    input logic rst_n,
    
    // Input pixel stream (from camera)
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Edge detection kernel
    input logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
    
    // Detection outputs (bounding box)
    output logic zebra_detected,
    output logic bbox_valid,
    output logic [$clog2(IMG_WIDTH)-1:0] bbox_x_min,
    output logic [$clog2(IMG_WIDTH)-1:0] bbox_x_max,
    output logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_min,
    output logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_max,
    output logic [$clog2(IMG_WIDTH)-1:0] columns_detected,
    
    // Optional: edge-detected image output
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data
);
    
    // Convolution filter outputs
    logic conv_valid;
    logic conv_ready;
    logic [W-1:0] conv_data;
    
    // Zebra detector outputs
    logic det_valid;
    logic det_ready;
    logic [W-1:0] det_data;
    
    // ========================================================================
    // 1. Convolution Filter (Edge Detection)
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
        .y_valid(conv_valid),
        .y_ready(conv_ready),
        .y_data(conv_data),
        .kernel(kernel)
    );
    
    // ========================================================================
    // 2. Zebra Crossing Detector (with Bounding Box)
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(WHITE_THRESHOLD),
        .BLACK_THRESHOLD(BLACK_THRESHOLD),
        .MIN_STRIPE_HEIGHT(MIN_STRIPE_HEIGHT),
        .MIN_ALTERNATIONS(MIN_ALTERNATIONS),
        .MIN_COLUMNS_DETECTED(MIN_COLUMNS_DETECTED),
        .SCAN_STEP(SCAN_STEP)
    ) zebra_detector (
        .clk(clk),
        .rst_n(rst_n),
        
        // Input from convolution filter
        .x_valid(conv_valid),
        .x_ready(conv_ready),
        .x_data(conv_data),
        
        // Pass-through output
        .y_valid(det_valid),
        .y_ready(det_ready),
        .y_data(det_data),
        
        // Bounding box outputs
        .bbox_valid(bbox_valid),
        .bbox_x_min(bbox_x_min),
        .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min),
        .bbox_y_max(bbox_y_max),
        .zebra_detected(zebra_detected),
        .columns_detected_count(columns_detected)
    );
    
    // ========================================================================
    // 3. Output Assignment
    // ========================================================================
    
    // Pass through the edge-detected image (or detector output)
    assign y_valid = det_valid;
    assign y_data = det_data;
    assign det_ready = y_ready;

endmodule