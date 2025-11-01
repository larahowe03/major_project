module pattern_recognition #(
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

    // BRAM capture control
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capturing,

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
    
    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);
    
    logic bram_x_ready;
    logic capture_complete;
    
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
    ) u_convolution_filter (
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
    // Step 2: Image BRAM (captures binary edge image)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] bram_read_addr;
    logic bram_read_data;
    
    binary_bram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        
        // Write stream (capture)
        .x_valid(y_valid),
        .x_ready(bram_x_ready),
        .x_data(y_data),
        
        // Read port (for detector)
        .read_addr(bram_read_addr),
        .read_data(bram_read_data),
        
        // Mark visited (from detector)
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr),
        
        // Control
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(capture_complete),
        .capturing(capturing)
    );

    // ========================================================================
    // Step 3: Visited BRAM (1-bit per pixel for tracking)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    logic mark_visited_we;

    // ========================================================================
    // Step 4: Zebra crossing detector
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MIN_EDGE_LENGTH(50)
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        
        .detection_valid(detection_valid),
        .crossing_detected(crossing_detected),
        .stripe_count(stripe_count),
        
        // Single BRAM interface
        .bram_addr(bram_read_addr),
        .bram_data(bram_read_data),
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr)
    );
    
endmodule