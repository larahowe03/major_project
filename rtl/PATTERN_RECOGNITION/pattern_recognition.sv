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
    
    logic bram_x_ready;  // ADDED: separate ready signal for BRAM writer
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
    // Step 2: BRAM writer (captures binary edge image)
    // ========================================================================

    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_read_addr;
    logic bram_read_data;
    binary_bram #(
        .ADDR_WIDTH($clog2(IMG_WIDTH*IMG_HEIGHT))
    ) u_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid),
        .x_ready(bram_x_ready),  // FIXED: Connected properly
        .x_data(y_data),
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(capture_complete),
        .capturing(capturing),

        // reading
        .read_addr(bram_read_addr),  // address to read from
        .read_data(bram_read_data)   // result from reading
    );

    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] visited_addr;
    logic visited_we, visited_wdata, visited_rdata;

    // Visited BRAM (1-bit per pixel)
    binary_bram #(
        .ADDR_WIDTH($clog2(IMG_WIDTH*IMG_HEIGHT))
    ) u_visited_bram (
        .clock(clk),
        .wren(visited_we),
        .wraddress(visited_addr),
        .wrdata(visited_wdata),
        .rdaddress(visited_addr),  // Same address for read/write
        .rddata(visited_rdata)
    );

    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) u_detector (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        .detection_valid(detection_valid),
        .crossing_detected(crossing_detected),
        .stripe_count(stripe_count),
        .pixel_addr(bram_read_addr),
        .pixel_data(bram_read_data),
        .visited_addr(visited_addr),
        .visited_we(visited_we),
        .visited_wdata(visited_wdata),
        .visited_rdata(visited_rdata)
    );
    
endmodule