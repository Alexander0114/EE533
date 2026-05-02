#!/bin/bash
# Compile and run soc_top integration testbench with Icarus Verilog
set -e

INTEG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TB_DIR="$INTEG_DIR/test"

echo "=== Compiling soc_top_tb ==="
iverilog -o "$TB_DIR/soc_top_tb.vvp" \
    -I "$INTEG_DIR/cpu" \
    -I "$INTEG_DIR/cpu/core" \
    -I "$INTEG_DIR/cpu/component" \
    -I "$INTEG_DIR/cpu/alu" \
    -I "$INTEG_DIR/cpu/mac" \
    -I "$INTEG_DIR/cpu/testmem" \
    -I "$INTEG_DIR/cpu/testdsp" \
    -I "$INTEG_DIR/network" \
    -I "$INTEG_DIR/gpu/core" \
    -I "$INTEG_DIR/gpu/arith" \
    -I "$INTEG_DIR/gpu/bram" \
    -I "$INTEG_DIR/gpu/sim" \
    -I "$INTEG_DIR/cp" \
    -I "$INTEG_DIR/soc" \
    -Wall \
    "$TB_DIR/soc_top_tb.v"

echo "=== Running simulation ==="
cd "$TB_DIR"
vvp soc_top_tb.vvp
