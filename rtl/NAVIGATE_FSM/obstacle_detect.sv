module obstacle_detect # (
	parameter THRESHOLD = 1000
)(
	input  logic 			clk,
	input  logic [11:0] 	distance_mm,
	input  logic 			direction,
	input  logic 			valid,
	output logic 			stop
);

  logic in_range;
  always_comb begin
    in_range = (distance_mm >= 50) && (distance_mm <= 4000);
  end
  
  
  
	always_ff @(posedge clk) begin
		if (valid) begin
			if (direction == 1'b0) begin
				if ((distance_mm < THRESHOLD) && (in_range)) begin
					stop <= 1'b1;
				end
				else begin
					stop <= 1'b0;
				end
			end
			else begin
				if ((distance_mm > THRESHOLD) || ((distance_mm >= 59) && distance_mm <= 65)) begin
					stop <= 1'b1;
				end
				else begin
					stop <= 1'b0;
				end
			end
		end
	end
	
endmodule
