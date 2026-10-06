module pcie_assertions
  import pcie_tlp_pkg::*;
(
  input logic        clk,
  input logic        rst_n,

  // PCIe RX
  input logic        rx_valid_i,
  input logic        rx_ready_i,

  input logic [31:0] rx_dw0_i,
  input logic [31:0] rx_dw1_i,
  input logic [31:0] rx_dw2_i,

  input logic        rx_payload_valid_i,

  // PCIe TX
  input logic        tx_valid_i,
  input logic        tx_ready_i,

  input logic [31:0] tx_dw0_i,
  input logic [31:0] tx_dw1_i,
  input logic [31:0] tx_dw2_i,

  input logic        tx_payload_valid_i
);


  // ============================================================
  // Local Decode
  // ============================================================

  logic rx_mem_write;
  logic rx_mem_read;

  logic tx_mem_write;
  logic tx_mem_read;

  logic tx_cpl;
  logic tx_cpld;


  always_comb begin

    rx_mem_read =
      (rx_dw0_i[31:29] == TLP_FMT_3DW_NO_DATA) &&
      (rx_dw0_i[28:24] == TLP_TYPE_MEM);

    rx_mem_write =
      (rx_dw0_i[31:29] == TLP_FMT_3DW_DATA) &&
      (rx_dw0_i[28:24] == TLP_TYPE_MEM);


    tx_mem_read =
      (tx_dw0_i[31:29] == TLP_FMT_3DW_NO_DATA) &&
      (tx_dw0_i[28:24] == TLP_TYPE_MEM);

    tx_mem_write =
      (tx_dw0_i[31:29] == TLP_FMT_3DW_DATA) &&
      (tx_dw0_i[28:24] == TLP_TYPE_MEM);


    tx_cpl =
      (tx_dw0_i[31:29] == TLP_FMT_3DW_NO_DATA) &&
      (tx_dw0_i[28:24] == TLP_TYPE_CPL);

    tx_cpld =
      (tx_dw0_i[31:29] == TLP_FMT_3DW_DATA) &&
      (tx_dw0_i[28:24] == TLP_TYPE_CPL);

  end


  // ============================================================
  // RX Memory Write Must Carry Payload
  // ============================================================

  property p_rx_mem_write_has_payload;

    @(posedge clk)
    disable iff (!rst_n)

    rx_valid_i &&
    rx_ready_i &&
    rx_mem_write

    |->

    rx_payload_valid_i;

  endproperty


  a_rx_mem_write_has_payload:
    assert property (
      p_rx_mem_write_has_payload
    )
    else
      $error(
        "PCIe ASSERTION: Memory Write accepted without payload"
      );


  // ============================================================
  // RX Memory Read Must Not Carry Payload
  // ============================================================

  property p_rx_mem_read_no_payload;

    @(posedge clk)
    disable iff (!rst_n)

    rx_valid_i &&
    rx_ready_i &&
    rx_mem_read

    |->

    !rx_payload_valid_i;

  endproperty


  a_rx_mem_read_no_payload:
    assert property (
      p_rx_mem_read_no_payload
    )
    else
      $error(
        "PCIe ASSERTION: Memory Read contains unexpected payload"
      );


  // ============================================================
  // TX Memory Write Must Carry Payload
  // ============================================================

  property p_tx_mem_write_has_payload;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i &&
    tx_mem_write

    |->

    tx_payload_valid_i;

  endproperty


  a_tx_mem_write_has_payload:
    assert property (
      p_tx_mem_write_has_payload
    )
    else
      $error(
        "PCIe ASSERTION: TX Memory Write missing payload"
      );


  // ============================================================
  // TX Memory Read Must Not Carry Payload
  // ============================================================

  property p_tx_mem_read_no_payload;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i &&
    tx_mem_read

    |->

    !tx_payload_valid_i;

  endproperty


  a_tx_mem_read_no_payload:
    assert property (
      p_tx_mem_read_no_payload
    )
    else
      $error(
        "PCIe ASSERTION: TX Memory Read has payload"
      );


  // ============================================================
  // Completion With Data Must Carry Payload
  // ============================================================

  property p_cpld_has_payload;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i &&
    tx_cpld

    |->

    tx_payload_valid_i;

  endproperty


  a_cpld_has_payload:
    assert property (
      p_cpld_has_payload
    )
    else
      $error(
        "PCIe ASSERTION: CplD missing payload"
      );


  // ============================================================
  // Completion Without Data Must Not Carry Payload
  // ============================================================

  property p_cpl_no_payload;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i &&
    tx_cpl

    |->

    !tx_payload_valid_i;

  endproperty


  a_cpl_no_payload:
    assert property (
      p_cpl_no_payload
    )
    else
      $error(
        "PCIe ASSERTION: CPL contains unexpected payload"
      );


  // ============================================================
  // TX Must Stay Stable During Backpressure
  // ============================================================

  property p_tx_stable_when_stalled;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i &&
    !tx_ready_i

    |=> (
      tx_valid_i &&
      $stable(tx_dw0_i) &&
      $stable(tx_dw1_i) &&
      $stable(tx_dw2_i) &&
      $stable(tx_payload_valid_i)
    );

  endproperty


  a_tx_stable_when_stalled:
    assert property (
      p_tx_stable_when_stalled
    )
    else
      $error(
        "PCIe ASSERTION: TX changed while stalled"
      );


  // ============================================================
  // Valid TX Header Must Not Contain X
  // ============================================================

  property p_tx_header_known;

    @(posedge clk)
    disable iff (!rst_n)

    tx_valid_i

    |->

    !$isunknown({
      tx_dw0_i,
      tx_dw1_i,
      tx_dw2_i
    });

  endproperty


  a_tx_header_known:
    assert property (
      p_tx_header_known
    )
    else
      $error(
        "PCIe ASSERTION: X/Z detected in TX header"
      );


endmodule