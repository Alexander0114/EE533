// Convertible FIFO Module
// Designed for EE 533 Lab 8
// Integrates NetFPGA pipeline and ARM-compatible processor access
// Instantiates True Dual Port RAM IP Core (FIFO.v)

`timescale 1ns / 1ps

module convertible_fifo(
    input clk,
    input rst,

    // --- Network FPGA Interface ---
    // Input Port (from Reference Pipeline)
    input [63:0] in_data,
    input [7:0] in_ctrl,
    input in_wr,
    output in_rdy,

    // Output Port (to Reference Pipeline)
    output [63:0] out_data,
    output [7:0] out_ctrl,
    output out_wr,
    input  out_rdy,

    // --- Processor (CPU/GPU) Interface ---
    input mode_select,         // 0: Network Mode, 1: Processor Mode
    
    // CPU Port A Access
    input [7:0] cpu_addr_a,
    input [71:0] cpu_data_in_a,
    input cpu_we_a,
    output [71:0] cpu_data_out_a,

    // Port B Access (GPU or output FSM)
    input [7:0] portb_addr,
    input [71:0] portb_data_in,
    input portb_we,
    output [71:0] portb_data_out,

    // Pointer Management
    input [7:0] cpu_head_ptr_in,
    input [7:0] cpu_tail_ptr_in,
    input cpu_ptr_we,
    output [7:0] head_ptr_val,
    output [7:0] tail_ptr_val,

    // Control Signals
    output packet_ready,
    input send_packet      // Signal from CPU that processing/sending is complete
);

    // Output FSM declarations (needed before first use)
    localparam SEND_IDLE    = 2'd0;
    localparam SEND_PRELOAD = 2'd1;
    localparam SEND_ACTIVE  = 2'd2;

    reg [1:0] send_state;
    reg [7:0] read_ptr;
    reg [7:0] end_ptr;
    reg       send_done;

    // Internal Pointers
    reg [7:0] head_ptr;
    reg [7:0] tail_ptr;
    reg packet_in_fifo;
    wire fifo_full;

    // Detect last word: falling edge of in_wr after receiving data
    reg prev_in_wr;
    always @(posedge clk or posedge rst) begin
        if (rst)
            prev_in_wr <= 1'b0;
        else
            prev_in_wr <= in_wr;
    end
    wire in_lastword = prev_in_wr && !in_wr;

    // Head/Tail Pointer Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            head_ptr <= 8'b0;
            tail_ptr <= 8'b0;
            packet_in_fifo <= 1'b0;
        end else begin
            if (cpu_ptr_we) begin
                head_ptr <= cpu_head_ptr_in;
                tail_ptr <= cpu_tail_ptr_in;
            end else if (mode_select == 1'b0) begin
                // Network Mode: Traditional FIFO movement
                if (in_wr && !fifo_full) begin
                    tail_ptr <= tail_ptr + 1'b1;
                end
                if (in_lastword)
                    packet_in_fifo <= 1'b1;

                // Head pointer advanced by output FSM
                if (out_wr && out_rdy) begin
                    head_ptr <= head_ptr + 1'b1;
                end
            end

            // Clear packet flag when output FSM finishes sending
            if (send_done) begin
                packet_in_fifo <= 1'b0;
                head_ptr <= 8'b0;
                tail_ptr <= 8'b0;
            end
        end
    end

    // Signal logic
    assign packet_ready = packet_in_fifo;
    assign fifo_full = packet_in_fifo; // Stall input once one packet is buffered
    assign head_ptr_val = head_ptr;
    assign tail_ptr_val = tail_ptr;
    assign in_rdy  = !packet_in_fifo && !mode_select;

    // Memory Port Multiplexers
    wire [7:0] mem_addr_a;
    wire [7:0] mem_addr_b;
    wire [71:0] mem_data_in_a;
    wire [71:0] mem_data_in_b;
    wire mem_we_a;
    wire mem_we_b;

    // Address and Data Muxes
    // Port A: Input from Network OR CPU Access A
    assign mem_addr_a    = (mode_select) ? cpu_addr_a : tail_ptr;
    assign mem_data_in_a = (mode_select) ? cpu_data_in_a : {in_ctrl, in_data};
    assign mem_we_a      = (mode_select) ? cpu_we_a : (in_wr && !fifo_full);

    // Port B: Output FSM (sending) OR CPU/GPU Access B
    wire sending = (send_state != SEND_IDLE);
    assign mem_addr_b    = sending    ? read_ptr       :
                           mode_select ? portb_addr     : head_ptr;
    assign mem_data_in_b = mode_select ? portb_data_in  : 72'b0;
    assign mem_we_b      = (mode_select && !sending) ? portb_we : 1'b0;

    // Output Data (split 72-bit BRAM output into ctrl + data)
    assign out_data = portb_data_out[63:0];
    assign out_ctrl = portb_data_out[71:64];

    // ========== Output FSM ==========
    // Drains FIFO to NetFPGA pipeline after send_packet.
    // Pipelined: pre-advances read_ptr in PRELOAD so BRAM data arrives
    // every cycle in ACTIVE — out_wr stays high with no gaps.
    //
    // Timing:
    //   PRELOAD: addr=read_ptr on bus, pre-advance read_ptr. out_wr=0.
    //   ACTIVE:  BRAM outputs data from prev cycle's addr. out_wr=1.
    //            Advance read_ptr each cycle → next data ready next cycle.
    assign out_wr = (send_state == SEND_ACTIVE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            send_state <= SEND_IDLE;
            read_ptr   <= 8'b0;
            end_ptr    <= 8'b0;
            send_done  <= 1'b0;
        end else begin
            send_done <= 1'b0;

            case (send_state)
                SEND_IDLE: begin
                    if (send_packet) begin
                        read_ptr   <= head_ptr;
                        end_ptr    <= tail_ptr;
                        send_state <= SEND_PRELOAD;
                    end
                end

                SEND_PRELOAD: begin
                    // BRAM latches read_ptr this cycle.
                    // Pre-advance so next addr is ready when we loop in ACTIVE.
                    read_ptr   <= read_ptr + 1'b1;
                    send_state <= SEND_ACTIVE;
                end

                SEND_ACTIVE: begin
                    // BRAM output has data from address loaded previous cycle.
                    if (out_rdy) begin
                        if (read_ptr == end_ptr) begin
                            // Just sent the last word
                            send_done  <= 1'b1;
                            send_state <= SEND_IDLE;
                        end else begin
                            // Advance to next word — BRAM addr updates
                            // immediately via combinational mux, data
                            // arrives next cycle. No gap in out_wr.
                            read_ptr <= read_ptr + 1'b1;
                        end
                    end
                    // If !out_rdy: stall. read_ptr stable → BRAM output stable.
                end
            endcase
        end
    end

    // Instantiate Xilinx IP Core (True Dual Port)
    FIFO mem_inst (
        .clka(clk),
        .clkb(clk),
        .addra(mem_addr_a),
        .addrb(mem_addr_b),
        .dina(mem_data_in_a),
        .dinb(mem_data_in_b),
        .douta(cpu_data_out_a),
        .doutb(portb_data_out),
        .wea(mem_we_a),
        .web(mem_we_b)
    );

endmodule
