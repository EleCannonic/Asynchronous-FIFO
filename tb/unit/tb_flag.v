`timescale 1ns / 1ps

module tb_flag;

    // param
    parameter ADDR_WIDTH = 8;
    localparam DEPTH = 1 << (ADDR_WIDTH-1);       // FIFO depth = 128

    // signal
    reg  clk;
    reg  rst_n;
    reg  [ADDR_WIDTH-1:0] addr_rd;
    reg  [ADDR_WIDTH-1:0] addr_wr;

    wire flag_empty;
    wire flag_full;

    // instantiaing
    flag #(
        .STATE     (0),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) i_flag_empty (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr_rd (addr_rd),
        .addr_wr (addr_wr),
        .flag    (flag_empty)
    );

    flag #(
        .STATE     (1),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) i_flag_full (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr_rd (addr_rd),
        .addr_wr (addr_wr),
        .flag    (flag_full)
    );

    // clk = 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // bin2gray
    function [ADDR_WIDTH-1:0] bin2gray;
        input [ADDR_WIDTH-1:0] bin;
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction

    // wait for n cycles
    task wait_clk;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    // checking symbols
    task check_flags;
        input expected_empty;
        input expected_full;
        input [31*8-1:0] msg;   
        begin
            @(posedge clk);  
            if (flag_empty !== expected_empty || flag_full !== expected_full) begin
                $display("*** ERROR at %0t ns ***", $time);
                $display("    Message        : %s", msg);
                $display("    addr_rd(Gray)  = %h", addr_rd);
                $display("    addr_wr(Gray)  = %h", addr_wr);
                $display("    flag_empty     = %b (expected %b)", flag_empty, expected_empty);
                $display("    flag_full      = %b (expected %b)", flag_full,   expected_full);
                $display("=====================================");
                $finish;
            end else begin
                $display("PASS at %0t ns: %s  (empty=%b, full=%b)", $time, msg, flag_empty, flag_full);
            end
        end
    endtask

    // ======================= Main Test ======================
    initial begin
        $display("\n=== flag verification start (Verilog-2001) ===\n");

        // initializing
        rst_n   = 0;
        addr_rd = 0;
        addr_wr = 0;
        #20 rst_n = 1;

        wait_clk(1);

        // 1. initial empty
        check_flags(1'b1, 1'b0, "Initial state - EMPTY");

        // 2. write
        addr_wr = bin2gray(1);
        wait_clk(2);
        check_flags(1'b0, 1'b0, "After write 1");

        // 3. read over write
        addr_rd = bin2gray(1);
        wait_clk(2);
        check_flags(1'b1, 1'b0, "Read catches up - EMPTY");

        // 4. full write
        addr_rd = 0;
        addr_wr = bin2gray(DEPTH);   // 128 -> Gray: 8'b1100_0000
        wait_clk(2);
        check_flags(1'b0, 1'b1, "FIFO FULL");

        // 5. read one, no longer full
        addr_rd = bin2gray(1);
        wait_clk(2);
        check_flags(1'b0, 1'b0, "Read one after full - NOT FULL");

        // 6. write again, full again
        addr_wr = bin2gray(DEPTH + 1);
        wait_clk(2);
        check_flags(1'b0, 1'b1, "Write one after read - FULL again");

        // 7. empty when ptr equal
        addr_rd = bin2gray(50);
        addr_wr = bin2gray(50);
        wait_clk(2);
        check_flags(1'b1, 1'b0, "Pointers equal - EMPTY");

        // 8. write full with offset
        addr_rd = bin2gray(20);
        addr_wr = bin2gray(20 + DEPTH);
        wait_clk(2);
        check_flags(1'b0, 1'b1, "Full with offset");

        // 9. reset
        rst_n = 0;
        addr_rd = 8'b0;
        addr_wr = 8'b0;
        #20 rst_n = 1;
        wait_clk(2);
        check_flags(1'b1, 1'b0, "After reset - EMPTY");

        // 10. multiple cycles
        repeat (3) begin
            addr_wr = bin2gray(DEPTH);
            addr_rd = 0;
            wait_clk(2);
            check_flags(1'b0, 1'b1, "Multi-wrap FULL");

            addr_rd = bin2gray(DEPTH);
            wait_clk(2);
            check_flags(1'b1, 1'b0, "Multi-wrap EMPTY");
        end

        $display("\n=== All Test Passed! ===\n");
        $finish;
    end

    // generate waveform
    initial begin
        $dumpfile("tb_flag.vcd");
        $dumpvars(0, tb_flag);
    end

endmodule