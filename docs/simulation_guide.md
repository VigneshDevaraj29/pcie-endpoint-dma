# PCIe Endpoint Transaction Layer with DMA Engine

## Simulation Guide

---

# 1. Purpose

This document describes how to compile, simulate, debug, run regressions, and collect coverage for the PCIe Endpoint Transaction Layer with DMA Engine project using Synopsys VCS.

The intended simulation environment is:

```text
Linux
Synopsys VCS
Synopsys DVE
SystemVerilog
UVM
Python
Tcl
Bash
Make
```

This guide should be used after Synopsys tool access is available.

---

# 2. Project Root

All commands in this document assume you are located at the project root.

Example:

```bash
cd /home/<user>/Projects/PCIe/pcie_endpoint_dma
```

Verify:

```bash
pwd
```

Expected structure:

```text
pcie_endpoint_dma/
├── rtl/
├── tb/
├── sva/
├── sim/
├── scripts/
├── logs/
├── coverage/
├── docs/
└── README.md
```

---

# 3. Check Synopsys Tool Access

Before compiling the project, confirm that VCS is available.

Run:

```bash
which vcs
```

Also check:

```bash
which vlogan
```

Optional version check:

```bash
vcs -ID
```

If VCS is correctly configured, these commands should resolve to the Synopsys installation.

---

# 4. Recommended Validation Order

Do not begin with the full UVM regression.

Use the following order:

```text
1. Verify VCS environment
2. Compile PCIe package
3. Compile RTL
4. Run unit tests one by one
5. Fix all RTL/TB issues
6. Run integration tests
7. Enable and validate assertions
8. Compile UVM
9. Run UVM smoke test
10. Run DMA UVM test
11. Run error UVM test
12. Run multiple seeds
13. Enable coverage
14. Merge coverage
15. Analyze coverage gaps
```

This makes debug significantly easier.

---

# 5. Compile the PCIe Package First

The first source file to validate is:

```text
rtl/common/pcie_tlp_pkg.sv
```

Run:

```bash
vlogan -full64 -sverilog rtl/common/pcie_tlp_pkg.sv
```

This checks:

```text
Package syntax
Enums
Structs
Functions
SystemVerilog syntax
```

Fix any errors before moving forward.

---

# 6. Compile RTL Using Filelist

RTL compile order is defined in:

```text
sim/filelists/rtl.f
```

Compile:

```bash
vlogan -full64 -sverilog -f sim/filelists/rtl.f
```

Alternatively, use VCS directly:

```bash
vcs \
    -full64 \
    -sverilog \
    -f sim/filelists/rtl.f \
    -top pcie_endpoint_dma_top
```

If only checking syntax and elaboration, no simulation is required yet.

---

# 7. RTL Filelist

The RTL filelist should contain files in dependency order.

Example:

```text
rtl/common/pcie_tlp_pkg.sv

rtl/common_blocks/sync_fifo.sv
rtl/common_blocks/timeout_counter.sv

rtl/pcie/tlp_rx_parser.sv
rtl/pcie/tlp_tx_formatter.sv
rtl/pcie/bar_decoder.sv
rtl/pcie/request_handler.sv
rtl/pcie/completion_engine.sv
rtl/pcie/outstanding_req_table.sv

rtl/memory/endpoint_memory.sv

rtl/dma/dma_regs.sv
rtl/dma/dma_read_engine.sv
rtl/dma/dma_write_engine.sv
rtl/dma/dma_controller.sv

rtl/pcie_endpoint_dma_top.sv
```

The package must appear before modules that import it.

---

# 8. Unit Test Execution

Unit tests are located in:

```text
tb/sv/unit/
```

The helper script is:

```text
sim/vcs/run_unit.sh
```

General usage:

```bash
./sim/vcs/run_unit.sh <testbench_name>
```

Example:

```bash
./sim/vcs/run_unit.sh tlp_rx_parser_tb
```

---

# 9. Recommended Unit Test Order

Run tests in this order:

```text
1. tlp_rx_parser_tb
2. bar_decoder_tb
3. endpoint_memory_tb
4. sync_fifo_tb
5. timeout_counter_tb
6. completion_engine_tb
7. tlp_tx_formatter_tb
8. outstanding_req_table_tb
9. request_handler_tb
10. dma_regs_tb
11. dma_write_engine_tb
12. dma_read_engine_tb
13. dma_controller_tb
```

This order roughly follows module dependency and complexity.

---

# 10. Example Unit Test

Run:

```bash
./sim/vcs/run_unit.sh tlp_rx_parser_tb
```

Expected flow:

```text
Compile RTL
Compile Testbench
Elaborate Testbench
Generate simv
Run simv
Generate compile log
Generate simulation log
```

Logs are stored under:

```text
logs/unit/
```

For example:

```text
logs/unit/tlp_rx_parser_tb_compile.log
logs/unit/tlp_rx_parser_tb_run.log
```

---

# 11. Unit Test PASS Criteria

A unit test should only be considered passing if:

```text
VCS compilation succeeds
Simulation exits normally
No unexpected $error
No $fatal
Self-checking test prints PASS
```

Example expected output:

```text
========================================
 TLP RX PARSER TEST: PASS
========================================
```

---

# 12. Unit Test Failure Debug

If a test fails:

```text
1. Open compile log
2. Fix first compile error
3. Recompile
4. Open run log
5. Fix first functional failure
6. Re-run only that test
7. Continue until PASS
```

Do not try to fix many downstream errors before fixing the first real error.

---

# 13. Integration Tests

Integration tests are located in:

```text
tb/sv/integration/
```

Current tests:

```text
pcie_endpoint_smoke_tb.sv
pcie_dma_integration_tb.sv
pcie_error_integration_tb.sv
```

Helper script:

```text
sim/vcs/run_integration.sh
```

---

# 14. Endpoint Smoke Integration

Run:

```bash
./sim/vcs/run_integration.sh smoke
```

Top module:

```text
pcie_endpoint_smoke_tb
```

This test verifies:

```text
Host Memory Write
Endpoint Memory
Host Memory Read
Completion With Data
Invalid BAR
Unsupported Request
```

---

# 15. DMA Integration Test

Run:

```bash
./sim/vcs/run_integration.sh dma
```

Top module:

```text
pcie_dma_integration_tb
```

Expected transaction flow:

```text
Program DMA SRC
Program DMA DST
Program DMA LENGTH
Start DMA
      |
      v
DUT MemRd
      |
      v
Testbench CplD
      |
      v
DUT MemWr
      |
      v
DMA DONE
```

---

# 16. Error Integration Test

Run:

```bash
./sim/vcs/run_integration.sh error
```

Top:

```text
pcie_error_integration_tb
```

Scenarios:

```text
Invalid BAR
Unexpected Completion
Completer Abort
Completion Timeout
Outstanding Entry Cancellation
```

---

# 17. Makefile Usage

The project includes:

```text
sim/vcs/Makefile
```

Examples:

```bash
make -f sim/vcs/Makefile unit-parser
```

```bash
make -f sim/vcs/Makefile unit-bar
```

```bash
make -f sim/vcs/Makefile unit-dma-controller
```

Integration:

```bash
make -f sim/vcs/Makefile integration-smoke
```

```bash
make -f sim/vcs/Makefile integration-dma
```

UVM:

```bash
make -f sim/vcs/Makefile uvm-smoke
```

```bash
make -f sim/vcs/Makefile uvm-dma
```

Clean:

```bash
make -f sim/vcs/Makefile clean
```

---

# 18. UVM Compile Setup

The UVM filelist is:

```text
sim/filelists/uvm.f
```

Compile with:

```bash
vcs \
    -full64 \
    -sverilog \
    -ntb_opts uvm \
    -debug_access+all \
    -timescale=1ns/1ps \
    -f sim/filelists/uvm.f \
    -top tb_top \
    -o sim/vcs/build/uvm/simv
```

---

# 19. UVM Test Execution

Use:

```bash
./sim/vcs/run_uvm.sh <test_name> <seed>
```

The seed argument is optional.

Example:

```bash
./sim/vcs/run_uvm.sh pcie_smoke_test
```

Default seed:

```text
1
```

Specific seed:

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 25
```

---

# 20. Available UVM Tests

Current tests:

```text
pcie_smoke_test
pcie_dma_test
pcie_error_test
```

Run:

```bash
./sim/vcs/run_uvm.sh pcie_smoke_test 1
```

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 1
```

```bash
./sim/vcs/run_uvm.sh pcie_error_test 1
```

---

# 21. UVM Verbosity

The run script currently uses:

```text
+UVM_VERBOSITY=UVM_MEDIUM
```

For less output:

```text
+UVM_VERBOSITY=UVM_LOW
```

For debug:

```text
+UVM_VERBOSITY=UVM_HIGH
```

or:

```text
+UVM_VERBOSITY=UVM_FULL
```

---

# 22. UVM Test Selection

VCS/UVM selects tests using:

```text
+UVM_TESTNAME=<test>
```

Example:

```bash
./simv +UVM_TESTNAME=pcie_dma_test
```

---

# 23. UVM Random Seed

Seed option:

```text
+ntb_random_seed=<seed>
```

Example:

```bash
./simv \
    +UVM_TESTNAME=pcie_dma_test \
    +ntb_random_seed=92831
```

Always preserve the seed when debugging a regression failure.

---

# 24. Regression Automation

Regression script:

```text
scripts/python/run_regression.py
```

Run unit regression:

```bash
python3 scripts/python/run_regression.py --unit
```

Run integration regression:

```bash
python3 scripts/python/run_regression.py --integration
```

Run UVM:

```bash
python3 scripts/python/run_regression.py --uvm
```

---

# 25. Multi-Seed UVM Regression

Example:

```bash
python3 scripts/python/run_regression.py \
    --uvm \
    --seeds 10
```

Seeds:

```text
1
2
3
...
10
```

Specify starting seed:

```bash
python3 scripts/python/run_regression.py \
    --uvm \
    --seeds 10 \
    --start-seed 100
```

This runs:

```text
100
101
102
...
109
```

---

# 26. Full Regression

Run everything:

```bash
python3 scripts/python/run_regression.py \
    --all \
    --seeds 10
```

This includes:

```text
All Unit Tests
All Integration Tests
All UVM Tests
Multiple UVM Seeds
```

---

# 27. Regression Logs

Regression logs are stored in:

```text
logs/regression/
```

Example:

```text
unit_tlp_rx_parser_tb.log
unit_bar_decoder_tb.log
integration_dma.log
uvm_pcie_dma_test_seed_1.log
uvm_pcie_dma_test_seed_2.log
```

---

# 28. Parse Results

Log parser:

```text
scripts/python/parse_results.py
```

Run:

```bash
python3 scripts/python/parse_results.py
```

Example output:

```text
PCIe ENDPOINT + DMA LOG SUMMARY

logs/unit/tlp_rx_parser_tb_run.log        PASS
logs/unit/bar_decoder_tb_run.log         PASS
logs/integration/dma_run.log             PASS
logs/uvm/pcie_dma_test_seed_1.log        PASS
```

---

# 29. Debugging with VCS

Useful compile option:

```text
-debug_access+all
```

This preserves internal design visibility for waveform debug.

The project run scripts currently enable it.

---

# 30. DVE Debug

Once a simulation executable exists, launch DVE using:

```bash
./simv -gui
```

or, depending on VCS version:

```bash
dve -vpd <waveform_file>
```

Exact waveform command should be verified against the installed Synopsys version.

---

# 31. Recommended Waveform Signals

For PCIe RX:

```text
rx_valid
rx_ready
rx_dw0
rx_dw1
rx_dw2
rx_payload_valid
rx_payload_data
```

For PCIe TX:

```text
tx_valid
tx_ready
tx_dw0
tx_dw1
tx_dw2
tx_payload_valid
tx_payload_data
```

---

# 32. DMA Debug Signals

Recommended signals:

```text
dma_start_pulse
dma_busy
dma_done
dma_error

dma_src_addr
dma_dst_addr
dma_length_bytes
```

DMA controller:

```text
state_q
src_addr_q
dst_addr_q
remaining_bytes_q
read_data_q
```

---

# 33. DMA Read Engine Debug

Signals:

```text
state_q
address_q
next_tag_q
active_tag_q

alloc_valid_o
alloc_ready_i
alloc_duplicate_i

tx_valid_o
tx_ready_i

cpl_valid_i
cpl_header_i.tag

timeout_start
timeout_hit

read_done_o
read_error_o
```

---

# 34. Outstanding Table Debug

Signals:

```text
state_q
tag_q
address_q
length_q

free_found
duplicate_found
completion_found
cancel_found

alloc_fire
cpl_fire
cancel_fire

outstanding_count_o
```

---

# 35. Request Handler Debug

Signals:

```text
state_q

req_valid_i
req_ready_o

kind_i
header_i

bar_hit_i
local_addr_i

mem_req_valid_o
mem_req_write_o

mem_rsp_valid_i

cpl_req_valid_o
cpl_status_o
```

---

# 36. Common Failure Types

## Compile Errors

Examples:

```text
Unknown type
Package not imported
Incorrect include path
Port mismatch
Width mismatch
Syntax error
```

Fix compile errors before simulation debugging.

---

## Elaboration Errors

Examples:

```text
Unresolved module
Incorrect parameter
Duplicate definition
Port connection mismatch
```

---

## Simulation Errors

Examples:

```text
Wrong state transition
Timeout
Incorrect data
Incorrect tag
Unexpected Completion
Scoreboard mismatch
Assertion failure
```

---

# 37. VCS Compile Log Debug

Compile logs may contain:

```text
Error-[SE]
Error-[IND]
Error-[XMRE]
Warning-[WIDTH]
```

Focus first on:

```text
Error
```

Warnings should also be reviewed, especially width and truncation warnings.

---

# 38. Recommended Bring-Up Strategy

When VCS access becomes available, use this exact approach:

```text
Step 1
Compile pcie_tlp_pkg.sv

Step 2
Compile rtl.f

Step 3
Run tlp_rx_parser_tb

Step 4
Run bar_decoder_tb

Step 5
Run endpoint_memory_tb

Step 6
Continue unit tests one by one

Step 7
Run integration smoke

Step 8
Run integration DMA

Step 9
Run integration error

Step 10
Compile UVM

Step 11
Run UVM smoke

Step 12
Run UVM DMA

Step 13
Run UVM error
```

Do not skip directly to regression until individual tests work.

---

# 39. Assertions

Assertion files are:

```text
sva/pcie_assertions.sv
sva/dma_assertions.sv
sva/tag_assertions.sv
```

The initial source has been created, but the assertions still need to be connected to the simulation hierarchy.

This can be done using:

```text
Direct instantiation
```

or:

```text
SystemVerilog bind
```

The final connection approach should be validated during VCS bring-up.

---

# 40. Assertion Compile Example

Conceptually:

```bash
vcs \
    -full64 \
    -sverilog \
    -assert svaext \
    -f sim/filelists/rtl.f \
    sva/pcie_assertions.sv \
    sva/dma_assertions.sv \
    sva/tag_assertions.sv \
    <testbench>
```

Exact options may depend on the installed VCS version.

---

# 41. Coverage Enablement

Do not enable coverage during initial compile-debug unless necessary.

Once the tests are stable, compile with:

```bash
-cm line+cond+fsm+tgl+branch+assert
```

Example:

```bash
vcs \
    -full64 \
    -sverilog \
    -ntb_opts uvm \
    -debug_access+all \
    -cm line+cond+fsm+tgl+branch+assert \
    -f sim/filelists/uvm.f \
    -top tb_top \
    -o simv
```

---

# 42. Run With Coverage

Example:

```bash
./simv \
    +UVM_TESTNAME=pcie_dma_test \
    +ntb_random_seed=25 \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir coverage/pcie_dma_test_seed_25.vdb
```

---

# 43. Coverage Directory

Planned structure:

```text
coverage/
├── pcie_smoke_test_seed_1.vdb
├── pcie_dma_test_seed_1.vdb
├── pcie_dma_test_seed_2.vdb
├── pcie_error_test_seed_1.vdb
├── merged.vdb
└── reports/
```

---

# 44. Merge Coverage

Once multiple `.vdb` databases exist, use Synopsys URG.

Conceptual example:

```bash
urg \
    -dir coverage/pcie_smoke_test_seed_1.vdb \
         coverage/pcie_dma_test_seed_1.vdb \
         coverage/pcie_error_test_seed_1.vdb \
    -dbname coverage/merged.vdb
```

The exact command syntax should be verified with the installed tool version.

---

# 45. Coverage Report Generation

A typical URG report command may resemble:

```bash
urg \
    -dir coverage/merged.vdb \
    -report coverage/reports
```

After generation, inspect:

```text
Line Coverage
Branch Coverage
Condition Coverage
FSM Coverage
Toggle Coverage
Assertion Coverage
```

Functional coverage results should also be reviewed from the UVM covergroups.

---

# 46. Tcl Coverage Helper

Current helper:

```text
scripts/tcl/run_coverage.tcl
```

It prepares coverage directories and documents intended coverage types.

This script can be expanded once the exact Synopsys environment is known.

---

# 47. Clean Simulation Files

Use:

```bash
make -f sim/vcs/Makefile clean
```

This removes generated files such as:

```text
sim/vcs/build/
csrc/
simv
simv.daidir/
ucli.key
DVEfiles/
vc_hdrs.h
```

Logs and coverage may be preserved separately.

---

# 48. Manual Clean

If necessary:

```bash
rm -rf sim/vcs/build
rm -rf csrc
rm -rf simv
rm -rf simv.daidir
rm -rf ucli.key
rm -rf DVEfiles
rm -rf vc_hdrs.h
```

Be careful not to delete source files.

---

# 49. Common UVM Debug Commands

Run with high verbosity:

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 1
```

Then temporarily modify:

```text
+UVM_VERBOSITY=UVM_HIGH
```

Useful UVM debug areas:

```text
Build hierarchy
Config DB
Sequence start
Driver transaction
Monitor transaction
Scoreboard transaction
```

---

# 50. Config DB Debug

If the UVM environment reports:

```text
NO_VIF
```

check:

```text
uvm_config_db::set
```

in:

```text
tb/uvm/tb_top.sv
```

and:

```text
uvm_config_db::get
```

inside the relevant UVM component.

---

# 51. UVM Hierarchy

Expected hierarchy conceptually:

```text
uvm_test_top
|
+-- env
    |
    +-- pcie_ag
    |   |
    |   +-- sequencer
    |   +-- driver
    |   +-- monitor
    |
    +-- dma_ag
    |   |
    |   +-- monitor
    |
    +-- scoreboard
    |
    +-- coverage
```

---

# 52. UVM Transaction Debug

If the scoreboard sees incorrect packets, inspect:

```text
pcie_seq_item.pack_tlp()
pcie_seq_item.decode_tlp()
```

These functions must remain consistent with:

```text
tlp_rx_parser.sv
tlp_tx_formatter.sv
```

---

# 53. Random Seed Reproduction

If regression reports:

```text
FAIL seed 62381
```

re-run:

```bash
./sim/vcs/run_uvm.sh pcie_dma_test 62381
```

Never debug a random failure without preserving the failing seed.

---

# 54. Regression Strategy

Recommended progression:

```text
1 seed
    |
    v
5 seeds
    |
    v
20 seeds
    |
    v
100 seeds
```

Only increase seed count once the test is stable at the previous level.

---

# 55. Suggested Daily Development Flow

During active project development:

```text
Edit RTL
   |
   v
Run affected unit test
   |
   v
Run related integration test
   |
   v
Run UVM smoke
   |
   v
Commit/stash externally if desired
```

Git is currently optional for this project.

---

# 56. Simulation Result Tracking

Maintain a table in project documentation:

| Test | Compile | Run | Result | Notes |
|---|---|---|---|---|
| `tlp_rx_parser_tb` | Pending | Pending | Pending | |
| `bar_decoder_tb` | Pending | Pending | Pending | |
| `endpoint_memory_tb` | Pending | Pending | Pending | |
| `request_handler_tb` | Pending | Pending | Pending | |
| `completion_engine_tb` | Pending | Pending | Pending | |
| `tlp_tx_formatter_tb` | Pending | Pending | Pending | |
| `outstanding_req_table_tb` | Pending | Pending | Pending | |
| `sync_fifo_tb` | Pending | Pending | Pending | |
| `timeout_counter_tb` | Pending | Pending | Pending | |
| `dma_regs_tb` | Pending | Pending | Pending | |
| `dma_read_engine_tb` | Pending | Pending | Pending | |
| `dma_write_engine_tb` | Pending | Pending | Pending | |
| `dma_controller_tb` | Pending | Pending | Pending | |
| `pcie_endpoint_smoke_tb` | Pending | Pending | Pending | |
| `pcie_dma_integration_tb` | Pending | Pending | Pending | |
| `pcie_error_integration_tb` | Pending | Pending | Pending | |
| `pcie_smoke_test` | Pending | Pending | Pending | |
| `pcie_dma_test` | Pending | Pending | Pending | |
| `pcie_error_test` | Pending | Pending | Pending | |

---

# 57. Important Rule

Do not mark a test as:

```text
PASS
```

unless it has actually executed successfully in VCS.

Do not report coverage percentages until VCS/URG produces real coverage results.

---

# 58. First Commands to Run Once Access Is Restored

Use this sequence:

```bash
cd /home/<user>/Projects/PCIe/pcie_endpoint_dma
```

Then:

```bash
which vcs
```

Then:

```bash
vcs -ID
```

Then:

```bash
vlogan -full64 -sverilog rtl/common/pcie_tlp_pkg.sv
```

If successful:

```bash
./sim/vcs/run_unit.sh tlp_rx_parser_tb
```

Then continue test-by-test.

---

# 59. Final Verification Flow

```text
VCS Available
     |
     v
Compile Package
     |
     v
Compile RTL
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
UVM Compile
     |
     v
UVM Tests
     |
     v
Multi-Seed Regression
     |
     v
Coverage
     |
     v
Coverage Closure
     |
     v
Final Project Results
```

---

# 60. Summary

The simulation environment is designed so that every stage can be executed independently.

Primary commands are:

```bash
./sim/vcs/run_unit.sh <unit_test>
```

```bash
./sim/vcs/run_integration.sh <smoke|dma|error>
```

```bash
./sim/vcs/run_uvm.sh <uvm_test> <seed>
```

```bash
python3 scripts/python/run_regression.py --all --seeds 10
```

```bash
python3 scripts/python/parse_results.py
```

The immediate goal once Synopsys VCS access becomes available is not to run the entire regression at once.

The first goal is:

```text
Compile one block
Run one test
Fix it completely
Move to the next
```

This provides a controlled path from initial RTL bring-up to full UVM regression and coverage closure.