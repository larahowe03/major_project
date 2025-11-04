import math

# === Parameters ===
N = 256           # number of samples
amplitude = 32767 # max 16-bit signed amplitude
frequency = 1000  # just for naming reference
filename = f"sine_{frequency}Hz.hex"

# === Generate 16-bit signed sine samples ===
samples = []
for i in range(N):
    angle = 2 * math.pi * i / N
    value = int(amplitude * math.sin(angle))
    samples.append(value & 0xFFFF)  # convert to 16-bit unsigned

# === Write file (with trailing space + CRLF endings) ===
with open(filename, "w", newline="\r\n") as f:
    for val in samples:
        f.write(f"{val:04X} \n")  # <-- note the space before \n

print(f"✅ Generated {filename} with {N} samples, CRLF endings, and trailing spaces.")
