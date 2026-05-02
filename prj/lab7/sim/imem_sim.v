`timescale 1ns / 1ps
module imem (
    input         clk,
    input  [9:0]  addr,
    output [31:0] data
);

    imem_bram core (
        .addr(addr),
        .clk(clk),
        .din(32'b0),
        .dout(data),
        .we(1'b0)
    );

endmodule
