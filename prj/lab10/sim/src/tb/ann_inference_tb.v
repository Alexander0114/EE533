// 2-layer ANN inference: Y = W2 * ReLU(W1 * X + B1) + B2
`timescale 1ns / 1ps
`include "soc.v"

module ann_inference_tb;

localparam CLK_PERIOD=10;
localparam MAX_CYCLES=15000;
localparam [31:0] ARM_NOP=32'hE1A00000, ARM_HALT=32'hEAFFFFFE;

reg clk,rst_n; initial clk=0; always #(CLK_PERIOD/2) clk=~clk;
reg [63:0] in_data; reg [7:0] in_ctrl; reg in_wr; wire in_rdy;
wire [63:0] out_data; wire [7:0] out_ctrl; wire out_wr; reg out_rdy;

soc u_soc(.clk(clk),.rst_n(rst_n),.in_data(in_data),.in_ctrl(in_ctrl),
  .in_wr(in_wr),.in_rdy(in_rdy),.out_data(out_data),.out_ctrl(out_ctrl),
  .out_wr(out_wr),.out_rdy(out_rdy));

integer pass_cnt=0,fail_cnt=0,test_id=0;
reg [63:0] tx_data[0:127];
integer tx_cnt;

task tick; begin @(posedge clk); #1; end endtask
function [63:0] cmd; input [3:0] op; input [11:0] a; input [15:0] n; input [31:0] p;
  cmd={op,a,n,p}; endfunction
task rx; input [63:0] d; input [7:0] c; begin in_data=d;in_ctrl=c;in_wr=1;tick; end endtask
task rx_end; begin in_wr=0;in_data=0;in_ctrl=0;tick; end endtask

task wait_and_capture; input integer mx; integer c;
begin
  tx_cnt=0;c=0;
  while(!u_soc.pp_active&&c<mx) begin tick;c=c+1; end
  while(u_soc.pp_active&&c<mx) begin
    if(out_wr&&out_rdy) begin tx_data[tx_cnt]=out_data;tx_cnt=tx_cnt+1; end
    tick;c=c+1;
  end
  if(c>=mx) $display("  [TIMEOUT]");
  repeat(5) tick;
end endtask

task check64; input [63:0] v,e; input [80*8-1:0] nm;
begin
  test_id=test_id+1;
  if(v===e) begin $display("  [PASS] T%0d: %0s=0x%016h",test_id,nm,v); pass_cnt=pass_cnt+1; end
  else begin $display("  [FAIL] T%0d: %0s=0x%016h exp 0x%016h",test_id,nm,v,e); fail_cnt=fail_cnt+1; end
end endtask
task checkN; input integer v,e; input [80*8-1:0] nm;
begin
  test_id=test_id+1;
  if(v==e) begin $display("  [PASS] T%0d: %0s=%0d",test_id,nm,v); pass_cnt=pass_cnt+1; end
  else begin $display("  [FAIL] T%0d: %0s=%0d exp %0d",test_id,nm,v,e); fail_cnt=fail_cnt+1; end
end endtask

initial begin
  rst_n=0;in_wr=0;in_data=0;in_ctrl=0;out_rdy=1;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  $display("================================================================");
  $display("  2-Layer ANN: Y = W2 * ReLU(W1 * X + B1) + B2");
  $display("================================================================");

  rx(cmd(4'h1,12'h000,16'd76,32'h0),8'h04);
  rx({32'hEE000A10,32'hE3A00000},8'h00);
  rx({32'hE3A01020,32'hEE010A10},8'h00);
  rx({32'hE3A02005,32'hEE021A10},8'h00);
  rx({32'hE1A00000,32'hEE032A10},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hEE000A10,32'hE3A00020},8'h00);
  rx({32'hEE011A10,32'hE3A01000},8'h00);
  rx({32'hEE022A10,32'hE3A0200A},8'h00);
  rx({32'hEE033A10,32'hE3A03041},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hEE040A10,32'hE3A00000},8'h00);
  rx({32'hEE071A10,32'hE3A0100F},8'h00);
  rx({32'hEE052A10,32'hE3A02001},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hEE000A10,32'hE3A00018},8'h00);
  rx({32'hEE011A10,32'hE3A01048},8'h00);
  rx({32'hEE022A10,32'hE3A02002},8'h00);
  rx({32'hEE033A10,32'hE3A03043},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hE1A00000},8'h00);
  rx({32'hE1A00000,32'hEAFFFFFE},8'h00);

  rx(cmd(4'h2,12'h000,16'd16,32'h0),8'h00);
  rx({32'hF4400000,32'h20000004},8'h00);
  rx({32'hF4800000,32'h20000000},8'h00);
  rx({32'hF4C00000,32'h20000008},8'h00);
  rx({32'h20000000,32'hECC48C00},8'h00);
  rx({32'h54DD0000,32'h54CC0000},8'h00);
  rx({32'h54FF0000,32'h54EE0000},8'h00);
  rx({32'hFCC00000,32'h20000014},8'h00);
  rx({32'hF4400000,32'h2000000C},8'h00);
  rx({32'hF4800000,32'h20000014},8'h00);
  rx({32'hF4C00000,32'h20000010},8'h00);
  rx({32'h20000018,32'hECC48C00},8'h00);
  rx({32'hC8000000,32'hFCC00000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);

  rx(cmd(4'h2,12'h020,16'd20,32'h0),8'h00);
  rx({32'h3F803F80,32'h3F803F80},8'h00);
  rx({32'h3E00BE80,32'h3E803F00},8'h00);
  rx({32'h3E003E00,32'h3E003E00},8'h00);
  rx({32'hBE00BE80,32'hBE803F00},8'h00);
  rx({32'h3E003E00,32'h3E003E00},8'h00);
  rx({32'h3F803F80,32'h3F803F80},8'h00);
  rx({32'hBE003E80,32'h3F003E00},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h00003E00,32'h3F00BE80},8'h00);
  rx({32'hBE00BE00,32'hBE00BE00},8'h00);
  rx({32'h3F803F80,32'h3F803F80},8'h00);
  rx({32'h00003F00,32'h3E80BE00},8'h00);
  rx({32'hBD80BD80,32'hBD80BD80},8'h00);
  rx({32'hBE003F00,32'h3E00BE00},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h3F803F80,32'h3F803F80},8'h00);
  rx({32'h3F003E00,32'hBE000000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);
  rx({32'h3F00BE00,32'hBE000000},8'h00);
  rx({32'h00000000,32'h00000000},8'h00);

  rx(cmd(4'h2,12'h048,16'd4,32'h0),8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h4,12'h048,16'd4,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;

  wait_and_capture(MAX_CYCLES);

  $display("TX words: %0d", tx_cnt);
  checkN(tx_cnt,4,"ANN TX count");
  check64(tx_data[0],64'h3DE03DE0_3DE03DE0,"ANN bank0 Y=[0.109,0.109,0.109,0.109]");
  check64(tx_data[1],64'h3E083E08_3E083E08,"ANN bank1 Y=[0.133,0.133,0.133,0.133]");
  check64(tx_data[2],64'h3E603E60_3E603E60,"ANN bank2 Y=[0.219,0.219,0.219,0.219]");
  check64(tx_data[3],64'h3DB03DB0_3DB03DB0,"ANN bank3 Y=[0.086,0.086,0.086,0.086]");

  $display("================================================================");
  if(fail_cnt==0) $display("  *** ALL %0d CHECKS PASSED ***",pass_cnt);
  else $display("  *** %0d PASSED, %0d FAILED ***",pass_cnt,fail_cnt);
  $display("================================================================");
  #(CLK_PERIOD*5); $finish;
end
endmodule
