/* file: bf16_lane.v
 Description: BF16 floating-point lane with pipelined FMA (fused multiply-add).
   Supports ADD, SUB, MUL, and FMA (a*b + c) operations. Uses MULT18X18S
   primitive for the multiply stage. 4-stage pipeline with round-to-nearest-even.
 Author: Raymond
 Date: Feb. 23, 2026
 Version: 1.3
 Revision History:
    - 1.0: Initial implementation with 8-bit internal mantissa and truncation
            rounding. (Feb. 23, 2026)
    - 1.1: Fixed BF16 accumulation precision bug — widened internal mantissa
            from 8 to 16 bits (8 original + 8 guard bits), multiply normalization
            now keeps 15 fraction bits, alignment threshold raised from 8 to 16,
            acc_sum widened from 10 to 18 bits, replaced truncation with
            round-to-nearest-even using guard/round/sticky bits. Fixes
            accumulator getting stuck when exp_diff >= 8. (Mar. 10, 2026)
    - 1.2: Added BF16 SUB (op_mode=3): a - b via sign-flip of b through the
            add path (a * 1.0 + (-b)). (Mar. 10, 2026)
    - 1.3: Gated result register update by valid_pipe[PIPE_DEPTH-2] so result
            holds its value between valid feeds. Required for tensor core
            accumulator feedback. (Mar. 10, 2026)
 */

`timescale 1ns / 1ps
`ifndef BF16_LANE_V
`define BF16_LANE_V
module bf16_lane #(
	 parameter PIPE_DEPTH = 4
)(
    input clk,
    input rst,
    input en,

	 // BF16: 1-bit sign, 8-bit exponent, 7-bit fraction
    input [15:0] src_a,
    input [15:0] src_b,
    input [15:0] src_c,

	 // 0: add, 1: mul, 2: FMA (a*b + c), 3: sub (a - b)
    input [2:0] op_mode,
	 // activate relu
	 input relu_en,

	 // output
    output reg [15:0] result,
    output output_ready
    );

	 // ================== INPUT MUX ==================
	 wire [15:0] mul_in_b = (op_mode == 3'd0 || op_mode == 3'd3) ? 16'h3F80 : src_b;
	 wire [15:0] neg_b    = {~src_b[15], src_b[14:0]};
	 wire [15:0] acc_in   = (op_mode == 3'd0) ? src_b     :
	                        (op_mode == 3'd3) ? neg_b     :
	                        (op_mode == 3'd1) ? 16'h0000  : src_c;

	 // ================== BF16 FIELD EXTRACTION ==================
	 wire        sign_a = src_a[15];
	 wire [7:0]  exp_a  = src_a[14:7];
	 wire [6:0]  frac_a = src_a[6:0];
	 wire [7:0]  mant_a = (exp_a != 8'h00) ? {1'b1, frac_a} : 8'h00;

	 wire        sign_b = mul_in_b[15];
	 wire [7:0]  exp_b  = mul_in_b[14:7];
	 wire [6:0]  frac_b = mul_in_b[6:0];
	 wire [7:0]  mant_b = (exp_b != 8'h00) ? {1'b1, frac_b} : 8'h00;

	 wire mul_zero = (exp_a == 8'h00) || (exp_b == 8'h00);

	 // ================== MULTIPLY (MULT18X18S, 1-cycle latency) ==================
	 wire [35:0] product_raw;

	 MULT18X18S bf16_mul_inst (
      .P(product_raw),
      .A({10'b0, mant_a}),
      .B({10'b0, mant_b}),
      .C(clk),
      .CE(1'b1),
      .R(rst)
    );

	 // ================================================================
	 // STAGE 1: Pipeline control signals and accumulate input
	 //          (matches MULT18X18S 1-cycle latency)
	 // ================================================================
	 reg        sign_mul_s1;
	 reg        relu_en_s1;
	 reg        mul_zero_s1;
	 reg [8:0]  exp_sum_s1;
	 reg [15:0] acc_s1;

    always @(posedge clk) begin
	     if (rst) begin
			sign_mul_s1 <= 1'b0;
            relu_en_s1  <= 1'b0;
			mul_zero_s1 <= 1'b0;
            exp_sum_s1  <= 9'b0;
			acc_s1      <= 16'b0;
		  end
        else begin
		    sign_mul_s1 <= sign_a ^ sign_b;
            relu_en_s1  <= relu_en;
			mul_zero_s1 <= mul_zero;
            exp_sum_s1  <= exp_a + exp_b - 8'd127;
			acc_s1      <= acc_in;
		  end
	 end

	 // ================================================================
	 // STAGE 2: Normalize product; decompose + compare for accumulate
	 //          Internal mantissa widened to 16 bits (1.15 format) for
	 //          precision: 8 original bits + 8 guard bits.
	 // ================================================================

	 // --- Normalize multiply result ---
	 // product_raw[15:0] is 8x8 = 16-bit product in 2.14 format
	 // Extract 15 fraction bits (full precision from the multiply)
	 wire [7:0]  mul_exp  = product_raw[15] ? (exp_sum_s1[7:0] + 8'd1)
	                                        : exp_sum_s1[7:0];
	 wire [14:0] mul_frac = product_raw[15] ? product_raw[14:0]
	                                        : {product_raw[13:0], 1'b0};

	 wire        p_sign = mul_zero_s1 ? 1'b0        : sign_mul_s1;
	 wire [7:0]  p_exp  = mul_zero_s1 ? 8'h00       : mul_exp;
	 wire [15:0] p_mant = mul_zero_s1 ? 16'h0000    : {1'b1, mul_frac};

	 // --- Decompose accumulate operand (widen BF16 to 16-bit mantissa) ---
	 wire        c_sign = acc_s1[15];
	 wire [7:0]  c_exp  = acc_s1[14:7];
	 wire [15:0] c_mant = (c_exp != 8'h00) ? {1'b1, acc_s1[6:0], 8'b0} : 16'h0000;

	 // --- Magnitude comparison (16-bit mantissa) ---
	 wire p_gte_c = (p_exp > c_exp) || ((p_exp == c_exp) && (p_mant >= c_mant));

	 wire [7:0]  s2_big_exp  = p_gte_c ? p_exp  : c_exp;
	 wire [15:0] s2_big_mant = p_gte_c ? p_mant : c_mant;
	 wire        s2_big_sign = p_gte_c ? p_sign : c_sign;
	 wire [15:0] s2_sml_mant = p_gte_c ? c_mant : p_mant;
	 wire [7:0]  s2_exp_diff = p_gte_c ? (p_exp - c_exp) : (c_exp - p_exp);
	 wire        s2_eff_sub  = p_sign ^ c_sign;

	 // --- Stage 2 registers ---
	 reg [7:0]  big_exp_s2;
	 reg [15:0] big_mant_s2;
	 reg        big_sign_s2;
	 reg [15:0] sml_mant_s2;
	 reg [7:0]  exp_diff_s2;
	 reg        eff_sub_s2;
	 reg        mul_zero_s2;
	 reg        relu_en_s2;
	 reg [15:0] acc_s2;

	 always @(posedge clk) begin
	     if (rst) begin
	         big_exp_s2  <= 8'b0;
	         big_mant_s2 <= 16'b0;
	         big_sign_s2 <= 1'b0;
	         sml_mant_s2 <= 16'b0;
	         exp_diff_s2 <= 8'b0;
	         eff_sub_s2  <= 1'b0;
	         mul_zero_s2 <= 1'b0;
	         relu_en_s2  <= 1'b0;
	         acc_s2      <= 16'b0;
	     end
	     else begin
	         big_exp_s2  <= s2_big_exp;
	         big_mant_s2 <= s2_big_mant;
	         big_sign_s2 <= s2_big_sign;
	         sml_mant_s2 <= s2_sml_mant;
	         exp_diff_s2 <= s2_exp_diff;
	         eff_sub_s2  <= s2_eff_sub;
	         mul_zero_s2 <= mul_zero_s1;
	         relu_en_s2  <= relu_en_s1;
	         acc_s2      <= acc_s1;
	     end
	 end

	 // ================================================================
	 // STAGE 3: Alignment shift + mantissa add/sub (16-bit wide)
	 // ================================================================
	 wire [15:0] aligned = (exp_diff_s2 >= 16) ? 16'b0
	                                           : (sml_mant_s2 >> exp_diff_s2);

	 wire [17:0] acc_sum = eff_sub_s2 ? ({2'b0, big_mant_s2} - {2'b0, aligned})
	                                  : ({2'b0, big_mant_s2} + {2'b0, aligned});

	 // --- Stage 3 registers ---
	 reg [17:0] acc_sum_s3;
	 reg [7:0]  big_exp_s3;
	 reg        big_sign_s3;
	 reg        mul_zero_s3;
	 reg        relu_en_s3;
	 reg [15:0] acc_s3;

	 always @(posedge clk) begin
	     if (rst) begin
	         acc_sum_s3  <= 18'b0;
	         big_exp_s3  <= 8'b0;
	         big_sign_s3 <= 1'b0;
	         mul_zero_s3 <= 1'b0;
	         relu_en_s3  <= 1'b0;
	         acc_s3      <= 16'b0;
	     end
	     else begin
	         acc_sum_s3  <= acc_sum;
	         big_exp_s3  <= big_exp_s2;
	         big_sign_s3 <= big_sign_s2;
	         mul_zero_s3 <= mul_zero_s2;
	         relu_en_s3  <= relu_en_s2;
	         acc_s3      <= acc_s2;
	     end
	 end

	 // ================================================================
	 // STAGE 4: Normalization with round-to-nearest-even + ReLU
	 //
	 // acc_sum_s3 is 18 bits. Leading 1 can be at bit 16 (carry) down
	 // to bit 0. For each position, extract 7 fraction bits + GRS
	 // (guard, round, sticky) for rounding.
	 // ================================================================
	 reg [7:0]  norm_exp;
	 reg [6:0]  norm_frac;
	 reg        norm_guard;
	 reg        norm_round;
	 reg        norm_sticky;
	 reg        norm_zero;

	 always @(*) begin
	     norm_exp    = 8'b0;
	     norm_frac   = 7'b0;
	     norm_guard  = 1'b0;
	     norm_round  = 1'b0;
	     norm_sticky = 1'b0;
	     norm_zero   = 1'b0;

	     if (acc_sum_s3[16]) begin
	         // Carry: leading 1 at bit 16, exp + 1 relative to widened format
	         // Widened format has hidden bit at bit 15, so carry means exp + 1
	         // but our base_exp already accounts for the hidden bit at bit 15.
	         // Carry at bit 16 = value is 2x normal, so exp + 1.
	         norm_exp    = big_exp_s3 + 8'd1;
	         norm_frac   = acc_sum_s3[15:9];
	         norm_guard  = acc_sum_s3[8];
	         norm_round  = acc_sum_s3[7];
	         norm_sticky = |acc_sum_s3[6:0];
	     end else if (acc_sum_s3[15]) begin
	         norm_exp    = big_exp_s3;
	         norm_frac   = acc_sum_s3[14:8];
	         norm_guard  = acc_sum_s3[7];
	         norm_round  = acc_sum_s3[6];
	         norm_sticky = |acc_sum_s3[5:0];
	     end else if (acc_sum_s3[14]) begin
	         norm_exp    = big_exp_s3 - 8'd1;
	         norm_frac   = acc_sum_s3[13:7];
	         norm_guard  = acc_sum_s3[6];
	         norm_round  = acc_sum_s3[5];
	         norm_sticky = |acc_sum_s3[4:0];
	     end else if (acc_sum_s3[13]) begin
	         norm_exp    = big_exp_s3 - 8'd2;
	         norm_frac   = acc_sum_s3[12:6];
	         norm_guard  = acc_sum_s3[5];
	         norm_round  = acc_sum_s3[4];
	         norm_sticky = |acc_sum_s3[3:0];
	     end else if (acc_sum_s3[12]) begin
	         norm_exp    = big_exp_s3 - 8'd3;
	         norm_frac   = acc_sum_s3[11:5];
	         norm_guard  = acc_sum_s3[4];
	         norm_round  = acc_sum_s3[3];
	         norm_sticky = |acc_sum_s3[2:0];
	     end else if (acc_sum_s3[11]) begin
	         norm_exp    = big_exp_s3 - 8'd4;
	         norm_frac   = acc_sum_s3[10:4];
	         norm_guard  = acc_sum_s3[3];
	         norm_round  = acc_sum_s3[2];
	         norm_sticky = |acc_sum_s3[1:0];
	     end else if (acc_sum_s3[10]) begin
	         norm_exp    = big_exp_s3 - 8'd5;
	         norm_frac   = acc_sum_s3[9:3];
	         norm_guard  = acc_sum_s3[2];
	         norm_round  = acc_sum_s3[1];
	         norm_sticky = acc_sum_s3[0];
	     end else if (acc_sum_s3[9]) begin
	         norm_exp    = big_exp_s3 - 8'd6;
	         norm_frac   = acc_sum_s3[8:2];
	         norm_guard  = acc_sum_s3[1];
	         norm_round  = acc_sum_s3[0];
	         norm_sticky = 1'b0;
	     end else if (acc_sum_s3[8]) begin
	         norm_exp    = big_exp_s3 - 8'd7;
	         norm_frac   = acc_sum_s3[7:1];
	         norm_guard  = acc_sum_s3[0];
	         norm_round  = 1'b0;
	         norm_sticky = 1'b0;
	     end else if (acc_sum_s3[7]) begin
	         norm_exp    = big_exp_s3 - 8'd8;
	         norm_frac   = acc_sum_s3[6:0];
	         norm_guard  = 1'b0;
	         norm_round  = 1'b0;
	         norm_sticky = 1'b0;
	     end else begin
	         norm_zero   = 1'b1;
	     end
	 end

	 // Round-to-nearest-even
	 wire do_round = norm_guard & (norm_round | norm_sticky | norm_frac[0]);
	 wire [7:0] rounded_frac = do_round ? {1'b0, norm_frac} + 8'd1 : {1'b0, norm_frac};
	 // Handle fraction overflow from rounding (0x7F + 1 = 0x80)
	 wire [7:0] final_exp  = rounded_frac[7] ? (norm_exp + 8'd1) : norm_exp;
	 wire [6:0] final_frac = rounded_frac[7] ? 7'b0              : rounded_frac[6:0];

	 wire [15:0] fma_out = mul_zero_s3 ? acc_s3
	                     : norm_zero   ? 16'h0000
	                     : {big_sign_s3, final_exp, final_frac};

	 // Gate result update by valid_pipe[PIPE_DEPTH-2]: this bit is 1 at the
	 // same posedge that fma_out holds the correct value, ensuring result
	 // is not overwritten by garbage on subsequent cycles. Required for
	 // tensor core accumulator feedback between feeds.
	 always @(posedge clk) begin
	     if (rst)
	         result <= 16'h0000;
	     else if (valid_pipe[PIPE_DEPTH-2]) begin
	         if ((fma_out[14:7] == 8'h00) || (relu_en_s3 && fma_out[15]))
	             result <= 16'h0000;
	         else
	             result <= fma_out;
	     end
	 end

	 // ================== VALID PIPELINE ==================
	 reg [PIPE_DEPTH-1:0] valid_pipe;

    always @(posedge clk) begin
      if (rst)
         valid_pipe <= {PIPE_DEPTH{1'b0}};
      else
         valid_pipe <= {valid_pipe[PIPE_DEPTH-2:0], en};
    end

    assign output_ready = valid_pipe[PIPE_DEPTH-1];

endmodule
`endif // BF16_LANE_V
