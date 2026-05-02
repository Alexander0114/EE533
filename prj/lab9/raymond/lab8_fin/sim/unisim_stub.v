// ============================================================
// Minimal UNISIM primitive stubs for Icarus Verilog simulation
// Replaces Xilinx UNISIM library for schematic-based modules
// ============================================================
`timescale 1ns / 1ps

// D flip-flop with Clock Enable and Asynchronous Clear
module FDCE (output reg Q, input C, CE, CLR, D);
    parameter INIT = 1'b0;
    initial Q = INIT;
    always @(posedge C or posedge CLR)
        if (CLR) Q <= 1'b0;
        else if (CE) Q <= D;
endmodule

// Logic gates
module AND2 (output O, input I0, I1);
    assign O = I0 & I1;
endmodule

module AND2B1 (output O, input I0, I1);
    assign O = (~I0) & I1;
endmodule

module AND3 (output O, input I0, I1, I2);
    assign O = I0 & I1 & I2;
endmodule

module AND3B1 (output O, input I0, I1, I2);
    assign O = (~I0) & I1 & I2;
endmodule

module AND3B2 (output O, input I0, I1, I2);
    assign O = (~I0) & (~I1) & I2;
endmodule

module AND4 (output O, input I0, I1, I2, I3);
    assign O = I0 & I1 & I2 & I3;
endmodule

module OR2 (output O, input I0, I1);
    assign O = I0 | I1;
endmodule

module XOR2 (output O, input I0, I1);
    assign O = I0 ^ I1;
endmodule

module VCC (output P);
    assign P = 1'b1;
endmodule

// 2:1 Mux (Xilinx MUXF5 primitive)
module MUXF5 (output O, input I0, I1, S);
    assign O = S ? I1 : I0;
endmodule

// 16-bit 2:1 Mux (used by Mux2_1_64b schematic)
module Mux_2_1_16b (
    input  [15:0] D0, D1,
    input         S,
    output [15:0] O
);
    assign O = S ? D1 : D0;
endmodule
