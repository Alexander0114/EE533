////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : Register_File_BRAM.vf
// /___/   /\     Timestamp : 02/22/2026 21:38:23
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/Register_File_BRAM.sch" Register_File_BRAM.vf
//Design Name: Register_File_BRAM
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module Register_File_BRAM(clk, 
                          R_ID, 
                          r0addr, 
                          r1addr, 
                          waddr, 
                          wdata, 
                          wena, 
                          W_ID, 
                          r0data, 
                          r1data);

    input clk;
    input [1:0] R_ID;
    input [3:0] r0addr;
    input [3:0] r1addr;
    input [3:0] waddr;
    input [63:0] wdata;
    input wena;
    input [1:0] W_ID;
   output [63:0] r0data;
   output [63:0] r1data;
   
   wire [5:0] XLXN_18;
   wire [5:0] XLXN_19;
   wire [5:0] XLXN_20;
   
   busmerge4_2 XLXI_66 (.da(R_ID[1:0]), 
                        .db(r0addr[3:0]), 
                        .q(XLXN_18[5:0]));
   busmerge4_2 XLXI_67 (.da(R_ID[1:0]), 
                        .db(r1addr[3:0]), 
                        .q(XLXN_19[5:0]));
   busmerge4_2 XLXI_68 (.da(W_ID[1:0]), 
                        .db(waddr[3:0]), 
                        .q(XLXN_20[5:0]));
   Reg_File_Dual XLXI_73 (.addra(XLXN_20[5:0]), 
                          .addrb(XLXN_18[5:0]), 
                          .clka(clk), 
                          .clkb(clk), 
                          .dina(wdata[63:0]), 
                          .wea(wena), 
                          .doutb(r0data[63:0]));
   Reg_File_Dual XLXI_74 (.addra(XLXN_20[5:0]), 
                          .addrb(XLXN_19[5:0]), 
                          .clka(clk), 
                          .clkb(clk), 
                          .dina(wdata[63:0]), 
                          .wea(wena), 
                          .doutb(r1data[63:0]));
endmodule
