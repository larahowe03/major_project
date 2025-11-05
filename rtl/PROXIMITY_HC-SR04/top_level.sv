module top_level(
	input CLOCK_50,
	inout [35:0] GPIO,
	input [3:0] KEY,
	output [7:0] LEDR
);

logic start, reset;
logic echo, trigger;

assign echo = GPIO[34];
assign GPIO[35] = trigger;

debounce start_edge(
    .clk(CLOCK_50),
	 .button(!KEY[3]),
    .button_edge(start)
);

debounce reset_edge(
    .clk(CLOCK_50),
	 .button(!KEY[2]),
    .button_edge(reset)
);

sensor_driver u0(
  .clk(CLOCK_50),
  .rst(reset),
  .measure(start),
  .echo(echo),
  .trig(trigger), 
  .distance(LEDR));
  
endmodule