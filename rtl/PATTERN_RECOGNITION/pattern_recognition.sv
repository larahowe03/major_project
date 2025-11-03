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
    
    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    input  logic capture_trigger,
    output logic valid_to_read,
    output logic capturing,

    input  logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
        
    output logic y_valid,
    output logic y_valid_bw,  // NEW: Separate valid
    input  logic y_ready,
    output logic [W-1:0] y_data,
    output logic [W-1:0] y_data_bw,

    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels,
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels,
    output logic white_count_valid
);

    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // Convolution filter
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
        .y_valid_bw(y_valid_bw),  // NEW: Separate valid
        .y_ready(y_ready),
        .y_data(y_data),
        .y_data_bw(y_data_bw),
        .kernel(kernel),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid)
    );

    // Raw Image BRAM (uses separate valid signal)
    logic [ADDR_WIDTH-1:0] raw_addr;
    logic [1:0] raw_data;
    
    binary_bram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_raw_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid_bw),  // FIXED: Use separate valid signal
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

    // Edge Image BRAM (uses convolution valid)
    logic [ADDR_WIDTH-1:0] edge_addr;
    logic [1:0] edge_data;
    logic mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    
    binary_bram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_edge_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid),  // Uses convolution valid
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