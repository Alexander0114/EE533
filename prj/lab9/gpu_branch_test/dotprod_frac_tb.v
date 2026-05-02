/* file: dotprod_frac_tb.v
 Description: BF16 dot product testbench with non-zero fractions. Tests
   per-lane values A={1.5, 2.5, 3.0, 0.5}, B={2.0, 0.5, 1.0, 4.0}.
   Test 1: N=16, exact BF16 match. Test 2: N=256, long accumulation with
   BF16 rounding tolerance check.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps

module dotprod_frac_tb;
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
    localparam [4:0] OP_BNE    = 5'h05;
    localparam [4:0] OP_ADDI   = 5'h09;
    localparam [4:0] OP_HALT   = 5'h0A;
    localparam [4:0] OP_MOVI   = 5'h0C;

    // BF16 constants
    // 1.5  = 0x3FC0  (1.1 × 2^0)
    // 2.5  = 0x4020  (1.01 × 2^1)
    // 3.0  = 0x4040  (1.1 × 2^1)
    // 0.5  = 0x3F00  (1.0 × 2^-1)
    // 2.0  = 0x4000  (1.0 × 2^1)
    // 4.0  = 0x4080  (1.0 × 2^2)
    // 1.0  = 0x3F80  (1.0 × 2^0)

    localparam N = 16;        // 16 words per vector
    localparam B_BASE = 128;  // B starts at DMEM[128]

    // A word: {lane3=1.5, lane2=2.5, lane1=3.0, lane0=0.5}
    localparam [63:0] A_WORD = {16'h3FC0, 16'h4020, 16'h4040, 16'h3F00};
    // B word: {lane3=2.0, lane2=0.5, lane1=1.0, lane0=4.0}
    localparam [63:0] B_WORD = {16'h4000, 16'h3F00, 16'h3F80, 16'h4080};

    // Per-lane products:
    //   Lane 3: 1.5 × 2.0 = 3.0   →  16 × 3.0  = 48.0   BF16=0x4240
    //   Lane 2: 2.5 × 0.5 = 1.25  →  16 × 1.25 = 20.0   BF16=0x41A0
    //   Lane 1: 3.0 × 1.0 = 3.0   →  16 × 3.0  = 48.0   BF16=0x4240
    //   Lane 0: 0.5 × 4.0 = 2.0   →  16 × 2.0  = 32.0   BF16=0x4200
    localparam [63:0] EXPECTED = {16'h4240, 16'h41A0, 16'h4240, 16'h4200};

    integer i;
    reg [63:0] result;
    integer pass_count, fail_count;

    initial begin
        $dumpfile("dotprod_frac_tb.vcd");
        $dumpvars(0, dotprod_frac_tb);
        pass_count = 0;
        fail_count = 0;

        // Init DMEM
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 64'h0;
        for (i = 0; i < N; i = i + 1) dmem[i] = A_WORD;
        for (i = 0; i < N; i = i + 1) dmem[B_BASE + i] = B_WORD;

        // GPU program: same dot product loop
        uut.imem_inst.mem[0]  = {OP_MOVI, 5'd8, 5'd0, 17'd0};        // R8 = 0 (A ptr)
        uut.imem_inst.mem[1]  = {OP_MOVI, 5'd9, 5'd0, 17'd128};      // R9 = 128 (B ptr)
        uut.imem_inst.mem[2]  = {OP_MOVI, 5'd2, 5'd0, 17'd0};        // R2 = 0 (acc)
        uut.imem_inst.mem[3]  = {OP_MOVI, 5'd3, 5'd0, {7'd0, 10'd16}};  // R3 = 16
        uut.imem_inst.mem[4]  = {OP_MOVI, 5'd7, 5'd0, 17'd0};        // R7 = 0

        // Loop (addr 5-11)
        uut.imem_inst.mem[5]  = {OP_LD, 5'd4, 5'd8, 17'd0};          // LD R4, R8, 0
        uut.imem_inst.mem[6]  = {OP_LD, 5'd5, 5'd9, 17'd0};          // LD R5, R9, 0
        uut.imem_inst.mem[7]  = {OP_TENSOR, 5'd2, 5'd4, 5'd5, 5'd2, 4'd0, 3'd2}; // FMA
        uut.imem_inst.mem[8]  = {OP_ADDI, 5'd8, 5'd8, 17'd1};        // R8++
        uut.imem_inst.mem[9]  = {OP_ADDI, 5'd9, 5'd9, 17'd1};        // R9++
        uut.imem_inst.mem[10] = {OP_ADDI, 5'd3, 5'd3, 17'h1FFFF};    // R3--
        uut.imem_inst.mem[11] = {OP_BNE, 5'd3, 5'd7, 17'h1FFFA};     // BNE R3,R7,-6

        uut.imem_inst.mem[12] = {OP_ST, 5'd2, 5'd7, 17'd512};        // ST R2 -> dmem[512]
        uut.imem_inst.mem[13] = {OP_HALT, 5'd0, 5'd0, 17'd0};

        // Reset + run
        rst = 1; run = 0; thread_id = 10'd0;
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("========================================");
        $display("  BF16 Dot Product — Non-zero Fractions");
        $display("  N=%0d words, 4 lanes, different values per lane", N);
        $display("  A lanes: {1.5, 2.5, 3.0, 0.5}");
        $display("  B lanes: {2.0, 0.5, 1.0, 4.0}");
        $display("========================================");

        run = 1; @(posedge clk); run = 0;

        // Wait
        begin : wait_halt
            integer timeout;
            timeout = 0;
            while (!halted && timeout < 5000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!halted)
                $display("[TIMEOUT]");
            else
                $display("  Completed in %0d cycles", timeout);
        end

        repeat(2) @(posedge clk);
        result = dmem[512];

        $display("\n=== Test 1: N=%0d, exact BF16 check ===", N);
        $display("Lane 3: got 0x%04h, expect 0x%04h (48.0 = 16 × 1.5 × 2.0)",
                 result[63:48], EXPECTED[63:48]);
        $display("Lane 2: got 0x%04h, expect 0x%04h (20.0 = 16 × 2.5 × 0.5)",
                 result[47:32], EXPECTED[47:32]);
        $display("Lane 1: got 0x%04h, expect 0x%04h (48.0 = 16 × 3.0 × 1.0)",
                 result[31:16], EXPECTED[31:16]);
        $display("Lane 0: got 0x%04h, expect 0x%04h (32.0 = 16 × 0.5 × 4.0)",
                 result[15:0], EXPECTED[15:0]);

        if (result === EXPECTED) begin
            $display("[PASS] All lanes exact match");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Mismatch!");
            fail_count = fail_count + 1;
        end

        // ============================================================
        // Test 2: Longer vector (N=256) — stress test
        // ============================================================
        // Reload vectors
        for (i = 0; i < 256; i = i + 1) dmem[i] = A_WORD;
        for (i = 0; i < 256; i = i + 1) dmem[256 + i] = B_WORD;

        // Update IMEM for N=256
        uut.imem_inst.mem[1]  = {OP_MOVI, 5'd9, 5'd0, 17'd256};      // R9 = 256
        uut.imem_inst.mem[3]  = {OP_MOVI, 5'd3, 5'd0, 17'd256};      // R3 = 256

        // Reset GPU and run again
        rst = 1;
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        run = 1; @(posedge clk); run = 0;

        begin : wait_halt2
            integer timeout2;
            timeout2 = 0;
            while (!halted && timeout2 < 20000) begin
                @(posedge clk);
                timeout2 = timeout2 + 1;
            end
            if (!halted)
                $display("\n[TIMEOUT] Test 2");
            else
                $display("\n  Test 2: Completed in %0d cycles", timeout2);
        end

        repeat(2) @(posedge clk);
        result = dmem[512];

        // Expected (exact math):
        //   Lane 3: 256 × 3.0  = 768.0   BF16=0x4440
        //   Lane 2: 256 × 1.25 = 320.0   BF16=0x43A0
        //   Lane 1: 256 × 3.0  = 768.0   BF16=0x4440
        //   Lane 0: 256 × 2.0  = 512.0   BF16=0x4400
        // (BF16 rounding may cause slight deviations)

        $display("\n=== Test 2: N=256, long accumulation ===");
        $display("Lane 3: got 0x%04h, exact=0x4440 (768.0 = 256 × 1.5 × 2.0)", result[63:48]);
        $display("Lane 2: got 0x%04h, exact=0x43A0 (320.0 = 256 × 2.5 × 0.5)", result[47:32]);
        $display("Lane 1: got 0x%04h, exact=0x4440 (768.0 = 256 × 3.0 × 1.0)", result[31:16]);
        $display("Lane 0: got 0x%04h, exact=0x4400 (512.0 = 256 × 0.5 × 4.0)", result[15:0]);

        // Allow ±1 ULP tolerance for BF16 rounding
        if (result === {16'h4440, 16'h43A0, 16'h4440, 16'h4400}) begin
            $display("[PASS] Exact match (no rounding error)");
            pass_count = pass_count + 1;
        end else begin
            // Check if close (within 2 ULP per lane)
            $display("[INFO] Checking with BF16 rounding tolerance...");
            if (result[63:48] >= 16'h443E && result[63:48] <= 16'h4442 &&
                result[47:32] >= 16'h439E && result[47:32] <= 16'h43A2 &&
                result[31:16] >= 16'h443E && result[31:16] <= 16'h4442 &&
                result[15:0]  >= 16'h43FE && result[15:0]  <= 16'h4402) begin
                $display("[PASS] Within BF16 rounding tolerance");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Result outside tolerance");
                fail_count = fail_count + 1;
            end
        end

        $display("\n========================================");
        $display("  %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        $finish;
    end
endmodule
