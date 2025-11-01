// ============================================================
// Auto-generated trig LUT ROM (Q1.15 fixed-point)
// Synchronous BRAM-based sine/cosine lookup for DE2 (M9K)
// ============================================================

module trig_lut_rom #(
    parameter THETA_STEPS = 180
) (
    input  logic clk,
    input  logic [$clog2(THETA_STEPS)-1:0] theta_idx,
    output logic signed [15:0] cos_q,
    output logic signed [15:0] sin_q
);

    // ------------------------------------------------------------
    // M9K-based ROMs (synchronous, 1-cycle latency)
    // ------------------------------------------------------------
    (* ramstyle = "M9K", romstyle = "M9K" *) reg signed [15:0] cos_rom [0:THETA_STEPS-1];
    (* ramstyle = "M9K", romstyle = "M9K" *) reg signed [15:0] sin_rom [0:THETA_STEPS-1];

    // Initialize ROM contents from external .mem files
    initial begin
        $readmemh("cos_lut.mem", cos_rom);
        $readmemh("sin_lut.mem", sin_rom);
    end

    // Synchronous read (block RAM behavior)
    always_ff @(posedge clk) begin
        cos_q <= cos_rom[theta_idx];
        sin_q <= sin_rom[theta_idx];
    end

endmodule
// ============================================================
