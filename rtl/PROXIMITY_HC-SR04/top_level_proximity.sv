module top_level_proximity(
	input          CLOCK_50,
	inout  [35:0]  GPIO,
	input  [3:0]   KEY,
	output [6:0]   HEX0,
	output [6:0]   HEX1,
	output [6:0]   HEX2,
	output [6:0]   HEX3,
	output [6:0]   HEX4,
	output [6:0]   HEX5,
	output [6:0]   HEX6,
	output [6:0]   HEX7,
	output [17:0]  LEDR
);

logic reset;
logic start;
logic locked;

// Front sensor variables
logic echo_front, trigger_front;
logic sonar_ready_front, sonar_valid_front;
logic [11:0] distance_mm_front;
logic [11:0] latched_distance_mm_front;

// Back sensor variables
logic echo_back, trigger_back;
logic sonar_ready_back, sonar_valid_back;
logic [11:0] distance_mm_back;
logic [11:0] latched_distance_mm_back;

logic SONAR_CLK;

logic [15:0] bcd;

assign reset = !KEY[2];

//-------------------------------------------
// GPIO Pin Assignment
//-------------------------------------------

// Front sensor - J3 on adapter board
assign echo_front = GPIO[29];
assign GPIO[27] = trigger_front;

// Back sensor - J4 on adapter board
assign echo_back = GPIO[32];
assign GPIO[30] = trigger_back;

//-------------------------------------------
// Set Sensor Clock
//-------------------------------------------

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
	.c0(SONAR_CLK),
	.locked(locked)
	);

//-------------------------------------------
// Set start_measure flag
//-------------------------------------------

always_ff @(posedge SONAR_CLK or negedge reset) begin
    if (!reset) begin
        start   <= 0;
    end else begin
        if (sonar_ready_front) begin
            start   <= 1'b1;
        end else begin
            start   <= 1'b0;
        end
    end
end
		

//-------------------------------------------
// Get sensor measurements
//-------------------------------------------
	
// Front sensor
sonar_range sonar_range_front (
	.clk(SONAR_CLK), // must be 43.904MHz
	.start_measure(!start),
	.rst(reset),
	.echo(echo_front),
	.trig(trigger_front),
	.distance(distance_mm_front),
	.ready(sonar_ready_front),
	.valid(sonar_valid_front)
);

// Back sensor
sonar_range sonar_range_back (
	.clk(SONAR_CLK), // must be 43.904MHz
	.start_measure(!start),
	.rst(reset),
	.echo(echo_back),
	.trig(trigger_back),
	.distance(distance_mm_back),
	.ready(sonar_ready_back),
	.valid(sonar_valid_back)
);


//-------------------------------------------
// 7 Seg Display
//-------------------------------------------

// Display of Front sensor distance
display u_display1(
	.clk(CLOCK_50),
	.value(latched_distance_mm_front),
	.display0(HEX0),
	.display1(HEX1),
	.display2(HEX2),
	.display3(HEX3)
);

// Display of Back sensor distance
display u_display2(
	.clk(CLOCK_50),
	.value(latched_distance_mm_back),
	.display0(HEX4),
	.display1(HEX5),
	.display2(HEX6),
	.display3(HEX7)
);


//-------------------------------------------
// Obstacle Detection
//-------------------------------------------

logic stop_front;
logic stop_back;

obstacle_detect #(
	.THRESHOLD(1000)
	) detector_front (
	.clk(CLOCK_50),
	.distance_mm(latched_distance_mm_front),
	.direction(1'b0),
	.valid(sonar_valid_front),
	.stop(stop_front)
);

obstacle_detect #(
	.THRESHOLD(1000)
	) detector_back (
	.clk(CLOCK_50),
	.distance_mm(latched_distance_mm_back),
	.direction(1'b1),
	.valid(sonar_valid_back),
	.stop(stop_back)
);


// ----------------------
// Debug LEDs
// ----------------------

assign LEDR[17] = stop_front;          // obstacle detected
assign LEDR[16] = stop_back;   		   // valid pulse from sonar
assign LEDR[15] = start;               // trigger pulse (every 1s)

endmodule
