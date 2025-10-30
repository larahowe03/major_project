module top_level (
  input  logic        CLOCK_50,
  input  logic [17:0] SW,
  inout  [35:0]       GPIO,
  output logic [17:0] LEDR
);
  // ---------------- Payload ----------------
  localparam int JSON_LEN = 24;
  logic [7:0] json_to_send [JSON_LEN] = '{
    8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,8'h30,
    8'h2E,8'h35,8'h2C,8'h22,8'h52,8'h22,8'h3A,8'h30,8'h2E,8'h35,8'h7D,8'h0A
  };

  // ---------------- Simple power-on reset (few cycles) ----------------
  logic [7:0] por_cnt = '0;
  logic       rst_n   = 1'b0;
  always_ff @(posedge CLOCK_50) begin
    if (&por_cnt) rst_n <= 1'b1; else por_cnt <= por_cnt + 1'b1;
  end
  logic rst; 
  assign rst = ~rst_n;

  // ---------------- UART TX ----------------
  logic       tx_valid;
  logic       tx_ready;     // asserted only in IDLE by your uart_tx
  logic [7:0] byte_to_send;

  uart_tx #(
    .CLKS_PER_BIT(50_000_000/115200),
    .BITS_N(8),
    .PARITY_TYPE(0)
  ) uart_tx_u (
    .clk      (CLOCK_50),
    .rst      (rst),
    .data_tx  (byte_to_send),
    .valid    (tx_valid),
    .ready    (tx_ready),
    .uart_out (GPIO[5])     // 3.3V TTL TX
  );

  // ---------------- Button edge detect (SW[0]) ----------------
  logic [17:0] sw_q;
  always_ff @(posedge CLOCK_50) sw_q <= SW;
  wire start_send = (~sw_q[0] & SW[0]);   // rising edge

  // ---------------- Byte streamer ----------------
  int   idx;          // index of the byte CURRENTLY being accepted
  logic sending;      // we're in the middle of a burst

  // Accept = the TX just latched data_tx at this clock edge
  wire accept = tx_valid && tx_ready;

  always_ff @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
      tx_valid     <= 1'b0;
      byte_to_send <= 8'h00;
      idx          <= 0;
      sending      <= 1'b0;
      LEDR         <= '0;
    end else begin
      // Start a burst on button rising edge (only if idle/not already sending)
      if (start_send && !sending) begin
        sending      <= 1'b1;
        tx_valid     <= 1'b1;

        idx          <= 0;
        byte_to_send <= json_to_send[0];   // preload first byte BEFORE first accept

        LEDR[0]      <= ~LEDR[0];          // debug blink on start
      end

      // Stream bytes: on each accept, move to the next
      if (sending && accept) begin
        if (idx == JSON_LEN-1) begin
          // last byte was just accepted; stop
          tx_valid <= 1'b0;
          sending  <= 1'b0;
          // (byte_to_send can keep its last value; TX is done with it)
          LEDR[1]  <= ~LEDR[1];            // debug blink on end
        end else begin
          idx          <= idx + 1;
          byte_to_send <= json_to_send[idx + 1]; // safe to update now (TX already latched current)
          LEDR[2]      <= ~LEDR[2];              // debug blink per byte
        end
      end
    end
  end

  // Unused LEDs low except debug bits toggled above
  // (If you don’t want LED blinks, remove the LEDR logic entirely.)

endmodule

