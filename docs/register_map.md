# PCIe Endpoint Transaction Layer with DMA Engine

## Register Map

---

# 1. Purpose

This document defines the BAR0 address map and DMA control/status registers implemented by the PCIe Endpoint Transaction Layer with DMA Engine.

The endpoint exposes a simplified memory-mapped register interface through PCIe BAR0.

The BAR contains two primary regions:

```text
DMA Control / Status Registers
Endpoint Local Memory
```

---

# 2. BAR0 Configuration

Default BAR0 configuration:

```text
BAR0 Base Address = 0x8000_0000
BAR0 Size         = 0x0000_1000 bytes
                  = 4096 bytes
                  = 4 KB
```

Valid PCIe BAR0 address range:

```text
0x8000_0000
through
0x8000_0FFF
```

Local BAR address calculation:

```text
local_addr = pcie_address - BAR0_BASE
```

Example:

```text
PCIe Address = 0x8000_0104
BAR0 Base    = 0x8000_0000

Local Address = 0x0000_0104
```

---

# 3. BAR0 Address Map

```text
PCIe Address Range         Local Offset       Function
----------------------------------------------------------------
0x8000_0000 - 0x8000_001F 0x000 - 0x01F      DMA Registers

0x8000_0020 - 0x8000_00FF 0x020 - 0x0FF      Reserved

0x8000_0100 - 0x8000_08FF 0x100 - 0x8FF      Endpoint Memory

0x8000_0900 - 0x8000_0FFF 0x900 - 0xFFF      Unused / Reserved
```

Current endpoint memory size:

```text
2048 bytes
```

Therefore:

```text
Memory Base Offset = 0x100

Memory Size        = 0x800 bytes

Last Memory Offset = 0x8FF
```

---

# 4. DMA Register Summary

| Offset | PCIe Address | Register | Access | Reset Value |
|---|---|---|---|---|
| `0x00` | `0x8000_0000` | `SRC_ADDR` | RW | `0x0000_0000` |
| `0x04` | `0x8000_0004` | `DST_ADDR` | RW | `0x0000_0000` |
| `0x08` | `0x8000_0008` | `LENGTH` | RW | `0x0000_0000` |
| `0x0C` | `0x8000_000C` | `CONTROL` | W | `0x0000_0000` |
| `0x10` | `0x8000_0010` | `STATUS` | R | `0x0000_0000` |
| `0x14-0x1F` | `0x8000_0014-0x8000_001F` | Reserved | - | - |

Access notation:

```text
R  = Read Only
W  = Write Only / command
RW = Read and Write
```

---

# 5. SRC_ADDR Register

## Offset

```text
0x00
```

## PCIe Address

```text
0x8000_0000
```

## Access

```text
Read / Write
```

## Reset Value

```text
0x0000_0000
```

## Description

`SRC_ADDR` contains the source PCIe address used by the DMA read engine.

Register layout:

```text
31                                            0
+----------------------------------------------+
|                 SRC_ADDR                     |
+----------------------------------------------+
```

Bits:

| Bits | Field | Access | Description |
|---|---|---|---|
| `[31:0]` | `SRC_ADDR` | RW | DMA source address |

The current DMA implementation requires the source address to be DWORD aligned.

Valid example:

```text
0x1000_0000
```

Invalid examples:

```text
0x1000_0001
0x1000_0002
0x1000_0003
```

Alignment requirement:

```text
SRC_ADDR[1:0] == 2'b00
```

---

# 6. DST_ADDR Register

## Offset

```text
0x04
```

## PCIe Address

```text
0x8000_0004
```

## Access

```text
Read / Write
```

## Reset Value

```text
0x0000_0000
```

## Description

`DST_ADDR` contains the destination PCIe address used by the DMA write engine.

Register layout:

```text
31                                            0
+----------------------------------------------+
|                 DST_ADDR                     |
+----------------------------------------------+
```

Bits:

| Bits | Field | Access | Description |
|---|---|---|---|
| `[31:0]` | `DST_ADDR` | RW | DMA destination address |

The destination must be DWORD aligned.

Requirement:

```text
DST_ADDR[1:0] == 2'b00
```

Example:

```text
DST_ADDR = 0x2000_0000
```

---

# 7. LENGTH Register

## Offset

```text
0x08
```

## PCIe Address

```text
0x8000_0008
```

## Access

```text
Read / Write
```

## Reset Value

```text
0x0000_0000
```

## Description

`LENGTH` specifies the number of bytes to transfer.

Register layout:

```text
31                                            0
+----------------------------------------------+
|                   LENGTH                     |
+----------------------------------------------+
```

Bits:

| Bits | Field | Access | Description |
|---|---|---|---|
| `[31:0]` | `LENGTH` | RW | DMA transfer length in bytes |

Current requirements:

```text
LENGTH > 0
```

and:

```text
LENGTH % 4 == 0
```

Valid examples:

```text
4
8
12
16
32
64
```

Invalid examples:

```text
0
1
2
3
5
6
7
```

The current DMA architecture transfers one DWORD at a time.

Example:

```text
LENGTH = 16 bytes
```

results in:

```text
4 DWORD transfers
```

---

# 8. CONTROL Register

## Offset

```text
0x0C
```

## PCIe Address

```text
0x8000_000C
```

## Access

```text
Write / Command
```

## Reset Value

```text
0x0000_0000
```

Register layout:

```text
31                    2 1       0
+----------------------+---+-----+
|       Reserved       |CLR|START|
+----------------------+---+-----+
```

Bit definitions:

| Bit | Field | Access | Description |
|---:|---|---|---|
| `0` | `START` | W | Start DMA transfer |
| `1` | `CLEAR_STATUS` | W | Clear DONE/ERROR status |
| `31:2` | Reserved | - | Reserved |

---

# 9. CONTROL.START

Writing:

```text
CONTROL[0] = 1
```

generates a DMA start pulse.

Example PCIe Memory Write:

```text
Address = 0x8000_000C
Data    = 0x0000_0001
```

This starts a DMA transaction using the current values of:

```text
SRC_ADDR
DST_ADDR
LENGTH
```

Conceptual flow:

```text
Write SRC_ADDR
     |
Write DST_ADDR
     |
Write LENGTH
     |
Write CONTROL.START
     |
     v
DMA Starts
```

---

# 10. CONTROL.CLEAR_STATUS

Writing:

```text
CONTROL[1] = 1
```

requests clearing of completed/error status.

Example:

```text
Data = 0x0000_0002
```

Conceptually:

```text
Before:

DONE  = 1
ERROR = 0

Write CLEAR_STATUS

After:

DONE  = 0
ERROR = 0
```

---

# 11. STATUS Register

## Offset

```text
0x10
```

## PCIe Address

```text
0x8000_0010
```

## Access

```text
Read Only
```

## Reset Value

```text
0x0000_0000
```

Register layout:

```text
31                    3 2      1      0
+----------------------+-------+------+------+
|       Reserved       | ERROR | DONE | BUSY |
+----------------------+-------+------+------+
```

Bit definitions:

| Bit | Field | Access | Description |
|---:|---|---|---|
| `0` | `BUSY` | R | DMA transfer currently active |
| `1` | `DONE` | R | DMA transfer completed |
| `2` | `ERROR` | R | DMA transfer failed |
| `31:3` | Reserved | R | Returns zero |

---

# 12. STATUS.BUSY

```text
BUSY = 0
```

means:

```text
DMA is idle
```

```text
BUSY = 1
```

means:

```text
DMA operation is in progress
```

Typical sequence:

```text
START
  |
  v
BUSY = 1
  |
DMA Transfer
  |
  v
BUSY = 0
```

---

# 13. STATUS.DONE

```text
DONE = 1
```

indicates that the DMA operation completed successfully.

Example final status:

```text
STATUS = 0x0000_0002
```

Binary:

```text
0000...0010
```

Interpretation:

```text
BUSY  = 0
DONE  = 1
ERROR = 0
```

---

# 14. STATUS.ERROR

```text
ERROR = 1
```

indicates the DMA transaction failed.

Possible reasons include:

```text
Invalid source alignment
Invalid destination alignment
Zero transfer length
Non-DWORD-aligned transfer length
Completion error
Completer Abort
Completion timeout
DMA read failure
DMA write failure
```

Example:

```text
STATUS = 0x0000_0004
```

Interpretation:

```text
BUSY  = 0
DONE  = 0
ERROR = 1
```

---

# 15. STATUS Values

Common values:

| Value | BUSY | DONE | ERROR | Meaning |
|---|---:|---:|---:|---|
| `0x0` | 0 | 0 | 0 | Idle |
| `0x1` | 1 | 0 | 0 | Transfer active |
| `0x2` | 0 | 1 | 0 | Transfer completed |
| `0x4` | 0 | 0 | 1 | Transfer error |

The implementation should not normally expose:

```text
DONE = 1
ERROR = 1
```

simultaneously.

This condition is also targeted by DMA assertions.

---

# 16. Reserved DMA Register Space

Offsets:

```text
0x14 - 0x1F
```

are currently reserved.

Future registers may include:

```text
DMA Descriptor Address
DMA Interrupt Control
DMA Interrupt Status
DMA Error Code
DMA Transfer Counter
DMA Capability Register
```

---

# 17. Endpoint Memory Region

Endpoint memory starts at:

```text
BAR0 + 0x100
```

PCIe address:

```text
0x8000_0100
```

Current memory size:

```text
2048 bytes
```

Valid local memory range:

```text
0x100 - 0x8FF
```

Valid PCIe address range:

```text
0x8000_0100 - 0x8000_08FF
```

---

# 18. Endpoint Memory Address Translation

Example PCIe access:

```text
PCIe Address = 0x8000_0120
```

BAR-local offset:

```text
0x120
```

Memory-relative offset:

```text
0x120 - 0x100
= 0x20
```

Therefore:

```text
Endpoint Memory Offset = 0x20
```

---

# 19. Endpoint Memory Access Size

The current memory interface uses:

```text
DATA_WIDTH = 32 bits
```

Therefore the natural access size is:

```text
4 bytes
```

Addresses should be DWORD aligned:

```text
address[1:0] == 2'b00
```

---

# 20. Endpoint Memory Byte Enables

PCIe Memory Write requests contain:

```text
First DW Byte Enable
```

The memory supports byte-level writes.

For a 32-bit DWORD:

```text
Byte Enable 0001 -> bits [7:0]

Byte Enable 0010 -> bits [15:8]

Byte Enable 0100 -> bits [23:16]

Byte Enable 1000 -> bits [31:24]

Byte Enable 1111 -> all 32 bits
```

Example:

```text
Original Data = 0x11223344
Write Data    = 0xAABBCCDD
Byte Enable   = 0011
```

Result:

```text
0x1122CCDD
```

Only the low two bytes are updated.

---

# 21. PCIe Memory Write to DMA Register

Example: program source address.

PCIe transaction:

```text
TLP     = MemWr
Address = 0x8000_0000
Data    = 0x1000_0000
BE      = 1111
```

Result:

```text
SRC_ADDR = 0x1000_0000
```

---

# 22. PCIe Memory Read from DMA Register

Example:

```text
TLP     = MemRd
Address = 0x8000_0010
Tag     = 0x25
```

The endpoint reads:

```text
STATUS
```

and returns:

```text
CplD
Tag     = 0x25
Payload = STATUS value
```

---

# 23. Complete DMA Programming Example

Goal:

```text
Copy one DWORD
from 0x1000_0000
to   0x2000_0000
```

Step 1 — Program source:

```text
MemWr
Address = 0x8000_0000
Data    = 0x1000_0000
```

Step 2 — Program destination:

```text
MemWr
Address = 0x8000_0004
Data    = 0x2000_0000
```

Step 3 — Program length:

```text
MemWr
Address = 0x8000_0008
Data    = 0x0000_0004
```

Step 4 — Start:

```text
MemWr
Address = 0x8000_000C
Data    = 0x0000_0001
```

Step 5 — DMA issues:

```text
MemRd
Address = 0x1000_0000
```

Step 6 — Host returns:

```text
CplD
Data = 0xCAFE_BABE
```

Step 7 — DMA generates:

```text
MemWr
Address = 0x2000_0000
Data    = 0xCAFE_BABE
```

Step 8 — STATUS becomes:

```text
DONE = 1
```

---

# 24. Multi-DWORD DMA Example

Configuration:

```text
SRC_ADDR = 0x1000_0000
DST_ADDR = 0x2000_0000
LENGTH   = 16
```

Expected operations:

```text
MemRd 0x1000_0000
MemWr 0x2000_0000

MemRd 0x1000_0004
MemWr 0x2000_0004

MemRd 0x1000_0008
MemWr 0x2000_0008

MemRd 0x1000_000C
MemWr 0x2000_000C
```

Final status:

```text
BUSY  = 0
DONE  = 1
ERROR = 0
```

---

# 25. Invalid DMA Configuration Examples

## Zero Length

```text
SRC_ADDR = 0x1000_0000
DST_ADDR = 0x2000_0000
LENGTH   = 0
```

Expected:

```text
ERROR = 1
```

---

## Invalid Length Alignment

```text
LENGTH = 6
```

Expected:

```text
ERROR = 1
```

---

## Unaligned Source

```text
SRC_ADDR = 0x1000_0002
```

Expected:

```text
ERROR = 1
```

---

## Unaligned Destination

```text
DST_ADDR = 0x2000_0001
```

Expected:

```text
ERROR = 1
```

---

# 26. Register Access Through Request Handler

Incoming PCIe request:

```text
PCIe MemWr / MemRd
        |
        v
TLP RX Parser
        |
        v
BAR Decoder
        |
        v
Request Handler
        |
        v
Local Address Decode
        |
        +--> DMA Registers
        |
        +--> Endpoint Memory
```

The register block does not directly process raw PCIe headers.

The PCIe frontend translates transactions into the local register interface.

---

# 27. DMA Register RTL Interface

Conceptual interface:

```text
cfg_valid
cfg_write
cfg_addr
cfg_wdata
cfg_be
```

Response:

```text
cfg_ready
cfg_rdata
```

DMA control outputs:

```text
start_pulse
src_addr
dst_addr
length
```

DMA status inputs:

```text
busy
done
error
```

---

# 28. Reset Behavior

Active-low reset:

```text
rst_n = 0
```

resets the DMA registers.

Expected reset values:

```text
SRC_ADDR = 0x0000_0000

DST_ADDR = 0x0000_0000

LENGTH   = 0x0000_0000

CONTROL  = 0x0000_0000

STATUS   = 0x0000_0000
```

---

# 29. Register Verification

Register behavior is verified primarily by:

```text
tb/sv/unit/dma_regs_tb.sv
```

Integration-level register programming is verified by:

```text
tb/sv/integration/pcie_dma_integration_tb.sv
```

and:

```text
tb/uvm/sequences/pcie_dma_seq.sv
```

---

# 30. Register Coverage Targets

Coverage should eventually exercise:

```text
SRC_ADDR write
SRC_ADDR read

DST_ADDR write
DST_ADDR read

LENGTH write
LENGTH read

START command

CLEAR_STATUS command

STATUS idle read
STATUS busy read
STATUS done read
STATUS error read
```

---

# 31. Access Rules

Current expected behavior:

```text
SRC_ADDR
    Software programmable

DST_ADDR
    Software programmable

LENGTH
    Software programmable

CONTROL
    Command register

STATUS
    Hardware generated
```

Software should configure:

```text
SRC_ADDR
DST_ADDR
LENGTH
```

before asserting:

```text
START
```

---

# 32. Recommended Programming Sequence

```text
1. Verify DMA is not BUSY

2. Write SRC_ADDR

3. Write DST_ADDR

4. Write LENGTH

5. Optionally clear old DONE/ERROR status

6. Write CONTROL.START

7. Poll STATUS.BUSY / DONE / ERROR

8. Stop polling when:
      DONE = 1
   or ERROR = 1
```

---

# 33. Example Software-Like Pseudocode

```text
write32(BAR0 + 0x00, source_address);

write32(BAR0 + 0x04, destination_address);

write32(BAR0 + 0x08, transfer_length);

write32(BAR0 + 0x0C, 0x1);

while (1) {

    status = read32(BAR0 + 0x10);

    if (status & DONE)
        break;

    if (status & ERROR)
        break;
}
```

---

# 34. Future Register Extensions

Future versions may add:

| Offset | Possible Register |
|---|---|
| `0x14` | ERROR_CODE |
| `0x18` | INTERRUPT_STATUS |
| `0x1C` | INTERRUPT_ENABLE |
| `0x20` | DESCRIPTOR_ADDR_LOW |
| `0x24` | DESCRIPTOR_ADDR_HIGH |
| `0x28` | DMA_CAPABILITY |
| `0x2C` | TRANSFER_COUNT |

These are not implemented in the current RTL.

---

# 35. Current Register Map Summary

```text
BAR0 Base = 0x8000_0000
BAR0 Size = 4 KB

+0x000
    SRC_ADDR

+0x004
    DST_ADDR

+0x008
    LENGTH

+0x00C
    CONTROL
        bit 0 START
        bit 1 CLEAR_STATUS

+0x010
    STATUS
        bit 0 BUSY
        bit 1 DONE
        bit 2 ERROR

+0x014 - +0x0FF
    Reserved

+0x100 - +0x8FF
    Endpoint Memory

+0x900 - +0xFFF
    Reserved / Unused
```

---

# 36. Verification Status

Register-map source implementation:

```text
Created
```

Unit-test source:

```text
Created
```

Integration-test source:

```text
Created
```

Actual VCS validation:

```text
Pending
```

No final register behavior should be marked as simulator-validated until the corresponding tests have been run successfully.

---

# 37. Summary

The current BAR0 architecture provides a small software-visible control plane for the DMA engine together with endpoint local memory.

The primary programming model is:

```text
Program Source
      |
Program Destination
      |
Program Length
      |
Start DMA
      |
      v
Monitor Status
```

The register map intentionally remains small so that the project can focus on the major PCIe and DMA concepts:

```text
Memory-Mapped Control
DMA Sequencing
PCIe Memory Reads
PCIe Memory Writes
Completion Handling
Tag Tracking
Error Handling
```