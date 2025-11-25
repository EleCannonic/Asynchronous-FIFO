`timescale 1ns / 1ps

module tp_ram #(
    // fundamental parameters
    parameter DEPTH         = 16,
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = (DEPTH <= 1) ? 1 : $clog2(DEPTH),

    // optimization parameters
    parameter OUTPUT_REG    = 1,
    parameter RAM_TYPE      = "block"         // block | distributed | register | ultra
)(
    input                   rst_n,

    // write
    input                   wr_clk,
    input                   wr_en,
    input  [ADDR_WIDTH-1:0] wr_addr,
    input  [DATA_WIDTH-1:0] wr_data,

    // read
    input                   rd_clk,
    input                   rd_en,
    input  [ADDR_WIDTH-1:0] rd_addr,
    output [DATA_WIDTH-1:0] rd_data
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
    wire [DATA_WIDTH-1:0] rd_data_unreg;

    // ==============================================================================



    // ============================ Write logic ============================
    always @(posedge wr_clk)
        if (wr_en) ram[wr_addr] <= wr_data;
    // ====================================================================



    // ============================ Read logic ============================
    // asynchronous read
    assign rd_data_unreg = ram[rd_addr];

    // synchronous read pipeline (only when OUTPUT_REG > 0)
    generate

        // pipeline registers for read (only when OUTPUT_REG > 0)

        if (OUTPUT_REG > 0) begin
            reg [DATA_WIDTH-1:0] rd_data_regs [0:OUTPUT_REG-1];

            always @(posedge rd_clk or negedge rst_n) 
            begin
                if (~rst_n) begin
                    for (i = 0; i < OUTPUT_REG; i = i + 1)
                        rd_data_regs[i] <= {DATA_WIDTH{1'b0}};
                end
                
                else if (rd_en) begin
                    rd_data_regs[0] <= ram[rd_addr];  // first stage

                    for (i = 1; i < OUTPUT_REG; i = i + 1)
                        rd_data_regs[i] <= rd_data_regs[i-1];  // subsequent stages
                end
            end

            // output
            assign rd_data = rd_data_regs[OUTPUT_REG-1];
        end
        else
            assign rd_data = rd_data_unreg;
    endgenerate
    // ======================================================================

endmodule