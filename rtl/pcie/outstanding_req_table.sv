module outstanding_req_table
  import pcie_tlp_pkg::*;
#(
  parameter int ADDR_WIDTH  = 32,
  parameter int NUM_ENTRIES = 16
)(
  input  logic                          clk,
  input  logic                          rst_n,

  // ============================================================
  // New Outstanding Request Allocation
  // ============================================================

  input  logic                          alloc_valid_i,
  output logic                          alloc_ready_o,

  input  logic [TAG_WIDTH-1:0]          alloc_tag_i,
  input  logic [ADDR_WIDTH-1:0]         alloc_address_i,
  input  logic [9:0]                    alloc_length_dw_i,

  output logic                          alloc_duplicate_o,


  // ============================================================
  // Completion Lookup
  // ============================================================

  input  logic                          cpl_valid_i,
  input  logic [TAG_WIDTH-1:0]          cpl_tag_i,

  output logic                          cpl_match_o,
  output logic                          cpl_unexpected_o,

  output logic [ADDR_WIDTH-1:0]         matched_address_o,
  output logic [9:0]                    matched_length_dw_o,


  // ============================================================
  // Request Cancellation
  //
  // Used when a completion times out or DMA aborts a request.
  // ============================================================

  input  logic                          cancel_valid_i,
  input  logic [TAG_WIDTH-1:0]          cancel_tag_i,

  output logic                          cancel_match_o,


  // ============================================================
  // Status
  // ============================================================

  output logic                          table_full_o,

  output logic [$clog2(NUM_ENTRIES+1)-1:0]
                                         outstanding_count_o
);


  // ============================================================
  // Local Parameters
  // ============================================================

  localparam int INDEX_WIDTH =
    (NUM_ENTRIES <= 1) ? 1 : $clog2(NUM_ENTRIES);


  // ============================================================
  // Request State
  // ============================================================

  typedef enum logic {
    REQ_FREE     = 1'b0,
    REQ_WAIT_CPL = 1'b1
  } req_state_e;


  // ============================================================
  // Table Storage
  // ============================================================

  req_state_e             state_q   [0:NUM_ENTRIES-1];

  logic [TAG_WIDTH-1:0]   tag_q     [0:NUM_ENTRIES-1];

  logic [ADDR_WIDTH-1:0]  address_q [0:NUM_ENTRIES-1];

  logic [9:0]             length_q  [0:NUM_ENTRIES-1];


  // ============================================================
  // Search Signals
  // ============================================================

  logic                   free_found;
  logic [INDEX_WIDTH-1:0] free_index;

  logic                   duplicate_found;

  logic                   completion_found;
  logic [INDEX_WIDTH-1:0] completion_index;

  logic                   cancel_found;
  logic [INDEX_WIDTH-1:0] cancel_index;


  logic                   alloc_fire;
  logic                   cpl_fire;
  logic                   cancel_fire;


  integer i;


  // ============================================================
  // Find Free Entry
  // ============================================================

  always_comb begin

    free_found = 1'b0;
    free_index = '0;

    for (int idx = 0; idx < NUM_ENTRIES; idx++) begin

      if (!free_found &&
          (state_q[idx] == REQ_FREE)) begin

        free_found = 1'b1;
        free_index = INDEX_WIDTH'(idx);

      end

    end

  end


  // ============================================================
  // Duplicate Tag Detection
  // ============================================================

  always_comb begin

    duplicate_found = 1'b0;

    for (int idx = 0; idx < NUM_ENTRIES; idx++) begin

      if ((state_q[idx] == REQ_WAIT_CPL) &&
          (tag_q[idx] == alloc_tag_i)) begin

        duplicate_found = 1'b1;

      end

    end

  end


  // ============================================================
  // Completion Tag Lookup
  // ============================================================

  always_comb begin

    completion_found = 1'b0;
    completion_index = '0;

    for (int idx = 0; idx < NUM_ENTRIES; idx++) begin

      if (!completion_found &&
          (state_q[idx] == REQ_WAIT_CPL) &&
          (tag_q[idx] == cpl_tag_i)) begin

        completion_found = 1'b1;
        completion_index = INDEX_WIDTH'(idx);

      end

    end

  end


  // ============================================================
  // Cancellation Tag Lookup
  // ============================================================

  always_comb begin

    cancel_found = 1'b0;
    cancel_index = '0;

    for (int idx = 0; idx < NUM_ENTRIES; idx++) begin

      if (!cancel_found &&
          (state_q[idx] == REQ_WAIT_CPL) &&
          (tag_q[idx] == cancel_tag_i)) begin

        cancel_found = 1'b1;
        cancel_index = INDEX_WIDTH'(idx);

      end

    end

  end


  // ============================================================
  // Allocation Control
  // ============================================================

  always_comb begin

    table_full_o = !free_found;

    alloc_duplicate_o =
      alloc_valid_i &&
      duplicate_found;

    alloc_ready_o =
      free_found &&
      !duplicate_found;

    alloc_fire =
      alloc_valid_i &&
      alloc_ready_o;

  end


  // ============================================================
  // Completion Control
  // ============================================================

  always_comb begin

    cpl_match_o =
      cpl_valid_i &&
      completion_found;

    cpl_unexpected_o =
      cpl_valid_i &&
      !completion_found;


    matched_address_o   = '0;
    matched_length_dw_o = '0;


    if (completion_found) begin

      matched_address_o =
        address_q[completion_index];

      matched_length_dw_o =
        length_q[completion_index];

    end


    cpl_fire =
      cpl_valid_i &&
      completion_found;

  end


  // ============================================================
  // Cancellation Control
  // ============================================================

  always_comb begin

    cancel_match_o =
      cancel_valid_i &&
      cancel_found;

    cancel_fire =
      cancel_valid_i &&
      cancel_found;

  end


  // ============================================================
  // Outstanding Count
  // ============================================================

  always_comb begin

    outstanding_count_o = '0;

    for (int idx = 0; idx < NUM_ENTRIES; idx++) begin

      if (state_q[idx] == REQ_WAIT_CPL) begin

        outstanding_count_o =
          outstanding_count_o + 1'b1;

      end

    end

  end


  // ============================================================
  // Table Update
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      for (i = 0; i < NUM_ENTRIES; i = i + 1) begin

        state_q[i]   <= REQ_FREE;

        tag_q[i]     <= '0;
        address_q[i] <= '0;
        length_q[i]  <= '0;

      end

    end
    else begin

      // --------------------------------------------------------
      // Completion releases an outstanding entry
      // --------------------------------------------------------

      if (cpl_fire) begin

        state_q[completion_index]   <= REQ_FREE;

        tag_q[completion_index]     <= '0;
        address_q[completion_index] <= '0;
        length_q[completion_index]  <= '0;

      end


      // --------------------------------------------------------
      // Timeout / abort cancellation
      // --------------------------------------------------------

      if (cancel_fire) begin

        state_q[cancel_index]   <= REQ_FREE;

        tag_q[cancel_index]     <= '0;
        address_q[cancel_index] <= '0;
        length_q[cancel_index]  <= '0;

      end


      // --------------------------------------------------------
      // Allocate New Request
      // --------------------------------------------------------

      if (alloc_fire) begin

        state_q[free_index]   <= REQ_WAIT_CPL;

        tag_q[free_index]     <= alloc_tag_i;

        address_q[free_index] <= alloc_address_i;

        length_q[free_index]  <= alloc_length_dw_i;

      end

    end

  end


endmodule