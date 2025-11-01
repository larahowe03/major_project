module bram_writer #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream
    input logic x_valid,
    output logic x_ready,  // FIXED: Uncommented
    input logic [7:0] x_data,
    
    // Control signals
    input logic capture_trigger,      // Pulse this to start capturing a frame
    output logic valid_to_read,       // Stays high while you can read from bram
    output logic capture_complete,    // Pulse when finished saving a frame
    output logic capturing            // High while actively capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    
    state_t state;
    
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // Just the write address counter
    logic [$clog2(TOTAL_PIXELS)-1:0] write_addr;
    
    // 1-bit BRAM array
    logic bram_array [0:TOTAL_PIXELS-1];
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    // Binary conversion: white (255) = 1, black (0) = 0
    logic binary_pixel;
    assign binary_pixel = (x_data == 8'd255);
    
    // State machine and capture logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_addr <= '0;
            capture_complete <= 1'b0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
        end else begin
            capture_complete <= 1'b0;  // FIXED: Default to 0, only pulse high
            
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    
                    if (capture_trigger) begin
                        // Start capturing
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_addr <= '0;
                        valid_to_read <= 1'b0;  // Clear while capturing
                    end
                end
                
                CAPTURING: begin
                    if (handshake) begin
                        // Write to BRAM
                        bram_array[write_addr] <= binary_pixel;
                        
                        // Check if frame complete
                        if (write_addr == TOTAL_PIXELS - 1) begin
                            // Frame complete!
                            write_addr <= '0;
                            state <= COMPLETE;
                        end else begin
                            write_addr <= write_addr + 1;
                        end
                    end
                end
                
                COMPLETE: begin
                    capturing <= 1'b0;
                    capture_complete <= 1'b1;     // Pulse high for 1 cycle
                    valid_to_read <= 1'b1;        // Set and HOLD high
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Ready to accept data only when capturing
    assign x_ready = (state == CAPTURING);

endmodule