`timescale 1ns / 1ps

module flag #(
    
    parameter STATE      = 0,    // 0 for empty (R domain), 1 for full (W domain)
    parameter ADDR_WIDTH = 4

) (
    
    input                   clk,     // clk_wr for full, clk_rd for empty
    input                   rst_n,   // low active sync

    input  [ADDR_WIDTH:0]   ptr_lc,   // local Gray pointer
    input  [ADDR_WIDTH:0]   ptr_rmt,  // sync_ed remote Gray pointer

    output reg              flag

);

    // ================================== Signal declaration ==================================
    reg  [ADDR_WIDTH:0] ptr_rmt_r;
    
    // ========================================================================================
    
    
    // ================================== Pointer Register Logic ==================================
    
    always @(posedge clk) 
    begin
        if (~rst_n) begin
            ptr_rmt_r <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            ptr_rmt_r <= ptr_rmt;
        end
    end
    // ============================================================================================
    
    
    // ================================== Flag generation ==================================
    
    always @(posedge clk)
    begin   
        if (~rst_n) 
            flag <= 1'b0;
        else begin
            case (STATE)
                0: flag <= (ptr_lc == ptr_rmt_r);
                1: flag <= (ptr_lc == {~ptr_rmt_r[ADDR_WIDTH], 
                                                ptr_rmt_r[ADDR_WIDTH-1:0]});

                default: $error("Invalid STATE value!");
            endcase
        end
    end
    
    // =====================================================================================
    
endmodule