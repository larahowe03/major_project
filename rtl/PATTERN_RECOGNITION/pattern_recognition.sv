module pattern_recognition #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
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
    output logic [7:0] long_run_count,
    
    // Optional: edge-detected image output
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data
);
    
    logic conv_valid;
    logic conv_ready;
    logic [W-1:0] conv_data;
    
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
        .y_valid(conv_valid),
        .y_ready(conv_ready),
        .y_data(conv_data),
        .kernel(kernel)
    );
    
    // Pass convolution output to module outputs
    assign y_valid = conv_valid;
    assign y_data = conv_data;
    assign conv_ready = y_ready;
            
    // Zebra crossing detector
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .MIN_RUN_LENGTH(50),      // Minimum pixels for a valid stripe
        .MIN_STRIPES(3)           // Need at least 3 stripes for zebra crossing
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        
        // Input stream
        .x_valid(conv_valid),
        .x_ready(), // TODO
        .x_data(conv_data),
        
        // Output stream (pass-through)
        .y_valid(),
        .y_ready(conv_ready),
        .y_data(),
        
        // Detection outputs
        .is_white(),                              // Current pixel is white
        .white_count(),  // Total white pixels in frame
        .max_connected(), // Longest white run
        .current_run(),   // Current white run length
        
        // Zebra crossing detection
        .long_run_count(long_run_count),                 // Number of long runs found
        .zebra_detected(crossing_detected),                       // Zebra crossing detected (≥3 long runs)
        .detection_valid(detection_valid)                       // Detection result valid (end of frame)
    );
        
endmodule