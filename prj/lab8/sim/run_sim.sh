#!/bin/bash
# ============================================================
# Run Network Processor simulation with Icarus Verilog
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB8="$SCRIPT_DIR/.."
SIM="$SCRIPT_DIR"
CPU="$LAB8/cpu"
FIFO="$LAB8/fifo"
GPU_SRC="$LAB8/gpu/src"

echo "=== Compiling Network Processor Testbench ==="

iverilog -o "$SIM/network_processor_tb.vvp" \
    -I "$SIM" \
    -Wall \
    \
    "$SIM/glbl.v" \
    "$SIM/unisim_stub.v" \
    "$SIM/bram_sim.v" \
    "$SIM/network_processor_tb.v" \
    \
    "$CPU/ARM_Processor_4T.v" \
    "$CPU/Control_Unit.v" \
    "$CPU/ALU.v" \
    "$CPU/Sign_Extend_12to64.v" \
    "$CPU/Mux2_1_64b.v" \
    "$CPU/Mux4_1_7b.v" \
    "$CPU/Register_File_BRAM.v" \
    "$CPU/busmerge4_2.v" \
    "$CPU/IF_ID_Reg.v" \
    "$CPU/ID_EX_Reg.v" \
    "$CPU/EX_M_Reg.v" \
    "$CPU/M_WB_Reg.v" \
    "$CPU/Flag_Reg.v" \
    "$CPU/Flag_Reg_4.v" \
    "$CPU/Condition_Unit.v" \
    "$CPU/Counter_2b.v" \
    "$CPU/PCL_7b.v" \
    "$CPU/PCL_7b_4.v" \
    "$CPU/dff2.v" \
    "$CPU/dff4.v" \
    "$CPU/dff12.v" \
    "$CPU/dff32.v" \
    "$CPU/dff64.v" \
    \
    "$GPU_SRC/gpu_top.v" \
    "$GPU_SRC/control_unit.v" \
    "$GPU_SRC/alu.v" \
    "$GPU_SRC/tensor_unit.v" \
    "$GPU_SRC/bf16_lane.v" \
    "$GPU_SRC/Register_file.v" \
    "$GPU_SRC/MULT18X18S.v" \
    \
    "$FIFO/convertible_fifo.v" \
    2>&1

echo "=== Running Simulation ==="
cd "$SIM"
vvp network_processor_tb.vvp 2>&1

echo ""
echo "=== VCD waveform: $SIM/network_processor_tb.vcd ==="
echo "    View with: gtkwave $SIM/network_processor_tb.vcd"
