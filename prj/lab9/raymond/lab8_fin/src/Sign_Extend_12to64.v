`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:35:53 02/19/2026 
// Design Name: 
// Module Name:    Sign_Extend_12to64 
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
module Sign_Extend_12to64(
    input [11:0] ext_in,
    output [63:0] ext_out
    );

assign ext_out = {{52{ext_in[11]}}, ext_in};

endmodule
