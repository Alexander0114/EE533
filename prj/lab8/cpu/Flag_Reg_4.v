////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : Flag_Reg_4.vf
// /___/   /\     Timestamp : 02/21/2026 01:22:07
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/Flag_Reg_4.sch" Flag_Reg_4.vf
//Design Name: Flag_Reg_4
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module M2_1E_MXILINX_Flag_Reg_4(D0, 
                                D1, 
                                E, 
                                S0, 
                                O);

    input D0;
    input D1;
    input E;
    input S0;
   output O;
   
   wire M0;
   wire M1;
   
   AND3 I_36_30 (.I0(D1), 
                 .I1(E), 
                 .I2(S0), 
                 .O(M1));
   AND3B1 I_36_31 (.I0(S0), 
                   .I1(E), 
                   .I2(D0), 
                   .O(M0));
   OR2 I_36_38 (.I0(M1), 
                .I1(M0), 
                .O(O));
endmodule
`timescale 1ns / 1ps

module M4_1E_MXILINX_Flag_Reg_4(D0, 
                                D1, 
                                D2, 
                                D3, 
                                E, 
                                S0, 
                                S1, 
                                O);

    input D0;
    input D1;
    input D2;
    input D3;
    input E;
    input S0;
    input S1;
   output O;
   
   wire M01;
   wire M23;
   
   M2_1E_MXILINX_Flag_Reg_4 I_M01 (.D0(D0), 
                                   .D1(D1), 
                                   .E(E), 
                                   .S0(S0), 
                                   .O(M01));
   // synthesis attribute HU_SET of I_M01 is "I_M01_1"
   M2_1E_MXILINX_Flag_Reg_4 I_M23 (.D0(D2), 
                                   .D1(D3), 
                                   .E(E), 
                                   .S0(S0), 
                                   .O(M23));
   // synthesis attribute HU_SET of I_M23 is "I_M23_0"
   MUXF5 I_O (.I0(M01), 
              .I1(M23), 
              .S(S1), 
              .O(O));
endmodule
`timescale 1ns / 1ps

module D2_4E_MXILINX_Flag_Reg_4(A0, 
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

module Flag_Reg_4(CLK, 
                  CLR, 
                  C_in, 
                  ID, 
                  N_in, 
                  V_in, 
                  Z_in, 
                  C_out, 
                  N_out, 
                  V_out, 
                  Z_out);

    input CLK;
    input CLR;
    input C_in;
    input [1:0] ID;
    input N_in;
    input V_in;
    input Z_in;
   output C_out;
   output N_out;
   output V_out;
   output Z_out;
   
   wire vdd;
   wire XLXN_1;
   wire XLXN_2;
   wire XLXN_3;
   wire XLXN_4;
   wire XLXN_23;
   wire XLXN_26;
   wire XLXN_27;
   wire XLXN_28;
   wire XLXN_29;
   wire XLXN_33;
   wire XLXN_35;
   wire XLXN_36;
   wire XLXN_37;
   wire XLXN_38;
   wire XLXN_39;
   wire XLXN_40;
   wire XLXN_41;
   wire XLXN_42;
   wire XLXN_44;
   wire XLXN_45;
   
   Flag_Reg XLXI_1 (.CE(XLXN_1), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .C_in(C_in), 
                    .N_in(N_in), 
                    .V_in(V_in), 
                    .Z_in(Z_in), 
                    .C_out(XLXN_37), 
                    .N_out(XLXN_23), 
                    .V_out(XLXN_41), 
                    .Z_out(XLXN_29));
   Flag_Reg XLXI_2 (.CE(XLXN_2), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .C_in(C_in), 
                    .N_in(N_in), 
                    .V_in(V_in), 
                    .Z_in(Z_in), 
                    .C_out(XLXN_38), 
                    .N_out(XLXN_26), 
                    .V_out(XLXN_42), 
                    .Z_out(XLXN_33));
   Flag_Reg XLXI_3 (.CE(XLXN_3), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .C_in(C_in), 
                    .N_in(N_in), 
                    .V_in(V_in), 
                    .Z_in(Z_in), 
                    .C_out(XLXN_39), 
                    .N_out(XLXN_27), 
                    .V_out(XLXN_44), 
                    .Z_out(XLXN_35));
   Flag_Reg XLXI_4 (.CE(XLXN_4), 
                    .CLK(CLK), 
                    .CLR(CLR), 
                    .C_in(C_in), 
                    .N_in(N_in), 
                    .V_in(V_in), 
                    .Z_in(Z_in), 
                    .C_out(XLXN_40), 
                    .N_out(XLXN_28), 
                    .V_out(XLXN_45), 
                    .Z_out(XLXN_36));
   D2_4E_MXILINX_Flag_Reg_4 XLXI_5 (.A0(ID[0]), 
                                    .A1(ID[1]), 
                                    .E(vdd), 
                                    .D0(XLXN_1), 
                                    .D1(XLXN_2), 
                                    .D2(XLXN_3), 
                                    .D3(XLXN_4));
   // synthesis attribute HU_SET of XLXI_5 is "XLXI_5_2"
   VCC XLXI_6 (.P(vdd));
   M4_1E_MXILINX_Flag_Reg_4 XLXI_8 (.D0(XLXN_23), 
                                    .D1(XLXN_26), 
                                    .D2(XLXN_27), 
                                    .D3(XLXN_28), 
                                    .E(vdd), 
                                    .S0(ID[0]), 
                                    .S1(ID[1]), 
                                    .O(N_out));
   // synthesis attribute HU_SET of XLXI_8 is "XLXI_8_3"
   M4_1E_MXILINX_Flag_Reg_4 XLXI_10 (.D0(XLXN_29), 
                                     .D1(XLXN_33), 
                                     .D2(XLXN_35), 
                                     .D3(XLXN_36), 
                                     .E(vdd), 
                                     .S0(ID[0]), 
                                     .S1(ID[1]), 
                                     .O(Z_out));
   // synthesis attribute HU_SET of XLXI_10 is "XLXI_10_4"
   M4_1E_MXILINX_Flag_Reg_4 XLXI_11 (.D0(XLXN_37), 
                                     .D1(XLXN_38), 
                                     .D2(XLXN_39), 
                                     .D3(XLXN_40), 
                                     .E(vdd), 
                                     .S0(ID[0]), 
                                     .S1(ID[1]), 
                                     .O(C_out));
   // synthesis attribute HU_SET of XLXI_11 is "XLXI_11_5"
   M4_1E_MXILINX_Flag_Reg_4 XLXI_12 (.D0(XLXN_41), 
                                     .D1(XLXN_42), 
                                     .D2(XLXN_44), 
                                     .D3(XLXN_45), 
                                     .E(vdd), 
                                     .S0(ID[0]), 
                                     .S1(ID[1]), 
                                     .O(V_out));
   // synthesis attribute HU_SET of XLXI_12 is "XLXI_12_6"
endmodule
