`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:18:33 02/21/2026 
// Design Name: 
// Module Name:    busmerge4_2 
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
module busmerge4_2(da, db, q);
    input [1:0] da;
    input [3:0] db;
    output [5:0] q;
    assign q = {da,db};

endmodule
