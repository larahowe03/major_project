module zebra_crossing_detector #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8,
    parameter WHITE_THRESHOLD = 8'd180,
    parameter MIN_RUN_LENGTH = 50,      // Minimum pixels for a valid stripe
    parameter MIN_STRIPES = 3           // Need at least 3 stripes for zebra crossing
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream (pass-through)
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data,
    
    // Detection outputs
    output logic is_white,                              // Current pixel is white
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count,  // Total white pixels in frame
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] max_connected, // Longest white run
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] current_run,   // Current white run length
    
    // Zebra crossing detection
    output logic [7:0] long_run_count,                 // Number of long runs found
    output logic zebra_detected,                       // Zebra crossing detected (≥3 long runs)
    output logic detection_valid                       // Detection result valid (end of frame)
);

    // Position tracking
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    logic frame_end;
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
            frame_end <= 1'b0;
        end else begin
            frame_end <= 1'b0;
            
            if (handshake) begin
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

    // Check if current pixel is white
    assign is_white = (x_data >= WHITE_THRESHOLD);
    
    // Count all white pixels, track runs, and count long runs
    logic was_white;
    logic [7:0] long_runs;  // Count of runs ≥ MIN_RUN_LENGTH
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            white_count <= '0;
            current_run <= '0;
            max_connected <= '0;
            was_white <= 1'b0;
            long_runs <= '0;
            long_run_count <= '0;
        end else begin
            // Reset at start of frame
            if (handshake && x_pos == 0 && y_pos == 0) begin
                white_count <= '0;
                current_run <= '0;
                max_connected <= '0;
                was_white <= 1'b0;
                long_runs <= '0;
            end
            
            // Process every pixel
            if (handshake) begin
                if (is_white) begin
                    // White pixel
                    white_count <= white_count + 1;
                    current_run <= current_run + 1;
                    was_white <= 1'b1;
                end else begin
                    // Not white - end of run
                    if (was_white) begin
                        // Check if this was a long run
                        if (current_run >= MIN_RUN_LENGTH) begin
                            long_runs <= long_runs + 1;
                        end
                        
                        // Update max
                        if (current_run > max_connected) begin
                            max_connected <= current_run;
                        end
                    end
                    
                    current_run <= '0;
                    was_white <= 1'b0;
                end
            end
            
            // At end of frame, check for final run and latch count
            if (frame_end) begin
                // Check if frame ended in middle of a run
                if (was_white && current_run >= MIN_RUN_LENGTH) begin
                    long_run_count <= long_runs + 1;
                end else begin
                    long_run_count <= long_runs;
                end
            end
        end
    end
    
    // Zebra crossing detection logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zebra_detected <= 1'b0;
            detection_valid <= 1'b0;
        end else begin
            detection_valid <= 1'b0;
            
            // At end of frame, determine if zebra crossing detected
            if (frame_end) begin
                detection_valid <= 1'b1;
                
                // Check if we ended on a long run
                if (was_white && current_run >= MIN_RUN_LENGTH) begin
                    // Include the final run
                    zebra_detected <= ((long_runs + 1) >= MIN_STRIPES);
                end else begin
                    zebra_detected <= (long_runs >= MIN_STRIPES);
                end
            end
        end
    end

    // Pass-through
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