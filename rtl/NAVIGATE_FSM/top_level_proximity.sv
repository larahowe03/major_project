module top_level_proximity(
  input          CLOCK_50,
  inout  [35:0]  GPIO,
  input  [3:0]   KEY,
  //output [6:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
  output [17:15] LEDR, 
  // NEW:
  input  logic   rst_n,
  input  logic   tick_20hz,

  output logic   stop_front_2s,   // persisted 2 s near
  output logic   stop_back_1s
);

  logic reset; 
 assign reset= !KEY[2];

  // -------- sonar signals (unchanged) --------
  logic echo_front, trigger_front, sonar_ready_front, sonar_valid_front;
  logic [11:0] distance_mm_front, latched_distance_mm_front;

  logic echo_back,  trigger_back,  sonar_ready_back,  sonar_valid_back;
  logic [11:0] distance_mm_back,  latched_distance_mm_back;

  logic SONAR_CLK, locked, start;

//  // Pin map
//  assign echo_front = GPIO[29];
//  assign GPIO[27]   = trigger_front;
//  assign echo_back  = GPIO[32];
//  assign GPIO[30]   = trigger_back;
//  
  
  // Pin map (SWAPPED: the module labeled “front” is wired where “back” used to be, and vice-versa)

// New FRONT sensor on J4 pins
assign echo_front = GPIO[32];   // input from front sensor
assign GPIO[30]   = trigger_front; // output to front sensor

// New BACK sensor on J3 pins
assign echo_back  = GPIO[29];   // input from back sensor
assign GPIO[27]   = trigger_back;  // output to back sensor

  // Latch latest distances on valid (OK to latch in CLOCK_50)
  // always_ff @(posedge CLOCK_50) begin
    // if (sonar_valid_front) latched_distance_mm_front <= distance_mm_front;
    // if (sonar_valid_back)  latched_distance_mm_back  <= distance_mm_back;
  // end
  
  latch_distance latch_front_distance (
    .clk(CLOCK_50),
    .reset(reset),
    .valid(sonar_valid_front),
    .distance_mm(distance_mm_front),
    .latched_distance_mm(latched_distance_mm_front)
  )

  latch_distance latch_back_distance (
    .clk(CLOCK_50),
    .reset(reset),
    .valid(sonar_valid_back),
    .distance_mm(distance_mm_back),
    .latched_distance_mm(latched_distance_mm_back)
  )
  sonar_pll u_pll (.areset(reset), .inclk0(CLOCK_50), .c0(SONAR_CLK), .locked(locked));

  // Generate start_measure on SONAR_CLK
  always_ff @(posedge SONAR_CLK or negedge reset) begin
    if (!reset)           start <= 1'b0;
    else if (sonar_ready_front) start <= 1'b1;
    else                  start <= 1'b0;
  end

  // Front sonar @ 43.904 MHz
  sonar_range sonar_range_front (
    .clk(SONAR_CLK), .start_measure(!start), .rst(reset), .echo(echo_front),
    .trig(trigger_front), .distance(distance_mm_front),
    .ready(sonar_ready_front), .valid(sonar_valid_front)
  );

  // Back sonar @ 43.904 MHz
  sonar_range sonar_range_back (
    .clk(SONAR_CLK), .start_measure(!start), .rst(reset), .echo(echo_back),
    .trig(trigger_back), .distance(distance_mm_back),
    .ready(sonar_ready_back), .valid(sonar_valid_back)
  );

//  // 7-segment (unchanged)
//  display u_display1(.clk(CLOCK_50), .value(latched_distance_mm_front),
//                     .display0(HEX0), .display1(HEX1), .display2(HEX2), .display3(HEX3));
//  display u_display2(.clk(CLOCK_50), .value(latched_distance_mm_back),
//                     .display0(HEX4), .display1(HEX5), .display2(HEX6), .display3(HEX7));

  // ---------- Threshold detectors ----------
  logic stop_front;  // RAW front near flag (declare it!)
  logic stop_back; 
  
  obstacle_detect #(.THRESHOLD(500)) detector_front (
    .clk(CLOCK_50),
    .distance_mm(latched_distance_mm_front),
    .direction(1'b0),              // 0 => stop=1 when dist < THRESHOLD
    .valid(sonar_valid_front),
    .stop(stop_front)
  );

  obstacle_detect #(.THRESHOLD(750)) detector_back (
    .clk(CLOCK_50),
    .distance_mm(latched_distance_mm_back),
    .direction(1'b1),              // 1 => stop=1 when dist > THRESHOLD (person is FAR)
    .valid(sonar_valid_back),
    .stop(stop_back)
  );

  // ---------- 2 s persistence on the FRONT raw flag ----------
  level_persist #(.ASSERT_TICKS(20), .CLEAR_TICKS(6)) u_front_hold (
    .clk       (CLOCK_50),
    .rst_n     (rst_n),
    .tick_20hz (tick_20hz),
    .in_level  (stop_front),
    .out_level (stop_front_2s) // this is actually 1 second so we can change the naming later though 
  );

  
  level_persist #(
  .ASSERT_TICKS(20),
  .CLEAR_TICKS (6)
) u_hold_back (
  .clk       (CLOCK_50),
  .rst_n     (rst_n),
  .tick_20hz (tick_20hz),
  .in_level  (stop_back),    
  .out_level (stop_back_1s)
);


  // Debug LEDs (subrange)
  assign LEDR[17] = stop_front;       // raw near (can flicker)
  assign LEDR[16] = stop_front_2s;    // persisted 2 s
             // sonar start strobe (approx 1 Hz)
  assign LEDR[15] = stop_back_1s; 

endmodule



////module top_level_proximity(
////	input          CLOCK_50,
////	inout  [35:0]  GPIO,
////	input  [3:0]   KEY,
////	output [6:0]   HEX0,
////	output [6:0]   HEX1,
////	output [6:0]   HEX2,
////	output [6:0]   HEX3,
////	output [6:0]   HEX4,
////	output [6:0]   HEX5,
////	output [6:0]   HEX6,
////	output [6:0]   HEX7,
////	output [17:15]  LEDR, 
////	output logic stop_front_2s, //put a tiny gate that it checks for signals 
////	output logic stop_back
////);
//
//module top_level_proximity(
//  input          CLOCK_50,
//  inout  [35:0]  GPIO,
//  input  [3:0]   KEY,
//  output [6:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
//  output [17:15] LEDR, 
//  // NEW:
//  input  logic   rst_n,
//  input  logic   tick_20hz,
//
//  output logic   stop_front_2s,   // persisted 2 s near
//  output logic   stop_back
//);
//
//
//logic reset;
//logic start;
//logic locked;
//
//// Front sensor variables
//logic echo_front, trigger_front;
//logic sonar_ready_front, sonar_valid_front;
//logic [11:0] distance_mm_front;
//logic [11:0] latched_distance_mm_front;
//
//// Back sensor variables
//logic echo_back, trigger_back;
//logic sonar_ready_back, sonar_valid_back;
//logic [11:0] distance_mm_back;
//logic [11:0] latched_distance_mm_back;
//
//logic SONAR_CLK;
//
//logic [15:0] bcd;
//
//assign reset = !KEY[2];
//
////-------------------------------------------
//// GPIO Pin Assignment
////-------------------------------------------
//
//// Front sensor - J3 on adapter board
//assign echo_front = GPIO[29];
//assign GPIO[27] = trigger_front;
//
//// Back sensor - J4 on adapter board
//assign echo_back = GPIO[32];
//assign GPIO[30] = trigger_back;
//
////-------------------------------------------
//// Set Sensor Clock
////-------------------------------------------
//
//always_ff @(posedge CLOCK_50) begin
//	if (sonar_valid_front) begin
//		latched_distance_mm_front <= distance_mm_front; 
//	end
//	if (sonar_valid_back) begin
//		latched_distance_mm_back <= distance_mm_back; 
//	end
//end
//
//
//
//
//sonar_pll sonar_pll (
//	.areset(reset),
//	.inclk0(CLOCK_50),
//	.c0(SONAR_CLK),
//	.locked(locked)
//	);
//
////-------------------------------------------
//// Set start_measure flag
////-------------------------------------------
//
//always_ff @(posedge SONAR_CLK or negedge reset) begin
//    if (!reset) begin
//        start   <= 0;
//    end else begin
//        if (sonar_ready_front) begin
//            start   <= 1'b1;
//        end else begin
//            start   <= 1'b0;
//        end
//    end
//end
//		
//
////-------------------------------------------
//// Get sensor measurements
////-------------------------------------------
//	
//// Front sensor
//sonar_range sonar_range_front (
//	.clk(SONAR_CLK), // must be 43.904MHz
//	.start_measure(!start),
//	.rst(reset),
//	.echo(echo_front),
//	.trig(trigger_front),
//	.distance(distance_mm_front),
//	.ready(sonar_ready_front),
//	.valid(sonar_valid_front)
//);
//
//// Back sensor
//sonar_range sonar_range_back (
//	.clk(SONAR_CLK), // must be 43.904MHz
//	.start_measure(!start),
//	.rst(reset),
//	.echo(echo_back),
//	.trig(trigger_back),
//	.distance(distance_mm_back),
//	.ready(sonar_ready_back),
//	.valid(sonar_valid_back)
//);
//
//
////-------------------------------------------
//// 7 Seg Display
////-------------------------------------------
//
//// Display of Front sensor distance
//display u_display1(
//	.clk(CLOCK_50),
//	.value(latched_distance_mm_front),
//	.display0(HEX0),
//	.display1(HEX1),
//	.display2(HEX2),
//	.display3(HEX3)
//);
//
//// Display of Back sensor distance
//display u_display2(
//	.clk(CLOCK_50),
//	.value(latched_distance_mm_back),
//	.display0(HEX4),
//	.display1(HEX5),
//	.display2(HEX6),
//	.display3(HEX7)
//);
//
//
////-------------------------------------------
//// Obstacle Detection
////-------------------------------------------
//
////logic stop_front;
////logic stop_back;
//
//obstacle_detect #(
//	.THRESHOLD(300)
//	) detector_front (
//	.clk(CLOCK_50),
//	.distance_mm(latched_distance_mm_front),
//	.direction(1'b0),
//	.valid(sonar_valid_front),
//	.stop(stop_front)
//);
//
//obstacle_detect #(
//	.THRESHOLD(1000)
//	) detector_back (
//	.clk(CLOCK_50),
//	.distance_mm(latched_distance_mm_back),
//	.direction(1'b1),
//	.valid(sonar_valid_back),
//	.stop(stop_back)
//);
//
////logic stop_front_2s;
//
//level_persist #(
//  .ASSERT_TICKS(40),  // 40/20Hz = 2.0s to assert
//  .CLEAR_TICKS (6)    // 6/20Hz  = 0.3s to clear (tune)
//) u_front_hold (
//  .clk       (CLOCK_50),
//  .rst_n     (rst_n),           // or ~reset if that’s your polarity
//  .tick_20hz (tick_20hz),
//  .in_level  (stop_front),  // raw from obstacle_detect
//  .out_level (stop_front_2s)    // clean + persisted 2s
//);
//
//
//
//
//// ----------------------
//// Debug LEDs
//// ----------------------
//
//assign LEDR[17] = stop_front;          // obstacle detected
//
//assign LEDR[16] = stop_front_2s; 
//
////assign LEDR[16] = stop_back;   		   // valid pulse from sonar
//assign LEDR[15] = start;               // trigger pulse (every 1s)
//
//endmodule
