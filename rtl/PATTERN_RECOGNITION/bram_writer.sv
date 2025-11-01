module binary_bram #(
    parameter ADDR_WIDTH
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream (write edge image)
    input logic x_valid,
    output logic x_ready,
    input logic [7:0] x_data,
    
    // Read port for detector
    input logic [$clog2(ADDR_WIDTH)-1:0] read_addr,
    output logic [1:0] read_data,  // 2-bit output: 0=black, 1=white, 2=visited
    
    // Write port for marking visited
    input logic mark_visited_we,
    input logic [$clog2(ADDR_WIDTH)-1:0] mark_visited_addr,
    
    // Control signals
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    
    state_t state;
    
    logic [$clog2(ADDR_WIDTH)-1:0] write_addr;
    
    // 2-bit BRAM array: 00=black, 01=white, 10=visited
    (* ramstyle = "M9K" *) logic [1:0] bram_array [0:ADDR_WIDTH-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    logic binary_pixel;
    assign binary_pixel = (x_data == 8'd255);
    
    // State machine for capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_addr <= '0;
            capture_complete <= 1'b0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
        end else begin
            capture_complete <= 1'b0;
            
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    
                    if (capture_trigger) begin
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_addr <= '0;
                        valid_to_read <= 1'b0;
                    end
                end
                
                CAPTURING: begin
                    if (handshake) begin
                        // Write 0 (black) or 1 (white edge)
                        bram_array[write_addr] <= binary_pixel ? 2'b01 : 2'b00;
                        
                        if (write_addr == ADDR_WIDTH - 1) begin
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
        // Write port: Mark as visited (set to 2'b10)
        if (mark_visited_we && valid_to_read) begin
            bram_array[mark_visited_addr] <= 2'b10;
        end
        
        // Read port: Always reading
        read_data <= bram_array[read_addr];
    end

endmodule