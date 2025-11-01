module image_bram #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream (write)
    input logic x_valid,
    output logic x_ready,
    input logic [7:0] x_data,
    
    // Read port - ADDED
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] read_addr,
    output logic read_data,  // 1-bit output
    
    // Control signals
    input logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    
    state_t state;
    
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    logic [$clog2(TOTAL_PIXELS)-1:0] write_addr;
    
    // 1-bit BRAM array
    (* ramstyle = "M9K" *) logic bram_array [0:TOTAL_PIXELS-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    logic binary_pixel;
    assign binary_pixel = (x_data == 8'd255);
    
    // State machine and capture logic (same as before)
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
                        bram_array[write_addr] <= binary_pixel;
                        
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
    // READ PORT - Registered output for BRAM inference
    // ========================================================================
    always_ff @(posedge clk) begin
        if (valid_to_read)
            read_data <= bram_array[read_addr];
    end

endmodule