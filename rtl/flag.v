`timescale 1ns / 1ps

module flag #(
    
    parameter STATE      = 0,    // 0 for empty (R domain), 1 for full (W domain)
    parameter ADDR_WIDTH = 4
    
) (
    
    input                   clk,     // clk_wr for full, clk_rd for empty
    input                   rst_n,   // low active sync

    input  [ADDR_WIDTH:0]   ptr_lc,   // local Gray pointer, extended
    input  [ADDR_WIDTH:0]   ptr_rmt,  // sync_ed remote Gray pointer, extended

    output reg              flag

);

    // ================================== Parameters ==================================
    localparam PTR_WIDTH = ADDR_WIDTH + 1; // 5 bits for 16 deep FIFO
    
    // ================================== Signal declaration ==================================
    reg  [ADDR_WIDTH:0] ptr_rmt_r;
    
    // ================================== Pointer Register Logic ==================================
    
    // Register the synchronized remote pointer
    always @(posedge clk) 
    begin
        if (~rst_n) ptr_rmt_r <= {(PTR_WIDTH){1'b0}};
        else        ptr_rmt_r <= ptr_rmt;
    end
    
    // ================================== Flag generation ==================================
    
    always @(posedge clk)
    begin   
        if (~rst_n) 
            flag <= 1'b0;
        else begin
            case (STATE)
                // EMPTY: Local pointer (R) equals registered remote pointer (W).
                0: flag <= (ptr_lc == ptr_rmt_r);                       
                
                // FULL: MSB of local differs from remote (W[N] != R[N]), 
                // Next MSB of local differs from remote (W[N-1] != R[N-1]), 
                // and the remaining bits are the same.
                1: flag <= (ptr_lc == {~ptr_rmt_r[PTR_WIDTH-1],       // Invert MSB (Bit 4)
                                       ~ptr_rmt_r[PTR_WIDTH-2],       // Invert Next MSB (Bit 3)
                                        ptr_rmt_r[PTR_WIDTH-3:0]});   // Remaining LSBs (Bits 2:0)
                
                default: $error("Invalid STATE value!");
            endcase
        end
    end
    
endmodule