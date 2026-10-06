# PCIe Endpoint Transaction Layer with DMA Engine

## Architecture Document

---

# 1. Purpose

This document describes the architecture of the simplified PCI Express Endpoint Transaction Layer with an integrated DMA engine.

The design is intended to demonstrate practical Digital Design and Design Verification concepts using SystemVerilog.

The implementation focuses on the PCIe Transaction Layer and does not model the complete PCIe protocol stack.

The main architectural areas are:

- PCIe TLP reception
- TLP parsing
- BAR address decoding
- Local register access
- Endpoint memory access
- Completion generation
- DMA configuration
- DMA read operation
- DMA write operation
- Outstanding request tracking
- Completion matching
- Timeout handling
- TX arbitration
- TLP formatting

---

# 2. High-Level Architecture

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
               +-----------+-----------+
               |                       |
               v                       v
       +---------------+        +---------------+
       | DMA Registers |        | Endpoint      |
       |               |        | Memory        |
       +-------+-------+        +-------+-------+
               |                        |
               +------------+-----------+
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

The DMA subsystem also generates PCIe traffic.

```text
                     DMA Registers
                          |
                          v
                   +---------------+
                   | DMA Controller|
                   +-------+-------+
                           |
             +-------------+-------------+
             |                           |
             v                           v
      +--------------+            +--------------+
      | DMA Read     |            | DMA Write    |
      | Engine       |            | Engine       |
      +------+-------+            +------+-------+
             |                           |
             |                           |
             v                           v
   Outstanding Request Table       Posted MemWr TLP
             |
             v
         MemRd TLP
             |
             v
       Wait for CplD
```

---

# 3. Project Scope

The architecture currently supports a simplified PCIe Transaction Layer model.

Supported TLP classes:

```text
Memory Read
Memory Write
Completion
Completion with Data
```

The current implementation assumes:

```text
32-bit PCIe addresses
3DW headers
32-bit payload datapath
One DWORD per DMA operation
Single BAR
Simplified handshake interfaces
```

The following are intentionally outside the current scope:

```text
PCIe Physical Layer
PCIe Data Link Layer
SerDes
LTSSM
PIPE
DLLP
LCRC
ACK / NAK
Replay Buffer
Full Configuration Space
MSI / MSI-X
Credit Flow Control
64-bit addressing
4DW headers
```

---

# 4. Source File Architecture

```text
rtl/
├── common/
│   └── pcie_tlp_pkg.sv
│
├── pcie/
│   ├── tlp_rx_parser.sv
│   ├── tlp_tx_formatter.sv
│   ├── bar_decoder.sv
│   ├── request_handler.sv
│   ├── completion_engine.sv
│   └── outstanding_req_table.sv
│
├── dma/
│   ├── dma_regs.sv
│   ├── dma_controller.sv
│   ├── dma_read_engine.sv
│   └── dma_write_engine.sv
│
├── common_blocks/
│   ├── sync_fifo.sv
│   └── timeout_counter.sv
│
├── memory/
│   └── endpoint_memory.sv
│
└── pcie_endpoint_dma_top.sv
```

---

# 5. PCIe TLP Package

File:

```text
rtl/common/pcie_tlp_pkg.sv
```

This package defines the shared PCIe data structures used throughout the design.

The package contains:

```text
tlp_fmt_e
tlp_type_e
tlp_kind_e
cpl_status_e
tlp_header_t
```

It also contains helper functions:

```text
get_tlp_kind()
is_posted()
needs_completion()
```

---

# 6. TLP Header Representation

The internal TLP header is represented using a packed SystemVerilog structure.

Conceptually:

```text
tlp_header_t
|
+-- fmt
+-- tlp_type
+-- length_dw
|
+-- requester_id
+-- tag
+-- first_be
+-- last_be
+-- address
|
+-- completer_id
+-- cpl_status
+-- byte_count
+-- lower_address
```

Not all fields are used for every packet type.

Memory Request fields include:

```text
Fmt
Type
Length
Requester ID
Tag
First DW Byte Enable
Last DW Byte Enable
Address
```

Completion fields include:

```text
Fmt
Type
Length
Completer ID
Completion Status
Byte Count
Requester ID
Tag
Lower Address
```

---

# 7. Supported TLP Types

## 7.1 Memory Read

Memory Read is modeled as:

```text
Fmt  = 3DW No Data
Type = Memory
```

Conceptually:

```text
MemRd
 |
 +-- Requester ID
 +-- Tag
 +-- Byte Enables
 +-- Address
 +-- Length
```

Memory Read is a Non-Posted transaction.

A Completion is expected.

---

## 7.2 Memory Write

Memory Write is modeled as:

```text
Fmt  = 3DW With Data
Type = Memory
```

Conceptually:

```text
MemWr
 |
 +-- Requester ID
 +-- Byte Enables
 +-- Address
 +-- Length
 +-- Payload
```

Memory Write is a Posted transaction.

No Completion is expected.

---

## 7.3 Completion

Completion without Data is modeled as:

```text
Fmt  = 3DW No Data
Type = Completion
```

Example use:

```text
Unsupported Request
Completer Abort without payload
```

---

## 7.4 Completion With Data

Completion with Data is modeled as:

```text
Fmt  = 3DW With Data
Type = Completion
```

This is used when returning data for a Memory Read.

---

# 8. RX Data Path

The RX path handles incoming PCIe transactions.

```text
PCIe RX Header
      |
      v
TLP RX Parser
      |
      v
Packet Classification
      |
      +--> MemRd
      |
      +--> MemWr
      |
      +--> Cpl
      |
      +--> CplD
      |
      +--> Unsupported
```

The decoded information is then routed depending on packet type.

---

# 9. TLP RX Parser

File:

```text
rtl/pcie/tlp_rx_parser.sv
```

Input:

```text
tlp_valid_i
tlp_dw0_i
tlp_dw1_i
tlp_dw2_i
```

Output:

```text
parsed_valid_o
supported_o
header_o
kind_o
```

The parser converts raw TLP DWORDs into the internal `tlp_header_t`.

For Memory Requests:

```text
DW0
 |
 +-- Fmt
 +-- Type
 +-- Length

DW1
 |
 +-- Requester ID
 +-- Tag
 +-- Last BE
 +-- First BE

DW2
 |
 +-- Address
```

For Completions:

```text
DW0
 |
 +-- Fmt
 +-- Type
 +-- Length

DW1
 |
 +-- Completer ID
 +-- Completion Status
 +-- Byte Count

DW2
 |
 +-- Requester ID
 +-- Tag
 +-- Lower Address
```

---

# 10. BAR Decoder

File:

```text
rtl/pcie/bar_decoder.sv
```

The design currently implements one BAR.

Default BAR0:

```text
BAR0 Base = 0x8000_0000
BAR0 Size = 4096 bytes
```

Address translation:

```text
PCIe Address
     |
     v
Compare against BAR0 range
     |
     +--> Outside range -> BAR miss
     |
     v
BAR hit
     |
     v
local_addr = PCIe Address - BAR0 Base
```

Example:

```text
PCIe Address = 0x8000_0120
BAR0 Base    = 0x8000_0000

Local Offset = 0x0000_0120
```

---

# 11. BAR0 Local Address Map

The top-level module divides BAR0 into local regions.

Current mapping:

```text
BAR0 + 0x000 - 0x01F
    DMA register space

BAR0 + 0x100 onward
    Endpoint memory
```

Conceptually:

```text
BAR0
0x8000_0000
    |
    +-- 0x000 : DMA SRC_ADDR
    |
    +-- 0x004 : DMA DST_ADDR
    |
    +-- 0x008 : DMA LENGTH
    |
    +-- 0x00C : DMA CONTROL
    |
    +-- 0x010 : DMA STATUS
    |
    +-- ...
    |
    +-- 0x100 : Endpoint Memory Base
```

---

# 12. Request Handler

File:

```text
rtl/pcie/request_handler.sv
```

The request handler processes incoming Memory Read and Memory Write requests.

---

## 12.1 Memory Write Flow

```text
Incoming MemWr
     |
     v
BAR Hit?
     |
     +-- No --> Discard / error handling according to model
     |
     v
Local Request
     |
     v
DMA Register or Endpoint Memory
     |
     v
Write Response
     |
     v
Return to IDLE
```

Because Memory Write is Posted:

```text
No PCIe completion is generated.
```

---

## 12.2 Memory Read Flow

```text
Incoming MemRd
     |
     v
BAR Hit?
     |
     +-- No --> Generate UR Completion
     |
     v
Local Read
     |
     v
Wait for Read Response
     |
     v
Generate CplD
```

Request metadata is saved while waiting for the local memory response:

```text
Requester ID
Tag
Lower Address
```

This information is used to build the Completion.

---

# 13. Endpoint Memory

File:

```text
rtl/memory/endpoint_memory.sv
```

The endpoint contains a simple local memory.

Current behavior:

```text
32-bit word storage
Byte-enable writes
Synchronous response
Address checking
Alignment checking
```

Memory interface:

```text
req_valid
req_write
local_addr
write_data
byte_en
```

Response:

```text
req_ready
rsp_valid
read_data
addr_error
```

---

# 14. DMA Registers

File:

```text
rtl/dma/dma_regs.sv
```

Register map:

| Offset | Register | Description |
|---|---|---|
| `0x00` | SRC_ADDR | DMA source address |
| `0x04` | DST_ADDR | DMA destination address |
| `0x08` | LENGTH | Transfer length |
| `0x0C` | CONTROL | Start and status clear |
| `0x10` | STATUS | Busy, Done and Error |

---

## 14.1 CONTROL Register

Current definition:

```text
bit 0 = START
bit 1 = CLEAR STATUS
```

---

## 14.2 STATUS Register

Current definition:

```text
bit 0 = BUSY
bit 1 = DONE
bit 2 = ERROR
```

---

# 15. DMA Controller

File:

```text
rtl/dma/dma_controller.sv
```

The DMA controller coordinates the read and write engines.

State machine:

```text
            +------+
            | IDLE |
            +--+---+
               |
               v
        +--------------+
        | ISSUE_READ   |
        +------+-------+
               |
               v
        +--------------+
        | WAIT_READ    |
        +------+-------+
               |
               v
        +--------------+
        | ISSUE_WRITE  |
        +------+-------+
               |
               v
        +--------------+
        | WAIT_WRITE   |
        +------+-------+
               |
      +--------+--------+
      |                 |
 More Data           Last DW
      |                 |
      v                 v
 ISSUE_READ          DONE
```

Error paths transition to:

```text
ST_ERROR
```

---

# 16. DMA Read Engine

File:

```text
rtl/dma/dma_read_engine.sv
```

The DMA read engine generates Non-Posted PCIe Memory Read requests.

Flow:

```text
DMA Read Command
      |
      v
Allocate Tag
      |
      v
Outstanding Request Entry
      |
      v
Generate MemRd
      |
      v
Start Timeout
      |
      v
WAIT_CPL
      |
      +------------------------+
      |                        |
      v                        v
CplD received               Timeout
      |                        |
      v                        v
Check Tag                  DMA Error
      |
      v
Check Status
      |
      v
Capture Payload
      |
      v
Read Done
```

---

# 17. Tag Allocation

The DMA read engine maintains a next-tag counter.

Conceptually:

```text
next_tag = 0x00
     |
Allocate
     |
     v
active_tag = 0x00
next_tag   = 0x01
```

If a duplicate tag is detected:

```text
Try next tag
```

Tags are not allowed to be reused while still outstanding.

---

# 18. Outstanding Request Table

File:

```text
rtl/pcie/outstanding_req_table.sv
```

The table tracks Memory Read requests waiting for Completion.

Each entry contains:

```text
State
Tag
Address
Length
```

State values:

```text
REQ_FREE
REQ_WAIT_CPL
```

Example table:

```text
Entry   State       Tag    Address       Length
--------------------------------------------------
0       WAIT_CPL    01     10000000      1
1       WAIT_CPL    07     20000000      1
2       FREE        00     00000000      0
3       WAIT_CPL    A2     30000000      1
```

---

# 19. Completion Lookup

A received Completion carries a Tag.

Example:

```text
Incoming CplD
Tag = 0x07
```

The table searches for:

```text
entry.tag == 0x07
```

If found:

```text
cpl_match = 1
```

The matching entry is then released.

If not found:

```text
cpl_unexpected = 1
```

---

# 20. Out-of-Order Completion Capability

The table lookup is based on Tag rather than issue order.

Example requests:

```text
Issue:
Tag 01
Tag 02
Tag 03
```

Possible Completion order:

```text
Receive:
Tag 03
Tag 01
Tag 02
```

Each Completion can still be matched to the appropriate outstanding request.

The first DMA implementation issues one read at a time, but the table architecture is designed to support multiple outstanding tags in future extensions.

---

# 21. Outstanding Request Cancellation

A request can be removed without receiving a Completion.

This is used for:

```text
Completion timeout
DMA abort
Error recovery
```

Flow:

```text
Timeout
   |
   v
cancel_valid
cancel_tag
   |
   v
Outstanding Table
   |
   v
Find Tag
   |
   v
Release Entry
```

---

# 22. Completion Timeout

File:

```text
rtl/common_blocks/timeout_counter.sv
```

The timer begins after a Memory Read TLP is transmitted.

```text
MemRd accepted
     |
     v
start timeout
     |
     v
Counter increments
     |
     +----------------------------+
     |                            |
CplD received                Count reaches limit
     |                            |
     v                            v
clear timer                   timeout
                                  |
                                  v
                              DMA error
```

The timeout value is parameterized.

---

# 23. DMA Write Engine

File:

```text
rtl/dma/dma_write_engine.sv
```

The write engine receives:

```text
Destination Address
Data
Byte Enable
```

It creates:

```text
3DW Memory Write TLP
```

Flow:

```text
DMA Write Command
      |
      v
Validate Alignment
      |
      v
Build MemWr Header
      |
      v
Attach Payload
      |
      v
Transmit
      |
      v
Write Done
```

No Completion is required.

---

# 24. Completion Engine

File:

```text
rtl/pcie/completion_engine.sv
```

The Completion engine receives completion requests from the endpoint request handler.

Input information:

```text
Completion Status
Data Valid
Data
Requester ID
Tag
Lower Address
```

Output:

```text
tlp_header_t
Payload Valid
Payload Data
```

---

## 24.1 Successful Read Completion

```text
Status     = SC
Fmt        = 3DW_DATA
Type       = CPL
Length     = 1 DW
Byte Count = 4
Payload    = Read Data
```

---

## 24.2 Unsupported Request

```text
Status     = UR
Fmt        = 3DW_NO_DATA
Type       = CPL
Payload    = None
```

---

# 25. TX Arbitration

The design has multiple PCIe TX producers:

```text
Completion Engine
DMA Read Engine
DMA Write Engine
```

Priority is currently:

```text
1. Endpoint Completion
2. DMA Memory Read
3. DMA Memory Write
```

Architecture:

```text
Completion TX --------+
                      |
DMA Read TX ----------+--> TX Arbiter --> TLP Formatter
                      |
DMA Write TX ---------+
```

Only the selected producer receives the ready signal from the formatter.

---

# 26. TLP TX Formatter

File:

```text
rtl/pcie/tlp_tx_formatter.sv
```

The formatter converts the internal representation into raw TLP header DWORDs.

```text
tlp_header_t
     |
     v
+------------------+
| TLP TX Formatter |
+---------+--------+
          |
          +--> DW0
          |
          +--> DW1
          |
          +--> DW2
          |
          +--> Payload
```

---

# 27. TX Memory Read Format

```text
DW0
+--------------------------------+
| Fmt | Type | ... | Length      |
+--------------------------------+

DW1
+--------------------------------+
| Requester ID | Tag | BE        |
+--------------------------------+

DW2
+--------------------------------+
| Address                        |
+--------------------------------+
```

No payload is sent.

---

# 28. TX Memory Write Format

```text
DW0
+--------------------------------+
| Fmt | Type | ... | Length      |
+--------------------------------+

DW1
+--------------------------------+
| Requester ID | Tag | BE        |
+--------------------------------+

DW2
+--------------------------------+
| Address                        |
+--------------------------------+

Payload
+--------------------------------+
| Data                           |
+--------------------------------+
```

---

# 29. TX Completion Format

```text
DW0
+--------------------------------+
| Fmt | Type | ... | Length      |
+--------------------------------+

DW1
+--------------------------------+
| Completer ID | Status | Count  |
+--------------------------------+

DW2
+--------------------------------+
| Requester ID | Tag | Lower Addr|
+--------------------------------+
```

A CplD additionally carries payload data.

---

# 30. Top-Level Module

File:

```text
rtl/pcie_endpoint_dma_top.sv
```

The top-level module connects all RTL blocks.

Major connections:

```text
RX Parser
   |
BAR Decoder
   |
Request Handler
   |
   +--> DMA Registers
   |
   +--> Endpoint Memory
   |
Completion Engine
   |
TX Arbitration
   |
TX Formatter
```

The DMA path connects:

```text
DMA Registers
     |
DMA Controller
     |
     +--> DMA Read Engine
     |        |
     |        +--> Outstanding Request Table
     |
     +--> DMA Write Engine
```

---

# 31. Top-Level RX Interface

```text
rx_valid_i
rx_ready_o

rx_dw0_i
rx_dw1_i
rx_dw2_i

rx_payload_valid_i
rx_payload_data_i
```

The interface represents a simplified Transaction Layer packet input.

---

# 32. Top-Level TX Interface

```text
tx_valid_o
tx_ready_i

tx_dw0_o
tx_dw1_o
tx_dw2_o

tx_payload_valid_o
tx_payload_data_o
```

---

# 33. Top-Level Status Signals

```text
dma_busy_o
dma_done_o
dma_error_o

unexpected_completion_o

outstanding_count_o

tx_formatter_error_o
```

These signals are also observed by the UVM passive DMA status agent.

---

# 34. Common FIFO

File:

```text
rtl/common_blocks/sync_fifo.sv
```

A synchronous FIFO utility block is included for future queueing extensions.

Features:

```text
Parameterized width
Parameterized depth
Write pointer
Read pointer
Occupancy counter
Full indication
Empty indication
```

The current top-level datapath does not require extensive FIFO buffering, but the block is included for future expansion.

---

# 35. Current DMA Transfer Granularity

The first DMA implementation transfers:

```text
1 DWORD = 4 bytes
```

at a time.

Example 16-byte transfer:

```text
Read 0x1000
Write 0x2000

Read 0x1004
Write 0x2004

Read 0x1008
Write 0x2008

Read 0x100C
Write 0x200C

DONE
```

This architecture simplifies the initial implementation while preserving the control flow of a real DMA engine.

---

# 36. DMA Transfer Example

Configuration:

```text
SRC_ADDR = 0x1000_0000
DST_ADDR = 0x2000_0000
LENGTH   = 8 bytes
```

Step 1:

```text
Generate:

MemRd
Address = 0x1000_0000
Tag     = 0x00
```

Step 2:

```text
Receive:

CplD
Tag  = 0x00
Data = 0xAAAA_BBBB
```

Step 3:

```text
Generate:

MemWr
Address = 0x2000_0000
Data    = 0xAAAA_BBBB
```

Step 4:

```text
Advance:

SRC = 0x1000_0004
DST = 0x2000_0004
Remaining = 4
```

Step 5:

```text
Generate:

MemRd
Address = 0x1000_0004
Tag     = 0x01
```

Step 6:

```text
Receive:

CplD
Tag  = 0x01
Data = 0xCCCC_DDDD
```

Step 7:

```text
Generate:

MemWr
Address = 0x2000_0004
Data    = 0xCCCC_DDDD
```

Step 8:

```text
Remaining = 0

DMA DONE
```

---

# 37. Error Architecture

Several errors can propagate through the design.

---

## 37.1 Invalid BAR Read

```text
MemRd
Address outside BAR0
       |
       v
BAR Miss
       |
       v
Request Handler
       |
       v
Generate UR Completion
```

---

## 37.2 Local Memory Error

```text
MemRd
   |
Local Memory
   |
Address Error
   |
   v
Completion Status = CA
```

---

## 37.3 Unexpected Completion

```text
Incoming CplD
Tag = X
   |
Outstanding Table Lookup
   |
No Match
   |
   v
unexpected_completion = 1
```

---

## 37.4 Completion Timeout

```text
DMA MemRd
   |
Wait for CplD
   |
No Completion
   |
Timeout Counter Expires
   |
Cancel Outstanding Entry
   |
DMA ERROR
```

---

## 37.5 Invalid DMA Configuration

Current DMA start checks include:

```text
Length != 0
Length DWORD aligned
Source DWORD aligned
Destination DWORD aligned
```

Invalid configuration causes:

```text
DMA ERROR
```

---

# 38. Reset Architecture

All major sequential blocks use:

```systemverilog
always_ff @(posedge clk or negedge rst_n)
```

The project uses active-low asynchronous reset.

On reset:

```text
FSMs return to IDLE
Outstanding table entries become FREE
DMA status is cleared
Counters are reset
Output valid signals are cleared
```

---

# 39. Handshake Model

The project primarily uses ready/valid handshakes.

Generic transfer:

```text
valid = 1
ready = 1
   |
   v
Transfer occurs
```

If:

```text
valid = 1
ready = 0
```

the producer must retain the transaction until accepted.

This behavior is checked by SystemVerilog Assertions on selected interfaces.

---

# 40. Design Parameterization

Several modules are parameterized.

Examples:

```text
ADDR_WIDTH
DATA_WIDTH
TAG_WIDTH
BAR0_BASE_ADDR
BAR0_SIZE_BYTES
MEM_SIZE_BYTES
NUM_ENTRIES
TIMEOUT_CYCLES
REQUESTER_ID
COMPLETER_ID
```

This allows the design to be extended without rewriting the entire RTL.

---

# 41. Current Architectural Limitations

The current architecture has several intentional simplifications.

These include:

- One payload DWORD per transaction
- Single active DMA read at a time
- No PCIe Data Link Layer
- No PCIe Physical Layer
- No credit-based flow control
- No packet retry
- No split Completion handling
- No multiple Completion packets for one request
- No 4DW headers
- No 64-bit PCIe addresses
- No PCIe Configuration Request TLP handling
- No Message TLP handling
- No AtomicOp support
- No MSI/MSI-X
- No scatter-gather DMA
- No descriptor ring

These simplifications keep the project focused on core RTL and DV concepts.

---

# 42. Future Architectural Extensions

Future development can extend the architecture in several directions.

---

## 42.1 Multiple Outstanding DMA Reads

Instead of:

```text
Read
Wait
Write
Read
Wait
Write
```

future architecture can support:

```text
Read Tag 01
Read Tag 02
Read Tag 03
Read Tag 04

       |
       v

CplD Tag 03
CplD Tag 01
CplD Tag 04
CplD Tag 02
```

This would make deeper use of the outstanding request table.

---

## 42.2 Descriptor-Based DMA

A future DMA descriptor could contain:

```text
Source Address
Destination Address
Length
Control
Next Descriptor Pointer
```

This would allow:

```text
Descriptor Fetch
      |
      v
Transfer
      |
      v
Next Descriptor
      |
      v
Transfer
```

---

## 42.3 Scatter-Gather DMA

Future support could transfer multiple non-contiguous buffers.

```text
Descriptor 0
SRC A -> DST A

Descriptor 1
SRC B -> DST B

Descriptor 2
SRC C -> DST C
```

---

## 42.4 AXI Integration

The local endpoint side could be replaced with an AXI4 interface.

Possible architecture:

```text
PCIe
 |
 v
PCIe Transaction Layer
 |
 v
PCIe-to-AXI Bridge
 |
 v
AXI4 Interconnect
 |
 +--> Registers
 |
 +--> Memory
 |
 +--> Peripheral
```

---

## 42.5 64-Bit PCIe Addressing

Future support could add:

```text
4DW Memory Read
4DW Memory Write
64-bit address field
```

---

## 42.6 PCIe Credit Flow Control

A future model may include:

```text
Posted Header Credits
Posted Data Credits

Non-Posted Header Credits
Non-Posted Data Credits

Completion Header Credits
Completion Data Credits
```

---

## 42.7 LTSSM

A separate future project block could implement a simplified PCIe Link Training and Status State Machine.

Example states:

```text
Detect
Polling
Configuration
L0
Recovery
```

This would extend the project beyond the Transaction Layer.

---

# 43. Architectural Verification Mapping

Each major block has a corresponding verification target.

| RTL Block | Verification |
|---|---|
| `pcie_tlp_pkg.sv` | Used across all TB components |
| `tlp_rx_parser.sv` | `tlp_rx_parser_tb.sv` |
| `bar_decoder.sv` | `bar_decoder_tb.sv` |
| `endpoint_memory.sv` | `endpoint_memory_tb.sv` |
| `request_handler.sv` | `request_handler_tb.sv` |
| `completion_engine.sv` | `completion_engine_tb.sv` |
| `tlp_tx_formatter.sv` | `tlp_tx_formatter_tb.sv` |
| `outstanding_req_table.sv` | `outstanding_req_table_tb.sv` |
| `sync_fifo.sv` | `sync_fifo_tb.sv` |
| `timeout_counter.sv` | `timeout_counter_tb.sv` |
| `dma_regs.sv` | `dma_regs_tb.sv` |
| `dma_read_engine.sv` | `dma_read_engine_tb.sv` |
| `dma_write_engine.sv` | `dma_write_engine_tb.sv` |
| `dma_controller.sv` | `dma_controller_tb.sv` |
| `pcie_endpoint_dma_top.sv` | Integration + UVM |

---

# 44. Architectural Summary

The PCIe Endpoint Transaction Layer with DMA Engine is organized around two major operational directions.

## Ingress

```text
PCIe Request
    |
    v
Parser
    |
    v
BAR Decode
    |
    v
Request Handler
    |
    +--> DMA Registers
    |
    +--> Endpoint Memory
    |
    v
Completion Generation
```

## Egress

```text
DMA Controller
    |
    +--> DMA Read Engine
    |
    +--> DMA Write Engine
    |
    v
TX Arbitration
    |
    v
TLP Formatter
    |
    v
PCIe TX
```

Memory Reads use tags and Completion tracking.

Memory Writes are Posted and do not require Completion.

The outstanding request table provides the foundation for supporting multiple simultaneous PCIe read requests and out-of-order Completion behavior in future versions of the project.

This architecture provides a practical platform for demonstrating:

```text
RTL Design
Packet Parsing
Protocol Handling
FSM Design
DMA Control
Outstanding Transaction Tracking
Error Handling
SystemVerilog Verification
UVM
Assertions
Functional Coverage
Regression Automation
```