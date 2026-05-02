////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : Counter_2b.vf
// /___/   /\     Timestamp : 02/22/2026 21:38:23
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/Counter_2b.sch" Counter_2b.vf
//Design Name: Counter_2b
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module FTCE_MXILINX_Counter_2b(C, 
                               CE, 
                               CLR, 
                               T, 
                               Q);

    input C;
    input CE;
    input CLR;
    input T;
   output Q;
   
   wire TQ;
   wire Q_DUMMY;
   
   assign Q = Q_DUMMY;
   XOR2 I_36_32 (.I0(T), 
                 .I1(Q_DUMMY), 
                 .O(TQ));
   FDCE I_36_35 (.C(C), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(TQ), 
                 .Q(Q_DUMMY));
   // synthesis attribute RLOC of I_36_35 is "X0Y0"
   defparam I_36_35.INIT = 1'b0;
endmodule
`timescale 1ns / 1ps

module Counter_2b(CE, 
                  CLK, 
                  CLR, 
                  T_ID);

    input CE;
    input CLK;
    input CLR;
   output [1:0] T_ID;
   
   wire XLXN_1;
   wire [1:0] T_ID_DUMMY;
   
   assign T_ID[1:0] = T_ID_DUMMY[1:0];
   FTCE_MXILINX_Counter_2b I_Q0 (.C(CLK), 
                                 .CE(CE), 
                                 .CLR(CLR), 
                                 .T(XLXN_1), 
                                 .Q(T_ID_DUMMY[0]));
   // synthesis attribute HU_SET of I_Q0 is "I_Q0_1"
   FTCE_MXILINX_Counter_2b I_Q1 (.C(CLK), 
                                 .CE(CE), 
                                 .CLR(CLR), 
                                 .T(T_ID_DUMMY[0]), 
                                 .Q(T_ID_DUMMY[1]));
   // synthesis attribute HU_SET of I_Q1 is "I_Q1_0"
   VCC I_36_9 (.P(XLXN_1));
endmodule
