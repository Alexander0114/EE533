/* file: test_gpu_dmem.v
Description: Behavioral dual-port BRAM for GPU DMEM simulation.
   256 x 64-bit. Port A: GPU read/write. Port B: pkt_proc read/write.
   Synchronous reads (1-cycle latency) to match Xilinx Block RAM behavior.
Author: Raymond
Date: Mar. 11, 2026
Version: 1.0

ISE Generation Spec (for synthesis):
   Type: Block Memory Generator / Dual-Port Block RAM
   Port A: Width=64, Depth=256, Read+Write, Synchronous
   Port B: Width=64, Depth=256, Read+Write, Synchronous
   Address Width: 8 bits
*/

`ifndef TEST_GPU_DMEM_V
`define TEST_GPU_DMEM_V

module test_gpu_dmem #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 64
)(
    input wire clka,
    input wire [ADDR_WIDTH-1:0] addra,
    input wire [DATA_WIDTH-1:0] dina,
    input wire wea,
    output reg [DATA_WIDTH-1:0] douta,

    input wire clkb,
    input wire [ADDR_WIDTH-1:0] addrb,
    input wire [DATA_WIDTH-1:0] dinb,
    input wire web,
    output reg [DATA_WIDTH-1:0] doutb
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    integer i;
    initial for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) mem[i] = {DATA_WIDTH{1'b0}};

    // Port A: synchronous read and write (GPU side)
    always @(posedge clka) begin
        if (wea)
            mem[addra] <= dina;
        douta <= mem[addra];
    end

    // Port B: synchronous read and write (pkt_proc side)
    always @(posedge clkb) begin
        if (web)
            mem[addrb] <= dinb;
        doutb <= mem[addrb];
    end

endmodule

`endif // TEST_GPU_DMEM_V
