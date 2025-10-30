// Builds a pre-defined JSON string command (based on the selected commmand), and feeds it to the UART byte by byte
// cmd_sel: 000 STOP, 001 FWD, 010 ARC_L, 011 ARC_R, 100 REV

module json_burst #(
  parameter int TICK_HZ = 20
)(
  input  logic        clk, rst_n,
  input  logic        tick_20hz,
  input  logic [2:0]  cmd_sel,        // <-- widened to 3 bits
  output logic        tx_valid,
  input  logic        tx_ready,
  output logic [7:0]  byte_to_send
);
  // Encodings
  localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1,
                         CMD_ARC_L=3'd2, CMD_ARC_R=3'd3,
                         CMD_REV =3'd4;

  // ----- Messages (half speeds) -----
// STOP: {"T":1,"L":0.0,"R":0.0}\n  (24)
localparam int LEN_STOP = 24;
localparam logic [7:0] MSG_STOP [0:LEN_STOP-1] = '{
  8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,
  8'h2C,8'h22,8'h52,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,
  8'h7D,8'h0A
};

// FWD: {"T":1,"L":0.05,"R":0.05}\n  (26)
localparam int LEN_FWD = 26;
localparam logic [7:0] MSG_FWD [0:LEN_FWD-1] = '{
  8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h35,             // "0.05"
  8'h2C,8'h22,8'h52,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h35,             // "0.05"
  8'h7D,8'h0A
};

// ARC_LEFT: {"T":1,"L":0.01,"R":0.08}\n  (26)
localparam int LEN_ARC_L = 26;
localparam logic [7:0] MSG_ARC_L [0:LEN_ARC_L-1] = '{
  8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h31,       // "0.01"
  8'h2C,8'h22,8'h52,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h38,       // "0.08"
  8'h7D,8'h0A
};

// ARC_RIGHT: {"T":1,"L":0.08,"R":0.01}\n  (26)
localparam int LEN_ARC_R = 26;
localparam logic [7:0] MSG_ARC_R [0:LEN_ARC_R-1] = '{
  8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h38,       // "0.08"
  8'h2C,8'h22,8'h52,8'h22,8'h3A,
  8'h30,8'h2E,8'h30,8'h31,       // "0.01"
  8'h7D,8'h0A
};


// REV: {"T":1,"L":-0.02,"R":-0.02}\n  (28)
localparam int LEN_REV = 28;
localparam logic [7:0] MSG_REV [0:LEN_REV-1] = '{
  8'h7B,8'h22,8'h54,8'h22,8'h3A,8'h31,8'h2C,8'h22,8'h4C,8'h22,8'h3A,
  8'h2D,8'h30,8'h2E,8'h30,8'h32,       // "-0.02"
  8'h2C,8'h22,8'h52,8'h22,8'h3A,
  8'h2D,8'h30,8'h2E,8'h30,8'h32,       // "-0.02"
  8'h7D,8'h0A
};


  // Pick message
  logic [7:0] idx, cur_len, cur_byte;
  always_comb begin
    cur_len  = 8'd0; cur_byte = 8'h00;
    unique case (cmd_sel)
      CMD_STOP : begin cur_len = LEN_STOP [7:0]; cur_byte = MSG_STOP [idx]; end
      CMD_FWD  : begin cur_len = LEN_FWD  [7:0]; cur_byte = MSG_FWD  [idx]; end
      CMD_ARC_L: begin cur_len = LEN_ARC_L[7:0]; cur_byte = MSG_ARC_L[idx]; end
      CMD_ARC_R: begin cur_len = LEN_ARC_R[7:0]; cur_byte = MSG_ARC_R[idx]; end
      default  : begin cur_len = LEN_REV  [7:0]; cur_byte = MSG_REV  [idx]; end
    endcase
  end

  // ARM→PULSE per byte
  typedef enum logic [1:0] {IDLE, ARM, PULSE} st_t;
  st_t st;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st<=IDLE; idx<=8'd0; tx_valid<=1'b0; byte_to_send<=8'h00;
    end else begin
      tx_valid <= 1'b0;
      unique case (st)
        IDLE:  begin idx<=8'd0; if (tick_20hz) st<=ARM; end
        ARM:   if (tx_ready) begin byte_to_send<=cur_byte; st<=PULSE; end
        PULSE: if (tx_ready) begin
                 tx_valid <= 1'b1;
                 if (idx + 8'd1 >= cur_len) begin idx<=8'd0; st<=IDLE; end
                 else begin idx<=idx+8'd1; st<=ARM; end
               end
      endcase
    end
  end
endmodule


