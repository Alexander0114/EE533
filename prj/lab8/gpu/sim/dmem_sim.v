`timescale 1ns / 1ps
module dmem (
    input         clk,
    input         we,
    input  [9:0]  addr,
    input  [63:0] w_data,
    output [63:0] r_data
);

    dmem_bram core (
        .addr(addr),
        .clk(clk),
        .din(w_data),
        .dout(r_data),
        .we(we)
    );

endmodule
