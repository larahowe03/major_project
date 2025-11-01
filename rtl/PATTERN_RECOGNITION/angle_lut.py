import numpy as np

# ===============================================
# Parameters
# ===============================================
THETA_STEPS = 180
AMPLITUDE = 32767  # Q1.15 scaling
VERILOG_FILE = "trig_lut_rom.v"

# ===============================================
# Generate values
# ===============================================
angles_deg = np.arange(THETA_STEPS)
angles_rad = np.deg2rad(angles_deg)

cos_vals = np.round(np.cos(angles_rad) * AMPLITUDE).astype(np.int16)
sin_vals = np.round(np.sin(angles_rad) * AMPLITUDE).astype(np.int16)

# two’s complement hex strings
def to_hex16(val):
    return f"16'sh{val & 0xFFFF:04X}"

# ===============================================
# Write the Verilog ROM module
# ===============================================
with open(VERILOG_FILE, "w") as f:
    f.write("// ============================================================\n")
    f.write("// Auto-generated Q1.15 sine/cosine ROM for FPGA\n")
    f.write("// ============================================================\n")
    f.write("module trig_lut_rom #(\n")
    f.write(f"    parameter THETA_STEPS = {THETA_STEPS}\n")
    f.write(") (\n")
    f.write("    input  logic [$clog2(THETA_STEPS)-1:0] theta_idx,\n")
    f.write("    output logic signed [15:0] cos_q,\n")
    f.write("    output logic signed [15:0] sin_q\n")
    f.write(");\n\n")

    # cosine table
    f.write(f"    // Cosine table (Q1.15)\n")
    f.write(f"    localparam logic signed [15:0] cos_lut [0:THETA_STEPS-1] = '{{\n")
    for i, c in enumerate(cos_vals):
        sep = "," if i < THETA_STEPS - 1 else ""
        f.write(f"        {to_hex16(c)}{sep}\n")
    f.write("    };\n\n")

    # sine table
    f.write(f"    // Sine table (Q1.15)\n")
    f.write(f"    localparam logic signed [15:0] sin_lut [0:THETA_STEPS-1] = '{{\n")
    for i, s in enumerate(sin_vals):
        sep = "," if i < THETA_STEPS - 1 else ""
        f.write(f"        {to_hex16(s)}{sep}\n")
    f.write("    };\n\n")

    f.write("    always_comb begin\n")
    f.write("        cos_q = cos_lut[theta_idx];\n")
    f.write("        sin_q = sin_lut[theta_idx];\n")
    f.write("    end\n\n")

    f.write("endmodule\n")
    f.write("// ============================================================\n")

print(f"✅ Generated {VERILOG_FILE} with {THETA_STEPS} entries.")
