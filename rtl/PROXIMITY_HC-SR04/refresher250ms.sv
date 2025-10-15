module refresher250ms (
    input CLOCK_50,
    input en,
    output measure
);
    logic [24:0] counter;

    assign measure = (counter == 25'd1);

    always @(posedge CLOCK_50) begin
        if (~en | (counter == 25'd12_500_000)) begin
            counter <= 25'd0;
        end else begin
            counter <= 25'd1 + counter;
        end
    end
endmodule
