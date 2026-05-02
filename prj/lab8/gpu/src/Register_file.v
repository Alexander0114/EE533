/* file: Register_file.v
 Description: 32x64-bit register file with 4 combinational read ports and
   1 synchronous write port. R0 is write-protected (hardwired to zero).
 Author: Raymond
 Date: Feb. 23, 2026
 Version: 1.1
 Revision History:
    - 1.0: Initial implementation with 3 read ports. (Feb. 23, 2026)
    - 1.1: Added 4th read port (r_addr_d / r_data_d) for tensor core
            matrix gather. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps
`ifndef REGISTER_FILE_V
`define REGISTER_FILE_V
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
    output [63:0] r_data_c,
    input [4:0] r_addr_d,
    output [63:0] r_data_d
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
	assign r_data_d = rf[r_addr_d];

endmodule
`endif // REGISTER_FILE_V
