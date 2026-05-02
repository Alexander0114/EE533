`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Comprehensive testbench for gpu_top
// Tests: VADD, VSUB, BF16 MUL/ADD/FMA, RELU_INT, BF16+RELU, ADDI+BNE loop
//////////////////////////////////////////////////////////////////////////////////

// Xilinx global reset (required by MULT18X18S)
module glbl;
    reg GSR;
    initial begin
        GSR = 1;
        #10 GSR = 0;
    end
endmodule

module gpu_top_tb;

    reg         clk;
    reg         rst;
    reg         run;
    reg  [9:0]  thread_id;

    wire        halted;
    wire [9:0]  debug_pc;
    wire [31:0] debug_ir;
    wire [3:0]  debug_state;

    // Instantiate DUT
    gpu_top uut (
        .clk(clk),
        .rst(rst),
        .run(run),
        .thread_id(thread_id),
        .halted(halted),
        .debug_pc(debug_pc),
        .debug_ir(debug_ir),
        .debug_state(debug_state)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Expected values
    localparam [63:0] EXP_VADD     = 64'h000B00160021002C;  // {11,22,33,44}
    localparam [63:0] EXP_BF16_MUL = 64'h40C04040400040C0;  // {6.0,3.0,2.0,6.0}
    localparam [63:0] EXP_BF16_ADD = 64'h40A04060404040A0;  // {5.0,3.5,3.0,5.0}
    localparam [63:0] EXP_BF16_FMA = 64'h4100409040404110;  // {8.0,4.5,3.0,9.0}
    localparam [63:0] EXP_RELU_INT = 64'h0000000A00000007;  // {0,10,0,7}
    localparam [63:0] EXP_MUL_RELU = 64'h000040C000004080;  // {0,6.0,0,4.0}
    localparam [63:0] EXP_VSUB     = 64'hFFF7FFEEFFE5FFDC;  // {-9,-18,-27,-36}
    localparam [63:0] EXP_VAND     = 64'h0000000000020000;  // {1,2,3,4} & {10,20,30,40}
    localparam [63:0] EXP_VOR      = 64'h000B0016001F002C;  // {1,2,3,4} | {10,20,30,40}
    localparam [63:0] EXP_VXOR     = 64'h000B0016001D002C;  // {1,2,3,4} ^ {10,20,30,40}
    localparam [63:0] EXP_VSLT     = 64'h0001000000010000;  // {1,2,3,4} < {5,-3,15,-10}
    localparam [63:0] EXP_LUI      = 64'h00D5800000000000;  // LUI 0x1AB
    localparam [63:0] EXP_ADD_RELU = 64'h3F8040A0000040A0;  // BF16 ADD+RELU
    localparam [63:0] EXP_FMA_RELU = 64'h00004100000040A0;  // BF16 FMA+RELU
    localparam [63:0] EXP_NOP_CHK  = 64'h000000000000002A;  // 42 after NOP
    localparam [63:0] EXP_VBCAST   = 64'h4000400040004000;  // {2.0,2.0,2.0,2.0}
    localparam [63:0] EXP_MATMUL0  = 64'h3F8040003F804000;  // {1.0,2.0,1.0,2.0}

    integer pass_count;
    integer fail_count;
    integer cycle_count;

    reg [63:0] dmem_readback;
    reg [63:0] reg_readback;

    // Monitor state transitions
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        if (!rst)
            $display("[Cycle %4d] PC=%3d State=%1d IR=%08h",
                     cycle_count, debug_pc, debug_state, debug_ir);
    end

    // Read dmem via force/release
    task read_dmem;
        input [9:0] address;
        output [63:0] data;
        begin
            force uut.ctrl_inst.dmem_addr = address;
            force uut.ctrl_inst.dmem_we   = 1'b0;
            @(posedge clk);
            @(posedge clk);
            #1;
            data = uut.dmem_rdata;
            release uut.ctrl_inst.dmem_addr;
            release uut.ctrl_inst.dmem_we;
        end
    endtask

    // Read register via force/release
    task read_reg;
        input [4:0] address;
        output [63:0] data;
        begin
            force uut.ctrl_inst.rf_rd_a = address;
            @(posedge clk);
            #1;
            data = uut.rf_a;
            release uut.ctrl_inst.rf_rd_a;
        end
    endtask

    // Check helper
    task check;
        input [8*32-1:0] name;
        input [63:0] actual;
        input [63:0] expected;
        begin
            if (actual === expected) begin
                $display("[PASS] %0s = 0x%016h", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s = 0x%016h, expected 0x%016h",
                         name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("gpu_top_tb.vcd");
        $dumpvars(0, gpu_top_tb);

        pass_count  = 0;
        fail_count  = 0;
        cycle_count = 0;

        // Reset
        rst       = 1;
        run       = 0;
        thread_id = 10'd0;
        repeat(6) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("========================================");
        $display("  GPU Comprehensive Test");
        $display("========================================");

        // Start execution
        run = 1;
        @(posedge clk);
        run = 0;

        // Wait for HALT (with timeout)
        begin : wait_halt
            integer timeout;
            timeout = 0;
            while (!halted && timeout < 800) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!halted)
                $display("[TIMEOUT] GPU did not halt within 800 cycles");
        end

        repeat(2) @(posedge clk);

        $display("\n--- Checking Results ---");

        // Test 1: Int16 VADD
        read_dmem(10'd2, dmem_readback);
        check("dmem[2]  VADD", dmem_readback, EXP_VADD);

        // Test 2: BF16 MUL
        read_dmem(10'd5, dmem_readback);
        check("dmem[5]  BF16 MUL", dmem_readback, EXP_BF16_MUL);

        // Test 3: BF16 ADD
        read_dmem(10'd6, dmem_readback);
        check("dmem[6]  BF16 ADD", dmem_readback, EXP_BF16_ADD);

        // Test 4: BF16 FMA
        read_dmem(10'd7, dmem_readback);
        check("dmem[7]  BF16 FMA", dmem_readback, EXP_BF16_FMA);

        // Test 5: RELU_INT
        read_dmem(10'd9, dmem_readback);
        check("dmem[9]  RELU_INT", dmem_readback, EXP_RELU_INT);

        // Test 6: BF16 MUL+RELU
        read_dmem(10'd12, dmem_readback);
        check("dmem[12] MUL+RELU", dmem_readback, EXP_MUL_RELU);

        // Test 7: VSUB
        read_dmem(10'd13, dmem_readback);
        check("dmem[13] VSUB", dmem_readback, EXP_VSUB);

        // Test 8: VAND
        read_dmem(10'd15, dmem_readback);
        check("dmem[15] VAND", dmem_readback, EXP_VAND);

        // Test 9: VOR
        read_dmem(10'd16, dmem_readback);
        check("dmem[16] VOR", dmem_readback, EXP_VOR);

        // Test 10: VXOR
        read_dmem(10'd17, dmem_readback);
        check("dmem[17] VXOR", dmem_readback, EXP_VXOR);

        // Test 11: VSLT
        read_dmem(10'd19, dmem_readback);
        check("dmem[19] VSLT", dmem_readback, EXP_VSLT);

        // Test 12: LUI
        read_dmem(10'd20, dmem_readback);
        check("dmem[20] LUI", dmem_readback, EXP_LUI);

        // Test 13: TENSOR_ADD_RELU
        read_dmem(10'd21, dmem_readback);
        check("dmem[21] ADD_RELU", dmem_readback, EXP_ADD_RELU);

        // Test 14: TENSOR_FMA_RELU
        read_dmem(10'd22, dmem_readback);
        check("dmem[22] FMA_RELU", dmem_readback, EXP_FMA_RELU);

        // Test 15: NOP
        read_dmem(10'd23, dmem_readback);
        check("dmem[23] NOP_CHK", dmem_readback, EXP_NOP_CHK);

        // Test 16: VBCAST
        read_dmem(10'd25, dmem_readback);
        check("dmem[25] VBCAST", dmem_readback, EXP_VBCAST);

        // Test 17: 2x2 Matrix Multiply C_row0
        read_dmem(10'd29, dmem_readback);
        check("dmem[29] MATMUL_C0", dmem_readback, EXP_MATMUL0);

        // Register dump
        $display("\n--- Register File Dump ---");
        read_reg(5'd1, reg_readback); $display("  R1  = 0x%016h", reg_readback);
        read_reg(5'd2, reg_readback); $display("  R2  = 0x%016h", reg_readback);
        read_reg(5'd3, reg_readback); $display("  R3  = 0x%016h", reg_readback);
        read_reg(5'd4, reg_readback); $display("  R4  = 0x%016h", reg_readback);
        read_reg(5'd5, reg_readback); $display("  R5  = 0x%016h", reg_readback);
        read_reg(5'd6, reg_readback); $display("  R6  = 0x%016h", reg_readback);
        read_reg(5'd7, reg_readback); $display("  R7  = 0x%016h", reg_readback);
        read_reg(5'd8, reg_readback); $display("  R8  = 0x%016h", reg_readback);
        read_reg(5'd10, reg_readback); $display("  R10 = 0x%016h", reg_readback);
        read_reg(5'd11, reg_readback); $display("  R11 = 0x%016h", reg_readback);
        read_reg(5'd12, reg_readback); $display("  R12 = 0x%016h", reg_readback);
        read_reg(5'd13, reg_readback); $display("  R13 = 0x%016h", reg_readback);
        read_reg(5'd14, reg_readback); $display("  R14 = 0x%016h", reg_readback);
        read_reg(5'd15, reg_readback); $display("  R15 = 0x%016h", reg_readback);

        // Summary
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("  Total cycles: %0d", cycle_count);
        $display("========================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");

        $finish;
    end

endmodule
