`timescale 1ns / 1ps

module rd_ctrl #(

    parameter ADDR_WIDTH = 4

)(
    
    // sys
    input                   rd_clk,
    input                   rst_n,
    input                   empty,
    output                  empty_out,

    // data
    input                   rd_en_sys,
    output                  ram_ren,
    output [ADDR_WIDTH-1:0] rd_ptr_ram,
    output [ADDR_WIDTH:0]   rd_ptr_ext  // extend one bit for gray

);
    reg [ADDR_WIDTH:0] rd_ptr_ext_r;

    // extended pointer update
    always @(posedge rd_clk)
    begin
        if (~rst_n) rd_ptr_ext_r <= {ADDR_WIDTH+1{1'b0}};
        else        rd_ptr_ext_r <= (~empty && rd_en_sys) ? rd_ptr_ext_r + 1'b1 : rd_ptr_ext_r;
    end

    // generate output pointer
    assign rd_ptr_ram = rd_ptr_ext_r[ADDR_WIDTH-1:0];
    assign rd_ptr_ext = rd_ptr_ext_r;

    // ram read enable 
    assign ram_ren  = ~empty & rd_en_sys;

    // output empty for debugging
    assign empty_out = empty; 
    
endmodule