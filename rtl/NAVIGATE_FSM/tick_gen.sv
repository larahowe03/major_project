module tick_gen #(parameter int CLK_HZ=50_000_000, parameter int TICK_HZ=20)(
  input  logic clk, rst_n,
  output logic tick
);
  localparam int N = CLK_HZ/TICK_HZ;
  logic [$clog2(N)-1:0] cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin cnt<=0; tick<=0; end
    else begin
      if (cnt==N-1) begin cnt<=0; tick<=1; end
      else begin cnt<=cnt+1; tick<=0; end
    end
  end
endmodule
