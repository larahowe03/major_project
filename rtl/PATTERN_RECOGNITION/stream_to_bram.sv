module stream_to_bram #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream (pass-through)
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data,
    
    // BRAM write interface
    output logic bram_we,
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_addr,
    output logic [W-1:0] bram_data,
    
    // Frame completion signal - ADDED THIS!
    output logic frame_complete
);

    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    // Position tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
            frame_complete <= 1'b0;  // ADDED THIS!
        end else begin
            frame_complete <= 1'b0;  // ADDED THIS! (default to 0, pulse high for 1 cycle)
            
            if (handshake) begin
                if (x_pos == IMG_WIDTH - 1) begin
                    x_pos <= '0;
                    if (y_pos == IMG_HEIGHT - 1) begin
                        y_pos <= '0;
                        frame_complete <= 1'b1;  // ADDED THIS! (pulse when frame ends)
                    end else begin
                        y_pos <= y_pos + 1;
                    end
                end else begin
                    x_pos <= x_pos + 1;
                end
            end
        end
    end
    
    // Write to BRAM
    assign bram_we = handshake;
    assign bram_addr = y_pos * IMG_WIDTH + x_pos;
    assign bram_data = x_data;
    
    // Pass-through for downstream processing
    assign x_ready = y_ready | ~y_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_valid <= 1'b0;
            y_data <= '0;
        end else begin
            if (handshake) begin
                y_valid <= x_valid;
                y_data <= x_data;
            end else if (y_ready && y_valid) begin
                y_valid <= 1'b0;
            end
        end
    end

endmodule