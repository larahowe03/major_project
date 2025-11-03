module binary_bram #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter ADDR_WIDTH
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream (write images)
    input logic x_valid,
    output logic x_ready,
    input logic [7:0] x_data_edge,
    input logic [7:0] x_data_threshold,
    
    // Read port for edge detector
    input logic [ADDR_WIDTH-1:0] read_addr_edge,
    output logic [1:0] read_data_edge,
    
    // Read port for threshold detector
    input logic [ADDR_WIDTH-1:0] read_addr_threshold,
    output logic [1:0] read_data_threshold,
    
    // Write port for marking visited (FIXED: Added these!)
    input logic mark_visited_we,
    input logic [ADDR_WIDTH-1:0] mark_visited_addr,
    
    // Control signals
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    
    state_t state;
    logic [ADDR_WIDTH-1:0] write_addr;
    
    // 4-bit BRAM: [1:0]=edge (00=black, 01=white, 10=visited), [3:2]=threshold
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;  // 307,200
    
    // FIXED: Use exact image size, not 2^ADDR_WIDTH
    (* ramstyle = "M9K" *) logic [3:0] bram_array [0:TOTAL_PIXELS-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    logic binary_pixel_edge;
    assign binary_pixel_edge = (x_data_edge == 8'd255);

    logic binary_pixel_threshold;
    assign binary_pixel_threshold = (x_data_threshold == 8'd255);

    logic initial_reading;
    logic capture_trigger_d1;
    wire capture_trigger_edge = capture_trigger && !capture_trigger_d1;
    
    // State machine for capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_addr <= '0;
            capture_complete <= 1'b0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
            initial_reading <= 1'b1;
            capture_trigger_d1 <= 1'b0;
        end else begin
            capture_complete <= 1'b0;
            capture_trigger_d1 <= capture_trigger;
            
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    
                    // Start on initial read or trigger edge
                    if (initial_reading || capture_trigger_edge) begin
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_addr <= '0;
                        valid_to_read <= 1'b0;
                        initial_reading <= 1'b0;
                    end
                end
                
                CAPTURING: begin
                    if (handshake) begin
                        bram_array[write_addr] <= {
                            binary_pixel_threshold ? 2'b01 : 2'b00,
                            binary_pixel_edge ? 2'b01 : 2'b00
                        };
                        
                        // FIXED: Check against actual pixel count
                        if (write_addr == TOTAL_PIXELS - 1) begin
                            write_addr <= '0;
                            state <= COMPLETE;
                        end else begin
                            write_addr <= write_addr + 1;
                        end
                    end
                end
                
                COMPLETE: begin
                    capturing <= 1'b0;
                    capture_complete <= 1'b1;
                    valid_to_read <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign x_ready = (state == CAPTURING);
    
    // ========================================================================
    // DUAL PORT: Read + Mark Visited
    // ========================================================================
    always_ff @(posedge clk) begin
        // Write port: Mark as visited ONLY when requested (FIXED!)
        if (mark_visited_we && valid_to_read) begin
            bram_array[mark_visited_addr][1:0] <= 2'b10;
        end
        
        // Read ports: Always reading
        read_data_edge <= bram_array[read_addr_edge][1:0];
        read_data_threshold <= bram_array[read_addr_threshold][3:2];
    end

endmodule