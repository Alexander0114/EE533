`timescale 1ns / 1ps
module gpu_control_unit (
    input         clk,
    input         rst,
    input         run,
    input  [31:0] instruction,
    input         tensor_done,
    input  [9:0]  thread_id,

    // Comparison inputs (from register file reads)
    input  [63:0] cmp_a,
    input  [63:0] cmp_b,

    // PC
    output reg [9:0] pc,

    // Register file control
    output reg [4:0] rf_rd_a,
    output reg [4:0] rf_rd_b,
    output reg [4:0] rf_rd_c,
    output reg [4:0] rf_wr_addr,
    output reg       rf_we,

    // ALU control
    output reg [3:0] alu_func,

    // Tensor control
    output reg       tensor_start,
    output reg [2:0] tensor_op_mode,
    output reg       tensor_relu_en,

    // Memory control
    output reg       dmem_we,

    // Writeback select: 0=ALU, 1=tensor, 2=dmem, 3=imm, 4=PC+1, 5=LUI, 6=relu_int
    output reg [2:0] wb_sel,

    // Immediate output (for MOVI/ADDI/LUI)
    output reg [63:0] imm_out,

    // Data memory address
    output reg [9:0] dmem_addr,

    // Status
    output reg       halted,
    output reg [3:0] state
);

    // States
    localparam IDLE         = 4'd0;
    localparam INIT         = 4'd1;
    localparam FETCH        = 4'd2;
    localparam FETCH2       = 4'd3;
    localparam DECODE       = 4'd4;
    localparam EXECUTE      = 4'd5;
    localparam TENSOR_WAIT  = 4'd6;
    localparam WRITEBACK    = 4'd7;
    localparam MEM_RD       = 4'd8;
    localparam HALTED_ST    = 4'd9;

    // Opcodes
    localparam OP_ALU      = 5'h00;
    localparam OP_TENSOR   = 5'h01;
    localparam OP_LD       = 5'h02;
    localparam OP_ST       = 5'h03;
    localparam OP_BEQ      = 5'h04;
    localparam OP_BNE      = 5'h05;
    localparam OP_BLT      = 5'h06;
    localparam OP_BGE      = 5'h07;
    localparam OP_LUI      = 5'h08;
    localparam OP_ADDI     = 5'h09;
    localparam OP_HALT     = 5'h0A;
    localparam OP_NOP      = 5'h0B;
    localparam OP_MOVI     = 5'h0C;
    localparam OP_RELU_INT = 5'h0D;
    localparam OP_VBCAST  = 5'h0E;

    // Instruction register
    reg [31:0] IR;

    // Decode fields
    wire [4:0]  opcode = IR[31:27];
    wire [4:0]  rd     = IR[26:22];
    wire [4:0]  ra     = IR[21:17];
    wire [4:0]  rb     = IR[16:12];
    wire [4:0]  rc     = IR[11:7];
    wire [3:0]  func   = IR[6:3];
    wire [2:0]  mode   = IR[2:0];
    wire [16:0] imm17  = IR[16:0];
    wire [63:0] imm_sext = {{47{imm17[16]}}, imm17};

    // Branch target (sign-extended offset from imm17)
    wire [9:0] branch_target = pc + imm17[9:0];

    // Branch condition evaluation
    reg branch_taken;
    always @(*) begin
        case (opcode)
            OP_BEQ:  branch_taken = (cmp_b == cmp_a);
            OP_BNE:  branch_taken = (cmp_b != cmp_a);
            OP_BLT:  branch_taken = ($signed(cmp_b) < $signed(cmp_a));
            OP_BGE:  branch_taken = ($signed(cmp_b) >= $signed(cmp_a));
            default: branch_taken = 1'b0;
        endcase
    end

    // FSM
    always @(posedge clk) begin
        if (rst) begin
            state          <= IDLE;
            pc             <= 10'b0;
            IR             <= 32'b0;
            rf_we          <= 1'b0;
            rf_wr_addr     <= 5'b0;
            rf_rd_a        <= 5'b0;
            rf_rd_b        <= 5'b0;
            rf_rd_c        <= 5'b0;
            alu_func       <= 4'b0;
            tensor_start   <= 1'b0;
            tensor_op_mode <= 3'b0;
            tensor_relu_en <= 1'b0;
            dmem_we        <= 1'b0;
            dmem_addr      <= 10'b0;
            wb_sel         <= 3'b0;
            imm_out        <= 64'b0;
            halted         <= 1'b0;
        end
        else begin
            // Defaults each cycle
            rf_we        <= 1'b0;
            tensor_start <= 1'b0;
            dmem_we      <= 1'b0;

            case (state)

                IDLE: begin
                    if (run) state <= INIT;
                end

                INIT: begin
                    // Write thread_id to R31
                    rf_we      <= 1'b1;
                    rf_wr_addr <= 5'd31;
                    imm_out    <= {54'b0, thread_id};
                    wb_sel     <= 3'd3;
                    state      <= FETCH;
                end

                FETCH: begin
                    IR    <= instruction;
                    state <= FETCH2;
                end

                FETCH2: begin
                    state <= DECODE;
                end

                DECODE: begin
                    rf_rd_a <= ra;
                    rf_rd_c <= rc;

                    // For ST and branches, read Rd via port B
                    if (opcode == OP_ST || opcode == OP_BEQ ||
                        opcode == OP_BNE || opcode == OP_BLT ||
                        opcode == OP_BGE)
                        rf_rd_b <= rd;
                    else
                        rf_rd_b <= rb;

                    state <= EXECUTE;
                end

                EXECUTE: begin
                    case (opcode)

                        OP_ALU: begin
                            alu_func   <= func;
                            wb_sel     <= 3'd0;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_RELU_INT: begin
                            wb_sel     <= 3'd6;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_VBCAST: begin
                            tensor_op_mode <= mode;
                            wb_sel     <= 3'd7;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_TENSOR: begin
                            tensor_start   <= 1'b1;
                            tensor_op_mode <= mode;
                            tensor_relu_en <= func[0];
                            wb_sel         <= 3'd1;
                            rf_wr_addr     <= rd;
                            state          <= TENSOR_WAIT;
                        end

                        OP_LD: begin
                            dmem_addr  <= cmp_a[9:0] + imm_sext[9:0];
                            wb_sel     <= 3'd2;
                            rf_wr_addr <= rd;
                            state      <= MEM_RD;
                        end

                        OP_ST: begin
                            dmem_addr  <= cmp_a[9:0] + imm_sext[9:0];
                            dmem_we    <= 1'b1;
                            state      <= WRITEBACK;
                        end

                        OP_BEQ, OP_BNE, OP_BLT, OP_BGE: begin
                            if (branch_taken)
                                pc <= branch_target;
                            else
                                pc <= pc + 10'd1;
                            state <= FETCH;
                        end

                        OP_LUI: begin
                            imm_out    <= {imm17, 47'b0};
                            wb_sel     <= 3'd3;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_ADDI: begin
                            imm_out    <= cmp_a + imm_sext;
                            wb_sel     <= 3'd3;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_MOVI: begin
                            imm_out    <= imm_sext;
                            wb_sel     <= 3'd3;
                            rf_wr_addr <= rd;
                            state      <= WRITEBACK;
                        end

                        OP_HALT: begin
                            halted <= 1'b1;
                            state  <= HALTED_ST;
                        end

                        OP_NOP: begin
                            pc    <= pc + 10'd1;
                            state <= FETCH;
                        end

                        default: begin
                            pc    <= pc + 10'd1;
                            state <= FETCH;
                        end
                    endcase
                end

                TENSOR_WAIT: begin
                    if (tensor_done)
                        state <= WRITEBACK;
                end

                MEM_RD: begin
                    state <= WRITEBACK;
                end

                WRITEBACK: begin
                    if (opcode != OP_ST)
                        rf_we <= 1'b1;

                    pc    <= pc + 10'd1;
                    state <= FETCH;
                end

                HALTED_ST: begin
                    halted <= 1'b1;
                end

            endcase
        end
    end

endmodule
