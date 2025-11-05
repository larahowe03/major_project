module latch_distance (
    input  logic        clk,          // System clock
    input  logic        reset,        
    input  logic        valid,        
    input  logic [11:0] distance_mm,  
    output logic [11:0] latched_distance_mm  
);

    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            latched_distance_mm <= 12'd0;
        else if (valid)
            latched_distance_mm <= distance_mm;
    end

endmodule