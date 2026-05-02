// ============================================================
// Testbench: Network Processor Integration (Lab 8 Final)
// Tests: Packet in -> CPU detects -> GPU processes -> Packet out
//
// Updates from lab8:
//   - CPU program: 25 instructions (added gpu_rst pulse)
//   - GPU program: unrolled (no branches)
//   - ARM_Processor_4T: debug_cpu_pc port connected
//   - convertible_fifo: pipelined output FSM (no out_wr gaps)
// ============================================================
`timescale 1ns / 1ps

module network_processor_tb;

    // Clock and reset
    reg clk;
    reg reset;

    // NetFPGA pipeline interface
    reg  [63:0] in_data;
    reg  [7:0]  in_ctrl;
    reg         in_wr;
    wire        in_rdy;

    wire [63:0] out_data;
    wire [7:0]  out_ctrl;
    wire        out_wr;
    reg         out_rdy;

    // CPU program loading
    reg  [8:0]  cpu_imem_addr;
    reg  [31:0] cpu_imem_data;
    reg         cpu_imem_we;

    // GPU program loading
    reg  [9:0]  gpu_imem_addr;
    reg  [31:0] gpu_imem_data;
    reg         gpu_imem_we;

    // ================================================================
    //  Internal wires (replicate network_processor_top wiring)
    // ================================================================

    // CPU <-> FIFO (Port A)
    wire [7:0]  cpu_fifo_addr;
    wire [63:0] cpu_fifo_wdata;
    wire        cpu_fifo_we;
    wire [63:0] cpu_fifo_rdata;

    // CPU control outputs
    wire        ctrl_mode_select;
    wire        ctrl_send_packet;
    wire        ctrl_gpu_rst;
    wire        ctrl_gpu_run;

    // Status inputs to CPU
    wire        ctrl_packet_ready;
    wire        ctrl_gpu_halted;
    wire [7:0]  ctrl_head_ptr;
    wire [7:0]  ctrl_tail_ptr;

    // GPU <-> FIFO (Port B)
    wire [9:0]  gpu_dmem_addr;
    wire [63:0] gpu_dmem_wdata;
    wire        gpu_dmem_we;
    wire [63:0] gpu_dmem_rdata;

    // FIFO Port B raw output (72-bit)
    wire [71:0] fifo_data_out_b;
    wire [71:0] fifo_data_out_a;

    // GPU debug
    wire [9:0]  gpu_debug_pc;
    wire        gpu_halted;
    wire [3:0]  gpu_state;
    wire [31:0] gpu_debug_ir;

    // CPU debug
    wire [8:0]  cpu_debug_pc;

    // ================================================================
    //  CPU Instance
    // ================================================================
    wire sys_reset = reset;

    ARM_Processor_4T cpu_inst (
        .CLK        (clk),
        .CLR_ALL    (sys_reset),
        .IM_CLR     (sys_reset),
        .ADDR       (cpu_imem_addr),
        .DIN        (cpu_imem_data),
        .IM_WE      (cpu_imem_we),
        .cpu_fifo_addr  (cpu_fifo_addr),
        .cpu_fifo_wdata (cpu_fifo_wdata),
        .cpu_fifo_we    (cpu_fifo_we),
        .cpu_fifo_rdata (cpu_fifo_rdata),
        .ctrl_mode_select  (ctrl_mode_select),
        .ctrl_send_packet  (ctrl_send_packet),
        .ctrl_gpu_rst      (ctrl_gpu_rst),
        .ctrl_gpu_run      (ctrl_gpu_run),
        .ctrl_packet_ready (ctrl_packet_ready),
        .ctrl_gpu_halted   (ctrl_gpu_halted),
        .ctrl_head_ptr     (ctrl_head_ptr),
        .ctrl_tail_ptr     (ctrl_tail_ptr),
        .debug_cpu_pc      (cpu_debug_pc)
    );

    // ================================================================
    //  GPU Instance
    // ================================================================
    wire gpu_reset = sys_reset | ctrl_gpu_rst;

    assign ctrl_gpu_halted = gpu_halted;

    gpu_top gpu_inst (
        .clk        (clk),
        .rst        (gpu_reset),
        .run        (ctrl_gpu_run),
        .thread_id  (10'd0),
        .halted     (gpu_halted),
        .debug_pc   (gpu_debug_pc),
        .debug_ir   (gpu_debug_ir),
        .debug_state(gpu_state),
        .ext_imem_addr (gpu_imem_addr),
        .ext_imem_data (gpu_imem_data),
        .ext_imem_we   (gpu_imem_we),
        .gpu_dmem_addr  (gpu_dmem_addr),
        .gpu_dmem_wdata (gpu_dmem_wdata),
        .gpu_dmem_we    (gpu_dmem_we),
        .gpu_dmem_rdata (gpu_dmem_rdata)
    );

    // ================================================================
    //  Convertible FIFO Instance
    // ================================================================
    convertible_fifo fifo_inst (
        .clk    (clk),
        .rst    (sys_reset),
        .in_data    (in_data),
        .in_ctrl    (in_ctrl),
        .in_wr      (in_wr),
        .in_rdy     (in_rdy),
        .out_data   (out_data),
        .out_ctrl   (out_ctrl),
        .out_wr     (out_wr),
        .out_rdy    (out_rdy),
        .mode_select    (ctrl_mode_select),
        .cpu_addr_a     (cpu_fifo_addr),
        .cpu_data_in_a  ({8'b0, cpu_fifo_wdata}),
        .cpu_we_a       (cpu_fifo_we),
        .cpu_data_out_a (fifo_data_out_a),
        .portb_addr     (gpu_dmem_addr[7:0]),
        .portb_data_in  ({8'b0, gpu_dmem_wdata}),
        .portb_we       (gpu_dmem_we),
        .portb_data_out (fifo_data_out_b),
        .cpu_head_ptr_in (8'b0),
        .cpu_tail_ptr_in (8'b0),
        .cpu_ptr_we      (1'b0),
        .head_ptr_val    (ctrl_head_ptr),
        .tail_ptr_val    (ctrl_tail_ptr),
        .packet_ready   (ctrl_packet_ready),
        .send_packet    (ctrl_send_packet)
    );

    assign gpu_dmem_rdata = fifo_data_out_b[63:0];
    assign cpu_fifo_rdata = fifo_data_out_a[63:0];

    // ================================================================
    //  Clock Generation: 10ns period (100 MHz)
    // ================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================================================================
    //  Test Packet Data
    // ================================================================
    // 7-word packet:
    //   Word 0: Module header   (ctrl=0xFF)
    //   Word 1: Ethernet hdr    (ctrl=0x00) -> GPU processes
    //   Word 2: IP header       (ctrl=0x00) -> GPU processes
    //   Word 3: Payload 0       (ctrl=0x00) -> GPU processes
    //   Word 4: Payload 1       (ctrl=0x00) -> GPU processes
    //   Word 5: Payload 2       (ctrl=0x00) -> GPU processes
    //   Word 6: Last word       (ctrl=0x01)
    //
    // GPU adds 1 to each int16 lane of words at addrs 1-5.

    reg [7:0]  pkt_ctrl [0:6];
    reg [63:0] pkt_data [0:6];

    initial begin
        // Module header
        pkt_ctrl[0] = 8'hFF;
        pkt_data[0] = 64'h0000_0002_0000_0000;  // output port = MAC1

        // Ethernet header (some fake data)
        pkt_ctrl[1] = 8'h00;
        pkt_data[1] = 64'h0001_0002_0003_0004;  // 4x int16: {1,2,3,4}

        // IP header
        pkt_ctrl[2] = 8'h00;
        pkt_data[2] = 64'h000A_0014_001E_0028;  // 4x int16: {10,20,30,40}

        // Payload 0
        pkt_ctrl[3] = 8'h00;
        pkt_data[3] = 64'h0064_00C8_012C_0190;  // 4x int16: {100,200,300,400}

        // Payload 1
        pkt_ctrl[4] = 8'h00;
        pkt_data[4] = 64'hFFFF_0000_7FFF_8000;  // 4x int16: {-1,0,32767,-32768}

        // Payload 2
        pkt_ctrl[5] = 8'h00;
        pkt_data[5] = 64'h1234_5678_9ABC_DEF0;  // arbitrary data

        // Last word
        pkt_ctrl[6] = 8'h01;                     // last word marker
        pkt_data[6] = 64'hDEAD_BEEF_CAFE_BABE;
    end

    // ================================================================
    //  Tasks
    // ================================================================

    // Load one CPU instruction
    task load_cpu_instr;
        input [8:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_imem_addr <= addr;
            cpu_imem_data <= data;
            cpu_imem_we   <= 1'b1;
            @(posedge clk);
            cpu_imem_we   <= 1'b0;
        end
    endtask

    // Load one GPU instruction
    task load_gpu_instr;
        input [9:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            gpu_imem_addr <= addr;
            gpu_imem_data <= data;
            gpu_imem_we   <= 1'b1;
            @(posedge clk);
            gpu_imem_we   <= 1'b0;
        end
    endtask

    // Send a complete packet (burst mode - in_wr stays high throughout)
    task send_packet;
        integer idx;
        begin
            // Wait until FIFO is ready
            @(posedge clk);
            while (!in_rdy) @(posedge clk);

            // Send all words with in_wr held high
            for (idx = 0; idx < 7; idx = idx + 1) begin
                in_ctrl <= pkt_ctrl[idx];
                in_data <= pkt_data[idx];
                in_wr   <= 1'b1;
                @(posedge clk);
            end

            // Deassert in_wr to signal end of packet
            in_wr <= 1'b0;
            @(posedge clk);
        end
    endtask

    // ================================================================
    //  Output Capture
    // ================================================================
    integer out_word_count;
    reg [7:0]  out_pkt_ctrl [0:31];
    reg [63:0] out_pkt_data [0:31];

    initial out_word_count = 0;

    always @(posedge clk) begin
        if (out_wr && out_rdy) begin
            out_pkt_ctrl[out_word_count] = out_ctrl;
            out_pkt_data[out_word_count] = out_data;
            $display("[OUT %0d] ctrl=%h data=%h", out_word_count, out_ctrl, out_data);
            out_word_count = out_word_count + 1;
        end
    end

    // ================================================================
    //  Main Test Sequence
    // ================================================================
    integer i;

    initial begin
        $dumpfile("network_processor_tb.vcd");
        $dumpvars(0, network_processor_tb);

        // --- Initialize ---
        reset        = 1;
        in_data      = 0;
        in_ctrl      = 0;
        in_wr        = 0;
        out_rdy      = 1;       // downstream always ready
        cpu_imem_we  = 0;
        gpu_imem_we  = 0;
        cpu_imem_addr = 0;
        cpu_imem_data = 0;
        gpu_imem_addr = 0;
        gpu_imem_data = 0;

        // Hold reset for 20 cycles
        repeat (20) @(posedge clk);

        // --- Load CPU program (25 instructions, with gpu_rst pulse) ---
        $display("\n=== Loading CPU Program (25 instructions) ===");
        // ctrl bits: 0=packet_ready(r), 1=mode_select, 2=send_packet, 3=gpu_run, 4=gpu_rst
        load_cpu_instr(9'd0,  32'h9000_1001);  // ADDI R1, R0, 1
        load_cpu_instr(9'd1,  32'h9610_100C);  // LSLI R1, R1, 12  -> R1 = 0x1000
        load_cpu_instr(9'd2,  32'h2010_2000);  // LW R2, [R1, 0]   POLL
        load_cpu_instr(9'd3,  32'h9220_3001);  // ANDI R3, R2, 1   check packet_ready
        load_cpu_instr(9'd4,  32'h400C_0008);  // BLE POLL (2*4=8)
        load_cpu_instr(9'd5,  32'h9000_2012);  // ADDI R2, R0, 18  mode_select=1, gpu_rst=1
        load_cpu_instr(9'd6,  32'h3012_0000);  // SW R2, [R1, 0]   (reset GPU)
        load_cpu_instr(9'd7,  32'h9000_2002);  // ADDI R2, R0, 2   mode_select=1 (release gpu_rst)
        load_cpu_instr(9'd8,  32'h3012_0000);  // SW R2, [R1, 0]
        load_cpu_instr(9'd9,  32'h9000_200A);  // ADDI R2, R0, 10  mode_select=1, gpu_run=1
        load_cpu_instr(9'd10, 32'h3012_0000);  // SW R2, [R1, 0]
        load_cpu_instr(9'd11, 32'h2010_2000);  // LW R2, [R1, 0]   GPU_WAIT
        load_cpu_instr(9'd12, 32'h9220_3020);  // ANDI R3, R2, 32  check gpu_halted
        load_cpu_instr(9'd13, 32'h400C_002C);  // BLE GPU_WAIT (11*4=44)
        load_cpu_instr(9'd14, 32'h9000_2002);  // ADDI R2, R0, 2   mode_select=1
        load_cpu_instr(9'd15, 32'h3012_0000);  // SW R2, [R1, 0]
        load_cpu_instr(9'd16, 32'h9000_2006);  // ADDI R2, R0, 6   mode_select=1, send_packet=1
        load_cpu_instr(9'd17, 32'h3012_0000);  // SW R2, [R1, 0]
        load_cpu_instr(9'd18, 32'h2010_2000);  // LW R2, [R1, 0]   WAIT_SEND
        load_cpu_instr(9'd19, 32'h9220_3001);  // ANDI R3, R2, 1   check packet_ready
        load_cpu_instr(9'd20, 32'h9430_3001);  // XORI R3, R3, 1   invert
        load_cpu_instr(9'd21, 32'h400C_0048);  // BLE WAIT_SEND (18*4=72)
        load_cpu_instr(9'd22, 32'h9000_2000);  // ADDI R2, R0, 0   clear ctrl
        load_cpu_instr(9'd23, 32'h3012_0000);  // SW R2, [R1, 0]
        load_cpu_instr(9'd24, 32'h4004_0008);  // B POLL (2*4=8)

        // --- Load GPU program (24 instructions, unrolled, no branches) ---
        $display("=== Loading GPU Program (24 instructions) ===");
        load_gpu_instr(10'd0,  32'h6000_0000);  // MOVI  R0, 0
        load_gpu_instr(10'd1,  32'h4840_0001);  // ADDI  R1, R0, 1
        load_gpu_instr(10'd2,  32'h7042_0003);  // VBCAST R1, R1, lane 3 (LSB)
        // Word 1
        load_gpu_instr(10'd3,  32'h6080_0001);  // MOVI  R2, 1
        load_gpu_instr(10'd4,  32'h1104_0000);  // LD    R4, [R2, 0]
        load_gpu_instr(10'd5,  32'h0108_1000);  // VADD  R4, R4, R1
        load_gpu_instr(10'd6,  32'h1904_0000);  // ST    R4, [R2, 0]
        // Word 2
        load_gpu_instr(10'd7,  32'h6080_0002);  // MOVI  R2, 2
        load_gpu_instr(10'd8,  32'h1104_0000);  // LD    R4, [R2, 0]
        load_gpu_instr(10'd9,  32'h0108_1000);  // VADD  R4, R4, R1
        load_gpu_instr(10'd10, 32'h1904_0000);  // ST    R4, [R2, 0]
        // Word 3
        load_gpu_instr(10'd11, 32'h6080_0003);  // MOVI  R2, 3
        load_gpu_instr(10'd12, 32'h1104_0000);  // LD    R4, [R2, 0]
        load_gpu_instr(10'd13, 32'h0108_1000);  // VADD  R4, R4, R1
        load_gpu_instr(10'd14, 32'h1904_0000);  // ST    R4, [R2, 0]
        // Word 4
        load_gpu_instr(10'd15, 32'h6080_0004);  // MOVI  R2, 4
        load_gpu_instr(10'd16, 32'h1104_0000);  // LD    R4, [R2, 0]
        load_gpu_instr(10'd17, 32'h0108_1000);  // VADD  R4, R4, R1
        load_gpu_instr(10'd18, 32'h1904_0000);  // ST    R4, [R2, 0]
        // Word 5
        load_gpu_instr(10'd19, 32'h6080_0005);  // MOVI  R2, 5
        load_gpu_instr(10'd20, 32'h1104_0000);  // LD    R4, [R2, 0]
        load_gpu_instr(10'd21, 32'h0108_1000);  // VADD  R4, R4, R1
        load_gpu_instr(10'd22, 32'h1904_0000);  // ST    R4, [R2, 0]
        // Done
        load_gpu_instr(10'd23, 32'h5000_0000);  // HALT

        // --- Release reset, let CPU start ---
        $display("=== Releasing Reset ===");
        reset = 0;

        // Wait a few cycles for CPU to start polling
        repeat (40) @(posedge clk);

        // --- Inject packet ---
        $display("\n=== Injecting Packet ===");
        send_packet;

        $display("=== Packet Injected, Waiting for Processing ===");

        // --- Wait for output packet (timeout after 5000 cycles) ---
        begin : wait_loop
            integer cyc;
            for (cyc = 0; cyc < 5000; cyc = cyc + 1) begin
                @(posedge clk);
                if (out_word_count >= 7) begin
                    $display("\n=== Output Packet Received (%0d words) ===", out_word_count);
                    disable wait_loop;
                end
            end
            $display("\n=== TIMEOUT: Only received %0d output words ===", out_word_count);
        end

        // --- Verify output ---
        $display("\n=== Verification ===");

        // Word 0: Module header - should be unchanged
        $display("Word 0: ctrl=%h data=%h (expect FF/%h)",
            out_pkt_ctrl[0], out_pkt_data[0], pkt_data[0]);

        // Words 1-5: GPU added 1 to each int16 lane
        for (i = 1; i <= 5; i = i + 1) begin
            $display("Word %0d: ctrl=%h data=%h (expect 00/int16+1)",
                i, out_pkt_ctrl[i], out_pkt_data[i]);
        end

        // Word 6: Last word - unchanged
        $display("Word 6: ctrl=%h data=%h (expect 01/%h)",
            out_pkt_ctrl[6], out_pkt_data[6], pkt_data[6]);

        // Detailed int16 lane checks for word 1
        if (out_word_count >= 2) begin
            // pkt_data[1] = {1, 2, 3, 4}, expect {2, 3, 4, 5}
            if (out_pkt_data[1] == 64'h0002_0003_0004_0005)
                $display("PASS: Word 1 correctly incremented");
            else
                $display("FAIL: Word 1 expected 0002000300040005, got %h", out_pkt_data[1]);
        end

        // Check word 3 (payload 0)
        if (out_word_count >= 4) begin
            // pkt_data[3] = {100, 200, 300, 400}, expect {101, 201, 301, 401}
            if (out_pkt_data[3] == 64'h0065_00C9_012D_0191)
                $display("PASS: Word 3 correctly incremented");
            else
                $display("FAIL: Word 3 expected 006500C9012D0191, got %h", out_pkt_data[3]);
        end

        // Check word 4 (overflow/underflow case)
        if (out_word_count >= 5) begin
            // pkt_data[4] = {0xFFFF, 0x0000, 0x7FFF, 0x8000}
            // expect       = {0x0000, 0x0001, 0x8000, 0x8001}
            if (out_pkt_data[4] == 64'h0000_0001_8000_8001)
                $display("PASS: Word 4 correctly incremented (overflow cases)");
            else
                $display("FAIL: Word 4 expected 0000000180008001, got %h", out_pkt_data[4]);
        end

        // --- Second packet test (verify gpu_rst allows re-processing) ---
        $display("\n=== Injecting Second Packet (gpu_rst test) ===");
        out_word_count = 0;
        send_packet;

        begin : wait_loop2
            integer cyc;
            for (cyc = 0; cyc < 5000; cyc = cyc + 1) begin
                @(posedge clk);
                if (out_word_count >= 7) begin
                    $display("\n=== Second Output Packet Received (%0d words) ===", out_word_count);
                    disable wait_loop2;
                end
            end
            $display("\n=== TIMEOUT on 2nd packet: Only received %0d output words ===", out_word_count);
        end

        // Verify second packet also processed
        if (out_word_count >= 2) begin
            if (out_pkt_data[1] == 64'h0002_0003_0004_0005)
                $display("PASS: Second packet Word 1 correctly incremented (gpu_rst works)");
            else
                $display("FAIL: Second packet Word 1 got %h", out_pkt_data[1]);
        end

        repeat (20) @(posedge clk);
        $display("\n=== Test Complete ===");
        $finish;
    end

    // ================================================================
    //  Debug Monitors
    // ================================================================

    // Key event monitors (edge-triggered to reduce spam)
    reg prev_pkt_rdy, prev_gpu_halted, prev_mode_sel, prev_gpu_rst;
    initial begin prev_pkt_rdy = 0; prev_gpu_halted = 0; prev_mode_sel = 0; prev_gpu_rst = 0; end
    always @(posedge clk) begin
        if (!reset) begin
            if (ctrl_packet_ready && !prev_pkt_rdy)
                $display("[%0t] packet_ready ASSERTED", $time);
            if (ctrl_mode_select && !prev_mode_sel)
                $display("[%0t] mode_select ON", $time);
            if (!ctrl_mode_select && prev_mode_sel)
                $display("[%0t] mode_select OFF", $time);
            if (gpu_halted && !prev_gpu_halted)
                $display("[%0t] GPU HALTED (pc=%0d)", $time, gpu_debug_pc);
            if (ctrl_gpu_rst && !prev_gpu_rst)
                $display("[%0t] gpu_rst ASSERTED", $time);
            if (!ctrl_gpu_rst && prev_gpu_rst)
                $display("[%0t] gpu_rst DEASSERTED", $time);
            if (ctrl_send_packet)
                $display("[%0t] send_packet pulse", $time);
            prev_pkt_rdy    <= ctrl_packet_ready;
            prev_gpu_halted <= gpu_halted;
            prev_mode_sel   <= ctrl_mode_select;
            prev_gpu_rst    <= ctrl_gpu_rst;
        end
    end

    // Periodic CPU PC monitor (every 100 cycles)
    integer cycle_count;
    initial cycle_count = 0;
    always @(posedge clk) begin
        if (!reset) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count % 200 == 0)
                $display("[%0t] CPU_PC=%0d GPU_PC=%0d halted=%b mode=%b",
                    $time, cpu_debug_pc, gpu_debug_pc, gpu_halted, ctrl_mode_select);
        end
    end

    // Monitor out_wr gaps during send
    reg prev_out_wr;
    initial prev_out_wr = 0;
    always @(posedge clk) begin
        if (!reset) begin
            // Detect gap: out_wr was high, dropped to 0, then goes high again
            if (prev_out_wr && !out_wr && out_word_count > 0 && out_word_count < 7)
                $display("[%0t] WARNING: out_wr gap detected after word %0d", $time, out_word_count);
            prev_out_wr <= out_wr;
        end
    end

endmodule
