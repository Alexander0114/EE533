`timescale 1ns / 1ps
module alu (
    input  [63:0] operand_a,
    input  [63:0] operand_b,
    input  [3:0]  func,
    output reg [63:0] result
);

    // Slice into 4 signed int16 lanes
    wire signed [15:0] a0 = operand_a[15:0],  b0 = operand_b[15:0];
    wire signed [15:0] a1 = operand_a[31:16], b1 = operand_b[31:16];
    wire signed [15:0] a2 = operand_a[47:32], b2 = operand_b[47:32];
    wire signed [15:0] a3 = operand_a[63:48], b3 = operand_b[63:48];

    always @(*) begin
        case (func)
            4'd0: result = {a3 + b3, a2 + b2, a1 + b1, a0 + b0};  // VADD
            4'd1: result = {a3 - b3, a2 - b2, a1 - b1, a0 - b0};  // VSUB
            4'd2: result = operand_a & operand_b;                    // VAND
            4'd3: result = operand_a | operand_b;                    // VOR
            4'd4: result = operand_a ^ operand_b;                    // VXOR
            4'd5: result = {15'b0, a3 < b3, 15'b0, a2 < b2,        // VSLT
                            15'b0, a1 < b1, 15'b0, a0 < b0};
            default: result = 64'b0;
        endcase
    end

endmodule
