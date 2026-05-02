/* file: branch_tb.v
 Description: Testbench for GPU branch instructions. Verifies BNE loop with
   MOVI, ADDI, ST, and HALT. Checks R1 decrements to 0, R2 increments to 4,
   and result is stored to dmem[0].
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps

module branch_tb;
    reg         clk;
    reg         rst;
    reg         run;
    reg  [9:0]  thread_id;

    wire        halted;
    wire [9:0]  debug_pc;
    wire [31:0] debug_ir;
    wire [3:0]  debug_state;

    // DMEM: simple 1024x64b behavioral model
    reg  [63:0] dmem [0:1023];
    wire [9:0]  gpu_dmem_addr;
    wire [63:0] gpu_dmem_wdata;
    wire        gpu_dmem_we;
    wire [63:0] gpu_dmem_rdata;

    assign gpu_dmem_rdata = dmem[gpu_dmem_addr];

    always @(posedge clk) begin
        if (gpu_dmem_we)
            dmem[gpu_dmem_addr] <= gpu_dmem_wdata;
    end

    gpu_top uut (
        .clk(clk), .rst(rst), .run(run),
        .thread_id(thread_id),
        .halted(halted),
        .debug_pc(debug_pc),
        .debug_ir(debug_ir),
        .debug_state(debug_state),
        .ext_imem_addr(10'd0),
        .ext_imem_data(32'd0),
        .ext_imem_we(1'b0),
        .gpu_dmem_addr(gpu_dmem_addr),
        .gpu_dmem_wdata(gpu_dmem_wdata),
        .gpu_dmem_we(gpu_dmem_we),
        .gpu_dmem_rdata(gpu_dmem_rdata)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Opcodes
    localparam [4:0] OP_MOVI = 5'h0C;
    localparam [4:0] OP_ADDI = 5'h09;
    localparam [4:0] OP_BNE  = 5'h05;
    localparam [4:0] OP_BEQ  = 5'h04;
    localparam [4:0] OP_ST   = 5'h03;
    localparam [4:0] OP_HALT = 5'h0A;
    localparam [4:0] OP_NOP  = 5'h0B;

    // Encode helpers
    // MOVI rd, imm17:  {OP_MOVI, rd, 5'b0, imm17[16:0]}
    // ADDI rd, ra, imm17: {OP_ADDI, rd, ra, imm17[16:0]}
    // BNE rd, ra, imm17:  {OP_BNE, rd, ra, imm17[16:0]}
    //   compares: rf[rd] != rf[ra] ? branch to pc + imm17[9:0]
    // ST rd, ra, imm17: store rf[rd] to dmem[rf[ra] + imm_sext]
    //   wait: actually control_unit stores rf_b (port B data) for ST
    //   In DECODE for ST: rf_rd_b <= rd; rf_rd_a <= ra
    //   In EXECUTE for ST: dmem_addr = cmp_a[9:0] + imm_sext[9:0]
    //   gpu_top: assign gpu_dmem_wdata = rf_b
    //   So ST stores rf[rd] to dmem[rf[ra] + imm]

    // Test program: simple loop
    // R1 = 4         ; loop count
    // R2 = 0         ; accumulator
    // R0 = 0         ; zero (hardwired R0 = 0)
    // loop (addr 3):
    //   ADDI R2, R2, 1   ; R2++
    //   ADDI R1, R1, -1  ; R1--   (imm17 = -1 = 17'h1FFFF)
    //   BNE R1, R0, -3   ; if R1 != 0, goto loop (pc + (-3))
    // ST R2, R0, 0       ; dmem[0] = R2 (should be 4)
    // HALT

    integer i;

    initial begin
        $dumpfile("branch_tb.vcd");
        $dumpvars(0, branch_tb);

        // Init DMEM
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 64'h0;

        // Load GPU program into IMEM via hierarchical access
        uut.imem_inst.mem[0]  = {OP_MOVI, 5'd1, 5'd0, 17'd4};         // MOVI R1, 4
        uut.imem_inst.mem[1]  = {OP_MOVI, 5'd2, 5'd0, 17'd0};         // MOVI R2, 0
        uut.imem_inst.mem[2]  = {OP_NOP,  5'd0, 5'd0, 17'd0};         // NOP (padding)
        uut.imem_inst.mem[3]  = {OP_ADDI, 5'd2, 5'd2, 17'd1};         // ADDI R2, R2, 1
        uut.imem_inst.mem[4]  = {OP_ADDI, 5'd1, 5'd1, 17'h1FFFF};     // ADDI R1, R1, -1
        uut.imem_inst.mem[5]  = {OP_BNE,  5'd1, 5'd0, 17'h1FFFE};     // BNE R1, R0, -2 (pc+(-2)=5-2=3=loop start)
        uut.imem_inst.mem[6]  = {OP_ST,   5'd2, 5'd0, 17'd0};         // ST R2, R0, 0
        uut.imem_inst.mem[7]  = {OP_HALT, 5'd0, 5'd0, 17'd0};         // HALT

        // Reset
        rst = 1; run = 0; thread_id = 10'd0;
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Start
        run = 1;
        @(posedge clk);
        run = 0;

        // Wait for halt
        begin : wait_halt
            integer timeout;
            timeout = 0;
            while (!halted && timeout < 500) begin
                @(posedge clk);
                timeout = timeout + 1;
                $display("[Cycle %3d] PC=%3d State=%1d IR=%08h R1=%h R2=%h",
                    timeout, debug_pc, debug_state, debug_ir,
                    uut.rf_inst.rf[1], uut.rf_inst.rf[2]);
            end
            if (!halted)
                $display("[TIMEOUT] GPU did not halt within 500 cycles");
        end

        repeat(2) @(posedge clk);

        // Check result
        $display("\n=== Results ===");
        $display("R1 = %0d (expect 0)", uut.rf_inst.rf[1]);
        $display("R2 = %0d (expect 4)", uut.rf_inst.rf[2]);
        $display("dmem[0] = 0x%016h (expect 0x0000000000000004)", dmem[0]);

        if (uut.rf_inst.rf[2] == 64'd4 && dmem[0] == 64'd4)
            $display("[PASS] Branch loop works correctly");
        else
            $display("[FAIL] Branch loop broken");

        $finish;
    end
endmodule
