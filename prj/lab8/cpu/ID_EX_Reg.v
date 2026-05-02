////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : ID_EX_Reg.vf
// /___/   /\     Timestamp : 02/21/2026 01:21:59
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/ID_EX_Reg.sch" ID_EX_Reg.vf
//Design Name: ID_EX_Reg
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module ID_EX_Reg(CE, 
                 CLK, 
                 CLR, 
                 ID_Addr, 
                 ID_ALUC, 
                 ID_ALUD, 
                 ID_ALUSrc, 
                 ID_B, 
                 ID_BT, 
                 ID_MemR, 
                 ID_MemW, 
                 ID_M2Reg, 
                 ID_RegW, 
                 ID_R1, 
                 ID_R2, 
                 ID_TID, 
                 EX_Addr, 
                 EX_ALUC, 
                 EX_ALUD, 
                 EX_ALUSrc, 
                 EX_B, 
                 EX_BT, 
                 EX_MemR, 
                 EX_MemW, 
                 EX_M2Reg, 
                 EX_RegW, 
                 EX_R1, 
                 EX_R2, 
                 EX_TID);

    input CE;
    input CLK;
    input CLR;
    input [3:0] ID_Addr;
    input [3:0] ID_ALUC;
    input [11:0] ID_ALUD;
    input ID_ALUSrc;
    input ID_B;
    input [1:0] ID_BT;
    input ID_MemR;
    input ID_MemW;
    input ID_M2Reg;
    input ID_RegW;
    input [63:0] ID_R1;
    input [63:0] ID_R2;
    input [1:0] ID_TID;
   output [3:0] EX_Addr;
   output [3:0] EX_ALUC;
   output [11:0] EX_ALUD;
   output EX_ALUSrc;
   output EX_B;
   output [1:0] EX_BT;
   output EX_MemR;
   output EX_MemW;
   output EX_M2Reg;
   output EX_RegW;
   output [63:0] EX_R1;
   output [63:0] EX_R2;
   output [1:0] EX_TID;
   
   
   dff64 XLXI_15 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(ID_R2[63:0]), 
                  .Q(EX_R2[63:0]));
   FDCE XLXI_28 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_B), 
                 .Q(EX_B));
   defparam XLXI_28.INIT = 1'b0;
   FDCE XLXI_29 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_MemW), 
                 .Q(EX_MemW));
   defparam XLXI_29.INIT = 1'b0;
   FDCE XLXI_30 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_MemR), 
                 .Q(EX_MemR));
   defparam XLXI_30.INIT = 1'b0;
   FDCE XLXI_39 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_M2Reg), 
                 .Q(EX_M2Reg));
   defparam XLXI_39.INIT = 1'b0;
   FDCE XLXI_59 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_RegW), 
                 .Q(EX_RegW));
   defparam XLXI_59.INIT = 1'b0;
   FDCE XLXI_65 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(ID_ALUSrc), 
                 .Q(EX_ALUSrc));
   defparam XLXI_65.INIT = 1'b0;
   dff4 XLXI_79 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(ID_ALUC[3:0]), 
                 .Q(EX_ALUC[3:0]));
   dff64 XLXI_80 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(ID_R1[63:0]), 
                  .Q(EX_R1[63:0]));
   dff4 XLXI_81 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(ID_Addr[3:0]), 
                 .Q(EX_Addr[3:0]));
   dff12 XLXI_82 (.CE(CE), 
                  .CLK(CLK), 
                  .CLR(CLR), 
                  .D(ID_ALUD[11:0]), 
                  .Q(EX_ALUD[11:0]));
   dff2 XLXI_83 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(ID_BT[1:0]), 
                 .Q(EX_BT[1:0]));
   dff2 XLXI_84 (.CE(CE), 
                 .CLK(CLK), 
                 .CLR(CLR), 
                 .D(ID_TID[1:0]), 
                 .Q(EX_TID[1:0]));
endmodule
