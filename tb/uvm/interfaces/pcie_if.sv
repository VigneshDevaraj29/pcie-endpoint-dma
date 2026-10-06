interface pcie_if (
  input logic clk,
  input logic rst_n
);

  logic        rx_valid;
  logic        rx_ready;

  logic [31:0] rx_dw0;
  logic [31:0] rx_dw1;
  logic [31:0] rx_dw2;

  logic        rx_payload_valid;
  logic [31:0] rx_payload_data;


  logic        tx_valid;
  logic        tx_ready;

  logic [31:0] tx_dw0;
  logic [31:0] tx_dw1;
  logic [31:0] tx_dw2;

  logic        tx_payload_valid;
  logic [31:0] tx_payload_data;


  clocking drv_cb @(posedge clk);

    default input #1step output #0;

    output rx_valid;
    output rx_dw0;
    output rx_dw1;
    output rx_dw2;

    output rx_payload_valid;
    output rx_payload_data;

    output tx_ready;

    input rx_ready;

    input tx_valid;
    input tx_dw0;
    input tx_dw1;
    input tx_dw2;

    input tx_payload_valid;
    input tx_payload_data;

  endclocking


  clocking mon_cb @(posedge clk);

    default input #1step;

    input rx_valid;
    input rx_ready;

    input rx_dw0;
    input rx_dw1;
    input rx_dw2;

    input rx_payload_valid;
    input rx_payload_data;

    input tx_valid;
    input tx_ready;

    input tx_dw0;
    input tx_dw1;
    input tx_dw2;

    input tx_payload_valid;
    input tx_payload_data;

  endclocking


endinterface