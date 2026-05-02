`timescale 1ns / 1ps
// Behavioral dmem for Icarus Verilog simulation
// Replaces Xilinx BLKMEMSP_V6_2 with $readmemh
// Matches c_pipe_stages(1): 2-cycle read latency
module dmem (
    input         clk,
    input         we,
    input  [9:0]  addr,
    input  [63:0] w_data,
    output [63:0] r_data
);

    reg [63:0] mem [0:1023];
    reg [63:0] stage0;
    reg [63:0] stage1;

    initial begin
        $readmemh("data.hex", mem);
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= w_data;
        stage0 <= mem[addr];   // BRAM internal read
        stage1 <= stage0;      // c_pipe_stages(1) output register
    end

    assign r_data = stage1;

endmodule
