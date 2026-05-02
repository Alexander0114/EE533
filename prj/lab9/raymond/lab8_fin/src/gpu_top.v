`timescale 1ns / 1ps
module gpu_top (
    input         clk,
    input         rst,
    input         run,
    input  [9:0]  thread_id,
    output        halted,
    output [9:0]  debug_pc,
    output [31:0] debug_ir,
    output [3:0]  debug_state,

    // External imem write port (ARM access)
    input  [9:0]  ext_imem_addr,
    input  [31:0] ext_imem_data,
    input         ext_imem_we,

    // External dmem interface (active always — BRAM is external)
    output [9:0]  gpu_dmem_addr,
    output [63:0] gpu_dmem_wdata,
    output        gpu_dmem_we,
    input  [63:0] gpu_dmem_rdata
);

    // === Control Unit Signals ===
    wire [9:0]  pc;
    wire [4:0]  rf_rd_a, rf_rd_b, rf_rd_c, rf_wr_addr;
    wire        rf_we;
    wire [3:0]  alu_func;
    wire        tensor_start;
    wire [2:0]  tensor_op_mode;
    wire        tensor_relu_en;
    wire        dmem_we;
    wire [2:0]  wb_sel;
    wire [63:0] imm_out;
    wire [9:0]  dmem_addr;
    wire [3:0]  state;

    // === Instruction Memory ===
    // When rst is asserted, ARM has control for writing; otherwise GPU reads
    wire [31:0] instruction;
    wire [9:0]  imem_addr_mux = (rst & ext_imem_we) ? ext_imem_addr : pc;
    wire        imem_we_mux   = rst & ext_imem_we;

    imem imem_inst (
        .addr(imem_addr_mux),
        .clk(clk),
        .din(ext_imem_data),
        .dout(instruction),
        .we(imem_we_mux)
    );

    // === Register File ===
    wire [63:0] rf_a, rf_b, rf_c;
    wire [63:0] rf_w_data;

    Register_file rf_inst (
        .clk(clk), .rst(rst), .we(rf_we),
        .w_addr(rf_wr_addr), .w_data(rf_w_data),
        .r_addr_a(rf_rd_a), .r_data_a(rf_a),
        .r_addr_b(rf_rd_b), .r_data_b(rf_b),
        .r_addr_c(rf_rd_c), .r_data_c(rf_c)
    );

    // === ALU ===
    wire [63:0] alu_result;
    gpu_alu alu_inst (
        .operand_a(rf_a), .operand_b(rf_b),
        .func(alu_func), .result(alu_result)
    );

    // === Tensor Unit ===
    wire [63:0] tensor_result;
    wire        tensor_done;
    tensor_unit tensor_inst (
        .clk(clk), .rst(rst), .start(tensor_start),
        .operand_a(rf_a), .operand_b(rf_b), .operand_c(rf_c),
        .op_mode(tensor_op_mode), .relu_en(tensor_relu_en),
        .result(tensor_result), .done(tensor_done)
    );

    // === Data Memory (externalized) ===
    // GPU drives address/data/we — top-level connects to FIFO Port B
    wire [63:0] dmem_rdata = gpu_dmem_rdata;

    assign gpu_dmem_addr  = dmem_addr;
    assign gpu_dmem_wdata = rf_b;
    assign gpu_dmem_we    = dmem_we;

    // === ReLU INT (per-lane max(0, x) on rf_a) ===
    wire [63:0] relu_int_result;
    assign relu_int_result[15:0]  = rf_a[15]  ? 16'b0 : rf_a[15:0];
    assign relu_int_result[31:16] = rf_a[31]  ? 16'b0 : rf_a[31:16];
    assign relu_int_result[47:32] = rf_a[47]  ? 16'b0 : rf_a[47:32];
    assign relu_int_result[63:48] = rf_a[63]  ? 16'b0 : rf_a[63:48];

    // === VBCAST: broadcast one BF16/int16 lane across all 4 lanes ===
    // Use tensor_op_mode (latched from IR[2:0] by control unit) as lane selector
    reg  [15:0] vbcast_sel;
    always @(*) begin
        case (tensor_op_mode[1:0])
            2'd0: vbcast_sel = rf_a[63:48];
            2'd1: vbcast_sel = rf_a[47:32];
            2'd2: vbcast_sel = rf_a[31:16];
            2'd3: vbcast_sel = rf_a[15:0];
        endcase
    end
    wire [63:0] vbcast_result = {vbcast_sel, vbcast_sel, vbcast_sel, vbcast_sel};

    // === Writeback Mux ===
    reg [63:0] wb_data;
    always @(*) begin
        case (wb_sel)
            3'd0: wb_data = alu_result;
            3'd1: wb_data = tensor_result;
            3'd2: wb_data = dmem_rdata;
            3'd3: wb_data = imm_out;
            3'd4: wb_data = {54'b0, pc + 10'd1};
            3'd5: wb_data = imm_out;
            3'd6: wb_data = relu_int_result;
            3'd7: wb_data = vbcast_result;
            default: wb_data = 64'b0;
        endcase
    end

    assign rf_w_data = wb_data;

    // === Control Unit ===
    gpu_control_unit ctrl_inst (
        .clk(clk), .rst(rst), .run(run),
        .instruction(instruction), .tensor_done(tensor_done),
        .thread_id(thread_id),
        .cmp_a(rf_a), .cmp_b(rf_b),
        .pc(pc),
        .rf_rd_a(rf_rd_a), .rf_rd_b(rf_rd_b), .rf_rd_c(rf_rd_c),
        .rf_wr_addr(rf_wr_addr), .rf_we(rf_we),
        .alu_func(alu_func),
        .tensor_start(tensor_start), .tensor_op_mode(tensor_op_mode),
        .tensor_relu_en(tensor_relu_en),
        .dmem_we(dmem_we), .wb_sel(wb_sel),
        .imm_out(imm_out), .dmem_addr(dmem_addr),
        .halted(halted), .state(state)
    );

    // === Debug Outputs ===
    assign debug_pc    = pc;
    assign debug_ir    = instruction;
    assign debug_state = state;

endmodule
