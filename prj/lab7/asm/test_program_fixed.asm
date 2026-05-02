# ============================================================
#   GPU Kernel Verification — test_program_fixed.asm
#   Disassembled from test_program_fixed.hex
#   Fix: VBCAST uses lane 3 (LSB) instead of lane 0
# ============================================================

# === Test 1: vector_add (int16) ===
# R2={3,3,3,3}, R4={5,5,5,5}, result → dmem[0]
# Expected: 0008000800080008
    MOVI    R2, 3
    VBCAST  R2, R2, 3
    MOVI    R4, 5
    VBCAST  R4, R4, 3
    MOVI    R7, 0               # dmem store address
    VADD    R6, R4, R2          # R6 = {5+3, ...} = {8,8,8,8}
    ST      R6, R7, 0           # dmem[0] = R6

# === Test 2: vector_sub (int16) ===
# R2={20,20,20,20}, R4={7,7,7,7}, result → dmem[1]
# Expected: 000D000D000D000D
    MOVI    R2, 20
    VBCAST  R2, R2, 3
    MOVI    R4, 7
    VBCAST  R4, R4, 3
    MOVI    R7, 1               # dmem store address
    VSUB    R6, R2, R4          # R6 = {20-7, ...} = {13,13,13,13}
    ST      R6, R7, 0           # dmem[1] = R6

# === Test 3: bf16_vector_mul (FMA with zero accum) ===
# R2={2.0}, R4={3.0}, result → dmem[2]
# Expected: 40C040C040C040C0
    MOVI    R2, 0x4000          # bf16 2.0
    VBCAST  R2, R2, 3
    MOVI    R4, 0x4040          # bf16 3.0
    VBCAST  R4, R4, 3
    MOVI    R8, 2               # dmem store address
    MOVI    R6, 0x8000          # bf16 -0.0 (zero accumulator, no VBCAST needed)
    TENSOR_FMA R7, R2, R4, R6  # R7 = 2.0*3.0 + 0.0 = 6.0 per lane
    ST      R7, R8, 0           # dmem[2] = R7

# === Test 4: bf16_fma ===
# R2={2.0}, R4={3.0} reused from test 3, R6={1.0}, result → dmem[3]
# Expected: 40E040E040E040E0
    MOVI    R6, 0x3F80          # bf16 1.0
    VBCAST  R6, R6, 3
    MOVI    R9, 3               # dmem store address
    TENSOR_FMA R8, R2, R4, R6  # R8 = 2.0*3.0 + 1.0 = 7.0 per lane
    ST      R8, R9, 0           # dmem[3] = R8

# === Test 5: relu_int16 ===
# R2={-5,-5,-5,-5}, result → dmem[4]
# Expected: 0000000000000000
    MOVI    R2, -5
    VBCAST  R2, R2, 3
    MOVI    R5, 4               # dmem store address
    RELU_INT R4, R2             # R4 = max(0, {-5,...}) = {0,0,0,0}
    ST      R4, R5, 0           # dmem[4] = R4

# === Test 6: relu_bf16 (TENSOR_ADD with ReLU) ===
# R2={-2.0,-2.0,-2.0,-2.0}, result → dmem[5]
# Expected: 0000000000000000
    MOVI    R2, 0xC000          # bf16 -2.0
    VBCAST  R2, R2, 3
    MOVI    R5, 0               # bf16 zero vector (no VBCAST needed)
    MOVI    R7, 5               # dmem store address
    TENSOR_ADD_RELU R4, R2, R5  # R4 = ReLU(-2.0 + 0.0) = 0.0 per lane
    ST      R4, R7, 0           # dmem[5] = R4

# === DONE ===
    HALT
