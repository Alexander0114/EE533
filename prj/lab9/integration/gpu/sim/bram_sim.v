// ============================================================
// Behavioral BRAM replacements for Icarus Verilog simulation
// Replaces Xilinx BLKMEMDP_V6_3 / BLKMEMSP_V6_2 IP cores
//
// CPU BRAMs use combinational (async) reads to match the
// pipeline timing assumed by the 4-thread barrel processor.
// ============================================================
`timescale 1ns / 1ps

// ---- CPU Instruction Memory: 512x32 dual-port ----
// Port A: read+write (synchronous — host loading + CPU MEM stage self-read)
// Port B: read-only  (combinational — IF stage fetch)
module I_Mem_Dual (
    input  [8:0]  addra, addrb,
    input         clka,  clkb,
    input  [31:0] dina,
    output reg [31:0] douta,
    output [31:0] doutb,
    input         wea
);
    reg [31:0] mem [0:511];
    integer i;
    initial for (i = 0; i < 512; i = i + 1) mem[i] = 32'b0;

    always @(posedge clka) begin
        if (wea) mem[addra] <= dina;
        douta <= mem[addra];
    end

    // Port B: combinational read for IF stage
    assign doutb = mem[addrb];
endmodule

// ---- CPU Data Memory: 256x64 dual-port ----
// Port A: write-only (synchronous)
// Port B: read (combinational)
module D_Mem (
    input  [7:0]  addra, addrb,
    input         clka,  clkb,
    input  [63:0] dina,
    output [63:0] doutb,
    input         enb,
    input         wea
);
    reg [63:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 64'b0;

    always @(posedge clka) begin
        if (wea) mem[addra] <= dina;
    end

    // Combinational read
    assign doutb = mem[addrb];
endmodule

// ---- CPU Register File BRAM: 64x64 dual-port ----
// Port A: write-only (synchronous)
// Port B: read-only  (combinational)
module Reg_File_Dual (
    input  [5:0]  addra, addrb,
    input         clka,  clkb,
    input  [63:0] dina,
    output [63:0] doutb,
    input         wea
);
    reg [63:0] mem [0:63];
    integer i;
    initial for (i = 0; i < 64; i = i + 1) mem[i] = 64'b0;

    always @(posedge clka) begin
        if (wea) mem[addra] <= dina;
    end

    // Combinational read
    assign doutb = mem[addrb];
endmodule

// ---- FIFO BRAM: 256x72 true dual-port ----
// Both ports: read+write
// Reads are combinational for CPU/GPU access
module FIFO (
    input  [7:0]  addra, addrb,
    input         clka,  clkb,
    input  [71:0] dina,  dinb,
    output [71:0] douta, doutb,
    input         wea,   web
);
    reg [71:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 72'b0;

    always @(posedge clka) begin
        if (wea) mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (web) mem[addrb] <= dinb;
    end

    // Combinational reads
    assign douta = mem[addra];
    assign doutb = mem[addrb];
endmodule

// ---- GPU Instruction Memory: 1024x32 single-port ----
// Combinational read for functional simulation (GPU FSM has FETCH+FETCH2 wait states)
module imem_bram (
    input  [9:0]  addr,
    input         clk,
    input  [31:0] din,
    output [31:0] dout,
    input         we
);
    reg [31:0] mem [0:1023];
    integer i;
    initial for (i = 0; i < 1024; i = i + 1) mem[i] = 32'b0;

    always @(posedge clk) begin
        if (we) mem[addr] <= din;
    end

    // Combinational read
    assign dout = mem[addr];
endmodule
