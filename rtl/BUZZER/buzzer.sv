module buzzer # (
    input  logic        clk,
    input  logic        trigger,
    inout  logic [35:0] GPIO
)
    logic [25:0] counter;
    logic active = 0;
    logic trigger_prev = 0;

    always_ff @(posedge clk) begin
        trigger_prev <= trigger;

        if (trigger && !trigger_prev) begin
            active <= 1;
            counter <= 0;
        end
        else if (active) begin
            if (counter >= 50000000) begin
                active <= 0;
            end
            else begin
                counter <= counter + 1;
            end
        end
    end

    assign GPIO[2] = active;

endmodule