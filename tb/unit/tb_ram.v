`timescale 1ns/1ps

module tb_ram;

    parameter DEPTH      = 16;
    parameter DATA_WIDTH = 8;
    parameter OUTPUT_REG = 2;
    parameter RAM_TYPE   = "register";

    localparam ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    // signals
    wire rst_n;
    wire wr_clk;
    wire rd_clk;

    reg wr_en, rd_en;
    reg [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    reg [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;

    integer i;

    // ====================== Instantiate clocks & reset ======================
    clk_gen #(.PERIOD(10)) i_clk_gen_wr (.clk(wr_clk));
    clk_gen #(.PERIOD(14)) i_clk_gen_rd (.clk(rd_clk));
    rst_gen                i_rst_gen    (.rst_n(rst_n));

    // ====================== Instantiate RAM ======================
    tp_ram #(
        .DEPTH          (DEPTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .OUTPUT_REG     (OUTPUT_REG),
        .RAM_TYPE       (RAM_TYPE)
    ) i_tp_ram (
        .rst_n          (rst_n),
        .wr_clk         (wr_clk),
        .wr_en          (wr_en),
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .rd_clk         (rd_clk),
        .rd_en          (rd_en),
        .rd_addr        (rd_addr),
        .rd_data        (rd_data)
    );

    // ====================== Stimulus ======================
    initial begin
        wr_en = 0;
        rd_en = 0;
        wr_addr = 0;
        rd_addr = 0;
        wr_data = 0;

        // wait for reset release
        @(posedge rst_n);

        // write sequence
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge wr_clk);
                wr_en <= 1;
                wr_addr <= i;
                wr_data <= i*10;
        end
        @(posedge wr_clk) wr_en <= 0;

        // read sequence
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge rd_clk);
                rd_en <= 1;
                rd_addr <= i;
        end
        @(posedge rd_clk) rd_en <= 0;

        // random test
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge wr_clk);
                wr_en   <= $random % 2;
                wr_addr <= $random % DEPTH;
                wr_data <= $random;

            @(posedge rd_clk);
                rd_en   <= $random % 2;
                rd_addr <= $random % DEPTH;
        end

        #50;
    end

    // ====================== Monitor ======================
    initial begin
        $dumpfile("tb_ram.vcd");
        $dumpvars(0, tb_ram);
        $display("Time\twr_en\twr_addr\twr_data\trd_en\trd_addr\trd_data");
        $monitor("%0t\t%b\t%0d\t%0d\t%b\t%0d\t%0d",
                 $time, wr_en, wr_addr, wr_data, rd_en, rd_addr, rd_data);
    end

endmodule
