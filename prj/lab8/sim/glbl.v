// Xilinx global signals stub for simulation
`timescale 1ns / 1ps
module glbl;
    reg GSR;
    initial begin
        GSR = 1'b1;
        #100 GSR = 1'b0;
    end
endmodule
