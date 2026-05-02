/* file: wmma_tb.v
 Description: Testbench for 4x4 BF16 tensor core WMMA operation. Tests
   D = A * B + C using the full GPU pipeline (gpu_top) with WMMA instruction.
   Loads matrices into register file, executes WMMA, and verifies results.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps

module wmma_tb;

    reg         clk, rst, run;
    reg  [9:0]  thread_id;
    wire        halted;
    wire [9:0]  debug_pc;
    wire [31:0] debug_ir;
    wire [3:0]  debug_state;

    reg  [9:0]  ext_imem_addr;
    reg  [31:0] ext_imem_data;
    reg         ext_imem_we;

    wire [9:0]  gpu_dmem_addr;
    wire [63:0] gpu_dmem_wdata;
    wire        gpu_dmem_we;
    reg  [63:0] gpu_dmem_rdata;

    gpu_top uut (
        .clk(clk), .rst(rst), .run(run),
        .thread_id(thread_id), .halted(halted),
        .debug_pc(debug_pc), .debug_ir(debug_ir), .debug_state(debug_state),
        .ext_imem_addr(ext_imem_addr), .ext_imem_data(ext_imem_data),
        .ext_imem_we(ext_imem_we),
        .gpu_dmem_addr(gpu_dmem_addr), .gpu_dmem_wdata(gpu_dmem_wdata),
        .gpu_dmem_we(gpu_dmem_we), .gpu_dmem_rdata(gpu_dmem_rdata)
    );

    // Clock: 10ns period
    always #5 clk = ~clk;

    // BF16 constants
    // 1.0 = 0x3F80, 2.0 = 0x4000, 3.0 = 0x4040, 4.0 = 0x4080
    // 0.0 = 0x0000, 0.5 = 0x3F00, 1.5 = 0x3FC0
    localparam [15:0] BF16_0 = 16'h0000;
    localparam [15:0] BF16_1 = 16'h3F80;
    localparam [15:0] BF16_2 = 16'h4000;
    localparam [15:0] BF16_3 = 16'h4040;
    localparam [15:0] BF16_4 = 16'h4080;

    // ISA encoding helpers
    // OP_TENSOR = 5'h01
    // WMMA: OP_TENSOR rd, ra, rb, rc, func=0, mode=4
    // IR = {opcode[31:27], rd[26:22], ra[21:17], rb[16:12], rc[11:7], func[6:3], mode[2:0]}
    function [31:0] encode_wmma;
        input [4:0] rd, ra, rb, rc;
        encode_wmma = {5'h01, rd, ra, rb, rc, 4'b0000, 3'd4};
    endfunction

    // OP_MOVI = 5'h0C: {opcode, rd, imm17}
    function [31:0] encode_movi;
        input [4:0] rd;
        input [16:0] imm;
        encode_movi = {5'h0C, rd, imm};
    endfunction

    // OP_LUI = 5'h08: {opcode, rd, imm17}
    function [31:0] encode_lui;
        input [4:0] rd;
        input [16:0] imm;
        encode_lui = {5'h08, rd, imm};
    endfunction

    // OP_HALT = 5'h0A
    localparam [31:0] HALT_INSTR = {5'h0A, 27'b0};

    // Task: write instruction to IMEM
    task write_imem;
        input [9:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            ext_imem_addr <= addr;
            ext_imem_data <= data;
            ext_imem_we   <= 1'b1;
            @(posedge clk);
            ext_imem_we   <= 1'b0;
        end
    endtask

    // Task: directly load register file (backdoor for test setup)
    task load_reg;
        input [4:0] addr;
        input [63:0] data;
        begin
            // Force write through RF
            @(posedge clk);
            force uut.rf_inst.we = 1'b1;
            force uut.rf_inst.w_addr = addr;
            force uut.rf_inst.w_data = data;
            @(posedge clk);
            release uut.rf_inst.we;
            release uut.rf_inst.w_addr;
            release uut.rf_inst.w_data;
        end
    endtask

    integer pass_count, fail_count;
    reg [63:0] expected;

    task check_reg;
        input [4:0] addr;
        input [63:0] exp;
        reg [63:0] actual;
        begin
            actual = uut.rf_inst.rf[addr];
            if (actual === exp) begin
                $display("  PASS: R%0d = %h (expected %h)", addr, actual, exp);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: R%0d = %h (expected %h)", addr, actual, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("wmma_tb.vcd");
        $dumpvars(0, wmma_tb);

        clk = 0; rst = 1; run = 0;
        thread_id = 10'd0;
        ext_imem_addr = 0;
        ext_imem_data = 0;
        ext_imem_we = 0;
        gpu_dmem_rdata = 0;
        pass_count = 0;
        fail_count = 0;

        // ============================================================
        // Test 1: Identity * Identity + Zero = Identity
        // A = I4, B = I4, C = 0 => D = I4
        // ============================================================
        $display("\n=== Test 1: I * I + 0 = I ===");

        // Load program during reset
        // Program: just WMMA R20, R4, R8, R12 then HALT
        // A = R4-R7, B = R8-R11, C = R12-R15, D = R20-R23
        write_imem(10'd0, encode_wmma(5'd20, 5'd4, 5'd8, 5'd12));
        write_imem(10'd1, HALT_INSTR);

        // Release reset
        @(posedge clk); rst <= 0;
        @(posedge clk);

        // Load A = Identity matrix (BF16)
        // Row 0: [1, 0, 0, 0] => {0x0000, 0x0000, 0x0000, 0x3F80}
        load_reg(5'd4,  {BF16_0, BF16_0, BF16_0, BF16_1});
        load_reg(5'd5,  {BF16_0, BF16_0, BF16_1, BF16_0});
        load_reg(5'd6,  {BF16_0, BF16_1, BF16_0, BF16_0});
        load_reg(5'd7,  {BF16_1, BF16_0, BF16_0, BF16_0});

        // Load B = Identity matrix
        load_reg(5'd8,  {BF16_0, BF16_0, BF16_0, BF16_1});
        load_reg(5'd9,  {BF16_0, BF16_0, BF16_1, BF16_0});
        load_reg(5'd10, {BF16_0, BF16_1, BF16_0, BF16_0});
        load_reg(5'd11, {BF16_1, BF16_0, BF16_0, BF16_0});

        // Load C = Zero matrix
        load_reg(5'd12, 64'h0);
        load_reg(5'd13, 64'h0);
        load_reg(5'd14, 64'h0);
        load_reg(5'd15, 64'h0);

        // Run GPU
        @(posedge clk); run <= 1;
        @(posedge clk); run <= 0;

        // Wait for halt
        wait(halted);
        @(posedge clk); @(posedge clk);

        // Check D = Identity
        check_reg(5'd20, {BF16_0, BF16_0, BF16_0, BF16_1});
        check_reg(5'd21, {BF16_0, BF16_0, BF16_1, BF16_0});
        check_reg(5'd22, {BF16_0, BF16_1, BF16_0, BF16_0});
        check_reg(5'd23, {BF16_1, BF16_0, BF16_0, BF16_0});

        // ============================================================
        // Test 2: A * I + C = A + C
        // A = [[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]]
        // B = I4, C = [[1,1,1,1],...] => D = [[2,3,4,5],...]
        // ============================================================
        $display("\n=== Test 2: A * I + C = A + C ===");

        // Reset for new test
        @(posedge clk); rst <= 1;
        @(posedge clk); @(posedge clk);

        // Write program
        write_imem(10'd0, encode_wmma(5'd20, 5'd4, 5'd8, 5'd12));
        write_imem(10'd1, HALT_INSTR);

        @(posedge clk); rst <= 0;
        @(posedge clk);

        // A = all rows [1, 2, 3, 4]
        // Row format: [63:48]=col3, [47:32]=col2, [31:16]=col1, [15:0]=col0
        load_reg(5'd4,  {BF16_4, BF16_3, BF16_2, BF16_1});
        load_reg(5'd5,  {BF16_4, BF16_3, BF16_2, BF16_1});
        load_reg(5'd6,  {BF16_4, BF16_3, BF16_2, BF16_1});
        load_reg(5'd7,  {BF16_4, BF16_3, BF16_2, BF16_1});

        // B = Identity
        load_reg(5'd8,  {BF16_0, BF16_0, BF16_0, BF16_1});
        load_reg(5'd9,  {BF16_0, BF16_0, BF16_1, BF16_0});
        load_reg(5'd10, {BF16_0, BF16_1, BF16_0, BF16_0});
        load_reg(5'd11, {BF16_1, BF16_0, BF16_0, BF16_0});

        // C = all 1s
        load_reg(5'd12, {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd13, {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd14, {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd15, {BF16_1, BF16_1, BF16_1, BF16_1});

        @(posedge clk); run <= 1;
        @(posedge clk); run <= 0;

        wait(halted);
        @(posedge clk); @(posedge clk);

        // D = A + C = [[2,3,4,5],[2,3,4,5],[2,3,4,5],[2,3,4,5]]
        // 5.0 = 0x40A0
        check_reg(5'd20, {16'h40A0, BF16_4, BF16_3, BF16_2});
        check_reg(5'd21, {16'h40A0, BF16_4, BF16_3, BF16_2});
        check_reg(5'd22, {16'h40A0, BF16_4, BF16_3, BF16_2});
        check_reg(5'd23, {16'h40A0, BF16_4, BF16_3, BF16_2});

        // ============================================================
        // Test 3: Simple matmul
        // A = [[1,0,0,0],[0,2,0,0],[0,0,3,0],[0,0,0,4]]  (diagonal)
        // B = [[1,1,1,1],[1,1,1,1],[1,1,1,1],[1,1,1,1]]  (all ones)
        // C = 0
        // D = [[1,1,1,1],[2,2,2,2],[3,3,3,3],[4,4,4,4]]
        // ============================================================
        $display("\n=== Test 3: Diagonal * Ones + 0 ===");

        @(posedge clk); rst <= 1;
        @(posedge clk); @(posedge clk);
        write_imem(10'd0, encode_wmma(5'd20, 5'd4, 5'd8, 5'd12));
        write_imem(10'd1, HALT_INSTR);
        @(posedge clk); rst <= 0;
        @(posedge clk);

        // A = diag(1,2,3,4)
        load_reg(5'd4,  {BF16_0, BF16_0, BF16_0, BF16_1});
        load_reg(5'd5,  {BF16_0, BF16_0, BF16_2, BF16_0});
        load_reg(5'd6,  {BF16_0, BF16_3, BF16_0, BF16_0});
        load_reg(5'd7,  {BF16_4, BF16_0, BF16_0, BF16_0});

        // B = all ones
        load_reg(5'd8,  {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd9,  {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd10, {BF16_1, BF16_1, BF16_1, BF16_1});
        load_reg(5'd11, {BF16_1, BF16_1, BF16_1, BF16_1});

        // C = zero
        load_reg(5'd12, 64'h0);
        load_reg(5'd13, 64'h0);
        load_reg(5'd14, 64'h0);
        load_reg(5'd15, 64'h0);

        @(posedge clk); run <= 1;
        @(posedge clk); run <= 0;
        wait(halted);
        @(posedge clk); @(posedge clk);

        // D[0] = [1,1,1,1], D[1] = [2,2,2,2], D[2] = [3,3,3,3], D[3] = [4,4,4,4]
        check_reg(5'd20, {BF16_1, BF16_1, BF16_1, BF16_1});
        check_reg(5'd21, {BF16_2, BF16_2, BF16_2, BF16_2});
        check_reg(5'd22, {BF16_3, BF16_3, BF16_3, BF16_3});
        check_reg(5'd23, {BF16_4, BF16_4, BF16_4, BF16_4});

        // ============================================================
        // Summary
        // ============================================================
        $display("\n=== WMMA Test Summary ===");
        $display("PASSED: %0d / %0d", pass_count, pass_count + fail_count);
        if (fail_count > 0)
            $display("FAILED: %0d", fail_count);
        else
            $display("All tests passed!");

        $finish;
    end

    // Timeout
    initial begin
        #50000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
