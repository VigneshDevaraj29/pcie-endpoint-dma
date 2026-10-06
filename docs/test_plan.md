# PCIe Endpoint Transaction Layer with DMA Engine

## Test Plan

---

# 1. Purpose

This document defines the planned directed, integration, UVM, error, and coverage-driven test scenarios for the PCIe Endpoint Transaction Layer with DMA Engine project.

The objective is to verify the supported PCIe Transaction Layer functionality and DMA behavior using:

```text
Directed Unit Tests
Integration Tests
UVM Sequences
Error Injection
Assertions
Functional Coverage
Regression Testing
```

The test plan is aligned with the current project scope and does not include unsupported PCIe PHY or Data Link Layer functionality.

---

# 2. Test Categories

The project verification is divided into the following test categories:

```text
Unit Tests
Integration Tests
UVM Directed Tests
UVM Error Tests
Constrained-Random Tests
Protocol Assertions
Coverage Closure Tests
Regression Tests
```

---

# 3. Unit Test List

Current unit testbenches:

```text
tlp_rx_parser_tb.sv
bar_decoder_tb.sv
endpoint_memory_tb.sv
request_handler_tb.sv
completion_engine_tb.sv
tlp_tx_formatter_tb.sv
outstanding_req_table_tb.sv
sync_fifo_tb.sv
timeout_counter_tb.sv
dma_regs_tb.sv
dma_read_engine_tb.sv
dma_write_engine_tb.sv
dma_controller_tb.sv
```

---

# 4. TLP RX Parser Test Plan

DUT:

```text
rtl/pcie/tlp_rx_parser.sv
```

Testbench:

```text
tb/sv/unit/tlp_rx_parser_tb.sv
```

## TP-PARSER-001 — Memory Read Decode

Stimulus:

```text
Fmt  = 3DW No Data
Type = Memory
Length = 1 DW
Requester ID = valid value
Tag = valid value
Address = DWORD aligned
```

Expected:

```text
kind = TLP_KIND_MEM_RD
supported = 1
Requester ID decoded correctly
Tag decoded correctly
Address decoded correctly
Length decoded correctly
```

---

## TP-PARSER-002 — Memory Write Decode

Stimulus:

```text
Fmt  = 3DW With Data
Type = Memory
```

Expected:

```text
kind = TLP_KIND_MEM_WR
supported = 1
```

---

## TP-PARSER-003 — Completion Decode

Stimulus:

```text
Fmt  = 3DW No Data
Type = Completion
```

Expected:

```text
kind = TLP_KIND_CPL
Completer ID decoded
Completion Status decoded
Byte Count decoded
Tag decoded
```

---

## TP-PARSER-004 — Completion With Data Decode

Stimulus:

```text
Fmt  = 3DW With Data
Type = Completion
```

Expected:

```text
kind = TLP_KIND_CPLD
supported = 1
```

---

## TP-PARSER-005 — Unsupported TLP

Stimulus:

```text
Unsupported Type/Fmt combination
```

Expected:

```text
kind = TLP_KIND_UNSUPPORTED
supported = 0
```

---

# 5. BAR Decoder Test Plan

DUT:

```text
rtl/pcie/bar_decoder.sv
```

Testbench:

```text
tb/sv/unit/bar_decoder_tb.sv
```

## TP-BAR-001 — BAR Base Address

Stimulus:

```text
Address = BAR0_BASE
```

Expected:

```text
bar_hit = 1
local_addr = 0
addr_error = 0
```

---

## TP-BAR-002 — Address Inside BAR

Stimulus:

```text
BAR0_BASE + valid offset
```

Expected:

```text
bar_hit = 1
local_addr = offset
```

---

## TP-BAR-003 — Last Valid BAR Address

Stimulus:

```text
BAR0_BASE + BAR0_SIZE - 1
```

Expected:

```text
bar_hit = 1
```

---

## TP-BAR-004 — First Address Above BAR

Stimulus:

```text
BAR0_BASE + BAR0_SIZE
```

Expected:

```text
bar_hit = 0
addr_error = 1
```

---

## TP-BAR-005 — Address Below BAR

Expected:

```text
bar_hit = 0
addr_error = 1
```

---

## TP-BAR-006 — Invalid Request

Stimulus:

```text
req_valid = 0
```

Expected:

```text
bar_hit = 0
addr_error = 0
```

---

# 6. Endpoint Memory Test Plan

DUT:

```text
rtl/memory/endpoint_memory.sv
```

Testbench:

```text
tb/sv/unit/endpoint_memory_tb.sv
```

## TP-MEM-001 — Full DWORD Write

Expected:

```text
Memory stores full 32-bit value
```

---

## TP-MEM-002 — Full DWORD Read

Expected:

```text
Read returns previously stored data
```

---

## TP-MEM-003 — Partial Byte Write

Stimulus:

```text
byte_en = partial mask
```

Expected:

```text
Only selected bytes updated
Other bytes preserved
```

---

## TP-MEM-004 — Unaligned Access

Stimulus:

```text
Address[1:0] != 00
```

Expected:

```text
addr_error = 1
```

---

## TP-MEM-005 — Out-of-Range Access

Expected:

```text
addr_error = 1
```

---

# 7. Request Handler Test Plan

DUT:

```text
rtl/pcie/request_handler.sv
```

Testbench:

```text
tb/sv/unit/request_handler_tb.sv
```

## TP-REQ-001 — Valid Memory Write

Expected:

```text
mem_req_valid = 1
mem_req_write = 1
Correct local address
Correct payload
Correct byte enable
No PCIe Completion
```

---

## TP-REQ-002 — Valid Memory Read

Expected:

```text
mem_req_valid = 1
mem_req_write = 0
```

After local read response:

```text
cpl_req_valid = 1
cpl_data_valid = 1
Correct Requester ID
Correct Tag
Correct Data
```

---

## TP-REQ-003 — Invalid BAR Read

Expected:

```text
Generate Completion
Status = UR
No data payload
```

---

## TP-REQ-004 — Local Read Error

Expected:

```text
Completion Status = CA
No data payload
```

---

## TP-REQ-005 — Posted Memory Write

Expected:

```text
No PCIe Completion generated
```

---

# 8. Completion Engine Test Plan

DUT:

```text
rtl/pcie/completion_engine.sv
```

Testbench:

```text
tb/sv/unit/completion_engine_tb.sv
```

## TP-CPL-001 — Successful Completion With Data

Expected:

```text
Fmt = 3DW Data
Type = Completion
Status = SC
Length = 1 DW
Byte Count = 4
Correct Tag
Correct Payload
```

---

## TP-CPL-002 — Completion Without Data

Expected:

```text
Fmt = 3DW No Data
Payload Valid = 0
```

---

## TP-CPL-003 — UR Completion

Expected:

```text
Status = UR
No payload
```

---

## TP-CPL-004 — Output Backpressure

Future test:

```text
tx_ready = 0
```

Expected:

```text
Completion remains valid and stable
```

---

# 9. TLP TX Formatter Test Plan

DUT:

```text
rtl/pcie/tlp_tx_formatter.sv
```

Testbench:

```text
tb/sv/unit/tlp_tx_formatter_tb.sv
```

## TP-TX-001 — Memory Read Formatting

Check:

```text
DW0 Fmt/Type
DW1 Requester ID/Tag/BE
DW2 Address
No payload
```

---

## TP-TX-002 — Memory Write Formatting

Check:

```text
Correct header
Payload valid
Correct payload
```

---

## TP-TX-003 — Completion Formatting

Check:

```text
Completer ID
Completion Status
Requester ID
Tag
Lower Address
```

---

## TP-TX-004 — Completion With Data Formatting

Check:

```text
Payload Valid = 1
```

---

## TP-TX-005 — Unsupported TLP

Expected:

```text
formatter_error = 1
```

---

# 10. Outstanding Request Table Test Plan

DUT:

```text
rtl/pcie/outstanding_req_table.sv
```

Testbench:

```text
tb/sv/unit/outstanding_req_table_tb.sv
```

## TP-TAG-001 — Allocate Entry

Expected:

```text
Outstanding Count increments
```

---

## TP-TAG-002 — Allocate Multiple Tags

Example:

```text
Tag 01
Tag 02
Tag 03
```

Expected:

```text
All entries retained independently
```

---

## TP-TAG-003 — Duplicate Tag

Stimulus:

```text
Allocate active tag again
```

Expected:

```text
alloc_duplicate = 1
alloc_ready = 0
```

---

## TP-TAG-004 — Completion Match

Expected:

```text
Correct address returned
Correct length returned
Entry released
```

---

## TP-TAG-005 — Out-of-Order Completion

Issue:

```text
Tag 01
Tag 02
Tag 03
```

Complete:

```text
Tag 03
Tag 01
Tag 02
```

Expected:

```text
Each Completion matched correctly
```

---

## TP-TAG-006 — Unexpected Completion

Expected:

```text
cpl_unexpected = 1
```

---

## TP-TAG-007 — Cancellation

Expected:

```text
Entry matching cancel_tag released
```

---

## TP-TAG-008 — Full Table

Future test:

Fill all entries.

Expected:

```text
table_full = 1
alloc_ready = 0
```

---

# 11. FIFO Test Plan

DUT:

```text
rtl/common_blocks/sync_fifo.sv
```

Testbench:

```text
tb/sv/unit/sync_fifo_tb.sv
```

Tests:

```text
Reset empty
Single write
Multiple writes
FIFO full
FIFO order
Multiple reads
FIFO empty
Simultaneous read/write
Wrap-around
```

---

# 12. Timeout Counter Test Plan

DUT:

```text
rtl/common_blocks/timeout_counter.sv
```

Testbench:

```text
tb/sv/unit/timeout_counter_tb.sv
```

Tests:

```text
Reset
Start
Active indication
Counter increment
Timeout
Clear
Restart
Clear before timeout
```

---

# 13. DMA Register Test Plan

DUT:

```text
rtl/dma/dma_regs.sv
```

Testbench:

```text
tb/sv/unit/dma_regs_tb.sv
```

Tests:

```text
SRC_ADDR write/read
DST_ADDR write/read
LENGTH write/read
START pulse
BUSY read
DONE read
ERROR read
Status clear
Invalid register address
Partial byte write
START while busy
```

---

# 14. DMA Read Engine Test Plan

DUT:

```text
rtl/dma/dma_read_engine.sv
```

Testbench:

```text
tb/sv/unit/dma_read_engine_tb.sv
```

## TP-DMAR-001 — Valid Read

Expected sequence:

```text
Command accepted
Tag allocated
MemRd generated
Completion received
Data returned
read_done asserted
```

---

## TP-DMAR-002 — Tag Allocation

Expected:

```text
alloc_valid asserted
Correct address stored
Length = 1 DW
```

---

## TP-DMAR-003 — Duplicate Tag Handling

Future test:

```text
alloc_duplicate = 1
```

Expected:

```text
Try next tag
```

---

## TP-DMAR-004 — Completion With Matching Tag

Expected:

```text
Data accepted
read_done = 1
```

---

## TP-DMAR-005 — Wrong Completion Tag

Expected:

```text
Completion ignored by read engine
Outstanding table flags unexpected if no match
```

---

## TP-DMAR-006 — Completer Abort

Expected:

```text
read_error = 1
```

---

## TP-DMAR-007 — Completion Without Data for Successful Read

Expected:

```text
read_error = 1
```

---

## TP-DMAR-008 — Completion Timeout

Expected:

```text
read_error = 1
cancel_valid = 1
```

---

# 15. DMA Write Engine Test Plan

DUT:

```text
rtl/dma/dma_write_engine.sv
```

Testbench:

```text
tb/sv/unit/dma_write_engine_tb.sv
```

## TP-DMAW-001 — Valid Write

Expected:

```text
MemWr generated
Correct destination address
Correct payload
Correct byte enable
```

---

## TP-DMAW-002 — Posted Behavior

Expected:

```text
No Completion waiting state
```

---

## TP-DMAW-003 — Unaligned Address

Expected:

```text
write_error = 1
```

---

## TP-DMAW-004 — TX Backpressure

Future test:

```text
tx_ready = 0
```

Expected:

```text
TLP remains valid and stable
```

---

# 16. DMA Controller Test Plan

DUT:

```text
rtl/dma/dma_controller.sv
```

Testbench:

```text
tb/sv/unit/dma_controller_tb.sv
```

## TP-DMAC-001 — One DWORD Transfer

Flow:

```text
START
 |
Read Command
 |
Read Done
 |
Write Command
 |
Write Done
 |
DONE
```

---

## TP-DMAC-002 — Multi-DWORD Transfer

Example:

```text
Length = 16 bytes
```

Expected:

```text
Four read/write operations
Source increments by 4
Destination increments by 4
Remaining length decrements by 4
```

---

## TP-DMAC-003 — Invalid Length

Stimulus:

```text
Length not multiple of 4
```

Expected:

```text
DMA ERROR
```

---

## TP-DMAC-004 — Zero Length

Expected:

```text
DMA ERROR
```

---

## TP-DMAC-005 — Unaligned Source

Expected:

```text
DMA ERROR
```

---

## TP-DMAC-006 — Unaligned Destination

Expected:

```text
DMA ERROR
```

---

## TP-DMAC-007 — Read Error

Expected:

```text
DMA transitions to ERROR
```

---

## TP-DMAC-008 — Write Error

Expected:

```text
DMA transitions to ERROR
```

---

# 17. Integration Test Plan

Current tests:

```text
pcie_endpoint_smoke_tb
pcie_dma_integration_tb
pcie_error_integration_tb
```

---

# 18. Endpoint Smoke Test

Test ID:

```text
TP-INT-001
```

Flow:

```text
Host MemWr -> Endpoint Memory
Host MemRd -> Endpoint Memory
Endpoint CplD -> Host
```

Checks:

```text
Write accepted
No Completion for write
Read accepted
Completion generated
Completion Tag correct
Completion Data correct
```

---

# 19. Invalid BAR Integration Test

Test ID:

```text
TP-INT-002
```

Stimulus:

```text
MemRd outside BAR0
```

Expected:

```text
Cpl
Status = UR
Tag preserved
```

---

# 20. DMA End-to-End Integration Test

Test ID:

```text
TP-INT-003
```

Configuration:

```text
SRC_ADDR = 0x10000000
DST_ADDR = 0x20000000
LENGTH   = 4
START    = 1
```

Expected:

```text
DUT issues MemRd at SRC_ADDR
Outstanding table count increments
Testbench returns CplD
DUT issues MemWr at DST_ADDR
Payload matches CplD data
DMA DONE asserted
Outstanding table returns to zero
```

---

# 21. DMA Completion Error Test

Test ID:

```text
TP-INT-004
```

Flow:

```text
DMA MemRd
 |
Return CA Completion
```

Expected:

```text
DMA ERROR
Outstanding entry released
```

---

# 22. DMA Completion Timeout Test

Test ID:

```text
TP-INT-005
```

Flow:

```text
DMA MemRd
 |
Do not return Completion
 |
Wait for timeout
```

Expected:

```text
DMA ERROR
Cancellation generated
Outstanding entry removed
```

---

# 23. Unexpected Completion Test

Test ID:

```text
TP-INT-006
```

Stimulus:

```text
CplD with unknown tag
```

Expected:

```text
unexpected_completion asserted
Outstanding table unchanged
```

---

# 24. UVM Smoke Test

Test:

```text
pcie_smoke_test
```

Sequence:

```text
pcie_smoke_seq
```

Scenarios:

```text
Endpoint Memory Write
Endpoint Memory Read
Invalid BAR Read
```

Expected scoreboard checks:

```text
Memory reference updated
CplD data matches reference
UR status matches expectation
```

---

# 25. UVM DMA Test

Test:

```text
pcie_dma_test
```

Sequence:

```text
pcie_dma_seq
```

Flow:

```text
Program DMA registers
Start DMA
Observe DUT MemRd
Capture Tag
Return CplD
Observe DUT MemWr
Compare destination
Compare payload
```

---

# 26. UVM Error Test

Test:

```text
pcie_error_test
```

Sequence:

```text
pcie_error_seq
```

Scenarios:

```text
Invalid BAR
Unexpected CplD
DMA CA Completion
```

---

# 27. Planned UVM Random Traffic Test

Future test:

```text
pcie_random_traffic_test
```

Random fields:

```text
MemRd / MemWr
Address
Tag
Payload
Byte Enable
Delay
```

Constraints should keep transactions legal unless explicitly running an error test.

---

# 28. Planned Partial Write Test

Future test:

```text
pcie_partial_write_test
```

Byte-enable cases:

```text
0001
0010
0100
1000
0011
1100
0110
1111
```

Expected:

```text
Only selected bytes update
```

---

# 29. Planned Backpressure Test

Future test:

```text
pcie_backpressure_test
```

Randomize:

```text
tx_ready
```

Expected:

```text
tx_valid remains asserted
Header remains stable
Payload remains stable
Transaction eventually completes
```

---

# 30. Planned Multiple Outstanding Test

Future test:

```text
pcie_multi_outstanding_test
```

Goal:

```text
Issue multiple Memory Reads before receiving Completion
```

Example:

```text
MemRd Tag 01
MemRd Tag 02
MemRd Tag 03
MemRd Tag 04
```

Expected:

```text
Outstanding count = 4
All tags unique
```

---

# 31. Planned Out-of-Order Completion Test

Future test:

```text
pcie_out_of_order_completion_test
```

Issue:

```text
01
02
03
04
```

Complete:

```text
03
01
04
02
```

Expected:

```text
Each Completion matched to correct request
No unexpected Completion
Outstanding count returns to zero
```

---

# 32. Planned Table Full Test

Future scenario:

```text
Allocate NUM_ENTRIES requests
```

Expected:

```text
table_full = 1
```

Attempt one additional allocation.

Expected:

```text
alloc_ready = 0
```

---

# 33. Planned Random Completion Delay Test

Completion delay randomized across:

```text
0 cycles
1 cycle
2-5 cycles
6-15 cycles
Near timeout
Timeout
```

Purpose:

```text
Exercise timeout boundary behavior
```

---

# 34. Planned Completion Status Test

Completion statuses:

```text
SC
UR
CA
```

Optional modeled status:

```text
CRS
```

Expected DMA behavior should be checked for each supported status.

---

# 35. Planned DMA Length Test

DMA lengths:

```text
4 bytes
8 bytes
16 bytes
32 bytes
64 bytes
```

Expected:

```text
Correct number of DWORD transfers
Correct address increment
Correct DONE behavior
```

---

# 36. Planned DMA Address Test

Source and destination address ranges:

```text
Low addresses
Middle addresses
High 32-bit addresses
Boundary-aligned addresses
```

Invalid:

```text
Address + 1
Address + 2
Address + 3
```

Expected:

```text
Alignment error
```

---

# 37. Reset Tests

Reset should be applied:

```text
Before traffic
During idle
During DMA configuration
During DMA read
While waiting for Completion
During DMA write
```

Expected:

```text
State machines return to IDLE
Outstanding table clears
DMA status clears
Valid signals deassert
```

Reset-during-transaction tests are planned future extensions.

---

# 38. Assertion Test Mapping

| Assertion Area | Stimulus |
|---|---|
| MemWr requires payload | Generate valid/invalid MemWr |
| MemRd no payload | Generate valid/invalid MemRd |
| CplD requires payload | Generate CplD |
| Cpl no payload | Generate Cpl |
| TX stable while stalled | Hold `tx_ready=0` |
| DMA read aligned | Random DMA source |
| DMA write aligned | Random DMA destination |
| Duplicate tag rejected | Allocate same tag twice |
| Count within range | Fill table |
| Match/unexpected exclusive | Completion lookup |

---

# 39. Coverage-Driven Tests

If functional coverage indicates missing bins, targeted tests should be added.

Examples:

Missing:

```text
CA status
```

Add:

```text
Completer Abort test
```

Missing:

```text
Partial byte enable
```

Add:

```text
Partial write sequence
```

Missing:

```text
Outstanding count = maximum
```

Add:

```text
Table-full sequence
```

---

# 40. Regression Test Sets

## Smoke Regression

```text
tlp_rx_parser_tb
bar_decoder_tb
endpoint_memory_tb
pcie_endpoint_smoke_tb
pcie_smoke_test
```

Purpose:

```text
Quick sanity check after changes
```

---

## DMA Regression

```text
dma_regs_tb
dma_read_engine_tb
dma_write_engine_tb
dma_controller_tb
outstanding_req_table_tb
pcie_dma_integration_tb
pcie_dma_test
```

---

## Error Regression

```text
timeout_counter_tb
outstanding_req_table_tb
pcie_error_integration_tb
pcie_error_test
```

---

## Full Regression

```text
All Unit Tests
All Integration Tests
All UVM Tests
Multiple Seeds
Assertions
Coverage
```

---

# 41. Test Pass Criteria

A test passes only when:

```text
Compilation succeeds
Simulation reaches normal completion
No unexpected $error
No $fatal
No unexpected UVM_ERROR
No UVM_FATAL
No unexpected assertion failure
All scoreboard comparisons pass
All explicit self-checks pass
```

---

# 42. Failure Reproduction

UVM regression failures should always record:

```text
Test Name
Seed
Compile Log
Simulation Log
Coverage Database
Waveform if enabled
```

Example:

```text
Test = pcie_dma_test
Seed = 92831
```

Re-run:

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 92831
```

---

# 43. Final Test Results

The final directed and UVM regressions completed successfully.

| Test | Status | Notes |
|---|---|---|
| `tlp_rx_parser_tb` | PASS | Unit test |
| `bar_decoder_tb` | PASS | Unit test |
| `endpoint_memory_tb` | PASS | Unit test |
| `request_handler_tb` | PASS | Unit test |
| `completion_engine_tb` | PASS | Unit test |
| `tlp_tx_formatter_tb` | PASS | Unit test |
| `outstanding_req_table_tb` | PASS | Unit test |
| `sync_fifo_tb` | PASS | Unit test |
| `timeout_counter_tb` | PASS | Unit test |
| `dma_regs_tb` | PASS | Unit test |
| `dma_read_engine_tb` | PASS | Unit test |
| `dma_write_engine_tb` | PASS | Unit test |
| `dma_controller_tb` | PASS | Unit test |
| `pcie_endpoint_smoke_tb` | PASS | Integration test |
| `pcie_dma_integration_tb` | PASS | Integration test |
| `pcie_error_integration_tb` | PASS | Integration test |
| `pcie_smoke_test` | PASS | UVM seeds 1-5 |
| `pcie_dma_test` | PASS | UVM seeds 1-5 |
| `pcie_error_test` | PASS | UVM seeds 1-5 |

Final regression summary:

```text
Unit tests        : 13/13 PASS
Integration tests : 3/3 PASS
UVM runs          : 15/15 PASS
UVM_ERROR         : 0
UVM_FATAL         : 0
```

---

# 44. Future Test Extensions

Potential future verification scenarios include:

```text
Multiple Outstanding DMA Reads
Out-of-Order Completion Stress
Random Completion Latency
Random TX Backpressure
DMA Burst Transfers
Descriptor-Based DMA
Scatter-Gather DMA
64-bit Address TLPs
4DW Header Tests
Multiple BARs
PCIe-to-AXI Integration
Credit Flow-Control Modeling
LTSSM Tests
```

---

# 45. Summary

The test plan validates the design from individual modules through complete end-to-end PCIe DMA operation.

The core test flow is:

```text
Parser
  |
BAR
  |
Local Access
  |
Completion
  |
DMA Read
  |
Tag Tracking
  |
CplD Matching
  |
DMA Write
  |
Error Handling
  |
UVM Regression
  |
Coverage Closure
```

The test plan will evolve as actual VCS simulation identifies design bugs, verification-environment issues, and coverage gaps.