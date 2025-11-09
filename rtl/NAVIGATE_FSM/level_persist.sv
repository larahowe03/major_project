module level_persist #(
  parameter int ASSERT_TICKS = 40,  
  parameter int CLEAR_TICKS  = 6    
)(
  input  logic clk,          
  input  logic rst_n,
  input  logic tick_20hz,    
  input  logic in_level,     // raw signal 
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
