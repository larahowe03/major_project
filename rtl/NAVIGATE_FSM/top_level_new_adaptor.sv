module top_level_new_adaptor (
      input  CLOCK_50,
      input  [9:0] SW,
      inout  [35:0] GPIO, // The DE2-115 has a header with 36 general purpose input/output pins!
      output [9:0] LEDR
);

      localparam JSON_LEN = 24;
 
      logic tx_valid = 1'b0;  // handshake
      logic tx_ready;         // handshake
 
      logic rx_valid;         // handshake
      logic rx_ready = 1'b1;  // handshake. We are always ready to receive.
      
      logic [7:0] rx_byte;
      
   // Store the JSON string for the forward command:
      logic [7:0]  json_to_send [JSON_LEN] = '{8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,8'h30,8'h2E,8'h35,8'h2C,8'h22,8'h52,8'h22,8'h3A,8'h30,8'h2E,8'h30,8'h7D,8'h0A};
      logic [7:0]  byte_to_send = 0;
      integer char_index = 0;

      uart_tx #(.CLKS_PER_BIT(50_000_000/115200),.BITS_N(8),.PARITY_TYPE(0)) uart_tx_u (.clk(CLOCK_50), .rst(1'b0), .data_tx(byte_to_send),.valid(tx_valid),.uart_out(GPIO[31]),.ready(tx_ready));

      logic [9:0] SW_prev = '0;

      always_ff @(posedge CLOCK_50) begin
            SW_prev <= SW;
            if (!tx_valid && !SW_prev[0] && SW[0])
            begin
                  tx_valid <= 1'b1;
                  byte_to_send <= json_to_send[0];
                  char_index <= 1;
            end
            if (tx_valid && tx_ready) // Handshake
            begin
                  if(char_index >= JSON_LEN) begin
                        tx_valid <= 1'b0;
                  end
                  byte_to_send <= json_to_send[char_index];
                  char_index <= char_index + 1;
            end
      end
      
endmodule
