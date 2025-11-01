module zebra_crossing_detector #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8,
    parameter WHITE_THRESHOLD = 8'd180
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
    // output logic [W-1:0] y_data,
    
    // Detection outputs
    output logic is_white,                              // Current pixel is white
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count,  // Total white pixels in frame
    // output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] current_blob, // Current blob size
    
    // Zebra crossing detection
    // output logic [7:0] blob_count,                     // Number of blobs found (≥MIN_BLOB_SIZE)
    output logic zebra_detected,                       // Zebra crossing detected (≥3 blobs)
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
    
    // Store previous row to check vertical connectivity
    // logic [IMG_WIDTH-1:0] prev_row_white;  // Bitmap of previous row
    // logic prev_pixel_white;                 // Previous pixel in current row
    
    // // Blob detection state
    // logic in_blob;
    // logic [7:0] blobs_found;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            white_count <= '0;
            // current_blob <= '0;
            // blobs_found <= '0;
            // in_blob <= 1'b0;
            // prev_row_white <= '0;
            // prev_pixel_white <= 1'b0;
        end else begin
            // Reset at start of frame
            if (handshake && x_pos == 0 && y_pos == 0) begin
                white_count <= '0;
                // current_blob <= '0;
                // blobs_found <= '0;
                // in_blob <= 1'b0;
                // prev_row_white <= '0;
                // prev_pixel_white <= 1'b0;
            end
            
            // Process every pixel
            if (handshake) begin
                // Check if connected to previous white pixels
                // logic connected;
                // connected = 1'b0;
                
                if (is_white) begin
                    white_count <= white_count + 1;
                    
                    // // Check horizontal connectivity (left neighbor)
                    // if (x_pos > 0 && prev_pixel_white) begin
                    //     connected = 1'b1;
                    // end
                    
                    // // Check vertical connectivity (pixel above)
                    // if (y_pos > 0 && prev_row_white[x_pos]) begin
                    //     connected = 1'b1;
                    // end
                    
                    // // Check diagonal connectivity (top-left and top-right)
                    // if (y_pos > 0) begin
                    //     if (x_pos > 0 && prev_row_white[x_pos-1]) begin
                    //         connected = 1'b1;
                    //     end
                    //     if (x_pos < IMG_WIDTH-1 && prev_row_white[x_pos+1]) begin
                    //         connected = 1'b1;
                    //     end
                    // end
                    
                    // if (connected) begin
                    //     // Part of existing blob
                    //     current_blob <= current_blob + 1;
                    //     in_blob <= 1'b1;
                    // end else begin
                    //     // Start of new blob - check if previous blob was valid
                    //     if (in_blob && current_blob >= MIN_BLOB_SIZE) begin
                    //         blobs_found <= blobs_found + 1;
                    //     end
                    //     current_blob <= 1;
                    //     in_blob <= 1'b1;
                    // end
                    
                    // prev_pixel_white <= 1'b1;
                end 
                // else begin
                //     // Not white
                //     if (in_blob && current_blob >= MIN_BLOB_SIZE) begin
                //         // End of a valid blob
                //         blobs_found <= blobs_found + 1;
                //     end
                    
                //     current_blob <= '0;
                //     in_blob <= 1'b0;
                //     prev_pixel_white <= 1'b0;
                // end
                
                // Update previous row bitmap
                // if (x_pos == IMG_WIDTH - 1) begin
                //     // End of row - clear for next row
                //     prev_row_white <= '0;
                //     prev_pixel_white <= 1'b0;
                // end
                
                // // Store current pixel for next row
                // prev_row_white[x_pos] <= is_white;
            end
        end
    end
    
    // Detection logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // blob_count <= '0;
            zebra_detected <= 1'b0;
            detection_valid <= 1'b0;
        end else begin
            // detection_valid <= 1'b0;
            
            // // At end of frame, finalize detection
            // if (frame_end) begin
            //     detection_valid <= 1'b1;
                
            //     // Check if last blob was valid
            //     if (in_blob && current_blob >= MIN_BLOB_SIZE) begin
            //         blob_count <= blobs_found + 1;
            //         zebra_detected <= ((blobs_found + 1) >= MIN_STRIPES);
            //     end else begin
            //         blob_count <= blobs_found;
            //         zebra_detected <= (blobs_found >= MIN_STRIPES);
            //     end
            // end
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