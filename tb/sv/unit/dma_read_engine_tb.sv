`timescale 1ns/1ps

module dma_read_engine_tb;

  import pcie_tlp_pkg::*;

  localparam int TIMEOUT_CYCLES = 8;

  logic clk;
  logic rst_n;

  logic        cmd_valid;
  logic        cmd_ready;
  logic [31:0] cmd_address;

  logic        alloc_valid;
  logic        alloc_ready;
  logic        alloc_duplicate;

  logic [7:0]  alloc_tag;
  logic [31:0] alloc_address;
  logic [9:0]  alloc_length;

  logic        cancel_valid;
  logic [7:0]  cancel_tag;

  logic        tx_valid;
  logic        tx_ready;

  tlp_header_t tx_header;

  logic        tx_payload_valid;
  logic [31:0] tx_payload_data;

  logic        cpl_valid;
  tlp_header_t cpl_header;

  logic        cpl_payload_valid;
  logic [31:0] cpl_payload_data;

  logic        read_done;
  logic        read_error;

  logic [31:0] read_data;

  logic        busy;

  int error_count;


  dma_read_engine #(
    .COMPLETION_TIMEOUT_CYCLES(TIMEOUT_CYCLES)
  ) dut (
    .clk                (clk),
    .rst_n              (rst_n),

    .cmd_valid_i        (cmd_valid),
    .cmd_ready_o        (cmd_ready),
    .cmd_address_i      (cmd_address),

    .alloc_valid_o      (alloc_valid),
    .alloc_ready_i      (alloc_ready),
    .alloc_duplicate_i  (alloc_duplicate),

    .alloc_tag_o        (alloc_tag),
    .alloc_address_o    (alloc_address),
    .alloc_length_dw_o  (alloc_length),

    .cancel_valid_o     (cancel_valid),
    .cancel_tag_o       (cancel_tag),

    .tx_valid_o         (tx_valid),
    .tx_ready_i         (tx_ready),

    .tx_header_o        (tx_header),

    .tx_payload_valid_o (tx_payload_valid),
    .tx_payload_data_o  (tx_payload_data),

    .cpl_valid_i        (cpl_valid),
    .cpl_header_i       (cpl_header),

    .cpl_payload_valid_i(cpl_payload_valid),
    .cpl_payload_data_i (cpl_payload_data),

    .read_done_o        (read_done),
    .read_error_o       (read_error),

    .read_data_o        (read_data),

    .busy_o             (busy)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  initial begin

    error_count = 0;

    rst_n = 0;

    cmd_valid   = 0;
    cmd_address = 0;

    alloc_ready     = 1;
    alloc_duplicate = 0;

    tx_ready = 1;

    cpl_valid         = 0;
    cpl_header        = '0;
    cpl_payload_valid = 0;
    cpl_payload_data  = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;


    // Issue read command

    wait(cmd_ready);
    @(negedge clk);

    cmd_valid   = 1;
    cmd_address = 32'h1000_0000;

    @(posedge clk);
    #1ps;
    cmd_valid = 0;


    // Wait for generated TLP

    wait(tx_valid);

    #1;

    if (tx_header.address != 32'h1000_0000 ||
        tx_header.fmt != TLP_FMT_3DW_NO_DATA) begin

      $error("DMA read TLP incorrect");
      error_count++;

    end


    // Wait until engine is waiting for completion

    @(posedge clk);

    repeat (2) @(posedge clk);


    // Send matching CplD

    @(negedge clk);

    cpl_header = '0;

    cpl_header.fmt        = TLP_FMT_3DW_DATA;
    cpl_header.tlp_type   = TLP_TYPE_CPL;

    cpl_header.tag        = tx_header.tag;

    cpl_header.cpl_status = CPL_STATUS_SC;

    cpl_valid         = 1;
    cpl_payload_valid = 1;

    cpl_payload_data =
      32'hCAFE_BABE;

    @(posedge clk);
    #1ps;
    cpl_valid         = 0;
    cpl_payload_valid = 0;


    wait(read_done);

    #1;

    if (read_data != 32'hCAFE_BABE) begin

      $error("DMA read data mismatch");
      error_count++;

    end


    if (read_error) begin

      $error("Unexpected DMA read error");
      error_count++;

    end


    if (error_count == 0)
      $display("DMA READ ENGINE TEST: PASS");
    else begin
      $display("DMA READ ENGINE TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule