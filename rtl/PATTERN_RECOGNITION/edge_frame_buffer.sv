module edge_frame_buffer #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 8
)(
    input logic clock,
    
    // Port A: Write only (from stream)
    input logic [DATA_WIDTH-1:0] data_a,
    input logic [ADDR_WIDTH-1:0] address_a,
    input logic wren_a,
    output logic [DATA_WIDTH-1:0] q_a,
    
    // Port B: Read/Write (for blob detector)
    input logic [DATA_WIDTH-1:0] data_b,
    input logic [ADDR_WIDTH-1:0] address_b,
    input logic wren_b,
    output logic [DATA_WIDTH-1:0] q_b
);

    // Dual-port RAM
    logic [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];
    
    // Port A
    always_ff @(posedge clock) begin
        if (wren_a) begin
            ram[address_a] <= data_a;
        end
        q_a <= ram[address_a];
    end
    
    // Port B
    always_ff @(posedge clock) begin
        if (wren_b) begin
            ram[address_b] <= data_b;
        end
        q_b <= ram[address_b];
    end

endmodule