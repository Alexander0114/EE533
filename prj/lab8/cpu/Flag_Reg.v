////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : Flag_Reg.vf
// /___/   /\     Timestamp : 02/20/2026 23:24:16
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Desktop/ARM_Processor_4T/Flag_Reg.sch" Flag_Reg.vf
//Design Name: Flag_Reg
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module Flag_Reg(CE, 
                CLK, 
                CLR, 
                C_in, 
                N_in, 
                V_in, 
                Z_in, 
                C_out, 
                N_out, 
                V_out, 
                Z_out);

    input CE;
    input CLK;
    input CLR;
    input C_in;
    input N_in;
    input V_in;
    input Z_in;
   output C_out;
   output N_out;
   output V_out;
   output Z_out;
   
   
   FDCE XLXI_12 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(C_in), 
                 .Q(C_out));
   defparam XLXI_12.INIT = 1'b0;
   FDCE XLXI_13 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(V_in), 
                 .Q(V_out));
   defparam XLXI_13.INIT = 1'b0;
   FDCE XLXI_14 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(Z_in), 
                 .Q(Z_out));
   defparam XLXI_14.INIT = 1'b0;
   FDCE XLXI_15 (.C(CLK), 
                 .CE(CE), 
                 .CLR(CLR), 
                 .D(N_in), 
                 .Q(N_out));
   defparam XLXI_15.INIT = 1'b0;
endmodule
