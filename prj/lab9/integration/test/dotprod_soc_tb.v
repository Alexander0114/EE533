/* file: dotprod_soc_tb.v
Description: Lab 9 integration testbench — BF16 dot product of two 16-element
   vectors. Demonstrates CUDA-style flow:
     Host (testbench) → packet → pkt_proc → ARM CPU launches GPU kernel →
     GPU computes dot(A,B) using TENSOR FMA loop + horizontal reduction →
     result read back and sent as response packet.

   Vectors:
     A = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]  (BF16)
     B = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]          (BF16)
     Expected dot product = sum(1..16) = 136.0 = BF16 0x4308

   GPU Kernel (21 instructions):
     - 4-iteration FMA loop (4 lanes × 4 iters = 16 elements)
     - Horizontal reduction via VBCAST + TENSOR ADD
     - Stores scalar result (broadcast across all lanes) to DMEM[8]

   ARM Host Program (6 instructions):
     - MCR p10 CR5 = 1 to start GPU
     - MRC p10 CR6 poll loop for done flag
     - B . (halt)

Author: Raymond
Date: Mar. 11, 2026
Version: 1.0
*/

`timescale 1ns / 1ps

`include "define.v"
`include "cpu_mt.v"
`include "test_i_mem.v"
`include "test_d_mem.v"
`include "cp10_regfile.v"
`include "pkt_proc.v"
`include "conv_fifo.v"
`include "gpu_top.v"
`include "control_unit.v"
`include "Register_file.v"
`include "gpu_alu.v"
`include "tensor_unit.v"
`include "tensor_core.v"
`include "bf16_lane.v"
`include "mult18x18s_stub.v"
`include "bram_sim.v"
`include "test_gpu_dmem.v"
`include "soc_top.v"

module dotprod_soc_tb;

    // ================================================================
    // Clock and reset
    // ================================================================
    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz, 10ns period

    // ================================================================
    // DUT I/O
    // ================================================================
    reg  [63:0] in_data;
    reg  [7:0]  in_ctrl;
    reg         in_wr;
    wire        in_rdy;

    wire [63:0] out_data;
    wire [7:0]  out_ctrl;
    wire        out_wr;
    reg         out_rdy;

    soc_top dut (
        .clk(clk), .rst_n(rst_n),
        .in_data(in_data), .in_ctrl(in_ctrl), .in_wr(in_wr), .in_rdy(in_rdy),
        .out_data(out_data), .out_ctrl(out_ctrl), .out_wr(out_wr), .out_rdy(out_rdy)
    );

    // ================================================================
    // BF16 Constants
    // ================================================================
    localparam [15:0] BF16_0  = 16'h0000;
    localparam [15:0] BF16_1  = 16'h3F80;
    localparam [15:0] BF16_2  = 16'h4000;
    localparam [15:0] BF16_3  = 16'h4040;
    localparam [15:0] BF16_4  = 16'h4080;
    localparam [15:0] BF16_5  = 16'h40A0;
    localparam [15:0] BF16_6  = 16'h40C0;
    localparam [15:0] BF16_7  = 16'h40E0;
    localparam [15:0] BF16_8  = 16'h4100;
    localparam [15:0] BF16_9  = 16'h4110;
    localparam [15:0] BF16_10 = 16'h4120;
    localparam [15:0] BF16_11 = 16'h4130;
    localparam [15:0] BF16_12 = 16'h4140;
    localparam [15:0] BF16_13 = 16'h4150;
    localparam [15:0] BF16_14 = 16'h4160;
    localparam [15:0] BF16_15 = 16'h4170;
    localparam [15:0] BF16_16 = 16'h4180;
    localparam [15:0] BF16_136 = 16'h4308;  // dot product result

    // ================================================================
    // GPU DMEM Data — vectors stored as 4 BF16 lanes per 64-bit word
    //   Lane layout: [63:48]=lane3, [47:32]=lane2, [31:16]=lane1, [15:0]=lane0
    // ================================================================
    // Vector A (16 elements, DMEM[0:3])
    localparam [63:0] A_WORD0 = {BF16_4,  BF16_3,  BF16_2,  BF16_1};   // A[3:0]
    localparam [63:0] A_WORD1 = {BF16_8,  BF16_7,  BF16_6,  BF16_5};   // A[7:4]
    localparam [63:0] A_WORD2 = {BF16_12, BF16_11, BF16_10, BF16_9};   // A[11:8]
    localparam [63:0] A_WORD3 = {BF16_16, BF16_15, BF16_14, BF16_13};  // A[15:12]

    // Vector B (16 elements, DMEM[4:7]) — all 1.0
    localparam [63:0] B_WORD  = {BF16_1, BF16_1, BF16_1, BF16_1};

    // Expected result: dot(A,B) = 136.0 in all lanes
    localparam [63:0] EXPECTED_RESULT = {BF16_136, BF16_136, BF16_136, BF16_136};

    // ================================================================
    // ARM Host Program (6 instructions)
    // ================================================================
    //  0: MOV R0, #1              — value for CP10 start
    //  1: MCR p10, 0, R0, CR5    — write CR5[0]=1 → start GPU
    //  2: MRC p10, 0, R1, CR6    — read GPU status
    //  3: TST R1, #1             — test done bit
    //  4: BEQ -4                 — loop back to MRC if not done
    //  5: B .                    — halt (self-branch)
    localparam [31:0] ARM_0 = 32'hE3A00001;  // MOV R0, #1
    localparam [31:0] ARM_1 = 32'hEE050A10;  // MCR p10, 0, R0, CR5, CR0, 0
    localparam [31:0] ARM_2 = 32'hEE161A10;  // MRC p10, 0, R1, CR6, CR0, 0
    localparam [31:0] ARM_3 = 32'hE3110001;  // TST R1, #1
    localparam [31:0] ARM_4 = 32'h0AFFFFFC;  // BEQ -4 (to addr 2)
    localparam [31:0] ARM_5 = 32'hEAFFFFFE;  // B . (halt)

    // ================================================================
    // GPU Dot Product Kernel (20 instructions)
    //
    // Register allocation:
    //   R0  = 0 (zero reg, default after reset)
    //   R1  = pointer to A (incremented each iteration)
    //   R2  = pointer to B (incremented each iteration)
    //   R3  = loop counter (counts down from 4, avoids BLT signed cmp bug in XST)
    //   R5  = loaded A chunk
    //   R6  = loaded B chunk
    //   R10 = FMA accumulator (4 partial sums)
    //   R11-R15 = horizontal reduction temporaries
    //   R13 = final result (scalar broadcast)
    //
    // Memory map:
    //   DMEM[0:3] = Vector A (4 words × 4 BF16 = 16 elements)
    //   DMEM[4:7] = Vector B (4 words × 4 BF16 = 16 elements)
    //   DMEM[8]   = output (dot product result)
    // ================================================================

    // Helper function for GPU instruction encoding
    // R-type: {opcode[4:0], rd[4:0], ra[4:0], rb[4:0], rc[4:0], func[3:0], mode[2:0]}
    // I-type: {opcode[4:0], rd[4:0], ra[4:0], imm17[16:0]}

    localparam [31:0] GPU_00 = {5'h0C, 5'd1,  5'd0,  17'd0};       //  0: MOVI R1, #0    (A ptr)
    localparam [31:0] GPU_01 = {5'h0C, 5'd2,  5'd0,  17'd4};       //  1: MOVI R2, #4    (B ptr)
    localparam [31:0] GPU_02 = {5'h0C, 5'd3,  5'd0,  17'd4};       //  2: MOVI R3, #4    (count down)
    localparam [31:0] GPU_03 = {5'h0C, 5'd10, 5'd0,  17'd0};       //  3: MOVI R10, #0   (acc)

    localparam [31:0] GPU_04 = {5'h02, 5'd5,  5'd1,  17'd0};       //  4: LD R5, R1, #0
    localparam [31:0] GPU_05 = {5'h02, 5'd6,  5'd2,  17'd0};       //  5: LD R6, R2, #0
    localparam [31:0] GPU_06 = {5'h01, 5'd10, 5'd5,  5'd6,  5'd10, 4'd0, 3'd2}; //  6: TENSOR FMA R10,R5,R6,R10

    localparam [31:0] GPU_07 = {5'h09, 5'd1,  5'd1,  17'd1};       //  7: ADDI R1, R1, #1
    localparam [31:0] GPU_08 = {5'h09, 5'd2,  5'd2,  17'd1};       //  8: ADDI R2, R2, #1
    localparam [31:0] GPU_09 = {5'h09, 5'd3,  5'd3,  17'h1FFFF};   //  9: ADDI R3, R3, #-1  (decrement)
    localparam [31:0] GPU_10 = {5'h05, 5'd3,  5'd0,  17'h1FFFA};   // 10: BNE R3, R0, -6    (→4)

    // Horizontal reduction: sum 4 partial-product lanes
    localparam [31:0] GPU_11 = {5'h0E, 5'd11, 5'd10, 17'd3};       // 11: VBCAST R11, R10, lane3
    localparam [31:0] GPU_12 = {5'h0E, 5'd12, 5'd10, 17'd2};       // 12: VBCAST R12, R10, lane2
    localparam [31:0] GPU_13 = {5'h01, 5'd13, 5'd11, 5'd12, 5'd0, 4'd0, 3'd0}; // 13: TENSOR ADD R13,R11,R12
    localparam [31:0] GPU_14 = {5'h0E, 5'd14, 5'd10, 17'd1};       // 14: VBCAST R14, R10, lane1
    localparam [31:0] GPU_15 = {5'h01, 5'd13, 5'd13, 5'd14, 5'd0, 4'd0, 3'd0}; // 15: TENSOR ADD R13,R13,R14
    localparam [31:0] GPU_16 = {5'h0E, 5'd15, 5'd10, 17'd0};       // 16: VBCAST R15, R10, lane0
    localparam [31:0] GPU_17 = {5'h01, 5'd13, 5'd13, 5'd15, 5'd0, 4'd0, 3'd0}; // 17: TENSOR ADD R13,R13,R15

    localparam [31:0] GPU_18 = {5'h03, 5'd13, 5'd0,  17'd8};       // 18: ST R13, R0, #8
    localparam [31:0] GPU_19 = {5'h0A, 27'd0};                      // 19: HALT

    // ================================================================
    // Packet storage
    // ================================================================
    reg [63:0] pkt_words [0:31];
    reg [7:0]  pkt_ctrl  [0:31];
    integer    pkt_len;

    // TX capture
    reg [63:0] tx_words [0:15];
    reg [7:0]  tx_ctrl  [0:15];
    integer    tx_count;

    // ================================================================
    // Build the command packet
    // ================================================================
    task build_packet;
        integer i;
    begin
        i = 0;

        // ---- LOAD_IMEM (CPU): addr=0, count=3 (6 ARM instructions) ----
        pkt_words[i] = {4'h1, 12'h000, 16'h0003, 32'h0};
        pkt_ctrl[i]  = 8'h04;  // module header (output port routing)
        i = i + 1;
        pkt_words[i] = {ARM_1, ARM_0};    pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_3, ARM_2};    pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_5, ARM_4};    pkt_ctrl[i] = 8'h00; i = i + 1;

        // ---- LOAD_GPU_IMEM: addr=0, count=10 (20 GPU instrs) ----
        pkt_words[i] = {4'h6, 12'h000, 16'h000A, 32'h0};
        pkt_ctrl[i]  = 8'h00; i = i + 1;
        pkt_words[i] = {GPU_01, GPU_00}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 0,1
        pkt_words[i] = {GPU_03, GPU_02}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 2,3
        pkt_words[i] = {GPU_05, GPU_04}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 4,5
        pkt_words[i] = {GPU_07, GPU_06}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 6,7
        pkt_words[i] = {GPU_09, GPU_08}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 8,9
        pkt_words[i] = {GPU_11, GPU_10}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 10,11
        pkt_words[i] = {GPU_13, GPU_12}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 12,13
        pkt_words[i] = {GPU_15, GPU_14}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 14,15
        pkt_words[i] = {GPU_17, GPU_16}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 16,17
        pkt_words[i] = {GPU_19, GPU_18}; pkt_ctrl[i] = 8'h00; i = i + 1;  // instrs 18,19

        // ---- LOAD_GPU_DMEM: addr=0, count=8 (A[0:3] + B[0:3]) ----
        pkt_words[i] = {4'h7, 12'h000, 16'h0008, 32'h0};
        pkt_ctrl[i]  = 8'h00; i = i + 1;
        // Vector A (DMEM[0:3])
        pkt_words[i] = A_WORD0; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = A_WORD1; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = A_WORD2; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = A_WORD3; pkt_ctrl[i] = 8'h00; i = i + 1;
        // Vector B (DMEM[4:7])
        pkt_words[i] = B_WORD;  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = B_WORD;  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = B_WORD;  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = B_WORD;  pkt_ctrl[i] = 8'h00; i = i + 1;

        // ---- CPU_START: entry_pc=0 ----
        pkt_words[i] = {4'h3, 12'h000, 16'h0000, 32'h0};
        pkt_ctrl[i]  = 8'h00; i = i + 1;

        // ---- READBACK_GPU: addr=8, count=1 (read result from DMEM[8]) ----
        pkt_words[i] = {4'h8, 12'h008, 16'h0001, 32'h0};
        pkt_ctrl[i]  = 8'h00; i = i + 1;

        // ---- SEND_PKT ----
        pkt_words[i] = {4'h5, 12'h000, 16'h0000, 32'h0};
        pkt_ctrl[i]  = 8'h00; i = i + 1;

        pkt_len = i;
    end
    endtask

    // ================================================================
    // Send packet via RX interface
    // ================================================================
    task send_packet;
        integer i;
    begin
        @(posedge clk);
        for (i = 0; i < pkt_len; i = i + 1) begin
            while (!in_rdy) @(posedge clk);
            in_data <= pkt_words[i];
            in_ctrl <= pkt_ctrl[i];
            in_wr   <= 1'b1;
            @(posedge clk);
        end
        in_wr   <= 1'b0;
        in_data <= 64'h0;
        in_ctrl <= 8'h0;
    end
    endtask

    // ================================================================
    // Capture TX output
    // ================================================================
    always @(posedge clk) begin
        if (out_wr && out_rdy) begin
            tx_words[tx_count] = out_data;
            tx_ctrl[tx_count]  = out_ctrl;
            tx_count = tx_count + 1;
            $display("[TX] word %0d: data=%016h ctrl=%02h", tx_count-1, out_data, out_ctrl);
        end
    end

    // ================================================================
    // Monitor key events
    // ================================================================
    wire [4:0] pp_state  = dut.u_pkt_proc.state;
    wire       cpu_done  = dut.cpu_done_w;
    wire       gpu_halt  = dut.gpu_halted_w;
    wire       gpu_act   = dut.gpu_active_r;
    wire [3:0] gpu_state = dut.u_gpu.debug_state;
    wire [9:0] gpu_pc    = dut.u_gpu.debug_pc;

    reg gpu_halt_prev, gpu_act_prev;

    always @(posedge clk) begin
        gpu_halt_prev <= gpu_halt;
        gpu_act_prev  <= gpu_act;
        if (pp_state == 5'd8)
            $display("[%0t ns] pkt_proc → CPU_START", $time/1000);
        if (pp_state == 5'd9 && cpu_done)
            $display("[%0t ns] CPU done → pkt_proc resumes", $time/1000);
        if (gpu_act && !gpu_act_prev)
            $display("[%0t ns] GPU kernel started", $time/1000);
        if (gpu_halt && !gpu_halt_prev)
            $display("[%0t ns] GPU kernel done (halted at PC=%0d)", $time/1000, gpu_pc);
    end

    // ================================================================
    // Main test
    // ================================================================
    integer pass_count, fail_count;

    initial begin
        $dumpfile("dotprod_soc_tb.vcd");
        $dumpvars(0, dotprod_soc_tb);

        rst_n    = 0;
        in_data  = 64'h0;
        in_ctrl  = 8'h0;
        in_wr    = 0;
        out_rdy  = 1;
        tx_count = 0;
        pass_count = 0;
        fail_count = 0;
        gpu_halt_prev = 0;
        gpu_act_prev  = 0;

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("============================================================");
        $display("  Lab 9: BF16 Dot Product — 16-element vectors");
        $display("  A = [1, 2, 3, ..., 16]  (BF16)");
        $display("  B = [1, 1, 1, ..., 1]   (BF16)");
        $display("  Expected dot(A,B) = 136.0 = BF16 0x4308");
        $display("============================================================");

        build_packet;
        $display("\n--- Sending command packet (%0d words) ---\n", pkt_len);
        send_packet;

        // Wait for TX or timeout
        begin : wait_block
            integer cyc;
            for (cyc = 0; cyc < 200000; cyc = cyc + 1) begin
                @(posedge clk);
                if (tx_count > 0) begin
                    repeat (20) @(posedge clk);
                    disable wait_block;
                end
            end
            $display("[ERROR] Timeout after 200000 cycles!");
        end

        // ================================================================
        // Verify
        // ================================================================
        $display("\n============================================================");
        $display("  RESULTS");
        $display("============================================================");
        $display("TX words received: %0d", tx_count);

        if (tx_count >= 1) begin
            $display("TX[0] = 0x%016h", tx_words[0]);
            $display("  Lane 3 [63:48] = 0x%04h  (expect 0x%04h = 136.0)",
                     tx_words[0][63:48], BF16_136);
            $display("  Lane 2 [47:32] = 0x%04h  (expect 0x%04h = 136.0)",
                     tx_words[0][47:32], BF16_136);
            $display("  Lane 1 [31:16] = 0x%04h  (expect 0x%04h = 136.0)",
                     tx_words[0][31:16], BF16_136);
            $display("  Lane 0 [15:0]  = 0x%04h  (expect 0x%04h = 136.0)",
                     tx_words[0][15:0],  BF16_136);

            if (tx_words[0] === EXPECTED_RESULT) begin
                $display("\n  >>> PASS: dot(A,B) = 136.0 correct! <<<");
                pass_count = pass_count + 1;
            end else begin
                $display("\n  >>> FAIL: expected 0x%016h, got 0x%016h <<<",
                         EXPECTED_RESULT, tx_words[0]);
                fail_count = fail_count + 1;
            end
        end else begin
            $display("  >>> FAIL: no TX output <<<");
            fail_count = fail_count + 1;
        end

        $display("\n============================================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED  (%0d/%0d)", pass_count, pass_count);
        else
            $display("  FAILED  (%0d pass, %0d fail)", pass_count, fail_count);
        $display("============================================================\n");

        $finish;
    end

endmodule
