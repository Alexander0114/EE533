`timescale 1ns / 1ps
module tensor_unit (
    input         clk,
    input         rst,
    input         start,
    input  [63:0] operand_a,
    input  [63:0] operand_b,
    input  [63:0] operand_c,
    input  [2:0]  op_mode,
    input         relu_en,
    output [63:0] result,
    output        done
);

    wire [3:0] lane_ready;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : LANE
            bf16_lane #(.PIPE_DEPTH(4)) lane_inst (
                .clk(clk),
                .rst(rst),
                .en(start),
                .src_a(operand_a[16*i +: 16]),
                .src_b(operand_b[16*i +: 16]),
                .src_c(operand_c[16*i +: 16]),
                .op_mode(op_mode),
                .relu_en(relu_en),
                .result(result[16*i +: 16]),
                .output_ready(lane_ready[i])
            );
        end
    endgenerate

    assign done = lane_ready[0];

endmodule
