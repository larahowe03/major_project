module binary_bram #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream
    input logic x_valid,
    output logic x_ready,
    input logic [7:0] x_data,
    
    // Read port
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] read_addr,
    output logic [1:0] read_data,
    
    // Mark visited
    input logic mark_visited_we,
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] mark_visited_addr,
    
    // Control
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;  // 76,800
    localparam ADDR_WIDTH = $clog2(TOTAL_PIXELS);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    state_t state;
    
    logic [ADDR_WIDTH-1:0] write_addr;
    
    // FIXED: Use exact pixel count
    (* ramstyle = "M9K" *) logic [1:0] bram_array [0:TOTAL_PIXELS-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    logic binary_pixel;
    assign binary_pixel = (x_data == 8'd255);

    logic initial_reading;
    logic capture_trigger_d1;
    wire capture_trigger_edge = capture_trigger && !capture_trigger_d1;
    
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
                        bram_array[write_addr] <= binary_pixel ? 2'b01 : 2'b00;
                        
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
    
    // Read/Write ports
    always_ff @(posedge clk) begin
        if (mark_visited_we && valid_to_read) begin
            bram_array[mark_visited_addr] <= 2'b10;
        end
        
        read_data <= bram_array[read_addr];
    end

endmodule