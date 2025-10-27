module zebra_crossing_detector #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8,                      // Data width
    parameter WHITE_THRESHOLD = 8'd180,   // Threshold for white detection
    parameter BLACK_THRESHOLD = 8'd75,    // Threshold for black detection
    parameter MIN_STRIPE_HEIGHT = 4,      // Minimum pixels for a valid stripe
    parameter MIN_ALTERNATIONS = 6,       // Minimum alternations (3 white + 3 black)
    parameter ANALYSIS_COL = IMG_WIDTH/2  // Which column to analyze (center)
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream from convolution filter
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream (binary: 1 = zebra crossing detected in this column, 0 = not)
    output logic y_valid,
    input logic y_ready,
    output logic y_data,  // Single bit: zebra crossing detected
    
    // Debug outputs
    output logic [$clog2(IMG_HEIGHT)-1:0] alternation_count,
    output logic [2:0] current_state_debug
);

    // ========================================================================
    // 1. POSITION TRACKING
    // ========================================================================
    
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
        end else begin
            if (handshake) begin
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

    // ========================================================================
    // 2. VERTICAL STRIPE ANALYSIS (Real-time as pixels stream)
    // ========================================================================
    
    typedef enum logic [2:0] {
        IDLE           = 3'd0,
        IN_WHITE       = 3'd1,
        IN_BLACK       = 3'd2,
        IN_TRANSITION  = 3'd3
    } stripe_state_t;
    
    stripe_state_t state;
    
    logic [$clog2(IMG_HEIGHT)-1:0] current_run_length;
    logic [$clog2(IMG_HEIGHT)-1:0] alternations;
    logic last_completed_was_white;
    
    // Classify current pixel
    logic is_white, is_black, is_gray;
    
    always_comb begin
        is_white = (x_data >= WHITE_THRESHOLD);
        is_black = (x_data <= BLACK_THRESHOLD);
        is_gray = !is_white && !is_black;
    end
    
    // Process pixels in the analysis column
    wire process_pixel = handshake && (x_pos == ANALYSIS_COL);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_run_length <= '0;
            alternations <= '0;
            last_completed_was_white <= 1'b0;
        end else begin
            // Reset at start of new frame
            if (handshake && y_pos == 0 && x_pos == 0) begin
                state <= IDLE;
                current_run_length <= '0;
                alternations <= '0;
                last_completed_was_white <= 1'b0;
            end
            
            // Process pixel in analysis column
            if (process_pixel) begin
                case (state)
                    IDLE: begin
                        if (is_white) begin
                            state <= IN_WHITE;
                            current_run_length <= 1;
                        end else if (is_black) begin
                            state <= IN_BLACK;
                            current_run_length <= 1;
                        end
                    end
                    
                    IN_WHITE: begin
                        if (is_white) begin
                            current_run_length <= current_run_length + 1;
                        end else if (is_black) begin
                            // Transition from white to black
                            if (current_run_length >= MIN_STRIPE_HEIGHT) begin
                                // Valid white stripe completed
                                if (!last_completed_was_white) begin
                                    alternations <= alternations + 1;
                                end
                                last_completed_was_white <= 1'b1;
                            end
                            state <= IN_BLACK;
                            current_run_length <= 1;
                        end else begin
                            // Gray area - transition
                            state <= IN_TRANSITION;
                        end
                    end
                    
                    IN_BLACK: begin
                        if (is_black) begin
                            current_run_length <= current_run_length + 1;
                        end else if (is_white) begin
                            // Transition from black to white
                            if (current_run_length >= MIN_STRIPE_HEIGHT) begin
                                // Valid black stripe completed
                                if (last_completed_was_white) begin
                                    alternations <= alternations + 1;
                                end
                                last_completed_was_white <= 1'b0;
                            end
                            state <= IN_WHITE;
                            current_run_length <= 1;
                        end else begin
                            // Gray area - transition
                            state <= IN_TRANSITION;
                        end
                    end
                    
                    IN_TRANSITION: begin
                        if (is_white) begin
                            state <= IN_WHITE;
                            current_run_length <= 1;
                        end else if (is_black) begin
                            state <= IN_BLACK;
                            current_run_length <= 1;
                        end
                    end
                endcase
            end
        end
    end

    // ========================================================================
    // 3. ZEBRA CROSSING DETECTION
    // ========================================================================
    
    logic zebra_detected;
    
    always_comb begin
        // Zebra detected if we have enough alternations
        zebra_detected = (alternations >= MIN_ALTERNATIONS);
    end
    
    // Latch detection at end of frame
    logic zebra_detected_latched;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zebra_detected_latched <= 1'b0;
        end else begin
            // Latch result at end of analysis column
            if (handshake && x_pos == ANALYSIS_COL && y_pos == IMG_HEIGHT - 1) begin
                zebra_detected_latched <= zebra_detected;
            end
            // Clear at start of new frame
            if (handshake && y_pos == 0 && x_pos == 0) begin
                zebra_detected_latched <= 1'b0;
            end
        end
    end

    // ========================================================================
    // 4. OUTPUT PIPELINE
    // ========================================================================
    
    assign x_ready = y_ready | ~y_valid;
    
    // Output the latched zebra detection for every pixel
    logic x_valid_d1;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_valid <= 1'b0;
            y_data <= 1'b0;
            x_valid_d1 <= 1'b0;
            alternation_count <= '0;
            current_state_debug <= '0;
        end else begin
            if (handshake) begin
                x_valid_d1 <= x_valid;
                
                // Output zebra detection (same for all pixels in frame)
                y_data <= zebra_detected_latched;
                y_valid <= x_valid_d1;
                
                // Update debug outputs
                alternation_count <= alternations;
                current_state_debug <= state;
            end else if (y_ready && y_valid) begin
                y_valid <= 1'b0;
            end
        end
    end

endmodule