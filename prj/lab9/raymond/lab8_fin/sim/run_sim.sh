#!/bin/bash
# ============================================================
# Run Network Processor simulation with Icarus Verilog (lab8_fin)
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/../src"
SIM="$SCRIPT_DIR"

echo "=== Compiling Network Processor Testbench (lab8_fin) ==="

iverilog -o "$SIM/network_processor_tb.vvp" \
    -I "$SIM" \
    -Wall \
    \
    "$SIM/glbl.v" \
    "$SIM/unisim_stub.v" \
    "$SIM/bram_sim.v" \
    "$SIM/MULT18X18S.v" \
    "$SIM/network_processor_tb.v" \
    \
    "$SRC/ARM_Processor_4T.v" \
    "$SRC/cpu_Control_Unit.v" \
    "$SRC/cpu_ALU.v" \
    "$SRC/Sign_Extend_12to64.v" \
    "$SRC/Mux2_1_64b.v" \
    "$SRC/Mux4_1_7b.v" \
    "$SRC/Register_File_BRAM.v" \
    "$SRC/busmerge4_2.v" \
    "$SRC/IF_ID_Reg.v" \
    "$SRC/ID_EX_Reg.v" \
    "$SRC/EX_M_Reg.v" \
    "$SRC/M_WB_Reg.v" \
    "$SRC/Flag_Reg.v" \
    "$SRC/Flag_Reg_4.v" \
    "$SRC/Condition_Unit.v" \
    "$SRC/Counter_2b.v" \
    "$SRC/PCL_7b.v" \
    "$SRC/PCL_7b_4.v" \
    "$SRC/dff2.v" \
    "$SRC/dff4.v" \
    "$SRC/dff12.v" \
    "$SRC/dff32.v" \
    "$SRC/dff64.v" \
    \
    "$SRC/gpu_top.v" \
    "$SRC/gpu_control_unit.v" \
    "$SRC/gpu_alu.v" \
    "$SRC/tensor_unit.v" \
    "$SRC/bf16_lane.v" \
    "$SRC/Register_file.v" \
    \
    "$SRC/convertible_fifo.v" \
    2>&1

echo "=== Running Simulation ==="
cd "$SIM"
vvp network_processor_tb.vvp 2>&1

echo ""
echo "=== VCD waveform: $SIM/network_processor_tb.vcd ==="
echo "    View with: gtkwave $SIM/network_processor_tb.vcd"
