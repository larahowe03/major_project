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
    S_ZEBRA,
    S_CROSS_ZEBRA
  } state_t;

  state_t current_state, next_state;

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
  assign hard_stop_any = (person_far_away_stop & ~in_maneuver);

  // ---------- Sequential: state, timers, latches ----------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= S_IDLE;
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
        current_state <= next_state;
        if (tick_20hz) begin
          // Reset on state exit, increment while in state and not done
          back_ctr  <= (s==S_BACK)   ? ((back_ctr  < BACK_T) ? back_ctr+1  : back_ctr)  : 0;
          r1_ctr    <= (s==S_ARC_R1) ? ((r1_ctr    < R1_T)   ? r1_ctr+1    : r1_ctr)    : 0;
          l1_ctr    <= (s==S_ARC_L1) ? ((l1_ctr    < L1_T)   ? l1_ctr+1    : l1_ctr)    : 0;
          coast_ctr <= (s==S_COAST)  ? ((coast_ctr < C_T)    ? coast_ctr+1 : coast_ctr) : 0;
          l2_ctr    <= (s==S_ARC_L2) ? ((l2_ctr    < L2_T)   ? l2_ctr+1    : l2_ctr)    : 0;
          r2_ctr    <= (s==S_ARC_R2) ? ((r2_ctr    < R2_T)   ? r2_ctr+1    : r2_ctr)    : 0;
          zebra_ctr <= (s==S_ZEBRA)  ? ((zebra_ctr < Z_T)    ? zebra_ctr+1 : zebra_ctr) : 0;
        end

      end
      // else: frozen by hard stop
    end
  end

  // ---------- Next-state ----------
  always_comb begin
    next_state = current_state;
    unique case (current_state)
      S_IDLE:   next_state = started ? S_FWD : S_IDLE;

      S_FWD: begin
        if (zebra_pattern_stop)              next_state = S_ZEBRA;
        else if (obstacle_rise && obst_rearm_ok) next_state = S_BACK;
        else                                   next_state = S_FWD;
      end

      S_BACK:    next_state = (back_ctr  >= BACK_T) ? S_ARC_R1 : S_BACK;
      S_ARC_R1:  next_state = (r1_ctr    >= R1_T  ) ? S_ARC_L1 : S_ARC_R1;
      S_ARC_L1:  next_state = (l1_ctr    >= L1_T  ) ? S_COAST  : S_ARC_L1;
      S_COAST:   next_state = (coast_ctr >= C_T   ) ? S_ARC_L2 : S_COAST;
      S_ARC_L2:  next_state = (l2_ctr    >= L2_T  ) ? S_ARC_R2 : S_ARC_L2;
      S_ARC_R2:  next_state = (r2_ctr    >= R2_T  ) ? S_FWD    : S_ARC_R2;
      S_ZEBRA:   next_state = (zebra_ctr >= Z_T   ) ? S_CROSS_ZEBRA    : S_ZEBRA;
      S_CROSS_ZEBRA:   next_state = (zebra_pattern_stop == '0  ) ? S_FWD    : S_CROSS_ZEBRA;
      default:   next_state = S_IDLE;
    endcase
  end

  // ---------- Outputs ----------
  always_comb begin
    if (!started) begin
      cmd_sel = CMD_STOP;
    end else if (hard_stop_any) begin
      cmd_sel = CMD_STOP;
    end else begin
      unique case (current_state)
        S_FWD    : cmd_sel = CMD_FWD;
        S_BACK   : cmd_sel = CMD_REV;
        S_ARC_R1 : cmd_sel = CMD_ARC_R;
        S_ARC_L1 : cmd_sel = CMD_ARC_L;
        S_COAST  : cmd_sel = CMD_FWD;
        S_ARC_L2 : cmd_sel = CMD_ARC_L;
        S_ARC_R2 : cmd_sel = CMD_ARC_R;
        S_ZEBRA  : cmd_sel = CMD_STOP;
        S_CROSS_ZEBRA  : cmd_sel = CMD_FWD;
        default  : cmd_sel = CMD_STOP;
      endcase
    end
  end
endmodule