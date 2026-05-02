`timescale 1ns / 1ps
module glbl;
    reg GSR;
    initial begin GSR = 1; #10 GSR = 0; end
endmodule

module debug_tb;
    reg clk, rst, run;
    reg [9:0] thread_id;
    wire halted;
    wire [9:0] debug_pc;
    wire [31:0] debug_ir;
    wire [3:0] debug_state;

    gpu_top uut (.clk(clk), .rst(rst), .run(run), .thread_id(thread_id),
                 .halted(halted), .debug_pc(debug_pc), .debug_ir(debug_ir), .debug_state(debug_state));

    initial clk = 0;
    always #5 clk = ~clk;

    integer cyc;
    always @(posedge clk) begin
        cyc = cyc + 1;
        if (!rst && debug_pc >= 39 && debug_pc <= 45)
            $display("[%4d] PC=%d St=%d IR=%08h | rf_rd_a=%d rf_rd_b=%d cmp_a=%h cmp_b=%h branch_taken=%b | R7=%h R8=%h",
                cyc, debug_pc, debug_state, debug_ir,
                uut.ctrl_inst.rf_rd_a, uut.ctrl_inst.rf_rd_b,
                uut.rf_a, uut.rf_b,
                uut.ctrl_inst.branch_taken,
                uut.rf_inst.rf[7], uut.rf_inst.rf[8]);
    end

    initial begin
        cyc = 0; rst = 1; run = 0; thread_id = 0;
        repeat(6) @(posedge clk);
        rst = 0; @(posedge clk);
        run = 1; @(posedge clk); run = 0;
        repeat(300) @(posedge clk);
        $finish;
    end
endmodule
