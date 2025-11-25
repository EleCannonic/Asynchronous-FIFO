`timescale 1ns / 1ps

module tb_bin2gray;

    // ====================== Parameters ======================
    parameter WIDTH = 8;
    
    // ====================== Signals ======================
    reg  [WIDTH-1:0] bin_in;
    wire [WIDTH-1:0] gray_out;
    reg  [WIDTH-1:0] expected_gray;  

    integer i;

    // ====================== Instantiate DUT ======================
    bin2gray #(
        .WIDTH (WIDTH)
    ) i_bin2gray (
        .bin   (bin_in),
        .gray  (gray_out)
    );

    // ====================== Stimulus ======================
    initial begin
        $display("=================================================");
        $display("Starting bin2gray Testbench (WIDTH=%0d)", WIDTH);
        $display("Time\tbin(Dec)\tbin(Hex)\tgray(Dec)\tgray(Hex)\tExpected");
        $display("-------------------------------------------------");

        // initializing input
        bin_in = {WIDTH{1'b0}}; // bin_in = 0

        // traverse all inputs：0 to 2^WIDTH - 1 (255)
        for (i = 0; i < (1 << WIDTH); i = i + 1) begin
            
            // apply input
            #10 bin_in = i; 

            // verify with expected Gray
            expected_gray = (bin_in >> 1) ^ bin_in;
            
            #1 $display("%0t\t%0d\t\t%h\t\t%0d\t\t%h\t\t%h",
                        $time, 
                        bin_in, 
                        bin_in, 
                        gray_out, 
                        gray_out, 
                        expected_gray);

            // check
            if (gray_out !== expected_gray) begin
                $display("!!! ERROR: bin=%h, Got gray=%h, Expected gray=%h", bin_in, gray_out, expected_gray);
                $finish;
            end
        end

        // end
        #10 $display("-------------------------------------------------");
        $display("Test finished successfully. All %0d vectors passed.", (1 << WIDTH));
        $display("=================================================");
        $finish;
    end

    // ====================== Waveform Dumping ======================
    initial begin
        $dumpfile("tb_bin2gray.vcd");
        $dumpvars(0, tb_bin2gray);
    end

endmodule