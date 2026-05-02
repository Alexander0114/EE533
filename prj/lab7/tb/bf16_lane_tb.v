`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for bf16_lane
// Tests ADD, MUL, FMA, ReLU, and edge cases with BFloat16 values.
//////////////////////////////////////////////////////////////////////////////////

// Xilinx global reset module (required by MULT18X18S)
module glbl;
    reg GSR;
    initial begin
        GSR = 1;
        #10 GSR = 0;
    end
endmodule

module bf16_lane_tb;

    // Clock and reset
    reg clk;
    reg rst;

    // DUT inputs
    reg        en;
    reg [15:0] src_a;
    reg [15:0] src_b;
    reg [15:0] src_c;
    reg [2:0]  op_mode;
    reg        relu_en;

    // DUT outputs
    wire [15:0] result;
    wire        output_ready;

    // Instantiate DUT
    bf16_lane #(.PIPE_DEPTH(4)) uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .src_a(src_a),
        .src_b(src_b),
        .src_c(src_c),
        .op_mode(op_mode),
        .relu_en(relu_en),
        .result(result),
        .output_ready(output_ready)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- BF16 Constants ----
    localparam BF16_0p0  = 16'h0000;  //  0.0
    localparam BF16_0p5  = 16'h3F00;  //  0.5
    localparam BF16_1p0  = 16'h3F80;  //  1.0
    localparam BF16_1p5  = 16'h3FC0;  //  1.5
    localparam BF16_2p0  = 16'h4000;  //  2.0
    localparam BF16_3p0  = 16'h4040;  //  3.0
    localparam BF16_4p0  = 16'h4080;  //  4.0
    localparam BF16_6p0  = 16'h40C0;  //  6.0
    localparam BF16_7p0  = 16'h40E0;  //  7.0
    // Negative
    localparam BF16_N1p0 = 16'hBF80;  // -1.0
    localparam BF16_N2p0 = 16'hC000;  // -2.0
    localparam BF16_N3p0 = 16'hC040;  // -3.0
    localparam BF16_N6p0 = 16'hC0C0;  // -6.0

    // Op modes
    localparam OP_ADD = 3'd0;
    localparam OP_MUL = 3'd1;
    localparam OP_FMA = 3'd2;

    // Test counters
    integer test_num;
    integer pass_count;
    integer fail_count;

    // ---- Task: apply one test vector and wait for result ----
    task apply_and_check;
        input [15:0] a, b, c;
        input [2:0]  op;
        input        relu;
        input [15:0] expected;
        input [8*48-1:0] test_name;
        begin
            test_num = test_num + 1;
            @(negedge clk);
            src_a   = a;
            src_b   = b;
            src_c   = c;
            op_mode = op;
            relu_en = relu;
            en      = 1'b1;
            @(negedge clk);
            en      = 1'b0;
            // Wait for output_ready (PIPE_DEPTH=4 cycles from en)
            @(posedge output_ready);
            @(negedge clk);
            if (result === expected) begin
                $display("[PASS] Test %0d: %0s | result=0x%04h", test_num, test_name, result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | result=0x%04h, expected=0x%04h",
                         test_num, test_name, result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Main test sequence ----
    initial begin
        $dumpfile("bf16_lane_tb.vcd");
        $dumpvars(0, bf16_lane_tb);

        // Initialize
        clk     = 0;
        rst     = 1;
        en      = 0;
        src_a   = 0;
        src_b   = 0;
        src_c   = 0;
        op_mode = 0;
        relu_en = 0;
        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        // Reset for a few cycles
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("========================================");
        $display("  bf16_lane Testbench (PIPE_DEPTH=4)");
        $display("========================================");

        // ------- MUL Tests -------
        $display("\n--- MUL Tests ---");

        apply_and_check(BF16_2p0, BF16_3p0, BF16_0p0,
                        OP_MUL, 0, BF16_6p0, "MUL: 2.0 * 3.0 = 6.0");

        apply_and_check(BF16_1p5, BF16_2p0, BF16_0p0,
                        OP_MUL, 0, BF16_3p0, "MUL: 1.5 * 2.0 = 3.0");

        apply_and_check(BF16_N2p0, BF16_3p0, BF16_0p0,
                        OP_MUL, 0, BF16_N6p0, "MUL: -2.0 * 3.0 = -6.0");

        apply_and_check(BF16_1p0, BF16_1p0, BF16_0p0,
                        OP_MUL, 0, BF16_1p0, "MUL: 1.0 * 1.0 = 1.0");

        apply_and_check(BF16_0p0, BF16_3p0, BF16_0p0,
                        OP_MUL, 0, BF16_0p0, "MUL: 0.0 * 3.0 = 0.0");

        // ------- ADD Tests -------
        $display("\n--- ADD Tests ---");

        apply_and_check(BF16_1p0, BF16_2p0, BF16_0p0,
                        OP_ADD, 0, BF16_3p0, "ADD: 1.0 + 2.0 = 3.0");

        apply_and_check(BF16_3p0, BF16_N1p0, BF16_0p0,
                        OP_ADD, 0, BF16_2p0, "ADD: 3.0 + (-1.0) = 2.0");

        apply_and_check(BF16_N1p0, BF16_N2p0, BF16_0p0,
                        OP_ADD, 0, BF16_N3p0, "ADD: -1.0 + (-2.0) = -3.0");

        apply_and_check(BF16_0p0, BF16_3p0, BF16_0p0,
                        OP_ADD, 0, BF16_3p0, "ADD: 0.0 + 3.0 = 3.0");

        apply_and_check(BF16_3p0, BF16_0p0, BF16_0p0,
                        OP_ADD, 0, BF16_3p0, "ADD: 3.0 + 0.0 = 3.0");

        apply_and_check(BF16_1p0, BF16_N1p0, BF16_0p0,
                        OP_ADD, 0, BF16_0p0, "ADD: 1.0 + (-1.0) = 0.0");

        // ------- FMA Tests -------
        $display("\n--- FMA Tests ---");

        apply_and_check(BF16_2p0, BF16_3p0, BF16_1p0,
                        OP_FMA, 0, BF16_7p0, "FMA: 2.0*3.0 + 1.0 = 7.0");

        apply_and_check(BF16_1p0, BF16_1p0, BF16_1p0,
                        OP_FMA, 0, BF16_2p0, "FMA: 1.0*1.0 + 1.0 = 2.0");

        apply_and_check(BF16_0p0, BF16_3p0, BF16_2p0,
                        OP_FMA, 0, BF16_2p0, "FMA: 0.0*3.0 + 2.0 = 2.0");

        apply_and_check(BF16_2p0, BF16_3p0, BF16_N6p0,
                        OP_FMA, 0, BF16_0p0, "FMA: 2.0*3.0 + (-6.0) = 0.0");

        // ------- ReLU Tests -------
        $display("\n--- ReLU Tests ---");

        apply_and_check(BF16_N2p0, BF16_3p0, BF16_0p0,
                        OP_MUL, 1, BF16_0p0, "ReLU MUL: max(0, -6.0) = 0.0");

        apply_and_check(BF16_2p0, BF16_3p0, BF16_0p0,
                        OP_MUL, 1, BF16_6p0, "ReLU MUL: max(0, 6.0) = 6.0");

        apply_and_check(BF16_N1p0, BF16_N2p0, BF16_0p0,
                        OP_ADD, 1, BF16_0p0, "ReLU ADD: max(0, -3.0) = 0.0");

        apply_and_check(BF16_1p0, BF16_2p0, BF16_0p0,
                        OP_ADD, 1, BF16_3p0, "ReLU ADD: max(0, 3.0) = 3.0");

        // ------- Summary -------
        repeat(2) @(posedge clk);
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, test_num);
        $display("========================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");

        $finish;
    end

endmodule
