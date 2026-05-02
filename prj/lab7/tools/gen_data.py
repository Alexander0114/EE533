#!/usr/bin/env python3
"""
Generate data.hex for the GPU testbench.
Packs int16 and BFloat16 test vectors into 64-bit words,
and prints expected results for verification.

Each 64-bit word holds 4 x 16-bit lanes:
  [63:48] = element 0
  [47:32] = element 1
  [31:16] = element 2
  [15:0]  = element 3
"""

import struct

# ── BFloat16 helpers ──────────────────────────────────────────────

def float_to_bf16(f):
    """Convert a Python float to a 16-bit BFloat16 value."""
    # Pack as IEEE-754 float32, take upper 16 bits
    bits = struct.pack('>f', f)
    return (bits[0] << 8) | bits[1]


def bf16_to_float(bf):
    """Convert a 16-bit BFloat16 value back to Python float."""
    # Pad lower 16 bits with zeros to get float32
    bits = struct.pack('>HH', bf, 0)
    return struct.unpack('>f', bits)[0]


# ── Packing helpers ───────────────────────────────────────────────

def pack_int16(elems):
    """Pack 4 int16 values into a 64-bit word. elems[0] goes to [63:48]."""
    word = 0
    for i, v in enumerate(elems):
        v16 = v & 0xFFFF
        word |= v16 << (48 - 16 * i)
    return word


def pack_bf16(floats):
    """Pack 4 float values as BF16 into a 64-bit word. floats[0] goes to [63:48]."""
    word = 0
    for i, f in enumerate(floats):
        bf = float_to_bf16(f)
        word |= bf << (48 - 16 * i)
    return word


# ── Compute expected results ──────────────────────────────────────

def bf16_mul(a, b):
    """Multiply two floats with BF16 precision (truncate intermediates)."""
    # Convert to bf16 and back to simulate hardware precision
    af = bf16_to_float(float_to_bf16(a))
    bf_ = bf16_to_float(float_to_bf16(b))
    return bf16_to_float(float_to_bf16(af * bf_))


def bf16_add(a, b):
    af = bf16_to_float(float_to_bf16(a))
    bf_ = bf16_to_float(float_to_bf16(b))
    return bf16_to_float(float_to_bf16(af + bf_))


def bf16_fma(a, b, c):
    af = bf16_to_float(float_to_bf16(a))
    bf_ = bf16_to_float(float_to_bf16(b))
    cf = bf16_to_float(float_to_bf16(c))
    return bf16_to_float(float_to_bf16(af * bf_ + cf))


def relu(x):
    return max(0, x)


# ── Define test vectors ──────────────────────────────────────────

# Int16 vectors
int_a = [1, 2, 3, 4]
int_b = [10, 20, 30, 40]

# BF16 vectors
bf_a = [2.0, 1.5, 1.0, 3.0]
bf_b = [3.0, 2.0, 2.0, 2.0]

# Int16 with negatives (for RELU_INT)
int_neg = [-5, 10, -3, 7]

# BF16 with negatives (for MUL+RELU)
bf_neg_a = [-1.0, 2.0, -3.0, 1.0]
bf_neg_b = [2.0, 3.0, 1.0, 4.0]

# ── Build data memory ────────────────────────────────────────────

dmem = [0] * 30  # 30 entries, all zero initially

# Inputs
dmem[0]  = pack_int16(int_a)                    # {1, 2, 3, 4}
dmem[1]  = pack_int16(int_b)                    # {10, 20, 30, 40}
dmem[2]  = 0                                     # result: VADD
dmem[3]  = pack_bf16(bf_a)                       # {2.0, 1.5, 1.0, 3.0}
dmem[4]  = pack_bf16(bf_b)                       # {3.0, 2.0, 2.0, 2.0}
dmem[5]  = 0                                     # result: BF16 MUL
dmem[6]  = 0                                     # result: BF16 ADD
dmem[7]  = 0                                     # result: BF16 FMA
dmem[8]  = pack_int16(int_neg)                   # {-5, 10, -3, 7}
dmem[9]  = 0                                     # result: RELU_INT
dmem[10] = pack_bf16(bf_neg_a)                   # {-1.0, 2.0, -3.0, 1.0}
dmem[11] = pack_bf16(bf_neg_b)                   # {2.0, 3.0, 1.0, 4.0}
dmem[12] = 0                                     # result: BF16 MUL+RELU
dmem[13] = 0                                     # result: VSUB
dmem[14] = 0                                     # result: ADDI loop
dmem[15] = 0                                     # result: VAND
dmem[16] = 0                                     # result: VOR
dmem[17] = 0                                     # result: VXOR
dmem[18] = pack_int16([5, -3, 15, -10])          # {5, -3, 15, -10} for VSLT test
dmem[19] = 0                                     # result: VSLT
dmem[20] = 0                                     # result: LUI
dmem[21] = 0                                     # result: TENSOR_ADD_RELU
dmem[22] = 0                                     # result: TENSOR_FMA_RELU
dmem[23] = 0                                     # result: NOP (store after NOP)

# VBCAST test data
vbcast_src = [1.0, 2.0, 3.0, 4.0]
dmem[24] = pack_bf16(vbcast_src)                  # VBCAST source vector
dmem[25] = 0                                     # result: VBCAST lane 1 (expect {2.0,2.0,2.0,2.0})

# 2x2 matrix multiply test data
# A matrix elements packed: {a00, a01, a10, a11} = {1.0, 2.0, 3.0, 4.0}
mat_a = [1.0, 2.0, 3.0, 4.0]
dmem[26] = pack_bf16(mat_a)                       # A elements
# B rows
mat_b_row0 = [1.0, 0.0, 1.0, 0.0]
mat_b_row1 = [0.0, 1.0, 0.0, 1.0]
dmem[27] = pack_bf16(mat_b_row0)                  # B row 0
dmem[28] = pack_bf16(mat_b_row1)                  # B row 1
dmem[29] = 0                                     # result: C row 0 (expect {1.0,2.0,1.0,2.0})

# ── Write data.hex ────────────────────────────────────────────────

with open('data.hex', 'w') as f:
    for word in dmem:
        f.write(f'{word:016X}\n')

print("Generated data.hex with", len(dmem), "entries\n")

# ── Print layout and expected results ─────────────────────────────

print("=== Data Memory Layout ===")
for i, word in enumerate(dmem):
    print(f"  dmem[{i:2d}] = 0x{word:016X}")

print("\n=== Expected Results ===")

# Test 1: VADD
exp_vadd = [a + b for a, b in zip(int_a, int_b)]
exp_vadd_word = pack_int16(exp_vadd)
print(f"  dmem[2]  VADD       = {exp_vadd}  -> 0x{exp_vadd_word:016X}")

# Test 2: BF16 MUL
exp_mul = [bf16_mul(a, b) for a, b in zip(bf_a, bf_b)]
exp_mul_word = pack_bf16(exp_mul)
print(f"  dmem[5]  BF16 MUL   = {exp_mul}  -> 0x{exp_mul_word:016X}")

# Test 3: BF16 ADD
exp_add = [bf16_add(a, b) for a, b in zip(bf_a, bf_b)]
exp_add_word = pack_bf16(exp_add)
print(f"  dmem[6]  BF16 ADD   = {exp_add}  -> 0x{exp_add_word:016X}")

# Test 4: BF16 FMA (a*b+c where c=a)
exp_fma = [bf16_fma(a, b, a) for a, b in zip(bf_a, bf_b)]
exp_fma_word = pack_bf16(exp_fma)
print(f"  dmem[7]  BF16 FMA   = {exp_fma}  -> 0x{exp_fma_word:016X}")

# Test 5: RELU_INT
exp_relu = [relu(x) for x in int_neg]
exp_relu_word = pack_int16(exp_relu)
print(f"  dmem[9]  RELU_INT   = {exp_relu}  -> 0x{exp_relu_word:016X}")

# Test 6: BF16 MUL+RELU
exp_mul_relu_raw = [bf16_mul(a, b) for a, b in zip(bf_neg_a, bf_neg_b)]
exp_mul_relu = [max(0.0, x) for x in exp_mul_relu_raw]
exp_mul_relu_word = pack_bf16(exp_mul_relu)
print(f"  dmem[12] MUL+RELU   = {exp_mul_relu}  -> 0x{exp_mul_relu_word:016X}")

# Test 7: VSUB
exp_vsub = [a - b for a, b in zip(int_a, int_b)]
exp_vsub_word = pack_int16(exp_vsub)
print(f"  dmem[13] VSUB       = {exp_vsub}  -> 0x{exp_vsub_word:016X}")

# Test 8: ADDI loop
exp_loop = pack_int16([0, 0, 0, 4])
print(f"  dmem[14] LOOP       = [0,0,0,4]  -> 0x{exp_loop:016X}")

# Test 9: VAND  (int_a & int_b)
exp_vand_word = pack_int16(int_a) & pack_int16(int_b)
print(f"  dmem[15] VAND       = -> 0x{exp_vand_word:016X}")

# Test 10: VOR  (int_a | int_b)
exp_vor_word = pack_int16(int_a) | pack_int16(int_b)
print(f"  dmem[16] VOR        = -> 0x{exp_vor_word:016X}")

# Test 11: VXOR (int_a ^ int_b)
exp_vxor_word = pack_int16(int_a) ^ pack_int16(int_b)
print(f"  dmem[17] VXOR       = -> 0x{exp_vxor_word:016X}")

# Test 12: VSLT (int_a < dmem[18]{5,-3,15,-10})
# Per-lane signed: 1<5=1, 2<-3=0, 3<15=1, 4<-10=0
int_c = [5, -3, 15, -10]
exp_vslt = [1 if a < b else 0 for a, b in zip(int_a, int_c)]
exp_vslt_word = pack_int16(exp_vslt)
print(f"  dmem[19] VSLT       = {exp_vslt}  -> 0x{exp_vslt_word:016X}")

# Test 13: LUI
# LUI Rd, imm  =>  {imm17, 47'b0}
# Use imm = 0x1AB (arbitrary). Result = 0x1AB << 47 = 0xD580_0000_0000_0000
lui_imm = 0x1AB
exp_lui_word = (lui_imm << 47) & 0xFFFFFFFFFFFFFFFF
print(f"  dmem[20] LUI        = imm=0x{lui_imm:05X}  -> 0x{exp_lui_word:016X}")

# Test 14: TENSOR_ADD_RELU
# bf_neg_a + bf_neg_b = {-1+2, 2+3, -3+1, 1+4} = {1.0, 5.0, -2.0, 5.0}
# ReLU clamps: {1.0, 5.0, 0, 5.0}
exp_add_relu_raw = [bf16_add(a, b) for a, b in zip(bf_neg_a, bf_neg_b)]
exp_add_relu = [max(0.0, x) for x in exp_add_relu_raw]
exp_add_relu_word = pack_bf16(exp_add_relu)
print(f"  dmem[21] ADD_RELU   = {exp_add_relu}  -> 0x{exp_add_relu_word:016X}")

# Test 15: TENSOR_FMA_RELU
# bf_neg_a * bf_neg_b + bf_neg_a = {(-1)*2+(-1), 2*3+2, (-3)*1+(-3), 1*4+1}
#                                = {-3, 8, -6, 5}
# ReLU clamps: {0, 8.0, 0, 5.0}
exp_fma_relu_raw = [bf16_fma(a, b, a) for a, b in zip(bf_neg_a, bf_neg_b)]
exp_fma_relu = [max(0.0, x) for x in exp_fma_relu_raw]
exp_fma_relu_word = pack_bf16(exp_fma_relu)
print(f"  dmem[22] FMA_RELU   = {exp_fma_relu}  -> 0x{exp_fma_relu_word:016X}")

# Test 16: NOP
# Just verify a known value (42) is stored after a NOP executes
exp_nop_word = 42
print(f"  dmem[23] NOP_CHECK  = 42  -> 0x{exp_nop_word:016X}")

# Test 17: VBCAST lane 1
# Source = {1.0, 2.0, 3.0, 4.0}, broadcast lane 1 => {2.0, 2.0, 2.0, 2.0}
exp_vbcast = [2.0, 2.0, 2.0, 2.0]
exp_vbcast_word = pack_bf16(exp_vbcast)
print(f"  dmem[25] VBCAST     = {exp_vbcast}  -> 0x{exp_vbcast_word:016X}")

# Test 18: 2x2 Matrix Multiply C_row0
# C_row0 = a00*B_row0 + a01*B_row1 = 1.0*{1,0,1,0} + 2.0*{0,1,0,1} = {1.0,2.0,1.0,2.0}
exp_matmul_c0 = [bf16_add(bf16_mul(mat_a[0], mat_b_row0[i]),
                           bf16_mul(mat_a[1], mat_b_row1[i])) for i in range(4)]
exp_matmul_c0_word = pack_bf16(exp_matmul_c0)
print(f"  dmem[29] MATMUL_C0  = {exp_matmul_c0}  -> 0x{exp_matmul_c0_word:016X}")

print("\n=== Verilog localparam Expected Values ===")
print(f"  localparam [63:0] EXP_VADD     = 64'h{exp_vadd_word:016X};")
print(f"  localparam [63:0] EXP_BF16_MUL = 64'h{exp_mul_word:016X};")
print(f"  localparam [63:0] EXP_BF16_ADD = 64'h{exp_add_word:016X};")
print(f"  localparam [63:0] EXP_BF16_FMA = 64'h{exp_fma_word:016X};")
print(f"  localparam [63:0] EXP_RELU_INT = 64'h{exp_relu_word:016X};")
print(f"  localparam [63:0] EXP_MUL_RELU = 64'h{exp_mul_relu_word:016X};")
print(f"  localparam [63:0] EXP_VSUB     = 64'h{exp_vsub_word:016X};")
print(f"  localparam [63:0] EXP_LOOP     = 64'h{exp_loop:016X};")
print(f"  localparam [63:0] EXP_VAND     = 64'h{exp_vand_word:016X};")
print(f"  localparam [63:0] EXP_VOR      = 64'h{exp_vor_word:016X};")
print(f"  localparam [63:0] EXP_VXOR     = 64'h{exp_vxor_word:016X};")
print(f"  localparam [63:0] EXP_VSLT     = 64'h{exp_vslt_word:016X};")
print(f"  localparam [63:0] EXP_LUI      = 64'h{exp_lui_word:016X};")
print(f"  localparam [63:0] EXP_ADD_RELU = 64'h{exp_add_relu_word:016X};")
print(f"  localparam [63:0] EXP_FMA_RELU = 64'h{exp_fma_relu_word:016X};")
print(f"  localparam [63:0] EXP_NOP_CHK  = 64'h{exp_nop_word:016X};")
print(f"  localparam [63:0] EXP_VBCAST   = 64'h{exp_vbcast_word:016X};")
print(f"  localparam [63:0] EXP_MATMUL0  = 64'h{exp_matmul_c0_word:016X};")
