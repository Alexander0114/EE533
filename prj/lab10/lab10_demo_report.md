# Lab 10 Demo Report: FC Layer Inference on NetFPGA SoC

## Overview

We demonstrate a fully connected (FC) neural network layer inference running end-to-end on the NetFPGA SoC hardware. The computation is:

```
y = ReLU(W * X + B)
```

where W, X, B are 4x4 BF16 (Brain Float 16) matrices, processed by a 4x4 hardware tensor core.

---

## FC Layer Computation

### Input Matrices

**W (Weights)** = 4x4 Identity Matrix:

```
         col0   col1   col2   col3
       +------+------+------+------+
row 0  |  1.0 |    0 |    0 |    0 |  <- Thread 0 (GPU Bank 0)
       +------+------+------+------+
row 1  |    0 |  1.0 |    0 |    0 |  <- Thread 1 (GPU Bank 1)
       +------+------+------+------+
row 2  |    0 |    0 |  1.0 |    0 |  <- Thread 2 (GPU Bank 2)
       +------+------+------+------+
row 3  |    0 |    0 |    0 |  1.0 |  <- Thread 3 (GPU Bank 3)
       +------+------+------+------+

BF16:   3F80   0000   0000   0000
        0000   3F80   0000   0000
        0000   0000   3F80   0000
        0000   0000   0000   3F80
```

**X (Input)** = Same input vector replicated across all rows:

```
         col0   col1   col2   col3
       +------+------+------+------+
row 0  |  2.0 |  3.0 |    0 | -1.0 |
       +------+------+------+------+
row 1  |  2.0 |  3.0 |    0 | -1.0 |
       +------+------+------+------+
row 2  |  2.0 |  3.0 |    0 | -1.0 |
       +------+------+------+------+
row 3  |  2.0 |  3.0 |    0 | -1.0 |
       +------+------+------+------+

BF16:   4000   4040   0000   BF80
        4000   4040   0000   BF80
        4000   4040   0000   BF80
        4000   4040   0000   BF80
```

**B (Bias)** = Zero:

```
         col0   col1   col2   col3
       +------+------+------+------+
       |    0 |    0 |    0 |    0 |
       +------+------+------+------+
       |    0 |    0 |    0 |    0 |
       +------+------+------+------+
       |    0 |    0 |    0 |    0 |
       +------+------+------+------+
       |    0 |    0 |    0 |    0 |
       +------+------+------+------+
```

### Step 1: Matrix Multiply (D = W * X + B)

```
         col0   col1   col2   col3
       +------+------+------+------+
row 0  |  2.0 |  3.0 |    0 | -1.0 |   W[0,:] . X[:,j] = X[0,j]
       +------+------+------+------+
row 1  |  2.0 |  3.0 |    0 | -1.0 |   W[1,:] . X[:,j] = X[1,j]
       +------+------+------+------+
row 2  |  2.0 |  3.0 |    0 | -1.0 |   W[2,:] . X[:,j] = X[2,j]
       +------+------+------+------+
row 3  |  2.0 |  3.0 |    0 | -1.0 |   W[3,:] . X[:,j] = X[3,j]
       +------+------+------+------+

(Identity * X + 0 = X)
```

### Step 2: ReLU Activation (Y = max(D, 0))

```
         col0   col1   col2   col3
       +------+------+------+------+
row 0  |  2.0 |  3.0 |    0 |    0 |   -1.0 clamped to 0
       +------+------+------+------+
row 1  |  2.0 |  3.0 |    0 |    0 |   -1.0 clamped to 0
       +------+------+------+------+
row 2  |  2.0 |  3.0 |    0 |    0 |   -1.0 clamped to 0
       +------+------+------+------+
row 3  |  2.0 |  3.0 |    0 |    0 |   -1.0 clamped to 0
       +------+------+------+------+

BF16:   4000   4040   0000   0000
        4000   4040   0000   0000
        4000   4040   0000   0000
        4000   4040   0000   0000
```

---

## Hardware Architecture

```
    Host PC                          NetFPGA (Virtex-II Pro)
  +-----------+                    +----------------------------------+
  |           |   regwrite/read    |  soc_netfpga                     |
  |  socreg   |<=================>|  +------------------------------+ |
  |  (Perl)   |   PCI registers   |  |  Injection     TX Snoop     | |
  |           |                    |  |  Buffer -----> hw_tx_word   | |
  +-----------+                    |  +------|-----------^-----------+ |
                                   |         | drain     | capture    |
                                   |         v           |            |
                                   |  +-------------------------------+
                                   |  |  SoC                          |
                                   |  |                               |
                                   |  |  pkt_proc --> CPU IMEM/DMEM   |
                                   |  |                  |            |
                                   |  |            ARM CPU (4-thread) |
                                   |  |              |         |      |
                                   |  |          DMA Engine   CP10    |
                                   |  |           |      |            |
                                   |  |     +-----+------+-----+     |
                                   |  |     |                   |     |
                                   |  |  GPU IMEM           GPU DMEM  |
                                   |  |     |             (4 banks)   |
                                   |  |     v                   |     |
                                   |  |  SIMT GPU (4 threads)   |     |
                                   |  |  +-------------------+  |     |
                                   |  |  | SP0  SP1  SP2 SP3 |  |     |
                                   |  |  | 16   16   16  16  |  |     |
                                   |  |  | regs regs regs regs| |     |
                                   |  |  |                   |  |     |
                                   |  |  | 4x4 Tensor Core   |  |     |
                                   |  |  | (BF16 WMMA)       |  |     |
                                   |  |  +-------------------+  |     |
                                   |  +-------------------------------+
                                   +----------------------------------+
```

---

## GPU Kernel Assembly

13 instructions executing on all 4 SIMT threads simultaneously:

```
PC  Instruction              Register State After
--  -----------------------  -----------------------------------
 0  MOVI R0, 0               R0 = 0 (base address)

 1  WMMA.LOAD R4, [R0+4]     R4-R7  = X row from DMEM[4..7]
 2  WMMA.LOAD R8, [R0+8]     R8-R11 = B row from DMEM[8..11]
 3  WMMA.LOAD R0, [R0+0]     R0-R3  = W row from DMEM[0..3]

 4  WMMA.MMA R12,R0,R4,R8    Tensor core: D = W * X + B
                              R12-R15 = result row

 5  MOVI R0, 0               R0 = 0 (for ReLU comparison)
 6  MAX.f R12, R12, R0       R12 = max(R12, 0)
 7  MAX.f R13, R13, R0       R13 = max(R13, 0)
 8  MAX.f R14, R14, R0       R14 = max(R14, 0)
 9  MAX.f R15, R15, R0       R15 = max(R15, 0)

10  MOVI R0, 0               R0 = 0 (store base address)
11  WMMA.STORE R12, [R0+0]   DMEM[0..3] = R12-R15

12  RET                       Kernel done
```

### Register Allocation (per thread)

```
R0  R1  R2  R3    W row (4 weights)       loaded last (R0 reused as base)
R4  R5  R6  R7    X row (4 inputs)        loaded first
R8  R9  R10 R11   B row (4 biases)        loaded second
R12 R13 R14 R15   D row (4 outputs)       WMMA result, then ReLU
                   ---- all 16 registers used ----
```

---

## Data Flow Through Hardware

### Phase 1: Host Injects Packet (60 words via register interface)

```
+-------------------+     +-------------------+     +------------------+
| ARM Firmware      |     | GPU Kernel        |     | Matrix Data      |
| (29 DWs)          |     | (8 DWs)           |     | (12 DWs)         |
|                   |     |                   |     |                  |
| D_IMEM setup      |     | MOVI, WMMA.LOAD   |     | Bank 0: W,X,B   |
| D_UNPACK setup    |     | WMMA.MMA          |     | Bank 1: W,X,B   |
| GPU launch        |     | MAX.f (ReLU)      |     | Bank 2: W,X,B   |
| D_PACK readback   |     | WMMA.STORE, RET   |     | Bank 3: W,X,B   |
| Halt              |     |                   |     |                  |
+-------------------+     +-------------------+     +------------------+
        |                          |                         |
        +----------+---------------+-----------+-------------+
                   |                           |
                   v                           v
            +-------------+             +-------------+
            | CPU IMEM    |             | CPU DMEM    |
            | (firmware)  |             | (kernel +   |
            |             |             |  matrices)  |
            +-------------+             +-------------+
```

### Phase 2: CPU Orchestrates DMA + GPU

```
CPU DMEM                    DMA Engine                  GPU
+--------+                                         +---------+
|[0..15] | ---D_IMEM (16 words)-----------------> | GPU IMEM|
| kernel |    (32-bit 1:1 copy)                    | 13 instr|
+--------+                                         +---------+
|[16..21]| ---D_UNPACK burst_all (xfer=6)-------> | Bank 0  |
| bank 0 |    (32-bit -> 2x16-bit)                 | DMEM    |
| W,X,B  |                                         | W,X,B   |
+--------+                                         +---------+
|[22..27]| ----------------------------------------> | Bank 1  |
| bank 1 |                                         +---------+
+--------+                                         | Bank 2  |
|[28..33]| ----------------------------------------> +---------+
| bank 2 |                                         | Bank 3  |
+--------+                                         +---------+
|[34..39]| ---------------------------------------->
| bank 3 |
+--------+
```

### Phase 3: GPU Executes Kernel

```
Each thread loads its row from its DMEM bank:

Thread 0 (Bank 0):  W=[1,0,0,0]  X=[2,3,0,-1]  B=[0,0,0,0]
Thread 1 (Bank 1):  W=[0,1,0,0]  X=[2,3,0,-1]  B=[0,0,0,0]
Thread 2 (Bank 2):  W=[0,0,1,0]  X=[2,3,0,-1]  B=[0,0,0,0]
Thread 3 (Bank 3):  W=[0,0,0,1]  X=[2,3,0,-1]  B=[0,0,0,0]

            WMMA.MMA (4x4 tensor core)
                     |
                     v
     D = W * X + B = I * X + 0 = X

     +------+------+------+------+
     |  2.0 |  3.0 |    0 | -1.0 |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 | -1.0 |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 | -1.0 |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 | -1.0 |
     +------+------+------+------+

            MAX.f with 0 (ReLU)
                     |
                     v
     +------+------+------+------+
     |  2.0 |  3.0 |    0 |  >>> 0 <<<  |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 |    0 |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 |    0 |
     +------+------+------+------+
     |  2.0 |  3.0 |    0 |    0 |
     +------+------+------+------+
                                    -1.0 clamped to 0 by ReLU
```

### Phase 4: Results Return to Host

```
GPU DMEM           DMA D_PACK              CPU DMEM         TX Output
+---------+        (2x16 -> 32)           +----------+
| Bank 0  |  {3.0,2.0}=0x40404000  ----> | CPU[32]  |---+
| [2,3,0,0]  {0,0}=0x00000000      ----> | CPU[33]  |   |
+---------+                               +----------+   |
| Bank 1  |  {3.0,2.0}=0x40404000  ----> | CPU[34]  |   |  READBACK
| [2,3,0,0]  {0,0}=0x00000000      ----> | CPU[35]  |   |  packs into
+---------+                               +----------+   |  TX words
| Bank 2  |                         ----> | CPU[36]  |   |
+---------+                               +----------+   |
| Bank 3  |                         ----> | CPU[38]  |   |
+---------+                               +----------+   |
                                                          v
                                          TX[0] = {CPU[33],CPU[32]}
                                                = 0x00000000_40404000
                                          TX[1] = {CPU[35],CPU[34]}
                                                = 0x00000000_40404000
```

---

## Hardware Test Results

```
============================================================
  FC: y = ReLU(W*X+B), W=I, X=[2,3,0,-1]
============================================================

  [DRAIN] 56 words
  [POLL] done @ 1
  TX[0]=00000000_40404000 TX[1]=00000000_40404000
  [PASS] FC TX[0]={0,40404000}
  [PASS] FC TX[1]={0,40404000}

==================================================
  PASSED: 2  FAILED: 0  TOTAL: 2
==================================================
>>> ALL TESTS PASSED <<<
```

### Result Decode

```
TX[0] = 0x00000000_40404000

  Low  32 bits: 0x40404000 = {BF16 hi, BF16 lo} = {0x4040, 0x4000}
                             = {3.0, 2.0}  --> Y[row][0]=2.0, Y[row][1]=3.0

  High 32 bits: 0x00000000 = {BF16 hi, BF16 lo} = {0x0000, 0x0000}
                             = {0, 0}      --> Y[row][2]=0, Y[row][3]=0

  Result: Y = [2.0, 3.0, 0, 0]  CORRECT
```

---

## Test Environment

- **FPGA**: Xilinx Virtex-II Pro XC2VP50 on NetFPGA 1G
- **Bitstream**: Jeremy's lab9 synthesis (soc_netfpga + SIMT GPU + tensor core)
- **Test script**: `perl socreg fc` (register-based packet injection)
- **Simulation**: `fc_layer_tb.v` — 5/5 checks pass (iverilog)
- **Golden model**: `fc_host.py` — numpy verification

## Resource Usage (from synthesis)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| Slices | ~14,000 | 23,616 | ~59% |
| RAMB16 | 115 | 232 | 49% |
| MULT18X18 | 24 | 232 | 10% |
| IOBs | 356 | 692 | 51% |

## Key Design Components

| Component | Description |
|-----------|-------------|
| ARM CPU | 4-thread FGMT barrel processor, 7-stage pipeline |
| SIMT GPU | 4-thread, 16 regs/thread, WMMA/MAX/LD/ST instructions |
| Tensor Core | 4x4 BF16 systolic array, D=A*B+C |
| DMA Engine | D_IMEM, D_UNPACK (32->2x16), D_PACK (2x16->32) |
| CP10 | 10 coprocessor registers bridging CPU to DMA + GPU |
| Packet Proc | Command parser (LOAD_IMEM/DMEM, CPU_START, READBACK, SEND_PKT) |
