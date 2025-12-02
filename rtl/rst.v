`timescale 1ns / 1ps

module rst #(

    parameter SYNC_STAGES = 2

)(

    input  clk,
    input  async_rst_n,
    output sync_rst_n

);

    reg [SYNC_STAGES-1:0] reset_sync_reg;
    
    always @(posedge clk or negedge async_rst_n) begin
        if (~async_rst_n) reset_sync_reg <= {SYNC_STAGES{1'b0}};
        else              reset_sync_reg <= {reset_sync_reg[SYNC_STAGES-2:0], 1'b1};
    end
    
    assign sync_rst_n = reset_sync_reg[SYNC_STAGES-1];
    
endmodule