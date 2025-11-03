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

    // Detection logic outputs
    output logic num_threshold_pixels_fulfilled,
    output logic num_edge_pixels_fulfilled,
    output logic num_connected_edge_instances_fulfilled
);

    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // ========================================================================
    // Convolution filter
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
        .y_valid_bw(y_valid_bw),
        .y_ready(y_ready),
        .y_data(y_data),
        .y_data_bw(y_data_bw),
        .kernel(kernel),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid)
    );

    // ========================================================================
    // Combined Edge + BW BRAM
    // ========================================================================
    logic [ADDR_WIDTH-1:0] edge_addr;
    logic [1:0] edge_data;
    logic [ADDR_WIDTH-1:0] bw_addr;
    logic [1:0] bw_data;
    logic mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    logic capture_trigger;

    combined_bram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_combined_bram (
        .clk(clk),
        .rst_n(rst_n),

        // Input streams from convolution filter
        .x_valid_edge(y_valid),
        .x_ready_edge(),
        .x_data_edge(y_data),

        .x_valid_bw(y_valid_bw),
        .x_ready_bw(),
        .x_data_bw(y_data_bw),

        // Read ports for zebra detector
        .edge_read_addr(edge_addr),
        .edge_read_data(edge_data),

        .bw_read_addr(bw_addr),
        .bw_read_data(bw_data),

        // Write for marking visited
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr),

        // Control
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(),
        .capturing(capturing)
    );


    // ========================================================================
    // Zebra Crossing Detector
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MIN_WHITE_PIXELS(61440),    // 20% of 307200 pixels)
        .MAX_WHITE_PIXELS(208320), // 70% of 307200 pixels
        .MIN_EDGE_PIXELS(2000),
        .MIN_CONNECTED_EDGE_PIXELS(20),
        .MIN_CONNECTED_EDGE_INSTANCES(10)
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        
        // Edge BRAM interface
        .edge_addr(edge_addr),
        .edge_data(edge_data),
        
        // BW BRAM interface
        .bw_addr(bw_addr),
        .bw_data(bw_data),
        
        // Pixel counts
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid),
        
        // Outputs
        .num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
        .num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
        .num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
        .capture_trigger(capture_trigger),

        // For marking visited
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr)
    );

endmodule