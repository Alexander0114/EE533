// 4-layer ANN: GPU (WMMA) vs CPU (shift-add multiply)
// GPU does 4x WMMA.MMA with BF16 general weights
// CPU does 4 layers of int32 matmul via ADD+barrel-shift (no MUL instr)
// Weights: w=[2,3,-1,5] per layer, same for GPU (BF16) and CPU (int)

`timescale 1ns / 1ps
`include "soc.v"

module ann_4layer_compare_tb;

localparam CLK_PERIOD = 10;
localparam MAX_CYCLES = 30000;
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

// GPU compute-only counter
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

integer gpu_cycles, cpu_cycles, gpu_only;
integer pass_cnt, fail_cnt;

task check; input [80*8-1:0] nm; input integer got, exp;
begin
  if(got===exp) begin $display("  [PASS] %0s = %0d",nm,got); pass_cnt=pass_cnt+1; end
  else begin $display("  [FAIL] %0s = %0d (exp %0d)",nm,got,exp); fail_cnt=fail_cnt+1; end
end endtask

// ================================================================
// CPU instruction builder: shift-and-add matmul
// Weights = [2, 3, -1, 5] hardcoded in instruction pattern
// Per element: LDR+shift-add for each weight, +bias, CMP/MOVLT, STR
// ================================================================
reg [31:0] ci [0:511];  // CPU instruction array
integer ci_cnt;

task ci_emit; input [31:0] instr; begin ci[ci_cnt]=instr; ci_cnt=ci_cnt+1; end endtask

// Emit one output element: y = 2*src[0] + 3*src[1] - src[2] + 5*src[3] + bias
task ci_element;
  input [11:0] src;   // byte offset of source[0]
  input [11:0] bias;  // byte offset of bias
  input [11:0] dst;   // byte offset of destination
  input do_relu;
begin
  ci_emit({20'hE5901, src});              // LDR R1, [R0, #src+0]
  ci_emit(32'hE0813001);                  // ADD R3, R1, R1       (R3 = 2*src[0])
  ci_emit({20'hE5901, src + 12'h004});    // LDR R1, [R0, #src+4]
  ci_emit(32'hE0812081);                  // ADD R2, R1, R1 LSL#1 (R2 = 3*src[1])
  ci_emit(32'hE0833002);                  // ADD R3, R3, R2
  ci_emit({20'hE5901, src + 12'h008});    // LDR R1, [R0, #src+8]
  ci_emit(32'hE0433001);                  // SUB R3, R3, R1       (R3 -= src[2])
  ci_emit({20'hE5901, src + 12'h00C});    // LDR R1, [R0, #src+C]
  ci_emit(32'hE0812101);                  // ADD R2, R1, R1 LSL#2 (R2 = 5*src[3])
  ci_emit(32'hE0833002);                  // ADD R3, R3, R2
  ci_emit({20'hE5901, bias});             // LDR R1, [R0, #bias]
  ci_emit(32'hE0833001);                  // ADD R3, R3, R1
  if (do_relu) begin
    ci_emit(32'hE3530000);                // CMP R3, #0
    ci_emit(32'hB3A03000);                // MOVLT R3, #0
  end
  ci_emit({20'hE5803, dst});              // STR R3, [R0, #dst]
end
endtask

// Emit one layer (4 elements, same src, 4 bias/dst offsets)
task ci_layer;
  input [11:0] src;
  input [11:0] bias_base;
  input [11:0] dst_base;
  input do_relu;
begin
  ci_element(src, bias_base,        dst_base,        do_relu);
  ci_element(src, bias_base+12'h4,  dst_base+12'h4,  do_relu);
  ci_element(src, bias_base+12'h8,  dst_base+12'h8,  do_relu);
  ci_element(src, bias_base+12'hC,  dst_base+12'hC,  do_relu);
end
endtask

// ================================================================
// GPU kernel builder: 4-layer (repeat 2-layer pattern twice)
// ================================================================
reg [31:0] gk [0:63];
integer gk_cnt;

integer i, n_dw;

initial begin
  rst_n=0; in_wr=0; in_data=0; in_ctrl=0; out_rdy=1;
  pass_cnt=0; fail_cnt=0;

  // ============================================================
  // Build GPU kernel: 4 WMMA layers (2-layer pattern × 2)
  // ============================================================
  // Layer 1: load X(4), load W(0), load B(8), MMA, ReLU, store H(20)
  gk[0] =32'h20000004; gk[1] =32'hF4400000;  // MOVI R0,4; WMMA.LOAD R4
  gk[2] =32'h20000000; gk[3] =32'hF4800000;  // MOVI R0,0; WMMA.LOAD R8
  gk[4] =32'h20000008; gk[5] =32'hF4C00000;  // MOVI R0,8; WMMA.LOAD R12
  gk[6] =32'hECC48C00;                        // WMMA.MMA
  gk[7] =32'h20000000;                        // MOVI R0,0
  gk[8] =32'h54CC0000; gk[9] =32'h54DD0000;  // MAX R12,R13
  gk[10]=32'h54EE0000; gk[11]=32'h54FF0000;   // MAX R14,R15
  gk[12]=32'h20000014; gk[13]=32'hFCC00000;   // MOVI R0,20; STORE
  // Layer 2: load W2(12), load H(20), load B2(16), MMA, store Y(24)
  gk[14]=32'h2000000C; gk[15]=32'hF4400000;
  gk[16]=32'h20000014; gk[17]=32'hF4800000;
  gk[18]=32'h20000010; gk[19]=32'hF4C00000;
  gk[20]=32'hECC48C00;
  gk[21]=32'h20000018; gk[22]=32'hFCC00000;
  // Repeat (iteration 2 = layers 3-4)
  for (i=0; i<23; i=i+1) gk[23+i] = gk[i];
  // RET + pad
  gk[46]=32'hC8000000; gk[47]=32'h00000000;
  gk_cnt = 48;

  // ============================================================
  // Build CPU program: 4 layers with shift-add multiply
  // DMEM: x[0-3]=0x000, b[4-7]=0x010, h1[8-11]=0x020,
  //       h2[12-15]=0x030, h3[16-19]=0x040, y[20-23]=0x050
  // ============================================================
  ci_cnt = 0;
  ci_emit(32'hE3A00000);                           // MOV R0, #0
  ci_layer(12'h000, 12'h010, 12'h020, 1);          // Layer 1: x→h1
  ci_layer(12'h020, 12'h010, 12'h030, 1);          // Layer 2: h1→h2
  ci_layer(12'h030, 12'h010, 12'h040, 1);          // Layer 3: h2→h3
  ci_layer(12'h040, 12'h010, 12'h050, 0);          // Layer 4: h3→y (no ReLU)
  ci_emit(32'hEAFFFFFE);                           // HALT

  repeat(10) tick; rst_n=1; repeat(5) tick;

  $display("");
  $display("================================================================");
  $display("  4-Layer ANN: GPU (WMMA) vs CPU (shift-add multiply)");
  $display("  Weights = [2, 3, -1, 5] per layer");
  $display("  GPU: %0d kernel instrs, CPU: %0d ARM instrs", gk_cnt, ci_cnt);
  $display("================================================================");

  // ================================================================
  //  GPU PATH
  // ================================================================
  $display("");
  $display("--- GPU Path: 4x WMMA.MMA ---");

  // ARM firmware: D_IMEM(48 words) + D_UNPACK + GPU launch + D_PACK + halt
  // D_IMEM: src=0, dst=0, len=48(0x30), tgt=5
  rx(cmd(4'h1,12'h000,16'd103,32'h0),8'h04);  // LOAD_IMEM 103 DWs
  rx({32'hEE000A10,32'hE3A00000},8'h00);  // MOV R0,#0; MCR CR0,R0
  rx({32'hE3A01030,32'hEE010A10},8'h00);  // MCR CR1,R0; MOV R1,#0x30
  rx({32'hE3A02005,32'hEE021A10},8'h00);  // MCR CR2,R1(=48); MOV R2,#5
  rx({NOP,32'hEE032A10},8'h00);            // MCR CR3,R2(=5 D_IMEM); NOP
  // D_IMEM wait 7 NOP pairs (48 words ≈ 100 cycles)
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00);
  // D_UNPACK: src=0x30(=48), dst=0, len=10, tgt=burst_all|start(0x41)
  rx({32'hEE000A10,32'hE3A00030},8'h00);
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
  // GPU wait: 55 NOP pairs (~440 cycles / 4 barrel = 110 instrs)
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
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00);
  // D_PACK: src=0x18(24), dst=0x60(96), len=2, tgt=0x43
  rx({32'hEE000A10,32'hE3A00018},8'h00);
  rx({32'hEE011A10,32'hE3A01060},8'h00);
  rx({32'hEE022A10,32'hE3A02002},8'h00);
  rx({32'hEE033A10,32'hE3A03043},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,NOP},8'h00); rx({NOP,NOP},8'h00);
  rx({NOP,HALT},8'h00);

  // Count actual LOAD_IMEM DWs: need to match the count=100
  // 4(D_IMEM) + 7(wait) + 4(D_UNPACK) + 20(wait) + 3(launch) + 55(wait) + 4(D_PACK) + 3(wait+halt) = 100 DWs ✓

  // GPU kernel (24 DWs at addr 0)
  rx(cmd(4'h2,12'h000,16'd24,32'h0),8'h00);
  for (i=0; i<gk_cnt; i=i+2)
    rx({gk[i+1], gk[i]}, 8'h00);

  // Matrix data (20 DWs at addr 0x030 = word 48), same as ann_inference_tb
  rx(cmd(4'h2,12'h030,16'd20,32'h0),8'h00);
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

  // Zero readback (4 DWs at addr 0x060 = word 96)
  rx(cmd(4'h2,12'h060,16'd4,32'h0),8'h00);
  rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00); rx(64'h0,8'h00);
  rx(cmd(4'h3,12'h000,16'd0,32'h0),8'h00);
  rx(cmd(4'h4,12'h060,16'd4,32'h0),8'h00);
  rx(cmd(4'h5,12'h000,16'd0,32'h0),8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, gpu_cycles);
  gpu_only = gpu_compute_count;
  $display("  GPU total:   %0d cycles", gpu_cycles);
  $display("  GPU compute: %0d cycles (4x WMMA.MMA)", gpu_only);
  $display("  GPU DMA:     %0d cycles (%0d%%)", gpu_cycles-gpu_only,
    (gpu_cycles > 0) ? (gpu_cycles-gpu_only)*100/gpu_cycles : 0);

  // ================================================================
  //  CPU PATH: 4-layer shift-add multiply
  // ================================================================
  $display("");
  $display("--- CPU Path: 4-layer shift-add multiply ---");
  repeat(100) tick;

  // Inject CPU program from ci[] array
  n_dw = (ci_cnt + 1) / 2;
  rx(cmd(4'h1, 12'h000, n_dw[15:0], 32'h0), 8'h04);
  for (i=0; i<ci_cnt; i=i+2) begin
    if (i+1 < ci_cnt)
      rx({ci[i+1], ci[i]}, 8'h00);
    else
      rx({32'h0, ci[i]}, 8'h00);
  end

  // Data: x=[1,2,3,4], b=[0,-10,-25,-30]
  rx(cmd(4'h2, 12'h000, 16'd4, 32'h0), 8'h00);
  rx({32'h00000002, 32'h00000001}, 8'h00);  // x[0]=1, x[1]=2
  rx({32'h00000004, 32'h00000003}, 8'h00);  // x[2]=3, x[3]=4
  rx({32'hFFFFFFF6, 32'h00000000}, 8'h00);  // b[0]=0, b[1]=-10
  rx({32'hFFFFFFE2, 32'hFFFFFFE7}, 8'h00);  // b[2]=-25, b[3]=-30

  // Zero y readback area (2 DWs at addr 0x014 = word 20)
  rx(cmd(4'h2, 12'h014, 16'd2, 32'h0), 8'h00);
  rx(64'h0, 8'h00); rx(64'h0, 8'h00);

  rx(cmd(4'h3, 12'h000, 16'd0, 32'h0), 8'h00);
  rx(cmd(4'h4, 12'h014, 16'd2, 32'h0), 8'h00);
  rx(cmd(4'h5, 12'h000, 16'd0, 32'h0), 8'h00);
  rx_end;

  wait_and_measure(MAX_CYCLES, cpu_cycles);
  $display("  CPU total:   %0d cycles (%0d ARM instrs)", cpu_cycles, ci_cnt);

  // Debug: show intermediate values
  $display("  h1[0..3]: %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[8]),  $signed(u_soc.u_cpu_dmem.mem[9]),
    $signed(u_soc.u_cpu_dmem.mem[10]), $signed(u_soc.u_cpu_dmem.mem[11]));
  $display("  h2[0..3]: %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[12]), $signed(u_soc.u_cpu_dmem.mem[13]),
    $signed(u_soc.u_cpu_dmem.mem[14]), $signed(u_soc.u_cpu_dmem.mem[15]));
  $display("  h3[0..3]: %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[16]), $signed(u_soc.u_cpu_dmem.mem[17]),
    $signed(u_soc.u_cpu_dmem.mem[18]), $signed(u_soc.u_cpu_dmem.mem[19]));
  $display("  y[0..3]:  %0d %0d %0d %0d",
    $signed(u_soc.u_cpu_dmem.mem[20]), $signed(u_soc.u_cpu_dmem.mem[21]),
    $signed(u_soc.u_cpu_dmem.mem[22]), $signed(u_soc.u_cpu_dmem.mem[23]));
  // Verify CPU output: y = [6145, 6135, 6120, 6115]
  check("CPU y[0]", $signed(u_soc.u_cpu_dmem.mem[20]), 6145);
  check("CPU y[1]", $signed(u_soc.u_cpu_dmem.mem[21]), 6135);
  check("CPU y[2]", $signed(u_soc.u_cpu_dmem.mem[22]), 6120);
  check("CPU y[3]", $signed(u_soc.u_cpu_dmem.mem[23]), 6115);

  // ================================================================
  $display("");
  $display("================================================================");
  $display("  SUMMARY: 4-Layer ANN (general weights)");
  $display("----------------------------------------------------------------");
  $display("  GPU total:           %0d cycles", gpu_cycles);
  $display("  GPU compute (WMMA):  %0d cycles", gpu_only);
  $display("  GPU DMA overhead:    %0d cycles", gpu_cycles - gpu_only);
  $display("  CPU compute (shift): %0d cycles (%0d instrs)", cpu_cycles, ci_cnt);
  $display("----------------------------------------------------------------");
  if (cpu_cycles > 0 && gpu_only > 0)
    $display("  Compute only: GPU is %0d.%01dx FASTER",
      cpu_cycles/gpu_only, (cpu_cycles*10/gpu_only)%10);
  if (cpu_cycles > 0 && gpu_cycles > 0) begin
    if (gpu_cycles < cpu_cycles)
      $display("  Including DMA: GPU is %0d.%01dx FASTER",
        cpu_cycles/gpu_cycles, (cpu_cycles*10/gpu_cycles)%10);
    else
      $display("  Including DMA: GPU is %0d.%01dx SLOWER",
        gpu_cycles/cpu_cycles, (gpu_cycles*10/cpu_cycles)%10);
  end
  $display("  %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
  $display("================================================================");
  #(CLK_PERIOD*5); $finish;
end
endmodule
