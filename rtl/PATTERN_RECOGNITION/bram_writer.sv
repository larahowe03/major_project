module binary_bram #(
    parameter ADDR_WIDTH
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream (write edge image)
    input logic x_valid,
    output logic x_ready,
    input logic [7:0] x_data_edge,
    input logic [7:0] x_data_threshold,
    
    // Read port for detector
    input logic [ADDR_WIDTH-1:0] read_addr_edge,
    output logic [1:0] read_data_edge,  // 2-bit output: 0=black, 1=white, 2=visited

    input logic [ADDR_WIDTH-1:0] read_addr_threshold,
    output logic [1:0] read_data_threshold,  // 2-bit output: 0=black, 1=white, 2=visited
    
    // Control signals
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;

    // [1:0] is edge data
    // [3:2] is threshold data
    
    state_t state;
    
    logic [ADDR_WIDTH-1:0] write_addr;
    
    // 2-bit BRAM array: 00=black, 01=white, 10=visited
    (* ramstyle = "M9K" *) logic [3:0] bram_array [0:2**ADDR_WIDTH-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    logic binary_pixel_edge;
    assign binary_pixel_edge = (x_data_edge == 8'd255);

    logic binary_pixel_threshold;
    assign binary_pixel_threshold = (x_data_threshold == 8'd255);

    logic initial_reading;
    
    // State machine for capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_addr <= '0;
            capture_complete <= 1'b0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
            initial_reading <= 1'b1;
        end else begin
            capture_complete <= 1'b0;
            
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    
                    if (capture_trigger || initial_reading) begin
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_addr <= '0;
                        valid_to_read <= 1'b0;
                        initial_reading <= 1'b0;
                    end
                end
                
                CAPTURING: begin
                    if (handshake) begin
                        // Write 0 (black) or 1 (white edge)
                        bram_array[write_addr][1:0] <= binary_pixel_edge ? 2'b01 : 2'b00;
                        bram_array[write_addr][3:2] <= binary_pixel_threshold ? 2'b01 : 2'b00;

                        
                        if (write_addr == (1 << ADDR_WIDTH) - 1) begin
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
        if (valid_to_read) begin
            bram_array[read_addr][1:0] <= 2'b10;
        end
        
        // Read port: Always reading
        read_data_edge <= bram_array[read_addr][1:0];
        read_data_threshold <= bram_array[read_addr][3:2];
    end

endmodule