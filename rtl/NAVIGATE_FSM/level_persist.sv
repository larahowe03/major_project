// Level persistence gate:
// - Input must stay HIGH for ASSERT_TICKS to assert.
// - Once asserted, it stays HIGH until input stays LOW for CLEAR_TICKS.
// Drive it with your 20 Hz tick so ASSERT_TICKS=40 ≈ 2 seconds.
module level_persist #(
  parameter int ASSERT_TICKS = 40,  // ~2.0s at 20 Hz
  parameter int CLEAR_TICKS  = 6    // ~0.3s at 20 Hz (tune)
)(
  input  logic clk,          // same domain as tick
  input  logic rst_n,
  input  logic tick_20hz,    // 20 Hz strobe
  input  logic in_level,     // raw level (e.g., distance<threshold)
  output logic out_level     // debounced/persisted output
);
  int unsigned hi_cnt, lo_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_level <= 1'b0;
      hi_cnt    <= 0;
      lo_cnt    <= 0;
    end else if (tick_20hz) begin
      if (!out_level) begin
        // Try to assert
        if (in_level) begin
          hi_cnt <= hi_cnt + 1;
          if (hi_cnt + 1 >= ASSERT_TICKS) begin
            out_level <= 1'b1;
            hi_cnt    <= 0;
            lo_cnt    <= 0;
          end
        end else begin
          hi_cnt <= 0;
        end
      end else begin
        // Currently asserted; try to clear
        if (!in_level) begin
          lo_cnt <= lo_cnt + 1;
          if (lo_cnt + 1 >= CLEAR_TICKS) begin
            out_level <= 1'b0;
            hi_cnt    <= 0;
            lo_cnt    <= 0;
          end
        end else begin
          lo_cnt <= 0;
        end
      end
    end
  end
endmodule
