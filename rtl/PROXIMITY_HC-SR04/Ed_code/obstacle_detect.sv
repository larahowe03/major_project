module obstacle_detect # (
	parameter THRESHOLD = 1000
)(
	input  logic 			clk,
	input  logic [11:0] 	distance_mm,
	input  logic 			valid,
	output logic 			stop
);

	always_ff @(posedge clk) begin
		if (valid) begin
			if (distance_mm < THRESHOLD) begin
				stop <= 1'b1;
			end
			else begin
				stop <= 1'b0;
			end
		end
	end
	
endmodule
