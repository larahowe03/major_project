module pattern_recognition #(
    parameter IMG_WIDTH  = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H   = 3,
    parameter KERNEL_W   = 3,
    parameter W          = 8,
    parameter W_FRAC     = 0
)(
    input  logic clk,
    input  logic rst_n,
    
    // Input pixel stream (from camera)
    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    // BRAM capture control
    input  logic capture_trigger,
    output logic valid_to_read,
    output logic capturing,

    // Edge detection kernel
    input  logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
        
    // Edge-detected image output (for VGA display)
    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data,
    output logic [W-1:0] y_data_bw
);

    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // ========================================================================
    // Step 1: Convolution filter (edge detection)
    // Also outputs black/white thresholded image
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
        .y_data_bw(y_data_bw),
        .kernel(kernel)
    );

    // ========================================================================
    // Step 2: Raw Image BRAM (b/w thresholded)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] raw_addr;
    logic [1:0] raw_data;
    
    binary_bram #(
        .ADDR_WIDTH(TOTAL_PIXELS)
    ) u_raw_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(),
        .x_data(y_data_bw),
        .read_addr(raw_addr),
        .read_data(raw_data),
        .mark_visited_we(1'b0),
        .mark_visited_addr('0),
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(),
        .capturing(capturing)
    );

    // ========================================================================
    // Step 3: Edge Image BRAM (2-bit: black/white/visited)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] edge_addr;
    logic [1:0] edge_data;
    logic mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    
    binary_bram #(
        .ADDR_WIDTH(TOTAL_PIXELS)
    ) u_edge_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid),
        .x_ready(),
        .x_data(y_data),
        .read_addr(edge_addr),
        .read_data(edge_data),
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr),
        .capture_trigger(capture_trigger),
        .valid_to_read(),
        .capture_complete(),
        .capturing()
    );

endmodule