`timescale 1ns / 1ps

module flag #(
    
    parameter STATE      = 0,    // 0 for empty (R domain), 1 for full (W domain)
    parameter ADDR_WIDTH = 8

) (
    
    input                   clk,     // clk_wr for full, clk_rd for empty
    input                   rst_n,   // low active sync

    // addr, gray code (Assumed external synchronization has occurred)
    input  [ADDR_WIDTH-1:0] addr_rd,
    input  [ADDR_WIDTH-1:0] addr_wr,

    output reg              flag

);

    // ================================== Signal declaration ==================================

    // bits stablization
    reg  [ADDR_WIDTH-1:0] addr_rd_r;   
    reg  [ADDR_WIDTH-1:0] addr_wr_r;   


    // ========================================================================================



    // ================================== Pointer Register Logic ==================================

    // Registers store the 1-cycle delayed version of both pointers
    // Such delay enables all bits are stable.
    always @(posedge clk) 
    begin
        if (~rst_n) begin
            addr_rd_r <= {ADDR_WIDTH{1'b0}};
            addr_wr_r <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            addr_rd_r <= addr_rd;
            addr_wr_r <= addr_wr;
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

                // generate empty signal: R_current (Local) vs W_delayed (Remote)
                0: flag <= (addr_rd == addr_wr_r);

                // generate full signal: W_current (Local) vs R_delayed (Remote)
                1: flag <= (addr_wr == { ~addr_rd_r[ADDR_WIDTH-1], 
                                          ~addr_rd_r[ADDR_WIDTH-2], 
                                           addr_rd_r[ADDR_WIDTH-3:0] });

                default: $error("Invalid STATE parameter (should be 0 or 1).");

            endcase
        end
    end

    // =====================================================================================
    
endmodule