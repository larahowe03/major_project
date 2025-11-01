module simple_blob_detector #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter W = 8,
    parameter WHITE_THRESHOLD = 8'd180,
    parameter MIN_BLOB_AREA = 500,
    parameter MAX_BLOB_AREA = 50000
)(
    input logic clk,
    input logic rst_n,
    
    input logic start_detection,
    output logic detection_done,
    
    // BRAM interface
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_addr,
    input logic [W-1:0] bram_rdata,
    output logic bram_we,
    output logic [7:0] bram_wdata,
    
    // Results
    output logic [7:0] valid_blob_count,
    output logic [31:0] largest_blob_area,
    output logic zebra_detected
);

    typedef enum logic [3:0] {
        IDLE,
        SCAN_FIND_SEED,
        SCAN_WAIT,
        CHECK_SEED,
        FLOOD_FILL_INIT,
        FLOOD_FILL_READ,
        FLOOD_FILL_WAIT,
        FLOOD_FILL_PROCESS,
        BLOB_COMPLETE,
        ALL_DONE
    } state_t;
    
    state_t state;
    
    logic [$clog2(IMG_WIDTH)-1:0] scan_x, fill_x;
    logic [$clog2(IMG_HEIGHT)-1:0] scan_y, fill_y;
    
    // Stack for flood fill (simple version - fixed size)
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] stack [0:1023];
    logic [9:0] stack_ptr;
    
    logic [31:0] current_area;
    logic [7:0] blob_counter;
    logic [7:0] current_blob_id;
    
    assign bram_addr = (state == FLOOD_FILL_READ || 
                        state == FLOOD_FILL_WAIT ||
                        state == FLOOD_FILL_PROCESS) ? 
                        (fill_y * IMG_WIDTH + fill_x) : 
                        (scan_y * IMG_WIDTH + scan_x);
    
    logic is_white;
    assign is_white = (bram_rdata >= WHITE_THRESHOLD);
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_blob_count <= '0;
            largest_blob_area <= '0;
            zebra_detected <= 1'b0;
            detection_done <= 1'b0;
            bram_we <= 1'b0;
        end else begin
            bram_we <= 1'b0;
            detection_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start_detection) begin
                        scan_x <= '0;
                        scan_y <= '0;
                        blob_counter <= '0;
                        valid_blob_count <= '0;
                        largest_blob_area <= '0;
                        current_blob_id <= 8'd1;
                        state <= SCAN_FIND_SEED;
                    end
                end
                
                SCAN_FIND_SEED: begin
                    state <= SCAN_WAIT;
                end
                
                SCAN_WAIT: begin
                    state <= CHECK_SEED;
                end
                
                CHECK_SEED: begin
                    if (is_white) begin
                        // Found a seed pixel - start flood fill
                        stack[0] <= scan_y * IMG_WIDTH + scan_x;
                        stack_ptr <= 10'd1;
                        current_area <= '0;
                        state <= FLOOD_FILL_INIT;
                    end else begin
                        // Continue scanning
                        if (scan_x == IMG_WIDTH - 1) begin
                            scan_x <= '0;
                            if (scan_y == IMG_HEIGHT - 1) begin
                                state <= ALL_DONE;
                            end else begin
                                scan_y <= scan_y + 1;
                                state <= SCAN_FIND_SEED;
                            end
                        end else begin
                            scan_x <= scan_x + 1;
                            state <= SCAN_FIND_SEED;
                        end
                    end
                end
                
                FLOOD_FILL_INIT: begin
                    if (stack_ptr == 0) begin
                        // Flood fill complete for this blob
                        state <= BLOB_COMPLETE;
                    end else begin
                        // Pop from stack
                        stack_ptr <= stack_ptr - 1;
                        addr = stack[stack_ptr - 1];
                        fill_x <= addr % IMG_WIDTH;
                        fill_y <= addr / IMG_WIDTH;
                        state <= FLOOD_FILL_READ;
                    end
                end
                
                FLOOD_FILL_READ: begin
                    state <= FLOOD_FILL_WAIT;
                end
                
                FLOOD_FILL_WAIT: begin
                    state <= FLOOD_FILL_PROCESS;
                end
                
                FLOOD_FILL_PROCESS: begin
                    if (is_white) begin
                        // Mark as visited
                        bram_we <= 1'b1;
                        bram_wdata <= current_blob_id;
                        current_area <= current_area + 1;
                        
                        // Add neighbors to stack (4-connectivity)
                        if (fill_x > 0 && stack_ptr < 1023) begin
                            stack[stack_ptr] <= fill_y * IMG_WIDTH + (fill_x - 1);
                            stack_ptr <= stack_ptr + 1;
                        end
                        if (fill_x < IMG_WIDTH - 1 && stack_ptr < 1023) begin
                            stack[stack_ptr] <= fill_y * IMG_WIDTH + (fill_x + 1);
                            stack_ptr <= stack_ptr + 1;
                        end
                        if (fill_y > 0 && stack_ptr < 1023) begin
                            stack[stack_ptr] <= (fill_y - 1) * IMG_WIDTH + fill_x;
                            stack_ptr <= stack_ptr + 1;
                        end
                        if (fill_y < IMG_HEIGHT - 1 && stack_ptr < 1023) begin
                            stack[stack_ptr] <= (fill_y + 1) * IMG_WIDTH + fill_x;
                            stack_ptr <= stack_ptr + 1;
                        end
                    end
                    
                    state <= FLOOD_FILL_INIT;
                end
                
                BLOB_COMPLETE: begin
                    // Check if this blob is valid
                    if (current_area >= MIN_BLOB_AREA && 
                        current_area <= MAX_BLOB_AREA) begin
                        valid_blob_count <= valid_blob_count + 1;
                        
                        if (current_area > largest_blob_area) begin
                            largest_blob_area <= current_area;
                        end
                    end
                    
                    current_blob_id <= current_blob_id + 1;
                    state <= SCAN_FIND_SEED;
                end
                
                ALL_DONE: begin
                    zebra_detected <= (valid_blob_count >= 3);
                    detection_done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule