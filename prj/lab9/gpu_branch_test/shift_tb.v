/* file: shift_tb.v
 Description: Testbench for VSHL (func=6) and VSHR (func=7) ALU operations.
   Tests per-lane shift with edge cases: shift by 0, max shift, negative values.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps

module shift_tb;

    reg  [63:0] operand_a, operand_b;
    reg  [3:0]  func;
    wire [63:0] result;

    alu uut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .func(func),
        .result(result)
    );

    integer pass_count, fail_count;

    task check;
        input [63:0] expected;
        input [255:0] label;
        begin
            #1;
            if (result === expected) begin
                $display("  PASS: %0s => %h", label, result);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %0s => %h (expected %h)", label, result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("shift_tb.vcd");
        $dumpvars(0, shift_tb);
        pass_count = 0;
        fail_count = 0;

        // ============================================================
        // VSHL tests (func=6)
        // ============================================================
        $display("\n=== VSHL (func=6) ===");
        func = 4'd6;

        // Test 1: shift by 0 — no change
        operand_a = {16'd5, 16'd100, 16'd1, 16'd7};
        operand_b = {16'd0, 16'd0, 16'd0, 16'd0};
        check({16'd5, 16'd100, 16'd1, 16'd7}, "SHL by 0");

        // Test 2: shift by 1 — multiply by 2
        operand_a = {16'd5, 16'd100, 16'd1, 16'd7};
        operand_b = {16'd1, 16'd1, 16'd1, 16'd1};
        check({16'd10, 16'd200, 16'd2, 16'd14}, "SHL by 1");

        // Test 3: different shift amounts per lane
        operand_a = {16'd1, 16'd1, 16'd1, 16'd1};
        operand_b = {16'd0, 16'd4, 16'd8, 16'd15};
        check({16'd1, 16'd16, 16'd256, 16'h8000}, "SHL mixed amounts");

        // Test 4: shift by 15 (max)
        operand_a = {16'd1, 16'd1, 16'd1, 16'd1};
        operand_b = {16'd15, 16'd15, 16'd15, 16'd15};
        check({16'h8000, 16'h8000, 16'h8000, 16'h8000}, "SHL by 15");

        // Test 5: shift negative value (0xFFFF = -1)
        operand_a = {16'hFFFF, 16'hFFFF, 16'hFFFF, 16'hFFFF};
        operand_b = {16'd1, 16'd4, 16'd8, 16'd0};
        check({16'hFFFE, 16'hFFF0, 16'hFF00, 16'hFFFF}, "SHL negative");

        // ============================================================
        // VSHR tests (func=7, arithmetic shift right)
        // ============================================================
        $display("\n=== VSHR (func=7, arithmetic) ===");
        func = 4'd7;

        // Test 6: shift by 0 — no change
        operand_a = {16'd100, 16'd50, 16'd25, 16'd7};
        operand_b = {16'd0, 16'd0, 16'd0, 16'd0};
        check({16'd100, 16'd50, 16'd25, 16'd7}, "SHR by 0");

        // Test 7: shift by 1 — divide by 2
        operand_a = {16'd100, 16'd50, 16'd24, 16'd8};
        operand_b = {16'd1, 16'd1, 16'd1, 16'd1};
        check({16'd50, 16'd25, 16'd12, 16'd4}, "SHR by 1");

        // Test 8: arithmetic shift on negative — sign extends
        // -2 (0xFFFE) >>> 1 = -1 (0xFFFF)
        // -128 (0xFF80) >>> 4 = -8 (0xFFF8)
        operand_a = {16'hFFFE, 16'hFF80, 16'h8000, 16'hFFF0};
        operand_b = {16'd1, 16'd4, 16'd15, 16'd4};
        check({16'hFFFF, 16'hFFF8, 16'hFFFF, 16'hFFFF}, "SHR negative (sign ext)");

        // Test 9: different amounts per lane
        operand_a = {16'h7FFF, 16'h0100, 16'h00FF, 16'h0001};
        operand_b = {16'd4, 16'd8, 16'd0, 16'd1};
        check({16'h07FF, 16'h0001, 16'h00FF, 16'h0000}, "SHR mixed amounts");

        // Test 10: shift by 15 — all sign bit
        operand_a = {16'h8000, 16'h7FFF, 16'hFFFF, 16'h0001};
        operand_b = {16'd15, 16'd15, 16'd15, 16'd15};
        check({16'hFFFF, 16'h0000, 16'hFFFF, 16'h0000}, "SHR by 15");

        // ============================================================
        // Summary
        // ============================================================
        $display("\n=== Shift Test Summary ===");
        $display("PASSED: %0d / %0d", pass_count, pass_count + fail_count);
        if (fail_count > 0)
            $display("FAILED: %0d", fail_count);
        else
            $display("All tests passed!");

        $finish;
    end

endmodule
