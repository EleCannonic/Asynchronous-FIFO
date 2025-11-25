`timescale 1ns/1ps

module clk_gen #(

    parameter PERIOD = 10 // ns
)(
    output reg clk
);
    
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

endmodule
