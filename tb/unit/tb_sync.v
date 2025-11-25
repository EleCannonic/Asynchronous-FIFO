`timescale 1ns / 1ps

module tb_sync;

    // Parameters
    parameter ADDR_WIDTH = 8;
    localparam T_SRC = 10; // Source Clock Period (clk_src edges at 5, 15, 25, 35, 45, 55, 65, 75, 85...)
    localparam T_TRG = 14; // Target Clock Period (clk_trg edges at 7, 21, 35, 49, 63, 77, 91...)

    // Signals declaration
    reg clk_src;
    reg clk_trg;
    reg rst_trg_n;
    reg [ADDR_WIDTH-1:0] addr_src_binary; 
    reg [ADDR_WIDTH-1:0] addr_src;       

    wire [ADDR_WIDTH-1:0] addr_trg; 
    
    // access internal signals
    wire [ADDR_WIDTH-1:0] sync_reg1; 
    wire [ADDR_WIDTH-1:0] sync_reg2; 

    // =================================================================
    // 1. Clock Generation
    // =================================================================

    initial begin
        clk_src = 1'b0;
        forever #(T_SRC/2) clk_src = ~clk_src;
    end

    initial begin
        clk_trg = 1'b0;
        forever #(T_TRG/2) clk_trg = ~clk_trg;
    end

    // =================================================================
    // 2. Gray Code Conversion Function
    // =================================================================

    function [ADDR_WIDTH-1:0] bin_to_gray;
        input [ADDR_WIDTH-1:0] bin;
        bin_to_gray = (bin >> 1) ^ bin;
    endfunction

    // =================================================================
    // 3. DUT Instantiation
    // =================================================================

    sync #(.ADDR_WIDTH(ADDR_WIDTH)) u_sync (
        .clk_trg    (clk_trg),
        .rst_trg_n  (rst_trg_n),
        .addr_src   (addr_src),
        .addr_trg   (addr_trg)
    );
    
    // access internal memeory
    assign sync_reg1 = u_sync.sync_reg1;
    assign sync_reg2 = u_sync.sync_reg2;

    // =================================================================
    // 4. Test Scenario and Stimulus
    // =================================================================

    initial begin
        $dumpfile("sync.vcd");
        $dumpvars(0, tb_sync);
        
        rst_trg_n = 1'b0; 
        addr_src_binary = 8'h00; 

        #15 rst_trg_n = 1'b1; // T=15ns: Deassert reset

        // Standard transitions driven by clk_src (T=25ns, 35ns, 45ns, 55ns, 65ns)
        @(posedge clk_src) addr_src_binary = 1; 
        @(posedge clk_src) addr_src_binary = 2; 
        @(posedge clk_src) addr_src_binary = 3; 
        @(posedge clk_src) addr_src_binary = 4; 
        @(posedge clk_src) addr_src_binary = 5; 
        
        
        // ================================ Setup Violation ================================
        // target edge T=77ns
        // source edge T=75ns
        
        $display("--------------------------------------------------------------------------------");
        $display("Time: %0t ns | Inducing clock-driven setup violation (2ns margin < 3.0ns required)", $time);
        
        @(posedge clk_src) addr_src_binary = 6; // T=75ns: Data changes here
        
        
        // wait for sync
        # (T_TRG * 4) $display("Time: %0t ns | Synchronization expected to be complete.", $time);
        
        // final check
        @(posedge clk_src) addr_src_binary = 7;

        #20 $finish;
    end
    
    // Gray Code mapping
    always @(addr_src_binary) begin
        addr_src = bin_to_gray(addr_src_binary);
    end

    // 监控 'X' state - 持续监控 sync_reg1 和 sync_reg2
    always @(sync_reg1 or sync_reg2) begin
        if (^sync_reg1 === 1'bx) begin // 检查 sync_reg1 
            $display("!!! WARNING: Time %0t ns | Stage 1 (sync_reg1) entered 'X' state: %h", $time, sync_reg1);
        end
        if (^sync_reg2 === 1'bx) begin // 检查 sync_reg2
            $display("!!! WARNING: Time %0t ns | Stage 2 (sync_reg2) entered 'X' state: %h", $time, sync_reg2);
        end
    end
    
    // Monitor for console output
    initial begin
        $monitor("Time: %0t | clk_src: %b | clk_trg: %b | Addr_SRC: %h | Reg1: %h | Reg2: %h | Addr_TRG: %h",
                 $time, clk_src, clk_trg, addr_src, sync_reg1, sync_reg2, addr_trg);
    end

endmodule