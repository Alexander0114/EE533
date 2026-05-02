/* file: soc_top_tb.v
Description: Layer 4 integration testbench for soc_top. Sends a single
   all-in-one command packet that:
     1. Loads CPU IMEM (6 ARM instructions: start GPU, poll CR6, halt)
     2. Loads GPU IMEM (5 instructions: MOVI, LD, VADD, ST, HALT)
     3. Loads GPU DMEM (1 word: test vector)
     4. CPU_START (entry_pc=0)
     5. READBACK_GPU (read 1 word from GPU DMEM addr 0)
     6. SEND_PKT
   Verifies TX output matches expected VADD+1 result.
Author: Raymond
Date: Mar. 11, 2026
Version: 1.0
*/

`timescale 1ns / 1ps

// Include all source files via includes (with -I paths in compile)
`include "define.v"

// CPU modules (cpu_mt.v includes its own dependencies)
`include "cpu_mt.v"
`include "test_i_mem.v"
`include "test_d_mem.v"

// CP10
`include "cp10_regfile.v"

// Network
`include "pkt_proc.v"
`include "conv_fifo.v"

// GPU modules
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

// SoC top
`include "soc_top.v"

module soc_top_tb;

    // ================================================================
    // Clock and reset
    // ================================================================
    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

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
    // Packet data storage
    // ================================================================
    reg [63:0] pkt_words [0:15];
    reg [7:0]  pkt_ctrl  [0:15];
    integer    pkt_len;

    // TX capture
    reg [63:0] tx_words [0:15];
    reg [7:0]  tx_ctrl  [0:15];
    integer    tx_count;

    // ================================================================
    // ARM instruction encodings
    // ================================================================
    // MOV R0, #1
    localparam [31:0] ARM_MOV_R0_1     = 32'hE3A00001;
    // MCR p10, 0, R0, CR5, CR0, 0  (write R0 to CP10 CR5 → start GPU)
    localparam [31:0] ARM_MCR_CR5_R0   = 32'hEE050A10;
    // MRC p10, 0, R1, CR6, CR0, 0  (read CP10 CR6 into R1)
    localparam [31:0] ARM_MRC_CR6_R1   = 32'hEE161A10;
    // TST R1, #1
    localparam [31:0] ARM_TST_R1_1     = 32'hE3110001;
    // BEQ -4 (back to MRC instruction, PC-relative)
    localparam [31:0] ARM_BEQ_POLL     = 32'h0AFFFFFC;
    // B . (self-branch = halt)
    localparam [31:0] ARM_HALT         = 32'hEAFFFFFE;

    // ================================================================
    // GPU instruction encodings
    // ================================================================
    // MOVI R1, #1   (opcode=0x0C, rd=1, imm17=1)
    localparam [31:0] GPU_MOVI_R1_1    = {5'h0C, 5'd1, 5'd0, 17'd1};
    // LD R2, R0, #0 (opcode=0x02, rd=2, ra=0, imm17=0)
    localparam [31:0] GPU_LD_R2_R0_0   = {5'h02, 5'd2, 5'd0, 17'd0};
    // ALU VADD R3, R2, R1 (opcode=0x00, rd=3, ra=2, rb=1, rc=0, func=0, mode=0)
    localparam [31:0] GPU_VADD_R3_R2_R1 = {5'h00, 5'd3, 5'd2, 5'd1, 5'd0, 4'd0, 3'd0};
    // ST R3, R0, #0 (opcode=0x03, rd=3, ra=0, imm17=0)
    localparam [31:0] GPU_ST_R3_R0_0   = {5'h03, 5'd3, 5'd0, 17'd0};
    // HALT (opcode=0x0A)
    localparam [31:0] GPU_HALT         = {5'h0A, 27'd0};

    // ================================================================
    // GPU DMEM test data
    // ================================================================
    // 4 lanes: {0x0003, 0x0002, 0x0001, 0x0000}
    localparam [63:0] GPU_DMEM_INIT    = 64'h0003_0002_0001_0000;
    // Expected after VADD R3 = R2 + R1:
    //   R1 = sign_extend(1) = 0x0000_0000_0000_0001
    //   Lane-wise: {3+0, 2+0, 1+0, 0+1} = {3, 2, 1, 1}
    localparam [63:0] GPU_DMEM_EXPECT  = 64'h0003_0002_0001_0001;

    // ================================================================
    // Build the command packet
    // ================================================================
    task build_packet;
        integer i;
    begin
        i = 0;

        // --- LOAD_IMEM: addr=0, count=3 (6 ARM instructions) ---
        pkt_words[i] = {4'h1, 12'h000, 16'h0003, 32'h0}; pkt_ctrl[i] = 8'h04; i = i + 1;
        pkt_words[i] = {ARM_MCR_CR5_R0, ARM_MOV_R0_1};    pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_TST_R1_1,   ARM_MRC_CR6_R1};  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_HALT,        ARM_BEQ_POLL};    pkt_ctrl[i] = 8'h00; i = i + 1;

        // --- LOAD_GPU_IMEM: addr=0, count=3 (5 GPU instrs + 1 pad) ---
        pkt_words[i] = {4'h6, 12'h000, 16'h0003, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {GPU_LD_R2_R0_0,  GPU_MOVI_R1_1};  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {GPU_ST_R3_R0_0,  GPU_VADD_R3_R2_R1}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {32'h0,           GPU_HALT};         pkt_ctrl[i] = 8'h00; i = i + 1;

        // --- LOAD_GPU_DMEM: addr=0, count=1 ---
        pkt_words[i] = {4'h7, 12'h000, 16'h0001, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = GPU_DMEM_INIT;                      pkt_ctrl[i] = 8'h00; i = i + 1;

        // --- CPU_START: entry_pc = 0 ---
        pkt_words[i] = {4'h3, 12'h000, 16'h0000, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

        // --- READBACK_GPU: addr=0, count=1 ---
        pkt_words[i] = {4'h8, 12'h000, 16'h0001, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

        // --- SEND_PKT ---
        pkt_words[i] = {4'h5, 12'h000, 16'h0000, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

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
    // Monitor key signals
    // ================================================================
    wire [4:0] pp_state = dut.u_pkt_proc.state;
    wire       cpu_done = dut.cpu_done_w;
    wire       gpu_halted = dut.gpu_halted_w;
    wire       gpu_active = dut.gpu_active_r;
    wire [3:0] gpu_state = dut.u_gpu.debug_state;
    wire [9:0] gpu_pc = dut.u_gpu.debug_pc;

    always @(posedge clk) begin
        if (pp_state == 5'd8)  // P_CPU_START
            $display("[%0t] pkt_proc: CPU_START", $time);
        if (pp_state == 5'd9 && cpu_done)  // P_CPU_RUN + cpu_done
            $display("[%0t] pkt_proc: CPU done, resuming commands", $time);
    end

    reg gpu_halted_prev;
    always @(posedge clk) begin
        gpu_halted_prev <= gpu_halted;
        if (gpu_halted && !gpu_halted_prev)
            $display("[%0t] GPU halted at PC=%0d", $time, gpu_pc);
    end

    reg gpu_active_prev;
    always @(posedge clk) begin
        gpu_active_prev <= gpu_active;
        if (gpu_active && !gpu_active_prev)
            $display("[%0t] GPU started", $time);
    end

    // ================================================================
    // Main test sequence
    // ================================================================
    integer pass_count, fail_count;

    initial begin
        $dumpfile("soc_top_tb.vcd");
        $dumpvars(0, soc_top_tb);

        // Initialize
        rst_n   = 0;
        in_data = 64'h0;
        in_ctrl = 8'h0;
        in_wr   = 0;
        out_rdy = 1;
        tx_count = 0;
        pass_count = 0;
        fail_count = 0;
        gpu_halted_prev = 0;
        gpu_active_prev = 0;

        // Reset
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // Build and send the command packet
        $display("\n=== Sending command packet (%0d words) ===", pkt_len);
        build_packet;
        send_packet;

        // Wait for TX output (timeout after 100000 cycles)
        $display("\n=== Waiting for processing... ===");
        begin : wait_block
            integer cyc;
            for (cyc = 0; cyc < 100000; cyc = cyc + 1) begin
                @(posedge clk);
                if (tx_count > 0) begin
                    repeat (20) @(posedge clk);
                    disable wait_block;
                end
            end
            $display("[ERROR] Timeout waiting for TX output!");
        end

        // ================================================================
        // Verify results
        // ================================================================
        $display("\n=== Results ===");
        $display("TX words captured: %0d", tx_count);

        if (tx_count >= 1) begin
            $display("TX[0] = %016h (expected %016h)", tx_words[0], GPU_DMEM_EXPECT);
            if (tx_words[0] === GPU_DMEM_EXPECT) begin
                $display("  PASS: GPU VADD+1 result correct");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: mismatch!");
                fail_count = fail_count + 1;
            end
        end else begin
            $display("  FAIL: no TX output received");
            fail_count = fail_count + 1;
        end

        $display("\n=== Summary: %0d PASS, %0d FAIL ===\n", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
