`timescale 1ns/1ps

module rst_gen(
    output reg rst_n
);
    initial begin
        rst_n = 0;
        #20;       // keep 20ns reset, low active
        rst_n = 1;
    end
endmodule
