`timescale 1ns/1ps

module tb_json_burst;

  // Clock & reset
  reg clk;
  reg rst_n;

  // DUT interface
  reg        tick_20hz;
  reg  [2:0] cmd_sel;
  reg        tx_ready;
  wire       tx_valid;
  wire [7:0] byte_to_send;

  // For readability in the testbench
  localparam [2:0] CMD_STOP  = 3'd0;
  localparam [2:0] CMD_FWD   = 3'd1;
  localparam [2:0] CMD_ARC_L = 3'd2;
  localparam [2:0] CMD_ARC_R = 3'd3;
  localparam [2:0] CMD_REV   = 3'd4;

  // ------------------------------------------------------------------
  // Instantiate DUT
  // ------------------------------------------------------------------
  json_burst #(
    .TICK_HZ(20)   
  ) dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .tick_20hz    (tick_20hz),
    .cmd_sel      (cmd_sel),
    .tx_valid     (tx_valid),
    .tx_ready     (tx_ready),
    .byte_to_send (byte_to_send)
  );

  // ------------------------------------------------------------------
  // 50 MHz clock (20 ns period)
  // ------------------------------------------------------------------
  initial clk = 1'b0;
  always #10 clk = ~clk;  // 20 ns period

  // ------------------------------------------------------------------
  // Simple task to kick off one burst for a given command
  // ------------------------------------------------------------------
  task send_command(input [2:0] sel);
    begin
      cmd_sel   = sel;

      // generate a single tick_20hz pulse (one clock cycle high)
      @(posedge clk);
      tick_20hz = 1'b1;
      @(posedge clk);
      tick_20hz = 1'b0;

      repeat (80) @(posedge clk);
    end
  endtask


  // ------------------------------------------------------------------
  // Stimulus
  // ------------------------------------------------------------------
  initial begin
    // VCD dump (for GTKWave, etc.)
    $dumpfile("tb_json_burst.vcd");
    $dumpvars(0, tb_json_burst);

    // Initial values
    rst_n     = 1'b0;
    tick_20hz = 1'b0;
    cmd_sel   = CMD_STOP;
    tx_ready  = 1'b1;   // always ready in this test

    // Reset for a few cycles
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    // Give DUT some cycles after reset
    repeat (10) @(posedge clk);

    $display("\n--- Sending STOP ---");
    send_command(CMD_STOP);


    $display("\nSimulation finished.");
    $finish;
  end

endmodule
