/* ===================================================================
 *
 *  Asynchronous FIFO
 *  File: async_fifo.v
 *  Author: [Your Name]
 *
 *  Description:
 *  Configurable asynchronous FIFO with independent read/write clock domains.
 *  Implements Gray code pointer synchronization for safe clock domain crossing.
 *  Supports multiple memory types and output register pipeline stages.
 *
 *  Features:
 *  - Independent read/write clock domains
 *  - Configurable depth and data width
 *  - Gray code pointer synchronization
 *  - Multiple memory types (Block, Distributed, Register, Ultra)
 *  - Output register pipeline (0-3 stages)
 *  - Full/empty flags with proper synchronization
 *
 *  Parameters:
 *  DEPTH: FIFO depth in entries (default: 16)
 *  DATA_WIDTH: Data width in bits (default: 32)
 *  ADDR_WIDTH: Address width = ceil(log2(DEPTH))
 *  OUTPUT_REG: Output pipeline stages (0=combinational, default: 1)
 *  RAM_TYPE: Memory implementation type ("block", "distributed", "register", "ultra")
 *
 *  Ports:
 *  wr_clk: Write clock domain
 *  wr_en: Write enable
 *  wr_data: Write data
 *  full_out: FIFO full flag
 *  rd_clk: Read clock domain  
 *  rd_en: Read enable
 *  rd_data: Read data
 *  empty_out: FIFO empty flag
 *  rst_glb_n: Global asynchronous reset (active low)
 *
 =================================================================== */


`timescale 1ns / 1ps

module async_fifo #(

    parameter DEPTH         = 16,
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 4,

    // optimization parameters
    parameter OUTPUT_REG    = 1,
    parameter RAM_TYPE      = "block"         // block | distributed | register | ultra

)(

    // sys reset
    input                   rst_glb_n,  // global reset, low active

    // write port
    input                   wr_clk,
    input                   wr_en,
    input [DATA_WIDTH-1:0]  wr_data,
    output                  full_out,

    // read port
    input                   rd_clk,
    input                   rd_en,
    output [DATA_WIDTH-1:0] rd_data,
    output                  empty_out

);

    // ========================= Signal declaration =========================

    // write port
    wire                  wr_rst_n;
    wire [ADDR_WIDTH-1:0] wr_ptr;
    wire [ADDR_WIDTH-1:0] wr_ptr_gray;
    wire [ADDR_WIDTH:0]   wr_ptr_ext;
    wire [ADDR_WIDTH:0]   wr_ptr_ext_gray;
    wire [ADDR_WIDTH:0]   wr_ptr_gray_sync;
    wire                  ram_wen;
    wire                  full;

    // read port
    wire                  rd_rst_n;
    wire [ADDR_WIDTH-1:0] rd_ptr;
    wire [ADDR_WIDTH-1:0] rd_ptr_gray;
    wire [ADDR_WIDTH:0]   rd_ptr_ext;
    wire [ADDR_WIDTH:0]   rd_ptr_ext_gray;
    wire [ADDR_WIDTH:0]   rd_ptr_gray_sync;
    wire                  ram_ren;
    wire                  empty;

    // ======================================================================



    // ============================= Reset sync =============================
    
    // write reset
    rst #(
        .SYNC_STAGES (2)
    ) u_rst_wr(
        .clk         (wr_clk),
        .async_rst_n (rst_glb_n),
        .sync_rst_n  (wr_rst_n)
    );

    // read reset
    rst #(
        .SYNC_STAGES (2)
    ) u_rst_rd(
        .clk         (rd_clk),
        .async_rst_n (rst_glb_n),
        .sync_rst_n  (rd_rst_n)
    );

    // ======================================================================



    // ========================== Pointer bin2gray ==========================

    bin2gray #(
        .WIDTH      (ADDR_WIDTH)
    ) u_bin2gray_wr(
        .bin        (wr_ptr),
        .gray       (wr_ptr_gray)
    );

    bin2gray #(
        .WIDTH      (ADDR_WIDTH)
    ) u_bin2gray_rd(
        .bin        (rd_ptr),
        .gray       (rd_ptr_gray)
    );

    // ======================================================================




    // ========================= Port instantiating =========================
    
    // write port
    wr_ctrl #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_wr_ctrl(
        .wr_clk     (wr_clk),
        .rst_n      (wr_rst_n),
        .full       (full),
        .full_out   (full_out),

        .wr_en_sys  (wr_en),
        .ram_wen    (ram_wen),
        .wr_ptr_ram (wr_ptr),
        .wr_ptr_ext (wr_ptr_ext)
    );

    // read port
    rd_ctrl #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_rd_ctrl(
        .rd_clk     (rd_clk),
        .rst_n      (rd_rst_n),
        .empty      (empty),
        .empty_out  (empty_out),

        .rd_en_sys  (rd_en),
        .ram_ren    (ram_ren),
        .rd_ptr_ram (rd_ptr),
        .rd_ptr_ext (rd_ptr_ext)
    );

    // ======================================================================



    // =========================== Full generation ===========================
    
    bin2gray #(
        .WIDTH      (ADDR_WIDTH+1)
    ) u_bin2gray_full(
        .bin        (rd_ptr_ext),
        .gray       (rd_ptr_ext_gray)
    );

    sync #(
        .ADDR_WIDTH (ADDR_WIDTH+1)
    ) u_sync_full (
        .clk_trg    (wr_clk),
        .rst_n_trg  (wr_rst_n),
        .addr_src   (rd_ptr_ext_gray),
        .addr_trg   (rd_ptr_gray_sync)
    );

    flag #(
        .STATE      (1),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_flag_full (
        .clk        (wr_clk),
        .rst_n      (wr_rst_n),
        .ptr_lc     (wr_ptr_ext_gray),
        .ptr_rmt    (rd_ptr_gray_sync),
        .flag       (full)
    );

    assign full_out = full;

    // =======================================================================




    // =========================== Empty generation ===========================

    bin2gray #(
        .WIDTH      (ADDR_WIDTH+1)
    ) u_bin2gray_empty(
        .bin        (wr_ptr_ext),
        .gray       (wr_ptr_ext_gray)
    );

    sync #(
        .ADDR_WIDTH (ADDR_WIDTH+1)
    ) u_sync_empty (
        .clk_trg    (rd_clk),
        .rst_n_trg  (rd_rst_n),
        .addr_src   (wr_ptr_ext_gray),
        .addr_trg   (wr_ptr_gray_sync)
    );

    flag #(
        .STATE      (0),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_flag_empty (
        .clk        (rd_clk),
        .rst_n      (rd_rst_n),
        .ptr_lc     (rd_ptr_ext_gray),
        .ptr_rmt    (wr_ptr_gray_sync),
        .flag       (empty)
    );

    assign empty_out = empty;

    // ========================================================================





    // ========================== RAM instantiating ==========================

    ram #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .OUTPUT_REG (OUTPUT_REG),
        .RAM_TYPE   (RAM_TYPE)
    ) u_ram(
        .rst_n      (rd_rst_n),
        .wr_clk     (wr_clk),
        .wr_en      (wr_en),
        .wr_ptr     (wr_ptr),
        .wr_data    (wr_data),

        .rd_clk     (rd_clk),
        .rd_en      (rd_en),
        .rd_ptr     (rd_ptr),
        .rd_data    (rd_data)
    );

    // =======================================================================



endmodule