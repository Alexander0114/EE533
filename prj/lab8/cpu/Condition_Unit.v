`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:42:50 02/19/2026 
// Design Name: 
// Module Name:    Condition_Unit 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Condition_Unit(
    input wire [1:0] BType,
	 input wire N,
    input wire Z,
    input wire C,
    input wire V,
	 input wire br_en,
	 output wire branch_taken
    );

    wire ge_condition = (N == V);
    wire le_condition = (Z == 1'b1) || (N != V);

    wire condition_result =
            (BType == 2'b01) ? 1'b1 :
            (BType == 2'b10) ? ge_condition :
            (BType == 2'b11) ? le_condition :
            1'b0;

    assign branch_taken = br_en & condition_result;

endmodule
