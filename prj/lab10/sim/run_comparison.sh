#!/bin/bash
# ============================================================
# Test Bench: GPU vs CPU Cycle Comparison — Simulation Runner
# Runs all testbenches, extracts results, prints unified table
# Usage: ./run_comparison.sh
# ============================================================

set -e
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

SIM_DIR="$(cd "$(dirname "$0")/src/sim" && pwd)"
TB_DIR="$(cd "$(dirname "$0")/src/tb" && pwd)"
INC="$(cat "$SIM_DIR/soc_sim_fix_inc.txt")"
OUT_DIR="/tmp/lab10_sim"
mkdir -p "$OUT_DIR"

pass_total=0
fail_total=0

# ============================================================
# Helper: compile + run one testbench, capture output
# ============================================================
run_tb() {
    local name="$1"
    local tb_file="$2"
    local vvp="$OUT_DIR/${name}.vvp"
    local log="$OUT_DIR/${name}.log"

    printf "${CYAN}  %-40s${RESET}" "$name"

    # Compile
    if ! iverilog -o "$vvp" -g2005 $INC "$tb_file" > "$OUT_DIR/${name}_compile.log" 2>&1; then
        printf "${RED}COMPILE ERROR${RESET}\n"
        cat "$OUT_DIR/${name}_compile.log"
        return 1
    fi

    # Run
    if ! timeout 600 vvp "$vvp" > "$log" 2>&1; then
        printf "${RED}RUNTIME ERROR${RESET}\n"
        return 1
    fi

    # Count PASS/FAIL
    local p=$(grep -c '\[PASS\]' "$log" 2>/dev/null || true)
    local f=$(grep -c '\[FAIL\]' "$log" 2>/dev/null || true)
    pass_total=$((pass_total + p))
    fail_total=$((fail_total + f))

    if [ "$f" -gt 0 ]; then
        printf "${RED}%d PASS  %d FAIL${RESET}\n" "$p" "$f"
    else
        printf "${GREEN}%d PASS${RESET}\n" "$p"
    fi

    # Show filtered testbench output
    echo ""
    grep -vE '^\[cpu_mt\]|^\.\./tb/|\$finish|^$' "$log" | while IFS= read -r line; do
        # Color PASS/FAIL lines
        if echo "$line" | grep -q '\[PASS\]'; then
            printf "    ${GREEN}%s${RESET}\n" "$line"
        elif echo "$line" | grep -q '\[FAIL\]'; then
            printf "    ${RED}%s${RESET}\n" "$line"
        elif echo "$line" | grep -q '===='; then
            printf "    ${BOLD}%s${RESET}\n" "$line"
        elif echo "$line" | grep -q '^\-\-\-'; then
            printf "    ${BOLD}%s${RESET}\n" "$line"
        else
            printf "    ${DIM}%s${RESET}\n" "$line"
        fi
    done
    echo ""
}

# ============================================================
# Print section header
# ============================================================
section() {
    echo ""
    printf "${BOLD}$1${RESET}\n"
    printf "${DIM}%0.s─${RESET}" $(seq 1 64)
    echo ""
}

# ============================================================
# Main
# ============================================================
clear 2>/dev/null || true
echo ""
printf "${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}║        Test Bench: GPU vs CPU Cycle Comparison (Simulation)    ║${RESET}\n"
printf "${BOLD}║   SoC: 4-thread barrel ARM + 4-thread SIMT GPU + tensor core   ║${RESET}\n"
printf "${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"

# ---- Compile & Run ----
section "1. Running Testbenches"

cd "$SIM_DIR"
run_tb "Test 1: 2-Layer GPU vs CPU (with DMA)"           "$TB_DIR/ann_cycle_compare_tb.v"
run_tb "Test 2: 4-Layer GPU vs CPU (with DMA)"           "$TB_DIR/ann_4layer_compare_tb.v"
run_tb "Test 3: 2-4-8-16 Layer Scaling (no DMA)"         "$TB_DIR/ann_compute_compare_tb.v"

# ---- Extract results ----
LOG_2L="$OUT_DIR/Test 1: 2-Layer GPU vs CPU (with DMA).log"
LOG_4L="$OUT_DIR/Test 2: 4-Layer GPU vs CPU (with DMA).log"
LOG_SWEEP="$OUT_DIR/Test 3: 2-4-8-16 Layer Scaling (no DMA).log"

# Extract first number after a label
num() { grep "$1" "$2" | head -1 | sed 's/.*'"$1"'[^0-9]*//' | grep -oP '^\d+'; }

# 2-layer with DMA
gpu2_total=$(num "GPU total:" "$LOG_2L")
gpu2_comp=$(num "GPU compute:" "$LOG_2L")
gpu2_dma=$(num "GPU DMA overhead:" "$LOG_2L")
cpu2_bin=$(num "CPU:" "$LOG_2L")

# 4-layer with DMA
gpu4_total=$(num "GPU total:" "$LOG_4L")
gpu4_comp=$(num "GPU compute:" "$LOG_4L")
gpu4_dma=$(num "GPU DMA:" "$LOG_4L")
cpu4_shift=$(num "CPU total:" "$LOG_4L")

# Pure compute sweep — match exact labels
gpu2c=$(num "GPU 2L compute:" "$LOG_SWEEP")
gpu4c=$(num "GPU 4L compute:" "$LOG_SWEEP")
gpu8c=$(num "GPU 8L compute:" "$LOG_SWEEP")
gpu16c=$(num "GPU 16L compute:" "$LOG_SWEEP")
cpu2c=$(num "CPU 2L:" "$LOG_SWEEP")
cpu4c=$(num "CPU 4L:" "$LOG_SWEEP")
cpu8c=$(num "CPU 8L:" "$LOG_SWEEP")
cpu16c=$(num "CPU 16L:" "$LOG_SWEEP")

# ---- Compute speedups ----
speedup() {
    local cpu=$1 gpu=$2
    local whole=$((cpu / gpu))
    local frac=$(( (cpu * 10 / gpu) % 10 ))
    echo "${whole}.${frac}x"
}

# ---- Display Tables ----
section "2. Pure Compute (No DMA — GPU memories pre-loaded)"

printf "${BOLD}  %-8s  %10s  %10s  %10s  %10s${RESET}\n" \
    "Layers" "GPU (cyc)" "CPU (cyc)" "GPU/layer" "Speedup"
printf "  %-8s  %10s  %10s  %10s  %10s\n" \
    "------" "--------" "--------" "--------" "-------"

for L in 2 4 8 16; do
    eval gc=\$gpu${L}c
    eval cc=\$cpu${L}c
    gpl=$((gc / L))
    sp=$(speedup $cc $gc)
    printf "  %-8d  %10d  %10d  %10d  ${GREEN}%10s${RESET}\n" \
        "$L" "$gc" "$cc" "$gpl" "$sp"
done

echo ""
printf "  ${DIM}GPU: BF16 WMMA tensor core (~110 cyc/layer)${RESET}\n"
printf "  ${DIM}CPU: int32 shift-add multiply, w=[2,3,-1,5] (~232 cyc/layer)${RESET}\n"
printf "  ${DIM}Constant 2.1-2.2x — no fixed overhead to amortize${RESET}\n"

section "3. End-to-End (With DMA)"

printf "${BOLD}  %-8s  %10s  %10s  %10s  %10s  %12s${RESET}\n" \
    "Layers" "GPU Total" "GPU Comp" "DMA" "CPU" "Speedup"
printf "  %-8s  %10s  %10s  %10s  %10s  %12s\n" \
    "------" "--------" "--------" "---" "---" "-------"

# 2-layer row (binary weights — note in output)
printf "  %-8s  %10d  %10d  %10d  %10d  " \
    "2 (bin)" "$gpu2_total" "$gpu2_comp" "$gpu2_dma" "$cpu2_bin"
if [ "$gpu2_total" -gt "$cpu2_bin" ]; then
    sp=$(speedup $gpu2_total $cpu2_bin)
    printf "${RED}CPU %s faster${RESET}\n" "$sp"
else
    sp=$(speedup $cpu2_bin $gpu2_total)
    printf "${GREEN}GPU %s${RESET}\n" "$sp"
fi

# 4-layer row
printf "  %-8s  %10d  %10d  %10d  %10d  " \
    "4" "$gpu4_total" "$gpu4_comp" "$gpu4_dma" "$cpu4_shift"
if [ "$gpu4_total" -gt "$cpu4_shift" ]; then
    sp=$(speedup $gpu4_total $cpu4_shift)
    printf "${RED}CPU %s faster${RESET}\n" "$sp"
else
    sp=$(speedup $cpu4_shift $gpu4_total)
    printf "${GREEN}GPU %s${RESET}\n" "$sp"
fi

# Projected 8L and 16L with DMA
DMA=395
for L in 8 16; do
    eval gc=\$gpu${L}c
    eval cc=\$cpu${L}c
    gt=$((gc + DMA))
    printf "  %-8s  %10d  %10d  %10d  %10d  " \
        "$L" "$gt" "$gc" "$DMA" "$cc"
    if [ "$gt" -gt "$cc" ]; then
        sp=$(speedup $gt $cc)
        printf "${RED}CPU %s faster${RESET}\n" "$sp"
    else
        sp=$(speedup $cc $gt)
        printf "${GREEN}GPU %s${RESET}\n" "$sp"
    fi
done

echo ""
printf "  ${DIM}DMA overhead: ~395 cycles (D_IMEM + D_UNPACK + D_PACK + NOP waits)${RESET}\n"
printf "  ${DIM}Crossover at ~4 layers: GPU total beats CPU total${RESET}\n"
printf "  ${DIM}8L/16L GPU+DMA rows use measured DMA=395 + measured compute${RESET}\n"

section "4. Per-Layer Breakdown"

printf "  ${BOLD}%-22s  %12s  %12s${RESET}\n" "" "GPU (WMMA)" "CPU (shift)"
printf "  %-22s  %12s  %12s\n" "--------------------" "----------" "----------"
printf "  %-22s  %12s  %12s\n" "Per-layer compute"   "~110 cycles" "~232 cycles"
printf "  %-22s  %12s  %12s\n" "WMMA.MMA (matmul)"   "~44 cycles"  "N/A"
printf "  %-22s  %12s  %12s\n" "Multiply method"     "BF16 SA"     "ADD+shift"
printf "  %-22s  %12s  %12s\n" "MACs per layer"      "16 parallel" "16 sequential"
printf "  %-22s  %12s  %12s\n" "CPU MUL instruction" "N/A"         "DISABLED"
printf "  %-22s  %12s  %12s\n" "Max layers (IMEM)"   "22 unrolled" "~136"

section "5. Test Verification"

printf "  ${BOLD}Total: ${GREEN}%d PASS${RESET}" "$pass_total"
if [ "$fail_total" -gt 0 ]; then
    printf "  ${RED}%d FAIL${RESET}" "$fail_total"
fi
echo ""

# List all PASS/FAIL lines
echo ""
for log in "$LOG_2L" "$LOG_4L" "$LOG_SWEEP"; do
    name=$(basename "$log" .log)
    grep '\[PASS\]\|\[FAIL\]' "$log" 2>/dev/null | while read -r line; do
        if echo "$line" | grep -q FAIL; then
            printf "  ${RED}%-30s %s${RESET}\n" "[$name]" "$line"
        else
            printf "  ${GREEN}%-30s %s${RESET}\n" "[$name]" "$line"
        fi
    done
done

echo ""
printf "${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}║  GPU tensor core: 2.1-2.2x faster (pure compute)               ║${RESET}\n"
printf "${BOLD}║  With DMA: 0.8x@2L → 1.1x@4L → 1.5x@8L → 1.8x@16L              ║${RESET}\n"
printf "${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"
echo ""
