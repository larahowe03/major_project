module zebra_crossing_recognition #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter WHITE_THRESHOLD = 8'd200,      // Threshold for raw pixel to be "white"
    parameter MIN_WHITE_PIXELS = 50000,      // Minimum white pixels in raw image
    parameter MIN_EDGE_GROUPS = 15,          // Minimum connected edge groups
    parameter MIN_GROUP_SIZE = 20            // Minimum pixels per edge group
)(
    input logic clk,
    input logic rst_n,
    
    // Control
    input logic start_recognition,
    output logic recognition_complete,
    output logic zebra_detected,
    
    // Raw image BRAM (grayscale from camera)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] raw_addr,
    input logic [7:0] raw_data,
    
    // Edge image BRAM (binary from convolution)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] edge_addr,
    input logic edge_data,
    
    // Visited BRAM for edge grouping
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] visited_addr,
    output logic visited_we,
    output logic visited_wdata,
    input logic visited_rdata,
    
    // Debug outputs
    output logic [31:0] white_pixel_count,
    output logic [7:0] edge_group_count
);

    typedef enum logic [3:0] {
        IDLE,
        
        // Phase 1: Count white pixels in raw image
        COUNT_WHITE_INIT,
        COUNT_WHITE_SCAN,
        COUNT_WHITE_CHECK,
        
        // Phase 2: Count connected edge groups
        EDGE_GROUP_INIT,
        EDGE_GROUP_SCAN,
        EDGE_GROUP_WAIT,
        EDGE_GROUP_FLOOD,
        EDGE_GROUP_POP,
        EDGE_GROUP_CHECK,
        
        // Final decision
        FINAL_CHECK,
        COMPLETE
    } state_t;
    
    state_t state;
    
    // ========================================================================
    // Phase 1: White pixel counting
    // ========================================================================
    logic [31:0] white_count;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] scan_addr;
    
    // ========================================================================
    // Phase 2: Edge group detection (flood fill)
    // ========================================================================
    logic [7:0] group_count;
    logic [15:0] current_group_size;
    
    // Stack for flood fill
    localparam STACK_DEPTH = 1024;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] stack [0:STACK_DEPTH-1];
    logic [$clog2(STACK_DEPTH+1)-1:0] stack_ptr;
    
    // Current position for flood fill
    logic [$clog2(IMG_WIDTH)-1:0] flood_x;
    logic [$clog2(IMG_HEIGHT)-1:0] flood_y;
    
    // 8-connected neighbors
    logic signed [10:0] neighbor_dx [0:7];
    logic signed [10:0] neighbor_dy [0:7];
    logic [2:0] neighbor_idx;
    
    initial begin
        neighbor_dx[0] = -1; neighbor_dy[0] = -1;  // NW
        neighbor_dx[1] =  0; neighbor_dy[1] = -1;  // N
        neighbor_dx[2] =  1; neighbor_dy[2] = -1;  // NE
        neighbor_dx[3] = -1; neighbor_dy[3] =  0;  // W
        neighbor_dx[4] =  1; neighbor_dy[4] =  0;  // E
        neighbor_dx[5] = -1; neighbor_dy[5] =  1;  // SW
        neighbor_dx[6] =  0; neighbor_dy[6] =  1;  // S
        neighbor_dx[7] =  1; neighbor_dy[7] =  1;  // SE
    end
    
    // Helper signals
    logic [$clog2(IMG_WIDTH)-1:0] neighbor_x;
    logic [$clog2(IMG_HEIGHT)-1:0] neighbor_y;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] neighbor_addr;
    logic neighbor_valid;
    
    always_comb begin
        neighbor_x = flood_x + neighbor_dx[neighbor_idx];
        neighbor_y = flood_y + neighbor_dy[neighbor_idx];
        neighbor_valid = (neighbor_x < IMG_WIDTH) && (neighbor_y < IMG_HEIGHT);
        neighbor_addr = neighbor_y * IMG_WIDTH + neighbor_x;
    end
    
    // Final results
    logic phase1_pass;  // Enough white pixels
    logic phase2_pass;  // Enough edge groups
    
    // ========================================================================
    // Main FSM
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            white_count <= '0;
            group_count <= '0;
            scan_addr <= '0;
            stack_ptr <= '0;
            recognition_complete <= 1'b0;
            zebra_detected <= 1'b0;
            visited_we <= 1'b0;
            phase1_pass <= 1'b0;
            phase2_pass <= 1'b0;
        end else begin
            recognition_complete <= 1'b0;
            visited_we <= 1'b0;
            
            case (state)
                // ============================================================
                // IDLE: Wait for trigger
                // ============================================================
                IDLE: begin
                    if (start_recognition) begin
                        state <= COUNT_WHITE_INIT;
                        white_count <= '0;
                        group_count <= '0;
                        scan_addr <= '0;
                        phase1_pass <= 1'b0;
                        phase2_pass <= 1'b0;
                    end
                end
                
                // ============================================================
                // PHASE 1: Count white pixels in raw image
                // ============================================================
                COUNT_WHITE_INIT: begin
                    white_count <= '0;
                    scan_addr <= '0;
                    raw_addr <= '0;
                    state <= COUNT_WHITE_SCAN;
                end
                
                COUNT_WHITE_SCAN: begin
                    // Wait 1 cycle for BRAM read
                    state <= COUNT_WHITE_CHECK;
                end
                
                COUNT_WHITE_CHECK: begin
                    // Check if pixel is white
                    if (raw_data >= WHITE_THRESHOLD) begin
                        white_count <= white_count + 1;
                    end
                    
                    // Move to next pixel
                    if (scan_addr == IMG_WIDTH * IMG_HEIGHT - 1) begin
                        // Done counting
                        phase1_pass <= (white_count >= MIN_WHITE_PIXELS);
                        state <= EDGE_GROUP_INIT;
                    end else begin
                        scan_addr <= scan_addr + 1;
                        raw_addr <= scan_addr + 1;
                        state <= COUNT_WHITE_SCAN;
                    end
                end
                
                // ============================================================
                // PHASE 2: Count connected edge groups (8-connected)
                // ============================================================
                EDGE_GROUP_INIT: begin
                    group_count <= '0;
                    scan_addr <= '0;
                    edge_addr <= '0;
                    visited_addr <= '0;
                    state <= EDGE_GROUP_SCAN;
                end
                
                EDGE_GROUP_SCAN: begin
                    // Wait for both edge_data and visited_rdata
                    state <= EDGE_GROUP_WAIT;
                end
                
                EDGE_GROUP_WAIT: begin
                    // Check if this is an unvisited edge pixel
                    if (edge_data == 1'b1 && visited_rdata == 1'b0) begin
                        // Found new edge group! Start flood fill
                        current_group_size <= 1;
                        
                        // Mark as visited
                        visited_we <= 1'b1;
                        visited_wdata <= 1'b1;
                        visited_addr <= scan_addr;
                        
                        // Initialize stack with seed pixel
                        stack[0] <= scan_addr;
                        stack_ptr <= 1;
                        
                        state <= EDGE_GROUP_POP;
                    end else begin
                        // Move to next scan position
                        if (scan_addr == IMG_WIDTH * IMG_HEIGHT - 1) begin
                            // Done scanning
                            phase2_pass <= (group_count >= MIN_EDGE_GROUPS);
                            state <= FINAL_CHECK;
                        end else begin
                            scan_addr <= scan_addr + 1;
                            edge_addr <= scan_addr + 1;
                            visited_addr <= scan_addr + 1;
                            state <= EDGE_GROUP_SCAN;
                        end
                    end
                end
                
                EDGE_GROUP_POP: begin
                    if (stack_ptr == 0) begin
                        // Stack empty - group complete
                        if (current_group_size >= MIN_GROUP_SIZE) begin
                            group_count <= group_count + 1;
                        end
                        
                        // Resume scanning
                        state <= EDGE_GROUP_SCAN;
                    end else begin
                        // Pop pixel from stack
                        stack_ptr <= stack_ptr - 1;
                        logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] pop_addr;
                        pop_addr = stack[stack_ptr - 1];
                        
                        // Convert to x, y
                        flood_x <= pop_addr % IMG_WIDTH;
                        flood_y <= pop_addr / IMG_WIDTH;
                        
                        // Check all 8 neighbors
                        neighbor_idx <= 0;
                        state <= EDGE_GROUP_FLOOD;
                    end
                end
                
                EDGE_GROUP_FLOOD: begin
                    if (neighbor_idx == 7) begin
                        // Checked all 8 neighbors
                        state <= EDGE_GROUP_POP;
                    end else begin
                        if (neighbor_valid) begin
                            // Read this neighbor
                            edge_addr <= neighbor_addr;
                            visited_addr <= neighbor_addr;
                            state <= EDGE_GROUP_CHECK;
                        end else begin
                            // Out of bounds, try next neighbor
                            neighbor_idx <= neighbor_idx + 1;
                        end
                    end
                end
                
                EDGE_GROUP_CHECK: begin
                    // Check if neighbor is unvisited edge pixel
                    if (edge_data == 1'b1 && visited_rdata == 1'b0) begin
                        // Add to group
                        current_group_size <= current_group_size + 1;
                        
                        // Mark visited
                        visited_we <= 1'b1;
                        visited_wdata <= 1'b1;
                        visited_addr <= neighbor_addr;
                        
                        // Push to stack (if room)
                        if (stack_ptr < STACK_DEPTH) begin
                            stack[stack_ptr] <= neighbor_addr;
                            stack_ptr <= stack_ptr + 1;
                        end
                    end
                    
                    // Move to next neighbor
                    neighbor_idx <= neighbor_idx + 1;
                    state <= EDGE_GROUP_FLOOD;
                end
                
                // ============================================================
                // FINAL: Check both conditions
                // ============================================================
                FINAL_CHECK: begin
                    zebra_detected <= phase1_pass && phase2_pass;
                    state <= COMPLETE;
                end
                
                COMPLETE: begin
                    recognition_complete <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Output current counts
    assign white_pixel_count = white_count;
    assign edge_group_count = group_count;

endmodule