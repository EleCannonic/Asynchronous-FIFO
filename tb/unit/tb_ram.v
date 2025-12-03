`timescale 1ns/1ps

module tb_ram;

    parameter DEPTH      = 16;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter OUTPUT_REG = 2;
    parameter RAM_TYPE   = "register";

    // signals
    wire rst_n;
    wire clk_wr;
    wire clk_rd;

    reg en_wr, en_rd;
    reg [ADDR_WIDTH-1:0] addr_wr, addr_rd;
    reg [DATA_WIDTH-1:0] data_wr;
    wire [DATA_WIDTH-1:0] data_rd;

    integer i;

    // ====================== Instantiate clocks & reset ======================
    clk_gen #(.PERIOD(10)) u_clk_gen_wr (.clk(clk_wr));
    clk_gen #(.PERIOD(14)) u_clk_gen_rd (.clk(clk_rd));
    rst_gen                u_rst_gen    (.rst_n(rst_n));

    // ====================== Instantiate RAM ======================
    ram #(
        .DEPTH          (DEPTH),
        .DATA_WIDTH     (DATA_WIDTH),
        .OUTPUT_REG     (OUTPUT_REG),
        .RAM_TYPE       (RAM_TYPE)
    ) u_ram (
        .rst_n          (rst_n),
        .clk_wr         (clk_wr),
        .en_wr          (en_wr),
        .addr_wr        (addr_wr),
        .data_wr        (data_wr),
        .clk_rd         (clk_rd),
        .en_rd          (en_rd),
        .addr_rd        (addr_rd),
        .data_rd        (data_rd)
    );

    // ====================== Stimulus ======================
    initial begin
        en_wr = 0;
        en_rd = 0;
        addr_wr = 0;
        addr_rd = 0;
        data_wr = 0;

        // wait for reset release
        @(posedge rst_n);

        // write sequence
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk_wr);
                en_wr <= 1;
                addr_wr <= i;
                data_wr <= i*10;
        end
        @(posedge clk_wr) en_wr <= 0;

        // read sequence
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk_rd);
                en_rd <= 1;
                addr_rd <= i;
        end
        @(posedge clk_rd) en_rd <= 0;

        // random test
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk_wr);
                en_wr   <= $random % 2;
                addr_wr <= $random % DEPTH;
                data_wr <= $random;

            @(posedge clk_rd);
                en_rd   <= $random % 2;
                addr_rd <= $random % DEPTH;
        end

        #50;
    end

    // ====================== Monitor ======================
    initial begin
        $dumpfile("tb_ram.vcd");
        $dumpvars(0, tb_ram);
        $display("Time\ten_wr\taddr_wr\tdata_wr\ten_rd\taddr_rd\tdata_rd");
        $monitor("%0t\t%b\t%0d\t%0d\t%b\t%0d\t%0d",
                 $time, en_wr, addr_wr, data_wr, en_rd, addr_rd, data_rd);
    end

endmodule
