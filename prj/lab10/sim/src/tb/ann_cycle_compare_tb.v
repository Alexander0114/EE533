// 2-layer ANN cycle comparison: GPU vs CPU-only
// GPU:  DMA + WMMA tensor core (BF16, 4x4 matmul per layer)
// CPU:  ARM integer LDR/ADD/CMP/STR only (NO MUL — removed from this CPU)
// Both compute Y = W2 * ReLU(W1 * X + B1) + B2

`timescale 1ns / 1ps
`include "soc.v"

module ann_cycle_compare_tb;

localparam CLK_PERIOD = 10;
localparam MAX_CYCLES = 20000;
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

// Hardware cycle counter: start on cpu_start, stop on cpu_done (total)
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

// GPU compute-only counter: kernel_start to kernel_done
reg gpu_computing;
integer gpu_compute_count;
always @(posedge clk) begin
    if (!rst_n) begin gpu_computing<=0; gpu_compute_count<=0; end
    else if (u_soc.gpu_kernel_start_w) begin gpu_computing<=1; gpu_compute_count<=0; end
    else if (u_soc.gpu_kernel_done_w && gpu_computing) begin gpu_computing<=0; end
    else if (gpu_computing) gpu_compute_count<=gpu_compute_count+1;
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

integer gpu_cycles, cpu_cycles, gpu_only_cycles;
integer pass_cnt, fail_cnt;

task check64; input [63:0] v,e; input [80*8-1:0] nm;
begin
  if(v===e) begin $display("  [PASS] %0s = 0x%016h",nm,v); pass_cnt=pass_cnt+1; end
  else begin $display("  [FAIL] %0s = 0x%016h exp 0x%016h",nm,v,e); fail_cnt=fail_cnt+1; end
end endtask

initial begin
  rst_n=0; in_wr=0; in_data=0; in_ctrl=0; out_rdy=1;
  pass_cnt=0; fail_cnt=0;
  repeat(10) tick; rst_n=1; repeat(5) tick;

  $display("");
  $display("================================================================");
  $display("  2-Layer ANN Cycle Comparison: GPU vs CPU");
  $display("  Y = W2 * ReLU(W1 * X + B1) + B2");
  $display("================================================================");

  // ================================================================
  //  GPU PATH: 2-layer ANN via WMMA (from ann_inference_tb.v)
  //  152 ARM instrs (76 DWs) + 24 GPU instrs + matrix data
  //  Power quality anomaly detection weights (BF16)
  // ================================================================
  $display("");
  $display("--- GPU Path: DMA + WMMA (2 layers, BF16) ---");

  // LOAD_IMEM: 76 DWs (152 ARM instructions)
  rx(cmd(4'h1,12'h000,16'd76,32'h0),8'h04);
  // D_IMEM setup
  rx({32'hEE000A10,32'hE3A00000},8'h00);
  rx({32'hE3A01020,32'hEE010A10},8'h00);
  rx({32'hE3A02005,32'hEE021A10},8'h00);
  rx({NOP,32'hEE032A10},8'h00);
  // D_IMEM wait 5 NOP pairs
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  // D_UNPACK setup
  rx({32'hEE000A10,32'hE3A00020},8'h00);
  rx({32'hEE011A10,32'hE3A01000},8'h00);
  rx({32'hEE022A10,32'hE3A0200A},8'h00);
  rx({32'hEE033A10,32'hE3A03041},8'h00);
  // D_UNPACK wait 20 NOP pairs
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  // GPU launch
  rx({32'hEE040A10,32'hE3A00000},8'h00);
  rx({32'hEE071A10,32'hE3A0100F},8'h00);
  rx({32'hEE052A10,32'hE3A02001},8'h00);
  // GPU wait 30 NOP pairs
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
  // D_PACK + halt
  rx({32'hEE000A10,32'hE3A00018},8'h00);
  rx({32'hEE011A10,32'hE3A01048},8'h00);
  rx({32'hEE022A10,32'hE3A02002},8'h00);
  rx({32'hEE033A10,32'hE3A03043},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,HALT},8'h00);

  // GPU kernel (16 DWs)
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
  rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00);

  // Matrix data (20 DWs at addr 0x020)
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

  // Zero readback area
  rx(cmd(4'h2,12'h048,16'd4,32'h0),8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h4,12'h048,16'd4,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, gpu_cycles);
  gpu_only_cycles = gpu_compute_count;
  $display("  GPU total:   %0d cycles (cpu_start to cpu_done)", gpu_cycles);
  $display("  GPU compute: %0d cycles (kernel_start to kernel_done)", gpu_only_cycles);
  $display("  GPU DMA overhead: %0d cycles", gpu_cycles - gpu_only_cycles);
  check64(tx_data[0],64'h3DE03DE0_3DE03DE0,"GPU bank0 [0.109x4]");
  check64(tx_data[1],64'h3E083E08_3E083E08,"GPU bank1 [0.133x4]");
  check64(tx_data[2],64'h3E603E60_3E603E60,"GPU bank2 [0.219x4]");
  check64(tx_data[3],64'h3DB03DB0_3DB03DB0,"GPU bank3 [0.086x4]");

  // ================================================================
  //  CPU-ONLY PATH: ARM integer 2-layer ANN
  //  NOTE: This CPU has NO MUL/MLA (mac removed in cu.v v1.3)
  //  Uses binary weights {0,1} with hardcoded LDR+ADD patterns
  //  62 ARM instructions (31 DWs), no GPU, no DMA
  //
  //  W1 = [[1,1,1,1],[1,1,0,0],[0,0,1,1],[1,0,1,0]]  (binary)
  //  x  = [3, -2, 5, -1]
  //  b1 = [0, -3, 0, 1]
  //  h_raw = [5, -2, 4, 9]  h = ReLU = [5, 0, 4, 9]
  //
  //  W2 = [[0,1,1,0],[1,0,0,1],[1,1,0,0],[0,0,1,1]]  (binary)
  //  b2 = [1, -5, 0, -3]
  //  y  = [5, 9, 5, 10]
  //
  //  DMEM layout (word/byte addr):
  //    x:  0-3  / 0x000-0x00C
  //    b1: 4-7  / 0x010-0x01C
  //    b2: 8-11 / 0x020-0x02C
  //    h:  12-15/ 0x030-0x03C  (written by CPU)
  //    y:  16-19/ 0x040-0x04C  (readback)
  // ================================================================
  $display("");
  $display("--- CPU Path: ARM integer (2 layers, ADD only) ---");
  repeat(100) tick;

  // LOAD_IMEM: 31 DWs (62 ARM instructions)
  rx(cmd(4'h1, 12'h000, 16'd31, 32'h0), 8'h04);

  // Instr 0: MOV R0, #0
  // --- h[0] = x[0]+x[1]+x[2]+x[3]+b1[0] = 3-2+5-1+0 = 5 ---
  rx({32'hE5903000, 32'hE3A00000}, 8'h00);  // DW0:  MOV R0,#0; LDR R3,[R0,#0]
  rx({32'hE0833001, 32'hE5901004}, 8'h00);  // DW1:  LDR R1,[R0,#4]; ADD R3,R3,R1
  rx({32'hE0833001, 32'hE5901008}, 8'h00);  // DW2:  LDR R1,[R0,#8]; ADD
  rx({32'hE0833001, 32'hE590100C}, 8'h00);  // DW3:  LDR R1,[R0,#C]; ADD
  rx({32'hE0833001, 32'hE5901010}, 8'h00);  // DW4:  LDR R1,[R0,#10]; ADD (b1[0])
  rx({32'hB3A03000, 32'hE3530000}, 8'h00);  // DW5:  CMP R3,#0; MOVLT R3,#0
  // --- h[1] = x[0]+x[1]+b1[1] = 3-2-3 = -2 -> ReLU=0 ---
  rx({32'hE5903000, 32'hE5803030}, 8'h00);  // DW6:  STR R3,[R0,#30]; LDR R3,[R0,#0]
  rx({32'hE0833001, 32'hE5901004}, 8'h00);  // DW7:  LDR R1,[R0,#4]; ADD
  rx({32'hE0833001, 32'hE5901014}, 8'h00);  // DW8:  LDR R1,[R0,#14]; ADD (b1[1])
  rx({32'hB3A03000, 32'hE3530000}, 8'h00);  // DW9:  CMP; MOVLT
  // --- h[2] = x[2]+x[3]+b1[2] = 5-1+0 = 4 ---
  rx({32'hE5903008, 32'hE5803034}, 8'h00);  // DW10: STR R3,[R0,#34]; LDR R3,[R0,#8]
  rx({32'hE0833001, 32'hE590100C}, 8'h00);  // DW11: LDR R1,[R0,#C]; ADD
  rx({32'hE0833001, 32'hE5901018}, 8'h00);  // DW12: LDR R1,[R0,#18]; ADD (b1[2])
  rx({32'hB3A03000, 32'hE3530000}, 8'h00);  // DW13: CMP; MOVLT
  // --- h[3] = x[0]+x[2]+b1[3] = 3+5+1 = 9 ---
  rx({32'hE5903000, 32'hE5803038}, 8'h00);  // DW14: STR R3,[R0,#38]; LDR R3,[R0,#0]
  rx({32'hE0833001, 32'hE5901008}, 8'h00);  // DW15: LDR R1,[R0,#8]; ADD
  rx({32'hE0833001, 32'hE590101C}, 8'h00);  // DW16: LDR R1,[R0,#1C]; ADD (b1[3])
  rx({32'hB3A03000, 32'hE3530000}, 8'h00);  // DW17: CMP; MOVLT
  // --- y[0] = h[1]+h[2]+b2[0] = 0+4+1 = 5 ---
  rx({32'hE5903034, 32'hE580303C}, 8'h00);  // DW18: STR R3,[R0,#3C]; LDR R3,[R0,#34]
  rx({32'hE0833001, 32'hE5901038}, 8'h00);  // DW19: LDR R1,[R0,#38]; ADD
  rx({32'hE0833001, 32'hE5901020}, 8'h00);  // DW20: LDR R1,[R0,#20]; ADD (b2[0])
  // --- y[1] = h[0]+h[3]+b2[1] = 5+9-5 = 9 ---
  rx({32'hE5903030, 32'hE5803040}, 8'h00);  // DW21: STR R3,[R0,#40]; LDR R3,[R0,#30]
  rx({32'hE0833001, 32'hE590103C}, 8'h00);  // DW22: LDR R1,[R0,#3C]; ADD
  rx({32'hE0833001, 32'hE5901024}, 8'h00);  // DW23: LDR R1,[R0,#24]; ADD (b2[1])
  // --- y[2] = h[0]+h[1]+b2[2] = 5+0+0 = 5 ---
  rx({32'hE5903030, 32'hE5803044}, 8'h00);  // DW24: STR R3,[R0,#44]; LDR R3,[R0,#30]
  rx({32'hE0833001, 32'hE5901034}, 8'h00);  // DW25: LDR R1,[R0,#34]; ADD
  rx({32'hE0833001, 32'hE5901028}, 8'h00);  // DW26: LDR R1,[R0,#28]; ADD (b2[2])
  // --- y[3] = h[2]+h[3]+b2[3] = 4+9-3 = 10 ---
  rx({32'hE5903038, 32'hE5803048}, 8'h00);  // DW27: STR R3,[R0,#48]; LDR R3,[R0,#38]
  rx({32'hE0833001, 32'hE590103C}, 8'h00);  // DW28: LDR R1,[R0,#3C]; ADD
  rx({32'hE0833001, 32'hE590102C}, 8'h00);  // DW29: LDR R1,[R0,#2C]; ADD (b2[3])
  rx({32'hEAFFFFFE, 32'hE580304C}, 8'h00);  // DW30: STR R3,[R0,#4C]; HALT

  // LOAD_DMEM: 6 DWs (12 words) at addr 0
  // x=[3,-2,5,-1], b1=[0,-3,0,1], b2=[1,-5,0,-3]
  rx(cmd(4'h2, 12'h000, 16'd6, 32'h0), 8'h00);
  rx({32'hFFFFFFFE, 32'h00000003}, 8'h00);  // x[0]=3,  x[1]=-2
  rx({32'hFFFFFFFF, 32'h00000005}, 8'h00);  // x[2]=5,  x[3]=-1
  rx({32'hFFFFFFFD, 32'h00000000}, 8'h00);  // b1[0]=0, b1[1]=-3
  rx({32'h00000001, 32'h00000000}, 8'h00);  // b1[2]=0, b1[3]=1
  rx({32'hFFFFFFFB, 32'h00000001}, 8'h00);  // b2[0]=1, b2[1]=-5
  rx({32'hFFFFFFFD, 32'h00000000}, 8'h00);  // b2[2]=0, b2[3]=-3

  // Zero readback area y (2 DWs at addr 0x010 = word 16)
  rx(cmd(4'h2, 12'h010, 16'd2, 32'h0), 8'h00);
  rx(64'h0, 8'h00); rx(64'h0, 8'h00);

  // CPU_START + READBACK + SEND_PKT
  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h4, 12'h010, 16'd2, 32'h0), 8'h00);  // readback 2 DWs from word 16
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, cpu_cycles);
  $display("  CPU: %0d cycles (cpu_start to cpu_done)", cpu_cycles);
  $display("  CPU ARM instrs: 62 (31 DWs), ADD-only (no MUL)");

  // Debug
  $display("  h[0..3]: %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[12]), $signed(u_soc.u_cpu_dmem.mem[13]),
    $signed(u_soc.u_cpu_dmem.mem[14]), $signed(u_soc.u_cpu_dmem.mem[15]));
  $display("  y[0..3]: %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[16]), $signed(u_soc.u_cpu_dmem.mem[17]),
    $signed(u_soc.u_cpu_dmem.mem[18]), $signed(u_soc.u_cpu_dmem.mem[19]));

  // Verify: y = [5, 9, 5, 10]
  // tx_data[0] = {dmem[17], dmem[16]} = {y[1]=9, y[0]=5}
  // tx_data[1] = {dmem[19], dmem[18]} = {y[3]=10, y[2]=5}
  check64(tx_data[0], 64'h00000009_00000005, "CPU y[0]=5,y[1]=9");
  check64(tx_data[1], 64'h0000000A_00000005, "CPU y[2]=5,y[3]=10");

  // ================================================================
  $display("");
  $display("================================================================");
  $display("  SUMMARY: 2-Layer ANN Inference");
  $display("----------------------------------------------------------------");
  $display("  GPU total (DMA+compute):  %0d cycles", gpu_cycles);
  $display("  GPU compute only (WMMA):  %0d cycles", gpu_only_cycles);
  $display("  GPU DMA overhead:         %0d cycles (%0d%%)", gpu_cycles-gpu_only_cycles,
    (gpu_cycles-gpu_only_cycles)*100/gpu_cycles);
  $display("  CPU compute (ADD only):   %0d cycles", cpu_cycles);
  $display("----------------------------------------------------------------");
  if (cpu_cycles > 0 && gpu_only_cycles > 0) begin
    if (gpu_only_cycles > cpu_cycles)
      $display("  Compute: GPU %0d.%01dx slower than CPU", gpu_only_cycles/cpu_cycles, (gpu_only_cycles*10/cpu_cycles)%10);
    else
      $display("  Compute: CPU %0d.%01dx slower than GPU", cpu_cycles/gpu_only_cycles, (cpu_cycles*10/gpu_only_cycles)%10);
  end
  $display("  NOTE: CPU has no MUL — binary weights only (ADD/SUB)");
  $display("  NOTE: GPU does general BF16 matmul via tensor core");
  $display("  %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
  $display("================================================================");
  #(CLK_PERIOD*5); $finish;
end
endmodule
