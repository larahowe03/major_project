module zebra_crossing_detector #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8,                      // Data width
    parameter WHITE_THRESHOLD = 8'd180,   // Threshold for white detection
    parameter BLACK_THRESHOLD = 8'd75,    // Threshold for black detection
    parameter MIN_STRIPE_HEIGHT = 4,      // Minimum pixels for a valid stripe
    parameter MIN_ALTERNATIONS = 4,       // Minimum alternations for zebra pattern
    parameter MIN_COLUMNS_DETECTED = 20,  // Minimum width of zebra crossing
    parameter SCAN_STEP = 4               // Scan every N columns for efficiency
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream from convolution filter
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream (passes through input data)
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data,
    
    // Bounding box outputs (valid at end of frame)
    output logic bbox_valid,
    output logic [$clog2(IMG_WIDTH)-1:0] bbox_x_min,
    output logic [$clog2(IMG_WIDTH)-1:0] bbox_x_max,
    output logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_min,
    output logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_max,
    output logic zebra_detected,
    
    // Debug outputs
    output logic [$clog2(IMG_WIDTH)-1:0] columns_detected_count
);

    // ========================================================================
    // 1. POSITION TRACKING
    // ========================================================================
    
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    logic frame_start, frame_end;
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
            frame_start <= 1'b0;
            frame_end <= 1'b0;
        end else begin
            frame_start <= 1'b0;
            frame_end <= 1'b0;
            
            if (handshake) begin
                if (x_pos == 0 && y_pos == 0) begin
                    frame_start <= 1'b1;
                end
                
                if (x_pos == IMG_WIDTH - 1) begin
                    x_pos <= '0;
                    if (y_pos == IMG_HEIGHT - 1) begin
                        y_pos <= '0;
                        frame_end <= 1'b1;
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
    // 2. COLUMN-WISE STRIPE DETECTION
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
    
    // Track first and last row of detected stripes for bbox
    logic [$clog2(IMG_HEIGHT)-1:0] first_stripe_row;
    logic [$clog2(IMG_HEIGHT)-1:0] last_stripe_row;
    logic stripe_found_in_column;
    
    // Classify current pixel
    logic is_white, is_black, is_gray;
    
    always_comb begin
        is_white = (x_data >= WHITE_THRESHOLD);
        is_black = (x_data <= BLACK_THRESHOLD);
        is_gray = !is_white && !is_black;
    end
    
    // Process pixels in columns at SCAN_STEP intervals
    wire process_pixel = handshake && ((x_pos % SCAN_STEP) == 0);
    wire column_end = handshake && (y_pos == IMG_HEIGHT - 1);
    wire new_column = handshake && (y_pos == 0);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_run_length <= '0;
            alternations <= '0;
            last_completed_was_white <= 1'b0;
            first_stripe_row <= '0;
            last_stripe_row <= '0;
            stripe_found_in_column <= 1'b0;
        end else begin
            // Reset at start of new column
            if (new_column && ((x_pos % SCAN_STEP) == 0)) begin
                state <= IDLE;
                current_run_length <= '0;
                alternations <= '0;
                last_completed_was_white <= 1'b0;
                first_stripe_row <= '0;
                last_stripe_row <= '0;
                stripe_found_in_column <= 1'b0;
            end
            
            // Process pixel in scanned columns
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
                                if (!last_completed_was_white) begin
                                    alternations <= alternations + 1;
                                end
                                last_completed_was_white <= 1'b1;
                                
                                // Update bounding box vertical extent
                                if (!stripe_found_in_column) begin
                                    first_stripe_row <= y_pos - current_run_length;
                                    stripe_found_in_column <= 1'b1;
                                end
                                last_stripe_row <= y_pos;
                            end
                            state <= IN_BLACK;
                            current_run_length <= 1;
                        end else begin
                            state <= IN_TRANSITION;
                        end
                    end
                    
                    IN_BLACK: begin
                        if (is_black) begin
                            current_run_length <= current_run_length + 1;
                        end else if (is_white) begin
                            // Transition from black to white
                            if (current_run_length >= MIN_STRIPE_HEIGHT) begin
                                if (last_completed_was_white) begin
                                    alternations <= alternations + 1;
                                end
                                last_completed_was_white <= 1'b0;
                                
                                // Update bounding box vertical extent
                                if (!stripe_found_in_column) begin
                                    first_stripe_row <= y_pos - current_run_length;
                                    stripe_found_in_column <= 1'b1;
                                end
                                last_stripe_row <= y_pos;
                            end
                            state <= IN_WHITE;
                            current_run_length <= 1;
                        end else begin
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
    // 3. COLUMN DETECTION RESULT
    // ========================================================================
    
    logic column_has_zebra;
    
    always_comb begin
        column_has_zebra = (alternations >= MIN_ALTERNATIONS);
    end
    
    // Latch column detection at end of each scanned column
    logic column_detection_valid;
    logic [$clog2(IMG_WIDTH)-1:0] detected_col_x;
    logic [$clog2(IMG_HEIGHT)-1:0] detected_col_y_min;
    logic [$clog2(IMG_HEIGHT)-1:0] detected_col_y_max;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            column_detection_valid <= 1'b0;
            detected_col_x <= '0;
            detected_col_y_min <= '0;
            detected_col_y_max <= '0;
        end else begin
            column_detection_valid <= 1'b0;
            
            // Latch result at end of scanned column
            if (column_end && ((x_pos % SCAN_STEP) == 0) && column_has_zebra) begin
                column_detection_valid <= 1'b1;
                detected_col_x <= x_pos;
                detected_col_y_min <= first_stripe_row;
                detected_col_y_max <= last_stripe_row;
            end
        end
    end

    // ========================================================================
    // 4. BOUNDING BOX ACCUMULATION
    // ========================================================================
    
    logic [$clog2(IMG_WIDTH)-1:0] columns_detected;
    logic [$clog2(IMG_WIDTH)-1:0] bbox_x_min_reg;
    logic [$clog2(IMG_WIDTH)-1:0] bbox_x_max_reg;
    logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_min_reg;
    logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_max_reg;
    logic bbox_initialized;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            columns_detected <= '0;
            bbox_x_min_reg <= '0;
            bbox_x_max_reg <= '0;
            bbox_y_min_reg <= '0;
            bbox_y_max_reg <= '0;
            bbox_initialized <= 1'b0;
        end else begin
            // Reset at frame start
            if (frame_start) begin
                columns_detected <= '0;
                bbox_x_min_reg <= '0;
                bbox_x_max_reg <= '0;
                bbox_y_min_reg <= '0;
                bbox_y_max_reg <= '0;
                bbox_initialized <= 1'b0;
            end
            
            // Accumulate detections
            if (column_detection_valid) begin
                columns_detected <= columns_detected + 1;
                
                if (!bbox_initialized) begin
                    // First detection - initialize bbox
                    bbox_x_min_reg <= detected_col_x;
                    bbox_x_max_reg <= detected_col_x;
                    bbox_y_min_reg <= detected_col_y_min;
                    bbox_y_max_reg <= detected_col_y_max;
                    bbox_initialized <= 1'b1;
                end else begin
                    // Expand bbox
                    if (detected_col_x < bbox_x_min_reg) begin
                        bbox_x_min_reg <= detected_col_x;
                    end
                    if (detected_col_x > bbox_x_max_reg) begin
                        bbox_x_max_reg <= detected_col_x;
                    end
                    if (detected_col_y_min < bbox_y_min_reg) begin
                        bbox_y_min_reg <= detected_col_y_min;
                    end
                    if (detected_col_y_max > bbox_y_max_reg) begin
                        bbox_y_max_reg <= detected_col_y_max;
                    end
                end
            end
        end
    end

    // ========================================================================
    // 5. FINAL DETECTION AND OUTPUT
    // ========================================================================
    
    logic zebra_detected_reg;
    logic bbox_valid_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zebra_detected_reg <= 1'b0;
            bbox_valid_reg <= 1'b0;
            bbox_x_min <= '0;
            bbox_x_max <= '0;
            bbox_y_min <= '0;
            bbox_y_max <= '0;
            columns_detected_count <= '0;
        end else begin
            bbox_valid_reg <= 1'b0;
            
            // Latch final result at frame end
            if (frame_end) begin
                zebra_detected_reg <= (columns_detected >= MIN_COLUMNS_DETECTED);
                bbox_valid_reg <= (columns_detected >= MIN_COLUMNS_DETECTED);
                
                if (columns_detected >= MIN_COLUMNS_DETECTED) begin
                    bbox_x_min <= bbox_x_min_reg;
                    bbox_x_max <= bbox_x_max_reg;
                    bbox_y_min <= bbox_y_min_reg;
                    bbox_y_max <= bbox_y_max_reg;
                end
                
                columns_detected_count <= columns_detected;
            end
        end
    end
    
    assign zebra_detected = zebra_detected_reg;
    assign bbox_valid = bbox_valid_reg;

    // ========================================================================
    // 6. OUTPUT PIPELINE (Pass-through with 1-cycle delay)
    // ========================================================================
    
    assign x_ready = y_ready | ~y_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_valid <= 1'b0;
            y_data <= '0;
        end else begin
            if (handshake) begin
                y_valid <= x_valid;
                y_data <= x_data;
            end else if (y_ready && y_valid) begin
                y_valid <= 1'b0;
            end
        end
    end

endmodule