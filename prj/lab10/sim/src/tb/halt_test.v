
`timescale 1ns / 1ps
`include "soc.v"
module halt_test;
localparam CLK_PERIOD=10;
localparam [31:0] NOP=32'hE1A00000, HALT=32'hEAFFFFFE;
reg clk,rst_n; initial clk=0; always #(CLK_PERIOD/2) clk=~clk;
reg [63:0] in_data; reg [7:0] in_ctrl; reg in_wr; wire in_rdy;
wire [63:0] out_data; wire [7:0] out_ctrl; wire out_wr; reg out_rdy;
soc u_soc(.clk(clk),.rst_n(rst_n),.in_data(in_data),.in_ctrl(in_ctrl),
  .in_wr(in_wr),.in_rdy(in_rdy),.out_data(out_data),.out_ctrl(out_ctrl),
  .out_wr(out_wr),.out_rdy(out_rdy));
task tick; begin @(posedge clk); #1; end endtask
function [63:0] cmd; input [3:0] op; input [11:0] a; input [15:0] n; input [31:0] p;
  cmd={op,a,n,p}; endfunction
task rx; input [63:0] d; input [7:0] c; begin in_data=d;in_ctrl=c;in_wr=1;tick; end endtask
task rx_end; begin in_wr=0;in_data=0;in_ctrl=0;tick; end endtask

initial begin
  rst_n=0;in_wr=0;in_data=0;in_ctrl=0;out_rdy=1;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  // Minimal ARM: just B . (halt immediately)
  // 2 instrs = 1 DW
  rx(cmd(4'h1, 12'h000, 16'd1, 32'h0), 8'h04);
  rx({NOP, HALT}, 8'h00);  // [1]NOP [0]B.

  // No data needed, just CPU_START
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;

  // Monitor halt detection for 200 cycles
  repeat(50) tick;  // let pkt_proc start
  begin : monitor_loop
    integer i;
    for (i=0; i<500; i=i+1) begin
      if (i % 50 == 0)
        $display("  [%0t] halted=%b halt_seen=%b running=%b cpu_done=%b pc0=%h",
          $time, u_soc.u_cpu_mt.halted, u_soc.u_cpu_mt.halt_seen_once,
          u_soc.u_cpu_mt.running, u_soc.cpu_done_w,
          u_soc.u_cpu_mt.pc_thread[0]);
      if (u_soc.cpu_done_w) begin
        $display("  CPU_DONE at cycle %0d!", i);
        disable monitor_loop;
      end
      tick;
    end
    $display("  NO CPU_DONE in 500 cycles");
  end

  #100; $finish;
end
endmodule

