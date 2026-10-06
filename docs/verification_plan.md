# PCIe Endpoint Transaction Layer with DMA Engine

## Verification Plan

---

# 1. Purpose

This document defines the verification strategy for the PCIe Endpoint Transaction Layer with DMA Engine project.

The verification objective is to demonstrate that the RTL behaves correctly for the supported transaction types, DMA operations, error conditions, outstanding request handling, and control/status behavior.

The verification environment uses:

```text
SystemVerilog
Self-Checking Directed Testbenches
UVM
SystemVerilog Assertions
Functional Coverage
Code Coverage
Python Regression Automation
Synopsys VCS
Synopsys DVE
```

The verification process is organized into multiple levels:

```text
Unit Verification
      |
      v
Integration Verification
      |
      v
Assertion-Based Verification
      |
      v
UVM Verification
      |
      v
Regression
      |
      v
Coverage Closure
```

---

# 2. Verification Objectives

The main verification objectives are:

- Verify correct decoding of supported PCIe TLP types
- Verify correct BAR0 address decoding
- Verify local register accesses
- Verify endpoint memory accesses
- Verify posted Memory Write behavior
- Verify non-posted Memory Read behavior
- Verify Completion generation
- Verify Completion with Data generation
- Verify DMA register programming
- Verify DMA read operation
- Verify DMA write operation
- Verify DMA transfer sequencing
- Verify tag allocation
- Verify outstanding request tracking
- Verify Completion matching
- Verify unexpected Completion detection
- Verify duplicate-tag protection
- Verify timeout handling
- Verify error propagation
- Verify valid/ready handshake behavior
- Verify stable outputs under backpressure
- Verify functional coverage goals
- Verify clean multi-seed UVM regression

---

# 3. Verification Scope

The verification plan covers the following supported functionality.

## PCIe Transaction Types

```text
Memory Read
Memory Write
Completion
Completion with Data
```

## PCIe Header Fields

```text
Fmt
Type
Length
Requester ID
Completer ID
Tag
First DW Byte Enable
Last DW Byte Enable
Address
Completion Status
Byte Count
Lower Address
```

## Endpoint Features

```text
BAR0 decoding
DMA registers
Endpoint memory
Completion generation
TX arbitration
TLP formatting
```

## DMA Features

```text
Source address programming
Destination address programming
Transfer length programming
Start control
Busy status
Done status
Error status
PCIe Memory Read generation
PCIe Memory Write generation
Completion handling
Timeout handling
```

---

# 4. Out-of-Scope Verification

The following PCIe features are outside the current verification scope:

```text
Physical Layer
Data Link Layer
SerDes
PIPE interface
LTSSM
DLLP
LCRC
Replay
ACK / NAK
Credit-based flow control
Configuration TLPs
Message TLPs
Atomic Operations
MSI
MSI-X
64-bit addressing
4DW Memory Requests
Split Completions
Multiple Completion packets for one request
```

These features may be considered future extensions.

---

# 5. Verification Architecture

The verification strategy contains both directed SystemVerilog testbenches and a reusable UVM environment.

```text
                    +----------------+
                    |   UVM TEST     |
                    +--------+-------+
                             |
                             v
                    +----------------+
                    |   SEQUENCE     |
                    +--------+-------+
                             |
                             v
                    +----------------+
                    |   SEQUENCER    |
                    +--------+-------+
                             |
                             v
                    +----------------+
                    |    DRIVER      |
                    +--------+-------+
                             |
                             v
                         PCIe IF
                             |
                             v
                    +----------------+
                    |      DUT       |
                    +--------+-------+
                             |
                             v
                    +----------------+
                    |    MONITOR     |
                    +--------+-------+
                             |
                +------------+------------+
                |                         |
                v                         v
         +-------------+           +-------------+
         | SCOREBOARD  |           |  COVERAGE   |
         +-------------+           +-------------+

                    DMA STATUS IF
                         |
                         v
                    DMA MONITOR
                         |
                         v
                    SCOREBOARD
```

---

# 6. Verification Levels

## 6.1 Unit Verification

Each RTL block is verified independently.

Unit verification is intended to detect:

- Basic functionality errors
- State machine errors
- Address decoding errors
- Data-path errors
- Handshake errors
- Register behavior errors
- Counter behavior errors
- Tag-table errors

Current unit tests:

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

# 7. Unit Verification Matrix

| RTL Module | Verification Focus |
|---|---|
| `tlp_rx_parser.sv` | MemRd, MemWr, Cpl, CplD decode |
| `bar_decoder.sv` | BAR hit, miss, boundaries |
| `endpoint_memory.sv` | Read, write, byte enable, alignment |
| `request_handler.sv` | MemRd/MemWr processing |
| `completion_engine.sv` | Cpl and CplD construction |
| `tlp_tx_formatter.sv` | Header formatting |
| `outstanding_req_table.sv` | Allocate, match, cancel, duplicates |
| `sync_fifo.sv` | FIFO write/read/full/empty |
| `timeout_counter.sv` | Start, count, timeout, clear |
| `dma_regs.sv` | Register read/write/status |
| `dma_read_engine.sv` | MemRd issue and Completion handling |
| `dma_write_engine.sv` | Posted MemWr generation |
| `dma_controller.sv` | Read/write sequencing |

---

# 8. Integration Verification

Integration verification checks interaction between multiple RTL modules.

Current integration testbenches:

```text
pcie_endpoint_smoke_tb.sv
pcie_dma_integration_tb.sv
pcie_error_integration_tb.sv
```

---

# 9. Endpoint Smoke Verification

The endpoint smoke test verifies:

```text
Host MemWr
     |
     v
BAR Decode
     |
     v
Endpoint Memory Write
```

followed by:

```text
Host MemRd
     |
     v
BAR Decode
     |
     v
Endpoint Memory Read
     |
     v
CplD
```

It also verifies:

```text
Invalid BAR MemRd
      |
      v
UR Completion
```

Expected results:

- Posted Memory Write produces no Completion
- Memory Read produces CplD
- Returned payload matches stored memory data
- Invalid BAR read produces UR

---

# 10. DMA Integration Verification

The DMA integration test verifies the complete transfer flow.

```text
Host programs SRC_ADDR
       |
Host programs DST_ADDR
       |
Host programs LENGTH
       |
Host writes START
       |
       v
DMA Controller Starts
       |
       v
DMA Read Engine Issues MemRd
       |
       v
Outstanding Table Allocates Tag
       |
       v
External Model Sends CplD
       |
       v
DMA Read Engine Captures Data
       |
       v
DMA Write Engine Issues MemWr
       |
       v
DMA DONE
```

Checks include:

- Correct DMA source address
- Correct DMA destination address
- Correct DMA read tag
- Correct returned Completion tag
- Correct payload propagation
- Outstanding request count increases
- Outstanding entry is removed after Completion
- DMA DONE is generated
- DMA ERROR remains inactive

---

# 11. Error Integration Verification

The error integration test verifies:

```text
Invalid BAR access
Unexpected Completion
Completer Abort
Completion Timeout
Outstanding entry cleanup
```

Expected behavior:

```text
Invalid BAR Read
    -> UR Completion

Unknown Completion Tag
    -> unexpected_completion

CA Completion
    -> DMA ERROR

No Completion
    -> Timeout
    -> Outstanding request cancelled
    -> DMA ERROR
```

---

# 12. UVM Verification Strategy

The UVM environment provides reusable transaction-level verification.

Major components:

```text
PCIe Sequence Item
PCIe Sequencer
PCIe Driver
PCIe Monitor
PCIe Agent

DMA Status Item
DMA Monitor
DMA Passive Agent

Scoreboard
Functional Coverage
Environment
Sequences
Tests
```

---

# 13. PCIe Sequence Item

The sequence item models one transaction.

Fields include:

```text
Direction
TLP Kind
Length
Requester ID
Completer ID
Tag
First BE
Last BE
Address
Completion Status
Byte Count
Lower Address
Payload Valid
Payload Data
```

The transaction can be converted to raw TLP DWORDs using:

```text
pack_tlp()
```

and decoded from raw DWORDs using:

```text
decode_tlp()
```

---

# 14. PCIe Driver

The driver receives sequence items from the sequencer.

Flow:

```text
Sequence Item
      |
      v
pack_tlp()
      |
      v
Drive RX Header
      |
      v
Drive Payload
      |
      v
Assert rx_valid
      |
      v
Wait for rx_ready
      |
      v
Deassert Interface
```

The driver also keeps:

```text
tx_ready = 1
```

for the initial environment.

Future backpressure sequences may vary `tx_ready`.

---

# 15. PCIe Monitor

The monitor observes both directions.

## RX Monitoring

A transaction is captured when:

```text
rx_valid && rx_ready
```

## TX Monitoring

A transaction is captured when:

```text
tx_valid && tx_ready
```

The monitor reconstructs a `pcie_seq_item` and broadcasts it using an analysis port.

---

# 16. DMA Status Monitor

The passive DMA monitor observes:

```text
dma_busy
dma_done
dma_error
unexpected_completion
outstanding_count
tx_formatter_error
```

This information is forwarded to the scoreboard.

---

# 17. Scoreboard Strategy

The scoreboard maintains a simplified reference model.

Reference state includes:

```text
Endpoint Memory Model
Expected Completion Data
Expected UR Completions
DMA Source Address
DMA Destination Address
DMA Length
DMA Active State
DMA Outstanding Tag
DMA Returned Data
```

---

# 18. Endpoint Memory Scoreboard Flow

For incoming host Memory Writes:

```text
Host MemWr
     |
     v
Monitor
     |
     v
Scoreboard updates reference memory
```

For incoming host Memory Reads:

```text
Host MemRd
     |
     v
Scoreboard looks up reference memory
     |
     v
Expected CplD stored by Tag
```

When DUT sends CplD:

```text
Observed CplD
     |
     v
Tag lookup
     |
     v
Compare expected payload
```

---

# 19. DMA Scoreboard Flow

DMA checking is performed using observed PCIe transactions.

```text
Host Programs DMA Registers
      |
      v
Scoreboard stores config
      |
      v
DUT sends MemRd
      |
      v
Compare source address
      |
      v
Capture Tag
      |
      v
Host sends CplD
      |
      v
Capture returned payload
      |
      v
DUT sends MemWr
      |
      +--> Compare destination address
      |
      +--> Compare payload
```

---

# 20. Current UVM Tests

Current tests:

```text
pcie_smoke_test
pcie_dma_test
pcie_error_test
```

---

# 21. Smoke UVM Test

The smoke test verifies:

```text
Endpoint Memory Write
Endpoint Memory Read
Completion with Data
Invalid BAR Read
UR Completion
```

---

# 22. DMA UVM Test

The DMA test verifies:

```text
DMA register programming
DMA start
DMA Memory Read
Completion with Data
DMA Memory Write
DMA completion
```

---

# 23. Error UVM Test

The error test verifies:

```text
Invalid BAR
Unexpected Completion
DMA Completer Abort
```

Timeout verification is currently handled directly in the integration environment and can later be added as a dedicated UVM sequence.

---

# 24. Planned Constrained-Random Verification

Future constrained-random sequences should randomize:

```text
Address
Tag
Payload Data
Byte Enable
Completion Status
Completion Delay
Backpressure
Transfer Length
DMA source
DMA destination
DMA length
```

Example constraints:

```systemverilog
constraint aligned_addr_c {
  address[1:0] == 2'b00;
}

constraint supported_length_c {
  length_dw inside {[1:16]};
}

constraint first_be_c {
  first_be != 4'b0000;
}
```

---

# 25. Planned Random Test Classes

Future UVM tests may include:

```text
pcie_random_traffic_test
pcie_random_dma_test
pcie_multi_outstanding_test
pcie_out_of_order_completion_test
pcie_random_error_test
pcie_backpressure_test
pcie_partial_write_test
pcie_timeout_test
```

---

# 26. Assertion-Based Verification

Assertions are divided into three groups.

```text
pcie_assertions.sv
dma_assertions.sv
tag_assertions.sv
```

---

# 27. PCIe Assertions

Planned/current PCIe properties include:

- RX Memory Write must contain payload
- RX Memory Read must not contain payload
- TX Memory Write must contain payload
- TX Memory Read must not contain payload
- CplD must contain payload
- Cpl must not contain payload
- TX header must remain stable during backpressure
- TX header must not contain X/Z while valid

---

# 28. DMA Assertions

DMA properties include:

- DONE and ERROR cannot be high simultaneously
- Read address must be DWORD aligned
- Write address must be DWORD aligned
- Read command must remain stable when stalled
- Write command must remain stable when stalled
- Read and write commands should not be generated simultaneously
- DMA start addresses must be aligned

---

# 29. Tag Assertions

Tag-related properties include:

- Duplicate outstanding tag cannot be accepted
- Completion match and unexpected completion are mutually exclusive
- Completion match requires valid Completion
- Unexpected completion requires valid Completion
- Cancellation match requires valid cancellation request
- Outstanding count cannot exceed table capacity
- Full-table indication must match maximum occupancy

---

# 30. Functional Coverage Strategy

Functional coverage is used to measure scenario execution.

Initial coverpoints:

```text
Transaction Direction
TLP Kind
Transfer Length
First Byte Enable
Completion Status
```

Cross coverage:

```text
Direction x TLP Kind
```

---

# 31. Planned Functional Coverage

Additional planned coverpoints:

```text
BAR hit / BAR miss
Posted / Non-Posted
Read / Write
Full / Partial Byte Enable
Completion Status
DMA success / DMA error
Timeout
Unexpected Completion
Outstanding count
Tag value
Completion latency
Backpressure
```

---

# 32. Coverage Crosses

Useful future crosses include:

```text
TLP Type x Direction

MemWr x Byte Enable

MemRd x BAR Hit/Miss

Completion Status x TLP Kind

DMA Length x DMA Result

Outstanding Count x Completion Order

Tag x Completion Status

Backpressure x TLP Type
```

---

# 33. Code Coverage

Planned code coverage metrics:

```text
Line Coverage
Branch Coverage
Condition Coverage
FSM Coverage
Toggle Coverage
```

Code coverage will be collected using Synopsys VCS.

---

# 34. Assertion Coverage

Assertion coverage should track:

```text
Property attempts
Property passes
Property failures
Cover-property hits
```

The initial goal is to ensure:

```text
0 unexpected assertion failures
```

before coverage closure.

---

# 35. Regression Strategy

Regression levels:

```text
Level 1
Unit Regression

Level 2
Integration Regression

Level 3
UVM Regression

Level 4
Multi-Seed UVM Regression

Level 5
Coverage Regression
```

---

# 36. Unit Regression

Unit regression runs all block-level testbenches.

Command:

```bash
python3 scripts/python/run_regression.py --unit
```

Expected result:

```text
All unit tests PASS
```

---

# 37. Integration Regression

Command:

```bash
python3 scripts/python/run_regression.py --integration
```

Expected tests:

```text
smoke
dma
error
```

---

# 38. UVM Regression

Command:

```bash
python3 scripts/python/run_regression.py --uvm
```

Multi-seed example:

```bash
python3 scripts/python/run_regression.py --uvm --seeds 20
```

---

# 39. Full Regression

Command:

```bash
python3 scripts/python/run_regression.py --all --seeds 20
```

This executes:

```text
Unit Tests
Integration Tests
UVM Tests
Multiple Seeds
```

---

# 40. Regression Pass Criteria

A regression run is considered passing when:

```text
No compile failure
No simulation fatal
No unexpected $error
No UVM_FATAL
No unexpected UVM_ERROR
No assertion failures
All self-checking comparisons pass
```

---

# 41. Debug Strategy

When a test fails:

```text
Failure
  |
  v
Check Compile Log
  |
  v
Check Simulation Log
  |
  v
Identify First Error
  |
  v
Reproduce Single Test
  |
  v
Enable Waveform
  |
  v
Open DVE
  |
  v
Trace Interface
  |
  v
Trace Internal FSM
  |
  v
Determine Root Cause
  |
  v
Fix RTL or TB
  |
  v
Re-run Unit Test
  |
  v
Re-run Regression
```

---

# 42. Waveform Debug Targets

Important signals for endpoint debugging:

```text
rx_valid
rx_ready
rx_dw0
rx_dw1
rx_dw2
rx_payload_valid
rx_payload_data
```

Important TX signals:

```text
tx_valid
tx_ready
tx_dw0
tx_dw1
tx_dw2
tx_payload_valid
tx_payload_data
```

Important DMA signals:

```text
dma_start
dma_busy
dma_done
dma_error

read_cmd_valid
read_cmd_ready

write_cmd_valid
write_cmd_ready
```

Important tag signals:

```text
alloc_valid
alloc_ready
alloc_tag

cpl_valid
cpl_tag
cpl_match

cancel_valid
cancel_tag

outstanding_count
```

---

# 43. Bug Classification

Discovered bugs should be classified into categories.

## RTL Functional Bug

Examples:

```text
Wrong Completion data
Incorrect address increment
Incorrect DMA state transition
Tag not released
```

## Protocol Bug

Examples:

```text
MemWr generating Completion
MemRd missing Completion
Payload present on incorrect TLP
```

## Verification Environment Bug

Examples:

```text
Scoreboard model incorrect
Driver timing incorrect
Monitor sampling incorrect
```

## Assertion Bug

Examples:

```text
Property too strict
Incorrect sampling cycle
Invalid disable condition
```

## Coverage Bug

Examples:

```text
Unreachable bin
Incorrect cross
Wrong sampling event
```

---

# 44. Verification Milestones

## Milestone 1 — RTL Compile

Requirements:

```text
All RTL files compile
No unresolved modules
No package errors
No width errors requiring correction
```

---

## Milestone 2 — Unit Test Pass

Requirements:

```text
13 unit testbenches compile
All directed checks pass
No unexpected simulation errors
```

---

## Milestone 3 — Integration Pass

Requirements:

```text
Endpoint Smoke PASS
DMA Integration PASS
Error Integration PASS
```

---

## Milestone 4 — Assertion Bring-Up

Requirements:

```text
Assertions compile
Assertions bind/instantiate correctly
No unexpected assertion failures
```

---

## Milestone 5 — UVM Bring-Up

Requirements:

```text
UVM package compiles
Interfaces connect
Agent builds
Driver runs
Monitor runs
Scoreboard receives transactions
Coverage samples transactions
```

---

## Milestone 6 — UVM Tests Pass

Requirements:

```text
pcie_smoke_test PASS
pcie_dma_test PASS
pcie_error_test PASS
```

---

## Milestone 7 — Multi-Seed Regression

Requirements:

```text
Multiple seeds execute without unexpected errors
Failures are reproducible by seed
```

---

## Milestone 8 — Coverage Collection

Requirements:

```text
Code coverage generated
Functional coverage generated
Assertion coverage generated
```

---

## Milestone 9 — Coverage Closure

Requirements:

```text
Review uncovered functionality
Determine reachable vs unreachable
Add targeted tests
Add missing coverpoints
Re-run regression
```

---

# 45. Verification Exit Criteria

The project can be considered verification-complete for its defined scope when:

```text
All RTL compiles successfully
All unit tests pass
All integration tests pass
All planned UVM tests pass
No unexpected assertion failures
No UVM_FATAL
No unexplained UVM_ERROR
Key functional coverage bins are hit
Meaningful code coverage gaps are reviewed
Regression is repeatable
Known limitations are documented
```

Coverage percentages should only be recorded after actual simulation.

---

# 46. Current Verification Status

Current project status:

```text
Unit TB source            : Created
Integration TB source     : Created
UVM source                : Created
Scoreboard source         : Created
Coverage model source     : Created
Assertion source          : Created
Regression scripts        : Created
VCS scripts               : Created
```

Current simulator-validation status:

```text
Compilation               : Pending
Unit execution            : Pending
Integration execution     : Pending
UVM execution             : Pending
Assertion execution       : Pending
Code coverage             : Pending
Functional coverage       : Pending
Regression results        : Pending
```

No PASS percentage or coverage percentage should be claimed until VCS execution is completed.

---

# 47. Final Verification Flow

```text
RTL Creation
    |
    v
Unit Tests
    |
    v
Integration Tests
    |
    v
Assertions
    |
    v
UVM Bring-Up
    |
    v
Directed UVM Tests
    |
    v
Constrained-Random Tests
    |
    v
Multi-Seed Regression
    |
    v
Code Coverage
    |
    v
Functional Coverage
    |
    v
Coverage Analysis
    |
    v
Targeted Tests
    |
    v
Regression Re-run
    |
    v
Verification Closure
```

---

# 48. Summary

The verification plan combines:

```text
Block-Level Verification
Integration Verification
Assertion-Based Verification
UVM Verification
Scoreboard Checking
Functional Coverage
Code Coverage
Regression Automation
Waveform Debug
```

The key verification focus is ensuring correct behavior across both major endpoint roles:

```text
Endpoint as Completer
        +
Endpoint as DMA Requester
```

This provides verification coverage across:

```text
Incoming PCIe Requests
Outgoing PCIe Completions
DMA-Generated Requests
Incoming DMA Completions
Outstanding Transaction Tracking
Error Handling
Timeout Handling
```

The project is structured so that verification depth can be expanded after initial VCS bring-up without redesigning the entire environment.