# PCIe Endpoint Transaction Layer with DMA Engine

## Coverage Plan

---

# 1. Purpose

This document defines the coverage strategy for the PCIe Endpoint Transaction Layer with DMA Engine project.

The goal of coverage is to measure whether the verification environment has exercised the important functional scenarios, RTL structures, protocol combinations, DMA behaviors, and error conditions defined by the project scope.

Coverage is divided into three major areas:

```text
Functional Coverage
Code Coverage
Assertion Coverage
```

Coverage collection was performed using Synopsys VCS after RTL and UVM bring-up reached a stable state.

---

# 2. Coverage Objectives

The main coverage objectives are:

- Exercise all supported PCIe TLP types
- Exercise both RX and TX transaction directions
- Exercise posted and non-posted traffic
- Exercise valid and invalid BAR accesses
- Exercise endpoint memory accesses
- Exercise DMA register accesses
- Exercise DMA success paths
- Exercise DMA error paths
- Exercise Completion status values
- Exercise tag allocation and Completion matching
- Exercise unexpected Completion handling
- Exercise timeout behavior
- Exercise byte-enable combinations
- Exercise multiple transfer lengths
- Exercise outstanding request occupancy
- Exercise backpressure behavior
- Exercise important FSM states and transitions
- Exercise relevant assertion properties

---

# 3. Coverage Categories

The coverage plan includes:

```text
TLP Coverage
BAR Coverage
Memory Coverage
DMA Coverage
Tag Coverage
Completion Coverage
Error Coverage
Handshake Coverage
FSM Coverage
Assertion Coverage
Code Coverage
Cross Coverage
```

---

# 4. Functional Coverage Architecture

Functional coverage is collected primarily from the PCIe monitor and DMA status monitor.

Current UVM coverage component:

```text
tb/uvm/coverage/pcie_coverage.sv
```

Data sources:

```text
PCIe Monitor
    |
    v
pcie_seq_item
    |
    v
Functional Coverage

DMA Status Monitor
    |
    v
dma_status_item
    |
    v
Future DMA Coverage
```

---

# 5. TLP Direction Coverage

Coverpoint:

```text
Transaction Direction
```

Bins:

```text
RX
TX
```

Expected coverage:

```text
RX hit
TX hit
```

---

# 6. TLP Type Coverage

Coverpoint:

```text
TLP Kind
```

Bins:

```text
MEM_RD
MEM_WR
CPL
CPLD
UNSUPPORTED
```

Expected behavior:

```text
MEM_RD         Covered
MEM_WR         Covered
CPL            Covered
CPLD           Covered
UNSUPPORTED    Covered by negative testing
```

---

# 7. TLP Length Coverage

Coverpoint:

```text
length_dw
```

Initial bins:

```text
1 DW
2-4 DW
5-16 DW
```

Current RTL primarily uses:

```text
1 DW
```

The larger bins are intended for future expansion.

Example:

```systemverilog
cp_length:
  coverpoint length_sample {

    bins one_dw = {1};

    bins small =
      {[2:4]};

    bins medium =
      {[5:16]};

  }
```

---

# 8. Byte Enable Coverage

Coverpoint:

```text
first_be
```

Important bins:

```text
0001
0010
0100
1000
0011
0110
1100
1111
```

Broad classification:

```text
Full Write
Partial Write
```

Current implementation commonly uses:

```text
1111
```

Future testing should intentionally exercise partial byte enables.

---

# 9. Completion Status Coverage

Coverpoint:

```text
cpl_status
```

Bins:

```text
SC
UR
CRS
CA
```

Primary project targets:

```text
SC
UR
CA
```

CRS is defined in the package but is not a major functional path in the current project.

---

# 10. Direction × TLP Type Cross Coverage

Cross:

```text
Direction x TLP Kind
```

Useful combinations:

```text
RX x MEM_RD
RX x MEM_WR
RX x CPL
RX x CPLD

TX x MEM_RD
TX x MEM_WR
TX x CPL
TX x CPLD
```

This verifies that both incoming and outgoing protocol roles are exercised.

---

# 11. Posted vs Non-Posted Coverage

Classification:

```text
Posted
Non-Posted
```

Bins:

```text
Memory Write -> Posted
Memory Read  -> Non-Posted
```

Expected scenarios:

```text
Posted TX
Posted RX
Non-Posted TX
Non-Posted RX
```

---

# 12. BAR Coverage

Coverage points:

```text
BAR Hit
BAR Miss
BAR Base Address
Address Inside BAR
Last Valid BAR Address
First Invalid Address
Address Below BAR
```

Suggested bins:

```text
BASE
LOW_RANGE
MID_RANGE
HIGH_RANGE
LAST_VALID
MISS_BELOW
MISS_ABOVE
```

---

# 13. Local Address Region Coverage

BAR0 local regions:

```text
DMA Registers
Endpoint Memory
Unused / Invalid Region
```

Coverpoint:

```text
local_target
```

Bins:

```text
DMA_REG
MEMORY
INVALID
```

---

# 14. DMA Register Coverage

Registers:

```text
SRC_ADDR
DST_ADDR
LENGTH
CONTROL
STATUS
```

Coverage goals:

```text
Read each register
Write each writable register
Start DMA
Clear status
Read status during idle
Read status during busy
Read status after done
Read status after error
```

---

# 15. Endpoint Memory Coverage

Coverage scenarios:

```text
Full DWORD Write
Full DWORD Read
Partial Write
Read After Write
Multiple Addresses
Unaligned Access
Out-of-Range Access
```

Suggested address bins:

```text
LOW
MID
HIGH
BOUNDARY
```

---

# 16. DMA Transfer Length Coverage

Coverpoint:

```text
dma_length_bytes
```

Planned bins:

```text
4 bytes
8 bytes
16 bytes
32 bytes
64 bytes
```

Invalid bins:

```text
0 bytes
Non-DWORD-Aligned Length
```

Example:

```text
3 bytes
5 bytes
6 bytes
```

---

# 17. DMA Source Address Coverage

Address classification:

```text
Aligned
Unaligned
Low Address
Middle Address
High Address
```

Important invalid bins:

```text
Address % 4 = 1
Address % 4 = 2
Address % 4 = 3
```

---

# 18. DMA Destination Address Coverage

Same classification as source:

```text
Aligned
Unaligned
Low
Mid
High
```

---

# 19. DMA Result Coverage

Coverpoint:

```text
DMA Result
```

Bins:

```text
DONE
ERROR
```

Error categories may later be split into:

```text
INVALID_CONFIG
COMPLETION_ERROR
TIMEOUT
WRITE_ERROR
```

---

# 20. DMA FSM Coverage

DMA Controller states:

```text
IDLE
ISSUE_READ
WAIT_READ
ISSUE_WRITE
WAIT_WRITE
DONE
ERROR
```

Coverage goal:

```text
Every state entered
```

Important transitions:

```text
IDLE -> ISSUE_READ

ISSUE_READ -> WAIT_READ

WAIT_READ -> ISSUE_WRITE

ISSUE_WRITE -> WAIT_WRITE

WAIT_WRITE -> ISSUE_READ

WAIT_WRITE -> DONE

WAIT_READ -> ERROR

WAIT_WRITE -> ERROR

IDLE -> ERROR
```

---

# 21. DMA Read Engine FSM Coverage

States:

```text
IDLE
ALLOCATE
SEND
WAIT_CPL
DONE
ERROR
```

Important transitions:

```text
IDLE -> ALLOCATE
ALLOCATE -> SEND
SEND -> WAIT_CPL
WAIT_CPL -> DONE
WAIT_CPL -> ERROR
DONE -> IDLE
ERROR -> IDLE
```

---

# 22. DMA Write Engine FSM Coverage

States:

```text
IDLE
SEND
DONE
ERROR
```

Transitions:

```text
IDLE -> SEND
SEND -> DONE
DONE -> IDLE

IDLE -> ERROR
ERROR -> IDLE
```

---

# 23. Request Handler FSM Coverage

States:

```text
IDLE
WAIT_MEM_RD
WAIT_MEM_WR
```

Transitions:

```text
IDLE -> WAIT_MEM_RD
WAIT_MEM_RD -> IDLE

IDLE -> WAIT_MEM_WR
WAIT_MEM_WR -> IDLE
```

---

# 24. Outstanding Request Count Coverage

Coverpoint:

```text
outstanding_count
```

Suggested bins:

```text
ZERO
ONE
LOW
MID
HIGH
FULL
```

Example for 16 entries:

```text
0
1
2-4
5-8
9-15
16
```

The current DMA engine issues only one read at a time, so deeper occupancy bins are future coverage targets.

---

# 25. Tag Coverage

Coverpoint:

```text
tag
```

Suggested bins:

```text
0x00
0x01
LOW_RANGE
MID_RANGE
HIGH_RANGE
0xFF
```

Coverage goals:

- Multiple tags used
- Tag reuse after Completion
- Duplicate tag attempt
- Unknown Completion tag

---

# 26. Tag Allocation Coverage

Scenarios:

```text
Successful Allocation
Duplicate Tag
Table Full
Cancellation
Completion Release
```

---

# 27. Completion Matching Coverage

Coverage scenarios:

```text
Matching Completion
Unexpected Completion
Out-of-Order Completion
Completion After Delay
Completion Near Timeout
```

---

# 28. Completion Order Coverage

Future classification:

```text
IN_ORDER
OUT_OF_ORDER
```

Example:

```text
Issued:
01 02 03

Received:
01 02 03
```

is:

```text
IN_ORDER
```

Example:

```text
Issued:
01 02 03

Received:
03 01 02
```

is:

```text
OUT_OF_ORDER
```

---

# 29. Completion Latency Coverage

Latency bins:

```text
0 cycles
1 cycle
2-5 cycles
6-15 cycles
16-31 cycles
Near Timeout
Timeout
```

This becomes particularly important when random Completion delays are added.

---

# 30. Completion Timeout Coverage

Coverage goals:

```text
Completion before timeout
Completion one cycle before timeout
Exact timeout boundary
No Completion
Timeout error
Outstanding cancellation
```

---

# 31. Error Coverage

Error categories:

```text
Invalid BAR
Unsupported Request
Completer Abort
Unexpected Completion
Duplicate Tag
Timeout
Unaligned DMA Source
Unaligned DMA Destination
Invalid DMA Length
Formatter Error
```

Each meaningful error path should have at least one functional coverage hit.

---

# 32. Backpressure Coverage

The design uses ready/valid interfaces.

Future coverpoint:

```text
stall_cycles
```

Bins:

```text
0
1
2-3
4-7
8+
```

Interfaces to exercise:

```text
PCIe TX
DMA Read Command
DMA Write Command
Completion Engine
```

---

# 33. TX Arbitration Coverage

TX producers:

```text
Completion Engine
DMA Read Engine
DMA Write Engine
```

Coverpoint:

```text
tx_source
```

Bins:

```text
COMPLETION
DMA_READ
DMA_WRITE
```

Future cross:

```text
TX Source x Backpressure
```

---

# 34. TX Arbitration Priority Coverage

Priority:

```text
1. Completion
2. DMA Read
3. DMA Write
```

Useful future scenarios:

```text
Completion + DMA Read pending
Completion + DMA Write pending
DMA Read + DMA Write pending
All three pending
```

Expected:

```text
Highest-priority source wins
Lower-priority request remains pending
```

---

# 35. Payload Coverage

Payload categories:

```text
0x00000000
0xFFFFFFFF
Walking Ones
Walking Zeros
Alternating Pattern
Random Data
```

Examples:

```text
0xAAAAAAAA
0x55555555
0xDEADBEEF
0xCAFEBABE
```

---

# 36. Memory Data Coverage

Reference memory traffic should include:

```text
Repeated write to same address
Read after write
Partial overwrite
Different addresses
Boundary address
Random data
```

---

# 37. Reset Coverage

Planned reset scenarios:

```text
Reset at idle
Reset after configuration
Reset during DMA read
Reset while waiting for Completion
Reset during write
Reset while outstanding entry exists
```

Coverage should indicate whether reset occurred in each meaningful state.

---

# 38. Assertion Coverage

Assertion files:

```text
sva/pcie_assertions.sv
sva/dma_assertions.sv
sva/tag_assertions.sv
```

Coverage should track:

```text
Assertion attempts
Assertion passes
Assertion failures
Cover-property hits
```

No unexplained assertion failures are acceptable at verification closure.

---

# 39. PCIe Assertion Coverage Targets

Properties include:

```text
RX MemWr has payload
RX MemRd has no payload

TX MemWr has payload
TX MemRd has no payload

CplD has payload
Cpl has no payload

TX stable during stall

TX header known
```

---

# 40. DMA Assertion Coverage Targets

Properties include:

```text
DONE/ERROR exclusive

Read address aligned

Write address aligned

Read command stable while stalled

Write command stable while stalled

No simultaneous read/write command

Start address alignment
```

---

# 41. Tag Assertion Coverage Targets

Properties include:

```text
Duplicate tag rejected

Match/unexpected mutually exclusive

Match requires completion

Unexpected requires completion

Cancel match requires cancel

Outstanding count within range

Full count consistency
```

---

# 42. Code Coverage

Planned code coverage types:

```text
Line
Branch
Condition
FSM
Toggle
```

VCS option:

```bash
-cm line+cond+fsm+tgl+branch+assert
```

---

# 43. Line Coverage

Goal:

Exercise meaningful RTL statements.

Low line coverage may indicate:

```text
Untested logic
Dead logic
Error path not exercised
Unsupported configuration
```

Each uncovered line should be reviewed rather than blindly targeted.

---

# 44. Branch Coverage

Important branch-heavy modules:

```text
request_handler.sv
dma_controller.sv
dma_read_engine.sv
dma_write_engine.sv
outstanding_req_table.sv
tlp_tx_formatter.sv
```

All meaningful legal and error branches should be exercised.

---

# 45. Condition Coverage

Condition coverage is important for expressions such as:

```text
bar_hit
duplicate_found
completion_found
address_valid
address_aligned
tx_ready
mem_rsp_valid
timeout_hit
```

---

# 46. FSM Coverage

FSM coverage should include:

```text
State Coverage
Transition Coverage
```

Important FSMs:

```text
Request Handler
DMA Controller
DMA Read Engine
DMA Write Engine
```

---

# 47. Toggle Coverage

Toggle coverage should be reviewed for:

```text
Control signals
Status bits
Address bits
Tag bits
Data bits
Counters
FSM encodings
```

Low toggle coverage on unused parameterized bits may be acceptable if documented.

---

# 48. Coverage Exclusions

Some coverage may be intentionally excluded.

Examples:

```text
Unsupported PCIe formats
Unused reserved header bits
Parameter configurations not used by project
Impossible FSM transitions
Unused memory entries
Future protocol features
```

Exclusions should be justified and documented.

Coverage exclusions must not be used to hide reachable untested functionality.

---

# 49. Functional Coverage Crosses

Recommended crosses include:

```text
Direction x TLP Type

TLP Type x Completion Status

MemWr x Byte Enable

MemRd x BAR Hit/Miss

DMA Length x DMA Result

DMA Result x Completion Status

Outstanding Count x Completion Order

Completion Latency x Completion Status

TX Source x Backpressure
```

---

# 50. Current Coverage Model

Current implemented functional coverage:

```text
Direction
TLP Kind
Length
First Byte Enable
Completion Status
Direction x TLP Kind
```

Implemented in:

```text
tb/uvm/coverage/pcie_coverage.sv
```

---

# 51. Planned Coverage Model Expansion

After initial UVM bring-up, expand coverage to include:

```text
BAR hit/miss
DMA status
Outstanding count
Unexpected Completion
DMA timeout
DMA Done/Error
Completion latency
Tag distribution
Partial writes
TX arbitration
Backpressure
```

---

# 52. Coverage Collection Flow

```text
Compile RTL + UVM
      |
      v
Enable VCS Coverage
      |
      v
Run Test
      |
      v
Generate .vdb
      |
      v
Run More Seeds
      |
      v
Merge Coverage Databases
      |
      v
Generate Report
      |
      v
Analyze Holes
      |
      v
Create Targeted Tests
      |
      v
Re-run Regression
```

---

# 53. Planned Coverage Database Structure

Example:

```text
coverage/
├── pcie_smoke_test_seed_1.vdb
├── pcie_dma_test_seed_1.vdb
├── pcie_dma_test_seed_2.vdb
├── pcie_error_test_seed_1.vdb
│
├── merged.vdb
│
└── reports/
```

---

# 54. Planned VCS Coverage Compile Command

Example:

```bash
vcs \
    -full64 \
    -sverilog \
    -ntb_opts uvm \
    -cm line+cond+fsm+tgl+branch+assert \
    -f sim/filelists/uvm.f \
    -top tb_top
```

---

# 55. Planned Simulation Coverage Command

Example:

```bash
./simv \
    +UVM_TESTNAME=pcie_dma_test \
    +ntb_random_seed=25 \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir coverage/pcie_dma_test_seed_25.vdb
```

The final coverage flow was executed using the available Synopsys VCS environment.

---

# 56. Coverage Merge

A future merged coverage flow may use Synopsys URG.

Conceptually:

```bash
urg \
    -dir coverage/test1.vdb \
         coverage/test2.vdb \
         coverage/test3.vdb \
    -dbname coverage/merged.vdb
```

The final coverage merge and reporting flow was validated with the installed Synopsys VCS/URG environment.

---

# 57. Coverage Report

Planned report directory:

```text
coverage/reports/
```

Coverage report should include:

```text
Overall Code Coverage
Line Coverage
Branch Coverage
Condition Coverage
FSM Coverage
Toggle Coverage
Assertion Coverage
Functional Coverage
```

---

# 58. Coverage Closure Process

Coverage closure should follow:

```text
Run Regression
     |
     v
Generate Coverage
     |
     v
Find Uncovered Bin/Line
     |
     v
Classify
     |
     +--> Reachable
     |
     +--> Unreachable
     |
     +--> Out of Scope
     |
     v
If Reachable
     |
     v
Add Test / Sequence
     |
     v
Re-run
```

---

# 59. Coverage Hole Classification

Every meaningful hole should be classified as:

```text
Missing Stimulus

Verification Environment Limitation

RTL Bug

Unreachable Logic

Out-of-Scope Functionality

Intentional Exclusion
```

---

# 60. Example Coverage Hole

Suppose:

```text
CPL_STATUS_CA bin = 0 hits
```

Action:

```text
Create a sequence that returns Completer Abort.
```

Expected:

```text
CA bin hit
DMA error path hit
DMA ERROR state covered
```

---

# 61. Example FSM Coverage Hole

Suppose:

```text
DMA Controller ERROR state never entered.
```

Possible action:

```text
Inject read error
or
Inject write error
or
Use invalid configuration
```

---

# 62. Example Tag Coverage Hole

Suppose:

```text
Duplicate Tag bin never hit.
```

Action:

```text
Force or generate second allocation with active tag.
```

Check:

```text
alloc_duplicate = 1
alloc_ready = 0
```

---

# 63. Coverage Goals

Exact percentages should only be set after the first real coverage run.

Initial project goals may later target approximately:

```text
Functional Coverage:
High coverage of all defined reachable bins

FSM Coverage:
All intended states and transitions

Assertion Coverage:
All meaningful properties exercised

Code Coverage:
High coverage with documented exclusions
```

No exact percentage should be claimed until actual VCS results are available.

---

# 64. Verification Closure Criteria

Coverage closure should require:

```text
All planned tests pass

All major functional coverage bins hit

All intended FSM states hit

All intended FSM transitions hit

No unexplained assertion failures

All important code coverage holes reviewed

Unreachable logic documented

Out-of-scope functionality documented

Regression remains stable after targeted tests
```

---

# 65. Coverage Status Table

The final merged UVM coverage results are summarized below.

| Coverage Area | Final Result | Status |
|---|---:|---|
| Functional | 93.33% | Final merged UVM snapshot |
| Line | 92.56% | Final merged UVM snapshot |
| Branch | 78.12% | Final merged UVM snapshot |
| Condition | 74.38% | Final merged UVM snapshot |
| FSM | 62.86% | Final merged UVM snapshot |
| Toggle | 36.57% | Final merged UVM snapshot |
| Assertion | 66.67% | Final merged UVM snapshot |

These percentages are taken from the final merged VCS/UVM coverage snapshot.

---

# 66. Planned Functional Coverage Checklist

```text
[ ] RX MemRd
[ ] RX MemWr
[ ] RX Cpl
[ ] RX CplD

[ ] TX MemRd
[ ] TX MemWr
[ ] TX Cpl
[ ] TX CplD

[ ] BAR Hit
[ ] BAR Miss

[ ] Full Byte Enable
[ ] Partial Byte Enable

[ ] Completion SC
[ ] Completion UR
[ ] Completion CA

[ ] DMA Done
[ ] DMA Error

[ ] Expected Completion
[ ] Unexpected Completion

[ ] Tag Allocation
[ ] Duplicate Tag
[ ] Cancellation

[ ] Outstanding Count 0
[ ] Outstanding Count 1
[ ] Outstanding Count >1
[ ] Table Full

[ ] Immediate Completion
[ ] Delayed Completion
[ ] Timeout

[ ] TX No Stall
[ ] TX Backpressure
```

Some items require future RTL/UVM extensions before they can be covered.

---

# 67. Current Coverage Status

Final project coverage status:

```text
Functional Coverage Model : Executed
Code Coverage Setup        : Executed
Assertion Coverage Setup   : Executed
Coverage Execution         : Complete
Coverage Merge             : Complete
Coverage Analysis          : Complete
Coverage Closure           : Complete for final project scope
```

Coverage results must not be invented or estimated.

---

# 68. Summary

The coverage strategy is intended to answer two questions:

```text
Did the tests execute the important behaviors?

Did the RTL structures actually get exercised?
```

Functional coverage answers the first question.

Code and FSM coverage help answer the second.

Assertion coverage provides additional confidence that protocol and control properties were actively exercised.

The final coverage process is:

```text
Test
 |
 v
Collect
 |
 v
Merge
 |
 v
Analyze
 |
 v
Target Gaps
 |
 v
Re-run
 |
 v
Coverage Closure
```

Coverage closure was completed after the RTL, directed tests, integration tests, assertions, and UVM environment successfully executed under Synopsys VCS. Remaining uncovered areas were reviewed and retained where they represented reset/default-recovery behavior, library/internal assertions, or functionality outside the intended project scope.