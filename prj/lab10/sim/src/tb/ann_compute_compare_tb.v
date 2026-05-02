// Pure compute comparison: GPU (WMMA) vs CPU (shift-add)
// GPU IMEM/DMEM pre-loaded via testbench — NO DMA
// Sweeps 2, 4, 8, 16 layers to show scaling

`timescale 1ns / 1ps
`include "soc.v"

module ann_compute_compare_tb;

localparam CLK_PERIOD = 10;
localparam MAX_CYCLES = 80000;
localparam [31:0] NOP  = 32'hE1A00000;
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

// Total cycle counter
reg counting; reg [3:0] ignore_done; integer hw_count;
always @(posedge clk) begin
    if (!rst_n) begin counting<=0; hw_count<=0; ignore_done<=0; end
    else if (u_soc.pp_cpu_start) begin counting<=1; hw_count<=0; ignore_done<=10; end
    else if (ignore_done > 0) begin ignore_done<=ignore_done-1; hw_count<=hw_count+1; end
    else if (u_soc.cpu_done_w && counting) begin counting<=0; end
    else if (counting) hw_count<=hw_count+1;
end

// GPU compute counter
reg gpu_computing; integer gpu_compute_count;
always @(posedge clk) begin
    if (!rst_n) begin gpu_computing<=0; gpu_compute_count<=0; end
    else if (u_soc.gpu_kernel_start_w) begin gpu_computing<=1; gpu_compute_count<=0; end
    else if (u_soc.gpu_kernel_done_w && gpu_computing) begin gpu_computing<=0; end
    else if (gpu_computing) gpu_compute_count<=gpu_compute_count+1;
end

task wait_and_measure;
  input integer mx; output integer cycles; integer c;
begin
  tx_cnt=0; c=0;
  while(!u_soc.pp_active && c<mx) begin tick; c=c+1; end
  while(u_soc.pp_active && c<mx) begin
    if(out_wr&&out_rdy) begin tx_data[tx_cnt]=out_data; tx_cnt=tx_cnt+1; end
    tick; c=c+1;
  end
  if(c>=mx) $display("  [TIMEOUT]");
  repeat(5) tick; cycles = hw_count;
end endtask

// ================================================================
// CPU instruction builder
// ================================================================
reg [31:0] ci [0:1023];
integer ci_cnt;
task ci_emit; input [31:0] instr; begin ci[ci_cnt]=instr; ci_cnt=ci_cnt+1; end endtask

task ci_element;
  input [11:0] src, bias, dst;
  input do_relu;
begin
  ci_emit({20'hE5901, src});
  ci_emit(32'hE0813001);                // R3 = 2*src[0]
  ci_emit({20'hE5901, src+12'h4});
  ci_emit(32'hE0812081);                // R2 = 3*src[1]
  ci_emit(32'hE0833002);                // R3 += R2
  ci_emit({20'hE5901, src+12'h8});
  ci_emit(32'hE0433001);                // R3 -= src[2]
  ci_emit({20'hE5901, src+12'hC});
  ci_emit(32'hE0812101);                // R2 = 5*src[3]
  ci_emit(32'hE0833002);                // R3 += R2
  ci_emit({20'hE5901, bias});
  ci_emit(32'hE0833001);                // R3 += bias
  if (do_relu) begin
    ci_emit(32'hE3530000);
    ci_emit(32'hB3A03000);
  end
  ci_emit({20'hE5803, dst});
end endtask

task ci_layer;
  input [11:0] src, bias_base, dst_base;
  input do_relu;
begin
  ci_element(src, bias_base,       dst_base,       do_relu);
  ci_element(src, bias_base+12'h4, dst_base+12'h4, do_relu);
  ci_element(src, bias_base+12'h8, dst_base+12'h8, do_relu);
  ci_element(src, bias_base+12'hC, dst_base+12'hC, do_relu);
end endtask

// ================================================================
// GPU kernel base: 2-layer pattern (23 instrs, no RET)
// ================================================================
reg [31:0] gk_base [0:22];
reg [31:0] gk [0:255]; // big enough for 16L
integer gk_cnt;

// DMEM bank loader
task load_bank;
  input [1:0] bank;
  input [9:0] addr;
  input [15:0] val;
begin
  case (bank)
    0: u_soc.GPU_DMEM_BANK[0].u_gpu_dmem.mem[addr] = val;
    1: u_soc.GPU_DMEM_BANK[1].u_gpu_dmem.mem[addr] = val;
    2: u_soc.GPU_DMEM_BANK[2].u_gpu_dmem.mem[addr] = val;
    3: u_soc.GPU_DMEM_BANK[3].u_gpu_dmem.mem[addr] = val;
  endcase
end endtask

task preload_gpu_dmem;
  integer b, a;
begin
  for (b=0; b<4; b=b+1)
    for (a=0; a<4; a=a+1) begin
      load_bank(b[1:0], a[9:0],    16'h3F80); // W1 = 1.0
      load_bank(b[1:0], a[9:0]+4,  16'h3F80); // X  = 1.0
      load_bank(b[1:0], a[9:0]+8,  16'h0000); // B1 = 0
      load_bank(b[1:0], a[9:0]+12, 16'h3F80); // W2 = 1.0
      load_bank(b[1:0], a[9:0]+16, 16'h0000); // B2 = 0
    end
end endtask

task build_gpu_kernel;
  input integer n_iter;  // number of 2-layer iterations
  integer it, j;
begin
  gk_cnt = 0;
  for (it = 0; it < n_iter; it = it + 1)
    for (j = 0; j < 23; j = j + 1) begin
      gk[gk_cnt] = gk_base[j];
      gk_cnt = gk_cnt + 1;
    end
  gk[gk_cnt] = 32'hC8000000; gk_cnt = gk_cnt + 1; // RET
  if (gk_cnt[0]) begin gk[gk_cnt] = 32'h0; gk_cnt = gk_cnt + 1; end // pad to even
  for (j = 0; j < gk_cnt; j = j + 1)
    u_soc.u_gpu_imem.mem[j] = gk[j];
end endtask

// GPU launch via minimal CPU firmware
task run_gpu_test;
  input integer nop_pairs;
  output integer comp_cycles;
  integer n_dw, j, dummy;
begin
  n_dw = 3 + nop_pairs + 1;
  rx(cmd(4'h1, 12'h000, n_dw[15:0], 32'h0), 8'h04);
  rx({32'hEE040A10, 32'hE3A00000}, 8'h00);
  rx({32'hEE071A10, 32'hE3A0100F}, 8'h00);
  rx({32'hEE052A10, 32'hE3A02001}, 8'h00);
  for (j=0; j<nop_pairs; j=j+1) rx({NOP, NOP}, 8'h00);
  rx({NOP, HALT}, 8'h00);
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;
  wait_and_measure(MAX_CYCLES, dummy);
  comp_cycles = gpu_compute_count;
end endtask

// CPU test: build N-layer program, inject, measure
task run_cpu_test;
  input integer n_layers;
  output integer cpu_cyc;
  output integer n_instrs;
  integer j, n_dw, dummy;
  // DMEM layout: x=0x000, b=0x010, then hidden layers at 0x020, 0x030, ...
  // Final output at 0x010 + n_layers * 0x010
  reg [11:0] src_addr, dst_addr;
begin
  ci_cnt = 0;
  ci_emit(32'hE3A00000); // MOV R0, #0
  src_addr = 12'h000; // start from x
  for (j = 0; j < n_layers; j = j + 1) begin
    dst_addr = 12'h020 + j[11:0] * 12'h010;
    if (j < n_layers - 1)
      ci_layer(src_addr, 12'h010, dst_addr, 1);  // hidden: with ReLU
    else
      ci_layer(src_addr, 12'h010, dst_addr, 0);  // output: no ReLU
    src_addr = dst_addr;
  end
  ci_emit(32'hEAFFFFFE); // HALT
  n_instrs = ci_cnt;

  n_dw = (ci_cnt + 1) / 2;
  rx(cmd(4'h1, 12'h000, n_dw[15:0], 32'h0), 8'h04);
  for (j=0; j<ci_cnt; j=j+2)
    if (j+1<ci_cnt) rx({ci[j+1],ci[j]},8'h00);
    else rx({32'h0,ci[j]},8'h00);
  // Data: x=[1,2,3,4], b=[0,-10,-25,-30]
  rx(cmd(4'h2, 12'h000, 16'd4, 32'h0), 8'h00);
  rx({32'h00000002, 32'h00000001}, 8'h00);
  rx({32'h00000004, 32'h00000003}, 8'h00);
  rx({32'hFFFFFFF6, 32'h00000000}, 8'h00);
  rx({32'hFFFFFFE2, 32'hFFFFFFE7}, 8'h00);
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;
  wait_and_measure(MAX_CYCLES, cpu_cyc);
end endtask

// ================================================================
// Results storage
// ================================================================
integer gpu_res [0:3];  // GPU compute cycles for 2,4,8,16 layers
integer cpu_res [0:3];  // CPU cycles
integer cpu_inst [0:3]; // CPU instruction counts
integer idx;
integer pass_cnt, fail_cnt;

task check; input [80*8-1:0] nm; input integer got, exp;
begin
  if(got===exp) begin $display("  [PASS] %0s = %0d",nm,got); pass_cnt=pass_cnt+1; end
  else begin $display("  [FAIL] %0s = %0d (exp %0d)",nm,got,exp); fail_cnt=fail_cnt+1; end
end endtask

initial begin
  rst_n=0; in_wr=0; in_data=0; in_ctrl=0; out_rdy=1;

  // Build base 2-layer kernel pattern (23 instrs, no RET)
  // Layer 1: load X,W1,B1 → MMA → ReLU → store H
  gk_base[0] =32'h20000004; gk_base[1] =32'hF4400000;
  gk_base[2] =32'h20000000; gk_base[3] =32'hF4800000;
  gk_base[4] =32'h20000008; gk_base[5] =32'hF4C00000;
  gk_base[6] =32'hECC48C00; gk_base[7] =32'h20000000;
  gk_base[8] =32'h54CC0000; gk_base[9] =32'h54DD0000;
  gk_base[10]=32'h54EE0000; gk_base[11]=32'h54FF0000;
  gk_base[12]=32'h20000014; gk_base[13]=32'hFCC00000;
  // Layer 2: load W2,H,B2 → MMA → store Y
  gk_base[14]=32'h2000000C; gk_base[15]=32'hF4400000;
  gk_base[16]=32'h20000014; gk_base[17]=32'hF4800000;
  gk_base[18]=32'h20000010; gk_base[19]=32'hF4C00000;
  gk_base[20]=32'hECC48C00;
  gk_base[21]=32'h20000018; gk_base[22]=32'hFCC00000;

  pass_cnt=0; fail_cnt=0;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  $display("");
  $display("================================================================");
  $display("  GPU vs CPU Compute Scaling (no DMA, pre-loaded)");
  $display("  GPU: WMMA.MMA tensor core (BF16)");
  $display("  CPU: shift-add multiply (int32, w=[2,3,-1,5])");
  $display("================================================================");

  // ============================================================
  // GPU tests: 2, 4, 8, 16 layers
  // ============================================================
  // 2-layer (1 iteration)
  $display(""); $display("--- GPU 2-layer ---");
  preload_gpu_dmem;
  build_gpu_kernel(1);
  run_gpu_test(30, gpu_res[0]);
  $display("  GPU 2L compute: %0d cycles (%0d kernel instrs)", gpu_res[0], gk_cnt);

  // 4-layer (2 iterations)
  repeat(100) tick;
  $display("--- GPU 4-layer ---");
  preload_gpu_dmem;
  build_gpu_kernel(2);
  run_gpu_test(60, gpu_res[1]);
  $display("  GPU 4L compute: %0d cycles (%0d kernel instrs)", gpu_res[1], gk_cnt);

  // 8-layer (4 iterations)
  repeat(100) tick;
  $display("--- GPU 8-layer ---");
  preload_gpu_dmem;
  build_gpu_kernel(4);
  run_gpu_test(120, gpu_res[2]);
  $display("  GPU 8L compute: %0d cycles (%0d kernel instrs)", gpu_res[2], gk_cnt);

  // 16-layer (8 iterations)
  repeat(100) tick;
  $display("--- GPU 16-layer ---");
  preload_gpu_dmem;
  build_gpu_kernel(8);
  run_gpu_test(240, gpu_res[3]);
  $display("  GPU 16L compute: %0d cycles (%0d kernel instrs)", gpu_res[3], gk_cnt);

  // ============================================================
  // CPU tests: 2, 4, 8, 16 layers
  // ============================================================
  repeat(100) tick;
  $display(""); $display("--- CPU 2-layer ---");
  run_cpu_test(2, cpu_res[0], cpu_inst[0]);
  $display("  CPU 2L: %0d cycles (%0d instrs)", cpu_res[0], cpu_inst[0]);
  // 2L output at word 12 (byte 0x030): y=[95,85,70,65]
  check("CPU 2L y[0]", $signed(u_soc.u_cpu_dmem.mem[12]), 95);
  check("CPU 2L y[1]", $signed(u_soc.u_cpu_dmem.mem[13]), 85);

  repeat(100) tick;
  $display("--- CPU 4-layer ---");
  run_cpu_test(4, cpu_res[1], cpu_inst[1]);
  $display("  CPU 4L: %0d cycles (%0d instrs)", cpu_res[1], cpu_inst[1]);
  // 4L output at word 20 (byte 0x050): y=[6145,6135,6120,6115]
  check("CPU 4L y[0]", $signed(u_soc.u_cpu_dmem.mem[20]), 6145);
  check("CPU 4L y[1]", $signed(u_soc.u_cpu_dmem.mem[21]), 6135);

  repeat(100) tick;
  $display("--- CPU 8-layer ---");
  run_cpu_test(8, cpu_res[2], cpu_inst[2]);
  $display("  CPU 8L: %0d cycles (%0d instrs)", cpu_res[2], cpu_inst[2]);

  repeat(100) tick;
  $display("--- CPU 16-layer ---");
  run_cpu_test(16, cpu_res[3], cpu_inst[3]);
  $display("  CPU 16L: %0d cycles (%0d instrs)", cpu_res[3], cpu_inst[3]);

  // ============================================================
  // Summary
  // ============================================================
  $display("");
  $display("================================================================");
  $display("  PURE COMPUTE COMPARISON (no DMA)");
  $display("----------------------------------------------------------------");
  $display("  Layers  GPU_cyc  CPU_cyc  CPU_instrs  Speedup");
  for (idx=0; idx<4; idx=idx+1) begin
    $display("  %3d     %5d    %5d    %4d        %0d.%01dx",
      (2 << idx),
      gpu_res[idx], cpu_res[idx], cpu_inst[idx],
      cpu_res[idx]/gpu_res[idx], (cpu_res[idx]*10/gpu_res[idx])%10);
  end
  $display("----------------------------------------------------------------");
  $display("  GPU per-layer:  ~%0d cycles", gpu_res[0]/2);
  $display("  CPU per-layer:  ~%0d cycles", cpu_res[0]/2);
  $display("  %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
  $display("================================================================");
  #(CLK_PERIOD*5); $finish;
end
endmodule
