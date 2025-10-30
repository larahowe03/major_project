module deb_edge #(parameter int STABLE_CYCLES=250_000)( // ~5 ms @ 50 MHz
  input  logic clk, rst_n,
  input  logic raw_in,         // 1 = asserted (pass an inverted KEY here)
  output logic level,          // debounced level
  output logic rise            // 1-clk pulse on rising edge
);
  // 2FF sync
  logic s0,s1; always_ff @(posedge clk) begin s0<=raw_in; s1<=s0; end

  // debounce
  logic [$clog2(STABLE_CYCLES):0] cnt;
  logic deb;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin deb<=0; cnt<=0; end
    else if (s1==deb) begin cnt<=0; end
    else if (cnt==STABLE_CYCLES) begin deb<=s1; cnt<=0; end
    else cnt<=cnt+1;
  end

  // edge
  logic deb_d; always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) deb_d<=0; else deb_d<=deb;
  end

  assign level = deb;
  assign rise  = deb & ~deb_d;
endmodule
