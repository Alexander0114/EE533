`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:21:39 01/24/2026
// Design Name:   ALU
// Module Name:   C:/Documents and Settings/student/Desktop/labs/lab2/lab2/alu/alu_verilog/ALU_tb.v
// Project Name:  alu_verilog
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: ALU
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module ALU_tb;

	// Inputs
	reg [31:0] a;
	reg [31:0] b;
	reg cin;
	reg [3:0] op_code;

	// Outputs
	wire [31:0] result;
	wire cout;

	// Instantiate the Unit Under Test (UUT)
	ALU uut (
		.a(a), 
		.b(b), 
		.result(result), 
		.cin(cin), 
		.op_code(op_code), 
		.cout(cout)
	);

	initial begin
		// Initialize Inputs
		a = 0;
		b = 0;
		cin = 0;
		op_code = 0;

    // Monitor changes to the console
    $monitor("Time=%0t | Op=%b | A=%h B=%h Cin=%b | Res=%h Cout=%b", 
	               $time, op_code, a, b, cin, result, cout);

		// Wait 100 ns for global reset to finish
		#10;
        
		  // Add stimulus here
        // ==========================================
        // TEST 1: ADDITION (Op 0000)
        // ==========================================
        $display("\n--- Testing ADDITION (0000) ---");
        
        // Case A: 10 + 20 = 30
        op_code = 4'b0000; a = 32'd10; b = 32'd20; cin = 0;
        #10;
        
        // Case B: Max Value Overflow (0xFFFFFFFF + 1)
        // Expect Result = 0, Cout = 1
        a = 32'hFFFFFFFF; b = 32'd1; cin = 0;
        #10;

        // Case C: Add with Carry In (10 + 10 + 1)
        a = 32'd10; b = 32'd10; cin = 1;
        #10;

        // ==========================================
        // TEST 2: SUBTRACTION (Op 0001)
        // ==========================================
        $display("\n--- Testing SUBTRACTION (0001) ---");
        
        // Case A: 50 - 20 = 30
        op_code = 4'b0001; a = 32'd50; b = 32'd20; cin = 0; // Cin ignored in sub logic
        #10;

        // Case B: Negative Result Check (10 - 20)
        // Expect 2's complement negative number (FFFFFFF6)
        a = 32'd10; b = 32'd20;
        #10;

        // ==========================================
        // TEST 3: LEFT SHIFT (Op 0010)
        // ==========================================
        $display("\n--- Testing LEFT SHIFT (0010) ---");
        
        // Case A: Shift 1 (binary 0...01) left by 1 -> 2
        op_code = 4'b0010; a = 32'd1;
        #10;

        // Case B: Shift bit out to carry (MSB is 1)
        // 0x80000000 << 1 -> Result 0, Cout should be 1
        a = 32'h80000000;
        #10;

        // ==========================================
        // TEST 4: BITWISE AND (Op 0011)
        // ==========================================
        $display("\n--- Testing AND (0011) ---");
        
        // Case A: F0F0 & 0F0F = 0000
        op_code = 4'b0011; a = 32'hF0F0F0F0; b = 32'h0F0F0F0F;
        #10;
        
        // Case B: FFFF & F0F0 = F0F0
        a = 32'hFFFFFFFF; b = 32'hF0F0F0F0;
        #10;

        // ==========================================
        // TEST 5: BITWISE OR (Op 0100)
        // ==========================================
        $display("\n--- Testing OR (0100) ---");
        
        // Case A: F0F0 | 0F0F = FFFF
        op_code = 4'b0100; a = 32'hF0F0F0F0; b = 32'h0F0F0F0F;
        #10;

        // End Simulation
        #10;
        $display("\nTest Complete.");
        //$finish;i


	end
      
endmodule

