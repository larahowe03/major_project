module top_level #(
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