module completion_engine
  import pcie_tlp_pkg::*;
#(
  parameter int DATA_WIDTH = 32,

  // Simplified PCIe Endpoint Completer ID
  parameter logic [15:0] COMPLETER_ID = 16'h0100
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // ============================================================
  // Completion Request Input
  // ============================================================

  input  logic                      cpl_req_valid_i,
  output logic                      cpl_req_ready_o,

  input  cpl_status_e               cpl_status_i,

  input  logic                      cpl_data_valid_i,
  input  logic [DATA_WIDTH-1:0]     cpl_data_i,

  input  logic [15:0]               requester_id_i,
  input  logic [TAG_WIDTH-1:0]      tag_i,
  input  logic [6:0]                lower_addr_i,


  // ============================================================
  // Completion TLP Output
  //
  // This will later connect to tlp_tx_formatter.sv
  // ============================================================

  output logic                      tx_valid_o,
  input  logic                      tx_ready_i,

  output tlp_header_t               tx_header_o,

  output logic                      tx_payload_valid_o,
  output logic [DATA_WIDTH-1:0]     tx_payload_data_o
);


  // ============================================================
  // Internal Registers
  // ============================================================

  logic                    tx_valid_q;

  tlp_header_t             tx_header_q;

  logic                    tx_payload_valid_q;
  logic [DATA_WIDTH-1:0]   tx_payload_data_q;


  // ============================================================
  // Completion Header Construction
  // ============================================================

  tlp_header_t cpl_header_d;


  always_comb begin

    cpl_header_d = '0;


    // ----------------------------------------------------------
    // Completion Format
    // ----------------------------------------------------------

    if (cpl_data_valid_i) begin

      cpl_header_d.fmt       = TLP_FMT_3DW_DATA;
      cpl_header_d.length_dw = 10'd1;

    end
    else begin

      cpl_header_d.fmt       = TLP_FMT_3DW_NO_DATA;
      cpl_header_d.length_dw = 10'd0;

    end


    // ----------------------------------------------------------
    // Completion Type
    // ----------------------------------------------------------

    cpl_header_d.tlp_type = TLP_TYPE_CPL;


    // ----------------------------------------------------------
    // Completion Header Fields
    // ----------------------------------------------------------

    cpl_header_d.completer_id = COMPLETER_ID;

    cpl_header_d.cpl_status   = cpl_status_i;


    if (cpl_data_valid_i)
      cpl_header_d.byte_count = 12'd4;
    else
      cpl_header_d.byte_count = 12'd0;


    cpl_header_d.requester_id = requester_id_i;

    cpl_header_d.tag          = tag_i;

    cpl_header_d.lower_address = lower_addr_i;

  end


  // ============================================================
  // Input Ready
  //
  // New request can be accepted when:
  //
  //   1. Output buffer is empty
  //   OR
  //   2. Current output is being accepted
  // ============================================================

  always_comb begin

    cpl_req_ready_o =
      (!tx_valid_q) ||
      (tx_valid_q && tx_ready_i);

  end


  // ============================================================
  // Completion Output Buffer
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      tx_valid_q         <= 1'b0;

      tx_header_q        <= '0;

      tx_payload_valid_q <= 1'b0;
      tx_payload_data_q  <= '0;

    end
    else begin

      if (cpl_req_ready_o) begin

        // ------------------------------------------------------
        // Accept New Completion Request
        // ------------------------------------------------------

        if (cpl_req_valid_i) begin

          tx_valid_q         <= 1'b1;

          tx_header_q        <= cpl_header_d;

          tx_payload_valid_q <= cpl_data_valid_i;
          tx_payload_data_q  <= cpl_data_i;

        end


        // ------------------------------------------------------
        // No New Completion Request
        // ------------------------------------------------------

        else begin

          tx_valid_q         <= 1'b0;

          tx_payload_valid_q <= 1'b0;

        end

      end

    end

  end


  // ============================================================
  // Outputs
  // ============================================================

  assign tx_valid_o         = tx_valid_q;

  assign tx_header_o        = tx_header_q;

  assign tx_payload_valid_o = tx_payload_valid_q;

  assign tx_payload_data_o  = tx_payload_data_q;


endmodule