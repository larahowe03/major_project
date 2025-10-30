module uart_tx #(
    parameter int CLKS_PER_BIT = (50_000_000/115200),
    parameter int BITS_N       = 8,  // data bits
    parameter int PARITY_TYPE  = 0   // 0=none, 1=odd, 2=even
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic [BITS_N-1:0]    data_tx,
    input  logic                 valid,   // producer asserts when data_tx is valid
    output logic                 ready,   // this TX is ready to accept a word
    output logic                 uart_out // serial line (idle high)
);

    // -------- sizes --------
    localparam int BIT_IDX_W = (BITS_N > 1) ? $clog2(BITS_N) : 1;
    localparam int BAUD_W    = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

    // -------- regs --------
    logic [BITS_N-1:0] data_reg;
    logic [BIT_IDX_W-1:0] bit_idx;
    logic [BAUD_W-1:0]    baud_cnt;

    logic parity_bit;

    typedef enum logic [2:0] {IDLE, START_BIT, DATA_BITS, PARITY_BIT, STOP_BIT} state_t;
    state_t state;

    // -------- main FSM (registered outputs for glitch-free line) --------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            uart_out  <= 1'b1;
            ready     <= 1'b1;
            baud_cnt  <= '0;
            bit_idx   <= '0;
            data_reg  <= '0;
            parity_bit<= 1'b0;
        end else begin
            case (state)
                // ---------------- IDLE ----------------
                IDLE: begin
                    uart_out <= 1'b1;
                    ready    <= 1'b1;
                    baud_cnt <= '0;
                    bit_idx  <= '0;

                    // handshake: latch data immediately when valid & ready
                    if (valid) begin
                        data_reg <= data_tx;
                        // compute parity once per frame
                        // reduction XOR (1 if odd # of 1s)
                        unique case (PARITY_TYPE)
                            1: parity_bit <= ~(^data_tx); // odd parity bit
                            2: parity_bit <=  (^data_tx); // even parity bit
                            default: parity_bit <= 1'b0;  // unused
                        endcase

                        ready    <= 1'b0;
                        state    <= START_BIT;
                    end
                end

                // --------------- START ----------------
                START_BIT: begin
                    uart_out <= 1'b0; // start = 0
                    if (baud_cnt == CLKS_PER_BIT-1) begin
                        baud_cnt <= '0;
                        state    <= DATA_BITS;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                // --------------- DATA -----------------
                DATA_BITS: begin
                    uart_out <= data_reg[bit_idx]; // LSB-first
                    if (baud_cnt == CLKS_PER_BIT-1) begin
                        baud_cnt <= '0;
                        if (bit_idx == BITS_N-1) begin
                            state <= (PARITY_TYPE==0) ? STOP_BIT : PARITY_BIT;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                // --------------- PARITY ---------------
                PARITY_BIT: begin
                    uart_out <= parity_bit;
                    if (baud_cnt == CLKS_PER_BIT-1) begin
                        baud_cnt <= '0;
                        state    <= STOP_BIT;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                // ---------------- STOP ----------------
                STOP_BIT: begin
                    uart_out <= 1'b1; // stop = 1
                    if (baud_cnt == CLKS_PER_BIT-1) begin
                        baud_cnt <= '0;
                        state    <= IDLE;
                        ready    <= 1'b1;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
