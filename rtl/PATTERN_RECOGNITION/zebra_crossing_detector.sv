module zebra_crossing_detector #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter MIN_EDGE_LENGTH = 50
)(
    input logic clk,
    input logic rst_n,
    input logic valid_to_read,
    
    output logic detection_valid,
    output logic crossing_detected,
    output logic [7:0] stripe_count,
    
    // Image BRAM (read pixel data)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] pixel_addr,
    input logic pixel_data,
    
    // Visited BRAM (read/write visited flags)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] visited_addr,
    output logic visited_we,
    output logic visited_wdata,
    input logic visited_rdata
);

    typedef enum logic [2:0] {
        IDLE, 
        WAIT_READ,
        SCAN,
        CHECK_NEIGHBOR,
        FOLLOW_EDGE,
        CHECK_LOOP
    } state_t;

    state_t state;

    logic [$clog2(IMG_WIDTH)-1:0] x_pos, x_scan_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos, y_scan_pos;
    logic [$clog2(IMG_WIDTH)-1:0] x_edge, x_start, x_prev;
    logic [$clog2(IMG_HEIGHT)-1:0] y_edge, y_start, y_prev;
    logic [15:0] edge_length;
    logic [7:0] num_stripes;
    logic found_loop;

    logic signed [2:0] neighbor_dx [0:7];
    logic signed [2:0] neighbor_dy [0:7];
    logic [2:0] neighbor_idx;
    
    initial begin
        neighbor_dx[0] = -1; neighbor_dy[0] = -1;
        neighbor_dx[1] =  0; neighbor_dy[1] = -1;
        neighbor_dx[2] =  1; neighbor_dy[2] = -1;
        neighbor_dx[3] = -1; neighbor_dy[3] =  0;
        neighbor_dx[4] =  1; neighbor_dy[4] =  0;
        neighbor_dx[5] = -1; neighbor_dy[5] =  1;
        neighbor_dx[6] =  0; neighbor_dy[6] =  1;
        neighbor_dx[7] =  1; neighbor_dy[7] =  1;
    end

    // ✅ NO MORE HUGE VISITED ARRAY - use BRAM instead!

    localparam BORDER = 20;
    localparam START_X = BORDER;
    localparam END_X = IMG_WIDTH - BORDER - 1;
    localparam START_Y = BORDER;
    localparam END_Y = IMG_HEIGHT - BORDER - 1;

    logic [$clog2(IMG_WIDTH)-1:0] next_x;
    logic [$clog2(IMG_HEIGHT)-1:0] next_y;
    logic in_bounds;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] next_addr, current_addr;
    
    always_comb begin
        next_x = x_edge + neighbor_dx[neighbor_idx];
        next_y = y_edge + neighbor_dy[neighbor_idx];
        in_bounds = (next_x >= START_X) && (next_x <= END_X) && 
                    (next_y >= START_Y) && (next_y <= END_Y);
        next_addr = next_y * IMG_WIDTH + next_x;
        current_addr = y_edge * IMG_WIDTH + x_edge;
    end

    // FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_pos <= START_X;
            y_pos <= START_Y;
            pixel_addr <= '0;
            visited_addr <= '0;
            visited_we <= 1'b0;
            visited_wdata <= 1'b0;
            detection_valid <= 1'b0;
            crossing_detected <= 1'b0;
            num_stripes <= '0;
            stripe_count <= '0;
        end else begin
            detection_valid <= 1'b0;
            visited_we <= 1'b0;  // Default: not writing
            
            case (state)
                IDLE: begin
                    if (valid_to_read) begin
                        state <= WAIT_READ;
                        x_pos <= START_X;
                        y_pos <= START_Y;
                        pixel_addr <= START_Y * IMG_WIDTH + START_X;
                        visited_addr <= START_Y * IMG_WIDTH + START_X;
                        num_stripes <= '0;
                    end
                end
                
                WAIT_READ: begin
                    // Wait for both pixel_data and visited_rdata
                    state <= SCAN;
                end
                
                SCAN: begin
                    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] scan_addr;
                    scan_addr = y_pos * IMG_WIDTH + x_pos;
                    
                    // Check if unvisited white pixel
                    if (pixel_data == 1'b1 && visited_rdata == 1'b0) begin
                        // Found edge start!
                        x_start <= x_pos;
                        y_start <= y_pos;
                        x_edge <= x_pos;
                        y_edge <= y_pos;
                        x_prev <= x_pos;
                        y_prev <= y_pos;
                        x_scan_pos <= x_pos;
                        y_scan_pos <= y_pos;
                        
                        edge_length <= 1;
                        found_loop <= 1'b0;
                        
                        // Mark as visited
                        visited_addr <= scan_addr;
                        visited_we <= 1'b1;
                        visited_wdata <= 1'b1;
                        
                        neighbor_idx <= 0;
                        state <= CHECK_NEIGHBOR;
                    end else begin
                        // Move to next scan position
                        if (x_pos == END_X) begin
                            x_pos <= START_X;
                            if (y_pos == END_Y) begin
                                state <= CHECK_LOOP;
                            end else begin
                                y_pos <= y_pos + 1;
                                pixel_addr <= (y_pos + 1) * IMG_WIDTH + START_X;
                                visited_addr <= (y_pos + 1) * IMG_WIDTH + START_X;
                            end
                        end else begin
                            x_pos <= x_pos + 1;
                            pixel_addr <= pixel_addr + 1;
                            visited_addr <= visited_addr + 1;
                        end
                    end
                end
                
                CHECK_NEIGHBOR: begin
                    if (neighbor_idx == 8) begin
                        // Resume scanning
                        state <= SCAN;
                        
                        if (x_scan_pos == END_X) begin
                            x_pos <= START_X;
                            y_pos <= y_scan_pos + 1;
                            pixel_addr <= (y_scan_pos + 1) * IMG_WIDTH + START_X;
                            visited_addr <= (y_scan_pos + 1) * IMG_WIDTH + START_X;
                        end else begin
                            x_pos <= x_scan_pos + 1;
                            y_pos <= y_scan_pos;
                            pixel_addr <= y_scan_pos * IMG_WIDTH + (x_scan_pos + 1);
                            visited_addr <= y_scan_pos * IMG_WIDTH + (x_scan_pos + 1);
                        end
                        
                        if (found_loop && edge_length >= MIN_EDGE_LENGTH) begin
                            num_stripes <= num_stripes + 1;
                        end
                    end else begin
                        if (in_bounds) begin
                            pixel_addr <= next_addr;
                            visited_addr <= next_addr;
                            state <= FOLLOW_EDGE;
                        end else begin
                            neighbor_idx <= neighbor_idx + 1;
                        end
                    end
                end
                
                FOLLOW_EDGE: begin
                    logic is_start, is_prev;
                    is_start = (next_x == x_start) && (next_y == y_start);
                    is_prev = (next_x == x_prev) && (next_y == y_prev);
                    
                    if (pixel_data == 1'b1) begin
                        if (is_start && edge_length >= MIN_EDGE_LENGTH) begin
                            found_loop <= 1'b1;
                            num_stripes <= num_stripes + 1;
                            neighbor_idx <= 8;
                            state <= CHECK_NEIGHBOR;
                        end else if (visited_rdata == 1'b0 && !is_prev) begin
                            // Mark visited
                            visited_we <= 1'b1;
                            visited_wdata <= 1'b1;
                            edge_length <= edge_length + 1;
                            
                            x_prev <= x_edge;
                            y_prev <= y_edge;
                            x_edge <= next_x;
                            y_edge <= next_y;
                            
                            neighbor_idx <= 0;
                            state <= CHECK_NEIGHBOR;
                        end else begin
                            neighbor_idx <= neighbor_idx + 1;
                            state <= CHECK_NEIGHBOR;
                        end
                    end else begin
                        neighbor_idx <= neighbor_idx + 1;
                        state <= CHECK_NEIGHBOR;
                    end
                end
                
                CHECK_LOOP: begin
                    crossing_detected <= (num_stripes >= 3);
                    stripe_count <= num_stripes;
                    detection_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule