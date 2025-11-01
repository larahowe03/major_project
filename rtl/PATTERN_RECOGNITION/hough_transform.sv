// ============================================================================
// Hough Transform Module
//  - Scans binary edge image from BRAM
//  - Accumulates votes for θ–ρ pairs
//  - Finds top peaks (strongest lines)
// ============================================================================
module hough_transform #(
    parameter IMG_WIDTH   = 640,
    parameter IMG_HEIGHT  = 480,
    parameter THETA_STEPS = 180,     // number of discrete angle bins
    parameter RHO_BINS    = 1024,    // number of ρ bins
    parameter ACC_WIDTH   = 8        // bits per accumulator cell
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,

    // BRAM interface (read-only)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] bram_addr,
    input  logic [1:0]  bram_data, // 1 = edge pixel, 0 = background

    // Line output (after peak detection)
    output logic [15:0] num_lines,
    output logic [15:0] line_theta [0:15],
    output logic [15:0] line_rho   [0:15]
);

    // ------------------------------------------------------------
    // Internal parameters and memories
    // ------------------------------------------------------------
    localparam IMG_SIZE = IMG_WIDTH * IMG_HEIGHT;
    localparam THETA_W  = $clog2(THETA_STEPS);
    localparam RHO_W    = $clog2(RHO_BINS);

    // LUTs for cosθ and sinθ in fixed-point (Q1.15)
    logic signed [15:0] cos_lut [0:THETA_STEPS-1];
    logic signed [15:0] sin_lut [0:THETA_STEPS-1];
    initial begin : init_trig
        integer i;
        real angle;
        for (i = 0; i < THETA_STEPS; i = i + 1) begin
            angle = (i * 3.14159265) / THETA_STEPS; // 0–π
            cos_lut[i] = $rtoi($cos(angle) * 32767.0);
            sin_lut[i] = $rtoi($sin(angle) * 32767.0);
        end
    end

    // Accumulator array (can be mapped to block RAM)
    logic [ACC_WIDTH-1:0] acc [0:THETA_STEPS-1][0:RHO_BINS-1];

    // ------------------------------------------------------------
    // FSM control
    // ------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        READ_PIXEL,
        ACCUM_THETA,
        FIND_PEAKS,
        DONE
    } state_t;
    state_t state;

    // Pixel scan counters
    logic [$clog2(IMG_WIDTH)-1:0]  x;
    logic [$clog2(IMG_HEIGHT)-1:0] y;
    logic [$clog2(IMG_SIZE)-1:0]   pixel_idx;

    // θ loop and ρ computation
    logic [THETA_W-1:0] theta_idx;
    logic signed [31:0] rho_val;
    logic [RHO_W-1:0]   rho_bin;

    // Peak search
    logic [ACC_WIDTH-1:0] max_vote;
    logic [THETA_W-1:0]   max_theta;
    logic [RHO_W-1:0]     max_rho;

    // ------------------------------------------------------------
    // FSM sequential logic
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 1'b0;
            pixel_idx <= 0;
            theta_idx <= 0;
            num_lines <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // clear accumulator
                        integer i,j;
                        for (i = 0; i < THETA_STEPS; i = i + 1)
                            for (j = 0; j < RHO_BINS; j = j + 1)
                                acc[i][j] <= '0;

                        pixel_idx <= 0;
                        theta_idx <= 0;
                        state <= READ_PIXEL;
                    end
                end

                READ_PIXEL: begin
                    bram_addr <= pixel_idx;
                    if (bram_data == 2'b01) begin  // edge pixel
                        theta_idx <= 0;
                        state <= ACCUM_THETA;
                    end else begin
                        pixel_idx <= pixel_idx + 1;
                        if (pixel_idx == IMG_SIZE-1)
                            state <= FIND_PEAKS;
                    end
                end

                ACCUM_THETA: begin
                    // compute ρ = x*cosθ + y*sinθ
                    x = pixel_idx % IMG_WIDTH;
                    y = pixel_idx / IMG_WIDTH;
                    rho_val = (x * cos_lut[theta_idx]) + (y * sin_lut[theta_idx]);
                    // normalize & bin
                    rho_bin = (rho_val >>> 15) + (RHO_BINS/2);
                    if (rho_bin < RHO_BINS)
                        acc[theta_idx][rho_bin] <= acc[theta_idx][rho_bin] + 1;

                    if (theta_idx == THETA_STEPS-1) begin
                        pixel_idx <= pixel_idx + 1;
                        if (pixel_idx == IMG_SIZE-1)
                            state <= FIND_PEAKS;
                        else
                            state <= READ_PIXEL;
                    end else
                        theta_idx <= theta_idx + 1;
                end

                FIND_PEAKS: begin
                    // simple linear search for max vote
                    integer i,j;
                    max_vote  = 0;
                    max_theta = 0;
                    max_rho   = 0;
                    for (i = 0; i < THETA_STEPS; i = i + 1)
                        for (j = 0; j < RHO_BINS; j = j + 1)
                            if (acc[i][j] > max_vote) begin
                                max_vote  = acc[i][j];
                                max_theta = i;
                                max_rho   = j;
                            end
                    // output single dominant line for now
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

                default: state <= IDLE;
            endcase
        end
    end

endmodule
