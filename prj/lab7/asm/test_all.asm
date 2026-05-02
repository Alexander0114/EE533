# ============================================================
# Comprehensive GPU Test Program
# ============================================================
# Data memory layout:
#   dmem[0]  = {1, 2, 3, 4}           int16 packed
#   dmem[1]  = {10, 20, 30, 40}       int16 packed
#   dmem[2]  = (result) VADD           expect {11,22,33,44}
#   dmem[3]  = {2.0, 1.5, 1.0, 3.0}   BF16 packed
#   dmem[4]  = {3.0, 2.0, 2.0, 2.0}   BF16 packed
#   dmem[5]  = (result) BF16 MUL       expect {6.0,3.0,2.0,6.0}
#   dmem[6]  = (result) BF16 ADD       expect {5.0,3.5,3.0,5.0}
#   dmem[7]  = (result) BF16 FMA       expect {8.0,4.5,3.0,9.0}
#   dmem[8]  = {-5, 10, -3, 7}        int16 (with negatives)
#   dmem[9]  = (result) RELU_INT       expect {0, 10, 0, 7}
#   dmem[10] = {-1.0, 2.0, -3.0, 1.0} BF16 (with negatives)
#   dmem[11] = {2.0, 3.0, 1.0, 4.0}   BF16
#   dmem[12] = (result) BF16 MUL+RELU  expect {0, 6.0, 0, 4.0}
#   dmem[13] = (result) VSUB           expect {-9,-18,-27,-36}
#   dmem[14] = (result) ADDI loop      expect 4
# ============================================================

# --- Test 1: Int16 VADD ---
# {1,2,3,4} + {10,20,30,40} = {11,22,33,44}
    MOVI R1, 0
    MOVI R2, 1
    MOVI R3, 2
    LD   R4, R1, 0
    LD   R5, R2, 0
    VADD R6, R4, R5
    ST   R6, R3, 0          # dmem[2]

# --- Test 2: BF16 MUL ---
# {2.0,1.5,1.0,3.0} * {3.0,2.0,2.0,2.0} = {6.0,3.0,2.0,6.0}
    MOVI R1, 3
    MOVI R2, 4
    MOVI R3, 5
    LD   R4, R1, 0
    LD   R5, R2, 0
    TENSOR_MUL R6, R4, R5
    ST   R6, R3, 0          # dmem[5]

# --- Test 3: BF16 ADD ---
# {2.0,1.5,1.0,3.0} + {3.0,2.0,2.0,2.0} = {5.0,3.5,3.0,5.0}
# R4 and R5 still hold dmem[3] and dmem[4]
    MOVI R3, 6
    TENSOR_ADD R6, R4, R5
    ST   R6, R3, 0          # dmem[6]

# --- Test 4: BF16 FMA (a*b+c) ---
# R4*R5+R4 = {2.0*3.0+2.0, 1.5*2.0+1.5, 1.0*2.0+1.0, 3.0*2.0+3.0}
#           = {8.0, 4.5, 3.0, 9.0}
    MOVI R3, 7
    TENSOR_FMA R6, R4, R5, R4
    ST   R6, R3, 0          # dmem[7]

# --- Test 5: RELU_INT ---
# max(0, {-5, 10, -3, 7}) = {0, 10, 0, 7}
    MOVI R1, 8
    MOVI R3, 9
    LD   R4, R1, 0
    RELU_INT R6, R4
    ST   R6, R3, 0          # dmem[9]

# --- Test 6: BF16 MUL + ReLU ---
# {-1.0,2.0,-3.0,1.0} * {2.0,3.0,1.0,4.0} = {-2.0,6.0,-3.0,4.0}
# ReLU clamps negatives: {0, 6.0, 0, 4.0}
    MOVI R1, 10
    MOVI R2, 11
    MOVI R3, 12
    LD   R4, R1, 0
    LD   R5, R2, 0
    TENSOR_MUL_RELU R6, R4, R5
    ST   R6, R3, 0          # dmem[12]

# --- Test 7: VSUB ---
# {1,2,3,4} - {10,20,30,40} = {-9,-18,-27,-36}
    MOVI R1, 0
    MOVI R2, 1
    MOVI R3, 13
    LD   R4, R1, 0
    LD   R5, R2, 0
    VSUB R6, R4, R5
    ST   R6, R3, 0          # dmem[13]

# --- Test 8: VAND ---
# {1,2,3,4} & {10,20,30,40}
    MOVI R1, 0
    MOVI R2, 1
    MOVI R3, 15
    LD   R4, R1, 0
    LD   R5, R2, 0
    VAND R6, R4, R5
    ST   R6, R3, 0          # dmem[15]

# --- Test 9: VOR ---
# {1,2,3,4} | {10,20,30,40}
    MOVI R3, 16
    VOR  R6, R4, R5
    ST   R6, R3, 0          # dmem[16]

# --- Test 10: VXOR ---
# {1,2,3,4} ^ {10,20,30,40}
    MOVI R3, 17
    VXOR R6, R4, R5
    ST   R6, R3, 0          # dmem[17]

# --- Test 11: VSLT ---
# {1,2,3,4} < {5,-3,15,-10} = {1,0,1,0}
    MOVI R1, 0
    MOVI R2, 18
    LD   R4, R1, 0           # dmem[0] = {1,2,3,4}
    LD   R5, R2, 0           # dmem[18] = {5,-3,15,-10}
    VSLT R6, R4, R5
    MOVI R3, 19
    ST   R6, R3, 0          # dmem[19]

# --- Test 12: LUI ---
# LUI R9, 0x1AB  =>  R9 = {0x1AB, 47'b0} = 0x00D5800000000000
    LUI  R9, 0x1AB
    MOVI R3, 20
    ST   R9, R3, 0          # dmem[20]

# --- Test 13: TENSOR_ADD_RELU ---
# {-1.0,2.0,-3.0,1.0} + {2.0,3.0,1.0,4.0} = {1.0,5.0,-2.0,5.0}
# ReLU clamps: {1.0, 5.0, 0, 5.0}
    MOVI R1, 10
    MOVI R2, 11
    MOVI R3, 21
    LD   R4, R1, 0
    LD   R5, R2, 0
    TENSOR_ADD_RELU R6, R4, R5
    ST   R6, R3, 0          # dmem[21]

# --- Test 14: TENSOR_FMA_RELU ---
# a*b+c where a=bf_neg_a, b=bf_neg_b, c=bf_neg_a
# {(-1)*2+(-1), 2*3+2, (-3)*1+(-3), 1*4+1} = {-3, 8, -6, 5}
# ReLU clamps: {0, 8.0, 0, 5.0}
# R4 and R5 still hold dmem[10] and dmem[11]
    MOVI R3, 22
    TENSOR_FMA_RELU R6, R4, R5, R4
    ST   R6, R3, 0          # dmem[22]

# --- Test 15: NOP ---
# Execute a NOP, then store a known value (42) to verify NOP didn't break flow
    MOVI R9, 42
    NOP
    MOVI R3, 23
    ST   R9, R3, 0          # dmem[23]

# --- Test 16: VBCAST ---
# Source = {1.0, 2.0, 3.0, 4.0} at dmem[24]
# Broadcast lane 1 (2.0) => {2.0, 2.0, 2.0, 2.0}
    MOVI R1, 24
    LD   R4, R1, 0           # R4 = {1.0, 2.0, 3.0, 4.0}
    VBCAST R7, R4, 1         # R7 = {2.0, 2.0, 2.0, 2.0}
    MOVI R3, 25
    ST   R7, R3, 0           # dmem[25]

# --- Test 17: 2x2 Matrix Multiply using VBCAST + TENSOR_FMA ---
# A = [[1.0, 2.0], [3.0, 4.0]]  packed in dmem[26] as {1.0, 2.0, 3.0, 4.0}
# B_row0 = {1.0, 0.0, 1.0, 0.0} at dmem[27]
# B_row1 = {0.0, 1.0, 0.0, 1.0} at dmem[28]
# C_row0 = a00*B_row0 + a01*B_row1 = 1*{1,0,1,0} + 2*{0,1,0,1} = {1,2,1,2}
    MOVI R1, 26
    LD   R10, R1, 0          # R10 = A elements {a00, a01, a10, a11}
    MOVI R1, 27
    LD   R11, R1, 0          # R11 = B_row0
    MOVI R1, 28
    LD   R12, R1, 0          # R12 = B_row1

    # Compute C_row0 = a00 * B_row0 + a01 * B_row1
    VBCAST R13, R10, 0       # R13 = {a00, a00, a00, a00} = {1.0, 1.0, 1.0, 1.0}
    TENSOR_MUL R14, R13, R11 # R14 = a00 * B_row0 = {1.0, 0.0, 1.0, 0.0}
    VBCAST R13, R10, 1       # R13 = {a01, a01, a01, a01} = {2.0, 2.0, 2.0, 2.0}
    TENSOR_FMA R15, R13, R12, R14  # R15 = a01*B_row1 + a00*B_row0 = {1.0,2.0,1.0,2.0}
    MOVI R3, 29
    ST   R15, R3, 0          # dmem[29]

    HALT
