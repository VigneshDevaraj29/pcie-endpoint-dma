`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  import pcie_tlp_pkg::*;
  import pcie_uvm_pkg::*;


  localparam int OUTSTANDING_ENTRIES = 16;


  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk;
  logic rst_n;


  initial begin

    clk = 1'b0;

    forever #5 clk = ~clk;

  end


  initial begin

    rst_n = 1'b0;

    repeat (5)
      @(posedge clk);

    rst_n = 1'b1;

  end


  // ============================================================
  // Interfaces
  // ============================================================

  pcie_if pcie_vif (
    .clk   (clk),
    .rst_n (rst_n)
  );


  dma_status_if #(
    .OUTSTANDING_ENTRIES(
      OUTSTANDING_ENTRIES
    )
  ) dma_vif (
    .clk   (clk),
    .rst_n (rst_n)
  );


  // ============================================================
  // DUT
  // ============================================================

  pcie_endpoint_dma_top #(
    .OUTSTANDING_ENTRIES(
      OUTSTANDING_ENTRIES
    ),

    // Shorter timeout for simulation
    .COMPLETION_TIMEOUT_CYCLES(
      32
    )
  ) dut (
    .clk                     (clk),
    .rst_n                   (rst_n),

    .rx_valid_i              (pcie_vif.rx_valid),
    .rx_ready_o              (pcie_vif.rx_ready),

    .rx_dw0_i                (pcie_vif.rx_dw0),
    .rx_dw1_i                (pcie_vif.rx_dw1),
    .rx_dw2_i                (pcie_vif.rx_dw2),

    .rx_payload_valid_i      (
      pcie_vif.rx_payload_valid
    ),

    .rx_payload_data_i       (
      pcie_vif.rx_payload_data
    ),

    .tx_valid_o              (pcie_vif.tx_valid),
    .tx_ready_i              (pcie_vif.tx_ready),

    .tx_dw0_o                (pcie_vif.tx_dw0),
    .tx_dw1_o                (pcie_vif.tx_dw1),
    .tx_dw2_o                (pcie_vif.tx_dw2),

    .tx_payload_valid_o      (
      pcie_vif.tx_payload_valid
    ),

    .tx_payload_data_o       (
      pcie_vif.tx_payload_data
    ),

    .dma_busy_o              (dma_vif.dma_busy),

    .dma_done_o              (dma_vif.dma_done),

    .dma_error_o             (dma_vif.dma_error),

    .unexpected_completion_o (
      dma_vif.unexpected_completion
    ),

    .outstanding_count_o     (
      dma_vif.outstanding_count
    ),

    .tx_formatter_error_o    (
      dma_vif.tx_formatter_error
    )
  );


  // ============================================================
  // UVM Configuration
  // ============================================================

  initial begin

    uvm_config_db#(
      virtual pcie_if
    )::set(
      null,
      "uvm_test_top.env.pcie_ag.*",
      "vif",
      pcie_vif
    );


    uvm_config_db#(
      virtual dma_status_if
    )::set(
      null,
      "uvm_test_top.env.dma_ag.*",
      "vif",
      dma_vif
    );


    run_test();

  end


endmodule