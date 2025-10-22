// timer used to measure distance at 250ms intervals - not used in top level
module refresher250ms(
  input clk,
  input en,
  output measure);
  reg [24:0] counter;

  assign measure = (counter == 25'd1);

  always@(posedge clk)
    begin
      if(~en | (counter == 25'd12_500_000))
        counter <= 25'd0;
      else
        counter <= 25'd1 + counter;
    end
endmodule