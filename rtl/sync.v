`timescale 1ns / 1ps

module sync #(

    parameter ADDR_WIDTH = 8

) (

    // target clock domain port
    input                    clk_trg,
    input                    rst_trg_n,     // low active sync

    // data transfer path, gray code
    input  [ADDR_WIDTH-1:0] addr_src,
    output [ADDR_WIDTH-1:0] addr_trg 

);

    // reg declaration
    reg [ADDR_WIDTH-1:0] sync_reg1;
    reg [ADDR_WIDTH-1:0] sync_reg2;
    
    // sync logic
    always @(posedge clk_trg)
    begin
        if (~rst_trg_n) begin
            sync_reg1 <= {ADDR_WIDTH{1'b0}};
            sync_reg2 <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            sync_reg1 <= addr_src;    // reg stage 1
            sync_reg2 <= sync_reg1;   // reg stage 2
        end
    end

    assign addr_trg = sync_reg2;

endmodule