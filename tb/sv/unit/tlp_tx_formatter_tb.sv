`timescale 1ns/1ps

module tlp_tx_formatter_tb;

  import pcie_tlp_pkg::*;

  logic        tx_valid;
  logic        tx_ready;

  tlp_header_t header;

  logic        payload_valid;
  logic [31:0] payload_data;

  logic        tlp_valid;
  logic        tlp_ready;

  logic [31:0] tlp_dw0;
  logic [31:0] tlp_dw1;
  logic [31:0] tlp_dw2;

  logic        tlp_payload_valid;
  logic [31:0] tlp_payload_data;

  logic        formatter_error;

  int error_count;


  tlp_tx_formatter dut (
    .tx_valid_i          (tx_valid),
    .tx_ready_o          (tx_ready),

    .header_i            (header),

    .payload_valid_i     (payload_valid),
    .payload_data_i      (payload_data),

    .tlp_valid_o         (tlp_valid),
    .tlp_ready_i         (tlp_ready),

    .tlp_dw0_o           (tlp_dw0),
    .tlp_dw1_o           (tlp_dw1),
    .tlp_dw2_o           (tlp_dw2),

    .tlp_payload_valid_o (tlp_payload_valid),
    .tlp_payload_data_o  (tlp_payload_data),

    .formatter_error_o   (formatter_error)
  );


  initial begin

    error_count = 0;

    tx_valid      = 0;
    header        = '0;
    payload_valid = 0;
    payload_data  = '0;

    tlp_ready = 1;

    #1;


    // Memory Read

    header = '0;

    header.fmt          = TLP_FMT_3DW_NO_DATA;
    header.tlp_type     = TLP_TYPE_MEM;
    header.length_dw    = 1;
    header.requester_id = 16'h1234;
    header.tag          = 8'h11;
    header.first_be     = 4'hF;
    header.address      = 32'h8000_0100;

    tx_valid = 1;

    #1;

    if (!tlp_valid ||
        tlp_dw1[31:16] != 16'h1234 ||
        tlp_dw1[15:8] != 8'h11 ||
        tlp_dw2 != 32'h8000_0100) begin

      $error("Memory Read formatting failed");
      error_count++;

    end


    // Memory Write

    header.fmt      = TLP_FMT_3DW_DATA;

    payload_valid   = 1;
    payload_data    = 32'hDEAD_BEEF;

    #1;

    if (!tlp_payload_valid ||
        tlp_payload_data != 32'hDEAD_BEEF) begin

      $error("Memory Write formatting failed");
      error_count++;

    end


    // Completion With Data

    header = '0;

    header.fmt           = TLP_FMT_3DW_DATA;
    header.tlp_type      = TLP_TYPE_CPL;
    header.length_dw     = 1;

    header.completer_id  = 16'h0100;
    header.cpl_status    = CPL_STATUS_SC;
    header.byte_count    = 4;

    header.requester_id  = 16'h2222;
    header.tag           = 8'h77;
    header.lower_address = 7'h20;

    payload_valid = 1;
    payload_data  = 32'hCAFE_BABE;

    #1;

    if (tlp_dw1[31:16] != 16'h0100 ||
        tlp_dw2[15:8] != 8'h77 ||
        !tlp_payload_valid) begin

      $error("CplD formatting failed");
      error_count++;

    end


    // Unsupported

    header = '0;

    header.fmt      = TLP_FMT_4DW_NO_DATA;
    header.tlp_type = TLP_TYPE_MEM;

    payload_valid = 0;

    #1;

    if (!formatter_error) begin
      $error("Unsupported TLP not flagged");
      error_count++;
    end


    if (error_count == 0)
      $display("TLP TX FORMATTER TEST: PASS");
    else begin
      $display("TLP TX FORMATTER TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule