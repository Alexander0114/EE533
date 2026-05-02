/* file: tensor_core.v
 Description: 4x4 BF16 tensor core for WMMA (Warp Matrix Multiply-Accumulate).
   Computes D = A x B + C where A, B, C, D are 4x4 BF16 matrices stored in
   4 consecutive 64-bit registers each (one row per register). Uses 16
   bf16_lane instances (16 MULT18X18S) for full parallel computation.
   FSM: IDLE -> GATHER (3 cyc) -> COMPUTE (16 cyc) -> SCATTER (4 cyc) -> DONE.
 Author: Raymond
 Date: Mar. 10, 2026
 Version: 1.0
 Revision History:
    - 1.0: Initial implementation. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps
`ifndef TENSOR_CORE_V
`define TENSOR_CORE_V
module tensor_core (
    input         clk,
    input         rst,
    input         start,       // pulse to begin WMMA

    // Base register addresses for 4x4 matrices (each matrix = 4 consecutive regs)
    input  [4:0]  base_ra,     // A matrix base
    input  [4:0]  base_rb,     // B matrix base
    input  [4:0]  base_rc,     // C matrix base (accumulator init)
    input  [4:0]  base_rd,     // D matrix base (result destination)

    // Register file read ports (directly drives RF address inputs)
    output reg [4:0]  rf_rd_a,
    output reg [4:0]  rf_rd_b,
    output reg [4:0]  rf_rd_c,
    output reg [4:0]  rf_rd_d,

    // Register file read data (directly from RF outputs)
    input  [63:0] rf_data_a,
    input  [63:0] rf_data_b,
    input  [63:0] rf_data_c,
    input  [63:0] rf_data_d,

    // Register file write port
    output reg [4:0]  rf_wr_addr,
    output reg        rf_we,
    output reg [63:0] rf_w_data,

    // Control
    output reg        rf_override, // 1 = tensor core controls RF ports
    output reg        done         // pulse when complete
);

    // ================================================================
    // FSM States
    // ================================================================
    localparam TC_IDLE      = 3'd0;
    localparam TC_GATHER_A  = 3'd1;  // set A addrs, latch nothing
    localparam TC_GATHER_B  = 3'd2;  // latch A, set B addrs
    localparam TC_GATHER_C  = 3'd3;  // latch B, set C addrs
    localparam TC_COMPUTE   = 3'd4;  // latch C, run 4x4 matmul
    localparam TC_SCATTER   = 3'd5;  // write results back to RF
    localparam TC_DONE      = 3'd6;

    reg [2:0] state;

    // ================================================================
    // Matrix Holding Registers (4 rows x 64 bits each)
    // Row format: [63:48]=col3, [47:32]=col2, [31:16]=col1, [15:0]=col0
    // ================================================================
    reg [63:0] a_hold [0:3];
    reg [63:0] b_hold [0:3];
    reg [63:0] c_hold [0:3];

    // Saved base addresses
    reg [4:0] rd_base;

    // Compute counters
    reg [1:0] k_cnt;      // which A column / B row (0..3)
    reg [1:0] wait_cnt;   // pipeline wait (0..3)
    reg       first_k;    // indicates k=0 (use C init, not feedback)

    // Scatter counter
    reg [1:0] scatter_cnt;

    // ================================================================
    // 16 bf16_lane PE instances: PE[i][j] computes D[i][j]
    // D[i][j] = sum_k(A[i][k] * B[k][j]) + C[i][j]
    // ================================================================
    wire feed_en = (state == TC_COMPUTE) && (wait_cnt == 2'd0);

    // PE input/output wires — accessed via generate hierarchy
    // PE source muxing is done inside the generate block

    genvar gi, gj;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : ROW
            for (gj = 0; gj < 4; gj = gj + 1) begin : COL
                // Select A[i][k] based on k_cnt
                reg [15:0] src_a_mux;
                always @(*) begin
                    case (k_cnt)
                        2'd0: src_a_mux = a_hold[gi][15:0];
                        2'd1: src_a_mux = a_hold[gi][31:16];
                        2'd2: src_a_mux = a_hold[gi][47:32];
                        2'd3: src_a_mux = a_hold[gi][63:48];
                    endcase
                end

                // Select B[k][j] based on k_cnt
                wire [15:0] src_b_mux = b_hold[k_cnt][gj*16 +: 16];

                // C[i][j] initial value
                wire [15:0] c_init = c_hold[gi][gj*16 +: 16];

                // PE output (holds between valid feeds due to gated result)
                wire [15:0] pe_out;

                // src_c: C init for first feed, feedback for subsequent
                wire [15:0] src_c_mux = first_k ? c_init : pe_out;

                bf16_lane #(.PIPE_DEPTH(4)) pe (
                    .clk(clk),
                    .rst(rst),
                    .en(feed_en),
                    .src_a(src_a_mux),
                    .src_b(src_b_mux),
                    .src_c(src_c_mux),
                    .op_mode(3'd2),  // FMA: a*b + c
                    .relu_en(1'b0),
                    .result(pe_out),
                    .output_ready()
                );
            end
        end
    endgenerate

    // ================================================================
    // Assemble result rows from PE outputs for scatter
    // ================================================================
    wire [63:0] d_row [0:3];
    assign d_row[0] = {ROW[0].COL[3].pe_out, ROW[0].COL[2].pe_out,
                       ROW[0].COL[1].pe_out, ROW[0].COL[0].pe_out};
    assign d_row[1] = {ROW[1].COL[3].pe_out, ROW[1].COL[2].pe_out,
                       ROW[1].COL[1].pe_out, ROW[1].COL[0].pe_out};
    assign d_row[2] = {ROW[2].COL[3].pe_out, ROW[2].COL[2].pe_out,
                       ROW[2].COL[1].pe_out, ROW[2].COL[0].pe_out};
    assign d_row[3] = {ROW[3].COL[3].pe_out, ROW[3].COL[2].pe_out,
                       ROW[3].COL[1].pe_out, ROW[3].COL[0].pe_out};

    // ================================================================
    // FSM
    // ================================================================
    always @(posedge clk) begin
        if (rst) begin
            state       <= TC_IDLE;
            rf_override <= 1'b0;
            rf_we       <= 1'b0;
            done        <= 1'b0;
            k_cnt       <= 2'd0;
            wait_cnt    <= 2'd0;
            first_k     <= 1'b1;
            scatter_cnt <= 2'd0;
            rd_base     <= 5'd0;
            rf_rd_a     <= 5'd0;
            rf_rd_b     <= 5'd0;
            rf_rd_c     <= 5'd0;
            rf_rd_d     <= 5'd0;
            rf_wr_addr  <= 5'd0;
            rf_w_data   <= 64'd0;
        end
        else begin
            // Defaults
            rf_we <= 1'b0;
            done  <= 1'b0;

            case (state)

                TC_IDLE: begin
                    if (start) begin
                        // Set RF addresses to read A matrix (4 rows)
                        rf_rd_a <= base_ra;
                        rf_rd_b <= base_ra + 5'd1;
                        rf_rd_c <= base_ra + 5'd2;
                        rf_rd_d <= base_ra + 5'd3;
                        rf_override <= 1'b1;
                        rd_base     <= base_rd;
                        state       <= TC_GATHER_A;
                    end
                end

                TC_GATHER_A: begin
                    // Latch A matrix from RF (combinational read ready)
                    a_hold[0] <= rf_data_a;
                    a_hold[1] <= rf_data_b;
                    a_hold[2] <= rf_data_c;
                    a_hold[3] <= rf_data_d;
                    // Set RF addresses for B matrix
                    rf_rd_a <= base_rb;
                    rf_rd_b <= base_rb + 5'd1;
                    rf_rd_c <= base_rb + 5'd2;
                    rf_rd_d <= base_rb + 5'd3;
                    state   <= TC_GATHER_B;
                end

                TC_GATHER_B: begin
                    // Latch B matrix
                    b_hold[0] <= rf_data_a;
                    b_hold[1] <= rf_data_b;
                    b_hold[2] <= rf_data_c;
                    b_hold[3] <= rf_data_d;
                    // Set RF addresses for C matrix
                    rf_rd_a <= base_rc;
                    rf_rd_b <= base_rc + 5'd1;
                    rf_rd_c <= base_rc + 5'd2;
                    rf_rd_d <= base_rc + 5'd3;
                    state   <= TC_GATHER_C;
                end

                TC_GATHER_C: begin
                    // Latch C matrix
                    c_hold[0] <= rf_data_a;
                    c_hold[1] <= rf_data_b;
                    c_hold[2] <= rf_data_c;
                    c_hold[3] <= rf_data_d;
                    // Release RF override (compute phase doesn't need RF)
                    rf_override <= 1'b0;
                    // Initialize compute
                    k_cnt    <= 2'd0;
                    wait_cnt <= 2'd0;
                    first_k  <= 1'b1;
                    state    <= TC_COMPUTE;
                end

                TC_COMPUTE: begin
                    // feed_en is combinational: (state==TC_COMPUTE && wait_cnt==0)
                    // Each feed triggers all 16 PEs simultaneously
                    if (wait_cnt < 2'd3) begin
                        wait_cnt <= wait_cnt + 2'd1;
                    end
                    else begin
                        // Pipeline result ready. Advance to next k or finish.
                        first_k <= 1'b0;
                        if (k_cnt < 2'd3) begin
                            k_cnt    <= k_cnt + 2'd1;
                            wait_cnt <= 2'd0;
                        end
                        else begin
                            // All 4 k's done. PE result registers update
                            // at this same posedge, so we must wait 1 cycle
                            // before reading d_row (which uses pe_out).
                            scatter_cnt <= 2'd0;
                            rf_override <= 1'b1;
                            state       <= TC_SCATTER;
                        end
                    end
                end

                TC_SCATTER: begin
                    // Write d_row[scatter_cnt] to rd_base + scatter_cnt
                    rf_wr_addr  <= rd_base + {3'd0, scatter_cnt};
                    rf_w_data   <= d_row[scatter_cnt];
                    rf_we       <= 1'b1;
                    if (scatter_cnt < 2'd3) begin
                        scatter_cnt <= scatter_cnt + 2'd1;
                    end
                    else begin
                        state <= TC_DONE;
                    end
                end

                TC_DONE: begin
                    rf_override <= 1'b0;
                    done        <= 1'b1;
                    state       <= TC_IDLE;
                end

            endcase
        end
    end

endmodule
`endif // TENSOR_CORE_V
