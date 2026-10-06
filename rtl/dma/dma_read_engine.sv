module dma_read_engine
  import pcie_tlp_pkg::*;
#(
  parameter int ADDR_WIDTH = 32,

  parameter logic [15:0] REQUESTER_ID = 16'h0100,

  parameter int COMPLETION_TIMEOUT_CYCLES = 1024
)(
  input  logic                     clk,
  input  logic                     rst_n,


  // ============================================================
  // DMA Read Command
  // ============================================================

  input  logic                     cmd_valid_i,
  output logic                     cmd_ready_o,

  input  logic [ADDR_WIDTH-1:0]    cmd_address_i,


  // ============================================================
  // Outstanding Request Table Allocation
  // ============================================================

  output logic                     alloc_valid_o,
  input  logic                     alloc_ready_i,

  input  logic                     alloc_duplicate_i,

  output logic [TAG_WIDTH-1:0]     alloc_tag_o,
  output logic [ADDR_WIDTH-1:0]    alloc_address_o,
  output logic [9:0]               alloc_length_dw_o,


  // ============================================================
  // Timeout Cancellation
  //
  // Will later be connected to the outstanding table.
  // ============================================================

  output logic                     cancel_valid_o,
  output logic [TAG_WIDTH-1:0]     cancel_tag_o,


  // ============================================================
  // PCIe Memory Read Request Output
  // ============================================================

  output logic                     tx_valid_o,
  input  logic                     tx_ready_i,

  output tlp_header_t              tx_header_o,

  output logic                     tx_payload_valid_o,
  output logic [31:0]              tx_payload_data_o,


  // ============================================================
  // Incoming Completion
  // ============================================================

  input  logic                     cpl_valid_i,

  input  tlp_header_t              cpl_header_i,

  input  logic                     cpl_payload_valid_i,
  input  logic [31:0]              cpl_payload_data_i,


  // ============================================================
  // DMA Read Result
  // ============================================================

  output logic                     read_done_o,
  output logic                     read_error_o,

  output logic [31:0]              read_data_o,

  output logic                     busy_o
);


  // ============================================================
  // State Machine
  // ============================================================

  typedef enum logic [2:0] {

    ST_IDLE,
    ST_ALLOCATE,
    ST_SEND,
    ST_WAIT_CPL,
    ST_DONE,
    ST_ERROR

  } state_e;


  state_e state_q;
  state_e state_d;


  // ============================================================
  // Internal Registers
  // ============================================================

  logic [ADDR_WIDTH-1:0] address_q;

  logic [TAG_WIDTH-1:0] next_tag_q;
  logic [TAG_WIDTH-1:0] active_tag_q;

  logic [31:0] read_data_q;


  // ============================================================
  // Timeout Signals
  // ============================================================

  logic timeout_start;
  logic timeout_clear;

  logic timeout_active;
  logic timeout_hit;

  logic [$clog2(COMPLETION_TIMEOUT_CYCLES+1)-1:0]
        timeout_count;


  // ============================================================
  // Completion Decode
  // ============================================================

  tlp_kind_e completion_kind;

  logic matching_completion;


  always_comb begin

    completion_kind =
      get_tlp_kind(cpl_header_i);


    matching_completion =
      cpl_valid_i &&
      (cpl_header_i.tag == active_tag_q) &&
      (
        (completion_kind == TLP_KIND_CPL) ||
        (completion_kind == TLP_KIND_CPLD)
      );

  end


  // ============================================================
  // Timeout Counter
  // ============================================================

  timeout_counter #(
    .TIMEOUT_CYCLES(COMPLETION_TIMEOUT_CYCLES)
  ) u_timeout_counter (
    .clk      (clk),
    .rst_n    (rst_n),

    .start_i  (timeout_start),
    .clear_i  (timeout_clear),

    .active_o (timeout_active),
    .timeout_o(timeout_hit),

    .count_o  (timeout_count)
  );


  // ============================================================
  // Sequential Registers
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state_q      <= ST_IDLE;

      address_q    <= '0;

      next_tag_q   <= '0;
      active_tag_q <= '0;

      read_data_q  <= '0;

    end
    else begin

      state_q <= state_d;


      // --------------------------------------------------------
      // Accept Read Command
      // --------------------------------------------------------

      if (state_q == ST_IDLE &&
          cmd_valid_i &&
          cmd_ready_o) begin

        address_q <= cmd_address_i;

      end


      // --------------------------------------------------------
      // Duplicate Tag
      // --------------------------------------------------------

      if (state_q == ST_ALLOCATE &&
          alloc_valid_o &&
          alloc_duplicate_i) begin

        next_tag_q <= next_tag_q + 1'b1;

      end


      // --------------------------------------------------------
      // Successful Tag Allocation
      // --------------------------------------------------------

      if (state_q == ST_ALLOCATE &&
          alloc_valid_o &&
          alloc_ready_i) begin

        active_tag_q <= next_tag_q;

        next_tag_q <= next_tag_q + 1'b1;

      end


      // --------------------------------------------------------
      // Successful Completion
      // --------------------------------------------------------

      if (state_q == ST_WAIT_CPL &&
          matching_completion &&
          cpl_header_i.cpl_status == CPL_STATUS_SC &&
          cpl_payload_valid_i) begin

        read_data_q <= cpl_payload_data_i;

      end

    end

  end


  // ============================================================
  // Main Control Logic
  // ============================================================

  always_comb begin

    state_d = state_q;


    // ----------------------------------------------------------
    // Defaults
    // ----------------------------------------------------------

    cmd_ready_o = 1'b0;

    busy_o       = 1'b1;

    read_done_o  = 1'b0;
    read_error_o = 1'b0;


    alloc_valid_o     = 1'b0;
    alloc_tag_o       = next_tag_q;
    alloc_address_o   = address_q;
    alloc_length_dw_o = 10'd1;


    cancel_valid_o = 1'b0;
    cancel_tag_o   = active_tag_q;


    tx_valid_o = 1'b0;

    tx_header_o = '0;

    tx_payload_valid_o = 1'b0;
    tx_payload_data_o  = '0;


    timeout_start = 1'b0;
    timeout_clear = 1'b0;


    // ==========================================================
    // State Machine
    // ==========================================================

    case (state_q)


      // ========================================================
      // IDLE
      // ========================================================

      ST_IDLE: begin

        cmd_ready_o = 1'b1;
        busy_o      = 1'b0;

        timeout_clear = 1'b1;


        if (cmd_valid_i)
          state_d = ST_ALLOCATE;

      end


      // ========================================================
      // ALLOCATE OUTSTANDING REQUEST ENTRY
      // ========================================================

      ST_ALLOCATE: begin

        alloc_valid_o     = 1'b1;
        alloc_tag_o       = next_tag_q;

        alloc_address_o   = address_q;
        alloc_length_dw_o = 10'd1;


        if (alloc_ready_i)
          state_d = ST_SEND;

      end


      // ========================================================
      // SEND PCIe MEMORY READ
      // ========================================================

      ST_SEND: begin

        tx_valid_o = 1'b1;


        tx_header_o.fmt =
          TLP_FMT_3DW_NO_DATA;

        tx_header_o.tlp_type =
          TLP_TYPE_MEM;

        tx_header_o.length_dw =
          10'd1;

        tx_header_o.requester_id =
          REQUESTER_ID;

        tx_header_o.tag =
          active_tag_q;

        tx_header_o.first_be =
          4'b1111;

        tx_header_o.last_be =
          4'b0000;

        tx_header_o.address =
          address_q;


        if (tx_ready_i) begin

          timeout_start = 1'b1;

          state_d = ST_WAIT_CPL;

        end

      end


      // ========================================================
      // WAIT FOR COMPLETION
      // ========================================================

      ST_WAIT_CPL: begin


        if (matching_completion) begin

          timeout_clear = 1'b1;


          if ((cpl_header_i.cpl_status ==
               CPL_STATUS_SC) &&
              cpl_payload_valid_i) begin

            state_d = ST_DONE;

          end
          else begin

            state_d = ST_ERROR;

          end

        end


        else if (timeout_hit) begin

          state_d = ST_ERROR;

        end

      end


      // ========================================================
      // DONE
      // ========================================================

      ST_DONE: begin

        busy_o      = 1'b0;
        read_done_o = 1'b1;

        timeout_clear = 1'b1;

        state_d = ST_IDLE;

      end


      // ========================================================
      // ERROR
      // ========================================================

      ST_ERROR: begin

        busy_o       = 1'b0;
        read_error_o = 1'b1;

        timeout_clear = 1'b1;


        // Remove stale outstanding request entry.
        cancel_valid_o = 1'b1;
        cancel_tag_o   = active_tag_q;


        state_d = ST_IDLE;

      end


      default: begin

        state_d = ST_IDLE;

      end

    endcase

  end


  // ============================================================
  // Output Data
  // ============================================================

  assign read_data_o = read_data_q;


endmodule