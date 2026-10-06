# PCIe Endpoint Transaction Layer with DMA Engine

## Project Overview

This project implements and verifies a simplified PCI Express Endpoint Transaction Layer integrated with a DMA engine. The design focuses on transaction-level PCIe behavior rather than the Physical Layer or Data Link Layer.

The RTL supports 3DW Memory Read and Memory Write requests, Completion and Completion-with-Data generation/handling, BAR0 address decoding, endpoint-local memory, DMA configuration and transfers, tag allocation, outstanding-request tracking, completion matching, timeout detection, and error handling.

The verification environment combines self-checking SystemVerilog unit tests, subsystem integration tests, SystemVerilog Assertions (SVA), and a UVM environment with scoreboard checking, functional coverage, and multi-seed regression using Synopsys VCS.

---

## Key Features

- Simplified PCIe Transaction Layer endpoint
- 3DW Memory Read and Memory Write TLP support
- Completion (`Cpl`) and Completion with Data (`CplD`)
- Posted and non-posted transaction handling
- 32-bit addressing
- BAR0 address decoding
- Endpoint-local memory with byte enables
- DMA configuration registers
- DMA read and write engines
- Sequential multi-DWORD DMA transfers
- PCIe tag allocation and outstanding-request tracking
- Tag-based completion matching
- Unit-verified multi-entry outstanding table with out-of-order completion matching
- Completion timeout detection
- Unsupported Request and Completer Abort handling
- Unexpected-completion detection
- Fixed-priority TX arbitration
- Self-checking SystemVerilog verification
- UVM scoreboard and functional coverage
- SystemVerilog Assertions
- Python/Tcl/Bash regression automation

---

## Project Scope

This project models a simplified PCIe Transaction Layer and is not intended to be a complete production PCIe controller.

The following are outside the current scope:

- PCIe Physical Layer / SerDes
- PIPE interface
- PCIe Data Link Layer
- DLLP handling
- Replay buffers
- LCRC
- ACK/NAK handling
- LTSSM
- Full PCIe Configuration Space
- MSI/MSI-X
- Gen-specific PHY behavior
- Credit-based flow-control modeling
- 64-bit / 4DW TLP support

The project intentionally concentrates on RTL architecture and verification of Transaction Layer and DMA concepts.

---

## High-Level Architecture

```text
                         PCIe RX
                            |
                            v
                    +---------------+
                    | TLP RX Parser |
                    +-------+-------+
                            |
                            v
                     +-------------+
                     | BAR Decoder |
                     +------+------+
                            |
                            v
                    +---------------+
                    | Request       |
                    | Handler       |
                    +-------+-------+
                            |
                  +---------+---------+
                  |                   |
                  v                   v
          +---------------+   +---------------+
          | DMA Registers |   | Endpoint      |
          |               |   | Memory        |
          +-------+-------+   +-------+-------+
                  |                   |
                  +---------+---------+
                            |
                            v
                    +---------------+
                    | Completion    |
                    | Engine        |
                    +-------+-------+
                            |
                            v
                     TX Arbitration
                            |
                            v
                    +---------------+
                    | TLP TX        |
                    | Formatter     |
                    +-------+-------+
                            |
                            v
                         PCIe TX
```

DMA traffic shares the same PCIe transmit path:

```text
DMA Registers
     |
     v
DMA Controller
     |
     +------------------+
     |                  |
     v                  v
DMA Read Engine    DMA Write Engine
     |                  |
     v                  v
Outstanding         Posted Memory
Request Table       Write TLP
     |
     v
Memory Read TLP
     |
     v
Wait for CplD
```

---

## Main RTL Blocks

| Block | File | Function |
|---|---|---|
| PCIe TLP package | `rtl/common/pcie_tlp_pkg.sv` | Common TLP types, enums, and helper definitions |
| TLP RX parser | `rtl/pcie/tlp_rx_parser.sv` | Decodes incoming 3DW TLP headers |
| BAR decoder | `rtl/pcie/bar_decoder.sv` | Decodes BAR0 accesses and local offsets |
| Request handler | `rtl/pcie/request_handler.sv` | Processes endpoint Memory Read/Write requests |
| Completion engine | `rtl/pcie/completion_engine.sv` | Generates `Cpl` and `CplD` responses |
| TLP TX formatter | `rtl/pcie/tlp_tx_formatter.sv` | Formats internal transactions into TX TLP fields |
| Outstanding request table | `rtl/pcie/outstanding_req_table.sv` | Tracks tagged non-posted requests |
| Endpoint memory | `rtl/memory/endpoint_memory.sv` | Local BAR-accessible memory |
| DMA registers | `rtl/dma/dma_regs.sv` | Source, destination, length, control, and status registers |
| DMA controller | `rtl/dma/dma_controller.sv` | Sequences read/write operations across the requested length |
| DMA read engine | `rtl/dma/dma_read_engine.sv` | Issues Memory Reads and waits for matching completions |
| DMA write engine | `rtl/dma/dma_write_engine.sv` | Generates posted Memory Write TLPs |
| Timeout counter | `rtl/common_blocks/timeout_counter.sv` | Detects completion timeout |
| Synchronous FIFO | `rtl/common_blocks/sync_fifo.sv` | Common buffering utility |
| Endpoint top | `rtl/pcie_endpoint_dma_top.sv` | Integrates endpoint, DMA, request tracking, and TX arbitration |

---

## BAR0 and DMA Register Map

BAR0 is modeled at:

```text
Base Address = 0x8000_0000
Size         = 4 KB
```

DMA registers:

| Offset | Register | Description |
|---:|---|---|
| `0x00` | `SRC_ADDR` | DMA source address |
| `0x04` | `DST_ADDR` | DMA destination address |
| `0x08` | `LENGTH` | Transfer length in bytes |
| `0x0C` | `CONTROL` | START / status control |
| `0x10` | `STATUS` | BUSY / DONE / ERROR |

---

## DMA Operation

The DMA controller transfers one 32-bit DWORD at a time and iterates across longer transfers.

```text
IDLE
 |
 v
ISSUE_READ
 |
 v
WAIT_READ
 |
 v
ISSUE_WRITE
 |
 v
WAIT_WRITE
 |
 +------ more data ------+
 |                       |
 v                       |
ISSUE_READ <-------------+
 |
 | last DWORD
 v
DONE
```

For each read transaction, the DMA read engine allocates a tag, creates an outstanding entry, generates a Memory Read TLP, starts timeout tracking, waits for the matching Completion, returns data to the controller, and reports timeout or completion-status errors when necessary.

DMA writes are posted transactions and therefore do not wait for a Completion.

---

## Outstanding Request Tracking

The outstanding-request table supports multiple active entries and performs tag-indexed completion lookup rather than FIFO-order matching.

Unit verification exercises multiple simultaneous entries and completes them out of allocation order, demonstrating that the table can correctly identify and retire requests by tag.

> The outstanding-request table supports multiple concurrent tagged requests and out-of-order completion matching, but the current DMA read engine intentionally permits only one outstanding DMA read at a time.

Therefore this project does **not** claim end-to-end multi-outstanding DMA execution.

---

## TX Arbitration

The endpoint has three TX producers:

1. Endpoint Completion traffic
2. DMA Memory Read traffic
3. DMA Memory Write traffic

The current arbiter uses fixed priority:

```text
Completion > DMA Memory Read > DMA Memory Write
```

Integration verification exercised a contention case with TX backpressure. A DMA Memory Read was pending while `tx_ready` was held low; a host Memory Read then caused an endpoint Completion to contend for the same TX path. The test verified that the Completion won with the expected tag and payload, then confirmed that the previously blocked DMA request was preserved and serviced afterward.

This verifies fixed-priority arbitration for the tested contention event.

The design does **not** claim fairness or starvation freedom under sustained higher-priority Completion traffic.

---

## Error Handling

The design includes handling for:

- Invalid BAR access
- Unsupported Request
- Completer Abort
- Unexpected Completion
- Duplicate outstanding tag
- Completion timeout
- Invalid DMA transfer length
- Unaligned DMA source address
- Unaligned DMA destination address
- Unsupported TLP format
- TX formatter errors

---

## Verification Methodology

Verification was performed at multiple levels:

```text
RTL Module
   |
   v
Self-Checking Unit Test
   |
   v
Integration Test
   |
   v
SystemVerilog Assertions
   |
   v
UVM Environment
   |
   v
Directed / Constrained Sequences
   |
   v
Monitor
   |
   +---------------------+
   |                     |
   v                     v
Scoreboard            Coverage
   |
   v
Multi-Seed Regression
```

---

## Unit Verification

Thirteen self-checking block-level testbenches were executed successfully:

| Unit Test | Result |
|---|---|
| `bar_decoder_tb` | PASS |
| `completion_engine_tb` | PASS |
| `dma_controller_tb` | PASS |
| `dma_read_engine_tb` | PASS |
| `dma_regs_tb` | PASS |
| `dma_write_engine_tb` | PASS |
| `endpoint_memory_tb` | PASS |
| `outstanding_req_table_tb` | PASS |
| `request_handler_tb` | PASS |
| `sync_fifo_tb` | PASS |
| `timeout_counter_tb` | PASS |
| `tlp_rx_parser_tb` | PASS |
| `tlp_tx_formatter_tb` | PASS |

**Final unit regression: 13/13 PASS**

---

## Integration Verification

| Integration Test | Scope | Result |
|---|---|---|
| `pcie_endpoint_smoke_tb` | Endpoint Memory Read/Write, Completion generation, invalid BAR / UR behavior | PASS |
| `pcie_dma_integration_tb` | DMA configuration, read/completion/write flow, busy handling, restart, TX contention, reset recovery | PASS |
| `pcie_error_integration_tb` | Error paths, unexpected completion, CA, timeout, cleanup, TX backpressure | PASS |

**Final integration regression: 3/3 PASS**

---

## Targeted DMA and Arbitration Tests

### 256-Byte / 64-DWORD DMA Stress

The DMA controller unit test executes a 256-byte transfer consisting of 64 DWORD operations. For every DWORD, the test checks the expected source address, destination address, forwarded data, byte enable, successful completion, and that no unexpected 65th transaction occurs.

This is a controller-level sequencing/data-forwarding test. It is **not** claimed as a physical source-memory-to-destination-memory byte-for-byte comparison.

### START While BUSY

The integrated DMA test issues a second START request while an existing DMA transfer is active. The test verifies that DMA remains BUSY, outstanding request count remains unchanged, no duplicate DMA Memory Read is generated, the in-flight transfer completes normally, and a fresh START issued after completion executes normally.

The busy-time START is intentionally **ignored**, not queued.

### Completion vs DMA TX Contention

The integrated test verifies the fixed-priority arbiter while `tx_ready` is held low. It confirms that Completion traffic wins over the pending DMA Memory Read, Completion tag/payload remain correct, the losing DMA request is not lost, and the DMA request is serviced successfully after the Completion.

### Reset During Active DMA

The integrated test asserts reset while a DMA read is outstanding. It checks that DMA BUSY, outstanding-request state, DMA error, unexpected-completion indication, and TX formatter error indication are cleared. The DMA registers are then reprogrammed and a new transfer completes successfully after reset.

---

## UVM Verification Environment

```text
pcie_base_test
   |
   +-- pcie_env
       |
       +-- pcie_agent
       |   +-- pcie_sequencer
       |   +-- pcie_driver
       |   +-- pcie_monitor
       |
       +-- dma_agent
       |   +-- dma_monitor
       |
       +-- pcie_scoreboard
       +-- pcie_coverage
```

Current UVM tests:

```text
pcie_smoke_test
pcie_dma_test
pcie_error_test
```

The final merged UVM regression executed each test across five seeds:

```text
3 tests x 5 seeds = 15 UVM runs
```

**Final UVM regression: 15/15 PASS**

Every final regression log completed with:

```text
UVM_ERROR : 0
UVM_FATAL : 0
```

The scoreboard also completed cleanly with no pending expected Completion, UR, or DMA state.

---

## SystemVerilog Assertions

Assertions cover behaviors including TX stability under backpressure, payload requirements, known TX header values, DMA command stability, address alignment, DONE/ERROR mutual exclusion, duplicate-tag protection, completion/cancellation matching, outstanding-count bounds, and full-table consistency.

---

## Coverage Results

Final merged UVM coverage snapshot:

| Metric | Coverage |
|---|---:|
| Overall score | **72.07%** |
| Line | **92.56%** |
| Condition | **74.38%** |
| Toggle | **36.57%** |
| FSM | **62.86%** |
| Branch | **78.12%** |
| Assertion | **66.67%** |
| Functional / Covergroup | **93.33%** |

A targeted UVM register-pattern sequence increased `dma_regs` toggle coverage to **81.05%**.

The remaining lower aggregate toggle/FSM/assertion percentages include structurally difficult or intentionally unexercised conditions such as reset/default-recovery FSM transitions and library/internal assertions. Coverage was not artificially inflated by forcing unrealistic scenarios or merging unrelated tops.

---

## Verified Results Summary

| Area | Final Result |
|---|---|
| Unit tests | **13/13 PASS** |
| Integration tests | **3/3 PASS** |
| UVM regression | **15/15 PASS** |
| UVM errors | **0** |
| UVM fatals | **0** |
| Functional coverage | **93.33%** |
| Line coverage | **92.56%** |
| Overall merged coverage score | **72.07%** |
| 256-byte / 64-DWORD DMA sequencing | **Verified at controller unit level** |
| START while BUSY handling | **Verified at integration level** |
| TX contention under backpressure | **Verified at integration level** |
| Reset during active DMA + recovery | **Verified at integration level** |
| Multi-entry out-of-order tag lookup | **Verified at outstanding-table unit level** |

---

## Known Limitations

- The DMA read engine allows only one outstanding DMA read at a time.
- Multi-entry / out-of-order behavior is verified at the outstanding-request-table level, not as multi-outstanding end-to-end DMA traffic.
- TX arbitration is fixed-priority and fairness/starvation freedom under sustained higher-priority traffic is not verified.
- The 256-byte stress test verifies per-DWORD sequencing and data forwarding at the DMA-controller level rather than full source-memory-to-destination-memory comparison.
- Only simplified 3DW / 32-bit Transaction Layer behavior is modeled.
- This is not a complete PCIe-compliant controller implementation.

---

## Project Structure

```text
pcie_endpoint_dma/
├── README.md
├── .gitignore
├── docs/
├── rtl/
│   ├── common/
│   ├── common_blocks/
│   ├── dma/
│   ├── memory/
│   ├── pcie/
│   └── pcie_endpoint_dma_top.sv
├── tb/
│   ├── sv/
│   │   ├── integration/
│   │   └── unit/
│   └── uvm/
├── sva/
│   ├── dma_assertions.sv
│   ├── pcie_assertions.sv
│   ├── sva_bind.sv
│   └── tag_assertions.sv
├── sim/
│   ├── filelists/
│   └── vcs/
│       ├── Makefile
│       ├── run_integration.sh
│       ├── run_unit.sh
│       └── run_uvm.sh
└── scripts/
    ├── python/
    │   ├── parse_results.py
    │   └── run_regression.py
    └── tcl/
        └── run_coverage.tcl
```

Generated VCS binaries, build databases, logs, waveforms, and coverage databases are excluded from version control through `.gitignore`.

---

## Running the Tests

### Unit Tests

```bash
./sim/vcs/run_unit.sh tlp_rx_parser_tb
./sim/vcs/run_unit.sh bar_decoder_tb
./sim/vcs/run_unit.sh dma_controller_tb
```

### Integration Tests

```bash
./sim/vcs/run_integration.sh smoke
./sim/vcs/run_integration.sh dma
./sim/vcs/run_integration.sh error
```

### UVM Tests

```bash
./sim/vcs/run_uvm.sh pcie_smoke_test
./sim/vcs/run_uvm.sh pcie_dma_test
./sim/vcs/run_uvm.sh pcie_error_test
```

A specific random seed can be supplied as the second argument:

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 25
```

### Regression Automation

```bash
python3 scripts/python/run_regression.py --unit
python3 scripts/python/run_regression.py --integration
python3 scripts/python/run_regression.py --uvm
```

> Synopsys VCS and a valid simulator environment/license are required to run the supplied VCS flow.

---

## Tools Used

- SystemVerilog
- UVM
- SystemVerilog Assertions
- Synopsys VCS
- Synopsys DVE
- Python
- Tcl
- Bash
- GNU Make
- Linux
- Git / GitHub

---

## Key Learning Outcomes

This project demonstrates practical experience with PCIe Transaction Layer concepts, TLP parsing/formatting, posted vs non-posted transactions, BAR decoding, request/completion handling, tags and outstanding-request tracking, DMA architecture, timeout/error recovery, fixed-priority arbitration, self-checking verification, UVM, assertions, coverage closure, and multi-seed regression.

---

## Summary

Designed and verified a simplified PCIe Endpoint Transaction Layer with an integrated DMA engine using SystemVerilog and UVM. The project includes BAR0 decoding, endpoint memory, Memory Read/Write TLP handling, Completion processing, tag-based outstanding-request tracking, timeout/error handling, DMA sequencing, and fixed-priority TX arbitration.

Final verification completed with **13/13 unit tests passing, 3/3 integration tests passing, and 15/15 UVM regression runs passing with 0 UVM errors and 0 UVM fatal errors**. The final UVM coverage snapshot achieved **93.33% functional coverage** and **92.56% line coverage**.

The project intentionally documents its remaining architectural and verification limits, including single-outstanding DMA-read operation and the absence of a fairness/starvation guarantee for sustained fixed-priority TX contention.
