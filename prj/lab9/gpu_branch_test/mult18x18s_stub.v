/* file: mult18x18s_stub.v
 Description: Behavioral stub for Xilinx MULT18X18S primitive. Used for
   Icarus Verilog simulation since the Xilinx unisim model is not available.
   Registered 18x18 signed multiplier with synchronous reset.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps
module MULT18X18S (
    output reg [35:0] P,
    input [17:0] A,
    input [17:0] B,
    input C, CE, R
);
    always @(posedge C) begin
        if (R)
            P <= 36'b0;
        else if (CE)
            P <= $signed(A) * $signed(B);
    end
endmodule
