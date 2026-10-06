`timescale 1ns/1ps

module bar_decoder_tb;

  localparam int ADDR_WIDTH = 32;

  localparam logic [ADDR_WIDTH-1:0] BAR0_BASE_ADDR =
    32'h8000_0000;

  localparam int unsigned BAR0_SIZE_BYTES =
    4096;


  // ============================================================
  // DUT Signals
  // ============================================================

  logic                  req_valid;
  logic [ADDR_WIDTH-1:0] address;

  logic                  bar_hit;
  logic                  addr_error;

  logic [ADDR_WIDTH-1:0] local_addr;


  // ============================================================
  // Error Counter
  // ============================================================

  int error_count;


  // ============================================================
  // DUT
  // ============================================================

  bar_decoder #(
    .ADDR_WIDTH      (ADDR_WIDTH),
    .BAR0_BASE_ADDR  (BAR0_BASE_ADDR),
    .BAR0_SIZE_BYTES (BAR0_SIZE_BYTES)
  ) dut (
    .req_valid_i  (req_valid),
    .address_i    (address),

    .bar_hit_o    (bar_hit),
    .addr_error_o (addr_error),
    .local_addr_o (local_addr)
  );


  // ============================================================
  // Clear Inputs
  // ============================================================

  task automatic clear_inputs();

    req_valid = 1'b0;
    address   = '0;

    #1;

  endtask


  // ============================================================
  // TEST 1
  // BAR Base Address
  // ============================================================

  task automatic test_base_address();

    $display("TEST: BAR base address");

    clear_inputs();

    req_valid = 1'b1;
    address   = BAR0_BASE_ADDR;

    #1;


    if (!bar_hit) begin

      $error("Base address did not generate BAR hit");
      error_count++;

    end


    if (addr_error) begin

      $error("Base address incorrectly generated error");
      error_count++;

    end


    if (local_addr != 32'h0000_0000) begin

      $error(
        "Base address local offset mismatch. Got %h",
        local_addr
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 2
  // Address Inside BAR
  // ============================================================

  task automatic test_inside_bar();

    $display("TEST: Address inside BAR");

    clear_inputs();

    req_valid = 1'b1;

    address =
      BAR0_BASE_ADDR + 32'h0000_0100;

    #1;


    if (!bar_hit) begin

      $error("Valid BAR address did not hit");
      error_count++;

    end


    if (addr_error) begin

      $error("Valid BAR address generated error");
      error_count++;

    end


    if (local_addr != 32'h0000_0100) begin

      $error(
        "Local address mismatch. Got %h",
        local_addr
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 3
  // Last Valid Byte
  // ============================================================

  task automatic test_last_valid_address();

    $display("TEST: Last valid BAR address");

    clear_inputs();

    req_valid = 1'b1;

    address =
      BAR0_BASE_ADDR +
      BAR0_SIZE_BYTES -
      1;

    #1;


    if (!bar_hit) begin

      $error("Last valid BAR address did not hit");
      error_count++;

    end


    if (addr_error) begin

      $error(
        "Last valid BAR address generated error"
      );

      error_count++;

    end


    if (local_addr != 32'h0000_0FFF) begin

      $error(
        "Last valid local offset mismatch. Got %h",
        local_addr
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 4
  // First Invalid Address Above BAR
  // ============================================================

  task automatic test_above_bar();

    $display("TEST: Address above BAR");

    clear_inputs();

    req_valid = 1'b1;

    address =
      BAR0_BASE_ADDR +
      BAR0_SIZE_BYTES;

    #1;


    if (bar_hit) begin

      $error(
        "Out-of-range address incorrectly generated BAR hit"
      );

      error_count++;

    end


    if (!addr_error) begin

      $error(
        "Out-of-range address did not generate error"
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 5
  // Address Below BAR
  // ============================================================

  task automatic test_below_bar();

    $display("TEST: Address below BAR");

    clear_inputs();

    req_valid = 1'b1;

    address =
      BAR0_BASE_ADDR - 32'h4;

    #1;


    if (bar_hit) begin

      $error(
        "Below-BAR address incorrectly generated BAR hit"
      );

      error_count++;

    end


    if (!addr_error) begin

      $error(
        "Below-BAR address did not generate error"
      );

      error_count++;

    end


    clear_inputs();

  endtask


  // ============================================================
  // TEST 6
  // Request Not Valid
  // ============================================================

  task automatic test_request_invalid();

    $display("TEST: req_valid low");

    clear_inputs();

    req_valid = 1'b0;

    address =
      BAR0_BASE_ADDR + 32'h100;

    #1;


    if (bar_hit !== 1'b0) begin

      $error(
        "BAR hit asserted while req_valid was low"
      );

      error_count++;

    end


    if (addr_error !== 1'b0) begin

      $error(
        "Address error asserted while req_valid was low"
      );

      error_count++;

    end


    if (local_addr !== '0) begin

      $error(
        "Local address not zero while req_valid was low"
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


    test_base_address();

    test_inside_bar();

    test_last_valid_address();

    test_above_bar();

    test_below_bar();

    test_request_invalid();


    // ==========================================================
    // Final Result
    // ==========================================================

    if (error_count == 0) begin

      $display("");
      $display(
        "========================================"
      );

      $display(
        " BAR DECODER TEST: PASS"
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
        " BAR DECODER TEST: FAIL"
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