/* file: gpu_wrapper.v
 Description: NetFPGA GPU wrapper module. Bridges the gpu_top to the NetFPGA
   register interface (generic_regs) and data path. Provides software registers
   for IMEM/DMEM access and GPU control from the host.
 Author: Raymond
 Date: Mar. 5, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation for Lab 8 NetFPGA integration. (Mar. 5, 2026)
 */

`ifndef GPU_WRAPPER_V
`define GPU_WRAPPER_V
module gpu_wrapper #(
	parameter DATA_WIDTH = 64,
	parameter CTRL_WIDTH = DATA_WIDTH/8,
	parameter UDP_REG_SRC_WIDTH = 2
) (
      // --- data path interface
      input  [DATA_WIDTH-1:0]     in_data,
      input  [CTRL_WIDTH-1:0]     in_ctrl,
      input                  in_wr,
      output                 in_rdy,

      output [DATA_WIDTH-1:0]  out_data,
      output [CTRL_WIDTH-1:0]  out_ctrl,
      output                 out_wr,
      input                  out_rdy,

      // --- Register interface
      input                  reg_req_in,
      input                  reg_ack_in,
      input                  reg_rd_wr_L_in,
      input [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_in,
      input [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
      input [UDP_REG_SRC_WIDTH-1:0] reg_src_in,

      output                 reg_req_out,
      output                 reg_ack_out,
      output                 reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0] reg_src_out,

      // --- Misc
      input                  clk,
      input                  reset
);

// Software registers (ARM -> FPGA)
wire [31:0] imem_addr, imem_data, dmem_addr, dmem_wr_data_lo, dmem_wr_data_hi, gpu_ctrl;

// Hardware registers (FPGA -> ARM)
wire [31:0] current_pc;
wire [31:0] dmem_rd_data_lo, dmem_rd_data_hi;
reg  [31:0] cycle_counts;
wire [31:0] gpu_status;

//******************************************************************
//    Register Interface
//*****************************************************************

generic_regs #(
	.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
	.TAG               (`GPU_BLOCK_ADDR),
	.REG_ADDR_WIDTH    (`GPU_REG_ADDR_WIDTH),
	.NUM_COUNTERS      (0),
	.NUM_SOFTWARE_REGS (6),
	.NUM_HARDWARE_REGS (5)
) module_reg (
	.reg_req_in(reg_req_in), .reg_ack_in(reg_ack_in), .reg_rd_wr_L_in(reg_rd_wr_L_in),
	.reg_addr_in(reg_addr_in), .reg_data_in(reg_data_in), .reg_src_in(reg_src_in),

	.reg_req_out(reg_req_out), .reg_ack_out(reg_ack_out), .reg_rd_wr_L_out(reg_rd_wr_L_out),
        .reg_addr_out(reg_addr_out), .reg_data_out(reg_data_out), .reg_src_out(reg_src_out),

	// Software regs: concatenated MSB-first (highest index reg is MSB)
	.software_regs ({gpu_ctrl, dmem_wr_data_hi, dmem_wr_data_lo, dmem_addr, imem_data, imem_addr}),
	// Hardware regs: concatenated MSB-first
	.hardware_regs ({gpu_status, cycle_counts, dmem_rd_data_hi, dmem_rd_data_lo, current_pc}),

	.clk(clk),
	.reset(reset)
);

//******************************************************************
//    Data path pass through
//*****************************************************************
assign out_data = in_data;
assign out_ctrl = in_ctrl;
assign out_wr = in_wr;
assign in_rdy = out_rdy;

//******************************************************************
//    GPU control signals
//*****************************************************************
wire gpu_reset = reset | gpu_ctrl[0];
wire gpu_run   = gpu_ctrl[1];
wire gpu_imem_we = gpu_ctrl[2];
wire gpu_dmem_we = gpu_ctrl[3];

//******************************************************************
//    GPU instance
//*****************************************************************
wire [9:0]  gpu_pc;
wire        gpu_halted;
wire [3:0]  gpu_state;
wire [63:0] ext_dmem_rdata;

assign current_pc = {22'h0, gpu_pc};
assign gpu_status = {27'h0, gpu_halted, gpu_state};

// Dmem read data split into lo/hi for ARM registers
assign dmem_rd_data_lo = ext_dmem_rdata[31:0];
assign dmem_rd_data_hi = ext_dmem_rdata[63:32];

// Cycle counter
always @(posedge clk) begin
	if(gpu_reset) begin
		cycle_counts <= 32'h0;
	end else begin
		cycle_counts <= cycle_counts + 1;
	end
end

gpu_top gpu_inst (
	.clk        (clk),
	.rst        (gpu_reset),
	.run        (gpu_run),
	.thread_id  (10'd0),
	.halted     (gpu_halted),
	.debug_pc   (gpu_pc),
	.debug_ir   (),
	.debug_state(gpu_state),

	// External imem write port
	.ext_imem_addr (imem_addr[9:0]),
	.ext_imem_data (imem_data),
	.ext_imem_we   (gpu_imem_we),

	// External dmem read/write port
	.ext_dmem_addr  (dmem_addr[9:0]),
	.ext_dmem_wdata ({dmem_wr_data_hi, dmem_wr_data_lo}),
	.ext_dmem_we    (gpu_dmem_we),
	.ext_dmem_rdata (ext_dmem_rdata)
);

endmodule
`endif // GPU_WRAPPER_V
