package pcie_uvm_pkg;

  import uvm_pkg::*;
  import pcie_tlp_pkg::*;

  `include "uvm_macros.svh"


  // ============================================================
  // PCIe Agent
  // ============================================================

  `include "agents/pcie_agent/pcie_seq_item.sv"

  `include "agents/pcie_agent/pcie_sequencer.sv"

  `include "agents/pcie_agent/pcie_driver.sv"

  `include "agents/pcie_agent/pcie_monitor.sv"

  `include "agents/pcie_agent/pcie_agent.sv"


  // ============================================================
  // DMA Passive Agent
  // ============================================================

  `include "agents/dma_agent/dma_status_item.sv"

  `include "agents/dma_agent/dma_monitor.sv"

  `include "agents/dma_agent/dma_agent.sv"


  // ============================================================
  // Scoreboard / Coverage
  // ============================================================

  `include "scoreboard/pcie_scoreboard.sv"

  `include "coverage/pcie_coverage.sv"


  // ============================================================
  // Environment
  // ============================================================

  `include "env/pcie_env.sv"


  // ============================================================
  // Sequences
  // ============================================================

  `include "sequences/pcie_base_seq.sv"

  `include "sequences/pcie_smoke_seq.sv"

  `include "sequences/pcie_dma_seq.sv"

  `include "sequences/pcie_error_seq.sv"


  // ============================================================
  // Tests
  // ============================================================

  `include "tests/pcie_base_test.sv"

  `include "tests/pcie_smoke_test.sv"

  `include "tests/pcie_dma_test.sv"

  `include "tests/pcie_error_test.sv"


endpackage