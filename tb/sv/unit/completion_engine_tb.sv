`timescale 1ns/1ps

module completion_engine_tb;

  import pcie_tlp_pkg::*;

  logic clk;
  logic rst_n;

  logic         cpl_req_valid;
  logic         cpl_req_ready;

  cpl_status_e  cpl_status;

  logic         cpl_data_valid;
  logic [31:0]  cpl_data;

  logic [15:0]  requester_id;
  logic [7:0]   tag;
  logic [6:0]   lower_addr;

  logic         tx_valid;
  logic         tx_ready;

  tlp_header_t  tx_header;

  logic         tx_payload_valid;
  logic [31:0]  tx_payload_data;

  int error_count;


  completion_engine dut (
    .clk                (clk),
    .rst_n              (rst_n),

    .cpl_req_valid_i    (cpl_req_valid),
    .cpl_req_ready_o    (cpl_req_ready),

    .cpl_status_i       (cpl_status),

    .cpl_data_valid_i   (cpl_data_valid),
    .cpl_data_i         (cpl_data),

    .requester_id_i     (requester_id),
    .tag_i              (tag),
    .lower_addr_i       (lower_addr),

    .tx_valid_o         (tx_valid),
    .tx_ready_i         (tx_ready),

    .tx_header_o        (tx_header),

    .tx_payload_valid_o (tx_payload_valid),
    .tx_payload_data_o  (tx_payload_data)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  initial begin

    error_count = 0;

    rst_n          = 0;
    cpl_req_valid  = 0;
    cpl_status     = CPL_STATUS_SC;
    cpl_data_valid = 0;
    cpl_data       = '0;

    requester_id = '0;
    tag          = '0;
    lower_addr   = '0;

    tx_ready = 1;

    repeat (3) @(posedge clk);

    rst_n = 1;


    // Completion with Data

    @(negedge clk);

    cpl_req_valid  = 1;
    cpl_status     = CPL_STATUS_SC;
    cpl_data_valid = 1;

    cpl_data     = 32'h1234_ABCD;
    requester_id = 16'h5678;
    tag          = 8'h44;
    lower_addr   = 7'h20;

    @(posedge clk);

    #1;

    cpl_req_valid = 0;

    if (!tx_valid ||
        !tx_payload_valid ||
        tx_payload_data != 32'h1234_ABCD ||
        tx_header.tag != 8'h44 ||
        tx_header.fmt != TLP_FMT_3DW_DATA) begin

      $error("CplD generation failed");
      error_count++;

    end


    @(posedge clk);


    // Completion without Data

    @(negedge clk);

    cpl_req_valid  = 1;
    cpl_status     = CPL_STATUS_UR;
    cpl_data_valid = 0;

    requester_id = 16'hAAAA;
    tag          = 8'h55;

    @(posedge clk);

    #1;

    cpl_req_valid = 0;

    if (!tx_valid ||
        tx_payload_valid ||
        tx_header.cpl_status != CPL_STATUS_UR ||
        tx_header.fmt != TLP_FMT_3DW_NO_DATA) begin

      $error("CPL generation failed");
      error_count++;

    end


    if (error_count == 0)
      $display("COMPLETION ENGINE TEST: PASS");
    else begin
      $display("COMPLETION ENGINE TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule