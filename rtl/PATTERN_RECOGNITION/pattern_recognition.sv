module pattern_recognition #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
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

    output logic valid_to_read,
    output logic capturing,

    input  logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
        
    output logic y_valid,
    output logic y_valid_bw,
    input  logic y_ready,
    output logic [W-1:0] y_data,
    output logic [W-1:0] y_data_bw,

    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels,
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels,
    output logic white_count_valid,

    output logic num_threshold_pixels_fulfilled,
    output logic num_edge_pixels_fulfilled,
    output logic num_connected_edge_instances_fulfilled
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
        .y_valid_bw(y_valid_bw),
        .y_ready(y_ready),
        .y_data(y_data),
        .y_data_bw(y_data_bw),
        .kernel(kernel),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid)
    );

    // BRAM signals
    logic [ADDR_WIDTH-1:0] bw_addr;
    logic [1:0] bw_data;
    logic [ADDR_WIDTH-1:0] edge_addr;
    logic [1:0] edge_data;
    logic mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    logic capture_trigger;
    
    // Threshold BRAM
    binary_bram #(
        .IMG_WIDTH(IMG_WIDTH),    // ← ADD
        .IMG_HEIGHT(IMG_HEIGHT)   // ← ADD
    ) u_bw_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid_bw),
        .x_ready(),
        .x_data(y_data_bw),
        .read_addr(bw_addr),
        .read_data(bw_data),
        .mark_visited_we(1'b0),
        .mark_visited_addr('0),
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(),
        .capturing(capturing)
    );

    // Edge BRAM
    binary_bram #(
        .IMG_WIDTH(IMG_WIDTH),    // ← ADD
        .IMG_HEIGHT(IMG_HEIGHT)   // ← ADD
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

    // Zebra Crossing Detector - FIXED PARAMETERS
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MIN_WHITE_PIXELS(15360),   // FIXED: 20% of 76,800
        .MAX_WHITE_PIXELS(53760),   // FIXED: 70% of 76,800
        .MIN_EDGE_PIXELS(1000),     // FIXED: Lower for 320×240
        .MIN_CONNECTED_EDGE_PIXELS(20),
        .MIN_CONNECTED_EDGE_INSTANCES(10)
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        .edge_addr(edge_addr),
        .edge_data(edge_data),
        .bw_addr(bw_addr),
        .bw_data(bw_data),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid),
        .num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
        .num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
        .num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
        .capture_trigger(capture_trigger),
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr)
    );

endmodule