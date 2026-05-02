////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : dff32.vf
// /___/   /\     Timestamp : 02/17/2026 20:41:37
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor/dff32.sch" dff32.vf
//Design Name: dff32
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module FD16CE_MXILINX_dff32(C, 
                            CE, 
                            CLR, 
                            D, 
                            Q);

    input C;
    input CE;
    input CLR;
    input [15:0] D;
   output [15:0] Q;
   
   
   FDCE I_Q0 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[0]), 
              .Q(Q[0]));
   defparam I_Q0.INIT = 1'b0;
   FDCE I_Q1 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[1]), 
              .Q(Q[1]));
   defparam I_Q1.INIT = 1'b0;
   FDCE I_Q2 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[2]), 
              .Q(Q[2]));
   defparam I_Q2.INIT = 1'b0;
   FDCE I_Q3 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[3]), 
              .Q(Q[3]));
   defparam I_Q3.INIT = 1'b0;
   FDCE I_Q4 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[4]), 
              .Q(Q[4]));
   defparam I_Q4.INIT = 1'b0;
   FDCE I_Q5 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[5]), 
              .Q(Q[5]));
   defparam I_Q5.INIT = 1'b0;
   FDCE I_Q6 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[6]), 
              .Q(Q[6]));
   defparam I_Q6.INIT = 1'b0;
   FDCE I_Q7 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[7]), 
              .Q(Q[7]));
   defparam I_Q7.INIT = 1'b0;
   FDCE I_Q8 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[8]), 
              .Q(Q[8]));
   defparam I_Q8.INIT = 1'b0;
   FDCE I_Q9 (.C(C), 
              .CE(CE), 
              .CLR(CLR), 
              .D(D[9]), 
              .Q(Q[9]));
   defparam I_Q9.INIT = 1'b0;
   FDCE I_Q10 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[10]), 
               .Q(Q[10]));
   defparam I_Q10.INIT = 1'b0;
   FDCE I_Q11 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[11]), 
               .Q(Q[11]));
   defparam I_Q11.INIT = 1'b0;
   FDCE I_Q12 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[12]), 
               .Q(Q[12]));
   defparam I_Q12.INIT = 1'b0;
   FDCE I_Q13 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[13]), 
               .Q(Q[13]));
   defparam I_Q13.INIT = 1'b0;
   FDCE I_Q14 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[14]), 
               .Q(Q[14]));
   defparam I_Q14.INIT = 1'b0;
   FDCE I_Q15 (.C(C), 
               .CE(CE), 
               .CLR(CLR), 
               .D(D[15]), 
               .Q(Q[15]));
   defparam I_Q15.INIT = 1'b0;
endmodule
`timescale 1ns / 1ps

module dff32(CE, 
             CLK, 
             CLR, 
             D, 
             Q);

    input CE;
    input CLK;
    input CLR;
    input [31:0] D;
   output [31:0] Q;
   
   
   FD16CE_MXILINX_dff32 XLXI_45 (.C(CLK), 
                                 .CE(CE), 
                                 .CLR(CLR), 
                                 .D(D[31:16]), 
                                 .Q(Q[31:16]));
   // synthesis attribute HU_SET of XLXI_45 is "XLXI_45_0"
   FD16CE_MXILINX_dff32 XLXI_46 (.C(CLK), 
                                 .CE(CE), 
                                 .CLR(CLR), 
                                 .D(D[15:0]), 
                                 .Q(Q[15:0]));
   // synthesis attribute HU_SET of XLXI_46 is "XLXI_46_1"
endmodule
