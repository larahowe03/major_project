import numpy as np

# ====================================================
# CONFIGURATION
# ====================================================
THETA_STEPS = 180           # number of LUT entries (0°–179°)
AMPLITUDE = 32767           # Q1.15 scaling
MODULE_NAME = "trig_lut_rom"

COS_FILE = "cos_lut.mem"
SIN_FILE = "sin_lut.mem"
VERILOG_FILE = f"{MODULE_NAME}.v"

# ====================================================
# GENERATE LUT DATA
# ====================================================
angles_deg = np.arange(THETA_STEPS)
angles_rad = np.deg2rad(angles_deg)

# Q1.15 scaled signed integers
cos_vals = np.round(np.cos(angles_rad) * AMPLITUDE).astype(np.int16)
sin_vals = np.round(np.sin(angles_rad) * AMPLITUDE).astype(np.int16)

# Write .mem files (hex, 4 digits per line)
def write_mem(filename, data):
    with open(filename, "w") as f:
        for val in data:
            f.write(f"{(val & 0xFFFF):04X}\n")

write_mem(COS_FILE, cos_vals)
write_mem(SIN_FILE, sin_vals)

print(f"✅ Wrote {COS_FILE} and {SIN_FILE} ({THETA_STEPS} entries each).")

# ====================================================
# GENERATE SYNTHESIZABLE VERILOG MODULE (M9K)
# ====================================================
with open(VERILOG_FILE, "w") as f:
    f.write("// ============================================================\n")
    f.write("// Auto-generated trig LUT ROM (Q1.15 fixed-point)\n")
    f.write("// Synchronous BRAM-based sine/cosine lookup for DE2 (M9K)\n")
    f.write("// ============================================================\n\n")
    f.write(f"module {MODULE_NAME} #(\n")
    f.write(f"    parameter THETA_STEPS = {THETA_STEPS}\n")
    f.write(") (\n")
    f.write("    input  logic clk,\n")
    f.write(f"    input  logic [$clog2(THETA_STEPS)-1:0] theta_idx,\n")
    f.write("    output logic signed [15:0] cos_q,\n")
    f.write("    output logic signed [15:0] sin_q\n")
    f.write(");\n\n")

    f.write("    // ------------------------------------------------------------\n")
    f.write("    // M9K-based ROMs (synchronous, 1-cycle latency)\n")
    f.write("    // ------------------------------------------------------------\n")
    f.write('    (* ramstyle = "M9K", romstyle = "M9K" *) reg signed [15:0] cos_rom [0:THETA_STEPS-1];\n')
    f.write('    (* ramstyle = "M9K", romstyle = "M9K" *) reg signed [15:0] sin_rom [0:THETA_STEPS-1];\n\n')

    f.write("    // Initialize ROM contents from external .mem files\n")
    f.write("    initial begin\n")
    f.write(f'        $readmemh("{COS_FILE}", cos_rom);\n')
    f.write(f'        $readmemh("{SIN_FILE}", sin_rom);\n')
    f.write("    end\n\n")

    f.write("    // Synchronous read (block RAM behavior)\n")
    f.write("    always_ff @(posedge clk) begin\n")
    f.write("        cos_q <= cos_rom[theta_idx];\n")
    f.write("        sin_q <= sin_rom[theta_idx];\n")
    f.write("    end\n\n")

    f.write("endmodule\n")
    f.write("// ============================================================\n")

print(f"✅ Generated {VERILOG_FILE} for M9K-based design.")
