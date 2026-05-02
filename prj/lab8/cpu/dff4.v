////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : dff4.vf
// /___/   /\     Timestamp : 02/20/2026 00:33:16
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor/dff4.sch" dff4.vf
//Design Name: dff4
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module dff4(CE, 
            CLK, 
            CLR, 
            D, 
            Q);

    input CE;
    input CLK;
    input CLR;
    input [3:0] D;
   output [3:0] Q;
   
   
   FDCE XLXI_12 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(D[1]), 
                 .Q(Q[1]));
   defparam XLXI_12.INIT = 1'b0;
   FDCE XLXI_13 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(D[0]), 
                 .Q(Q[0]));
   defparam XLXI_13.INIT = 1'b0;
   FDCE XLXI_14 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(D[2]), 
                 .Q(Q[2]));
   defparam XLXI_14.INIT = 1'b0;
   FDCE XLXI_15 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(D[3]), 
                 .Q(Q[3]));
   defparam XLXI_15.INIT = 1'b0;
endmodule
