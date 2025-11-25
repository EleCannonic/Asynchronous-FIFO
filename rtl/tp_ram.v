`timescale 1ns / 1ps

module tp_ram #(
    // fundamental parameters
    parameter DEPTH         = 16,
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 4,

    // optimization parameters
    parameter OUTPUT_REG    = 1,
    parameter RAM_TYPE      = "block"         // block | distributed | register | ultra
)(
    input                   rst_n,            // low active, sync

    // write
    input                   clk_wr,
    input                   en_wr,
    input  [ADDR_WIDTH-1:0] addr_wr,
    input  [DATA_WIDTH-1:0] data_wr,

    // read
    input                   clk_rd,
    input                   en_rd,
    input  [ADDR_WIDTH-1:0] addr_rd,
    output [DATA_WIDTH-1:0] data_rd
);


    // ============================ Parameter & Address Width ============================
    generate
        if (DEPTH == 1)     
            $warning("Be careful to use 1-depth RAM. Use registers recommended.");
        if (OUTPUT_REG < 0) 
            $error  ("Please input valid output register number.");
        if (RAM_TYPE != "block" && RAM_TYPE != "distributed" && RAM_TYPE != "ultra" && RAM_TYPE != "register")
            $error  ("Please input valid RAM types, including \"block\", \"distributed\",\"ultra\" and \"register.");
        if (RAM_TYPE == "block" && OUTPUT_REG == 0)
            $warning("Block RAM does not support asynchronous read. The RAM will be implemented as distributed RAM.");
    endgenerate
    // ===================================================================================



    // ============================ Signals declaration ============================

    // storage
    (* ram_style = RAM_TYPE *)
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    
    integer i;

    // asynchronous read wire
    wire [DATA_WIDTH-1:0] data_rd_unreg;

    // ==============================================================================



    // ============================ Write logic ============================
    always @(posedge clk_wr)
        if (en_wr) ram[addr_wr] <= data_wr;
    // ====================================================================



    // ============================ Read logic ============================
    // asynchronous read
    assign data_rd_unreg = ram[addr_rd];

    // synchronous read pipeline (only when OUTPUT_REG > 0)
    generate

        // pipeline registers for read (only when OUTPUT_REG > 0)

        if (OUTPUT_REG > 0) begin
            reg [DATA_WIDTH-1:0] data_rd_regs [0:OUTPUT_REG-1];

            always @(posedge clk_rd) 
            begin
                if (~rst_n) begin
                    for (i = 0; i < OUTPUT_REG; i = i + 1)
                        data_rd_regs[i] <= {DATA_WIDTH{1'b0}};
                end
                
                else if (en_rd) begin
                    data_rd_regs[0] <= ram[addr_rd];  // first stage

                    for (i = 1; i < OUTPUT_REG; i = i + 1)
                        data_rd_regs[i] <= data_rd_regs[i-1];  // subsequent stages
                end
            end

            // output
            assign data_rd = data_rd_regs[OUTPUT_REG-1];
        end
        else
            assign data_rd = data_rd_unreg;
    endgenerate
    // ======================================================================

endmodule