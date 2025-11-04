// Drives cmd_sel based on high-level stop/command signals from your sensor modules.
module guide_fsm #(
  parameter int CLK_HZ    = 50_000_000,
  parameter int TICK_HZ   = 20,

  // ----- obstacle maneuver timing (tune freely) -----
  parameter int BACK_MS   = 1200,  // reverse
  parameter int R1_MS     = 400,   // first RIGHT arc
  parameter int L1_MS     = 300,   // small LEFT arc
  parameter int COAST_MS  = 800,   // straight segment
  parameter int L2_MS     = 800,   // continue LEFT arc
  parameter int R2_MS     = 400,   // final RIGHT arc to straighten

  // ----- zebra stop -----
  parameter int ZEBRA_MS  = 3000
)(
  input  logic clk, rst_n,

  // sensor/command inputs
  input  logic start_whistle,
  input  logic obstacle_stop,
  input  logic zebra_pattern_stop,
  input  logic person_far_away_stop,
  input  logic stop_command_clap,
  input  logic IR_remote_emergency_stop,

  input  logic tick_20hz,

  output logic [2:0] cmd_sel           // 000 STOP, 001 FWD, 010 ARC_L, 011 ARC_R, 100 REV
);

  // Command encodings
  localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1, CMD_ARC_L=3'd2, CMD_ARC_R=3'd3, CMD_REV=3'd4;

  // Convert ms→ticks
  localparam int BACK_T = (BACK_MS   * TICK_HZ) / 1000;
  localparam int R1_T   = (R1_MS     * TICK_HZ) / 1000;
  localparam int L1_T   = (L1_MS     * TICK_HZ) / 1000;
  localparam int C_T    = (COAST_MS  * TICK_HZ) / 1000;
  localparam int L2_T   = (L2_MS     * TICK_HZ) / 1000;
  localparam int R2_T   = (R2_MS     * TICK_HZ) / 1000;
  localparam int Z_T    = (ZEBRA_MS  * TICK_HZ) / 1000;

  // States
  typedef enum logic [3:0] {
    S_IDLE,
    S_FWD,
    S_BACK,
    S_ARC_R1,
    S_ARC_L1,
    S_COAST,
    S_ARC_L2,
    S_ARC_R2,
    S_ZEBRA
  } state_t;

  state_t s, ns;

  // Edge detect for obstacle_stop
  logic obstacle_stop_d, obstacle_rise;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) obstacle_stop_d <= 1'b0;
    else        obstacle_stop_d <= obstacle_stop;
  end
  assign obstacle_rise = obstacle_stop & ~obstacle_stop_d;

  // Started latch + re-arm
  logic started, obst_rearm_ok;

  // Timers
  int unsigned back_ctr, r1_ctr, l1_ctr, coast_ctr, l2_ctr, r2_ctr, zebra_ctr;

  // Are we inside the maneuver?
  logic in_maneuver;
  always_comb begin
    in_maneuver = (s==S_BACK) || (s==S_ARC_R1) || (s==S_ARC_L1) ||
                  (s==S_COAST) || (s==S_ARC_L2) || (s==S_ARC_R2);
  end

  // Hard-stop mask: ignore person_far_away_stop while maneuvering
  logic hard_stop_any;
  assign hard_stop_any =
      IR_remote_emergency_stop
    | stop_command_clap
    | (person_far_away_stop & ~in_maneuver);

  // ---------- Sequential: state, timers, latches ----------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s <= S_IDLE;
      started <= 1'b0;
      obst_rearm_ok <= 1'b1;
      back_ctr <= 0; r1_ctr <= 0; l1_ctr <= 0; coast_ctr <= 0; l2_ctr <= 0; r2_ctr <= 0; zebra_ctr <= 0;
    end else begin
      if (start_whistle) started <= 1'b1;

      // re-arm blocks retrigger during ANY maneuver state
      if (in_maneuver)
        obst_rearm_ok <= 1'b0;
      else if (!obstacle_stop)
        obst_rearm_ok <= 1'b1;

      if (!hard_stop_any) begin
        s <= ns;
        if (tick_20hz) begin
          back_ctr  <= (s==S_BACK   && back_ctr  < BACK_T) ? back_ctr+1  : (s!=S_BACK   ? 0 : back_ctr);
          r1_ctr    <= (s==S_ARC_R1 && r1_ctr    < R1_T  ) ? r1_ctr+1    : (s!=S_ARC_R1 ? 0 : r1_ctr);
          l1_ctr    <= (s==S_ARC_L1 && l1_ctr    < L1_T  ) ? l1_ctr+1    : (s!=S_ARC_L1 ? 0 : l1_ctr);
          coast_ctr <= (s==S_COAST  && coast_ctr < C_T   ) ? coast_ctr+1 : (s!=S_COAST  ? 0 : coast_ctr);
          l2_ctr    <= (s==S_ARC_L2 && l2_ctr    < L2_T  ) ? l2_ctr+1    : (s!=S_ARC_L2 ? 0 : l2_ctr);
          r2_ctr    <= (s==S_ARC_R2 && r2_ctr    < R2_T  ) ? r2_ctr+1    : (s!=S_ARC_R2 ? 0 : r2_ctr);
          zebra_ctr <= (s==S_ZEBRA  && zebra_ctr < Z_T   ) ? zebra_ctr+1 : (s!=S_ZEBRA  ? 0 : zebra_ctr);
        end
      end
      // else: frozen by hard stop
    end
  end

  // ---------- Next-state ----------
  always_comb begin
    ns = s;
    unique case (s)
      S_IDLE:   ns = started ? S_FWD : S_IDLE;

      S_FWD: begin
        if (zebra_pattern_stop)              ns = S_ZEBRA;
        else if (obstacle_rise && obst_rearm_ok) ns = S_BACK;
        else                                   ns = S_FWD;
      end

      S_BACK:    ns = (back_ctr  >= BACK_T) ? S_ARC_R1 : S_BACK;
      S_ARC_R1:  ns = (r1_ctr    >= R1_T  ) ? S_ARC_L1 : S_ARC_R1;
      S_ARC_L1:  ns = (l1_ctr    >= L1_T  ) ? S_COAST  : S_ARC_L1;
      S_COAST:   ns = (coast_ctr >= C_T   ) ? S_ARC_L2 : S_COAST;
      S_ARC_L2:  ns = (l2_ctr    >= L2_T  ) ? S_ARC_R2 : S_ARC_L2;
      S_ARC_R2:  ns = (r2_ctr    >= R2_T  ) ? S_FWD    : S_ARC_R2;

      S_ZEBRA:   ns = (zebra_ctr >= Z_T   ) ? S_FWD    : S_ZEBRA;

      default:   ns = S_IDLE;
    endcase
  end

  // ---------- Outputs ----------
  always_comb begin
    if (!started) begin
      cmd_sel = CMD_STOP;
    end else if (hard_stop_any) begin
      cmd_sel = CMD_STOP;
    end else begin
      unique case (s)
        S_FWD    : cmd_sel = CMD_FWD;
        S_BACK   : cmd_sel = CMD_REV;
        S_ARC_R1 : cmd_sel = CMD_ARC_R;
        S_ARC_L1 : cmd_sel = CMD_ARC_L;
        S_COAST  : cmd_sel = CMD_FWD;
        S_ARC_L2 : cmd_sel = CMD_ARC_L;
        S_ARC_R2 : cmd_sel = CMD_ARC_R;
        S_ZEBRA  : cmd_sel = CMD_STOP;
        default  : cmd_sel = CMD_STOP;
      endcase
    end
  end
endmodule



//// Drives cmd_sel based on high-level stop/command signals from your sensor modules.
//module guide_fsm #(
//  parameter int CLK_HZ    = 50_000_000,
//  parameter int TICK_HZ   = 20,
////  // obstacle movement time durations 
////  parameter int BACK_MS   = 1200,   // reverse duration
////  parameter int R1_MS     = 400,   // first right arc  
////  parameter int L_MS      = 1000,   // left arc
////  parameter int COAST_MS  = 1500,   // <-- NEW: straight forward gap (1–2 s typical)
////  parameter int R2_MS     = 400,   // second right arc
//
//  // ----- obstacle maneuver timing (tune freely) -----
//  parameter int BACK_MS   = 1200,  // reverse
//  parameter int R1_MS     = 400,   // first RIGHT arc
//  parameter int L1_MS     = 300,   // small LEFT arc
//  parameter int COAST_MS  = 800,   // straight segment
//  parameter int L2_MS     = 800,   // continue LEFT arc
//  parameter int R2_MS     = 400,   // final RIGHT arc to straighten
//
//  // zebra crossing time durations 
//  parameter int ZEBRA_MS  = 3000   // stop time at zebra
//)(
//  input  logic clk, rst_n,
//
//  // stops from  modules
//  input  logic start_whistle,           // level; start to move forward (once)
//  input  logic obstacle_stop,           // level: curve around obstacle 
//  input  logic zebra_pattern_stop,      // level: temporarily STOP for ZEBRA_MS time duration 
//  input  logic person_far_away_stop,    // level: hold STOP 
//  input  logic stop_command_clap,       // level: hold STOP 
//  input  logic IR_remote_emergency_stop,// level: hold STOP 
//
//  input  logic tick_20hz,               // 20 Hz timer tick
//
//  output logic [2:0] cmd_sel            // 000 STOP, 001 FWD, 010 ARC_L, 011 ARC_R, 100 REV
//);
//
//  // Encodings
//  localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1, CMD_ARC_L=3'd2, CMD_ARC_R=3'd3, CMD_REV=3'd4;
//
//  // Timers in ticks
//  localparam int BACK_T = (BACK_MS  * TICK_HZ) / 1000;
//  localparam int R1_T   = (R1_MS    * TICK_HZ) / 1000;
//  localparam int C_T    = (COAST_MS * TICK_HZ) / 1000; // <-- NEW
//  localparam int L_T    = (L_MS     * TICK_HZ) / 1000;
//  localparam int R2_T   = (R2_MS    * TICK_HZ) / 1000;
//  localparam int Z_T    = (ZEBRA_MS * TICK_HZ) / 1000;
//
//  // States (only for timed sequences)
//  typedef enum logic [3:0] {
//    S_IDLE,            // not started yet
//    S_FWD,             // cruising forward
//    S_BACK,            // reverse
//    S_ARC_R1,          // first right arc
//	 S_COAST,            // <-- NEW straight segment
//    S_ARC_L,           // left arc
//    S_ARC_R2,          // second right arc
//    S_ZEBRA            // timed stop at crossing
//  } state_t;
//
//  state_t s, ns;
//
//  // Edge detect & re-arm for obstacle_stop
//  // Basically, we don't want to check obstacle_stop until we finished the obstacle movement first
//  logic obstacle_stop_d, obstacle_rise;
//  always_ff @(posedge clk or negedge rst_n) begin
//    if (!rst_n) obstacle_stop_d <= 1'b0;
//    else        obstacle_stop_d <= obstacle_stop;
//  end
//  assign obstacle_rise = obstacle_stop & ~obstacle_stop_d;
//
//  // After finishing the S-curve, require obstacle_stop to drop before we accept another
//  logic obst_rearm_ok;  // goes 0 when we start a maneuver, returns to 1 only when obstacle_stop==0
//  // Start/armed flag
//  logic started;
//
//  // Timers
//  int unsigned back_ctr, r1_ctr, coast_ctr, l_ctr, r2_ctr, zebra_ctr;
//  
//  // Are we currently executing the obstacle maneuver?
//logic in_maneuver;
//  always_comb begin
//    in_maneuver = (s==S_BACK) || (s==S_ARC_R1) || (s==S_COAST) || (s==S_ARC_L) || (s==S_ARC_R2);
//  end
//  
//  
//// Hold/pause the maneuver if any higher-priority STOP is asserted
//// Mask person_far_away_stop ONLY while maneuvering
//logic hard_stop_any;
//assign hard_stop_any =
//    IR_remote_emergency_stop
//  | stop_command_clap
//  | (person_far_away_stop & ~in_maneuver);
//  
//  
//
//  // Go back to S_IDLE if reset 
//  always_ff @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//      s <= S_IDLE;
//      started <= 1'b0;
//      obst_rearm_ok <= 1'b1;
//      back_ctr <= 0; r1_ctr <= 0;  coast_ctr <= 0; l_ctr <= 0; r2_ctr <= 0; zebra_ctr <= 0;
//    end else begin
//      // start latch
//      if (start_whistle) started <= 1'b1;
//
//      // re-arm logic for obstacles
//      if (s==S_BACK || s==S_ARC_R1 || s==S_COAST || s==S_ARC_L || s==S_ARC_R2)
//        obst_rearm_ok <= 1'b0;                     // in maneuver, block retrigger
//      else if (!obstacle_stop)
//        obst_rearm_ok <= 1'b1;                     // re-arm only when input released
//
//      // advance state only if not hard-stopped; if hard-stopped, freeze state & timers
//      if (!hard_stop_any) begin
//        s <= ns;
//        if (tick_20hz) begin
//          back_ctr  <= (s==S_BACK   && back_ctr  < BACK_T) ? back_ctr+1  : (s!=S_BACK   ? 0 : back_ctr);
//          r1_ctr    <= (s==S_ARC_R1 && r1_ctr    < R1_T  ) ? r1_ctr+1    : (s!=S_ARC_R1 ? 0 : r1_ctr);
//			 coast_ctr <= (s==S_COAST  && coast_ctr < C_T   ) ? coast_ctr+1 : (s!=S_COAST  ? 0 : coast_ctr); // NEW
//          l_ctr     <= (s==S_ARC_L  && l_ctr     < L_T   ) ? l_ctr+1     : (s!=S_ARC_L  ? 0 : l_ctr);
//          r2_ctr    <= (s==S_ARC_R2 && r2_ctr    < R2_T  ) ? r2_ctr+1    : (s!=S_ARC_R2 ? 0 : r2_ctr);
//          zebra_ctr <= (s==S_ZEBRA  && zebra_ctr < Z_T   ) ? zebra_ctr+1 : (s!=S_ZEBRA  ? 0 : zebra_ctr);
//        end
//      end
//      // else: paused by hard stop; stay in current state and keep counters as-is
//    end
//  end
//
//  // Next-state (maneuvers + zebra). Start and obstacle trigger only when not hard-stopped.
//  always_comb begin
//    ns = s;
//    unique case (s)
//      S_IDLE: begin
//        if (started) ns = S_FWD;
//      end
//
//      S_FWD: begin
//        if (zebra_pattern_stop)             ns = S_ZEBRA;                 // timed stop
//        else if (obstacle_rise && obst_rearm_ok) ns = S_BACK;             // start S-curve once
//        else                                  ns = S_FWD;
//      end
//
//      S_BACK:    ns = (back_ctr  >= BACK_T) ? S_ARC_R1 : S_BACK;
//      
//		S_ARC_R1 : ns = (r1_ctr    >= R1_T  ) ? S_ARC_L  : S_ARC_R1;   
//     
//      S_ARC_L:   ns = (l_ctr     >= L_T   ) ? S_COAST  : S_ARC_L;
//		S_COAST  : ns = (coast_ctr >= C_T   ) ? S_ARC_R2  : S_COAST;    // NEW
//      S_ARC_R2:  ns = (r2_ctr    >= R2_T  ) ? S_FWD    : S_ARC_R2;
//
//      S_ZEBRA:   ns = (zebra_ctr >= Z_T   ) ? S_FWD    : S_ZEBRA;
//
//      default:   ns = S_IDLE;
//    endcase
//  end
//
//  // Output command with priorities:
//  // 1) Emergency/person/clap => STOP immediately (override anything)
//  // 2) Otherwise drive by state
//  always_comb begin
//    if (!started) begin
//      cmd_sel = CMD_STOP;
//    end else if (hard_stop_any) begin
//      cmd_sel = CMD_STOP;
//    end else begin
//      unique case (s)
//        S_FWD   : cmd_sel = CMD_FWD;
//        S_BACK  : cmd_sel = CMD_REV;
//        S_ARC_R1: cmd_sel = CMD_ARC_R;
//		  S_COAST  : cmd_sel = CMD_FWD;    // <-- NEW
//        S_ARC_L : cmd_sel = CMD_ARC_L;
//        S_ARC_R2: cmd_sel = CMD_ARC_R;
//        S_ZEBRA : cmd_sel = CMD_STOP;
//        default : cmd_sel = CMD_STOP; // S_IDLE and others
//      endcase
//    end
//  end
//endmodule

