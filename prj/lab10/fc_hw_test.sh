#!/bin/bash
# fc_hw_test.sh — FC layer inference via register injection on NetFPGA
#
# Uses soc_netfpga's register-based packet injection to run:
#   y = ReLU(W * X + B)
# where W=Identity, X=[2,3,0,-1], B=0
# Expected: [2.0, 3.0, 0, 0] per bank
#
# TX snoop captures first 2 words only (hw_tx_word0 = header, hw_tx_word1 = bank0+1 data)
#
# Usage: sudo bash fc_hw_test.sh

set -e

# ================================================================
#  Register addresses
#  Base = SOC_NETFPGA_BLOCK_ADDR (19'h00008) << 8 = 0x00000800
# ================================================================
BASE=0x00000800
SW_DATA_HI=$((BASE + 0x00))   # reg 0
SW_DATA_LO=$((BASE + 0x04))   # reg 1
SW_CTRL=$((BASE + 0x08))      # reg 2
SW_CMD=$((BASE + 0x0C))       # reg 3
HW_STATUS=$((BASE + 0x10))    # reg 4
HW_TX_W0_HI=$((BASE + 0x14)) # reg 5
HW_TX_W0_LO=$((BASE + 0x18)) # reg 6
HW_TX_W1_HI=$((BASE + 0x1C)) # reg 7
HW_TX_W1_LO=$((BASE + 0x20)) # reg 8

# ================================================================
#  Helper functions
# ================================================================
wr() { regwrite $1 $2; }
rd() { regread $1 2>/dev/null | grep -oP '0x[0-9a-fA-F]+' | tail -1; }

push_word() {
    # push_word <data_hi> <data_lo> <ctrl>
    wr $SW_DATA_HI $1
    wr $SW_DATA_LO $2
    wr $SW_CTRL $3
    wr $SW_CMD 0x3   # mux_sel=1 | push_toggle=1
    wr $SW_CMD 0x2   # mux_sel=1 | push_toggle=0
}

# ================================================================
#  BF16 constants
# ================================================================
BF16_0=0x0000
BF16_1=0x3F80
BF16_2=0x4000
BF16_3=0x4040
BF16_N1=0xBF80

# ================================================================
#  GPU Kernel (13+3 pad = 16 instrs = 8 DWs)
# ================================================================
# [0]  MOVI R0, 0
# [1]  WMMA.LOAD R4, [R0+4]
# [2]  WMMA.LOAD R8, [R0+8]
# [3]  WMMA.LOAD R0, [R0+0]
# [4]  WMMA.MMA R12, R0, R4, R8
# [5]  MOVI R0, 0
# [6]  MAX.f R12, R12, R0
# [7]  MAX.f R13, R13, R0
# [8]  MAX.f R14, R14, R0
# [9]  MAX.f R15, R15, R0
# [10] MOVI R0, 0
# [11] WMMA.STORE R12, [R0+0]
# [12] RET

GPU_0=0x20000000  # MOVI R0,0
GPU_1=0xF0400004  # WMMA.LOAD R4
GPU_2=0xF0800008  # WMMA.LOAD R8
GPU_3=0xF0000000  # WMMA.LOAD R0
GPU_4=0xECC04800  # WMMA.MMA
GPU_5=0x20000000  # MOVI R0,0
GPU_6=0x54CC0000  # MAX.f R12
GPU_7=0x54DD0000  # MAX.f R13
GPU_8=0x54EE0000  # MAX.f R14
GPU_9=0x54FF0000  # MAX.f R15
GPU_A=0x20000000  # MOVI R0,0
GPU_B=0xF8C00000  # WMMA.STORE
GPU_C=0xC8000000  # RET

# ================================================================
#  ARM Firmware
#  Total: 80 instrs = 40 DWs
# ================================================================
ARM_NOP=0xE1A00000
ARM_HALT=0xEAFFFFFE

# ARM helpers
arm_mov() { printf "0x%08X" $(( 0xE3A00000 | ($1 << 12) | ($2 & 0xFF) )); }
arm_mcr() { printf "0x%08X" $(( 0xEE000A10 | ($1 << 16) | ($2 << 12) )); }

# ================================================================
#  Build and inject packet
# ================================================================
echo "================================================================"
echo "  FC Layer Inference: y = ReLU(W * X + B)"
echo "  W = Identity, X = [2, 3, 0, -1], B = 0"
echo "  Expected: [2.0, 3.0, 0, 0] per bank"
echo "================================================================"
echo ""

# 1. Set mux to register injection, clear state
echo "[1] Setting up register injection mode..."
wr $SW_CMD 0x6   # mux_sel=1 | clear=1
wr $SW_CMD 0x2   # mux_sel=1, release clear

# 2. Push LOAD_IMEM command + ARM firmware (40 DWs)
echo "[2] Pushing ARM firmware (LOAD_IMEM)..."
# cmd: opcode=1, addr=0, count=40, param=0
# {4'h1, 12'h000, 16'd40, 32'h0} = 0x1000002800000000
push_word 0x10000028 0x00000000 0x04  # ctrl=0x04 (module header)

# Phase 1: D_IMEM [0..7] + 8 NOPs [8..15]
push_word $ARM_NOP     $(arm_mcr 0 0)   0x00  # [1]MCR CR0; [0]MOV R0,#0 -- wait, order
# Actually: DW packing is {instr[odd], instr[even]} = {HI, LO}
# instr[0] = LO = arm_mov(0,0) = E3A00000
# instr[1] = HI = arm_mcr(0,0) = EE000A10
push_word 0xEE000A10 0xE3A00000 0x00  # [1]MCR CR0,R0; [0]MOV R0,#0
push_word 0xE3A01010 0xEE010A10 0x00  # [3]MOV R1,#16; [2]MCR CR1,R0(=0)
push_word 0xEE021A10 0xE3A02005 0x00  # [5]MCR CR2,R1(=16); [4]MOV R2,#5
push_word $ARM_NOP   0xEE032A10 0x00  # [7]NOP; [6]MCR CR3,R2(=5→D_IMEM)
# NOPs [8..15] = 4 DWs
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00

# Phase 2: D_UNPACK [16..23] + 10 NOPs [24..33]
push_word 0xEE000A10 0xE3A00010 0x00  # [17]MCR CR0,R0; [16]MOV R0,#16
push_word 0xEE011A10 0xE3A01000 0x00  # [19]MCR CR1,R1; [18]MOV R1,#0
push_word 0xEE022A10 0xE3A02006 0x00  # [21]MCR CR2,R2; [20]MOV R2,#6
push_word 0xEE033A10 0xE3A03041 0x00  # [23]MCR CR3,R3; [22]MOV R3,#65(0x41)
# NOPs [24..33] = 5 DWs
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00

# Phase 3: GPU launch [34..39] + 10 NOPs [40..59]
push_word 0xEE040A10 0xE3A00000 0x00  # [35]MCR CR4,R0; [34]MOV R0,#0
push_word 0xEE071A10 0xE3A0100F 0x00  # [37]MCR CR7,R1; [36]MOV R1,#15
push_word 0xEE052A10 0xE3A02001 0x00  # [39]MCR CR5,R2; [38]MOV R2,#1
# NOPs [40..59] = 10 DWs
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00

# Phase 4: D_PACK [60..67] + 5 NOPs [68..77]
push_word 0xEE000A10 0xE3A00000 0x00  # [61]MCR CR0,R0; [60]MOV R0,#0(gpu src)
push_word 0xEE011A10 0xE3A01030 0x00  # [63]MCR CR1,R1; [62]MOV R1,#48(cpu dst)
push_word 0xEE022A10 0xE3A02002 0x00  # [65]MCR CR2,R2; [64]MOV R2,#2
push_word 0xEE033A10 0xE3A03043 0x00  # [67]MCR CR3,R3; [66]MOV R3,#67(0x43)
# NOPs [68..77] = 5 DWs
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00
push_word $ARM_NOP $ARM_NOP 0x00

# Phase 5: Halt [78..79]
push_word $ARM_NOP $ARM_HALT 0x00  # [79]NOP; [78]B .

echo "  40 DWs pushed (ARM firmware)"

# 3. Push LOAD_DMEM (GPU kernel at addr=0, count=8)
echo "[3] Pushing GPU kernel (LOAD_DMEM addr=0)..."
push_word 0x20000008 0x00000000 0x00  # cmd: {2, 0x000, 8, 0}

push_word $GPU_1 $GPU_0 0x00  # [1]WMMA.LD R4; [0]MOVI R0
push_word $GPU_3 $GPU_2 0x00  # [3]WMMA.LD R0; [2]WMMA.LD R8
push_word $GPU_5 $GPU_4 0x00  # [5]MOVI R0;    [4]WMMA.MMA
push_word $GPU_7 $GPU_6 0x00  # [7]MAX R13;    [6]MAX R12
push_word $GPU_9 $GPU_8 0x00  # [9]MAX R15;    [8]MAX R14
push_word $GPU_B $GPU_A 0x00  # [11]WMMA.ST;   [10]MOVI R0
push_word 0x00000000 $GPU_C 0x00  # [13]NOP; [12]RET
push_word 0x00000000 0x00000000 0x00  # [15]NOP; [14]NOP

echo "  8 DWs pushed (GPU kernel)"

# 4. Push LOAD_DMEM (matrix data at addr=16, count=12)
echo "[4] Pushing matrix data (LOAD_DMEM addr=16)..."
push_word 0x2001000C 0x00000000 0x00  # cmd: {2, 0x010, 12, 0}

# Bank 0: W[0]=[1,0,0,0] X[0]=[2,3,0,-1] B[0]=[0,0,0,0]
push_word 0x00000000 0x00003F80 0x00  # W: {0,0},{0,1.0}
push_word 0xBF800000 0x40404000 0x00  # X: {-1,0},{3.0,2.0}
push_word 0x00000000 0x00000000 0x00  # B: zero

# Bank 1: W[1]=[0,1,0,0]
push_word 0x00000000 0x3F800000 0x00  # W: {0,0},{1.0,0}
push_word 0xBF800000 0x40404000 0x00  # X: same
push_word 0x00000000 0x00000000 0x00  # B: zero

# Bank 2: W[2]=[0,0,1,0]
push_word 0x00003F80 0x00000000 0x00  # W: {0,1.0},{0,0}
push_word 0xBF800000 0x40404000 0x00  # X: same
push_word 0x00000000 0x00000000 0x00  # B: zero

# Bank 3: W[3]=[0,0,0,1]
push_word 0x3F800000 0x00000000 0x00  # W: {1.0,0},{0,0}
push_word 0xBF800000 0x40404000 0x00  # X: same
push_word 0x00000000 0x00000000 0x00  # B: zero

echo "  12 DWs pushed (matrix data)"

# 5. Push LOAD_DMEM (zero readback at addr=48, count=4)
echo "[5] Pushing zero readback area (LOAD_DMEM addr=48)..."
push_word 0x20300004 0x00000000 0x00  # cmd: {2, 0x030, 4, 0}
push_word 0x00000000 0x00000000 0x00
push_word 0x00000000 0x00000000 0x00
push_word 0x00000000 0x00000000 0x00
push_word 0x00000000 0x00000000 0x00

# 6. Push CPU_START
echo "[6] Pushing CPU_START..."
push_word 0x30000000 0x00000000 0x00  # cmd: {3, 0, 0, 0}

# 7. Push READBACK (addr=48, count=4)
echo "[7] Pushing READBACK..."
push_word 0x40300004 0x00000000 0x00  # cmd: {4, 0x030, 4, 0}

# 8. Push SEND_PKT
echo "[8] Pushing SEND_PKT..."
push_word 0x50000000 0x00000000 0x00  # cmd: {5, 0, 0, 0}

# ================================================================
#  Check buffer count, then drain
# ================================================================
echo ""
STATUS=$(rd $HW_STATUS)
echo "Buffer status before drain: $STATUS"
BUF_CNT=$(( (STATUS >> 8) & 0x3F ))
echo "  buf_count = $BUF_CNT words"

echo ""
echo "[9] Triggering drain..."
wr $SW_CMD 0xA   # mux_sel=1 | drain=1

# Wait for completion
sleep 2

# ================================================================
#  Read results
# ================================================================
echo ""
echo "================================================================"
echo "  Results"
echo "================================================================"
STATUS=$(rd $HW_STATUS)
echo "hw_status     = $STATUS"
TX_CNT=$(( (STATUS >> 16) & 0x3F ))
TX_DONE=$(( (STATUS >> 2) & 1 ))
DRAIN_DONE=$(( (STATUS >> 4) & 1 ))
echo "  tx_word_cnt = $TX_CNT"
echo "  tx_done     = $TX_DONE"
echo "  drain_done  = $DRAIN_DONE"

echo ""
W0_HI=$(rd $HW_TX_W0_HI)
W0_LO=$(rd $HW_TX_W0_LO)
W1_HI=$(rd $HW_TX_W1_HI)
W1_LO=$(rd $HW_TX_W1_LO)

echo "hw_tx_word0 (header)  = $W0_HI $W0_LO"
echo "hw_tx_word1 (bank0+1) = $W1_HI $W1_LO"

echo ""
echo "Expected tx_word1 (READBACK banks 0+1):"
echo "  bank0: ReLU([2,3,0,-1]) = [2,3,0,0]"
echo "  D_PACK: {DMEM[1],DMEM[0]} = {3.0,2.0} = 0x40404000"
echo "          {DMEM[3],DMEM[2]} = {0,0}     = 0x00000000"
echo "  TX[0] = {CPU[49],CPU[48]} = 0x00000000_40404000"
echo ""
echo "  Expected hw_tx_word1_hi = 0x00000000"
echo "  Expected hw_tx_word1_lo = 0x40404000"

if [ "$W1_HI" = "0x00000000" ] && [ "$W1_LO" = "0x40404000" ]; then
    echo ""
    echo "  *** PASS ***"
else
    echo ""
    echo "  *** FAIL ***"
    echo "  Got: hi=$W1_HI lo=$W1_LO"
fi
