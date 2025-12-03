`timescale 1ns / 1ps

module wr_ctrl #(
    
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = 4

)(
    // sys
    input                   wr_clk,
    input                   rst_n,
    input                   full,
    output                  full_out,
    
    // data
    input                   wr_en_sys,
    output                  ram_wen,
    output [ADDR_WIDTH-1:0] wr_ptr_ram,
    output [ADDR_WIDTH:0]   wr_ptr_ext  // extend one bit for gray
    
);
    
    reg [ADDR_WIDTH:0] wr_ptr_ext_r;
    
    // extended pointer update
    always @(posedge wr_clk)
    begin
        if (~rst_n) 
            wr_ptr_ext_r <= {(ADDR_WIDTH+1){1'b0}};
        else 
            wr_ptr_ext_r <= (~full && wr_en_sys) ? 
                            (wr_ptr_ext_r + 1'b1) : 
                             wr_ptr_ext_r;
    end
    
    // generate output pointer
    assign wr_ptr_ram = wr_ptr_ext_r[ADDR_WIDTH-1:0];
    assign wr_ptr_ext = wr_ptr_ext_r;
    
    // generate write enable for RAM
    assign ram_wen = (~full && wr_en_sys);
    
    // generate full_out
    assign full_out = full;

endmodule