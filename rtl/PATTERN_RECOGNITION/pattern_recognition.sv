module pattern_recognition #(
    parameter IMG_WIDTH  = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H   = 3,
    parameter KERNEL_W   = 3,
    parameter W          = 8,
    parameter W_FRAC     = 0,
    parameter MAX_EDGES  = 1024
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
    output logic num_connected_edge_instances_fulfilled,
    output logic lowest_edge_position_fulfilled,
    
    // Edge bounding box outputs
    output logic [$clog2(IMG_HEIGHT)-1:0] edge_top,
    output logic [$clog2(IMG_HEIGHT)-1:0] edge_bottom,
    output logic [$clog2(IMG_WIDTH)-1:0] edge_left,
    output logic [$clog2(IMG_WIDTH)-1:0] edge_right,
    output logic close_to_crossing,  // HIGH when edge_bottom > 380
    
    // Connected components count
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_components,
    output logic components_valid
);

    // Internal signals from detector
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_components_internal;
    logic components_done;
    
    // Bounding box from convolution filter
    logic [$clog2(IMG_HEIGHT)-1:0] edge_top_internal;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_bottom_internal;
    logic [$clog2(IMG_WIDTH)-1:0] edge_left_internal;
    logic [$clog2(IMG_WIDTH)-1:0] edge_right_internal;
    logic close_to_crossing_internal;

    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // ========================================================================
    // Convolution filter with bounding box tracking
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
        .edge_top(edge_top_internal),
        .edge_bottom(edge_bottom_internal),
        .edge_left(edge_left_internal),
        .edge_right(edge_right_internal),
        .close_to_crossing(close_to_crossing_internal),
        .white_count_valid(white_count_valid)
    );

    // ========================================================================
    // Position tracking for sparse storage writes
    // ========================================================================
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
        end else begin
            if (y_valid && y_ready) begin
                if (x_pos == IMG_WIDTH - 1) begin
                    x_pos <= '0;
                    if (y_pos == IMG_HEIGHT - 1) begin
                        y_pos <= '0;
                    end else begin
                        y_pos <= y_pos + 1;
                    end
                end else begin
                    x_pos <= x_pos + 1;
                end
            end
        end
    end
    
    wire frame_complete = (x_pos == IMG_WIDTH - 1) && (y_pos == IMG_HEIGHT - 1) && y_valid;

    // ========================================================================
    // Sparse Edge Storage
    // ========================================================================
    logic [$clog2(MAX_EDGES)-1:0] edge_read_idx;
    logic [$clog2(IMG_WIDTH)-1:0] edge_x;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_y;
    logic edge_valid;
    logic [$clog2(MAX_EDGES)-1:0] num_edges;
    logic capture_trigger;
    logic buffer_overflow;
    
    sparse_edge_storage #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_EDGES(MAX_EDGES)
    ) u_sparse_edge_storage (
        .clk(clk),
        .rst_n(rst_n),
        
        // Write from edge detection
        .write_valid(y_valid),
        .write_data(y_data),
        .write_x(x_pos),
        .write_y(y_pos),
        
        // Capture control
        .capture_trigger(capture_trigger),
        .frame_complete(frame_complete),
        .capturing(capturing),
        .valid_to_read(valid_to_read),
        
        // Read for detector
        .read_idx(edge_read_idx),
        .edge_x(edge_x),
        .edge_y(edge_y),
        .edge_valid(edge_valid),
        
        .num_edges(num_edges),
        .buffer_overflow(buffer_overflow)
    );

    // ========================================================================
    // Zebra Crossing Detector
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_EDGES(MAX_EDGES),
        .MIN_WHITE_PIXELS(38400),
        .MAX_WHITE_PIXELS(307200),
        .MIN_EDGE_PIXELS(2000),
        .MIN_CONNECTED_EDGE_PIXELS(20),
        .MIN_CONNECTED_EDGE_INSTANCES(10),
        .MIN_LOWEST_EDGE_Y(IMG_HEIGHT * 4 / 5)
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        
        .edge_read_idx(edge_read_idx),
        .edge_x(edge_x),
        .edge_y(edge_y),
        .edge_valid(edge_valid),
        .num_edges(num_edges),
        
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid),
        
        .num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
        .num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
        .num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
        .lowest_edge_position_fulfilled(lowest_edge_position_fulfilled),
        
        .capture_trigger(capture_trigger),
        
        .num_connected_components(num_components_internal),
        .lowest_edge_y(),  // Not used - we get it from convolution filter
        .components_done(components_done)
    );
    
    // Register outputs for stable display
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_connected_components <= '0;
            components_valid <= 1'b0;
            edge_top <= '0;
            edge_bottom <= '0;
            edge_left <= '0;
            edge_right <= '0;
            close_to_crossing <= 1'b0;
        end else begin
            // Update connected components when detector finishes
            if (components_done) begin
                num_connected_components <= num_components_internal;
                components_valid <= 1'b1;
            end else begin
                components_valid <= 1'b0;
            end
            
            // Update bounding box and close_to_crossing flag when frame completes
            if (white_count_valid) begin
                edge_top <= edge_top_internal;
                edge_bottom <= edge_bottom_internal;
                edge_left <= edge_left_internal;
                edge_right <= edge_right_internal;
                close_to_crossing <= close_to_crossing_internal;
            end
        end
    end

endmodule