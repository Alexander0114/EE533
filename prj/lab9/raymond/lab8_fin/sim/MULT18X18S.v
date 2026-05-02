// Simplified MULT18X18S stub for Icarus Verilog simulation
// 18x18 signed registered multiplier
`timescale 1ns / 1ps

module MULT18X18S (P, A, B, C, CE, R);
    output reg [35:0] P;
    input  [17:0] A;
    input  [17:0] B;
    input  C, CE, R;

    wire signed [17:0] a_s = A;
    wire signed [17:0] b_s = B;
    wire signed [35:0] product = a_s * b_s;

    tri0 GSR = glbl.GSR;

    always @(posedge C or posedge GSR)
        if (GSR)
            P <= 36'b0;
        else if (R)
            P <= 36'b0;
        else if (CE)
            P <= product;
endmodule
