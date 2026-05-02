# === Test 1: Int16 VADD ===
MOVI R1, 0          # base addr vec A
MOVI R2, 1          # base addr vec B
MOVI R3, 2          # result addr
LD   R4, R1, 0      # R4 = dmem[0] = vec A
LD   R5, R2, 0      # R5 = dmem[1] = vec B
VADD R6, R4, R5     # R6 = A + B (4-lane int16)
ST   R6, R3, 0      # dmem[2] = R6

# === Test 2: BF16 MUL ===
MOVI R1, 3          # base addr vec X
MOVI R2, 4          # base addr vec Y
MOVI R3, 5          # result addr
LD   R4, R1, 0      # R4 = dmem[3] = vec X
LD   R5, R2, 0      # R5 = dmem[4] = vec Y
TENSOR_MUL R6, R4, R5  # R6 = X * Y (4-lane BF16)
ST   R6, R3, 0      # dmem[5] = R6

HALT
