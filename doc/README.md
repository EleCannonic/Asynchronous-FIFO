# Asynchronous FIFO (Asynchronous First-In-First-Out) Design Documentation

## Overview
A parameterized, dual-clock domain asynchronous FIFO module written in Verilog. This module implements a reliable data buffer between different clock domains using Gray code pointer synchronization and configurable memory types. Ideal for clock domain crossing (CDC) applications and data buffering in multi-clock systems.

## Features
- **Independent Clock Domains**: Read and write interfaces operate on separate clocks
- **Parameterized Design**: Configurable depth, data width, and memory type
- **Gray Code Synchronization**: Safe pointer transfer between clock domains
- **Multiple RAM Types**: Support for Block RAM, Distributed RAM, UltraRAM, and register-based implementation
- **Output Pipeline Registers**: Configurable output register stages for timing improvement
- **Asynchronous Reset Synchronization**: Proper reset handling for each clock domain
- **Full/Empty Flag Generation**: Reliable status flags with proper synchronization
- **Resource Optimization**: Configurable implementation based on performance requirements

## Module Hierarchy
```
async_fifo (top)
├── rst (reset synchronizer, 2 instances)
├── wr_ctrl (write controller)
├── rd_ctrl (read controller)
├── ram (memory core)
├── bin2gray (binary to Gray converter, 4 instances)
├── sync (pointer synchronizer, 2 instances)
└── flag (full/empty flag generator, 2 instances)
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DEPTH` | integer | 16 | FIFO depth (number of entries) |
| `DATA_WIDTH` | integer | 32 | Data width in bits |
| `ADDR_WIDTH` | integer | 4 | Address width (Recommand `$clog2(DEPTH)$`) |
| `OUTPUT_REG` | integer | 1 | Number of output pipeline registers (0 for combinational output) |
| `RAM_TYPE` | string | "block" | Memory implementation type: "block", "distributed", "register", or "ultra" |

## Ports

### Global Ports
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `rst_glb_n` | input | 1 | Global asynchronous reset (active low) |

### Write Interface (Write Clock Domain)
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `wr_clk` | input | 1 | Write clock |
| `wr_en` | input | 1 | Write enable |
| `wr_data` | input | DATA_WIDTH | Write data |
| `full_out` | output | 1 | FIFO full flag |

### Read Interface (Read Clock Domain)
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `rd_clk` | input | 1 | Read clock |
| `rd_en` | input | 1 | Read enable |
| `rd_data` | output | DATA_WIDTH | Read data |
| `empty_out` | output | 1 | FIFO empty flag |

## Usage Examples

### Basic 32-bit FIFO with Block RAM
```verilog
// 32-bit wide, 16-deep FIFO with block RAM
async_fifo #(
    .DEPTH      (16),
    .DATA_WIDTH (32),
    .ADDR_WIDTH (4),
    .OUTPUT_REG (1),
    .RAM_TYPE   ("block")
) u_async_fifo (
    .rst_glb_n  (rst_n),
    .wr_clk     (wr_clk),
    .wr_en      (wr_en),
    .wr_data    (wr_data),
    .full_out   (full),
    .rd_clk     (rd_clk),
    .rd_en      (rd_en),
    .rd_data    (rd_data),
    .empty_out  (empty)
);
```

### Deep FIFO with Distributed RAM
```verilog
// 64-bit wide, 256-deep FIFO with distributed RAM
async_fifo #(
    .DEPTH      (256),
    .DATA_WIDTH (64),
    .ADDR_WIDTH (8),  // log2(256)
    .OUTPUT_REG (2),  // Two pipeline stages for better timing
    .RAM_TYPE   ("distributed")
) u_async_fifo (
    .rst_glb_n  (sys_rst_n),
    .wr_clk     (clk_domain_a),
    .wr_en      (data_valid_a),
    .wr_data    (data_from_domain_a),
    .full_out   (fifo_full),
    .rd_clk     (clk_domain_b),
    .rd_en      (data_req_b),
    .rd_data    (data_to_domain_b),
    .empty_out  (fifo_empty)
);
```

### Register-based FIFO for Small Buffers
```verilog
// 8-bit wide, 4-deep FIFO using registers (low latency)
async_fifo #(
    .DEPTH      (4),
    .DATA_WIDTH (8),
    .ADDR_WIDTH (2),  // log2(4)
    .OUTPUT_REG (0),  // No output registers for minimum latency
    .RAM_TYPE   ("register")
) u_small_fifo (
    .rst_glb_n  (rst_n),
    .wr_clk     (fast_clk),
    .wr_en      (fast_wr_en),
    .wr_data    (fast_data),
    .full_out   (fast_full),
    .rd_clk     (slow_clk),
    .rd_en      (slow_rd_en),
    .rd_data    (slow_data),
    .empty_out  (slow_empty)
);
```

## Architecture Details

### Structure Scheme

![FIFO Scheme](fifo_scheme.png)

### Reset

Global asynchronous, low active reset.
But the reset will be synchronized before acting in a specific domain by Reset synchronizer.
This will bring a delay of 2 cycles.


### Memory Implementation Options
1. **Block RAM**: Dedicated RAM blocks, efficient for large memories
2. **Distributed RAM**: Uses FPGA LUTs, good for small to medium memories
3. **UltraRAM**: Specific to certain FPGA families (e.g., Xilinx UltraScale+)
4. **Register-based**: Uses flip-flops, lowest latency but highest resource usage

## Timing Characteristics

### Clock Domain Requirements
- **No Frequency Relationship**: Read and write clocks can have any frequency ratio
- **Minimum Pulse Width**: Must meet minimum pulse requirements of target technology
- **Setup/Hold Times**: Synchronizer flip-flops must meet timing requirements

### Maximum Operating Frequency
- Limited by target technology and critical paths
- Pointer comparison logic typically sets the maximum frequency
- Output registers can improve timing at the cost of latency

### Latency
- **Write to Read Latency**: Minimum 3 read clock cycles (synchronization + flag generation)
- **Output Pipeline Latency**: Additional cycles based on `OUTPUT_REG` parameter
- **Flag Update Latency**: Full/empty flags update within 2-3 clock cycles after pointer changes

## Synthesis Notes

### Resource Utilization
- Scales with `DEPTH × DATA_WIDTH` for memory elements
- Control logic scales with `ADDR_WIDTH`
- Synchronizers add fixed overhead per clock domain


## Limitations

### Depth Restrictions
- Maximum depth limited by address width (typically 2^ADDR_WIDTH)
- Very deep FIFOs may have longer flag update latency

### Memory Type Constraints
- Block RAM does not support asynchronous read (`OUTPUT_REG` must be ≥ 1)
- UltraRAM only available in specific FPGA families
- Register-based implementation consumes significant flip-flops especially for large RAM.

### Performance Considerations
- Gray code conversion adds combinatorial delay
- Flag generation logic may become critical path
- Synchronizer latency affects response time to status changes

### Functional Limitations
- Not suitable for packet-based operations without additional logic
- No partial reset capability
- No watermark or almost-full/almost-empty flags

## Simulation Report

With the testbench provided in this project (`tb.v`).
The RTL passes the test. Here is the testbench report.

```
=========================================
   Asynchronous FIFO Testbench Start   
=========================================
@                    0: Asserting Global Reset (rst_glb_n = 0)
@                50000: Deasserting Global Reset (rst_glb_n = 1)
@               105000: Initial state check passed (Empty, Not Full).
--- Starting Write Test (exactly DEPTH entries) ---
@               115000: Wrote data 0 at address 0.
@               125000: Wrote data 1 at address 1.
@               135000: Wrote data 2 at address 2.
@               145000: Wrote data 3 at address 3.
@               155000: Wrote data 4 at address 4.
@               165000: Wrote data 5 at address 5.
@               175000: Wrote data 6 at address 6.
@               185000: Wrote data 7 at address 7.
@               195000: Wrote data 8 at address 8.
@               205000: Wrote data 9 at address 9.
@               215000: Wrote data 10 at address 10.
@               225000: Wrote data 11 at address 11.
@               235000: Wrote data 12 at address 12.
@               245000: Wrote data 13 at address 13.
@               255000: Wrote data 14 at address 14.
@               265000: Wrote data 15 at address 15.
@               265000: Write stopped (wr_en=0). Data 15 was the last written.
@               275000: FIFO is Full (Full flag check passed).
@               285000: Attempted write when full (data 999) with wr_en=0. Write should be blocked by DUT logic.
--- Starting Read Test (until empty) ---
@               306000: Read data 0 (Matches) at address 0.
@               318000: Read data 1 (Matches) at address 1.
@               330000: Read data 2 (Matches) at address 2.
@               342000: Read data 3 (Matches) at address 3.
@               354000: Read data 4 (Matches) at address 4.
@               366000: Read data 5 (Matches) at address 5.
@               378000: Read data 6 (Matches) at address 6.
@               390000: Read data 7 (Matches) at address 7.
@               402000: Read data 8 (Matches) at address 8.
@               414000: Read data 9 (Matches) at address 9.
@               426000: Read data 10 (Matches) at address 10.
@               438000: Read data 11 (Matches) at address 11.
@               450000: Read data 12 (Matches) at address 12.
@               462000: Read data 13 (Matches) at address 13.
@               474000: Read data 14 (Matches) at address 14.
@               486000: Read data 15 (Matches) at address 15.
@               486000: Last valid data read. Dropping rd_en to prevent pointer increment on next clock.
@               487000: Empty detected combinatorially after last read. rd_en dropped.
@               498000: FIFO is Empty (Empty flag check passed).
@               498000: Current rd_data is 15. Read should be blocked/data held (Expected 15).
@               510000: Read blocked check passed. rd_data remains 15.
=========================================
    Asynchronous FIFO Testbench Finished  
=========================================
```



## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025.12.03 | Initial release |

