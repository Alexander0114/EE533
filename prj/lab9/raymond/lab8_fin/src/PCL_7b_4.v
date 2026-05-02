////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : PCL_7b_4.vf
// /___/   /\     Timestamp : 03/04/2026 00:51:00
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/PCL_7b_4.sch" PCL_7b_4.vf
//Design Name: PCL_7b_4
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module D2_4E_MXILINX_PCL_7b_4(A0, 
                              A1, 
                              E, 
                              D0, 
                              D1, 
                              D2, 
                              D3);

    input A0;
    input A1;
    input E;
   output D0;
   output D1;
   output D2;
   output D3;
   
   
   AND3 I_36_30 (.I0(A1), 
                 .I1(A0), 
                 .I2(E), 
                 .O(D3));
   AND3B1 I_36_31 (.I0(A0), 
                   .I1(A1), 
                   .I2(E), 
                   .O(D2));
   AND3B1 I_36_32 (.I0(A1), 
                   .I1(A0), 
                   .I2(E), 
                   .O(D1));
   AND3B2 I_36_33 (.I0(A0), 
                   .I1(A1), 
                   .I2(E), 
                   .O(D0));
endmodule
`timescale 1ns / 1ps

module PCL_7b_4(CLK, 
                CLR, 
                D, 
                ID, 
                L, 
                Q);

    input CLK;
    input CLR;
    input [6:0] D;
    input [1:0] ID;
    input L;
   output [6:0] Q;
   
   wire vdd;
   wire XLXN_7;
   wire XLXN_16;
   wire XLXN_17;
   wire XLXN_18;
   wire [6:0] XLXN_47;
   wire [6:0] XLXN_48;
   wire [6:0] XLXN_49;
   wire [6:0] XLXN_50;
   wire XLXN_52;
   wire XLXN_53;
   wire XLXN_54;
   wire XLXN_56;
   
   D2_4E_MXILINX_PCL_7b_4 XLXI_5 (.A0(ID[0]), 
                                  .A1(ID[1]), 
                                  .E(vdd), 
                                  .D0(XLXN_52), 
                                  .D1(XLXN_53), 
                                  .D2(XLXN_54), 
                                  .D3(XLXN_56));
   // synthesis attribute HU_SET of XLXI_5 is "XLXI_5_0"
   VCC XLXI_6 (.P(vdd));
   PCL_7b XLXI_189 (.CE(XLXN_52), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .D(D[6:0]), 
                    .L(XLXN_7), 
                    .Q(XLXN_47[6:0]));
   PCL_7b XLXI_190 (.CE(XLXN_53), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .D(D[6:0]), 
                    .L(XLXN_16), 
                    .Q(XLXN_48[6:0]));
   PCL_7b XLXI_191 (.CE(XLXN_54), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .D(D[6:0]), 
                    .L(XLXN_17), 
                    .Q(XLXN_49[6:0]));
   PCL_7b XLXI_192 (.CE(XLXN_56), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .D(D[6:0]), 
                    .L(XLXN_18), 
                    .Q(XLXN_50[6:0]));
   AND2 XLXI_197 (.I0(L), 
                  .I1(XLXN_56), 
                  .O(XLXN_7));
   AND2 XLXI_198 (.I0(L), 
                  .I1(XLXN_52), 
                  .O(XLXN_16));
   AND2 XLXI_199 (.I0(L), 
                  .I1(XLXN_53), 
                  .O(XLXN_17));
   AND2 XLXI_200 (.I0(L), 
                  .I1(XLXN_54), 
                  .O(XLXN_18));
   Mux4_1_7b XLXI_206 (.D0(XLXN_47[6:0]), 
                       .D1(XLXN_48[6:0]), 
                       .D2(XLXN_49[6:0]), 
                       .D3(XLXN_50[6:0]), 
                       .S(ID[1:0]), 
                       .O(Q[6:0]));
endmodule
