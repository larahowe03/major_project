// Top level: OLD guide-dog controller WITHOUT proximity / mic / vision.
// Uses only the board switches for testing the turning sequence and stops.
//
// SW0 (edge)  -> start
// SW1 (level) -> obstacle_stop (triggers maneuver)
// SW2 (level) -> zebra_pattern_stop (timed STOP)
// SW3 (level) -> person_far_away_stop (hold STOP)
// SW4 (level) -> clap stop (hold STOP)
// KEY0 (active-low) -> emergency stop (hold STOP)
// KEY1 (active-low) -> reset
//
// UART JSON is sent on GPIO[31] (TX) @115200 8N1.

module top_level_guide_dog_old_without_prox (
  input  logic        CLOCK_50,
  input  logic [9:0]  SW,          // SW0=start, SW1=obstacle, SW2=zebra, SW3=person_far
  input  logic [3:0]  KEY,         // KEY1=reset (active-low), KEY0=estop (active-low)
  inout  [35:0]       GPIO,        // GPIO[31] = UART TX to UGV02 RX
  output logic [9:0]  LEDR
);

  // =================== Reset ===================
  logic rst_n;
  assign rst_n = KEY[1];   // KEY1 held low = reset

  // =================== Debounced inputs ===================
  // edge + level helper for START
  logic start_lvl, start_rise;
  deb_edge u_start (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[0]), .level(start_lvl), .rise(start_rise));

  // Level-only debounces
  logic obstacle_lvl;     deb_edge u_obs  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[1]), .level(obstacle_lvl),   .rise());
  logic zebra_lvl;        deb_edge u_zeb  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[2]), .level(zebra_lvl),      .rise());
  logic person_far_lvl;   deb_edge u_far  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[3]), .level(person_far_lvl), .rise());
  logic clap_lvl;         deb_edge u_clap (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[4]), .level(clap_lvl),       .rise());

  // Emergency stop from KEY0 (active-low button)
  logic ir_emerg_lvl;
  assign ir_emerg_lvl = ~KEY[0];  // no debounce needed

  // =================== 20 Hz heartbeat ===================
  logic tick_20hz;
  tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(20)) u_tick(
    .clk(CLOCK_50), .rst_n(rst_n), .tick(tick_20hz)
  );

  // =================== Command bus (3 bits) ===================
  logic [2:0] cmd_sel;
//  
//      // Obstacle maneuver timing (ms)
//    .BACK_MS  (3800),
//    .R1_MS    (2400),
//    .L1_MS    (800),    // small left
//    .COAST_MS (1200),   // straight
//    .L2_MS    (5000),   // continue left
//    .R2_MS    (3400),

  // =================== Guide FSM ===================
  
//  
//  guide_fsm #(
//  .CLK_HZ   (50_000_000),
//  .TICK_HZ  (20),
//  .BACK_MS  (2000),
//  .R1_MS    (3000),
//  .L1_MS    (800),   // small left
//  .COAST_MS (1800),  // straight
//  .L2_MS    (5000),   // continue left
//  .R2_MS    (3400),
//  .ZEBRA_MS (3000)


  // Tune these to test your turning behavior.
  guide_fsm #(
  .CLK_HZ   (50_000_000),
  .TICK_HZ  (20),
  .BACK_MS  (4200),
  .R1_MS    (2500),
  .L1_MS    (2500),   // small left
  .COAST_MS (200),  // straight
  .L2_MS    (2800),   // continue left
  .R2_MS    (2800),
    // Zebra stop time
    .ZEBRA_MS (3000)
  ) u_fsm (
    .clk                     (CLOCK_50),
    .rst_n                   (rst_n),

    // <<< back to the debounced switches >>>
    .start_whistle           (start_rise),      // SW0 edge
    .obstacle_stop           (obstacle_lvl),    // SW1 level
    .zebra_pattern_stop      (zebra_lvl),       // SW2 level
    .person_far_away_stop    (person_far_lvl),  // SW3 level

    .stop_command_clap       (clap_lvl),        // SW4 level
    .IR_remote_emergency_stop(ir_emerg_lvl),    // KEY0 active-low => level high here
    .tick_20hz               (tick_20hz),
    .cmd_sel                 (cmd_sel)          // 3-bit command bus
  );

  // =================== JSON burst + UART ===================
  logic       tx_valid, tx_ready;
  logic [7:0] byte_to_send;

  json_burst #(.TICK_HZ(20)) u_burst (
    .clk          (CLOCK_50),
    .rst_n        (rst_n),
    .tick_20hz    (tick_20hz),
    .cmd_sel      (cmd_sel),        // 3 bits: STOP, FWD, ARC_L, ARC_R, REV
    .tx_valid     (tx_valid),
    .tx_ready     (tx_ready),
    .byte_to_send (byte_to_send)
  );

  uart_tx #(
    .CLKS_PER_BIT(50_000_000/115200),
    .BITS_N(8),
    .PARITY_TYPE(0)
  ) u_uart (
    .clk      (CLOCK_50),
    .rst      (1'b0),               // keep deasserted
    .data_tx  (byte_to_send),
    .valid    (tx_valid),
    .ready    (tx_ready),
    .uart_out (GPIO[31])            // TX to UGV02 RX
  );

  // =================== (Optional) LEDs ===================
  localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1, CMD_ARC_L=3'd2, CMD_ARC_R=3'd3, CMD_REV=3'd4;
  assign LEDR[6] = (cmd_sel == CMD_STOP);
  assign LEDR[7] = (cmd_sel == CMD_FWD);
  assign LEDR[8] = (cmd_sel == CMD_ARC_L) | (cmd_sel == CMD_ARC_R);
  assign LEDR[9] = (cmd_sel == CMD_REV);

  // Handshake/debug
  assign LEDR[4] = tx_valid;  // 1-clk pulses (invisible by eye)
  assign LEDR[5] = tx_ready;  // should dip during frames if observed on LA

  // Byte counter per burst (helps you see 24/25/26/27)
  logic [7:0] sent_cnt;
  always_ff @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n)          sent_cnt <= 8'd0;
    else if (tick_20hz)  sent_cnt <= 8'd0;
    else if (tx_valid)   sent_cnt <= sent_cnt + 8'd1;
  end
  assign LEDR[3:0] = sent_cnt[3:0];

endmodule




//module top_level_guide_dog_old_without_prox (
//  input  logic        CLOCK_50,
//  input  logic [9:0]  SW,          // SW0=start, SW1=obstacle, SW2=zebra, SW3=path_clear
//  input  logic [3:0]  KEY,         // KEY1=reset (active-low), KEY0=estop (active-low)
//  inout  [35:0]       GPIO,        // GPIO[31] = UART TX to UGV02 RX
//  output logic [9:0]  LEDR
//);
//  // =================== Reset ===================
//logic rst_n; 
//assign rst_n = KEY[1];   // KEY1 held low = reset
//
//// =================== Debounced inputs ===================
//// edge + level helper
//logic start_lvl, start_rise;
//deb_edge u_start (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[0]),   .level(start_lvl), .rise(start_rise));
//
//// Level-only debounces (rises unused)
//logic obstacle_lvl;        deb_edge u_obs  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[1]),   .level(obstacle_lvl),      .rise());
//logic zebra_lvl;           deb_edge u_zeb  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[2]),   .level(zebra_lvl),         .rise());
//logic person_far_lvl;      deb_edge u_far  (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[3]),   .level(person_far_lvl),    .rise());
//logic clap_lvl;            deb_edge u_clap (.clk(CLOCK_50), .rst_n(rst_n), .raw_in(SW[4]),   .level(clap_lvl),          .rise());
//
//// Emergency stop from KEY0 (active-low button)
//logic ir_emerg_lvl;
//assign ir_emerg_lvl = ~KEY[0];  // no debounce needed if you don’t want it
//
//// =================== 20 Hz heartbeat ===================
//logic tick_20hz;
//tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(20)) u_tick(
//  .clk(CLOCK_50), .rst_n(rst_n), .tick(tick_20hz)
//);
//
//// =================== Command bus (3 bits) ===================
//logic [2:0] cmd_sel;
//
//// =================== Guide FSM (new signals) ===================
////guide_fsm #(
////  .CLK_HZ   (50_000_000),
////  .TICK_HZ  (20),
////  // Timings for S-curve & zebra (tune if needed)
////  .BACK_MS  (2000),
////.R1_MS(3000),   // was 400
////.L_MS (3900),  // was 900
////.R2_MS(3000),    // was 400
////  .ZEBRA_MS (3000)
////) u_fsm (
////  .clk                     (CLOCK_50),
////  .rst_n                   (rst_n),
////  .start_whistle           (start_rise),     // SW0 edge
////  .obstacle_stop           (obstacle_lvl),   // SW1 level
////  .zebra_pattern_stop      (zebra_lvl),      // SW2 level
////  .person_far_away_stop    (person_far_lvl), // SW3 level
////  .stop_command_clap       (clap_lvl),       // SW4 level
////  .IR_remote_emergency_stop(ir_emerg_lvl),   // KEY0 active-low => level high here
////  .tick_20hz               (tick_20hz),
////  .cmd_sel                 (cmd_sel)         // 3-bit command bus
////);
//
//guide_fsm #(
//  .CLK_HZ   (50_000_000),
//  .TICK_HZ  (20),
//  .BACK_MS  (2800), // 2000 before 
//  .R1_MS    (2400),
//  .L1_MS    (800),   // small left
//  .COAST_MS (1200),  // straight
//  .L2_MS    (5000),   // continue left
//  .R2_MS    (3400),
//  .ZEBRA_MS (3000)
//) u_fsm (
//  .clk                     (CLOCK_50),
//  .rst_n                   (rst_n),
//  .start_whistle           (whistle_detected),     // SW0 edge
//  .obstacle_stop           (stop_front_raw),   // SW1 level
//  .zebra_pattern_stop      (zebra_crossing_stop),      // SW2 level
//  .person_far_away_stop    (stop_back_raw), // SW3 level
//  .stop_command_clap       (clap_lvl),       // SW4 level
//  .IR_remote_emergency_stop(ir_emerg_lvl),   // KEY0 active-low => level high here
//  .tick_20hz               (tick_20hz),
//  .cmd_sel                 (cmd_sel)         // 3-bit command bus
//);
//
//
//
//// =================== JSON burst + UART (unchanged except 3-bit cmd_sel) ===================
//logic       tx_valid, tx_ready;
//logic [7:0] byte_to_send;
//
//json_burst #(.TICK_HZ(20)) u_burst (
//  .clk          (CLOCK_50),
//  .rst_n        (rst_n),
//  .tick_20hz    (tick_20hz),
//  .cmd_sel      (cmd_sel),        // 3 bits now: STOP, FWD, ARC_L, ARC_R, REV
//  .tx_valid     (tx_valid),
//  .tx_ready     (tx_ready),
//  .byte_to_send (byte_to_send)
//);
//
//uart_tx #(
//  .CLKS_PER_BIT(50_000_000/115200),
//  .BITS_N(8),
//  .PARITY_TYPE(0)
//) u_uart (
//  .clk      (CLOCK_50),
//  .rst      (1'b0),               // keep deasserted (as before)
//  .data_tx  (byte_to_send),
//  .valid    (tx_valid),
//  .ready    (tx_ready),
//  .uart_out (GPIO[31])
//);
//
//// =================== (Optional) LEDs ===================
//localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1, CMD_ARC_L=3'd2, CMD_ARC_R=3'd3, CMD_REV=3'd4;
//assign LEDR[6] = (cmd_sel == CMD_STOP);
//assign LEDR[7] = (cmd_sel == CMD_FWD);
//assign LEDR[8] = (cmd_sel == CMD_ARC_L) | (cmd_sel == CMD_ARC_R);
//assign LEDR[9] = (cmd_sel == CMD_REV);
//
//// Handshake/debug (as you had them)
//assign LEDR[4] = tx_valid;  // 1-clk pulses (invisible by eye)
//assign LEDR[5] = tx_ready;  // should dip during frames if observed on LA
//
//// Byte counter per burst (optional – helps you see 24/25/26/27)
//logic [7:0] sent_cnt;
//always_ff @(posedge CLOCK_50 or negedge rst_n) begin
//  if (!rst_n)          sent_cnt <= 8'd0;
//  else if (tick_20hz)  sent_cnt <= 8'd0;
//  else if (tx_valid)   sent_cnt <= sent_cnt + 8'd1;
//end
//assign LEDR[3:0] = sent_cnt[3:0];
//endmodule 
