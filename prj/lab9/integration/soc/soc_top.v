/* file: soc_top.v
Description: Lab 9 SoC top-level. Jeremy's 4-thread barrel ARM CPU + Raymond's
   SIMD GPU. pkt_proc loads all memories directly (no DMA engine). CPU controls
   GPU via CP10 MCR/MRC instructions.
Author: Jeremy Cai (soc.v v1.0), Raymond (soc_top.v v1.0)
Date: Mar. 11, 2026
Version: 1.0
Revision history:
    - Mar. 11, 2026: v1.0 — New top-level replacing soc.v. Removed DMA engine
            and sm_core. Added Raymond's gpu_top with dedicated 256x64 DMEM BRAM.
            pkt_proc v3.0 handles CPU + GPU memory loading.

Architecture:
    conv_fifo <-> pkt_proc -> CPU IMEM (Port B write)
                           -> CPU DMEM (Port B read/write)
                           -> GPU IMEM (ext_imem write via gpu_top)
                           -> GPU DMEM BRAM (Port B read/write)
    cpu_mt <-> CPU IMEM (Port A fetch)
           <-> CPU DMEM (Port A read/write)
           <-> CP10 (MCR/MRC)
    CP10 -> gpu_top (start, reset)
    gpu_top <-> GPU DMEM BRAM (Port A read/write)
*/

`ifndef SOC_TOP_V
`define SOC_TOP_V

`include "define.v"

module soc_top (
    input wire clk,
    input wire rst_n,

    // NetFPGA RX (from output_port_lookup)
    input wire [63:0] in_data,
    input wire [7:0]  in_ctrl,
    input wire        in_wr,
    output wire       in_rdy,

    // NetFPGA TX (to output_queues)
    output wire [63:0] out_data,
    output wire [7:0]  out_ctrl,
    output wire        out_wr,
    input wire         out_rdy
);

    // ================================================================
    // Parameters
    // ================================================================
    localparam GPU_IMEM_ADDR_WIDTH = 10;  // 1024 x 32-bit instructions
    localparam GPU_DMEM_ADDR_WIDTH = 8;   // 256 x 64-bit data words

    // ================================================================
    // pkt_proc <-> conv_fifo
    // ================================================================
    wire [11:0] pp_fifo_addr;
    wire [63:0] pp_fifo_wdata;
    wire        pp_fifo_we;
    wire [63:0] pp_fifo_rdata;
    wire [1:0]  pp_fifo_mode;
    wire [11:0] pp_fifo_head_wr_data, pp_fifo_tail_wr_data;
    wire        pp_fifo_head_wr, pp_fifo_tail_wr;
    wire        pp_fifo_tx_start, pp_fifo_pkt_ack;
    wire [11:0] fifo_head_ptr, fifo_tail_ptr, fifo_pkt_end;
    wire        fifo_pkt_ready, fifo_tx_done;
    wire        fifo_nearly_full, fifo_empty, fifo_full;

    // ================================================================
    // pkt_proc <-> CPU memories
    // ================================================================
    wire [`IMEM_ADDR_WIDTH-1:0] pp_imem_addr;
    wire [31:0] pp_imem_din;
    wire        pp_imem_we;

    wire [`DMEM_ADDR_WIDTH-1:0] pp_dmem_addr;
    wire [31:0] pp_dmem_din;
    wire        pp_dmem_we;
    wire [31:0] pp_dmem_dout;

    // ================================================================
    // pkt_proc <-> GPU memories
    // ================================================================
    wire [GPU_IMEM_ADDR_WIDTH-1:0] pp_gpu_imem_addr;
    wire [31:0] pp_gpu_imem_din;
    wire        pp_gpu_imem_we;

    wire [GPU_DMEM_ADDR_WIDTH-1:0] pp_gpu_dmem_addr;
    wire [63:0] pp_gpu_dmem_wdata;
    wire        pp_gpu_dmem_we;
    wire [63:0] pp_gpu_dmem_rdata;

    // ================================================================
    // pkt_proc <-> CPU control
    // ================================================================
    wire        pp_cpu_rst_n;
    wire        pp_cpu_start;
    wire [31:0] pp_entry_pc;
    wire        pp_active, pp_owns_port_b;

    // ================================================================
    // CPU <-> memories
    // ================================================================
    wire [`PC_WIDTH-1:0]             cpu_imem_byte_addr;
    wire [`INSTR_WIDTH-1:0]          cpu_imem_rdata;

    wire [`CPU_DMEM_ADDR_WIDTH-1:0]  cpu_dmem_byte_addr;
    wire [`DATA_WIDTH-1:0]           cpu_dmem_rdata;
    wire [`DATA_WIDTH-1:0]           cpu_dmem_wdata;
    wire                             cpu_dmem_wen;
    wire [1:0]                       cpu_dmem_size;
    wire                             cpu_done_w;

    // ================================================================
    // CPU <-> CP10
    // ================================================================
    wire        cp_wen, cp_ren;
    wire [3:0]  cp_reg;
    wire [31:0] cp_wr_data, cp_rd_data;

    // ================================================================
    // CP10 <-> GPU
    // ================================================================
    wire        gpu_kernel_start_w;
    wire        gpu_reset_cp10;      // active-high from CP10 CR5[1]
    wire        gpu_halted_w;        // level from gpu_top

    // gpu_active: flop set on kernel_start, cleared on halted
    reg gpu_active_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                   gpu_active_r <= 1'b0;
        else if (gpu_kernel_start_w)  gpu_active_r <= 1'b1;
        else if (gpu_halted_w)        gpu_active_r <= 1'b0;
    end

    // ================================================================
    // GPU reset logic
    // ================================================================
    // GPU is in reset when:
    //   - Global reset (!rst_n)
    //   - CPU not yet started (pp_cpu_rst_n=0, i.e. pkt_proc loading phase)
    //   - CP10 asserts reset (CR5[1]=1)
    // This ensures GPU IMEM ext writes work during pkt_proc loading
    // (gpu_top gates ext_imem_we with rst).
    wire gpu_rst = ~rst_n | ~pp_cpu_rst_n | gpu_reset_cp10;

    // ================================================================
    // GPU DMEM BRAM wires (Port A = GPU, Port B = pkt_proc)
    // ================================================================
    wire [9:0]  gpu_dmem_addr_a;   // 10-bit from gpu_top, lower 8 used
    wire [63:0] gpu_dmem_wdata_a;
    wire        gpu_dmem_we_a;
    wire [63:0] gpu_dmem_rdata_a;

    // ================================================================
    //   CONVERTIBLE FIFO
    // ================================================================
    conv_fifo #(
        .ADDR_WIDTH(12), .DATA_WIDTH(64), .CTRL_WIDTH(8)
    ) u_conv_fifo (
        .clk(clk), .rst_n(rst_n),
        .mode(pp_fifo_mode),
        // RX
        .in_data(in_data), .in_ctrl(in_ctrl), .in_wr(in_wr), .in_rdy(in_rdy),
        // TX
        .out_data(out_data), .out_ctrl(out_ctrl), .out_wr(out_wr), .out_rdy(out_rdy),
        // TX drain control
        .tx_start(pp_fifo_tx_start), .pkt_ack(pp_fifo_pkt_ack), .tx_done(fifo_tx_done),
        // SRAM Port B (pkt_proc)
        .sram_addr(pp_fifo_addr), .sram_wdata(pp_fifo_wdata),
        .sram_we(pp_fifo_we), .sram_rdata(pp_fifo_rdata),
        // Pointer I/O
        .head_ptr_in(pp_fifo_head_wr_data), .head_ptr_wr(pp_fifo_head_wr),
        .tail_ptr_in(pp_fifo_tail_wr_data), .tail_ptr_wr(pp_fifo_tail_wr),
        .head_ptr_out(fifo_head_ptr), .tail_ptr_out(fifo_tail_ptr),
        .pkt_end_ptr(fifo_pkt_end),
        // Status
        .pkt_ready(fifo_pkt_ready), .nearly_full(fifo_nearly_full),
        .fifo_empty(fifo_empty), .fifo_full(fifo_full)
    );

    // ================================================================
    //   PACKET PROCESSOR (v3.0 — sole FIFO master)
    // ================================================================
    pkt_proc #(
        .FIFO_ADDR_WIDTH     (12),
        .IMEM_ADDR_WIDTH     (`IMEM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH     (`DMEM_ADDR_WIDTH),
        .GPU_IMEM_ADDR_WIDTH (GPU_IMEM_ADDR_WIDTH),
        .GPU_DMEM_ADDR_WIDTH (GPU_DMEM_ADDR_WIDTH)
    ) u_pkt_proc (
        .clk(clk), .rst_n(rst_n),
        // FIFO interface
        .fifo_addr(pp_fifo_addr), .fifo_wdata(pp_fifo_wdata),
        .fifo_we(pp_fifo_we), .fifo_rdata(pp_fifo_rdata),
        .fifo_mode(pp_fifo_mode),
        .fifo_head_wr_data(pp_fifo_head_wr_data), .fifo_head_wr(pp_fifo_head_wr),
        .fifo_tail_wr_data(pp_fifo_tail_wr_data), .fifo_tail_wr(pp_fifo_tail_wr),
        .fifo_tx_start(pp_fifo_tx_start),
        .fifo_head_ptr(fifo_head_ptr), .fifo_pkt_end(fifo_pkt_end),
        .fifo_pkt_ready(fifo_pkt_ready), .fifo_pkt_ack(pp_fifo_pkt_ack),
        .fifo_tx_done(fifo_tx_done),
        // CPU IMEM Port B
        .imem_addr(pp_imem_addr), .imem_din(pp_imem_din), .imem_we(pp_imem_we),
        // CPU DMEM Port B
        .dmem_addr(pp_dmem_addr), .dmem_din(pp_dmem_din),
        .dmem_we(pp_dmem_we), .dmem_dout(pp_dmem_dout),
        // CPU control
        .cpu_rst_n(pp_cpu_rst_n), .cpu_start(pp_cpu_start),
        .entry_pc(pp_entry_pc), .cpu_done(cpu_done_w),
        // GPU IMEM
        .gpu_imem_addr(pp_gpu_imem_addr), .gpu_imem_din(pp_gpu_imem_din),
        .gpu_imem_we(pp_gpu_imem_we),
        // GPU DMEM
        .gpu_dmem_addr(pp_gpu_dmem_addr), .gpu_dmem_wdata(pp_gpu_dmem_wdata),
        .gpu_dmem_we(pp_gpu_dmem_we), .gpu_dmem_rdata(pp_gpu_dmem_rdata),
        // Status
        .active(pp_active), .owns_port_b(pp_owns_port_b)
    );

    // ================================================================
    //   CPU IMEM — dual-port (uses Jeremy's test_i_mem)
    //     Port A: CPU fetch (byte addr -> word addr)
    //     Port B: pkt_proc write
    // ================================================================
    test_i_mem u_cpu_imem (
        .clka(clk),
        .addra(cpu_imem_byte_addr[`IMEM_ADDR_WIDTH+1:2]),
        .dina({`IMEM_DATA_WIDTH{1'b0}}),
        .wea(1'b0),
        .douta(cpu_imem_rdata),
        .clkb(clk),
        .addrb(pp_imem_addr),
        .dinb(pp_imem_din),
        .web(pp_imem_we),
        .doutb()
    );

    // ================================================================
    //   CPU DMEM — dual-port (uses Jeremy's test_d_mem)
    //     Port A: CPU read/write (byte addr -> word addr)
    //     Port B: pkt_proc read/write (no DMA mux needed)
    // ================================================================
    test_d_mem u_cpu_dmem (
        .clka(clk),
        .addra(cpu_dmem_byte_addr[`DMEM_ADDR_WIDTH+1:2]),
        .dina(cpu_dmem_wdata),
        .wea(cpu_dmem_wen),
        .douta(cpu_dmem_rdata),
        .clkb(clk),
        .addrb(pp_dmem_addr),
        .dinb(pp_dmem_din),
        .web(pp_dmem_we),
        .doutb(pp_dmem_dout)
    );

    // ================================================================
    //   ARM CPU — 7-stage FGMT barrel (cpu_mt)
    //     rst_n gated by pkt_proc's cpu_rst_n
    // ================================================================
    wire cpu_rst_gated = rst_n & pp_cpu_rst_n;

    cpu_mt u_cpu_mt (
        .clk(clk), .rst_n(cpu_rst_gated),
        .cpu_start_i(pp_cpu_start), .entry_pc_i(pp_entry_pc),
        // IMEM
        .i_mem_data_i(cpu_imem_rdata), .i_mem_addr_o(cpu_imem_byte_addr),
        // DMEM
        .d_mem_data_i(cpu_dmem_rdata), .d_mem_addr_o(cpu_dmem_byte_addr),
        .d_mem_data_o(cpu_dmem_wdata), .d_mem_wen_o(cpu_dmem_wen),
        .d_mem_size_o(cpu_dmem_size),
        // CP10
        .cp_wen_o(cp_wen), .cp_ren_o(cp_ren), .cp_reg_o(cp_reg),
        .cp_wr_data_o(cp_wr_data), .cp_rd_data_i(cp_rd_data),
        .cpu_done(cpu_done_w)
    );

    // ================================================================
    //   CP10 — Coprocessor Register File (v2.0, no DMA)
    // ================================================================
    cp10_regfile u_cp10 (
        .clk(clk), .rst_n(rst_n),
        .cp_wen(cp_wen), .cp_ren(cp_ren), .cp_reg(cp_reg),
        .cp_wdata(cp_wr_data), .cp_rdata(cp_rd_data),
        // GPU
        .gpu_kernel_start(gpu_kernel_start_w),
        .gpu_reset(gpu_reset_cp10),
        .gpu_kernel_done(gpu_halted_w),
        .gpu_active(gpu_active_r)
    );

    // ================================================================
    //   GPU — Raymond's SIMD gpu_top (v1.3)
    // ================================================================
    gpu_top u_gpu (
        .clk(clk),
        .rst(gpu_rst),
        .run(gpu_kernel_start_w),
        .thread_id(10'd0),
        .halted(gpu_halted_w),
        .debug_pc(),
        .debug_ir(),
        .debug_state(),
        // External IMEM write (from pkt_proc, gated by rst inside gpu_top)
        .ext_imem_addr(pp_gpu_imem_addr),
        .ext_imem_data(pp_gpu_imem_din),
        .ext_imem_we(pp_gpu_imem_we),
        // External DMEM (Port A of gpu_dmem_bram)
        .gpu_dmem_addr(gpu_dmem_addr_a),
        .gpu_dmem_wdata(gpu_dmem_wdata_a),
        .gpu_dmem_we(gpu_dmem_we_a),
        .gpu_dmem_rdata(gpu_dmem_rdata_a)
    );

    // ================================================================
    //   GPU DMEM BRAM — 256 x 64-bit dual-port
    //     Port A: GPU read/write
    //     Port B: pkt_proc read/write
    // ================================================================
    test_gpu_dmem #(
        .ADDR_WIDTH(GPU_DMEM_ADDR_WIDTH),
        .DATA_WIDTH(64)
    ) u_gpu_dmem (
        // Port A: GPU
        .clka(clk),
        .addra(gpu_dmem_addr_a[GPU_DMEM_ADDR_WIDTH-1:0]),
        .dina(gpu_dmem_wdata_a),
        .wea(gpu_dmem_we_a),
        .douta(gpu_dmem_rdata_a),
        // Port B: pkt_proc
        .clkb(clk),
        .addrb(pp_gpu_dmem_addr),
        .dinb(pp_gpu_dmem_wdata),
        .web(pp_gpu_dmem_we),
        .doutb(pp_gpu_dmem_rdata)
    );

endmodule

`endif // SOC_TOP_V
