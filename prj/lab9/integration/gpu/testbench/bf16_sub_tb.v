/* file: bf16_sub_tb.v
 Description: Testbench for BF16 SUB (op_mode=3). Tests a - b for various
   cases: basic subtraction, negative result, same value (=0), subtraction
   with fractions, and large - small.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps

module bf16_sub_tb;
    reg         clk;
    reg         rst;
    reg         run;
    reg  [9:0]  thread_id;

    wire        halted;
    wire [9:0]  debug_pc;
    wire [31:0] debug_ir;
    wire [3:0]  debug_state;

    // DMEM
    reg  [63:0] dmem [0:1023];
    wire [9:0]  gpu_dmem_addr;
    wire [63:0] gpu_dmem_wdata;
    wire        gpu_dmem_we;
    wire [63:0] gpu_dmem_rdata;

    assign gpu_dmem_rdata = dmem[gpu_dmem_addr];
    always @(posedge clk) begin
        if (gpu_dmem_we) dmem[gpu_dmem_addr] <= gpu_dmem_wdata;
    end

    gpu_top uut (
        .clk(clk), .rst(rst), .run(run),
        .thread_id(thread_id),
        .halted(halted),
        .debug_pc(debug_pc), .debug_ir(debug_ir), .debug_state(debug_state),
        .ext_imem_addr(10'd0), .ext_imem_data(32'd0), .ext_imem_we(1'b0),
        .gpu_dmem_addr(gpu_dmem_addr), .gpu_dmem_wdata(gpu_dmem_wdata),
        .gpu_dmem_we(gpu_dmem_we), .gpu_dmem_rdata(gpu_dmem_rdata)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Opcodes
    localparam [4:0] OP_TENSOR = 5'h01;
    localparam [4:0] OP_LD     = 5'h02;
    localparam [4:0] OP_ST     = 5'h03;
    localparam [4:0] OP_HALT   = 5'h0A;
    localparam [4:0] OP_MOVI   = 5'h0C;

    // BF16 constants
    // 0.0   = 0x0000
    // 1.0   = 0x3F80
    // 2.0   = 0x4000
    // 3.0   = 0x4040
    // 5.0   = 0x40A0
    // 10.0  = 0x4120
    // 0.5   = 0x3F00
    // 1.5   = 0x3FC0
    // 100.0 = 0x42C8
    // 0.25  = 0x3E80

    integer i;
    reg [63:0] result;
    integer pass_count, fail_count;

    // Helper task
    task check_lane;
        input [15:0] got, expect;
        input integer lane;
        input [8*40-1:0] desc;
        begin
            $display("  Lane %0d: got 0x%04h, expect 0x%04h  %0s", lane, got, expect, desc);
            if (got === expect) pass_count = pass_count + 1;
            else begin
                $display("    *** FAIL ***");
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("bf16_sub_tb.vcd");
        $dumpvars(0, bf16_sub_tb);
        pass_count = 0;
        fail_count = 0;

        // Init DMEM
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 64'h0;

        // ============================================================
        // Test 1: Basic subtraction  5.0 - 2.0 = 3.0
        //   All 4 lanes: A=5.0(0x40A0), B=2.0(0x4000)
        //   Expected: 3.0 = 0x4040
        // ============================================================
        dmem[0] = {16'h40A0, 16'h40A0, 16'h40A0, 16'h40A0};  // A = 5.0
        dmem[1] = {16'h4000, 16'h4000, 16'h4000, 16'h4000};  // B = 2.0

        // ============================================================
        // Test 2: Negative result  2.0 - 5.0 = -3.0
        //   -3.0 = 0xC040  (sign=1, exp=0x80, frac=0x40)
        // ============================================================
        dmem[2] = {16'h4000, 16'h4000, 16'h4000, 16'h4000};  // A = 2.0
        dmem[3] = {16'h40A0, 16'h40A0, 16'h40A0, 16'h40A0};  // B = 5.0

        // ============================================================
        // Test 3: Same value  3.0 - 3.0 = 0.0
        // ============================================================
        dmem[4] = {16'h4040, 16'h4040, 16'h4040, 16'h4040};  // A = 3.0
        dmem[5] = {16'h4040, 16'h4040, 16'h4040, 16'h4040};  // B = 3.0

        // ============================================================
        // Test 4: Fractions  1.5 - 0.5 = 1.0
        //   1.5=0x3FC0, 0.5=0x3F00, 1.0=0x3F80
        // ============================================================
        dmem[6] = {16'h3FC0, 16'h3FC0, 16'h3FC0, 16'h3FC0};  // A = 1.5
        dmem[7] = {16'h3F00, 16'h3F00, 16'h3F00, 16'h3F00};  // B = 0.5

        // ============================================================
        // Test 5: Large - small  100.0 - 0.25 = 99.75
        //   100.0=0x42C8, 0.25=0x3E80
        //   99.75: exp=133(0x85), 1.10001110 -> frac=0x47 -> 0x42A7? Let me compute:
        //   99.75 = 1.5585938 * 2^6 = 99.75
        //   2^6=64, 99.75/64 = 1.55859375 = 1 + 0.55859375
        //   0.55859375 = 0.100011110... in binary = 0x23C0000...
        //   Actually: 99.75 = 0x42C7 in BF16? Let me compute precisely.
        //   99.75 in float32: sign=0, exp=127+6=133=0x85, mantissa=(99.75/64)-1=0.55859375
        //   0.55859375 = 1/2 + 1/16 + 1/32 + 1/64 + 1/128 = 0.1000111_1 in binary
        //   BF16 truncates to 7 fraction bits: 0.1000111 = 0x47
        //   But with rounding: 8th bit is 1, so round up -> 0x48
        //   BF16 = 0_10000101_1000111 -> but wait, hidden bit, so:
        //   value = 1.1000111(1) * 2^6
        //   BF16 frac = 1000111 with round bit = 1 -> rounds to 1001000 = 0x48
        //   Hmm, let me just check: 100.0 - 0.25 with BF16 precision
        //   100.0 BF16 = 0x42C8 = 1.1001000 * 2^6 = (1+0.5+0.0625)*64 = 1.5625*64 = 100.0
        //   0.25 BF16 = 0x3E80 = 1.0000000 * 2^-2 = 0.25
        //   With BF16 7-bit mantissa: ULP at 2^6 = 2^6 * 2^-7 = 0.5
        //   So 0.25 is below ULP! Result should round to either 100.0 or 99.5
        //   99.5 = 1.5546875 * 64... no, 99.5/64 = 1.5546875 = 1 + 0.5546875
        //   0.5546875 in binary = 0.1000111 = 0x47
        //   So 99.5 BF16 = 0_10000101_1000111 = 0x42C7
        //   With round-to-nearest-even: 99.75 is exactly between 99.5 and 100.0
        //   99.5 = 0x42C7, 100.0 = 0x42C8. Midpoint rounds to even -> 0x42C8 (even frac)
        //   So result should be 0x42C8 (rounds back to 100.0)
        // ============================================================
        dmem[8] = {16'h42C8, 16'h42C8, 16'h42C8, 16'h42C8};  // A = 100.0
        dmem[9] = {16'h3E80, 16'h3E80, 16'h3E80, 16'h3E80};  // B = 0.25

        // ============================================================
        // Test 6: Mixed per-lane values
        //   Lane 3: 10.0 - 3.0 = 7.0  (0x40E0)
        //   Lane 2:  5.0 - 5.0 = 0.0  (0x0000)
        //   Lane 1:  1.0 - 2.0 = -1.0 (0xBF80)
        //   Lane 0:  3.0 - 1.5 = 1.5  (0x3FC0)
        // ============================================================
        dmem[10] = {16'h4120, 16'h40A0, 16'h3F80, 16'h4040};  // A
        dmem[11] = {16'h4040, 16'h40A0, 16'h4000, 16'h3FC0};  // B

        // GPU program:
        // For each test pair at dmem[2*t] and dmem[2*t+1]:
        //   LD R4, Rptr, 0     -- load A
        //   LD R5, Rptr, 1     -- load B
        //   TENSOR R2, R4, R5, R0, func=0, mode=3  -- R2 = R4 - R5 (BF16 SUB)
        //   ST R2, R0, <result_addr>
        //   ADDI Rptr, Rptr, 2

        // R8 = data pointer (starts at 0)
        // R0 = 0 (hardwired)
        uut.imem_inst.mem[0]  = {OP_MOVI, 5'd8, 5'd0, 17'd0};        // R8 = 0

        // Test 1: A=dmem[0], B=dmem[1], result -> dmem[100]
        uut.imem_inst.mem[1]  = {OP_LD, 5'd4, 5'd8, 17'd0};          // LD R4, R8, 0
        uut.imem_inst.mem[2]  = {OP_LD, 5'd5, 5'd8, 17'd1};          // LD R5, R8, 1
        uut.imem_inst.mem[3]  = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3}; // SUB
        uut.imem_inst.mem[4]  = {OP_ST, 5'd2, 5'd0, 17'd100};        // ST -> dmem[100]

        // Test 2: A=dmem[2], B=dmem[3], result -> dmem[101]
        uut.imem_inst.mem[5]  = {OP_LD, 5'd4, 5'd8, 17'd2};
        uut.imem_inst.mem[6]  = {OP_LD, 5'd5, 5'd8, 17'd3};
        uut.imem_inst.mem[7]  = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3};
        uut.imem_inst.mem[8]  = {OP_ST, 5'd2, 5'd0, 17'd101};

        // Test 3: A=dmem[4], B=dmem[5], result -> dmem[102]
        uut.imem_inst.mem[9]  = {OP_LD, 5'd4, 5'd8, 17'd4};
        uut.imem_inst.mem[10] = {OP_LD, 5'd5, 5'd8, 17'd5};
        uut.imem_inst.mem[11] = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3};
        uut.imem_inst.mem[12] = {OP_ST, 5'd2, 5'd0, 17'd102};

        // Test 4: A=dmem[6], B=dmem[7], result -> dmem[103]
        uut.imem_inst.mem[13] = {OP_LD, 5'd4, 5'd8, 17'd6};
        uut.imem_inst.mem[14] = {OP_LD, 5'd5, 5'd8, 17'd7};
        uut.imem_inst.mem[15] = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3};
        uut.imem_inst.mem[16] = {OP_ST, 5'd2, 5'd0, 17'd103};

        // Test 5: A=dmem[8], B=dmem[9], result -> dmem[104]
        uut.imem_inst.mem[17] = {OP_LD, 5'd4, 5'd8, 17'd8};
        uut.imem_inst.mem[18] = {OP_LD, 5'd5, 5'd8, 17'd9};
        uut.imem_inst.mem[19] = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3};
        uut.imem_inst.mem[20] = {OP_ST, 5'd2, 5'd0, 17'd104};

        // Test 6: A=dmem[10], B=dmem[11], result -> dmem[105]
        uut.imem_inst.mem[21] = {OP_LD, 5'd4, 5'd8, 17'd10};
        uut.imem_inst.mem[22] = {OP_LD, 5'd5, 5'd8, 17'd11};
        uut.imem_inst.mem[23] = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd0, 4'd0, 3'd3};
        uut.imem_inst.mem[24] = {OP_ST, 5'd2, 5'd0, 17'd105};

        uut.imem_inst.mem[25] = {OP_HALT, 5'd0, 5'd0, 17'd0};

        // Reset + run
        rst = 1; run = 0; thread_id = 10'd0;
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("========================================");
        $display("  BF16 SUB Test (op_mode=3)");
        $display("========================================");

        run = 1; @(posedge clk); run = 0;

        // Wait for halt
        begin : wait_halt
            integer timeout;
            timeout = 0;
            while (!halted && timeout < 2000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!halted)
                $display("[TIMEOUT]");
            else
                $display("  Completed in %0d cycles", timeout);
        end

        repeat(2) @(posedge clk);

        // Check results
        $display("\n=== Test 1: 5.0 - 2.0 = 3.0 ===");
        result = dmem[100];
        check_lane(result[63:48], 16'h4040, 3, "3.0");
        check_lane(result[47:32], 16'h4040, 2, "3.0");
        check_lane(result[31:16], 16'h4040, 1, "3.0");
        check_lane(result[15:0],  16'h4040, 0, "3.0");

        $display("\n=== Test 2: 2.0 - 5.0 = -3.0 ===");
        result = dmem[101];
        check_lane(result[63:48], 16'hC040, 3, "-3.0");
        check_lane(result[47:32], 16'hC040, 2, "-3.0");
        check_lane(result[31:16], 16'hC040, 1, "-3.0");
        check_lane(result[15:0],  16'hC040, 0, "-3.0");

        $display("\n=== Test 3: 3.0 - 3.0 = 0.0 ===");
        result = dmem[102];
        check_lane(result[63:48], 16'h0000, 3, "0.0");
        check_lane(result[47:32], 16'h0000, 2, "0.0");
        check_lane(result[31:16], 16'h0000, 1, "0.0");
        check_lane(result[15:0],  16'h0000, 0, "0.0");

        $display("\n=== Test 4: 1.5 - 0.5 = 1.0 ===");
        result = dmem[103];
        check_lane(result[63:48], 16'h3F80, 3, "1.0");
        check_lane(result[47:32], 16'h3F80, 2, "1.0");
        check_lane(result[31:16], 16'h3F80, 1, "1.0");
        check_lane(result[15:0],  16'h3F80, 0, "1.0");

        $display("\n=== Test 5: 100.0 - 0.25 (below ULP, rounds to 100.0) ===");
        result = dmem[104];
        check_lane(result[63:48], 16'h42C8, 3, "100.0");
        check_lane(result[47:32], 16'h42C8, 2, "100.0");
        check_lane(result[31:16], 16'h42C8, 1, "100.0");
        check_lane(result[15:0],  16'h42C8, 0, "100.0");

        $display("\n=== Test 6: Mixed per-lane ===");
        result = dmem[105];
        check_lane(result[63:48], 16'h40E0, 3, "10-3=7.0");
        check_lane(result[47:32], 16'h0000, 2, "5-5=0.0");
        check_lane(result[31:16], 16'hBF80, 1, "1-2=-1.0");
        check_lane(result[15:0],  16'h3FC0, 0, "3-1.5=1.5");

        $display("\n========================================");
        $display("  %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        $finish;
    end
endmodule
