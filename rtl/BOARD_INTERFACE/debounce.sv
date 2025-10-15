module debounce #(
  parameter DELAY_COUNTS = 2500 // 50us with clk period 20ns totals in 50*10^-6/20*10-9 counts
) (
    input clk, button,
    output reg button_pressed
);

  // Use a synchronizer to synchronize `button`.
  wire button_sync; // Output of the synchronizer. Input to your debounce logic.
  synchroniser button_synchroniser (.clk(clk), .x(button), .y(button_sync));  

  reg prev_button;
  reg [$clog2(DELAY_COUNTS) - 1:0] count;

  always @(posedge clk) begin
      if (button_sync != prev_button) begin
        count <= 0;
      end
      else if (count == DELAY_COUNTS) begin
        count <= count;
      end
      else begin
        count <= count + 1;
      end
  end

  // Set the prev_button flip-flop:
  always @(posedge clk) begin
    if (button_sync != prev_button) begin
      prev_button <= button_sync;
    end
    else begin
      prev_button <= prev_button;
    end
  end

  // reg button_pressed;
  // Set the button_pressed flip-flop:
  always @(posedge clk) begin
    if (button_sync == prev_button && count == DELAY_COUNTS) begin
      button_pressed <= prev_button;
    end
    else begin
      button_pressed <= button_pressed;
    end
  end

endmodule

