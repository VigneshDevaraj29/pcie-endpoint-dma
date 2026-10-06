module tag_assertions
  import pcie_tlp_pkg::*;
#(
  parameter int NUM_ENTRIES = 16
)(
  input logic                     clk,
  input logic                     rst_n,

  // Allocation
  input logic                     alloc_valid_i,
  input logic                     alloc_ready_i,

  input logic [TAG_WIDTH-1:0]     alloc_tag_i,

  input logic                     alloc_duplicate_i,

  // Completion
  input logic                     cpl_valid_i,
  input logic                     cpl_match_i,
  input logic                     cpl_unexpected_i,

  input logic [TAG_WIDTH-1:0]     cpl_tag_i,

  // Cancellation
  input logic                     cancel_valid_i,
  input logic                     cancel_match_i,

  input logic [TAG_WIDTH-1:0]     cancel_tag_i,

  // Status
  input logic                     table_full_i,

  input logic [$clog2(NUM_ENTRIES+1)-1:0]
                                  outstanding_count_i
);


  // ============================================================
  // Duplicate Tag Cannot Be Accepted
  // ============================================================

  property p_duplicate_not_accepted;

    @(posedge clk)
    disable iff (!rst_n)

    alloc_valid_i &&
    alloc_duplicate_i

    |->

    !alloc_ready_i;

  endproperty


  a_duplicate_not_accepted:
    assert property (
      p_duplicate_not_accepted
    )
    else
      $error(
        "TAG ASSERTION: Duplicate tag was accepted"
      );


  // ============================================================
  // Completion Match and Unexpected Cannot Both Be True
  // ============================================================

  property p_completion_result_exclusive;

    @(posedge clk)
    disable iff (!rst_n)

    !(cpl_match_i &&
      cpl_unexpected_i);

  endproperty


  a_completion_result_exclusive:
    assert property (
      p_completion_result_exclusive
    )
    else
      $error(
        "TAG ASSERTION: Completion marked both matched and unexpected"
      );


  // ============================================================
  // Match Requires Valid Completion
  // ============================================================

  property p_match_requires_completion;

    @(posedge clk)
    disable iff (!rst_n)

    cpl_match_i

    |->

    cpl_valid_i;

  endproperty


  a_match_requires_completion:
    assert property (
      p_match_requires_completion
    )
    else
      $error(
        "TAG ASSERTION: Match asserted without completion"
      );


  // ============================================================
  // Unexpected Requires Valid Completion
  // ============================================================

  property p_unexpected_requires_completion;

    @(posedge clk)
    disable iff (!rst_n)

    cpl_unexpected_i

    |->

    cpl_valid_i;

  endproperty


  a_unexpected_requires_completion:
    assert property (
      p_unexpected_requires_completion
    )
    else
      $error(
        "TAG ASSERTION: Unexpected flag without completion"
      );


  // ============================================================
  // Cancel Match Requires Cancel Request
  // ============================================================

  property p_cancel_match_requires_valid;

    @(posedge clk)
    disable iff (!rst_n)

    cancel_match_i

    |->

    cancel_valid_i;

  endproperty


  a_cancel_match_requires_valid:
    assert property (
      p_cancel_match_requires_valid
    )
    else
      $error(
        "TAG ASSERTION: Cancel match without cancel request"
      );


  // ============================================================
  // Outstanding Count Must Never Exceed Table Size
  // ============================================================

  property p_count_within_range;

    @(posedge clk)
    disable iff (!rst_n)

    outstanding_count_i <=
      NUM_ENTRIES;

  endproperty


  a_count_within_range:
    assert property (
      p_count_within_range
    )
    else
      $error(
        "TAG ASSERTION: Outstanding count exceeded table capacity"
      );


  // ============================================================
  // Full Table Corresponds To Maximum Outstanding Count
  // ============================================================

  property p_full_count_consistent;

    @(posedge clk)
    disable iff (!rst_n)

    table_full_i

    |->

    (outstanding_count_i ==
     NUM_ENTRIES);

  endproperty


  a_full_count_consistent:
    assert property (
      p_full_count_consistent
    )
    else
      $error(
        "TAG ASSERTION: Table full inconsistent with count"
      );


endmodule