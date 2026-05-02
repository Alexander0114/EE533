////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : PCL_7b.vf
// /___/   /\     Timestamp : 02/21/2026 01:22:04
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/PCL_7b.sch" PCL_7b.vf
//Design Name: PCL_7b
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module M2_1_MXILINX_PCL_7b(D0, 
                           D1, 
                           S0, 
                           O);

    input D0;
    input D1;
    input S0;
   output O;
   
   wire M0;
   wire M1;
   
   AND2B1 I_36_7 (.I0(S0), 
                  .I1(D0), 
                  .O(M0));
   OR2 I_36_8 (.I0(M1), 
               .I1(M0), 
               .O(O));
   AND2 I_36_9 (.I0(D1), 
                .I1(S0), 
                .O(M1));
endmodule
`timescale 1ns / 1ps

module FTCLEX_MXILINX_PCL_7b(C, 
                             CE, 
                             CLR, 
                             D, 
                             L, 
                             T, 
                             Q);

    input C;
    input CE;
    input CLR;
    input D;
    input L;
    input T;
   output Q;
   
   wire MD;
   wire TQ;
   wire Q_DUMMY;
   
   assign Q = Q_DUMMY;
   M2_1_MXILINX_PCL_7b I_36_30 (.D0(TQ), 
                                .D1(D), 
                                .S0(L), 
                                .O(MD));
   // synthesis attribute HU_SET of I_36_30 is "I_36_30_0"
   XOR2 I_36_32 (.I0(T), 
                 .I1(Q_DUMMY), 
                 .O(TQ));
   FDCE I_36_35 (.C(C), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(MD), 
                 .Q(Q_DUMMY));
   // synthesis attribute RLOC of I_36_35 is "X0Y0"
   defparam I_36_35.INIT = 1'b0;
endmodule
`timescale 1ns / 1ps

module PCL_7b(CE, 
              CLK, 
              CLR, 
              D, 
              L, 
              Q);

    input CE;
    input CLK;
    input CLR;
    input [6:0] D;
    input L;
   output [6:0] Q;
   
   wire T2;
   wire T3;
   wire XLXN_19;
   wire XLXN_52;
   wire XLXN_55;
   wire XLXN_58;
   wire XLXN_169;
   wire [6:0] Q_DUMMY;
   
   assign Q[6:0] = Q_DUMMY[6:0];
   FTCLEX_MXILINX_PCL_7b I_Q0 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[0]), 
                               .L(L), 
                               .T(XLXN_19), 
                               .Q(Q_DUMMY[0]));
   // synthesis attribute HU_SET of I_Q0 is "I_Q0_7"
   FTCLEX_MXILINX_PCL_7b I_Q1 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[1]), 
                               .L(L), 
                               .T(Q_DUMMY[0]), 
                               .Q(Q_DUMMY[1]));
   // synthesis attribute HU_SET of I_Q1 is "I_Q1_6"
   FTCLEX_MXILINX_PCL_7b I_Q2 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[2]), 
                               .L(L), 
                               .T(T2), 
                               .Q(Q_DUMMY[2]));
   // synthesis attribute HU_SET of I_Q2 is "I_Q2_5"
   FTCLEX_MXILINX_PCL_7b I_Q3 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[3]), 
                               .L(L), 
                               .T(T3), 
                               .Q(Q_DUMMY[3]));
   // synthesis attribute HU_SET of I_Q3 is "I_Q3_4"
   FTCLEX_MXILINX_PCL_7b I_Q4 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[4]), 
                               .L(L), 
                               .T(XLXN_58), 
                               .Q(Q_DUMMY[4]));
   // synthesis attribute HU_SET of I_Q4 is "I_Q4_3"
   FTCLEX_MXILINX_PCL_7b I_Q5 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[5]), 
                               .L(L), 
                               .T(XLXN_52), 
                               .Q(Q_DUMMY[5]));
   // synthesis attribute HU_SET of I_Q5 is "I_Q5_2"
   FTCLEX_MXILINX_PCL_7b I_Q6 (.C(CLK), 
                               .CE(XLXN_169), 
                               .CLR(CLR), 
                               .D(D[6]), 
                               .L(L), 
                               .T(XLXN_55), 
                               .Q(Q_DUMMY[6]));
   // synthesis attribute HU_SET of I_Q6 is "I_Q6_1"
   AND4 I_36_17 (.I0(Q_DUMMY[3]), 
                 .I1(Q_DUMMY[2]), 
                 .I2(Q_DUMMY[1]), 
                 .I3(Q_DUMMY[0]), 
                 .O(XLXN_58));
   AND3 I_36_18 (.I0(Q_DUMMY[2]), 
                 .I1(Q_DUMMY[1]), 
                 .I2(Q_DUMMY[0]), 
                 .O(T3));
   AND2 I_36_19 (.I0(Q_DUMMY[1]), 
                 .I1(Q_DUMMY[0]), 
                 .O(T2));
   VCC I_36_31 (.P(XLXN_19));
   OR2 I_36_68 (.I0(CE), 
                .I1(L), 
                .O(XLXN_169));
   AND2 XLXI_32 (.I0(Q_DUMMY[4]), 
                 .I1(XLXN_58), 
                 .O(XLXN_52));
   AND3 XLXI_35 (.I0(Q_DUMMY[5]), 
                 .I1(Q_DUMMY[4]), 
                 .I2(XLXN_58), 
                 .O(XLXN_55));
endmodule
