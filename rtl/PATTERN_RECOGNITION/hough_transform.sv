// ============================================================================
// FPGA-synthesizable Hough Transform
//  - Uses prebuilt trig_lut_rom (Q1.15 fixed-point sin/cos tables)
//  - LUT outputs registered 1 cycle before multiply
//  - All math fixed-point integer; no "real", $sin, $cos, $rtoi
// ============================================================================
module hough_transform #(
    parameter IMG_WIDTH   = 640,
    parameter IMG_HEIGHT  = 480,
    parameter THETA_STEPS = 180,
    parameter RHO_BINS    = 1024,
    parameter ACC_WIDTH   = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,

    // BRAM interface
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_addr,
    input  logic [1:0]  bram_data,     // 1 = edge pixel, 0 = background

    // Line output
    output logic [15:0] num_lines,
    output logic [15:0] line_theta [0:15],
    output logic [15:0] line_rho   [0:15]
);
    // ------------------------------------------------------------
    // Internal parameters
    // ------------------------------------------------------------
    localparam IMG_SIZE = IMG_WIDTH * IMG_HEIGHT;
    localparam THETA_W  = $clog2(THETA_STEPS);
    localparam RHO_W    = $clog2(RHO_BINS);

    // ------------------------------------------------------------
    // Trig lookup ROM (clocked output)
    // ------------------------------------------------------------
    logic signed [15:0] cos_q, sin_q;
    logic [THETA_W-1:0] theta_idx;
    trig_lut_rom #(.THETA_STEPS(THETA_STEPS)) trig_rom_inst (
        .clk       (clk),
        .theta_idx (theta_idx),
        .cos_q     (cos_q),
        .sin_q     (sin_q)
    );

    // ------------------------------------------------------------
    // Accumulator memory
    // ------------------------------------------------------------
    logic [ACC_WIDTH-1:0] acc [0:THETA_STEPS-1][0:RHO_BINS-1];

    // FSM states
    typedef enum logic [2:0] { IDLE, READ_PIXEL, THETA_REQ, THETA_USE,
                               FIND_PEAKS, DONE } state_t;
    state_t state;

    // counters
    logic [$clog2(IMG_SIZE)-1:0] pixel_idx;
    logic [$clog2(IMG_WIDTH)-1:0] x;
    logic [$clog2(IMG_HEIGHT)-1:0] y;

    // rho math
    logic signed [31:0] rho_val;
    logic [RHO_W-1:0]   rho_bin;

    // peak search
    logic [ACC_WIDTH-1:0] max_vote;
    logic [THETA_W-1:0]   max_theta;
    logic [RHO_W-1:0]     max_rho;

    // ------------------------------------------------------------
    // Sequential FSM
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            pixel_idx  <= '0;
            theta_idx  <= '0;
            num_lines  <= '0;
            done       <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        integer i,j;
                        for (i = 0; i < THETA_STEPS; i++)
                            for (j = 0; j < RHO_BINS; j++)
                                acc[i][j] <= '0;
                        pixel_idx <= 0;
                        theta_idx <= 0;
                        state     <= READ_PIXEL;
                    end
                end

                READ_PIXEL: begin
                    bram_addr <= pixel_idx;
                    if (bram_data == 2'b01) begin
                        theta_idx <= 0;
                        state     <= THETA_REQ; // request LUT outputs
                    end else begin
                        pixel_idx <= pixel_idx + 1;
                        if (pixel_idx == IMG_SIZE-1)
                            state <= FIND_PEAKS;
                    end
                end

                // ask ROM for cos/sin (1-cycle latency)
                THETA_REQ: begin
                    state <= THETA_USE;
                end

                // use registered cos/sin values
                THETA_USE: begin
                    x = pixel_idx % IMG_WIDTH;
                    y = pixel_idx / IMG_WIDTH;

                    rho_val = (x * cos_q) + (y * sin_q);
                    rho_bin = (rho_val >>> 15) + (RHO_BINS >> 1);

                    if (rho_bin < RHO_BINS)
                        acc[theta_idx][rho_bin] <= acc[theta_idx][rho_bin] + 1;

                    if (theta_idx == THETA_STEPS-1) begin
                        pixel_idx <= pixel_idx + 1;
                        if (pixel_idx == IMG_SIZE-1)
                            state <= FIND_PEAKS;
                        else
                            state <= READ_PIXEL;
                    end else begin
                        theta_idx <= theta_idx + 1;
                        state     <= THETA_REQ;  // next θ, pipeline repeats
                    end
                end

                FIND_PEAKS: begin
                    integer i,j;
                    max_vote  = 0;
                    max_theta = 0;
                    max_rho   = 0;
                    for (i = 0; i < THETA_STEPS; i++)
                        for (j = 0; j < RHO_BINS; j++)
                            if (acc[i][j] > max_vote) begin
                                max_vote  = acc[i][j];
                                max_theta = i;
                                max_rho   = j;
                            end
                    line_theta[0] <= max_theta;
                    line_rho[0]   <= max_rho;
                    num_lines     <= 1;
                    state         <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start)
                        state <= IDLE;
                end
            endcase
        end
    end
endmodule
