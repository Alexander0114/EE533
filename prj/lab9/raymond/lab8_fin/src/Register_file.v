`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:58:48 02/23/2026 
// Design Name: 
// Module Name:    Register_file 
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
module Register_file(
    input clk,
    input rst,
    input we,
    input [4:0] w_addr,
    input [63:0] w_data,
    input [4:0] r_addr_a,
    output [63:0] r_data_a,
    input [4:0] r_addr_b,
    output [63:0] r_data_b,
    input [4:0] r_addr_c,
    output [63:0] r_data_c
    );

	reg [63:0] rf [0:31];
	
	always @(posedge clk) begin
		if (rst) begin : reset_logic
			integer i;
			for(i=0; i<32; i=i+1) begin
				rf[i] <= 64'b0;
			end
		end else if(we && (w_addr != 5'b0)) begin
				rf[w_addr] <= w_data;
		end
	end
	
	assign r_data_a = rf[r_addr_a];
	assign r_data_b = rf[r_addr_b];
	assign r_data_c = rf[r_addr_c];

endmodule
