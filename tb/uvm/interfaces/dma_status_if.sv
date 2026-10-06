interface dma_status_if #(
  parameter int OUTSTANDING_ENTRIES = 16
)(
  input logic clk,
  input logic rst_n
);

  logic dma_busy;
  logic dma_done;
  logic dma_error;

  logic unexpected_completion;

  logic [$clog2(OUTSTANDING_ENTRIES+1)-1:0]
        outstanding_count;

  logic tx_formatter_error;


  clocking mon_cb @(posedge clk);

    default input #1step;

    input dma_busy;
    input dma_done;
    input dma_error;

    input unexpected_completion;
    input outstanding_count;

    input tx_formatter_error;

  endclocking


endinterface