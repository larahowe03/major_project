module top_level(
	input         CLOCK_50,
	inout  [35:0] GPIO,
	input  [3:0]  KEY,
	output [6:0]  HEX0,
	output [6:0]  HEX1,
	output [6:0]  HEX2,
	output [6:0]  HEX3,
	output [17:0]  LEDR
);


logic reset;
logic start;

// front sensor variables
logic echo_front, trigger_front;
logic sonar_ready_front, sonar_valid_front;
logic [11:0] distance_mm_front;
logic [11:0] latched_distance_mm_front;

// back sensor variables
logic echo_back, trigger_back;
logic sonar_ready_back, sonar_valid_back;
logic [11:0] distance_mm_back;
logic [11:0] latched_distance_mm_back;

logic SONAR_CLK;

logic [15:0] bcd;

// assign front GPIO pins (J3 on adapter board)
assign echo_front = GPIO[29];
assign GPIO[27] = trigger_front;

// assign back GPIO pins (J4 on adapter board)
assign echo_back = GPIO[32];
assign GPIO[30] = trigger_back;


assign reset = !KEY[2];

always_ff @(posedge CLOCK_50) begin
	if (sonar_valid_front) begin
		latched_distance_mm_front <= distance_mm_front; 
	end
	if (sonar_valid_back) begin
		latched_distance_mm_back <= distance_mm_back; 
	end
end

sonar_pll sonar_pll (
	.areset(reset),
	.inclk0(CLOCK_50),
	.c0(SONAR_CLK)
	);

localparam SONAR_FREQ_HZ = 43904000;
localparam MEASURE_PERIOD_SEC = 1; // measure distance every 2 seconds
localparam MEASURE_CYCLES = SONAR_FREQ_HZ * MEASURE_PERIOD_SEC;

logic [26:0] counter;

always_ff @(posedge SONAR_CLK or negedge reset) begin
	if (reset) begin
		counter <= 0;
		start <= 0;
	end
	else if (counter >= MEASURE_CYCLES) begin
		counter <= 0;
		start <= 1'b1;
	end
	else begin
		counter <= counter + 1;
		start <= 1'b0;
	end
end
	
// Front sensor - get measurement
sonar_range sonar_range_front (
	.clk(SONAR_CLK), // must be 43.904MHz
	.start_measure(start),
	.rst(reset),
	.echo(echo_front),
	.trig(trigger_front),
	.distance(distance_mm_front),
	.ready(sonar_ready_front),
	.valid(sonar_valid_front)
);

// Back sensor - get measurement
sonar_range sonar_range_back (
	.clk(SONAR_CLK), // must be 43.904MHz
	.start_measure(start),
	.rst(reset),
	.echo(echo_back),
	.trig(trigger_back),
	.distance(distance_mm_back),
	.ready(sonar_ready_back),
	.valid(sonar_valid_back)
);


display u_display(
	.clk(CLOCK_50),
	.value(latched_distance_mm_front),
	.display0(HEX0),
	.display1(HEX1),
	.display2(HEX2),
	.display3(HEX3)
);


//--- can display the back sensor distance too using the two paired 7 segs 
// display u_display(
// 	.clk(CLOCK_50),
// 	.value(latched_distance_mm_front),
// 	.display0(HEX0),
// 	.display1(HEX1),
// 	.display2(HEX2),
// 	.display3(HEX3)
// );


logic stop_front;
logic stop_back;

obstacle_detect front_sensor (
	.THRESHOLD(1000)
	) detector (
	.clk(CLOCK_50),
	.distance_mm(latched_distance_mm_front),
	.valid(sonar_valid_front),
	.stop(stop_front)
);

obstacle_detect back_sensor (
	.THRESHOLD(500)
	) detector (
	.clk(CLOCK_50),
	.distance_mm(latched_distance_mm_back),
	.valid(sonar_valid_back),
	.stop(stop_back)
);

assign LEDR[17] = stop_front;
assign LEDR[16] = stop_back;

endmodule
