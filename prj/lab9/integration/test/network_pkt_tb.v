/* file: network_pkt_tb.v
Description: Tests the network packet path (with module header + Ethernet header).
   Verifies:
   1. conv_fifo EOP ctrl on last TX word (Bug fix #1)
   2. pkt_proc updates module header byte_len/word_len for response (Bug fix #2)
   3. VADD+1 computation result is correct
Author: Raymond
Date: Mar. 12, 2026
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

module network_pkt_tb;

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
    // TX capture
    // ================================================================
    reg [63:0] tx_words [0:31];
    reg [7:0]  tx_ctrl  [0:31];
    integer    tx_count;

    always @(posedge clk) begin
        if (out_wr && out_rdy) begin
            tx_words[tx_count] = out_data;
            tx_ctrl[tx_count]  = out_ctrl;
            tx_count = tx_count + 1;
            $display("[TX] word %0d: data=%016h ctrl=%02h", tx_count-1, out_data, out_ctrl);
        end
    end

    // ================================================================
    // NetFPGA module header constants (NF_2.1_defines.v)
    // ================================================================
    localparam IOQ_BYTE_LEN_POS = 0;
    localparam IOQ_SRC_PORT_POS = 16;
    localparam IOQ_WORD_LEN_POS = 32;
    localparam IOQ_DST_PORT_POS = 48;
    localparam IO_QUEUE_STAGE_NUM = 8'hFF;

    // ================================================================
    // ARM instruction encodings
    // ================================================================
    localparam [31:0] ARM_MOV_R0_1   = 32'hE3A00001;
    localparam [31:0] ARM_MCR_CR5_R0 = 32'hEE050A10;
    localparam [31:0] ARM_MRC_CR6_R1 = 32'hEE161A10;
    localparam [31:0] ARM_TST_R1_1   = 32'hE3110001;
    localparam [31:0] ARM_BEQ_POLL   = 32'h0AFFFFFC;
    localparam [31:0] ARM_HALT       = 32'hEAFFFFFE;

    // ================================================================
    // GPU instruction encodings
    // ================================================================
    localparam [31:0] GPU_MOVI_R1_1    = {5'h0C, 5'd1, 5'd0, 17'd1};
    localparam [31:0] GPU_LD_R2_R0_0   = {5'h02, 5'd2, 5'd0, 17'd0};
    localparam [31:0] GPU_VADD_R3_R2_R1 = {5'h00, 5'd3, 5'd2, 5'd1, 5'd0, 4'd0, 3'd0};
    localparam [31:0] GPU_ST_R3_R0_0   = {5'h03, 5'd3, 5'd0, 17'd0};
    localparam [31:0] GPU_HALT         = {5'h0A, 27'd0};

    // ================================================================
    // GPU DMEM test data
    // ================================================================
    localparam [63:0] GPU_DMEM_INIT   = 64'h0003_0002_0001_0000;
    localparam [63:0] GPU_DMEM_EXPECT = 64'h0003_0002_0001_0001;

    // ================================================================
    // Build network-style command packet
    // Like what tcpreplay sends: module_hdr + eth_hdr + commands
    // ================================================================
    reg [63:0] pkt_words [0:31];
    reg [7:0]  pkt_ctrl  [0:31];
    integer    pkt_len;

    task build_network_packet;
        integer i;
        reg [15:0] src_port, dst_port;
        reg [15:0] word_len, byte_len;
        integer cmd_start;
    begin
        i = 0;

        // --- Word 0: Module header ---
        // Mimics what output_port_lookup would produce:
        //   dst_port = 0x0002 (CPU port 0 = nf2c1)
        //   src_port = 0x0001 (MAC port 0 = nf2c0)
        src_port = 16'h0001;
        dst_port = 16'h0002;
        // word_len and byte_len: we'll set them to the ORIGINAL (incoming) sizes
        // (deliberately wrong for response, to test that pkt_proc fixes them)
        word_len = 16'd99;  // intentionally wrong
        byte_len = 16'd792; // intentionally wrong (99*8)
        pkt_words[i] = {dst_port, word_len, src_port, byte_len};
        pkt_ctrl[i]  = IO_QUEUE_STAGE_NUM;  // 0xFF = module header
        i = i + 1;

        // --- Word 1: Ethernet header part 1 ---
        // DST_MAC[47:0] + SRC_MAC[47:16]
        // DST_MAC = 00:01:02:03:04:05, SRC_MAC = 06:07:08:09:0a:0b
        pkt_words[i] = 64'h000102030405_0607;
        pkt_ctrl[i]  = 8'h00;
        i = i + 1;

        // --- Word 2: Ethernet header part 2 ---
        // SRC_MAC[15:0] + EtherType(0x88B5) + Pad(0x0000)
        pkt_words[i] = 64'h08090a0b_88B5_0000;
        pkt_ctrl[i]  = 8'h00;
        i = i + 1;

        // --- Commands start here (word 3+) ---
        cmd_start = i;

        // LOAD_IMEM: addr=0, count=3
        pkt_words[i] = {4'h1, 12'h000, 16'h0003, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_MCR_CR5_R0, ARM_MOV_R0_1};    pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_TST_R1_1,   ARM_MRC_CR6_R1};  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {ARM_HALT,        ARM_BEQ_POLL};    pkt_ctrl[i] = 8'h00; i = i + 1;

        // LOAD_GPU_IMEM: addr=0, count=3
        pkt_words[i] = {4'h6, 12'h000, 16'h0003, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {GPU_LD_R2_R0_0,  GPU_MOVI_R1_1};  pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {GPU_ST_R3_R0_0,  GPU_VADD_R3_R2_R1}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = {32'h0,           GPU_HALT};         pkt_ctrl[i] = 8'h00; i = i + 1;

        // LOAD_GPU_DMEM: addr=0, count=1
        pkt_words[i] = {4'h7, 12'h000, 16'h0001, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;
        pkt_words[i] = GPU_DMEM_INIT;                      pkt_ctrl[i] = 8'h00; i = i + 1;

        // CPU_START: entry_pc = 0
        pkt_words[i] = {4'h3, 12'h000, 16'h0000, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

        // READBACK_GPU: addr=0, count=1
        pkt_words[i] = {4'h8, 12'h000, 16'h0001, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

        // SEND_PKT
        pkt_words[i] = {4'h5, 12'h000, 16'h0000, 32'h0}; pkt_ctrl[i] = 8'h00; i = i + 1;

        pkt_len = i;
        $display("Network packet: %0d words total (%0d header + %0d commands)",
                 pkt_len, cmd_start, pkt_len - cmd_start);
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
    // Main test
    // ================================================================
    integer pass_count, fail_count;

    initial begin
        $dumpfile("network_pkt_tb.vcd");
        $dumpvars(0, network_pkt_tb);

        rst_n   = 0;
        in_data = 64'h0;
        in_ctrl = 8'h0;
        in_wr   = 0;
        out_rdy = 1;
        tx_count = 0;
        pass_count = 0;
        fail_count = 0;

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("\n=== Test: Network packet with Ethernet headers ===");
        build_network_packet;
        send_packet;

        // Wait for TX
        $display("=== Waiting for TX output... ===");
        begin : wait_block
            integer cyc;
            for (cyc = 0; cyc < 100000; cyc = cyc + 1) begin
                @(posedge clk);
                if (tx_count > 0) begin
                    repeat (50) @(posedge clk);
                    disable wait_block;
                end
            end
            $display("[ERROR] Timeout waiting for TX output!");
            fail_count = fail_count + 1;
        end

        // ================================================================
        // Verify
        // ================================================================
        $display("\n=== TX Capture: %0d words ===", tx_count);

        // --- Check 1: Module header (word 0) ---
        if (tx_count >= 1) begin
            $display("\n--- Check 1: Module header ---");
            $display("TX[0] = %016h  ctrl=%02h", tx_words[0], tx_ctrl[0]);

            // ctrl should be IO_QUEUE_STAGE_NUM (0xFF)
            if (tx_ctrl[0] === IO_QUEUE_STAGE_NUM) begin
                $display("  PASS: Module header ctrl = 0x%02h", tx_ctrl[0]);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Module header ctrl = 0x%02h (expected 0xFF)", tx_ctrl[0]);
                fail_count = fail_count + 1;
            end

            // Check dst_port preserved
            if (tx_words[0][63:48] === 16'h0002) begin
                $display("  PASS: dst_port = 0x%04h", tx_words[0][63:48]);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: dst_port = 0x%04h (expected 0x0002)", tx_words[0][63:48]);
                fail_count = fail_count + 1;
            end

            // Check src_port preserved
            if (tx_words[0][31:16] === 16'h0001) begin
                $display("  PASS: src_port = 0x%04h", tx_words[0][31:16]);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: src_port = 0x%04h (expected 0x0001)", tx_words[0][31:16]);
                fail_count = fail_count + 1;
            end

            // Check word_len updated (should be tx_count-1, not 99)
            // Response = module_hdr(1) + eth_hdr(2) + readback(1) = 4 words total
            // word_len = 4 - 1 = 3 (data words excluding module header)
            begin : check_lengths
                reg [15:0] got_word_len, got_byte_len;
                reg [15:0] exp_word_len, exp_byte_len;
                got_word_len = tx_words[0][47:32];
                got_byte_len = tx_words[0][15:0];
                exp_word_len = tx_count - 1;
                exp_byte_len = (tx_count - 1) * 8;

                $display("\n--- Check 2: Response lengths (Bug fix #2) ---");
                $display("  word_len = %0d (expected %0d)", got_word_len, exp_word_len);
                if (got_word_len === exp_word_len) begin
                    $display("  PASS: word_len correct");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: word_len wrong (was %0d, old buggy value would be 99)", got_word_len);
                    fail_count = fail_count + 1;
                end

                $display("  byte_len = %0d (expected %0d)", got_byte_len, exp_byte_len);
                if (got_byte_len === exp_byte_len) begin
                    $display("  PASS: byte_len correct");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: byte_len wrong", got_byte_len);
                    fail_count = fail_count + 1;
                end
            end
        end else begin
            $display("  FAIL: No TX output (EOP bug not fixed?)");
            fail_count = fail_count + 1;
        end

        // --- Check 3: EOP ctrl on last word ---
        if (tx_count >= 2) begin
            $display("\n--- Check 3: EOP ctrl on last word (Bug fix #1) ---");
            $display("  Last word TX[%0d] ctrl = 0x%02h", tx_count-1, tx_ctrl[tx_count-1]);
            if (tx_ctrl[tx_count-1] === 8'h80) begin
                $display("  PASS: EOP ctrl = 0x80 (all 8 bytes valid)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: EOP ctrl = 0x%02h (expected 0x80)", tx_ctrl[tx_count-1]);
                fail_count = fail_count + 1;
            end

            // Middle words should have ctrl=0
            begin : check_middle_ctrl
                integer ok;
                integer w;
                ok = 1;
                for (w = 1; w < tx_count-1; w = w + 1) begin
                    if (tx_ctrl[w] !== 8'h00) begin
                        $display("  FAIL: TX[%0d] ctrl = 0x%02h (expected 0x00)", w, tx_ctrl[w]);
                        ok = 0;
                    end
                end
                if (ok) begin
                    $display("  PASS: Middle words all have ctrl=0x00");
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                end
            end
        end

        // --- Check 4: Ethernet header preserved ---
        if (tx_count >= 3) begin
            $display("\n--- Check 4: Ethernet header preserved ---");
            if (tx_words[1] === 64'h000102030405_0607 && tx_words[2] === 64'h08090a0b_88B5_0000) begin
                $display("  PASS: Ethernet header intact");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Ethernet header corrupted");
                $display("    TX[1] = %016h (expected 0001020304050607)", tx_words[1]);
                $display("    TX[2] = %016h (expected 08090a0b88b50000)", tx_words[2]);
                fail_count = fail_count + 1;
            end
        end

        // --- Check 5: GPU computation result ---
        if (tx_count >= 4) begin
            $display("\n--- Check 5: GPU VADD+1 result ---");
            $display("  TX[3] = %016h (expected %016h)", tx_words[3], GPU_DMEM_EXPECT);
            if (tx_words[3] === GPU_DMEM_EXPECT) begin
                $display("  PASS: VADD+1 result correct");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: VADD+1 result mismatch");
                fail_count = fail_count + 1;
            end
        end

        // ================================================================
        // Summary
        // ================================================================
        $display("\n============================================================");
        $display("  %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("============================================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("============================================================\n");

        $finish;
    end

endmodule
