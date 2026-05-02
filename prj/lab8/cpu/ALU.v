`timescale 1ns / 1ps

module ALU (
    input      [63:0]  A,
    input      [63:0]  B,
    input      [3:0]   aluctrl,
    output reg [63:0]  ALU_Result,
    output reg         N,
    output reg         Z,
    output reg         C,
    output reg         V
);


    always @(*) begin
        ALU_Result = 64'b0;
        C          = 1'b0;
        V          = 1'b0;

        case (aluctrl)

            4'b0000: begin   // ADD
                {C, ALU_Result} = A + B;
                V = (A[63] == B[63]) && (ALU_Result[63] != A[63]);
            end

            4'b0001: begin   // SUB
                ALU_Result = A - B;
                C = (A >= B); // ARM standard: C=1 if no borrow
                V = (A[63] != B[63]) && (ALU_Result[63] != A[63]);
            end

            4'b0010: ALU_Result = A & B;        // AND
            4'b0011: ALU_Result = A | B;        // OR
            4'b0100: ALU_Result = A ^ B;        // XOR
            4'b0101: ALU_Result = ~(A ^ B);     // XNOR

            4'b0110: ALU_Result = A << B[5:0];  // Logical Shift Left
            4'b0111: ALU_Result = A >> B[5:0];  // Logical Shift Right
            4'b1000: ALU_Result = $signed(A) >>> B[5:0]; // Arithmetic Shift Right
				
            4'b1001: ALU_Result = (A == B) ? 64'd1 : 64'd0; // EQ
            4'b1010: ALU_Result = ($signed(A) < $signed(B)) ? 64'd1 : 64'd0; // LT
            4'b1011: ALU_Result = ($signed(A) > $signed(B)) ? 64'd1 : 64'd0; // GT

            default: ALU_Result = 64'b0;

        endcase

        N = ALU_Result[63];
        Z = (ALU_Result == 64'b0);
    end

endmodule
