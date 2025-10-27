module pattern_recognition #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
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
    // ISSUE 1: Need intermediate signals for convolution output
    // The y_valid/y_data signals are module outputs AND need to go to detectors
    // ========================================================================
    
    logic conv_valid;
    logic conv_ready;
    logic [W-1:0] conv_data;
    
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
        .y_valid(conv_valid),
        .y_ready(conv_ready),
        .y_data(conv_data),
        .kernel(kernel)
    );
    
    // Pass convolution output to module outputs
    assign y_valid = conv_valid;
    assign y_data = conv_data;
    assign conv_ready = y_ready;
    
    // ========================================================================
    // ISSUE 2: Wrong module name - should be zebra_crossing_detector_stream
    // (unless you're using the full buffer version)
    // ========================================================================
    
    // ========================================================================
    // ISSUE 3: Ready signal conflict - all three detectors try to drive y_ready
    // Need separate ready signals or use internal taps
    // ========================================================================
    
    logic zebra_detected_a, zebra_detected_b, zebra_detected_c;
    logic detection_valid_a, detection_valid_b, detection_valid_c;
    logic [7:0] stripe_count_a, stripe_count_b, stripe_count_c;
    
    // Detector A doesn't control ready (just monitors)
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .BLACK_THRESHOLD(8'd75),
        .MIN_STRIPE_HEIGHT(4),
        .MIN_ALTERNATIONS(6),
        .ANALYSIS_COL(IMG_WIDTH/4)
    ) zebra_det_a (
        .clk(clk), 
        .rst_n(rst_n),
        .x_valid(conv_valid), 
        .x_ready(),  // Leave unconnected - not controlling flow
        .x_data(conv_data),
        .y_valid(detection_valid_a), 
        .y_ready(1'b1), 
        .y_data(zebra_detected_a),
        .alternation_count(stripe_count_a),
        .current_state_debug()
    );
    
    // Detector B doesn't control ready
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .BLACK_THRESHOLD(8'd75),
        .MIN_STRIPE_HEIGHT(4),
        .MIN_ALTERNATIONS(6),
        .ANALYSIS_COL(IMG_WIDTH/2)
    ) zebra_det_b (
        .clk(clk), 
        .rst_n(rst_n),
        .x_valid(conv_valid), 
        .x_ready(),  // Leave unconnected - not controlling flow
        .x_data(conv_data),
        .y_valid(detection_valid_b), 
        .y_ready(1'b1), 
        .y_data(zebra_detected_b),
        .alternation_count(stripe_count_b),
        .current_state_debug()
    );
    
    // Detector C doesn't control ready
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .BLACK_THRESHOLD(8'd75),
        .MIN_STRIPE_HEIGHT(4),
        .MIN_ALTERNATIONS(6),
        .ANALYSIS_COL(IMG_WIDTH/4 + IMG_WIDTH/2)
    ) zebra_det_c (
        .clk(clk), 
        .rst_n(rst_n),
        .x_valid(conv_valid), 
        .x_ready(),  // Leave unconnected - not controlling flow
        .x_data(conv_data),
        .y_valid(detection_valid_c), 
        .y_ready(1'b1), 
        .y_data(zebra_detected_c),
        .alternation_count(stripe_count_c),
        .current_state_debug()
    );

    // ========================================================================
    // ISSUE 4: Assignments must be in always block or use assign
    // ========================================================================
    
    // Combine results - zebra detected if ANY column detects it
    assign crossing_detected = zebra_detected_a || zebra_detected_b || zebra_detected_c;
    
    // Valid when all detectors have valid outputs
    assign detection_valid = detection_valid_a && detection_valid_b && detection_valid_c;
    
    // Average stripe count (integer division)
    assign stripe_count = (stripe_count_a + stripe_count_b + stripe_count_c) / 3;

endmodule