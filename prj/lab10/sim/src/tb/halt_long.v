`timescale 1ns / 1ps
`include "soc.v"
module halt_long;
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

reg counting; integer hw_count; reg [1:0] sd;
always @(posedge clk) begin
    if (!rst_n) begin counting<=0; hw_count<=0; sd<=0; end
    else if (u.pp_cpu_start) begin counting<=1; hw_count<=0; sd<=2; end
    else if (sd>0) begin sd<=sd-1; hw_count<=hw_count+1; end
    else if (u.cpu_done_w && counting) begin counting<=0; end
    else if (counting) hw_count<=hw_count+1;
end

initial begin
  rst_n=0;in_wr=0;in_data=0;in_ctrl=0;out_rdy=1;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  // Test 1: 4 instrs, B . at instr 2 (should halt ~13 cycles)
  $display("--- Test 1: 4 instrs, B. at [2] ---");
  rx(cmd(4'h1,12'h000,16'd2,32'h0),8'h04);
  rx({NOP,NOP},8'h00);
  rx({NOP,HALT},8'h00);
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;
  begin : w1
    integer c; c=0;
    while(!u.pp_active && c<5000) begin tick;c=c+1; end
    while(u.pp_active && c<20000) begin tick;c=c+1; end
  end
  $display("  Cycles: %0d", hw_count);

  // Test 2: 20 instrs, B . at instr 18 (should halt ~18*4+13 = ~85 cycles)
  repeat(100) tick;
  $display("--- Test 2: 20 instrs, B. at [18] ---");
  rx(cmd(4'h1,12'h000,16'd10,32'h0),8'h04);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,HALT},8'h00);  // B . at instr 18
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;
  begin : w2
    integer c; c=0;
    while(!u.pp_active && c<5000) begin tick;c=c+1; end
    while(u.pp_active && c<20000) begin tick;c=c+1; end
  end
  $display("  Cycles: %0d", hw_count);

  // Test 3: 74 instrs (same as GPU test), B . at instr 72
  repeat(100) tick;
  $display("--- Test 3: 74 instrs, B. at [72] ---");
  rx(cmd(4'h1,12'h000,16'd37,32'h0),8'h04);
  // 36 DWs of NOPs
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,HALT},8'h00);  // B . at instr 72
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;
  begin : w3
    integer c; c=0;
    while(!u.pp_active && c<5000) begin tick;c=c+1; end
    while(u.pp_active && c<20000) begin tick;c=c+1; end
  end
  $display("  Cycles: %0d", hw_count);

  $display("Done"); #100; $finish;
end
endmodule
