import numpy as np

# ====================================================
# Parameters
# ====================================================
THETA_STEPS = 180
AMPLITUDE = 32767  # Q1.15 scaling
MODULE_NAME = "trig_lut_rom"

# ====================================================
# Generate Q1.15 sin/cos values
# ====================================================
angles_deg = np.arange(THETA_STEPS)
angles_rad = np.deg2rad(angles_deg)
cos_vals = np.round(np.cos(angles_rad) * AMPLITUDE).astype(np.int16)
sin_vals = np.round(np.sin(angles_rad) * AMPLITUDE).astype(np.int16)

# helper for Verilog literals
def to_signed16(v):
    if v < 0:
        return f"16'sh{(v + (1<<16)) & 0xFFFF:04X}"
    else:
        return f"16'sh{v:04X}"

# ====================================================
# Write Verilog module
# ====================================================
with open(f"{MODULE_NAME}.v", "w") as f:
    f.write("// ============================================================\n")
    f.write(f"// Auto-generated Q1.15 trig LUT ROM ({THETA_STEPS} entries)\n")
    f.write("// ============================================================\n")
    f.write(f"module {MODULE_NAME} (\n")
    f.write("    input  logic clk,\n")
    f.write(f"    input  logic [$clog2({THETA_STEPS})-1:0] theta_idx,\n")
    f.write("    output logic signed [15:0] cos_q,\n")
    f.write("    output logic signed [15:0] sin_q\n")
    f.write(");\n\n")

    # declare arrays
    f.write(f"    // Synchronous ROMs (Q1.15 fixed-point)\n")
    f.write(f"    reg signed [15:0] cos_rom [0:{THETA_STEPS-1}];\n")
    f.write(f"    reg signed [15:0] sin_rom [0:{THETA_STEPS-1}];\n\n")

    # initial block
    f.write("    initial begin\n")
    for i in range(THETA_STEPS):
        f.write(f"        cos_rom[{i}] = {to_signed16(int(cos_vals[i]))};"
                f"  // cos({i:3d}°) = {cos_vals[i]/32768:.6f}\n")
    f.write("\n")
    for i in range(THETA_STEPS):
        f.write(f"        sin_rom[{i}] = {to_signed16(int(sin_vals[i]))};"
                f"  // sin({i:3d}°) = {sin_vals[i]/32768:.6f}\n")
    f.write("    end\n\n")

    # synchronous read
    f.write("    always_ff @(posedge clk) begin\n")
    f.write("        cos_q <= cos_rom[theta_idx];\n")
    f.write("        sin_q <= sin_rom[theta_idx];\n")
    f.write("    end\n\n")

    f.write("endmodule\n")
    f.write("// ============================================================\n")

print(f"✅ Generated {MODULE_NAME}.v with {THETA_STEPS} entries.")
