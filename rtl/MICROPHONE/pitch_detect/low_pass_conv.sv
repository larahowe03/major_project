`timescale 1ns/1ns
module low_pass_conv #(
    parameter int W = 32,         // total width
    parameter int W_FRAC = 16     // fractional bits
)(
    input  logic clk,
    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data
);

    localparam int N  = 41;                // number of filter taps
    localparam int G  = 8;                 // group size per partial sum
    localparam int NUM_GROUPS = (N + G - 1) / G;  // derived constant
    assign x_ready = y_ready;  // no backpressure

    logic signed [W-1:0] h [0:N-1] = '{
        32'h00000000, 32'h00000014, 32'h0000003f, 32'h00000050, 32'h00000000,
        32'hffffff0b, 32'hfffffd56, 32'hfffffb08, 32'hfffff8a1, 32'hfffff6ee,
        32'hfffff6f3, 32'hfffff9b5, 32'h00000000, 32'h00000a2d, 32'h000017f4,
        32'h00002860, 32'h000039e3, 32'h00004a8b, 32'h0000584b, 32'h0000615d,
        32'h00006488, 32'h0000615d, 32'h0000584b, 32'h00004a8b, 32'h000039e3,
        32'h00002860, 32'h000017f4, 32'h00000a2d, 32'h00000000, 32'hfffff9b5,
        32'hfffff6f3, 32'hfffff6ee, 32'hfffff8a1, 32'hfffffb08, 32'hfffffd56,
        32'hffffff0b, 32'h00000000, 32'h00000050, 32'h0000003f, 32'h00000014,
        32'h00000000
    };

    // Input shift register
    logic signed [W-1:0] shift_reg [0:N-1];

    always_ff @(posedge clk) begin : shift_reg_stage
        if (x_valid && x_ready) begin
            shift_reg[0] <= signed'(x_data);
            for (int i = 0; i < N-1; i++) begin
                shift_reg[i+1] <= shift_reg[i];
            end
        end
    end

    // multiply stage
    logic signed [2*W-1:0] mult_result [0:N-1];

    always_ff @(posedge clk) begin : multiply_stage
        for (int i = 0; i < N; i++) begin
            mult_result[i] <= signed'(shift_reg[i]) * signed'(h[i]);
        end
    end

    // addiiton stage 1
    logic signed [2*W+8:0] partial_sum [0:NUM_GROUPS-1];

    always_ff @(posedge clk) begin : add_stage1
        for (int g = 0; g < NUM_GROUPS; g++) begin
            partial_sum[g] <= '0;
            for (int k = 0; k < G; k++) begin
                integer idx;               // declare separately, no static init
                idx = g*G + k;             // compute index
                if (idx < N)
                    partial_sum[g] <= partial_sum[g] + mult_result[idx];
            end
        end
    end

    // addition stage 2
    logic signed [2*W+12:0] macc;

    always_ff @(posedge clk) begin : add_stage2
        macc <= '0;
        for (int g = 0; g < NUM_GROUPS; g++) begin
            macc <= macc + partial_sum[g];
        end
    end

    // output
    logic x_valid_q1;
    logic x_valid_q2;

    always_ff @(posedge clk) begin : output_stage
        x_valid_q1 <= x_valid;
        x_valid_q2 <= x_valid_q1;

        if (y_ready) begin
            y_valid <= x_valid_q2;
            y_data  <= macc[W-1+W_FRAC : W_FRAC];  // truncate fractional bits
        end
    end

endmodule