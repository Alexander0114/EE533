////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : IF_ID_Reg.vf
// /___/   /\     Timestamp : 02/21/2026 01:22:06
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/IF_ID_Reg.sch" IF_ID_Reg.vf
//Design Name: IF_ID_Reg
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module IF_ID_Reg(CE, 
                 CLK, 
                 CLR, 
                 IF_Ins, 
                 IF_TID, 
                 ID_Ins, 
                 ID_TID);

    input CE;
    input CLK;
    input CLR;
    input [31:0] IF_Ins;
    input [1:0] IF_TID;
   output [31:0] ID_Ins;
   output [1:0] ID_TID;
   
   
   dff32 XLXI_179 (.CE(CE), 
                   .CLK(CLK), 
                   .CLR(CLR), 
                   .D(IF_Ins[31:0]), 
                   .Q(ID_Ins[31:0]));
   dff2 XLXI_180 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(IF_TID[1:0]), 
                  .Q(ID_TID[1:0]));
endmodule
