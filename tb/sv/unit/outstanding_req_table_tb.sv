`timescale 1ns/1ps

module outstanding_req_table_tb;

  import pcie_tlp_pkg::*;

  localparam int NUM_ENTRIES = 4;

  logic clk;
  logic rst_n;

  logic        alloc_valid;
  logic        alloc_ready;

  logic [7:0]  alloc_tag;
  logic [31:0] alloc_address;
  logic [9:0]  alloc_length;

  logic        alloc_duplicate;

  logic        cpl_valid;
  logic [7:0]  cpl_tag;

  logic        cpl_match;
  logic        cpl_unexpected;

  logic [31:0] matched_address;
  logic [9:0]  matched_length;

  logic        cancel_valid;
  logic [7:0]  cancel_tag;

  logic        cancel_match;

  logic        table_full;

  logic [$clog2(NUM_ENTRIES+1)-1:0]
               outstanding_count;

  int error_count;


  outstanding_req_table #(
    .NUM_ENTRIES(NUM_ENTRIES)
  ) dut (
    .clk                   (clk),
    .rst_n                 (rst_n),

    .alloc_valid_i         (alloc_valid),
    .alloc_ready_o         (alloc_ready),

    .alloc_tag_i           (alloc_tag),
    .alloc_address_i       (alloc_address),
    .alloc_length_dw_i     (alloc_length),

    .alloc_duplicate_o     (alloc_duplicate),

    .cpl_valid_i           (cpl_valid),
    .cpl_tag_i             (cpl_tag),

    .cpl_match_o           (cpl_match),
    .cpl_unexpected_o      (cpl_unexpected),

    .matched_address_o     (matched_address),
    .matched_length_dw_o   (matched_length),

    .cancel_valid_i        (cancel_valid),
    .cancel_tag_i          (cancel_tag),

    .cancel_match_o        (cancel_match),

    .table_full_o          (table_full),

    .outstanding_count_o   (outstanding_count)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  task automatic allocate(
    input logic [7:0] tag,
    input logic [31:0] addr
  );

    @(negedge clk);

    alloc_valid   = 1;
    alloc_tag     = tag;
    alloc_address = addr;
    alloc_length  = 1;

    @(posedge clk);
    #1ps;

    alloc_valid = 0;

  endtask


  initial begin

    error_count = 0;

    rst_n = 0;

    alloc_valid = 0;
    alloc_tag = 0;
    alloc_address = 0;
    alloc_length = 0;

    cpl_valid = 0;
    cpl_tag = 0;

    cancel_valid = 0;
    cancel_tag = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;


    allocate(8'h01, 32'h1000);
    allocate(8'h02, 32'h2000);
    allocate(8'h03, 32'h3000);


    #1;

    if (outstanding_count != 3) begin
      $error("Outstanding count incorrect");
      error_count++;
    end


    // ============================================================
    // Duplicate allocation
    // Keep request asserted through a posedge so the SVA property
    // a_duplicate_not_accepted can sample the condition.
    // ============================================================

    @(negedge clk);

    alloc_valid = 1;
    alloc_tag   = 8'h02;

    #1;

    if (!alloc_duplicate ||
        alloc_ready) begin

      $error("Duplicate tag detection failed");
      error_count++;

    end

    @(posedge clk);
    #1ps;

    alloc_valid = 0;


    // ============================================================
    // Fill final entry
    // Exercise table_full and a_full_count_consistent.
    // ============================================================

    allocate(8'h04, 32'h4000);

    @(posedge clk);
    #1;

    if (!table_full ||
        outstanding_count != NUM_ENTRIES) begin

      $error(
        "Full-table status/count check failed"
      );
      error_count++;

    end


    // ============================================================
    // Remove temporary fourth entry
    // Restore original three-entry state for remaining tests.
    // ============================================================

    @(negedge clk);

    cancel_valid = 1;
    cancel_tag   = 8'h04;

    #1;

    if (!cancel_match) begin
      $error(
        "Temporary full-table entry cancellation failed"
      );
      error_count++;
    end

    @(posedge clk);
    #1ps;

    cancel_valid = 0;


    // ============================================================
    // Out-of-order completion: tag 03
    // ============================================================

    @(negedge clk);

    cpl_valid = 1;
    cpl_tag   = 8'h03;

    #1;

    if (!cpl_match ||
        matched_address != 32'h3000) begin

      $error("Completion tag lookup failed");
      error_count++;

    end

    @(posedge clk);
    #1ps;

    cpl_valid = 0;


    // ============================================================
    // Completion tag 01
    // ============================================================

    @(negedge clk);

    cpl_valid = 1;
    cpl_tag   = 8'h01;

    #1;

    if (!cpl_match ||
        matched_address != 32'h1000) begin

      $error("Out-of-order lookup failed");
      error_count++;

    end

    @(posedge clk);
    #1ps;

    cpl_valid = 0;


    // ============================================================
    // Cancel tag 02
    // ============================================================

    @(negedge clk);

    cancel_valid = 1;
    cancel_tag   = 8'h02;

    #1;

    if (!cancel_match) begin
      $error("Cancellation failed");
      error_count++;
    end

    @(posedge clk);
    #1ps;

    cancel_valid = 0;


    // ============================================================
    // Unexpected completion
    // ============================================================

    @(negedge clk);

    cpl_valid = 1;
    cpl_tag   = 8'hAA;

    #1;

    if (!cpl_unexpected) begin
      $error("Unexpected completion not detected");
      error_count++;
    end

    @(posedge clk);
    #1ps;

    cpl_valid = 0;


    // ============================================================
    // Final result
    // ============================================================

    if (error_count == 0)
      $display(
        "OUTSTANDING REQUEST TABLE TEST: PASS"
      );
    else begin
      $display(
        "OUTSTANDING REQUEST TABLE TEST: FAIL errors=%0d",
        error_count
      );
      $fatal(1);
    end

    $finish;

  end

endmodule