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

    // todo: temp
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capturing,

    
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
    // Step 1: Convolution filter (edge detection) - STANDALONE
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
        .x_ready(x_ready),        // Direct connection
        .x_data(x_data),
        .y_valid(y_valid),        // Direct connection
        .y_ready(y_ready),        // Connect y_ready!
        .y_data(y_data),          // Direct connection
        .kernel(kernel)
    );

    // In your top-level or pattern_recognition module:

    bram_writer #(
        .IMG_WIDTH(640),
        .IMG_HEIGHT(480)
    ) u_bram_writer (
        .clk(clk_video),
        .rst_n(rst_n),
        .x_valid(y_valid),
//        .x_ready(y_ready),
        .x_data(y_data),
        .capture_trigger(capture_trigger),    // Pulse high to start capture
        .valid_to_read(valid_to_read),  // Goes high when done
        .capturing(capturing)                 // High while actively capturing
    );

    // Use valid_to_read to start blob detection
//    always_ff @(posedge clk_video or negedge rst_n) begin
//        if (!rst_n) begin
//            start_blob_detection <= 1'b0;
//        end else begin
//            if (valid_to_read) begin
//                start_blob_detection <= 1'b1;  // Start analysis
//            end else begin
//                start_blob_detection <= 1'b0;
//            end
//        end
//    end

// _________--------_________--___-_---_-_-_-__________
    
    // Stub outputs for blob detector (not implemented)
    assign crossing_detected = 1'b0;
    assign detection_valid = 1'b0;
    assign white_count = '0;
    assign blob_count = '0;
    
    // Initialize blob_areas array
    integer i;
    always_comb begin
        for (i = 0; i < 256; i = i + 1) begin
            blob_areas[i] = '0;
        end
    end
    
endmodule