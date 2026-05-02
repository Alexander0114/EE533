# Lab 7 — SIMD GPU on NetFPGA

USC EE533 — Custom SIMD GPU core targeting Xilinx NetFPGA.

## Architecture

```
                 ┌──────────┐
 program.hex ──► │   IMEM   │──── instruction ──┐
                 │(1024x32) │                    │
                 └──────────┘                    ▼
                      ▲              ┌──────────────────┐
                      │ pc           │  CONTROL UNIT    │
                      │              │  (FSM + decoder) │
                      │              └──────┬───────────┘
                      │                     │ control signals
                 ┌────┴─────────────────────┼──────────────┐
                 │            gpu_top       ▼              │
                 │  ┌──────────┐  ┌─────┐  ┌───────────┐  │
                 │  │ Reg File │─►│ ALU │  │  Tensor   │  │
                 │  │ (32x64)  │─►│(x4  │  │  Unit (x4 │  │
                 │  │  3R/1W   │─►│int16│  │  BF16)    │  │
                 │  └──────────┘  └──┬──┘  └─────┬─────┘  │
                 │       ▲           │           │         │
                 │       └───────────┴───────────┘         │
                 │            Writeback Mux                │
                 │  ┌──────────┐       │                   │
                 │  │   DMEM   │───────┘                   │
                 │  │(1024x64) │                           │
                 │  └──────────┘                           │
                 └─────────────────────────────────────────┘
```

- **Execution model**: Multi-cycle FSM, one instruction at a time (no pipelining)
- **Register file**: 32 x 64-bit registers, 3 read / 1 write ports. R0 = hardwired zero
- **ALU**: 4 parallel int16 lanes (VADD, VSUB, VAND, VOR, VXOR, VSLT)
- **Tensor unit**: 4 BF16 lanes with 4-cycle pipeline (ADD, MUL, FMA, optional ReLU)
- **Memories**: IMEM 1024x32-bit (instructions), DMEM 1024x64-bit (data) — Xilinx BRAM

## ISA Summary

### Instruction Encoding (32-bit)

```
R-TYPE: [opcode(5)][rd(5)][ra(5)][rb(5)][rc(5)][func(4)][mode(3)]
I-TYPE: [opcode(5)][rd(5)][ra(5)][imm17(17)]
```

### Opcodes

| Opcode | Mnemonic | Type | Operation |
|--------|----------|------|-----------|
| 0x00 | VADD/VSUB/VAND/VOR/VXOR/VSLT | R | 4-lane int16 ALU (func selects op) |
| 0x01 | TENSOR_ADD/MUL/FMA[_RELU] | R | 4-lane BF16 (mode selects op, func[0]=relu) |
| 0x02 | LD Rd, Ra, imm | I | Rd = dmem[Ra + sign_ext(imm17)] |
| 0x03 | ST Rd, Ra, imm | I | dmem[Ra + sign_ext(imm17)] = Rd |
| 0x04 | BEQ Rd, Ra, off | I | Branch if Rd == Ra |
| 0x05 | BNE Rd, Ra, off | I | Branch if Rd != Ra |
| 0x06 | BLT Rd, Ra, off | I | Branch if signed(Rd < Ra) |
| 0x07 | BGE Rd, Ra, off | I | Branch if signed(Rd >= Ra) |
| 0x08 | LUI Rd, imm | I | Rd = imm17 << 47 |
| 0x09 | ADDI Rd, Ra, imm | I | Rd = Ra + sign_ext(imm17) |
| 0x0A | HALT | — | Stop execution |
| 0x0B | NOP | — | No operation |
| 0x0C | MOVI Rd, imm | I | Rd = sign_ext(imm17) |
| 0x0D | RELU_INT Rd, Ra | R | Rd[i] = max(0, Ra[i]) per int16 lane |
| 0x0E | VBCAST Rd, Ra, lane | R | Broadcast Ra[lane] to all 4 lanes of Rd |

### Lane Mapping

VBCAST lane index: lane 0 = bits[63:48] (MSB), lane 3 = bits[15:0] (LSB).
MOVI places the immediate in bits[15:0], so use **lane 3** to broadcast a MOVI value.

## Control Unit FSM

```
IDLE ──► INIT ──► FETCH ──► FETCH2 ──► DECODE ──► EXECUTE ─┐
                    ▲                                       │
                    │         ┌──────────────────────────────┤
                    │         ▼                              ▼
                    │    TENSOR_WAIT ──(done)──►       WRITEBACK ──► FETCH
                    │         (loops on !done)               │
                    │    MEM_RD (OP_LD only) ───────────────►┘
                    │
                    ├── Branches/NOP: skip WRITEBACK, return to FETCH
                    └── HALTED_ST: terminal (halted=1)
```

- **FETCH2**: extra cycle for BRAM read latency
- **TENSOR_WAIT**: waits for BF16 pipeline completion (4 cycles)
- **MEM_RD**: extra cycle for DMEM read latency

## Directory Structure

```
lab7/
├── src/            RTL Verilog source (FPGA versions with ext memory ports)
│   ├── gpu_top.v           Top-level GPU (with ARM ext access ports)
│   ├── control_unit.v      FSM + instruction decoder
│   ├── alu.v               4-lane int16 vector ALU
│   ├── tensor_unit.v       4x BF16 lane wrapper
│   ├── bf16_lane.v         Single BF16 pipeline (4-cycle, ADD/MUL/FMA + ReLU)
│   ├── Register_file.v     32x64-bit, 3R/1W
│   ├── dmem.v              Data memory (Xilinx BRAM, 1024x64)
│   ├── imem.v              Instruction memory (Xilinx BRAM, 1024x32)
│   ├── gpu_wrapper.v       NetFPGA register interface wrapper
│   ├── user_data_path.v    NetFPGA top-level data path
│   └── MULT18X18S.v        Xilinx hard multiplier primitive
├── sim/            Simulation-only variants (simple memory models)
│   ├── gpu_top_sim.v       GPU top without ext ports (for Icarus/Verilator)
│   ├── dmem_sim.v          Simple behavioral DMEM
│   └── imem_sim.v          Simple behavioral IMEM
├── tb/             Testbenches
│   ├── gpu_top_tb.v        Comprehensive GPU testbench
│   ├── bf16_lane_tb.v      BF16 lane unit test
│   └── debug_tb.v          Minimal debug testbench
├── tools/          Assembler and data generation
│   ├── assembler.py        Assembler: .asm → .hex
│   └── gen_data.py         Data hex generator + expected output printer
├── sw/             FPGA control scripts
│   ├── gpureg              Perl script: load/run/dump GPU via NetFPGA regs
│   ├── cpureg              CPU register access script
│   └── idsreg              ID/status register script
├── asm/            Assembly source files
│   ├── test_all.asm        Comprehensive test (all instructions)
│   ├── test_basic.asm      Basic VADD + BF16_MUL test
│   └── test_program_fixed.asm  6-kernel verification test (disassembled)
├── hex/            Machine code and data files
│   ├── test_program_fixed.hex  Main test program (VBCAST lane 3 fix)
│   ├── test_program.hex        Original test (VBCAST lane 0 bug)
│   └── ...                     Other test/data hex files
├── doc/            Documentation
│   ├── lab7.pdf            Lab assignment
│   ├── architecture.txt    GPU architecture walkthrough
│   ├── instructions.txt    ISA reference
│   └── README_gpureg       gpureg usage guide
├── include/        NetFPGA config and register definitions
│   ├── registers.v         Auto-generated register address defines
│   └── gpu.xml             GPU register block XML descriptor
├── bram/           BRAM COE initialization files
│   ├── dmem.coe / imem.coe
│   └── dmem_bram.v / imem_bram.v
└── test_expected.txt   Expected outputs for 6-kernel test
```

## Quick Start

### Assemble a program

```bash
cd tools/
python3 assembler.py ../asm/test_all.asm -o ../hex/program.hex
```

### Simulate (Icarus Verilog)

```bash
# Use sim/ variants for simulation (simple memory models)
iverilog -o gpu_top_tb.vvp sim/gpu_top_sim.v sim/dmem_sim.v sim/imem_sim.v \
    src/control_unit.v src/alu.v src/tensor_unit.v src/bf16_lane.v \
    src/Register_file.v src/MULT18X18S.v tb/gpu_top_tb.v
vvp gpu_top_tb.vvp
```

### Run on FPGA

```bash
cd /mnt/e/sharedir/lab7/netfpga/projects/lab7/sw/
./gpureg stop
./gpureg load <path>/hex/test_program_fixed.hex
./gpureg run
./gpureg status          # should show "halted"
./gpureg dump 0 6        # read 6 DMEM words starting at addr 0
```

### Expected results (6-kernel test)

| DMEM Addr | Kernel | Expected Value | Computation |
|-----------|--------|----------------|-------------|
| 0 | VADD (int16) | `0008000800080008` | {3+5} x 4 = {8,8,8,8} |
| 1 | VSUB (int16) | `000D000D000D000D` | {20-7} x 4 = {13,13,13,13} |
| 2 | BF16 MUL | `40C040C040C040C0` | 2.0 * 3.0 = 6.0 x 4 |
| 3 | BF16 FMA | `40E040E040E040E0` | 2.0 * 3.0 + 1.0 = 7.0 x 4 |
| 4 | ReLU int16 | `0000000000000000` | max(0, -5) = 0 x 4 |
| 5 | ReLU BF16 | `0000000000000000` | ReLU(-2.0) = 0.0 x 4 |

## GPU Register Map (NetFPGA, base 0x2000100)

| Offset | Register | Description |
|--------|----------|-------------|
| +0x00 | IMEM_ADDR | Instruction memory write address |
| +0x04 | IMEM_DATA | Instruction memory write data |
| +0x08 | DMEM_ADDR | Data memory address |
| +0x0C | DMEM_WR_DATA_LO | DMEM write data [31:0] |
| +0x10 | DMEM_WR_DATA_HI | DMEM write data [63:32] |
| +0x14 | GPU_CTRL | [0]=reset [1]=run [2]=imem_we [3]=dmem_we |
| +0x18 | CURRENT_PC | Current program counter |
| +0x1C | DMEM_RD_DATA_LO | DMEM read data [31:0] |
| +0x20 | DMEM_RD_DATA_HI | DMEM read data [63:32] |
| +0x24 | CYCLE_COUNTS | Cycle counter |
| +0x28 | GPU_STATUS | [4]=halted [3:0]=FSM state |

## Known Issues

1. **VBCAST lane mapping**: MOVI loads imm into bits[15:0] (lane 3 in RTL), so VBCAST
   must use lane 3 to broadcast. Original test used lane 0 (broadcasting zeros).
   Fixed in `test_program_fixed.hex`.

2. **FETCH timing (off-by-one)**: IR is latched in FETCH but BRAM output is not valid
   until FETCH2. First instruction executes twice, subsequent instructions are off-by-one.
   Non-blocking for straight-line code; would break branch-heavy programs.
   Fix: move `IR <= instruction` from FETCH to FETCH2.
