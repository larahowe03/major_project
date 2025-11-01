module simple_dual_port_bram #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 1
)(
    input logic clk,
    
    // Write port
    input logic we,
    input logic [ADDR_WIDTH-1:0] waddr,
    input logic [DATA_WIDTH-1:0] wdata,
    
    // Read port
    input logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata
);

    (* ramstyle = "M9K" *) logic [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];
    
    // Write port
    always_ff @(posedge clk) begin
        if (we) begin
            ram[waddr] <= wdata;
        end
    end
    
    // Read port (registered output)
    always_ff @(posedge clk) begin
        rdata <= ram[raddr];
    end

endmodule