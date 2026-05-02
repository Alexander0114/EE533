////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : dff12.vf
// /___/   /\     Timestamp : 02/20/2026 00:33:18
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor/dff12.sch" dff12.vf
//Design Name: dff12
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module dff12(CE, 
             CLK, 
             CLR, 
             D, 
             Q);

    input CE;
    input CLK;
    input CLR;
    input [11:0] D;
   output [11:0] Q;
   
   
   dff4 XLXI_17 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(D[11:8]), 
                 .Q(Q[11:8]));
   dff4 XLXI_18 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(D[7:4]), 
                 .Q(Q[7:4]));
   dff4 XLXI_19 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(D[3:0]), 
                 .Q(Q[3:0]));
endmodule
