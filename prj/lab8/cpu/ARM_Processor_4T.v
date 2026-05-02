`timescale 1ns / 1ps

module ARM_Processor_4T(
    input  [10:2] ADDR,
    input         CLK,
    input         CLR_ALL,
    input  [31:0] DIN,
    input         IM_CLR,
    input         IM_WE,

    // --- FIFO Access (Port A) ---
    output [7:0]  cpu_fifo_addr,
    output [63:0] cpu_fifo_wdata,
    output        cpu_fifo_we,
    input  [63:0] cpu_fifo_rdata,

    // --- Control Register Interface ---
    output        ctrl_mode_select,
    output        ctrl_send_packet,
    output        ctrl_gpu_rst,
    output        ctrl_gpu_run,
    input         ctrl_packet_ready,
    input         ctrl_gpu_halted,
    input  [7:0]  ctrl_head_ptr,
    input  [7:0]  ctrl_tail_ptr
);

    // --- Wire Declarations ---
    wire vdd;
    assign vdd = 1'b1;
    
    // Instruction Fetch (IF) Stage
    wire [10:2] PC;
    wire [31:0] IM_OUT;
    
    // IF/ID Pipeline Register Outputs
    wire [31:0] INS;
    wire [1:0]  ID_TID;
    
    // ID Stage Control & Data Wires
    wire        ID_ALUSrc;
    wire        ID_Branch;
    wire        ID_MemRead;
    wire        ID_MemtoReg;
    wire        ID_MemWrite;
    wire        ID_RegWrite;
    wire [63:0] R0_OUT;
    wire [63:0] R1_OUT;
    
    // ID/EX Pipeline Register Outputs
    wire [3:0]  EX_RegAddr;
    wire [3:0]  ALUAddr;
    wire [11:0] EX_Imm12;
    wire        EX_ALUSrc;
    wire        EX_BE;       // Branch enable signal from control
    wire [1:0]  EX_BType;    // Branch condition type
    wire        EX_MemRead;
    wire        EX_MemWrite;
    wire        EX_MemtoReg;
    wire        EX_RegWrite;
    wire [63:0] EX_R1;
    wire [63:0] EX_R2;
    wire [1:0]  EX_TID;
    
    // EX Stage Execution Wires
    wire [63:0] EX_Imm64;
    wire [63:0] ALUB;
    wire [63:0] EX_ALU_Res;
    wire        ALU_C, ALU_N, ALU_V, ALU_Z;
    wire        Flag_C, Flag_N, Flag_V, Flag_Z;
    wire        EX_BranchTaken; // Signal to PC logic
    
    // EX/MEM Pipeline Register Outputs
    wire [3:0]  M_RegAddr;
    wire [63:0] M_ALU;
    wire        M_BranchTaken;
    wire [1:0]  M_TID;
    wire        M_MemRead_MemStage;
    wire        M_MemWrite_MemStage;
    wire        M_MemtoReg_MemStage;
    wire        M_RegWrite_MemStage;
    wire [63:0] M_R2;
    
    // MEM Stage Memory Output
    wire [63:0] M_DM_OUT;
    wire [31:0] M_IM_OUT;
    wire [63:0] M_FINAL_OUT;

    // --- Address Decoding ---
    // 0x000-0x7FF: IM (M_ALU[11] == 0)
    // 0x800-0xBFF: DM (M_ALU[11] == 1, M_ALU[10] == 0)
    // 0xC00-0xFFF: FIFO (M_ALU[11] == 1, M_ALU[10] == 1)
    // 0x1000: CTRL (M_ALU[12] == 1)
    wire is_ctrl = (M_ALU[12] == 1'b1);
    wire is_dm   = (M_ALU[11] == 1'b1 && M_ALU[10] == 1'b0 && !is_ctrl);
    wire is_fifo = (M_ALU[11] == 1'b1 && M_ALU[10] == 1'b1 && !is_ctrl);

    // --- FIFO Port A Drives ---
    assign cpu_fifo_addr  = M_ALU[9:2];
    assign cpu_fifo_wdata = M_R2;
    assign cpu_fifo_we    = M_MemWrite_MemStage && is_fifo;

    // --- Control Register (0x1000) ---
    // Bit 0: packet_ready    (R)
    // Bit 1: mode_select     (RW)
    // Bit 2: send_packet     (W pulse)
    // Bit 3: gpu_run         (RW)
    // Bit 4: gpu_rst         (RW)
    // Bit 5: gpu_halted      (R)
    // Bits 6-7: head_ptr     (R) — read via separate LW to 0x1004 if needed
    reg [4:1] ctrl_reg;
    reg       send_packet_reg;

    always @(posedge CLK or posedge CLR_ALL) begin
        if (CLR_ALL) begin
            ctrl_reg        <= 4'b0;
            send_packet_reg <= 1'b0;
        end else begin
            send_packet_reg <= 1'b0; // auto-clear pulse
            if (is_ctrl && M_MemWrite_MemStage) begin
                ctrl_reg        <= M_R2[4:1];
                send_packet_reg <= M_R2[2];
            end
        end
    end

    assign ctrl_mode_select = ctrl_reg[1];
    assign ctrl_send_packet = send_packet_reg;
    assign ctrl_gpu_run     = ctrl_reg[3];
    assign ctrl_gpu_rst     = ctrl_reg[4];

    wire [63:0] M_CTRL_OUT = {32'b0,
        ctrl_tail_ptr,          // bits [21:14]
        ctrl_head_ptr,          // bits [13:6]
        ctrl_gpu_halted,        // bit 5
        ctrl_reg[4],            // bit 4: gpu_rst
        ctrl_reg[3],            // bit 3: gpu_run
        send_packet_reg,        // bit 2: send_packet
        ctrl_reg[1],            // bit 1: mode_select
        ctrl_packet_ready       // bit 0: packet_ready
    };

    // MEM Stage Final Output Selection
    assign M_FINAL_OUT = is_ctrl ? M_CTRL_OUT :
                         is_fifo ? cpu_fifo_rdata :
                         is_dm   ? M_DM_OUT :
                         {32'b0, M_IM_OUT};
    
    // MEM/WB Pipeline Register Outputs
    wire [3:0]  WB_ADDR;
    wire [63:0] WB_ALU;
    wire [63:0] WB_OUT;
    wire [1:0]  WB_TID;
    wire        WB_MemtoReg;
    wire        WB_W;
    
    // WB Stage Final Data
    wire [63:0] WB_Data;

    // --- Pipeline Implementation ---

    // 1. Instruction Memory & PC Logic (IF Stage)
    I_Mem_Dual Inst_Mem (
        .addra(IM_WE ? ADDR : M_ALU[10:2]), // Use [10:2] to access 512 words of IM via byte addresses
        .addrb(PC),
        .clka(CLK),
        .clkb(CLK),
        .dina(DIN),
        .douta(M_IM_OUT),
        .doutb(IM_OUT),
        .wea(IM_WE)
    );

    Counter_2b Thread_Counter (
        .CE(vdd),
        .CLK(CLK),
        .CLR(IM_CLR),
        .T_ID(PC[10:9])
    );

    PCL_7b_4 PC_Logic (
        .CLK(CLK),
        .CLR(IM_CLR),
        .D(M_ALU[8:2]),  // Translate byte-aligned branch target to word-aligned PC
        .ID(PC[10:9]),
        .L(M_BranchTaken),
        .Q(PC[8:2])
    );

    // 2. IF/ID Pipeline Register
    IF_ID_Reg IF_ID_PR (
        .CE(vdd),
        .CLK(CLK),
        .CLR(CLR_ALL),
        .IF_Ins(IM_OUT),
        .IF_TID(PC[10:9]),
        .ID_Ins(INS),
        .ID_TID(ID_TID)
    );

    // 3. Instruction Decode (ID) Stage
    Control_Unit Control (
        .OP(INS[31:28]),
        .ALUSrc(ID_ALUSrc),
        .Branch(ID_Branch),
        .MemRead(ID_MemRead),
        .MemtoReg(ID_MemtoReg),
        .MemWrite(ID_MemWrite),
        .RegWrite(ID_RegWrite)
    );

    Register_File_BRAM Reg_File (
        .clk(CLK),
        .R_ID(ID_TID),
        .r0addr(INS[23:20]),
        .r1addr(INS[19:16]),
        .waddr(WB_ADDR),
        .wdata(WB_Data),
        .wena(WB_W),
        .W_ID(WB_TID),
        .r0data(R0_OUT),
        .r1data(R1_OUT)
    );

    // 4. ID/EX Pipeline Register
    ID_EX_Reg ID_EX_PR (
        .CE(vdd),
        .CLK(CLK),
        .CLR(CLR_ALL),
        .ID_Addr(INS[15:12]),
        .ID_ALUC(INS[27:24]),
        .ID_ALUD(INS[11:0]),
        .ID_ALUSrc(ID_ALUSrc),
        .ID_B(ID_Branch),
        .ID_BT(INS[19:18]),
        .ID_MemR(ID_MemRead),
        .ID_MemW(ID_MemWrite),
        .ID_M2Reg(ID_MemtoReg),
        .ID_RegW(ID_RegWrite),
        .ID_R1(R0_OUT),
        .ID_R2(R1_OUT),
        .ID_TID(ID_TID),
        .EX_Addr(EX_RegAddr),
        .EX_ALUC(ALUAddr),
        .EX_ALUD(EX_Imm12),
        .EX_ALUSrc(EX_ALUSrc),
        .EX_B(EX_BE),
        .EX_BT(EX_BType),
        .EX_MemR(EX_MemRead),
        .EX_MemW(EX_MemWrite),
        .EX_M2Reg(EX_MemtoReg),
        .EX_RegW(EX_RegWrite),
        .EX_R1(EX_R1),
        .EX_R2(EX_R2),
        .EX_TID(EX_TID)
    );

    // 5. Execution (EX) Stage
    Sign_Extend_12to64 Imm_Ext (
        .ext_in(EX_Imm12),
        .ext_out(EX_Imm64)
    );

    Mux2_1_64b ALU_Src_Mux (
        .D0(EX_R2),
        .D1(EX_Imm64),
        .S(EX_ALUSrc),
        .O(ALUB)
    );

    ALU Main_ALU (
        .A(EX_R1),
        .aluctrl(ALUAddr),
        .B(ALUB),
        .ALU_Result(EX_ALU_Res),
        .C(ALU_C),
        .N(ALU_N),
        .V(ALU_V),
        .Z(ALU_Z)
    );

    Flag_Reg_4 Flags (
        .CLK(CLK),
        .CLR(CLR_ALL),
        .C_in(ALU_C),
        .ID(EX_TID),
        .N_in(ALU_N),
        .V_in(ALU_V),
        .Z_in(ALU_Z),
        .C_out(Flag_C),
        .N_out(Flag_N),
        .V_out(Flag_V),
        .Z_out(Flag_Z)
    );

    Condition_Unit Branch_Unit (
        .br_en(EX_BE),
        .BType(EX_BType),
        .C(Flag_C),
        .N(Flag_N),
        .V(Flag_V),
        .Z(Flag_Z),
        .branch_taken(EX_BranchTaken)
    );

    // 6. EX/MEM Pipeline Register
    EX_M_Reg EX_MEM_PR (
        .CE(vdd),
        .CLK(CLK),
        .CLR(CLR_ALL),
        .EX_Addr(EX_RegAddr),
        .EX_ALU(EX_ALU_Res),
        .EX_B(EX_BranchTaken),
        .EX_ID(EX_TID),
        .EX_MemR(EX_MemRead),
        .EX_MemW(EX_MemWrite),
        .EX_M2Reg(EX_MemtoReg),
        .EX_RegW(EX_RegWrite),
        .EX_R2(EX_R2),
        .M_Addr(M_RegAddr),
        .M_ALU(M_ALU),
        .M_B(M_BranchTaken),
        .M_ID(M_TID),
        .M_MemR(M_MemRead_MemStage),
        .M_MemW(M_MemWrite_MemStage),
        .M_M2Reg(M_MemtoReg_MemStage),
        .M_RegW(M_RegWrite_MemStage),
        .M_R2(M_R2)
    );

    // 7. Memory (MEM) Stage
    D_Mem Data_Mem (
        .addra(M_ALU[9:2]),
        .addrb(M_ALU[9:2]),
        .clka(CLK),
        .clkb(CLK),
        .dina(M_R2),
        .enb(M_MemRead_MemStage),
        .wea(M_MemWrite_MemStage),
        .doutb(M_DM_OUT)
    );

    // 8. MEM/WB Pipeline Register
    M_WB_Reg MEM_WB_PR (
        .CE(vdd),
        .CLK(CLK),
        .CLR(CLR_ALL),
        .M_Addr(M_RegAddr),
        .M_ALU(M_ALU),
        .M_Data(M_FINAL_OUT),
        .M_ID(M_TID),
        .M_M2Reg(M_MemtoReg_MemStage),
        .M_RegW(M_RegWrite_MemStage),
        .WB_Addr(WB_ADDR),
        .WB_ALU(WB_ALU),
        .WB_Data(WB_OUT),
        .WB_ID(WB_TID),
        .WB_M2Reg(WB_MemtoReg),
        .WB_RegW(WB_W)
    );

    // 9. Write-Back (WB) Stage
    Mux2_1_64b WB_Data_Mux (
        .D0(WB_ALU),
        .D1(WB_OUT),
        .S(WB_MemtoReg),
        .O(WB_Data)
    );

endmodule
