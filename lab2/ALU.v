`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    02:17:54 01/24/2026 
// Design Name: 
// Module Name:    ALU 
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
module ALU(
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    input cin,
    input [3:0] op_code,
    output reg cout
    );

// Internal signals for the shared arithmetic unit
    reg [31:0] operand_b;
    reg carry_in_internal;
    wire [31:0] sum_result;
    wire arithmetic_cout;

    // =================================================================
    // 1. ARITHMETIC UNIT EXTENSION (Shared Adder)
    // =================================================================
    // To save hardware, we reuse the adder for subtraction.
    // Logic: A - B  ===  A + (~B) + 1
    always @(*) begin
        if (op_code == 4'b0001) begin
            // Subtraction Mode
            operand_b = ~b;          // Invert B
            carry_in_internal = 1'b1; // Add 1 (This forces the +1 for 2's complement)
        end else begin
            // Addition Mode
            operand_b = b;           // Keep B as is
            carry_in_internal = cin; // Use the external Carry-In
        end
    end

    // The actual 32-bit Adder Calculation
    assign {arithmetic_cout, sum_result} = a + operand_b + carry_in_internal;


    // =================================================================
    // 2. OUTPUT MULTIPLEXER (Function Selection)
    // =================================================================
    always @(*) begin
        // Default values to prevent latches
        result = 32'b0;
        cout = 1'b0; 

        case (op_code)
            4'b0000: begin // ADDITION
                result = sum_result;
                cout = arithmetic_cout;
            end
            
            4'b0001: begin // SUBTRACTION
                result = sum_result;
                cout = arithmetic_cout; 
                // Note: In this logic, cout=1 means "No Borrow", cout=0 means "Borrow"
            end

            4'b0010: begin // LEFT SHIFT ONE BIT
                // Shifts 'a' left by 1. 'b' is ignored.
                result = a << 1; 
                cout = a[31]; // The bit shifted out is often captured in Carry
            end

            4'b0011: begin // BITWISE AND
                result = a & b;
                cout = 1'b0;
            end

            4'b0100: begin // BITWISE OR
                result = a | b;
                cout = 1'b0;
            end

            default: begin
                result = 32'b0;
                cout = 1'b0;
            end
        endcase
    end
endmodule
