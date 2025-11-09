`timescale 1ns/1ps

module tb_guide_fsm;

  // --------------------------------------------------------------------------
  // DUT inputs / outputs
  // --------------------------------------------------------------------------
  reg        clk;
  reg        rst_n;

  reg        start_whistle;
  reg        obstacle_stop;
  reg        zebra_pattern_stop;
  reg        person_far_away_stop;

  reg        tick_20hz;

  wire [2:0] cmd_sel;

  // --------------------------------------------------------------------------
  // Instantiate DUT
  // --------------------------------------------------------------------------
  guide_fsm #(
    .CLK_HZ    (50_000_000),
    .TICK_HZ   (20),
    .BACK_MS   (1200),
    .R1_MS     (400),
    .L1_MS     (300),
    .COAST_MS  (800),
    .L2_MS     (800),
    .R2_MS     (400),
    .ZEBRA_MS  (3000)
  ) dut (
    .clk                  (clk),
    .rst_n                (rst_n),
    .start_whistle        (start_whistle),
    .obstacle_stop        (obstacle_stop),
    .zebra_pattern_stop   (zebra_pattern_stop),
    .person_far_away_stop (person_far_away_stop),
    .tick_20hz            (tick_20hz),
    .cmd_sel              (cmd_sel)
  );

  // --------------------------------------------------------------------------
  // 50 MHz clock (20 ns period)
  // --------------------------------------------------------------------------
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // --------------------------------------------------------------------------
  // Fake "20 Hz" tick
  // --------------------------------------------------------------------------
  initial begin
    tick_20hz = 1'b0;
    forever begin
      #500  tick_20hz = 1'b1;   // short tick
      #20   tick_20hz = 1'b0;
    end
  end

  // --------------------------------------------------------------------------
  // Stimulus sequence
  // --------------------------------------------------------------------------
  initial begin
    // Initial values
    rst_n               = 1'b0;
    start_whistle       = 1'b0;
    obstacle_stop       = 1'b0;
    zebra_pattern_stop  = 1'b0;
    person_far_away_stop= 1'b0;

    // Hold reset for a while -> FSM in S_IDLE
    #500;
    rst_n = 1'b1;

    // Stay in IDLE for a bit with *no* inputs active
    #2000;

    // --------------------------------------------------------------
    // 1) FIRST EVENT: start_whistle pulse -> IDLE -> FWD
    // --------------------------------------------------------------
    start_whistle = 1'b1;
    #40;                    // short pulse
    start_whistle = 1'b0;

    // Let it run forward
    #8000;

    // --------------------------------------------------------------
    // 2) Obstacle: assert obstacle_stop to start manoeuvre
    // --------------------------------------------------------------
    obstacle_stop = 1'b1;
    #20000;                 // long enough to run through manoeuvre
    obstacle_stop = 1'b0;

    // Back in FORWARD
    #8000;

    // --------------------------------------------------------------
    // 3) Zebra crossing: assert zebra_pattern_stop long enough
    //    ZEBRA_MS = 3000 ms @20 Hz => 60 ticks.
    // --------------------------------------------------------------
    zebra_pattern_stop = 1'b1;
    #40000;                 // covers >60 fake ticks
    zebra_pattern_stop = 1'b0;

    // Let it move out of S_ZEBRA/S_CROSS_ZEBRA
    #20000;

    // --------------------------------------------------------------
    // 4) Person far away: force STOP, then release
    // --------------------------------------------------------------
    person_far_away_stop = 1'b1;
    #8000;
    person_far_away_stop = 1'b0;

    #8000;
    $finish;
  end


endmodule