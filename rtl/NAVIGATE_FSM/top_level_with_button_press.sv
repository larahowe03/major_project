module top_level_with_button_press (
  input  logic        CLOCK_50,
  input  logic [17:0] SW,
  inout  [35:0]       GPIO,
  output logic [17:0] LEDR
);

  // ---------------- Power-on reset ----------------
  logic [7:0] por_cnt = '0;
  logic       rst_n   = 1'b0;
  always_ff @(posedge CLOCK_50) begin
    if (&por_cnt) rst_n <= 1'b1; else por_cnt <= por_cnt + 1'b1;
  end
  logic rst; 
  assign rst = ~rst_n;

  // ---------------- UART TX ----------------
  logic       tx_valid;
  logic       tx_ready;     // asserted by uart_tx in IDLE
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

  // ---------------- Buttons: edge detect ----------------
  logic [17:0] sw_q;
  always_ff @(posedge CLOCK_50) sw_q <= SW;

  wire btn_send   = (~sw_q[0] & SW[0]); // rising edges
  wire btn_spdup  = (~sw_q[1] & SW[1]);
  wire btn_spddn  = (~sw_q[2] & SW[2]);
  wire btn_left   = (~sw_q[3] & SW[3]);
  wire btn_right  = (~sw_q[4] & SW[4]);
  wire btn_stra   = (~sw_q[5] & SW[5]);

  // ---------------- Drive-state: speed + turn mode ----------------
  typedef enum logic [1:0] {STRAIGHT=2'd0, LEFT=2'd1, RIGHT=2'd2} turn_t;
  turn_t turn_mode;

  // speed_idx in [0..4] mapping to {"0.00","0.25","0.50","0.75","1.00"}
  logic [2:0] speed_idx;

  // ---------------- JSON buffer ----------------
  // Max length kept generous for clarity; actual length in json_len.
  localparam int MAX_JSON = 40;
  logic [7:0] json_buf [MAX_JSON];
  int         json_len;

  // Pre-baked ASCII strings for speeds (you can add more as needed)
  // WARNING: keep all strings same width for simplicity here.
  localparam int SPEED_STR_LEN = 4; // "0.00","0.25",...
  logic [8*SPEED_STR_LEN-1:0] speed_str_lut [5];
  initial begin
    speed_str_lut[0] = {"0",".","0","0"};
    speed_str_lut[1] = {"0",".","2","5"};
    speed_str_lut[2] = {"0",".","5","0"};
    speed_str_lut[3] = {"0",".","7","5"};
    speed_str_lut[4] = {"1",".","0","0"};
  end

  // helper to copy a byte into json_buf
  task automatic put_byte(input byte b, inout int k);
    begin json_buf[k] = b; k = k + 1; end
  endtask

  // helper to copy a 4-char speed string into json_buf
  task automatic put_speed4(input logic [8*SPEED_STR_LEN-1:0] s, inout int k);
    begin
      put_byte(s[8*4-1:8*3], k); // s[31:24]
      put_byte(s[8*3-1:8*2], k); // s[23:16]
      put_byte(s[8*2-1:8*1], k); // s[15:8]
      put_byte(s[8*1-1:8*0], k); // s[7:0]
    end
  endtask

  // Build JSON: {"T":1,"L":<speed>,"R":<speed>}\n
  // T is fixed to 1 here; adjust if your API uses T for fwd/back.
  task automatic build_json(input turn_t tm, input [2:0] spd, output int out_len);
    int k;
    logic [2:0] l_idx, r_idx;

    // pick left/right indices per turn mode
    unique case (tm)
      STRAIGHT: begin l_idx = spd;                   r_idx = spd;                   end
      LEFT:     begin l_idx = (spd==0)? 0 : spd-1;   r_idx = spd;                   end
      RIGHT:    begin l_idx = spd;                   r_idx = (spd==0)? 0 : spd-1;   end
      default:  begin l_idx = spd;                   r_idx = spd;                   end
    endcase

    k = 0;
    put_byte(8'h7B, k);                // {
    put_byte(8'h22, k); put_byte("T", k); put_byte(8'h22, k); put_byte(8'h3A, k); // "T":
    put_byte("1", k);                  // T = 1 (forward)
    put_byte(8'h2C, k);                // ,
    put_byte(8'h22, k); put_byte("L", k); put_byte(8'h22, k); put_byte(8'h3A, k); // "L":
    put_speed4(speed_str_lut[l_idx], k);
    put_byte(8'h2C, k);                // ,
    put_byte(8'h22, k); put_byte("R", k); put_byte(8'h22, k); put_byte(8'h3A, k); // "R":
    put_speed4(speed_str_lut[r_idx], k);
    put_byte(8'h7D, k);                // }
    put_byte(8'h0A, k);                // \n
    out_len = k;
  endtask

  // ---------------- Streamer (same pattern you had) ----------------
  int   idx;
  logic sending;
  wire  accept = tx_valid && tx_ready;

  always_ff @(posedge CLOCK_50 or posedge rst) begin
    if (rst) begin
      tx_valid   <= 1'b0;
      sending    <= 1'b0;
      idx        <= 0;
      speed_idx  <= 3'd2;   // start at 0.50
      turn_mode  <= STRAIGHT;
      byte_to_send <= 8'h00;
      LEDR       <= '0;
    end else begin
      // ---- Control buttons update the drive state ----
      if (btn_spdup)  speed_idx <= (speed_idx==3'd4) ? 3'd4 : speed_idx + 1;
      if (btn_spddn)  speed_idx <= (speed_idx==3'd0) ? 3'd0 : speed_idx - 1;
      if (btn_left)   turn_mode <= LEFT;
      if (btn_right)  turn_mode <= RIGHT;
      if (btn_stra)   turn_mode <= STRAIGHT;

      // ---- Build & send on SW[0] rising edge ----
      if (btn_send && !sending) begin
        build_json(turn_mode, speed_idx, json_len);
        sending      <= 1'b1;
        tx_valid     <= 1'b1;
        idx          <= 0;
        byte_to_send <= json_buf[0];
        LEDR[0]      <= ~LEDR[0];
      end

      // ---- Advance one byte per handshake ----
      if (sending && accept) begin
        if (idx == json_len-1) begin
          tx_valid <= 1'b0;
          sending  <= 1'b0;
          LEDR[1]  <= ~LEDR[1];
        end else begin
          idx          <= idx + 1;
          byte_to_send <= json_buf[idx + 1];
          LEDR[2]      <= ~LEDR[2];
        end
      end
    end
  end

endmodule
