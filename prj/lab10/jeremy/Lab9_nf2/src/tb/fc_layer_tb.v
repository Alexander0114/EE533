/* file: fc_layer_tb.v
 * FC Layer Inference Testbench: y = ReLU(W × X + B)
 *
 * Test: W=I (identity), X=[[2,3,0,-1],...], B=0
 * Expected: ReLU(I×X+0) = [[2,3,0,0],...] (-1 clamped by ReLU)
 *
 * Uses existing soc_tb infrastructure (send_gpu_arm, send_gpu_imem, etc.)
 *
 * Author: Raymond
 * Date: Mar. 26, 2026
 */

`timescale 1ns / 1ps
`include "soc.v"

module fc_layer_tb;

localparam CLK_PERIOD = 10;
localparam MAX_CYCLES = 8000;

// ═══════════════════════════════════════════════════════════════
//  Constants
// ═══════════════════════════════════════════════════════════════
localparam [31:0] ARM_NOP  = 32'hE1A00000;
localparam [31:0] ARM_HALT = 32'hEAFF_FFFE;

// BF16 constants
localparam [15:0] BF16_0   = 16'h0000;  // 0.0
localparam [15:0] BF16_1   = 16'h3F80;  // 1.0
localparam [15:0] BF16_2   = 16'h4000;  // 2.0
localparam [15:0] BF16_3   = 16'h4040;  // 3.0
localparam [15:0] BF16_N1  = 16'hBF80;  // -1.0

// ═══════════════════════════════════════════════════════════════
//  Clock / Reset
// ═══════════════════════════════════════════════════════════════
reg clk, rst_n;
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// ═══════════════════════════════════════════════════════════════
//  DUT I/O
// ═══════════════════════════════════════════════════════════════
reg  [63:0] in_data;
reg  [7:0]  in_ctrl;
reg         in_wr;
wire        in_rdy;

wire [63:0] out_data;
wire [7:0]  out_ctrl;
wire        out_wr;
reg         out_rdy;

// ═══════════════════════════════════════════════════════════════
//  DUT
// ═══════════════════════════════════════════════════════════════
soc u_soc (
    .clk(clk), .rst_n(rst_n),
    .in_data(in_data), .in_ctrl(in_ctrl), .in_wr(in_wr), .in_rdy(in_rdy),
    .out_data(out_data), .out_ctrl(out_ctrl), .out_wr(out_wr), .out_rdy(out_rdy)
);

// ═══════════════════════════════════════════════════════════════
//  Test Infrastructure
// ═══════════════════════════════════════════════════════════════
integer pass_cnt = 0, fail_cnt = 0, test_id = 0;

reg [63:0] tx_data [0:127];
reg [7:0]  tx_ctrl [0:127];
integer tx_cnt;

task tick; begin @(posedge clk); #1; end endtask

function [63:0] cmd;
    input [3:0] opcode;
    input [11:0] addr;
    input [15:0] count;
    input [31:0] param;
    cmd = {opcode, addr, count, param};
endfunction

task rx;
    input [63:0] data;
    input [7:0]  ctrl;
begin
    in_data = data; in_ctrl = ctrl; in_wr = 1; tick;
end
endtask

task rx_end;
begin
    in_wr = 0; in_data = 64'd0; in_ctrl = 8'd0; tick;
end
endtask

task send_nop_pairs;
    input integer n;
    integer i;
begin
    for (i = 0; i < n; i = i + 1)
        rx({ARM_NOP, ARM_NOP}, 8'h00);
end
endtask

task wait_and_capture;
    input integer max_cyc;
    integer c;
begin
    tx_cnt = 0; c = 0;
    while (!u_soc.pp_active && c < max_cyc) begin tick; c = c + 1; end
    while (u_soc.pp_active && c < max_cyc) begin
        if (out_wr && out_rdy) begin
            tx_data[tx_cnt] = out_data;
            tx_ctrl[tx_cnt] = out_ctrl;
            tx_cnt = tx_cnt + 1;
        end
        tick; c = c + 1;
    end
    if (c >= max_cyc) begin
        $display("    [TIMEOUT] pkt_proc stuck (state=%0d cpu_done=%b)",
                 u_soc.u_pkt_proc.state, u_soc.cpu_done_w);
    end
    repeat (5) tick;
end
endtask

task check64;
    input [63:0] val, exp;
    input [80*8-1:0] name;
begin
    test_id = test_id + 1;
    if (val === exp) begin
        $display("    [PASS] T%0d: %0s = 0x%016h", test_id, name, val);
        pass_cnt = pass_cnt + 1;
    end else begin
        $display("    [FAIL] T%0d: %0s = 0x%016h, exp 0x%016h", test_id, name, val, exp);
        fail_cnt = fail_cnt + 1;
    end
end
endtask

task checkN;
    input integer val, exp;
    input [80*8-1:0] name;
begin
    test_id = test_id + 1;
    if (val == exp) begin
        $display("    [PASS] T%0d: %0s = %0d", test_id, name, val);
        pass_cnt = pass_cnt + 1;
    end else begin
        $display("    [FAIL] T%0d: %0s = %0d, exp %0d", test_id, name, val, exp);
        fail_cnt = fail_cnt + 1;
    end
end
endtask

// ═══════════════════════════════════════════════════════════════
//  GPU Kernel: y = ReLU(W × X + B)
//
//  Register allocation: R0-3=W, R4-7=X, R8-11=B, R12-15=D
//
//  [0]  MOVI R0, 0              ; base address
//  [1]  WMMA.LOAD R4, [R0+4]   ; X from DMEM[4..7]
//  [2]  WMMA.LOAD R8, [R0+8]   ; B from DMEM[8..11]
//  [3]  WMMA.LOAD R0, [R0+0]   ; W from DMEM[0..3] (R0 overwritten last)
//  [4]  WMMA.MMA R12,R0,R4,R8  ; D = W*X + B
//  [5]  MOVI R0, 0             ; zero for ReLU
//  [6]  MAX.f R12, R12, R0     ; ReLU
//  [7]  MAX.f R13, R13, R0     ; ReLU
//  [8]  MAX.f R14, R14, R0     ; ReLU
//  [9]  MAX.f R15, R15, R0     ; ReLU
//  [10] MOVI R0, 0             ; store base
//  [11] WMMA.STORE R12,[R0+0]  ; D → DMEM[0..3]
//  [12] RET
// ═══════════════════════════════════════════════════════════════

// GPU instruction encodings
localparam [31:0] G_MOVI_R0_0    = 32'h2000_0000; // MOVI R0, 0
localparam [31:0] G_WLOAD_R4     = 32'hF040_0004; // WMMA.LOAD R4,[R0+4]
localparam [31:0] G_WLOAD_R8     = 32'hF080_0008; // WMMA.LOAD R8,[R0+8]
localparam [31:0] G_WLOAD_R0     = 32'hF000_0000; // WMMA.LOAD R0,[R0+0]
localparam [31:0] G_WMMA_MMA     = 32'hECC0_4800; // WMMA.MMA R12,R0,R4,R8
localparam [31:0] G_MAX_R12      = 32'h54CC_0000; // MAX.f R12,R12,R0
localparam [31:0] G_MAX_R13      = 32'h54DD_0000; // MAX.f R13,R13,R0
localparam [31:0] G_MAX_R14      = 32'h54EE_0000; // MAX.f R14,R14,R0
localparam [31:0] G_MAX_R15      = 32'h54FF_0000; // MAX.f R15,R15,R0
localparam [31:0] G_WSTORE_R12   = 32'hF8C0_0000; // WMMA.STORE R12,[R0+0]
localparam [31:0] G_RET          = 32'hC800_0000; // RET

// ═══════════════════════════════════════════════════════════════
//  Main Test
// ═══════════════════════════════════════════════════════════════
initial begin
    $dumpfile("fc_layer_tb.vcd");
    $dumpvars(0, fc_layer_tb);

    // Reset
    rst_n = 0; in_wr = 0; in_data = 0; in_ctrl = 0; out_rdy = 1;
    repeat (10) tick;
    rst_n = 1;
    repeat (5) tick;

    $display("");
    $display("================================================================");
    $display("  FC Layer Inference: y = ReLU(W * X + B)");
    $display("  W = Identity, X = [2,3,0,-1], B = 0");
    $display("  Expected: [2.0, 3.0, 0, 0] (ReLU clamps -1)");
    $display("================================================================");

    // ──────────────────────────────────────────────────────────
    //  Send ARM program (LOAD_IMEM)
    //
    //  Uses send_gpu_arm pattern: 80 instrs = 40 DWs
    //  Phase 1: D_IMEM (DMEM[0..15] → GPU IMEM, 16 words)
    //  Phase 2: D_UNPACK (DMEM[16..] → GPU DMEM, burst_all, xfer=6)
    //  Phase 3: GPU launch (entry_pc=0, mask=0xF)
    //  Phase 4: D_PACK (GPU DMEM[0..] → DMEM[32..], burst_all, xfer=2)
    //  Phase 5: Halt
    // ──────────────────────────────────────────────────────────
    rx(cmd(4'h1, 12'h000, 16'd40, 32'h0), 8'h04); // LOAD_IMEM, 40 DWs

    // Phase 1: D_IMEM setup [0..7]
    rx({32'hEE000A10, 32'hE3A00000}, 8'h00); // [1]MCR CR0,R0; [0]MOV R0,#0
    rx({32'hE3A01010, 32'hEE010A10}, 8'h00); // [3]MOV R1,#16; [2]MCR CR1,R0(=0)
    rx({32'hE3A02005, 32'hEE021A10}, 8'h00); // [5]MOV R2,#5;  [4]MCR CR2,R1(=16)
    rx({ARM_NOP,      32'hEE032A10}, 8'h00); // [7]NOP;         [6]MCR CR3,R2(=5→D_IMEM)
    send_nop_pairs(4);                        // [8..15] wait for D_IMEM

    // Phase 2: D_UNPACK [16..23]
    rx({32'hEE000A10, 32'hE3A00010}, 8'h00); // [17]MCR CR0,R0; [16]MOV R0,#16
    rx({32'hEE011A10, 32'hE3A01000}, 8'h00); // [19]MCR CR1,R1; [18]MOV R1,#0
    rx({32'hEE022A10, 32'hE3A02006}, 8'h00); // [21]MCR CR2,R2; [20]MOV R2,#6 (xfer=6)
    rx({32'hEE033A10, 32'hE3A03041}, 8'h00); // [23]MCR CR3,R3; [22]MOV R3,#65(=0x41)
    send_nop_pairs(5);                        // [24..33] wait for D_UNPACK

    // Phase 3: GPU launch [34..39]
    rx({32'hEE040A10, 32'hE3A00000}, 8'h00); // [35]MCR CR4,R0; [34]MOV R0,#0
    rx({32'hEE071A10, 32'hE3A0100F}, 8'h00); // [37]MCR CR7,R1; [36]MOV R1,#15
    rx({32'hEE052A10, 32'hE3A02001}, 8'h00); // [39]MCR CR5,R2; [38]MOV R2,#1
    send_nop_pairs(10);                       // [40..59] wait for GPU

    // Phase 4: D_PACK [60..67]
    rx({32'hEE000A10, 32'hE3A00000}, 8'h00); // [61]MCR CR0,R0; [60]MOV R0,#0(gpu src)
    rx({32'hEE011A10, 32'hE3A01030}, 8'h00); // [63]MCR CR1,R1; [62]MOV R1,#48(cpu dst)
    rx({32'hEE022A10, 32'hE3A02002}, 8'h00); // [65]MCR CR2,R2; [64]MOV R2,#2(xfer=2)
    rx({32'hEE033A10, 32'hE3A03043}, 8'h00); // [67]MCR CR3,R3; [66]MOV R3,#67(=0x43)
    send_nop_pairs(5);                        // [68..77] wait for D_PACK

    // Phase 5: Halt
    rx({ARM_NOP, ARM_HALT}, 8'h00);           // [79]NOP; [78]B .

    // ──────────────────────────────────────────────────────────
    //  Send GPU program (LOAD_DMEM addr=0, count=8)
    //  16 GPU instructions packed in 8 DWs (LO=even, HI=odd)
    // ──────────────────────────────────────────────────────────
    rx(cmd(4'h2, 12'h000, 16'd8, 32'h0), 8'h00);
    rx({G_WLOAD_R4,   G_MOVI_R0_0},  8'h00); // [1]WMMA.LD R4;  [0]MOVI R0,0
    rx({G_WLOAD_R0,   G_WLOAD_R8},   8'h00); // [3]WMMA.LD R0;  [2]WMMA.LD R8
    rx({G_MOVI_R0_0,  G_WMMA_MMA},   8'h00); // [5]MOVI R0,0;   [4]WMMA.MMA
    rx({G_MAX_R13,    G_MAX_R12},     8'h00); // [7]MAX.f R13;   [6]MAX.f R12
    rx({G_MAX_R15,    G_MAX_R14},     8'h00); // [9]MAX.f R15;   [8]MAX.f R14
    rx({G_WSTORE_R12, G_MOVI_R0_0},  8'h00); // [11]WMMA.ST;    [10]MOVI R0,0
    rx({32'h0,        G_RET},         8'h00); // [13]NOP;         [12]RET
    rx({32'h0,        32'h0},         8'h00); // [15]NOP;         [14]NOP

    // ──────────────────────────────────────────────────────────
    //  Send matrix data (LOAD_DMEM addr=16, count=12)
    //
    //  D_UNPACK burst_all, xfer_len=6:
    //    Bank 0: CPU[16..21] → GPU DMEM[0..11]
    //    Bank 1: CPU[22..27] → GPU DMEM[0..11]
    //    Bank 2: CPU[28..33] → GPU DMEM[0..11]
    //    Bank 3: CPU[34..39] → GPU DMEM[0..11]
    //
    //  Per bank layout (12 BF16 values):
    //    DMEM[0..3]  = W row (identity: only one 1.0)
    //    DMEM[4..7]  = X row = [2.0, 3.0, 0, -1.0]
    //    DMEM[8..11] = B row = [0, 0, 0, 0]
    //
    //  CPU word packing: {HI=DMEM[odd], LO=DMEM[even]}
    // ──────────────────────────────────────────────────────────
    rx(cmd(4'h2, 12'h010, 16'd12, 32'h0), 8'h00);

    // Bank 0: W[0]=[1,0,0,0], X[0]=[2,3,0,-1], B[0]=[0,0,0,0]
    // W: CPU[16]={DMEM[1],DMEM[0]}={0,1.0}  CPU[17]={DMEM[3],DMEM[2]}={0,0}
    rx({{BF16_0,BF16_0},  {BF16_0,BF16_1}},  8'h00); // CPU[17,16]
    // X: CPU[18]={DMEM[5],DMEM[4]}={3.0,2.0}  CPU[19]={DMEM[7],DMEM[6]}={-1.0,0}
    rx({{BF16_N1,BF16_0}, {BF16_3,BF16_2}},  8'h00); // CPU[19,18]
    // B: CPU[20]={0,0}  CPU[21]={0,0}
    rx(64'h0, 8'h00);                                   // CPU[21,20]

    // Bank 1: W[1]=[0,1,0,0], X[1]=[2,3,0,-1], B[1]=[0,0,0,0]
    rx({{BF16_0,BF16_0},  {BF16_1,BF16_0}},  8'h00); // W: {0,0},{1.0,0}
    rx({{BF16_N1,BF16_0}, {BF16_3,BF16_2}},  8'h00); // X: same
    rx(64'h0, 8'h00);                                   // B: zero

    // Bank 2: W[2]=[0,0,1,0], X[2]=[2,3,0,-1], B[2]=[0,0,0,0]
    rx({{BF16_0,BF16_1},  {BF16_0,BF16_0}},  8'h00); // W: {0,1.0},{0,0}
    rx({{BF16_N1,BF16_0}, {BF16_3,BF16_2}},  8'h00); // X: same
    rx(64'h0, 8'h00);                                   // B: zero

    // Bank 3: W[3]=[0,0,0,1], X[3]=[2,3,0,-1], B[3]=[0,0,0,0]
    rx({{BF16_1,BF16_0},  {BF16_0,BF16_0}},  8'h00); // W: {1.0,0},{0,0}
    rx({{BF16_N1,BF16_0}, {BF16_3,BF16_2}},  8'h00); // X: same
    rx(64'h0, 8'h00);                                   // B: zero

    // ──────────────────────────────────────────────────────────
    //  Zero readback area + CPU_START + READBACK + SEND_PKT
    //
    //  Readback at addr=48 (after matrix data ends at addr=39)
    //  to avoid overwriting bank 3 data at addr=34..39
    // ──────────────────────────────────────────────────────────
    // LOAD_DMEM addr=48, count=4 (zero readback area)
    rx(cmd(4'h2, 12'h030, 16'd4, 32'h0), 8'h00);
    rx(64'h0, 8'h00); rx(64'h0, 8'h00);
    rx(64'h0, 8'h00); rx(64'h0, 8'h00);

    // CPU_START (entry_pc=0)
    rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);

    // READBACK addr=48, count=4 (4 DWs = 8 CPU words covering 4 banks)
    rx(cmd(4'h4, 12'h030, 16'd4, 32'h0), 8'h00);

    // SEND_PKT
    rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
    rx_end;

    // ──────────────────────────────────────────────────────────
    //  Wait and capture TX output
    // ──────────────────────────────────────────────────────────
    wait_and_capture(MAX_CYCLES);

    // ──────────────────────────────────────────────────────────
    //  Verify results
    //
    //  D_PACK xfer=2, burst_all, gpu_src=0:
    //    Bank 0: GPU DMEM[0..3] → CPU[32,33]
    //    Bank 1: GPU DMEM[0..3] → CPU[34,35]
    //    Bank 2: GPU DMEM[0..3] → CPU[36,37]
    //    Bank 3: GPU DMEM[0..3] → CPU[38,39]
    //
    //  READBACK addr=32, count=4:
    //    TX[0] = {CPU[33], CPU[32]} = {bank0_hi, bank0_lo}
    //    TX[1] = {CPU[35], CPU[34]} = {bank1_hi, bank1_lo}
    //    TX[2] = {CPU[37], CPU[36]} = {bank2_hi, bank2_lo}
    //    TX[3] = {CPU[39], CPU[38]} = {bank3_hi, bank3_lo}
    //
    //  Expected per bank:
    //    ReLU(W*X+B) = ReLU([2,3,0,-1]) = [2,3,0,0]
    //    GPU DMEM[0]=2.0=0x4000, [1]=3.0=0x4040, [2]=0, [3]=0
    //    D_PACK: CPU_lo={DMEM[1],DMEM[0]}={3.0,2.0}=0x40404000
    //            CPU_hi={DMEM[3],DMEM[2]}={0,0}=0x00000000
    //    TX word = {CPU_hi, CPU_lo} = 0x00000000_40404000
    // ──────────────────────────────────────────────────────────

    // Debug: CPU DMEM data region (was it loaded correctly by pkt_proc?)
    $display("--- Debug: CPU DMEM data loaded by pkt_proc ---");
    $display("  Bank0 CPU[16..21]: %08h %08h %08h %08h %08h %08h",
        u_soc.u_cpu_dmem.mem[16], u_soc.u_cpu_dmem.mem[17],
        u_soc.u_cpu_dmem.mem[18], u_soc.u_cpu_dmem.mem[19],
        u_soc.u_cpu_dmem.mem[20], u_soc.u_cpu_dmem.mem[21]);
    $display("  Bank3 CPU[34..39]: %08h %08h %08h %08h %08h %08h",
        u_soc.u_cpu_dmem.mem[34], u_soc.u_cpu_dmem.mem[35],
        u_soc.u_cpu_dmem.mem[36], u_soc.u_cpu_dmem.mem[37],
        u_soc.u_cpu_dmem.mem[38], u_soc.u_cpu_dmem.mem[39]);

    // Debug: dump GPU DMEM bank 3 contents (result should be at DMEM[0..3])
    $display("");
    $display("--- Debug: GPU DMEM after computation ---");
    $display("  Bank0 DMEM[0..3]: %04h %04h %04h %04h",
        u_soc.GPU_DMEM_BANK[0].u_gpu_dmem.mem[0],
        u_soc.GPU_DMEM_BANK[0].u_gpu_dmem.mem[1],
        u_soc.GPU_DMEM_BANK[0].u_gpu_dmem.mem[2],
        u_soc.GPU_DMEM_BANK[0].u_gpu_dmem.mem[3]);
    $display("  Bank3 DMEM[0..3]: %04h %04h %04h %04h",
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[0],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[1],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[2],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[3]);
    $display("  Bank3 DMEM[4..7]: %04h %04h %04h %04h",
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[4],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[5],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[6],
        u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[7]);
    // Debug: CPU DMEM readback area
    $display("  CPU DMEM[48..55]: %08h %08h %08h %08h %08h %08h %08h %08h",
        u_soc.u_cpu_dmem.mem[48], u_soc.u_cpu_dmem.mem[49],
        u_soc.u_cpu_dmem.mem[50], u_soc.u_cpu_dmem.mem[51],
        u_soc.u_cpu_dmem.mem[52], u_soc.u_cpu_dmem.mem[53],
        u_soc.u_cpu_dmem.mem[54], u_soc.u_cpu_dmem.mem[55]);

    $display("");
    $display("--- FC Layer Results ---");
    $display("  TX words captured: %0d", tx_cnt);

    checkN(tx_cnt, 4, "FC TX count");
    check64(tx_data[0], 64'h00000000_40404000, "FC bank0 ReLU([2,3,0,-1])=[2,3,0,0]");
    check64(tx_data[1], 64'h00000000_40404000, "FC bank1 ReLU([2,3,0,-1])=[2,3,0,0]");
    check64(tx_data[2], 64'h00000000_40404000, "FC bank2 ReLU([2,3,0,-1])=[2,3,0,0]");
    check64(tx_data[3], 64'h00000000_40404000, "FC bank3 ReLU([2,3,0,-1])=[2,3,0,0]");

    $display("");
    $display("================================================================");
    if (fail_cnt == 0)
        $display("  *** ALL %0d CHECKS PASSED ***", pass_cnt);
    else
        $display("  *** %0d PASSED, %0d FAILED ***", pass_cnt, fail_cnt);
    $display("  Total checks: %0d", pass_cnt + fail_cnt);
    $display("================================================================");
    $display("");
    #(CLK_PERIOD * 5);
    $finish;
end

endmodule
