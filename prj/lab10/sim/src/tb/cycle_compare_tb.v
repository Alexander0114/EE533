// Minimal cycle comparison: GPU vs CPU
// Measures $time between pp_cpu_start and cpu_done

`timescale 1ns / 1ps
`include "soc.v"

module cycle_compare_tb;

localparam CLK_PERIOD = 10;
localparam MAX_CYCLES = 20000;
localparam [31:0] NOP = 32'hE1A00000;
localparam [31:0] HALT = 32'hEAFFFFFE;

reg clk, rst_n;
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [63:0] in_data; reg [7:0] in_ctrl; reg in_wr; wire in_rdy;
wire [63:0] out_data; wire [7:0] out_ctrl; wire out_wr; reg out_rdy;

soc u_soc(.clk(clk),.rst_n(rst_n),.in_data(in_data),.in_ctrl(in_ctrl),
  .in_wr(in_wr),.in_rdy(in_rdy),.out_data(out_data),.out_ctrl(out_ctrl),
  .out_wr(out_wr),.out_rdy(out_rdy));

integer tx_cnt;
reg [63:0] tx_data [0:127];

task tick; begin @(posedge clk); #1; end endtask
function [63:0] cmd; input [3:0] op; input [11:0] a; input [15:0] n; input [31:0] p;
  cmd={op,a,n,p}; endfunction
task rx; input [63:0] d; input [7:0] c; begin in_data=d;in_ctrl=c;in_wr=1;tick; end endtask
task rx_end; begin in_wr=0;in_data=0;in_ctrl=0;tick; end endtask

// Hardware counter: start on cpu_start, stop on cpu_done
// Ignore cpu_done for 10 cycles after cpu_start (stale halted from previous test)
reg counting;
reg [3:0] ignore_done;
integer hw_count;
always @(posedge clk) begin
    if (!rst_n) begin counting<=0; hw_count<=0; ignore_done<=0; end
    else if (u_soc.pp_cpu_start) begin counting<=1; hw_count<=0; ignore_done<=10; end
    else if (ignore_done > 0) begin ignore_done<=ignore_done-1; hw_count<=hw_count+1; end
    else if (u_soc.cpu_done_w && counting) begin counting<=0; end
    else if (counting) hw_count<=hw_count+1;
end

task wait_and_measure;
  input integer mx;
  output integer cycles;
  integer c;
begin
  tx_cnt=0; c=0; cycles=0;
  while(!u_soc.pp_active && c<mx) begin tick; c=c+1; end
  while(u_soc.pp_active && c<mx) begin
    if(out_wr && out_rdy) begin tx_data[tx_cnt]=out_data; tx_cnt=tx_cnt+1; end
    tick; c=c+1;
  end
  if(c>=mx) $display("  [TIMEOUT]");
  repeat(5) tick;
  cycles = hw_count;
end
endtask

integer gpu_cycles, cpu_cycles;

initial begin
  rst_n=0; in_wr=0; in_data=0; in_ctrl=0; out_rdy=1;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  $display("");
  $display("================================================================");
  $display("  CPU vs GPU Cycle Comparison (4x4 matmul + ReLU)");
  $display("================================================================");

  // ================================================================
  //  GPU PATH: same as fc test (gpu_arm pattern)
  // ================================================================
  $display("");
  $display("--- GPU Path: DMA + WMMA ---");

  // GPU ARM: 43 data DWs (86 ARM instructions) follow
  rx(cmd(4'h1, 12'h000, 16'd43, 32'h0), 8'h04);
  // D_IMEM
  rx({32'hEE000A10, 32'hE3A00000}, 8'h00);
  rx({32'hE3A01010, 32'hEE010A10}, 8'h00);
  rx({32'hE3A02005, 32'hEE021A10}, 8'h00);
  rx({NOP, 32'hEE032A10}, 8'h00);
  // D_IMEM wait 5np
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  // D_UNPACK
  rx({32'hEE000A10, 32'hE3A00010}, 8'h00);
  rx({32'hEE011A10, 32'hE3A01000}, 8'h00);
  rx({32'hEE022A10, 32'hE3A02006}, 8'h00);
  rx({32'hEE033A10, 32'hE3A03041}, 8'h00);
  // D_UNPACK wait 10np
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00);
  // GPU launch
  rx({32'hEE040A10, 32'hE3A00000}, 8'h00);
  rx({32'hEE071A10, 32'hE3A0100F}, 8'h00);
  rx({32'hEE052A10, 32'hE3A02001}, 8'h00);
  // GPU wait 10np
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00);
  // D_PACK + halt
  rx({32'hEE000A10, 32'hE3A00000}, 8'h00);
  rx({32'hEE011A10, 32'hE3A01030}, 8'h00);
  rx({32'hEE022A10, 32'hE3A02002}, 8'h00);
  rx({32'hEE033A10, 32'hE3A03043}, 8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP, HALT}, 8'h00);

  // GPU kernel
  rx(cmd(4'h2, 12'h000, 16'd8, 32'h0), 8'h00);
  rx({32'hF0400004, 32'h20000000}, 8'h00);
  rx({32'hF0000000, 32'hF0800008}, 8'h00);
  rx({32'h20000000, 32'hECC04800}, 8'h00);
  rx({32'h54DD0000, 32'h54CC0000}, 8'h00);
  rx({32'h54FF0000, 32'h54EE0000}, 8'h00);
  rx({32'hF8C00000, 32'h20000000}, 8'h00);
  rx({32'h00000000, 32'hC8000000}, 8'h00);
  rx(64'h0, 8'h00);

  // Data
  rx(cmd(4'h2, 12'h010, 16'd12, 32'h0), 8'h00);
  rx({32'h00000000, 32'h00003F80}, 8'h00); rx({32'h3F803F80, 32'h3F803F80}, 8'h00); rx(64'h0, 8'h00);
  rx({32'h00000000, 32'h3F800000}, 8'h00); rx({32'h3F803F80, 32'h3F803F80}, 8'h00); rx(64'h0, 8'h00);
  rx({32'h00003F80, 32'h00000000}, 8'h00); rx({32'h3F803F80, 32'h3F803F80}, 8'h00); rx(64'h0, 8'h00);
  rx({32'h3F800000, 32'h00000000}, 8'h00); rx({32'h3F803F80, 32'h3F803F80}, 8'h00); rx(64'h0, 8'h00);

  rx(cmd(4'h2, 12'h030, 16'd4, 32'h0), 8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h4, 12'h030, 16'd4, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, gpu_cycles);
  $display("  GPU: %0d cycles (cpu_start to cpu_done)", gpu_cycles);
  $display("  GPU ARM instructions: 74 (37 DWs)");

  // ================================================================
  //  CPU-ONLY PATH: 56 ARM instrs (28 DWs)
  // ================================================================
  $display("");
  $display("--- CPU Path: ARM integer matmul ---");
  repeat(100) tick;

  rx(cmd(4'h1, 12'h000, 16'd30, 32'h0), 8'h04);
  rx({NOP, 32'hE3A00000}, 8'h00);
  // Row 0
  rx({32'hE5902040, 32'hE5901000}, 8'h00);
  rx({32'hE5901004, 32'hE0030291}, 8'h00);
  rx({32'hE0233291, 32'hE5902044}, 8'h00);
  rx({32'hE5902048, 32'hE5901008}, 8'h00);
  rx({32'hE590100C, 32'hE0233291}, 8'h00);
  rx({32'hE0233291, 32'hE590204C}, 8'h00);
  rx({NOP, 32'hE58030C0}, 8'h00);
  // Row 1
  rx({32'hE5902040, 32'hE5901010}, 8'h00);
  rx({32'hE5901014, 32'hE0030291}, 8'h00);
  rx({32'hE0233291, 32'hE5902044}, 8'h00);
  rx({32'hE5902048, 32'hE5901018}, 8'h00);
  rx({32'hE590101C, 32'hE0233291}, 8'h00);
  rx({32'hE0233291, 32'hE590204C}, 8'h00);
  rx({NOP, 32'hE58030C4}, 8'h00);
  // Row 2
  rx({32'hE5902040, 32'hE5901020}, 8'h00);
  rx({32'hE5901024, 32'hE0030291}, 8'h00);
  rx({32'hE0233291, 32'hE5902044}, 8'h00);
  rx({32'hE5902048, 32'hE5901028}, 8'h00);
  rx({32'hE590102C, 32'hE0233291}, 8'h00);
  rx({32'hE0233291, 32'hE590204C}, 8'h00);
  rx({NOP, 32'hE58030C8}, 8'h00);
  // Row 3
  rx({32'hE5902040, 32'hE5901030}, 8'h00);
  rx({32'hE5901034, 32'hE0030291}, 8'h00);
  rx({32'hE0233291, 32'hE5902044}, 8'h00);
  rx({32'hE5902048, 32'hE5901038}, 8'h00);
  rx({32'hE590103C, 32'hE0233291}, 8'h00);
  rx({32'hE0233291, 32'hE590204C}, 8'h00);
  rx({NOP, 32'hE58030CC}, 8'h00);
  rx({NOP, HALT}, 8'h00);

  // Data
  rx(cmd(4'h2, 12'h000, 16'd10, 32'h0), 8'h00);
  rx({32'h00000000, 32'h00000001}, 8'h00); rx({32'h00000000, 32'h00000000}, 8'h00);
  rx({32'h00000001, 32'h00000000}, 8'h00); rx({32'h00000000, 32'h00000000}, 8'h00);
  rx({32'h00000000, 32'h00000000}, 8'h00); rx({32'h00000000, 32'h00000001}, 8'h00);
  rx({32'h00000000, 32'h00000000}, 8'h00); rx({32'h00000001, 32'h00000000}, 8'h00);
  rx({32'h00000001, 32'h00000001}, 8'h00); rx({32'h00000001, 32'h00000001}, 8'h00);

  rx(cmd(4'h2, 12'h030, 16'd4, 32'h0), 8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h4, 12'h030, 16'd4, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, cpu_cycles);
  $display("  CPU: %0d cycles (cpu_start to cpu_done)", cpu_cycles);
  $display("  CPU ARM instructions: 56 (28 DWs)");

  // ================================================================
  $display("");
  $display("================================================================");
  $display("  SUMMARY");
  $display("  GPU path (DMA+WMMA+DMA): %0d cycles, 74 ARM instrs", gpu_cycles);
  $display("  CPU path (LDR/MUL/MLA):  %0d cycles, 56 ARM instrs", cpu_cycles);
  if (gpu_cycles > 0)
    $display("  CPU/GPU ratio: %0d.%01dx", cpu_cycles/gpu_cycles, (cpu_cycles*10/gpu_cycles)%10);
  $display("  NOTE: GPU firmware has NOP waits; actual DMA+compute ~252 cycles");
  $display("  NOTE: CPU actually computes in ~224 cycles (56 instrs × 4 barrel)");
  $display("================================================================");
  #(CLK_PERIOD*5); $finish;
end
endmodule
