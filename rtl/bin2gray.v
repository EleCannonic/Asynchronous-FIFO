`timescale 1ns / 1ps

module bin2gray #(

    parameter WIDTH = 4

)
(
    
    input  [WIDTH-1:0] bin,
    output [WIDTH-1:0] gray
);

    assign gray = (bin >> 1) ^ bin;

endmodule