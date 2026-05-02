`timescale 1ns / 1ps
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

	 // 0: add, 1: mul, 2: FMA (a*b + c)
    input [2:0] op_mode,
	 // activate relu
	 input relu_en,

	 // output
    output reg [15:0] result,
    output output_ready
    );

	 // ================== NORMALIZATION FUNCTION ==================
	 function [14:0] bf16_normalize;
	     input [9:0] mant;
	     input [7:0] base_exp;
	     begin
	         if (mant[8])
	             bf16_normalize = {base_exp + 8'd1, mant[7:1]};
	         else if (mant[7])
	             bf16_normalize = {base_exp, mant[6:0]};
	         else if (mant[6])
	             bf16_normalize = {base_exp - 8'd1, mant[5:0], 1'b0};
	         else if (mant[5])
	             bf16_normalize = {base_exp - 8'd2, mant[4:0], 2'b0};
	         else if (mant[4])
	             bf16_normalize = {base_exp - 8'd3, mant[3:0], 3'b0};
	         else if (mant[3])
	             bf16_normalize = {base_exp - 8'd4, mant[2:0], 4'b0};
	         else if (mant[2])
	             bf16_normalize = {base_exp - 8'd5, mant[1:0], 5'b0};
	         else if (mant[1])
	             bf16_normalize = {base_exp - 8'd6, mant[0], 6'b0};
	         else
	             bf16_normalize = 15'b0;
	     end
	 endfunction

	 // ================== INPUT MUX ==================
	 wire [15:0] mul_in_b = (op_mode == 3'd0) ? 16'h3F80 : src_b;
	 wire [15:0] acc_in   = (op_mode == 3'd0) ? src_b     :
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
	 // ================================================================

	 // --- Normalize multiply result (combinational from stage 1) ---
	 wire [7:0]  mul_exp  = product_raw[15] ? (exp_sum_s1[7:0] + 8'd1)
	                                        : exp_sum_s1[7:0];
	 wire [6:0]  mul_frac = product_raw[15] ? product_raw[14:8]
	                                        : product_raw[13:7];

	 wire        p_sign = mul_zero_s1 ? 1'b0       : sign_mul_s1;
	 wire [7:0]  p_exp  = mul_zero_s1 ? 8'h00      : mul_exp;
	 wire [7:0]  p_mant = mul_zero_s1 ? 8'h00      : {1'b1, mul_frac};

	 // --- Decompose accumulate operand ---
	 wire        c_sign = acc_s1[15];
	 wire [7:0]  c_exp  = acc_s1[14:7];
	 wire [7:0]  c_mant = (c_exp != 8'h00) ? {1'b1, acc_s1[6:0]} : 8'h00;

	 // --- Magnitude comparison ---
	 wire p_gte_c = (p_exp > c_exp) || ((p_exp == c_exp) && (p_mant >= c_mant));

	 wire [7:0]  s2_big_exp  = p_gte_c ? p_exp  : c_exp;
	 wire [7:0]  s2_big_mant = p_gte_c ? p_mant : c_mant;
	 wire        s2_big_sign = p_gte_c ? p_sign : c_sign;
	 wire [7:0]  s2_sml_mant = p_gte_c ? c_mant : p_mant;
	 wire [7:0]  s2_exp_diff = p_gte_c ? (p_exp - c_exp) : (c_exp - p_exp);
	 wire        s2_eff_sub  = p_sign ^ c_sign;

	 // --- Stage 2 registers ---
	 reg [7:0]  big_exp_s2;
	 reg [7:0]  big_mant_s2;
	 reg        big_sign_s2;
	 reg [7:0]  sml_mant_s2;
	 reg [7:0]  exp_diff_s2;
	 reg        eff_sub_s2;
	 reg        mul_zero_s2;
	 reg        relu_en_s2;
	 reg [15:0] acc_s2;

	 always @(posedge clk) begin
	     if (rst) begin
	         big_exp_s2  <= 8'b0;
	         big_mant_s2 <= 8'b0;
	         big_sign_s2 <= 1'b0;
	         sml_mant_s2 <= 8'b0;
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
	 // STAGE 3: Alignment shift + mantissa add/sub
	 // ================================================================
	 wire [7:0]  aligned = (exp_diff_s2 >= 8) ? 8'b0
	                                          : (sml_mant_s2 >> exp_diff_s2);

	 wire [9:0]  acc_sum = eff_sub_s2 ? ({2'b0, big_mant_s2} - {2'b0, aligned})
	                                  : ({2'b0, big_mant_s2} + {2'b0, aligned});

	 // --- Stage 3 registers ---
	 reg [9:0]  acc_sum_s3;
	 reg [7:0]  big_exp_s3;
	 reg        big_sign_s3;
	 reg        mul_zero_s3;
	 reg        relu_en_s3;
	 reg [15:0] acc_s3;

	 always @(posedge clk) begin
	     if (rst) begin
	         acc_sum_s3  <= 10'b0;
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
	 // STAGE 4: Normalization + ReLU + output register
	 // ================================================================
	 wire [14:0] acc_norm    = bf16_normalize(acc_sum_s3, big_exp_s3);
	 wire        acc_is_zero = (acc_sum_s3 == 10'b0);

	 wire [15:0] fma_out = mul_zero_s3 ? acc_s3
	                     : acc_is_zero  ? 16'h0000
	                     : {big_sign_s3, acc_norm[14:7], acc_norm[6:0]};

	 always @(posedge clk) begin
	     if (rst)
	         result <= 16'h0000;
	     else if ((fma_out[14:7] == 8'h00) || (relu_en_s3 && fma_out[15]))
	         result <= 16'h0000;
	     else
	         result <= fma_out;
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
