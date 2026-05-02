////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : Mux2_1_64b.vf
// /___/   /\     Timestamp : 02/18/2026 19:45:35
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor/Mux2_1_64b.sch" Mux2_1_64b.vf
//Design Name: Mux2_1_64b
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module Mux2_1_64b(D0, 
                  D1, 
                  S, 
                  O);

    input [63:0] D0;
    input [63:0] D1;
    input S;
   output [63:0] O;
   
   
   Mux_2_1_16b XLXI_5 (.D0(D0[15:0]), 
                       .D1(D1[15:0]), 
                       .S(S), 
                       .O(O[15:0]));
   Mux_2_1_16b XLXI_6 (.D0(D0[31:16]), 
                       .D1(D1[31:16]), 
                       .S(S), 
                       .O(O[31:16]));
   Mux_2_1_16b XLXI_7 (.D0(D0[47:32]), 
                       .D1(D1[47:32]), 
                       .S(S), 
                       .O(O[47:32]));
   Mux_2_1_16b XLXI_8 (.D0(D0[63:48]), 
                       .D1(D1[63:48]), 
                       .S(S), 
                       .O(O[63:48]));
endmodule
