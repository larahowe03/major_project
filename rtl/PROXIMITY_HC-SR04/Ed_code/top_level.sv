module top_level(
	input         CLOCK_50,
	inout  [35:0] GPIO,
	input  [3:0]  KEY,
	output [6:0]  HEX0,
	output [6:0]  HEX1,
	output [6:0]  HEX2,
	output [6:0]  HEX3,
	output [9:0]  LEDR
);

logic start;
logic reset;
logic echo, trigger;
logic sonar_ready, sonar_valid;
logic SONAR_CLK;
logic [11:0] distance_mm;
logic [11:0] latched_distance_mm;
logic [15:0] bcd;

assign echo = GPIO[29];
assign GPIO[27] = trigger;


always_ff @(posedge CLOCK_50) begin
	if (sonar_valid) begin
		latched_distance_mm <= distance_mm; 
	end
end

sonar_pll sonar_pll (
	.areset(reset),
	.inclk0(CLOCK_50),
	.c0(SONAR_CLK)
	);
	
	
sonar_range sonar_range(
	.clk(SONAR_CLK), // must be 43.904MHz
	.start_measure(!KEY[3]),
	.rst(!KEY[2]),
	.echo(echo),
	.trig(trigger),
	.distance(distance_mm),
	.ready(sonar_ready),
	.valid(sonar_valid)
);


display u_display(
	.clk(CLOCK_50),
   .value(latched_distance_mm),
   .display0(HEX0),
   .display1(HEX1),
   .display2(HEX2),
   .display3(HEX3)
);
 
endmodule
