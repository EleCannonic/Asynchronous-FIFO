`timescale 1ns / 1ps

module tb;

    // ================== Parameters ==================
    parameter DEPTH         = 16;
    parameter DATA_WIDTH    = 8;
    parameter ADDR_WIDTH    = 4; // log2(DEPTH)

    // Clock Periods
    parameter WR_CLK_PERIOD = 10; // 100 MHz
    parameter RD_CLK_PERIOD = 7;  // ~142.8 MHz

    // ================== Signals ==================

    // Clocks and Reset
    reg   wr_clk;
    reg   rd_clk;
    reg   rst_glb_n;

    // Write Port
    reg   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire  full_out;

    // Read Port
    reg   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire  empty_out;

    // Test Bench Variables
    integer i;
    integer errors = 0;
    integer data_in = 0;
    integer data_out = 0;


    // ================== Clock Generation ==================

    initial begin
        wr_clk = 1'b0;
        forever #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 1'b0;
        forever #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;
    end


    // ================== DUT Instantiation ==================

    async_fifo #(
        .DEPTH         (DEPTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .OUTPUT_REG    (1) // Keep output register for synchronous RAM read
    ) u_async_fifo (
        .rst_glb_n     (rst_glb_n),

        .wr_clk        (wr_clk),
        .wr_en         (wr_en),
        .wr_data       (wr_data),
        .full_out      (full_out),

        .rd_clk        (rd_clk),
        .rd_en         (rd_en),
        .rd_data       (rd_data),
        .empty_out     (empty_out)
    );

    // ================== Test Sequence ==================

    initial begin
        // Initialize
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_data = 8'h00;
        rst_glb_n = 1'b0;

        // Apply Reset
        # (2 * WR_CLK_PERIOD) rst_glb_n = 1'b1;
        $display("\n===================== Start Test =====================");

        // --- 1. Fill the FIFO ---
        $display("Time %0t: Start filling the FIFO.", $time);
        #10;
        wr_en = 1'b1;
        
        // Write DEPTH items (0 to DEPTH-1)
        for (i = 0; i < DEPTH; i = i + 1) begin
            data_in = i;
            wr_data = data_in;
            @(posedge wr_clk);
            #1;
            if (full_out) $display("Time %0t: Full flag raised prematurely at %0d writes!", $time, i);
        end

        // Wait for 'full' flag to assert
        // FIX: Add 1 extra cycle for 2-stage synchronization delay
        @(posedge wr_clk) #1; 
        @(posedge wr_clk) #1; 
        if (!full_out) $display("Time %0t: ERROR: Full flag did not assert after %0d writes!", $time, DEPTH);
        
        wr_en = 1'b0;
        $display("Time %0t: FIFO is now FULL.", $time);


        // --- 2. Empty the FIFO ---
        $display("Time %0t: Start emptying the FIFO.", $time);
        rd_en = 1'b1;
        
        // FIX 1: RAM Read Pipeline Compensation.
        // Issue Read #0 command. Data 0 enters the 1-cycle pipeline.
        @(posedge rd_clk); 
        
        // Read DEPTH items (0 to DEPTH-1)
        for (i = 0; i < DEPTH; i = i + 1) begin
            data_out = i;
            #1; // Wait for data (from previous cycle) to stabilize
            
            if (rd_data !== data_out) begin
                $display("Time %0t: ERROR: Expected %h, Got %h (Read #%0d)", $time, data_out, rd_data, i);
                errors = errors + 1;
            end
            
            if (empty_out) $display("Time %0t: Empty flag raised prematurely at %0d reads!", $time, i);
            
            // Issue next Read command, which is also the wait for the next cycle
            @(posedge rd_clk); 
        end
        
        // FIX 2: Empty Flag Synchronization Compensation.
        // The pointer was updated on the last @(posedge rd_clk) in the loop.
        // Need 1 more cycle for the 2-stage synchronization to complete.
        @(posedge rd_clk) #1;
        if (!empty_out) $display("Time %0t: ERROR: Empty flag did not assert after %0d reads!", $time, DEPTH);
        
        rd_en = 1'b0;
        $display("Time %0t: FIFO is now EMPTY.", $time);

        
        // --- 3. Partial write/read test ---
        $display("Time %0t: Start partial R/W test.", $time);
        // Write 4 items (16 to 19)
        wr_en = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            data_in = DEPTH + i;
            wr_data = data_in;
            @(posedge wr_clk);
        end
        wr_en = 1'b0;
        $display("Time %0t: Wrote 4 items.", $time);

        // Read 2 items (16 and 17)
        rd_en = 1'b1;
        
        // FIX 3: Apply RAM Read Pipeline Compensation again.
        // Issue Read #16 command. Data 16 enters the 1-cycle pipeline.
        @(posedge rd_clk); 
        
        for (i = 0; i < 2; i = i + 1) begin
            data_out = DEPTH + i;
            #1; // Wait for data (from previous cycle) to stabilize
            
            if (rd_data !== data_out) begin
                $display("Time %0t: ERROR: Expected %h, Got %h (Partial Read #%0d)", $time, data_out, rd_data, i);
                errors = errors + 1;
            end
            
            // Issue next Read command, which is also the wait for the next cycle
            @(posedge rd_clk); 
        end
        rd_en = 1'b0;
        $display("Time %0t: Read 2 items.", $time);
        
        
        // --- Final Check ---
        # (2 * WR_CLK_PERIOD);
        # (2 * RD_CLK_PERIOD);
        
        if (errors == 0) begin
            $display("\n===================== Test PASSED: No data errors detected! =====================");
        end else begin
            $display("\n===================== Test FAILED: %0d data errors detected. ======================", errors);
        end

    end
    
endmodule