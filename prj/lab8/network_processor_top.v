`timescale 1ns / 1ps

module network_processor_top #(
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2
) (
    // --- NetFPGA Pipeline Interface ---
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output                             in_rdy,

    output [DATA_WIDTH-1:0]            out_data,
    output [CTRL_WIDTH-1:0]            out_ctrl,
    output                             out_wr,
    input                              out_rdy,

    // --- Register Interface (passthrough) ---
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
    output [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
    output [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

    // --- Misc ---
    input                              clk,
    input                              reset
);

    // ================================================================
    //  Software Registers (host PC → FPGA via generic_regs)
    // ================================================================
    wire [31:0] cpu_imem_addr, cpu_imem_data;
    wire [31:0] gpu_imem_addr, gpu_imem_data;
    wire [31:0] sys_ctrl;

    // Hardware Registers (FPGA → host PC)
    wire [31:0] gpu_status;
    wire [31:0] gpu_pc;
    reg  [31:0] cycle_counts;

    generic_regs #(
        .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
        .TAG               (`GPU_BLOCK_ADDR),
        .REG_ADDR_WIDTH    (`GPU_REG_ADDR_WIDTH),
        .NUM_COUNTERS      (0),
        .NUM_SOFTWARE_REGS (5),
        .NUM_HARDWARE_REGS (3)
    ) module_reg (
        .reg_req_in(reg_req_in), .reg_ack_in(reg_ack_in),
        .reg_rd_wr_L_in(reg_rd_wr_L_in),
        .reg_addr_in(reg_addr_in), .reg_data_in(reg_data_in),
        .reg_src_in(reg_src_in),

        .reg_req_out(reg_req_out), .reg_ack_out(reg_ack_out),
        .reg_rd_wr_L_out(reg_rd_wr_L_out),
        .reg_addr_out(reg_addr_out), .reg_data_out(reg_data_out),
        .reg_src_out(reg_src_out),

        // SW regs: {sys_ctrl, gpu_imem_data, gpu_imem_addr, cpu_imem_data, cpu_imem_addr}
        .software_regs({sys_ctrl, gpu_imem_data, gpu_imem_addr, cpu_imem_data, cpu_imem_addr}),
        // HW regs: {gpu_status, cycle_counts, gpu_pc}
        .hardware_regs({gpu_status, cycle_counts, gpu_pc}),

        .clk(clk),
        .reset(reset)
    );

    // System control bits (from host PC)
    wire cpu_imem_we  = sys_ctrl[0];
    wire gpu_imem_we  = sys_ctrl[1];
    wire sys_reset    = reset | sys_ctrl[2];   // software reset

    // Cycle counter
    always @(posedge clk) begin
        if (sys_reset)
            cycle_counts <= 32'b0;
        else
            cycle_counts <= cycle_counts + 1;
    end

    // ================================================================
    //  CPU ↔ FIFO ↔ GPU Interconnect Wires
    // ================================================================

    // CPU ↔ FIFO (Port A)
    wire [7:0]  cpu_fifo_addr;
    wire [63:0] cpu_fifo_wdata;
    wire        cpu_fifo_we;
    wire [63:0] cpu_fifo_rdata;

    // CPU control outputs
    wire        ctrl_mode_select;
    wire        ctrl_send_packet;
    wire        ctrl_gpu_rst;
    wire        ctrl_gpu_run;

    // Status inputs to CPU
    wire        ctrl_packet_ready;
    wire        ctrl_gpu_halted;
    wire [7:0]  ctrl_head_ptr;
    wire [7:0]  ctrl_tail_ptr;

    // GPU ↔ FIFO (Port B)
    wire [9:0]  gpu_dmem_addr;
    wire [63:0] gpu_dmem_wdata;
    wire        gpu_dmem_we;
    wire [63:0] gpu_dmem_rdata;

    // FIFO Port B raw output (72-bit)
    wire [71:0] fifo_data_out_b;

    // GPU debug
    wire [9:0]  gpu_debug_pc;
    wire        gpu_halted;
    wire [3:0]  gpu_state;

    // ================================================================
    //  CPU Instance
    // ================================================================
    ARM_Processor_4T cpu_inst (
        .CLK        (clk),
        .CLR_ALL    (sys_reset),
        .IM_CLR     (sys_reset),

        // Program loading from host PC
        .ADDR       (cpu_imem_addr[10:2]),
        .DIN        (cpu_imem_data),
        .IM_WE      (cpu_imem_we),

        // FIFO Port A
        .cpu_fifo_addr  (cpu_fifo_addr),
        .cpu_fifo_wdata (cpu_fifo_wdata),
        .cpu_fifo_we    (cpu_fifo_we),
        .cpu_fifo_rdata (cpu_fifo_rdata),

        // Control interface
        .ctrl_mode_select  (ctrl_mode_select),
        .ctrl_send_packet  (ctrl_send_packet),
        .ctrl_gpu_rst      (ctrl_gpu_rst),
        .ctrl_gpu_run      (ctrl_gpu_run),
        .ctrl_packet_ready (ctrl_packet_ready),
        .ctrl_gpu_halted   (ctrl_gpu_halted),
        .ctrl_head_ptr     (ctrl_head_ptr),
        .ctrl_tail_ptr     (ctrl_tail_ptr)
    );

    // ================================================================
    //  GPU Instance
    // ================================================================
    wire gpu_reset = sys_reset | ctrl_gpu_rst;

    assign gpu_pc     = {22'b0, gpu_debug_pc};
    assign gpu_status = {27'b0, gpu_halted, gpu_state};
    assign ctrl_gpu_halted = gpu_halted;

    gpu_top gpu_inst (
        .clk        (clk),
        .rst        (gpu_reset),
        .run        (ctrl_gpu_run),
        .thread_id  (10'd0),
        .halted     (gpu_halted),
        .debug_pc   (gpu_debug_pc),
        .debug_ir   (),
        .debug_state(gpu_state),

        // GPU program loading from host PC
        .ext_imem_addr (gpu_imem_addr[9:0]),
        .ext_imem_data (gpu_imem_data),
        .ext_imem_we   (gpu_imem_we),

        // External dmem → routed to FIFO Port B
        .gpu_dmem_addr  (gpu_dmem_addr),
        .gpu_dmem_wdata (gpu_dmem_wdata),
        .gpu_dmem_we    (gpu_dmem_we),
        .gpu_dmem_rdata (gpu_dmem_rdata)
    );

    // ================================================================
    //  Convertible FIFO Instance
    // ================================================================

    // Port A: CPU access — 64-bit data zero-padded to 72
    // Port B: GPU access (when not sending) — 64-bit with 8-bit ctrl

    convertible_fifo fifo_inst (
        .clk    (clk),
        .rst    (sys_reset),

        // Network pipeline interface
        .in_data    (in_data),
        .in_ctrl    (in_ctrl),
        .in_wr      (in_wr),
        .in_rdy     (in_rdy),
        .out_data   (out_data),
        .out_ctrl   (out_ctrl),
        .out_wr     (out_wr),
        .out_rdy    (out_rdy),

        // Mode control
        .mode_select    (ctrl_mode_select),

        // Port A — CPU
        .cpu_addr_a     (cpu_fifo_addr),
        .cpu_data_in_a  ({8'b0, cpu_fifo_wdata}),   // zero-pad upper 8 bits
        .cpu_we_a       (cpu_fifo_we),
        .cpu_data_out_a (fifo_data_out_a),

        // Port B — GPU (active when not sending)
        .portb_addr     (gpu_dmem_addr[7:0]),         // truncate 10→8
        .portb_data_in  ({8'b0, gpu_dmem_wdata}),    // zero-pad upper 8 bits
        .portb_we       (gpu_dmem_we),
        .portb_data_out (fifo_data_out_b),

        // Pointer management (not used — FSM auto-resets)
        .cpu_head_ptr_in (8'b0),
        .cpu_tail_ptr_in (8'b0),
        .cpu_ptr_we      (1'b0),
        .head_ptr_val    (ctrl_head_ptr),
        .tail_ptr_val    (ctrl_tail_ptr),

        // Control
        .packet_ready   (ctrl_packet_ready),
        .send_packet    (ctrl_send_packet)
    );

    // GPU reads lower 64 bits from FIFO Port B
    assign gpu_dmem_rdata = fifo_data_out_b[63:0];

    // CPU reads lower 64 bits from FIFO Port A
    wire [71:0] fifo_data_out_a;
    assign cpu_fifo_rdata = fifo_data_out_a[63:0];

endmodule
