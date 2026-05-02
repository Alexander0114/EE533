`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:57:35 02/18/2026 
// Design Name: 
// Module Name:    Control_Unit 
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
module cpu_Control_Unit(
    input  [3:0] OP,
    output reg Branch,
	 output reg MemtoReg,
    output reg RegWrite,
    output reg MemRead,
    output reg MemWrite,
    output reg ALUSrc
);

always @(*) begin
	Branch   = 0;
	MemRead  = 0;
	MemtoReg = 0;
	ALUSrc   = 0;
	MemWrite = 0;
	RegWrite = 0;

    case (OP)
        4'b0001: begin  // R-type
            ALUSrc   = 0;
				MemtoReg = 0;
            RegWrite = 1;
				MemRead  = 0;
				MemWrite = 0;
				Branch   = 0;
        end

        4'b0010: begin  // lw
            ALUSrc   = 1;
				MemtoReg = 1;
            RegWrite = 1;
				MemRead  = 1;
				MemWrite = 0;
				Branch   = 0;
        end

        4'b0011: begin  // sw
            ALUSrc   = 1;
            RegWrite = 0;
				MemRead  = 0;
				MemWrite = 1;
				Branch   = 0;
        end

        4'b0100: begin  // b
            ALUSrc   = 1;
				RegWrite = 0;
				MemRead  = 0;
				MemWrite = 0;
				Branch   = 1;
        end

        4'b1000: begin  // cmp immediate
            ALUSrc   = 1;
            RegWrite = 0;
				MemRead  = 0;
				MemWrite = 0;
				Branch   = 0;
        end
		  
        4'b1001: begin  // R-type immediate
            ALUSrc   = 1;
				MemtoReg = 0;
            RegWrite = 1;
				MemRead  = 0;
				MemWrite = 0;
				Branch   = 0;
        end

        default: begin
        end
    endcase
end

endmodule