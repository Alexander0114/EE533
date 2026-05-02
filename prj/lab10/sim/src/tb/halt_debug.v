`timescale 1ns / 1ps
`include "soc.v"
module halt_debug;
localparam CLK=10;
localparam [31:0] NOP=32'hE1A00000, HALT=32'hEAFFFFFE;
reg clk,rst_n; initial clk=0; always #(CLK/2) clk=~clk;
reg [63:0] in_data; reg [7:0] in_ctrl; reg in_wr; wire in_rdy;
wire [63:0] out_data; wire [7:0] out_ctrl; wire out_wr; reg out_rdy;
soc u(.clk(clk),.rst_n(rst_n),.in_data(in_data),.in_ctrl(in_ctrl),
  .in_wr(in_wr),.in_rdy(in_rdy),.out_data(out_data),.out_ctrl(out_ctrl),
  .out_wr(out_wr),.out_rdy(out_rdy));
task tick; begin @(posedge clk); #1; end endtask
function [63:0] cmd; input [3:0] op; input [11:0] a; input [15:0] n; input [31:0] p;
  cmd={op,a,n,p}; endfunction
task rx; input [63:0] d; input [7:0] c; begin in_data=d;in_ctrl=c;in_wr=1;tick; end endtask
task rx_end; begin in_wr=0;in_data=0;in_ctrl=0;tick; end endtask

integer cyc;
initial begin
  rst_n=0;in_wr=0;in_data=0;in_ctrl=0;out_rdy=1;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  // Tiny ARM program: 4 instrs = 2 DWs
  // [0] NOP, [1] NOP, [2] B ., [3] NOP
  rx(cmd(4'h1, 12'h000, 16'd2, 32'h0), 8'h04);
  rx({NOP, NOP}, 8'h00);
  rx({NOP, HALT}, 8'h00);  // [3]NOP [2]B.

  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00); // CPU_START
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00); // SEND_PKT
  rx_end;

  // Wait for pkt_proc to start CPU
  cyc = 0;
  while (!u.u_cpu_mt.running && cyc < 5000) begin tick; cyc=cyc+1; end
  $display("CPU started after %0d cycles, running=%b", cyc, u.u_cpu_mt.running);

  // Monitor halt signals for 100 cycles after CPU starts
  begin : mon
    integer i;
    for (i=0; i<100; i=i+1) begin
      if (i < 20 || u.u_cpu_mt.halted != 0 || u.cpu_done_w)
        $display("[%0d] tid_if=%0d tid_if2=%0d valid_if2=%b stall=%b imem=%h halted=%b seen=%b running=%b done=%b pc0=%h pc1=%h",
          i, u.u_cpu_mt.tid_if, u.u_cpu_mt.tid_if2,
          u.u_cpu_mt.valid_if2, u.u_cpu_mt.stall_all,
          u.u_cpu_mt.i_mem_data_i, u.u_cpu_mt.halted,
          u.u_cpu_mt.halt_seen_once, u.u_cpu_mt.running,
          u.cpu_done_w, u.u_cpu_mt.pc_thread[0], u.u_cpu_mt.pc_thread[1]);
      if (u.cpu_done_w) begin
        $display("CPU_DONE at cycle %0d!", i);
        disable mon;
      end
      tick;
    end
    $display("No CPU_DONE in 100 cycles");
  end

  #100; $finish;
end
endmodule
