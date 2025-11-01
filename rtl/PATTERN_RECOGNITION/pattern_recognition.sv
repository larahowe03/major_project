module pattern_recognition #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,
    parameter W_FRAC = 0,
    parameter MIN_BLOB_AREA = 500,
    parameter MAX_BLOB_AREA = 50000,
    parameter MIN_BLOBS = 3
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
    output logic [7:0] blob_count,
    output logic [31:0] blob_areas [0:255],
    
    // Optional: edge-detected image output
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data
);
    
    // ========================================================================
    // Internal signals
    // ========================================================================
    
    // Convolution -> BRAM writer
    logic conv_valid;
    logic conv_ready;
    logic [W-1:0] conv_data;
    
    // BRAM writer -> passthrough
    logic bram_y_valid;
    logic bram_y_ready;
    logic [W-1:0] bram_y_data;
    logic frame_complete;
    
    // BRAM write interface (from stream)
    logic stream_bram_we;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] stream_bram_addr;
    logic [W-1:0] stream_bram_data;
    
    // BRAM read/write interface (for blob detector)
    logic blob_bram_we;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] blob_bram_addr;
    logic [W-1:0] blob_bram_rdata;
    logic [7:0] blob_bram_wdata;
    
    // Blob detector control
    logic start_blob_detection;
    logic blob_detection_done;
    
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
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        .y_valid(conv_valid),
        .y_ready(conv_ready),
        .y_data(conv_data),
        .kernel(kernel)
    );
    
    // ========================================================================
    // Step 2: Stream to BRAM (saves edge-detected image)
    // ========================================================================
    stream_to_bram #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W)
    ) u_bram_writer (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(conv_valid),
        .x_ready(conv_ready),
        .x_data(conv_data),
        .y_valid(bram_y_valid),
        .y_ready(bram_y_ready),
        .y_data(bram_y_data),
        .bram_we(stream_bram_we),
        .bram_addr(stream_bram_addr),
        .bram_data(stream_bram_data),
        .frame_complete(frame_complete)
    );
    
    // Connect passthrough to outputs (for VGA display)
    assign y_valid = bram_y_valid;
    assign y_data = bram_y_data;
    assign bram_y_ready = y_ready;
    
    // ========================================================================
    // Step 3: Dual-port BRAM (edge-detected frame buffer)
    // ========================================================================
    edge_frame_buffer #(
        .ADDR_WIDTH($clog2(IMG_WIDTH*IMG_HEIGHT)),
        .DATA_WIDTH(W)
    ) u_frame_buffer (
        .clock(clk),
        
        // Port A: Write from stream (edge-detected pixels)
        .data_a(stream_bram_data),
        .address_a(stream_bram_addr),
        .wren_a(stream_bram_we),
        .q_a(),  // Not used
        
        // Port B: Read/Write for blob detector
        .data_b(blob_bram_wdata),
        .address_b(blob_bram_addr),
        .wren_b(blob_bram_we),
        .q_b(blob_bram_rdata)
    );
    
    // ========================================================================
    // Step 4: Trigger blob detection on frame complete
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_blob_detection <= 1'b0;
        end else begin
            // Pulse start_blob_detection when frame completes
            if (frame_complete && !start_blob_detection) begin
                start_blob_detection <= 1'b1;
            end else begin
                start_blob_detection <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // Step 5: Blob detector (connected component analysis)
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .MIN_BLOB_AREA(MIN_BLOB_AREA),
        .MAX_BLOB_AREA(MAX_BLOB_AREA),
        .MIN_BLOBS(MIN_BLOBS)
    ) u_zebra_crossing_detector (
        .clk(clk),
        .rst_n(rst_n),
        
        // Control
        .start_detection(start_blob_detection),
        .detection_done(blob_detection_done),
        
        // BRAM read interface
        .bram_addr(blob_bram_addr),
        .bram_data(blob_bram_rdata),
        
        // BRAM write interface (for labeling)
        .bram_we(blob_bram_we),
        .bram_wr_addr(blob_bram_addr),  // Same address bus
        .bram_wr_data(blob_bram_wdata),
        
        // Detection results
        .white_count(white_count),
        .blob_count(blob_count),
        .blob_areas(blob_areas),
        .zebra_detected(crossing_detected)
    );
    
    // Detection valid when blob analysis completes
    assign detection_valid = blob_detection_done;
    
endmodule