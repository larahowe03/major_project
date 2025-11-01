module zebra_crossing_detector #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter W = 8,
    parameter WHITE_THRESHOLD = 8'd180,
    parameter MIN_BLOB_AREA = 500,        // Minimum pixels for valid blob
    parameter MAX_BLOB_AREA = 50000,      // Maximum pixels for valid blob
    parameter MIN_BLOBS = 3               // Need at least 3 blobs for zebra
)(
    input logic clk,
    input logic rst_n,
    
    // Control
    input logic start_detection,
    output logic detection_done,
    
    // BRAM read interface
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_addr,
    input logic [W-1:0] bram_data,
    
    // BRAM write interface (for labeling)
    output logic bram_we,
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_wr_addr,
    output logic [7:0] bram_wr_data,
    
    // Detection results
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count,
    output logic [7:0] blob_count,
    output logic [31:0] blob_areas [0:255],  // Area of each blob
    output logic zebra_detected
);

    typedef enum logic [3:0] {
        IDLE,
        FIRST_PASS_READ,
        FIRST_PASS_WAIT,
        FIRST_PASS_LABEL,
        MEASURE_AREAS_READ,
        MEASURE_AREAS_WAIT,
        MEASURE_AREAS_COUNT,
        FILTER_BLOBS,
        DONE
    } state_t;
    
    state_t state;
	 logic [7:0] assigned_label;

    // Position tracking
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    assign bram_addr = y_pos * IMG_WIDTH + x_pos;
    assign bram_wr_addr = bram_addr;
    
    // Pixel classification
    logic is_white;
    assign is_white = (bram_data >= WHITE_THRESHOLD);
    
    // Connected component labeling
    logic [7:0] current_label;
    logic [7:0] label_buffer [0:IMG_WIDTH-1];  // Previous row labels
    logic [7:0] prev_pixel_label;              // Left neighbor label
    
    // Area measurement
    logic [31:0] area_counters [0:255];
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] total_white_pixels;
    
    // Valid blob tracking
    logic [7:0] valid_blob_count;
    logic blob_valid [0:255];
    
    // ========================================================================
    // Two-Pass Connected Component Labeling
    // ========================================================================
    logic has_left, has_above;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_pos <= '0;
            y_pos <= '0;
            current_label <= 8'd1;
            detection_done <= 1'b0;
            zebra_detected <= 1'b0;
            white_count <= '0;
            blob_count <= '0;
            valid_blob_count <= '0;
            bram_we <= 1'b0;
            total_white_pixels <= '0;
            
            // Initialize arrays
            for (int i = 0; i < 256; i++) begin
                area_counters[i] <= '0;
                blob_areas[i] <= '0;
                blob_valid[i] <= 1'b0;
            end
            
            for (int i = 0; i < IMG_WIDTH; i++) begin
                label_buffer[i] <= '0;
            end
            
            prev_pixel_label <= '0;
            
        end else begin
            bram_we <= 1'b0;  // Default
            detection_done <= 1'b0;
            
            case (state)
                // ============================================================
                // IDLE - Wait for start
                // ============================================================
                IDLE: begin
                    if (start_detection) begin
                        x_pos <= '0;
                        y_pos <= '0;
                        current_label <= 8'd1;
                        total_white_pixels <= '0;
                        
                        for (int i = 0; i < 256; i++) begin
                            area_counters[i] <= '0;
                            blob_valid[i] <= 1'b0;
                        end
                        
                        for (int i = 0; i < IMG_WIDTH; i++) begin
                            label_buffer[i] <= '0;
                        end
                        
                        prev_pixel_label <= '0;
                        state <= FIRST_PASS_READ;
                    end
                end
                
                // ============================================================
                // FIRST PASS - Label connected components
                // ============================================================
                FIRST_PASS_READ: begin
                    state <= FIRST_PASS_WAIT;
                end
                
                FIRST_PASS_WAIT: begin
                    state <= FIRST_PASS_LABEL;
                end
                
                FIRST_PASS_LABEL: begin
                    assigned_label = 8'd0;
                    
                    if (is_white) begin
                        total_white_pixels <= total_white_pixels + 1;
                        
                        // Check 4-connectivity (left and above)
                        has_left = (x_pos > 0) && (prev_pixel_label != 8'd0);
                        has_above = (y_pos > 0) && (label_buffer[x_pos] != 8'd0);
                        
                        if (has_left && has_above) begin
                            // Both neighbors are labeled - use minimum
                            assigned_label = (prev_pixel_label < label_buffer[x_pos]) ? 
                                           prev_pixel_label : label_buffer[x_pos];
                        end else if (has_left) begin
                            // Only left neighbor
                            assigned_label = prev_pixel_label;
                        end else if (has_above) begin
                            // Only above neighbor
                            assigned_label = label_buffer[x_pos];
                        end else begin
                            // New blob - assign new label
                            assigned_label = current_label;
                            current_label <= current_label + 1;
                        end
                        
                        prev_pixel_label <= assigned_label;
                        label_buffer[x_pos] <= assigned_label;
                        
                        // Write label to BRAM (for second pass)
                        bram_we <= 1'b1;
                        bram_wr_data <= assigned_label;
                        
                    end else begin
                        // Black pixel
                        prev_pixel_label <= 8'd0;
                        label_buffer[x_pos] <= 8'd0;
                        bram_we <= 1'b1;
                        bram_wr_data <= 8'd0;
                    end
                    
                    // Move to next pixel
                    if (x_pos == IMG_WIDTH - 1) begin
                        x_pos <= '0;
                        prev_pixel_label <= 8'd0;
                        
                        if (y_pos == IMG_HEIGHT - 1) begin
                            // First pass complete
                            y_pos <= '0;
                            blob_count <= current_label - 1;
                            state <= MEASURE_AREAS_READ;
                        end else begin
                            y_pos <= y_pos + 1;
                            state <= FIRST_PASS_READ;
                        end
                    end else begin
                        x_pos <= x_pos + 1;
                        state <= FIRST_PASS_READ;
                    end
                end
                
                // ============================================================
                // SECOND PASS - Measure areas
                // ============================================================
                MEASURE_AREAS_READ: begin
                    state <= MEASURE_AREAS_WAIT;
                end
                
                MEASURE_AREAS_WAIT: begin
                    state <= MEASURE_AREAS_COUNT;
                end
                
                MEASURE_AREAS_COUNT: begin
                    // Read label from BRAM
                    logic [7:0] pixel_label;
                    pixel_label = bram_data;
                    
                    if (pixel_label != 8'd0) begin
                        area_counters[pixel_label] <= area_counters[pixel_label] + 1;
                    end
                    
                    // Move to next pixel
                    if (x_pos == IMG_WIDTH - 1) begin
                        x_pos <= '0;
                        
                        if (y_pos == IMG_HEIGHT - 1) begin
                            y_pos <= '0;
                            state <= FILTER_BLOBS;
                        end else begin
                            y_pos <= y_pos + 1;
                            state <= MEASURE_AREAS_READ;
                        end
                    end else begin
                        x_pos <= x_pos + 1;
                        state <= MEASURE_AREAS_READ;
                    end
                end
                
                // ============================================================
                // FILTER - Count valid blobs
                // ============================================================
                FILTER_BLOBS: begin
                    valid_blob_count = 0;
                    
                    for (int i = 1; i < 256; i++) begin
                        blob_areas[i] <= area_counters[i];
                        
                        if (area_counters[i] >= MIN_BLOB_AREA && 
                            area_counters[i] <= MAX_BLOB_AREA) begin
                            blob_valid[i] <= 1'b1;
                            valid_blob_count = valid_blob_count + 1;
                        end else begin
                            blob_valid[i] <= 1'b0;
                        end
                    end
                    
                    // Check if zebra crossing detected
                    zebra_detected <= (valid_blob_count >= MIN_BLOBS);
                    white_count <= total_white_pixels;
                    
                    state <= DONE;
                end
                
                // ============================================================
                // DONE
                // ============================================================
                DONE: begin
                    detection_done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule