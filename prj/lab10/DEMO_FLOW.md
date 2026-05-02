# Lab 10 Demo Video Flow

## Setup
- Terminal open at `~/USC/ee533/prj/lab10/sim/`
- Make sure font is large enough for recording (Ctrl+= to zoom)
- Clear terminal before starting

## Demo Script (5-7 minutes)

### Part 1: Introduction + Caveats (1.5 min)

**Say:** "This demo shows GPU vs CPU cycle comparison for neural network inference on our NetFPGA SoC. The SoC has a 4-thread barrel ARM CPU and a 4-thread SIMT GPU with a 4x4 BF16 tensor core."

**Say:** "Before we look at results, three important caveats about this comparison:"

**Caveat 1 — Layer size is 4x4 only:**
"The ANN uses 4 neurons per layer — matching the tensor core's native 4x4 size. For wider layers like 8 or 16 neurons, you'd tile: call WMMA.MMA multiple times and accumulate partial sums. We didn't implement tiling in this demo."

```
  Network shape (4-layer example):

  Input [4]  →  FC [4x4]  →  FC [4x4]  →  FC [4x4]  →  FC [4x4]  →  Output [4]
    x[0..3]     W1*x+b1      W2*h1+b2     W3*h2+b3     W4*h3+b4      y[0..3]
                 ReLU          ReLU          ReLU        (no ReLU)
```

**Caveat 2 — CPU has no MUL instruction:**
"The ARM CPU's multiply unit is disabled — mul_en is hardcoded to 0 in the control unit. So the CPU uses the barrel shifter to fake multiply: ADD R3, R1, R1-shifted-left-by-1 gives 3 times R1, in one instruction."

```
  weight 2:   ADD R3, R1, R1          →  R1 + R1     = 2*R1   (1 instr)
  weight 3:   ADD R3, R1, R1 LSL #1   →  R1 + 2*R1   = 3*R1   (1 instr)
  weight 5:   ADD R3, R1, R1 LSL #2   →  R1 + 4*R1   = 5*R1   (1 instr)
  weight 173: 5+ shift-add instrs     →  128+32+8+4+1          (5+ instrs!)
```

**Caveat 3 — We use easy weights:**
"We picked weights [2, 3, -1, 5] — each takes 1 shift-add instruction. Real ANN weights like 173 would need 5+ instructions per multiply. So the 2.1x GPU speedup we measure is actually the best case for the CPU — with real 8-bit weights, GPU advantage would be even larger."

### Part 2: Run the simulation (1 min)
```bash
cd ~/USC/ee533/prj/lab10/sim
./run_comparison.sh
```

**Say while it compiles:** "The script runs 3 testbenches with increasing network depth:
- Test 1: 2-layer ANN (4→4→4) with full DMA pipeline
- Test 2: 4-layer ANN (4→4→4→4→4) with DMA — this is where GPU starts winning
- Test 3: Scaling sweep from 2 to 16 layers — pure compute, no DMA"

Wait for it to finish (~2-3 min). The output will show each testbench result inline.

### Part 3: Walk through Test 1 output (1 min)
Scroll up to **Test 1: 2-Layer GPU vs CPU (with DMA)**

**Say:** "Test 1 is a 2-layer ANN — that's 4 inputs, one 4-neuron hidden layer with ReLU, and 4 outputs. Shape: 4→4→4."

**Point out:**
- "GPU total: 613 cycles, but only 221 are compute — 64% is DMA overhead"
- "CPU total: 257 cycles — faster because no DMA, and only 2 layers of ADD"
- "The GPU BF16 output: bank0-3 show the 4 output classes, all 6 assertions PASS"

### Part 4: Walk through Test 2 output (1 min)
Scroll to **Test 2: 4-Layer GPU vs CPU (with DMA)**

**Say:** "Now we double the depth to 4 layers — shape 4→4→4→4→4. Each layer uses general weights [2,3,-1,5], so the CPU must do shift-and-add multiply."

**Point out:**
- "At 4 layers, GPU total 829 vs CPU 945 — GPU wins by 1.1x"
- "GPU compute is 434 cycles (4 WMMA.MMA calls), DMA still ~395 — now 47%"
- "CPU intermediate values propagate: h1=[25,15,0,0], h2=[95,85,70,65], h3=[700,690,675,670]"
- "The 0 in h1 shows ReLU clamping: 2*1 + 3*2 - 3 + 5*4 - 25 = -2 → 0"
- "Final y=[6145,6135,6120,6115] — all 4 assertions PASS"

### Part 5: Walk through Scaling Table (1 min)
Scroll to **Section 2: Pure Compute**

**Say:** "Now the scaling sweep — same 4-neuron-wide network but from 2 to 16 layers deep. GPU memories are pre-loaded so there's zero DMA."

**Point out the table:**
- "2-layer (4→4→4): GPU 221, CPU 465, speedup 2.1x"
- "16-layer (4→4→...→4, 17 stages): GPU 1712, CPU 3825, still 2.2x"
- "The ratio is flat because both scale linearly — each extra 4x4 FC layer costs a fixed ~110 GPU or ~232 CPU cycles"

Then scroll to **Section 3: End-to-End**

**Say:** "In a real system you pay the DMA tax. Here's what happens:"
- "2-layer: DMA adds 392 cycles, GPU total 613 > CPU 257 — CPU wins"
- "4-layer: GPU 829 < CPU 945 — crossover, GPU starts winning"
- "16-layer: GPU 2107 vs CPU 3825 — GPU 1.8x faster, DMA is only 19% of total now"

### Part 6: Architecture Recap (30 sec)
Scroll to **Section 4: Per-Layer Breakdown**

**Point out:**
- "GPU: 14 kernel instructions per layer — 3 loads, 1 WMMA.MMA (44 cycles for 16 MACs in parallel), ReLU, 1 store"
- "CPU: 60 instructions per layer — 15 per element x 4 elements, all sequential through the barrel pipeline"
- "GPU per-layer: ~110 cycles. CPU per-layer: ~232 cycles. That's the 2.1x ratio."
- "And remember, that's with our easy weights. Real weights would make CPU even slower."

### Part 7: Wrap up (30 sec)
Scroll to bottom banner.

**Say:** "In summary, for a 4-neuron-wide fully connected ANN on this SoC:
- GPU tensor core is 2.1x faster in pure compute — 4x4 matmul in 44 cycles via systolic array
- DMA overhead hurts at shallow networks but amortizes: 0.8x at 2 layers → 1.8x at 16 layers
- We tested 4→4 FC layers matching the native tensor core size
- For wider layers like 8 or 16 neurons, WMMA.MMA's accumulator enables tiling — we didn't implement that here but the hardware supports it
- All 14 assertions pass across 3 testbenches
- Full report in lab10_cycle_comparison_report.docx"

## Quick Commands Reference
```bash
# Run full comparison (all 3 tests)
./run_comparison.sh

# Run individual testbenches manually
cd src/sim
iverilog -o test.vvp -g2005 $(cat soc_sim_fix_inc.txt) ../tb/ann_cycle_compare_tb.v && vvp test.vvp
iverilog -o test.vvp -g2005 $(cat soc_sim_fix_inc.txt) ../tb/ann_4layer_compare_tb.v && vvp test.vvp
iverilog -o test.vvp -g2005 $(cat soc_sim_fix_inc.txt) ../tb/ann_compute_compare_tb.v && vvp test.vvp
```

## Files
| File | Purpose |
|------|---------|
| `sim/run_comparison.sh` | Main demo script — runs all tests |
| `sim/src/tb/ann_cycle_compare_tb.v` | Test 1: 2-layer with DMA |
| `sim/src/tb/ann_4layer_compare_tb.v` | Test 2: 4-layer with DMA |
| `sim/src/tb/ann_compute_compare_tb.v` | Test 3: scaling sweep no DMA |
| `sim/src/rtl_fix/cpu/core/cpu_mt.v` | Halt-fixed CPU RTL |
| `lab10_cycle_comparison_report.docx` | Written report |
| `gen_cycle_report.py` | Report generator |
