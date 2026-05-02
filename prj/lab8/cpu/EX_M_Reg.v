////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : EX_M_Reg.vf
// /___/   /\     Timestamp : 02/21/2026 13:10:18
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/EX_M_Reg.sch" EX_M_Reg.vf
//Design Name: EX_M_Reg
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module EX_M_Reg(CE, 
                CLK, 
                CLR, 
                EX_Addr, 
                EX_ALU, 
                EX_B, 
                EX_ID, 
                EX_MemR, 
                EX_MemW, 
                EX_M2Reg, 
                EX_RegW, 
                EX_R2, 
                M_Addr, 
                M_ALU, 
                M_B, 
                M_ID, 
                M_MemR, 
                M_MemW, 
                M_M2Reg, 
                M_RegW, 
                M_R2);

    input CE;
    input CLK;
    input CLR;
    input [3:0] EX_Addr;
    input [63:0] EX_ALU;
    input EX_B;
    input [1:0] EX_ID;
    input EX_MemR;
    input EX_MemW;
    input EX_M2Reg;
    input EX_RegW;
    input [63:0] EX_R2;
   output [3:0] M_Addr;
   output [63:0] M_ALU;
   output M_B;
   output [1:0] M_ID;
   output M_MemR;
   output M_MemW;
   output M_M2Reg;
   output M_RegW;
   output [63:0] M_R2;
   
   
   dff64 XLXI_14 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(EX_ALU[63:0]), 
                  .Q(M_ALU[63:0]));
   dff64 XLXI_15 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(EX_R2[63:0]), 
                  .Q(M_R2[63:0]));
   FDCE XLXI_28 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(EX_B), 
                 .Q(M_B));
   defparam XLXI_28.INIT = 1'b0;
   FDCE XLXI_29 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(EX_MemW), 
                 .Q(M_MemW));
   defparam XLXI_29.INIT = 1'b0;
   FDCE XLXI_30 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(EX_MemR), 
                 .Q(M_MemR));
   defparam XLXI_30.INIT = 1'b0;
   FDCE XLXI_39 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(EX_M2Reg), 
                 .Q(M_M2Reg));
   defparam XLXI_39.INIT = 1'b0;
   FDCE XLXI_59 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(EX_RegW), 
                 .Q(M_RegW));
   defparam XLXI_59.INIT = 1'b0;
   dff4 XLXI_83 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(EX_Addr[3:0]), 
                 .Q(M_Addr[3:0]));
   dff2 XLXI_84 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(EX_ID[1:0]), 
                 .Q(M_ID[1:0]));
endmodule
