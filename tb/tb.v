`timescale 1ns / 1ps

module tb;

    // =========================================================================
    // Parameters 
    // =========================================================================
    parameter DEPTH         = 16;
    parameter DATA_WIDTH    = 32;
    parameter ADDR_WIDTH    = 4;
    parameter OUTPUT_REG    = 1; 
    parameter RAM_TYPE      = "block"; // block | distributed | register | ultra
    
    // Clock periods 
    parameter WR_CLK_PERIOD = 10; // 10 ns
    parameter RD_CLK_PERIOD = 12; // 12 ns

    // =========================================================================
    // Signals Declaration (
    // =========================================================================

    // System
    reg  rst_glb_n;  // global reset, low active

    // Write Port
    reg  wr_clk;
    reg  wr_en;
    reg  [DATA_WIDTH-1:0]   wr_data;
    wire full_out;

    // Read Port
    reg  rd_clk;
    reg  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire empty_out;

    // Testbench Variables
    reg [DATA_WIDTH-1:0] expected_data;
    reg [ADDR_WIDTH-1:0] write_count;
    reg [ADDR_WIDTH-1:0] read_count;
    // memory model for verification
    reg [DATA_WIDTH-1:0] mem_model [0:DEPTH-1]; 
    integer i;
    // last valid data for blocking
    reg [DATA_WIDTH-1:0] last_valid_rd_data; 

    // =========================================================================
    // Clock Generation
    // =========================================================================

    // Write Clock
    initial begin
        wr_clk = 1'b0;
        forever #(WR_CLK_PERIOD / 2) wr_clk = ~wr_clk;
    end

    // Read Clock
    initial begin
        rd_clk = 1'b0;
        forever #(RD_CLK_PERIOD / 2) rd_clk = ~rd_clk;
    end

    // =========================================================================
    // Instantiate Device Under Test (DUT)
    // =========================================================================
    async_fifo #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .OUTPUT_REG (OUTPUT_REG),
        .RAM_TYPE   (RAM_TYPE)
    ) u_async_fifo (
        .rst_glb_n  (rst_glb_n),

        .wr_clk     (wr_clk),
        .wr_en      (wr_en),
        .wr_data    (wr_data),
        .full_out   (full_out),

        .rd_clk     (rd_clk),
        .rd_en      (rd_en),
        .rd_data    (rd_data),
        .empty_out  (empty_out)
    );

    // =========================================================================
    // Main Test Sequence
    // =========================================================================

    initial begin // <--- initial begin
        $display("=========================================");
        $display("   Asynchronous FIFO Testbench Start   ");
        $display("=========================================");
        
        // 1. Initial Setup and Reset
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_data = 0; // Start data at 0
        write_count = 0;
        read_count = 0;
        last_valid_rd_data = {DATA_WIDTH{1'b0}};

        // Assert Reset (low active)
        rst_glb_n = 1'b0;
        $display("@ %t: Asserting Global Reset (rst_glb_n = 0)", $time);
        
        # (WR_CLK_PERIOD * 5); 

        // Deassert Reset
        rst_glb_n = 1'b1;
        $display("@ %t: Deasserting Global Reset (rst_glb_n = 1)", $time);

        # (WR_CLK_PERIOD * 5); 
        
        // Wait an extra clock cycle for full state settling
        @(posedge wr_clk); 
        
        if (empty_out !== 1'b1 || full_out !== 1'b0) begin
            $error("@ %t: Reset check failed! Empty: %b, Full: %b. Expected: 1/0", $time, empty_out, full_out);
        end else begin
            $display("@ %t: Initial state check passed (Empty, Not Full).", $time);
        end

        // 2. Write to FIFO until Full (exactly DEPTH entries)
        $display("--- Starting Write Test (exactly DEPTH entries) ---");
        wr_en = 1'b1;
        
        // Loop DEPTH times (i=0 to DEPTH-1)
        for (i = 0; i < DEPTH; i = i + 1) begin
            
            mem_model[i] = wr_data; // Store current data (i.e., D_0 to D_15)
            
            // Clock in the data
            @(posedge wr_clk);
            
            // Check that the full flag is NOT asserted prematurely (for i < DEPTH - 1)
            if (i < DEPTH - 1 && full_out == 1'b1) begin
                $error("@ %t: Full flag asserted too early at entry %0d!", $time, i);
            end
            
            write_count = write_count + 1;
            
            $display("@ %t: Wrote data %0d at address %0d.", $time, wr_data, i);
            wr_data = i + 1; // Prepare next data
        end
        
        // CRITICAL: Stop write enable immediately after the last data (15) is clocked in.
        wr_en = 1'b0; 
        $display("@ %t: Write stopped (wr_en=0). Data %0d was the last written.", $time, wr_data - 1); // wr_data is now 16

        // Wait one more cycle for the full flag to update after the final write
        @(posedge wr_clk); 

        // 3. Full check and attempt to write more
        if (full_out !== 1'b1) begin
            $error("@ %t: Full flag check failed! Full is %b, Expected 1. THIS IS THE CRITICAL FULL CHECK!", $time, full_out);
        end else begin
            $display("@ %t: FIFO is Full (Full flag check passed).", $time);
        end
        
        wr_data = 999; // Data to attempt writing (should be blocked, but wr_en is already 0)
        @(posedge wr_clk);
        
        $display("@ %t: Attempted write when full (data 999) with wr_en=0. Write should be blocked by DUT logic.", $time);


        // 4. Read from FIFO until Empty, verifying data
        $display("--- Starting Read Test (until empty) ---");
        rd_en = 1'b1;

        // Primer cycle for OUTPUT_REG=1 latency. This loads the first data (D0).
        @(posedge rd_clk); 
        
        // Read DEPTH - 1 entries (i=0 to 14) with rd_en=1
        for (i = 0; i < DEPTH - 1; i = i + 1) begin
            expected_data = mem_model[i];
            
            // Wait for one read clock edge. Data D_i is now available on rd_data.
            @(posedge rd_clk);
            
            // Check that the empty flag is NOT asserted prematurely
            if (empty_out == 1'b1) begin
                $error("@ %t: Empty flag asserted too early at entry %0d!", $time, i);
            end
            
            // Data match check 
            if (rd_data !== expected_data) begin
                $error("@ %t: Data mismatch at read count %0d! Got %0d, Expected %0d.", $time, i, rd_data, expected_data);
            end else begin
                $display("@ %t: Read data %0d (Matches) at address %0d.", $time, rd_data, i);
            end

            read_count = read_count + 1;
        end // end of read loop (i=0 to 14, 15 reads done)
        
        // --- Manually handle the final read (i = DEPTH - 1 = 15) ---
        i = DEPTH - 1;
        expected_data = mem_model[i];
        
        // Wait for the final read clock edge. 
        @(posedge rd_clk);
        
        // Check data match
        if (rd_data !== expected_data) begin
            $error("@ %t: Data mismatch at final read count %0d! Got %0d, Expected %0d.", $time, i, rd_data, expected_data);
        end else begin
            $display("@ %t: Read data %0d (Matches) at address %0d.", $time, rd_data, i);
        end

        // Store the last correct data value (15)
        last_valid_rd_data = expected_data; 
        read_count = read_count + 1;

        // pull down rd_en right after the last valid read (before the rising edge)
        rd_en = 1'b0; 
        $display("@ %t: Last valid data read. Dropping rd_en to prevent pointer increment on next clock.", $time);
        
        // Wait for a small delay to ensure rd_en has propagated low
        #1;
        $display("@ %t: Empty detected combinatorially after last read. rd_en dropped.", $time);
        
        // 5. Final Empty check and hold data verification
        
        // Wait for the clock edge. Since rd_en is now low, the register should hold data 15.
        @(posedge rd_clk);
        
        if (empty_out !== 1'b1) begin
            $error("@ %t: Empty flag check failed! Empty is %b, Expected 1. THIS IS THE CRITICAL EMPTY CHECK! (DUT Flag Issue)", $time, empty_out);
        end else begin
            $display("@ %t: FIFO is Empty (Empty flag check passed).", $time);
        end
        
        // rd_en is already 0
        $display("@ %t: Current rd_data is %0d. Read should be blocked/data held (Expected %0d).", $time, rd_data, last_valid_rd_data);
        
        @(posedge rd_clk); // Wait one more cycle to confirm data hold
        
        // Verify rd_data has not changed (should hold last valid data: 15)
        if (rd_data === last_valid_rd_data) begin
            $display("@ %t: Read blocked check passed. rd_data remains %0d.", $time, last_valid_rd_data);
        end else begin
            $error("@ %t: Read blocked check failed. rd_data should be %0d, got %0d. THIS IS THE READ BLOCKED CHECK! (DUT failing to hold last data)", $time, last_valid_rd_data, rd_data);
        end

        $display("=========================================");
        $display("    Asynchronous FIFO Testbench Finished  ");
        $display("=========================================");
        
        $finish;
    end // <--- Closing the initial begin block

endmodule