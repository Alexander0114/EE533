`timescale 1ns / 1ps
// Behavioral imem for Icarus Verilog simulation
// Replaces Xilinx BLKMEMSP_V6_2 with $readmemh
// Matches c_pipe_stages(1): 2-cycle read latency (addr -> stage0 -> stage1 -> dout)
module imem (
    input         clk,
    input  [9:0]  addr,
    output [31:0] data
);

    reg [31:0] mem [0:1023];
    reg [31:0] stage0;
    reg [31:0] stage1;

    initial begin
        $readmemh("program.hex", mem);
    end

    always @(posedge clk) begin
        stage0 <= mem[addr];   // BRAM internal read
        stage1 <= stage0;      // c_pipe_stages(1) output register
    end

    assign data = stage1;

endmodule
