`timescale 1ns/1ps

module tlp_rx_parser_tb;

  import pcie_tlp_pkg::*;


  // ============================================================
  // DUT Signals
  // ============================================================

  logic        tlp_valid;

  logic [31:0] tlp_dw0;
  logic [31:0] tlp_dw1;
  logic [31:0] tlp_dw2;

  logic        parsed_valid;
  logic        supported;

  tlp_header_t header;
  tlp_kind_e   kind;


  // ============================================================
  // Error Counter
  // ============================================================

  int error_count;


  // ============================================================
  // DUT
  // ============================================================

  tlp_rx_parser dut (
    .tlp_valid_i    (tlp_valid),

    .tlp_dw0_i      (tlp_dw0),
    .tlp_dw1_i      (tlp_dw1),
    .tlp_dw2_i      (tlp_dw2),

    .parsed_valid_o (parsed_valid),
    .supported_o    (supported),

    .header_o       (header),
    .kind_o         (kind)
  );


  // ============================================================
  // Reset Inputs
  // ============================================================

  task automatic clear_inputs();

    tlp_valid = 1'b0;

    tlp_dw0 = '0;
    tlp_dw1 = '0;
    tlp_dw2 = '0;

    #1;

  endtask


  // ============================================================
  // TEST 1
  // Memory Read
  // ============================================================

  task automatic test_mem_read();

    $display("TEST: Memory Read");

    clear_inputs();


    // ----------------------------------------------------------
    // DW0
    //
    // Fmt    = 000
    // Type   = 00000
    // Length = 1 DW
    // ----------------------------------------------------------

    tlp_dw0 = '0;

    tlp_dw0[31:29] = TLP_FMT_3DW_NO_DATA;
    tlp_dw0[28:24] = TLP_TYPE_MEM;
    tlp_dw0[9:0]   = 10'd1;


    // ----------------------------------------------------------
    // DW1
    // ----------------------------------------------------------

    tlp_dw1[31:16] = 16'h1234;
    tlp_dw1[15:8]  = 8'h55;

    tlp_dw1[7:4]   = 4'b0000;
    tlp_dw1[3:0]   = 4'b1111;


    // ----------------------------------------------------------
    // DW2
    // ----------------------------------------------------------

    tlp_dw2 = 32'h8000_0100;


    tlp_valid = 1'b1;

    #1;


    if (!parsed_valid) begin

      $error("Memory Read: parsed_valid not asserted");
      error_count++;

    end


    if (!supported) begin

      $error("Memory Read: packet marked unsupported");
      error_count++;

    end


    if (kind != TLP_KIND_MEM_RD) begin

      $error("Memory Read: incorrect kind");
      error_count++;

    end


    if (header.requester_id != 16'h1234) begin

      $error("Memory Read: requester ID mismatch");
      error_count++;

    end


    if (header.tag != 8'h55) begin

      $error("Memory Read: tag mismatch");
      error_count++;

    end


    if (header.length_dw != 10'd1) begin

      $error("Memory Read: length mismatch");
      error_count++;

    end


    if (header.first_be != 4'b1111) begin

      $error("Memory Read: first BE mismatch");
      error_count++;

    end


    if (header.address != 32'h8000_0100) begin

      $error(
        "Memory Read: address mismatch. Got %h",
        header.address
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 2
  // Memory Write
  // ============================================================

  task automatic test_mem_write();

    $display("TEST: Memory Write");

    clear_inputs();


    tlp_dw0 = '0;

    tlp_dw0[31:29] = TLP_FMT_3DW_DATA;
    tlp_dw0[28:24] = TLP_TYPE_MEM;
    tlp_dw0[9:0]   = 10'd1;


    tlp_dw1[31:16] = 16'hABCD;
    tlp_dw1[15:8]  = 8'h22;

    tlp_dw1[7:4]   = 4'b0000;
    tlp_dw1[3:0]   = 4'b1111;


    tlp_dw2 = 32'h8000_0200;


    tlp_valid = 1'b1;

    #1;


    if (!parsed_valid) begin

      $error("Memory Write: parsed_valid not asserted");
      error_count++;

    end


    if (!supported) begin

      $error("Memory Write: packet marked unsupported");
      error_count++;

    end


    if (kind != TLP_KIND_MEM_WR) begin

      $error("Memory Write: incorrect kind");
      error_count++;

    end


    if (header.requester_id != 16'hABCD) begin

      $error("Memory Write: requester ID mismatch");
      error_count++;

    end


    if (header.tag != 8'h22) begin

      $error("Memory Write: tag mismatch");
      error_count++;

    end


    if (header.address != 32'h8000_0200) begin

      $error("Memory Write: address mismatch");
      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 3
  // Completion With Data
  // ============================================================

  task automatic test_completion_data();

    $display("TEST: Completion With Data");

    clear_inputs();


    // ----------------------------------------------------------
    // DW0
    // ----------------------------------------------------------

    tlp_dw0 = '0;

    tlp_dw0[31:29] = TLP_FMT_3DW_DATA;
    tlp_dw0[28:24] = TLP_TYPE_CPL;
    tlp_dw0[9:0]   = 10'd1;


    // ----------------------------------------------------------
    // DW1
    //
    // Completer ID
    // Completion Status
    // Byte Count
    // ----------------------------------------------------------

    tlp_dw1 = '0;

    tlp_dw1[31:16] = 16'h0100;

    tlp_dw1[15:13] =
      CPL_STATUS_SC;

    tlp_dw1[11:0] =
      12'd4;


    // ----------------------------------------------------------
    // DW2
    //
    // Requester ID
    // Tag
    // Lower Address
    // ----------------------------------------------------------

    tlp_dw2 = '0;

    tlp_dw2[31:16] = 16'h1234;

    tlp_dw2[15:8] =
      8'h66;

    tlp_dw2[6:0] =
      7'h20;


    tlp_valid = 1'b1;

    #1;


    if (!supported) begin

      $error("CplD: packet marked unsupported");
      error_count++;

    end


    if (kind != TLP_KIND_CPLD) begin

      $error("CplD: incorrect kind");
      error_count++;

    end


    if (header.completer_id != 16'h0100) begin

      $error("CplD: completer ID mismatch");
      error_count++;

    end


    if (header.cpl_status != CPL_STATUS_SC) begin

      $error("CplD: completion status mismatch");
      error_count++;

    end


    if (header.byte_count != 12'd4) begin

      $error("CplD: byte count mismatch");
      error_count++;

    end


    if (header.requester_id != 16'h1234) begin

      $error("CplD: requester ID mismatch");
      error_count++;

    end


    if (header.tag != 8'h66) begin

      $error("CplD: tag mismatch");
      error_count++;

    end


    if (header.lower_address != 7'h20) begin

      $error("CplD: lower address mismatch");
      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 4
  // Completion Without Data
  // ============================================================

  task automatic test_completion_no_data();

    $display("TEST: Completion Without Data");

    clear_inputs();


    tlp_dw0 = '0;

    tlp_dw0[31:29] = TLP_FMT_3DW_NO_DATA;
    tlp_dw0[28:24] = TLP_TYPE_CPL;
    tlp_dw0[9:0]   = 10'd0;


    tlp_dw1 = '0;

    tlp_dw1[31:16] = 16'h0100;

    tlp_dw1[15:13] =
      CPL_STATUS_UR;

    tlp_dw1[11:0] =
      12'd0;


    tlp_dw2 = '0;

    tlp_dw2[31:16] = 16'h5678;
    tlp_dw2[15:8]  = 8'h44;


    tlp_valid = 1'b1;

    #1;


    if (kind != TLP_KIND_CPL) begin

      $error("CPL: incorrect kind");
      error_count++;

    end


    if (header.cpl_status != CPL_STATUS_UR) begin

      $error("CPL: status mismatch");
      error_count++;

    end


    if (header.tag != 8'h44) begin

      $error("CPL: tag mismatch");
      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 5
  // Unsupported TLP
  // ============================================================

  task automatic test_unsupported();

    $display("TEST: Unsupported TLP");

    clear_inputs();


    tlp_dw0 = '0;

    tlp_dw0[31:29] =
      TLP_FMT_3DW_NO_DATA;

    tlp_dw0[28:24] =
      5'b11111;


    tlp_valid = 1'b1;

    #1;


    if (supported !== 1'b0) begin

      $error(
        "Unsupported TLP incorrectly marked supported"
      );

      error_count++;

    end


    if (kind != TLP_KIND_UNSUPPORTED) begin

      $error(
        "Unsupported TLP incorrect decoded kind"
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    error_count = 0;


    clear_inputs();


    test_mem_read();

    test_mem_write();

    test_completion_data();

    test_completion_no_data();

    test_unsupported();


    // ==========================================================
    // Final Result
    // ==========================================================

    if (error_count == 0) begin

      $display("");
      $display(
        "========================================"
      );

      $display(
        " TLP RX PARSER TEST: PASS"
      );

      $display(
        "========================================"
      );

    end
    else begin

      $display("");
      $display(
        "========================================"
      );

      $display(
        " TLP RX PARSER TEST: FAIL"
      );

      $display(
        " Errors = %0d",
        error_count
      );

      $display(
        "========================================"
      );

      $fatal(1);

    end


    $finish;

  end


endmodule