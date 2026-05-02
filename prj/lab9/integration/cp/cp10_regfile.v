/* file: cp10_regfile.v
Description: CP10 coprocessor register file. Provides ARM CPU control over
   Raymond's SIMD GPU via MCR/MRC instructions. Stripped of DMA logic from
   Jeremy's original — pkt_proc handles all memory loading directly.
Author: Jeremy Cai (v1.0), Raymond (v2.0 modifications)
Date: Mar. 4, 2026
Version: 2.0
Revision history:
    - Mar. 4, 2026: v1.0 — Initial implementation with DMA + GPU control.
    - Mar. 11, 2026: v2.0 — Removed DMA (CR0-CR3, CR9) for pkt_proc-based
            memory loading. Retained GPU control (CR4-CR6) and utility (CR7-CR8).
*/

`ifndef CP10_REGFILE_V
`define CP10_REGFILE_V

//  CP10 Register Map (v2.0):
//  CR4  GPU_ENTRY_PC   — GPU entry PC (reserved for future use)
//  CR5  GPU_CTRL       — {reset, start} (bit[1]=reset active-high, bit[0]=start pulse)
//  CR6  GPU_STATUS     — {idle, active, done} (read-only)
//  CR7  THREAD_MASK    — active thread mask (reserved, default 4'b0001)
//  CR8  GPU_SCRATCH    — scratch register for CPU↔GPU parameter passing

module cp10_regfile (
    input wire clk,
    input wire rst_n,

    // Coprocessor interface from ARM CPU (EX2 stage)
    input wire cp_wen,          // MCR: write enable (1 cycle)
    input wire cp_ren,          // MRC: read enable (1 cycle)
    input wire [3:0] cp_reg,    // CRn: register select (0–15)
    input wire [31:0] cp_wdata, // write data from CPU Rd
    output reg [31:0] cp_rdata, // read data to CPU Rd

    // GPU interface (to/from gpu_top)
    output wire gpu_kernel_start,   // 1-cycle pulse to begin execution
    output wire gpu_reset,          // active-high reset to GPU
    input wire  gpu_kernel_done,    // level: GPU halted (sticky OK)
    input wire  gpu_active          // high while GPU is running
);

    // ================================================================
    // Register storage
    // ================================================================

    // GPU Kernel (CR4–CR6)
    reg [31:0] cr4_gpu_pc;      // CR4: GPU entry PC (reserved)
    reg [1:0]  cr5_gpu_ctrl;    // CR5: {reset, start}
    // CR6: GPU_STATUS — read-only, derived combinationally

    // Utility (CR7–CR8)
    reg [3:0]  cr7_thread_mask; // CR7: thread mask (reserved)
    reg [31:0] cr8_gpu_scratch; // CR8: scratch register

    // ================================================================
    // Status tracking — sticky done flag
    // ================================================================
    reg gpu_done_flag;

    // ================================================================
    // Write-trigger pulse generation
    // ================================================================
    wire wr_cr4 = cp_wen & (cp_reg == 4'd4);
    wire wr_cr5 = cp_wen & (cp_reg == 4'd5);
    wire wr_cr7 = cp_wen & (cp_reg == 4'd7);
    wire wr_cr8 = cp_wen & (cp_reg == 4'd8);

    reg gpu_start_r;

    // ================================================================
    // Register write logic
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cr4_gpu_pc     <= 32'd0;
            cr5_gpu_ctrl   <= 2'd0;
            cr7_thread_mask <= 4'b0001;  // default: single thread
            cr8_gpu_scratch <= 32'd0;
            gpu_done_flag  <= 1'b0;
            gpu_start_r    <= 1'b0;
        end else begin
            // Pulse auto-clear
            gpu_start_r <= 1'b0;

            // CR5[0] auto-clear
            if (cr5_gpu_ctrl[0])
                cr5_gpu_ctrl[0] <= 1'b0;

            // MCR writes
            if (wr_cr4) cr4_gpu_pc <= cp_wdata;

            if (wr_cr5) begin
                cr5_gpu_ctrl <= cp_wdata[1:0];
                if (cp_wdata[0]) begin
                    gpu_start_r   <= 1'b1;
                    gpu_done_flag <= 1'b0;  // clear done on new start
                end
            end

            if (wr_cr7) cr7_thread_mask <= cp_wdata[3:0];
            if (wr_cr8) cr8_gpu_scratch <= cp_wdata;

            // Sticky done flag capture
            if (gpu_kernel_done)
                gpu_done_flag <= 1'b1;
        end
    end

    // ================================================================
    // MRC read mux
    // ================================================================
    wire gpu_idle = ~gpu_active & gpu_done_flag;
    wire [31:0] cr6_gpu_status = {29'd0, gpu_idle, gpu_active, gpu_done_flag};

    always @(*) begin
        case (cp_reg)
            4'd4:    cp_rdata = cr4_gpu_pc;
            4'd5:    cp_rdata = {30'd0, cr5_gpu_ctrl};
            4'd6:    cp_rdata = cr6_gpu_status;
            4'd7:    cp_rdata = {28'd0, cr7_thread_mask};
            4'd8:    cp_rdata = cr8_gpu_scratch;
            default: cp_rdata = 32'd0;
        endcase
    end

    // ================================================================
    // Output assignments
    // ================================================================
    assign gpu_kernel_start = gpu_start_r;
    assign gpu_reset = cr5_gpu_ctrl[1];  // bit[1]=1 → reset active

endmodule

`endif // CP10_REGFILE_V
