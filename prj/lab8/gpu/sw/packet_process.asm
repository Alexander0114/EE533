# ============================================================
# GPU Packet Processing Program (Lab 8)
# ============================================================
# Reads payload words from FIFO BRAM, applies int16 VADD (+1
# per lane), writes results back in-place. Demonstrates GPU
# SIMD processing on network packet data.
#
# FIFO BRAM layout (after network input):
#   addr 0:   Module headers (ctrl=0xFF) -- DO NOT TOUCH
#   addr 1-N: Ethernet/IP headers + payload (ctrl=0x00)
#   addr N+1: Last word (ctrl may be non-zero)
#
# This program processes a fixed range of words (addr 1 to 5).
# The GPU's dmem interface maps directly to FIFO BRAM Port B.
# ============================================================

# --- Setup constants ---
    MOVI  R0,  0              # R0 = zero base
    ADDI  R1,  R0, 1          # R1 = 1 (scalar)
    VBCAST R1, R1, 3          # R1 = {1, 1, 1, 1} int16 lanes (lane 3 = LSB)

# --- Loop setup ---
    MOVI  R2,  1              # R2 = current addr (start at 1, skip module header)
    MOVI  R3,  6              # R3 = end addr (exclusive, process addrs 1-5)

# --- Processing loop ---
loop:
    BGE   R2, R3, done        # if R2 >= R3, exit
    LD    R4, R2, 0           # R4 = FIFO[R2] (64-bit word, 4x int16)
    VADD  R4, R4, R1          # R4 += {1,1,1,1} per int16 lane
    ST    R4, R2, 0           # FIFO[R2] = R4 (writes back, ctrl zeroed to 0x00)
    ADDI  R2, R2, 1           # R2++ (next word)
    BEQ   R0, R0, loop        # unconditional branch back

done:
    HALT
