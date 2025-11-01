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
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count,
    
    // Optional: edge-detected image output
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data
);
    
    // Signals between convolution and zebra detector
    logic conv_valid;
    logic conv_ready;
    logic [W-1:0] conv_data;
    
    // Unused output from zebra detector
    logic is_white;
    
    // ========================================================================
    // Step 1: Convolution filter (edge detection)
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
        // Input from camera
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        // Output to zebra detector
        .y_valid(conv_valid),
        .y_ready(conv_ready),
        .y_data(conv_data),
        .kernel(kernel)
    );
    
    // ========================================================================
    // Step 2: Zebra crossing detector (on edge-detected image)
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),        
        .W(W),
        .WHITE_THRESHOLD(8'd180)
    ) u_zebra_crossing_detector (
        .clk(clk),       
        .rst_n(rst_n),
        
        // Input from convolution filter (edge-detected pixels)
        .x_valid(conv_valid),
        .x_ready(conv_ready),  
        .x_data(conv_data),
        
        // Output to display (pass-through of edge-detected image)
        .y_valid(y_valid), 
        .y_ready(y_ready),
        .y_data(y_data),
        // Detection results
        .is_white(is_white),
        .white_count(white_count),
        .zebra_detected(crossing_detected),
        .detection_valid(detection_valid)
    );
    
endmodule