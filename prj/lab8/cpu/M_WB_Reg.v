////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : M_WB_Reg.vf
// /___/   /\     Timestamp : 02/21/2026 13:10:19
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/M_WB_Reg.sch" M_WB_Reg.vf
//Design Name: M_WB_Reg
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module M_WB_Reg(CE, 
                CLK, 
                CLR, 
                M_Addr, 
                M_ALU, 
                M_Data, 
                M_ID, 
                M_M2Reg, 
                M_RegW, 
                WB_Addr, 
                WB_ALU, 
                WB_Data, 
                WB_ID, 
                WB_M2Reg, 
                WB_RegW);

    input CE;
    input CLK;
    input CLR;
    input [3:0] M_Addr;
    input [63:0] M_ALU;
    input [63:0] M_Data;
    input [1:0] M_ID;
    input M_M2Reg;
    input M_RegW;
   output [3:0] WB_Addr;
   output [63:0] WB_ALU;
   output [63:0] WB_Data;
   output [1:0] WB_ID;
   output WB_M2Reg;
   output WB_RegW;
   
   
   FDCE XLXI_39 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(M_M2Reg), 
                 .Q(WB_M2Reg));
   defparam XLXI_39.INIT = 1'b0;
   FDCE XLXI_59 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(M_RegW), 
                 .Q(WB_RegW));
   defparam XLXI_59.INIT = 1'b0;
   dff64 XLXI_80 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(M_ALU[63:0]), 
                  .Q(WB_ALU[63:0]));
   dff64 XLXI_82 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(M_Data[63:0]), 
                  .Q(WB_Data[63:0]));
   dff4 XLXI_84 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(M_Addr[3:0]), 
                 .Q(WB_Addr[3:0]));
   dff2 XLXI_85 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(M_ID[1:0]), 
                 .Q(WB_ID[1:0]));
endmodule
