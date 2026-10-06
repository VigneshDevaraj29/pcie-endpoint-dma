module tlp_tx_formatter
  import pcie_tlp_pkg::*;
#(
  parameter int DATA_WIDTH = 32
)(
  // ============================================================
  // Decoded TLP Input
  // ============================================================

  input  logic                      tx_valid_i,
  output logic                      tx_ready_o,

  input  tlp_header_t               header_i,

  input  logic                      payload_valid_i,
  input  logic [DATA_WIDTH-1:0]     payload_data_i,


  // ============================================================
  // Raw TLP Output
  //
  // Initial project supports 3DW headers.
  // ============================================================

  output logic                      tlp_valid_o,
  input  logic                      tlp_ready_i,

  output logic [31:0]               tlp_dw0_o,
  output logic [31:0]               tlp_dw1_o,
  output logic [31:0]               tlp_dw2_o,

  output logic                      tlp_payload_valid_o,
  output logic [DATA_WIDTH-1:0]     tlp_payload_data_o,

  output logic                      formatter_error_o
);


  // ============================================================
  // Internal TLP Classification
  // ============================================================

  tlp_kind_e kind;


  // ============================================================
  // TLP Classification
  // ============================================================

  always_comb begin

    kind = get_tlp_kind(header_i);

  end


  // ============================================================
  // Ready / Valid Handshake
  // ============================================================

  always_comb begin

    tx_ready_o  = tlp_ready_i;

    tlp_valid_o = tx_valid_i;

  end


  // ============================================================
  // TLP Header Formatting
  // ============================================================

  always_comb begin

    // ----------------------------------------------------------
    // Defaults
    // ----------------------------------------------------------

    tlp_dw0_o = '0;
    tlp_dw1_o = '0;
    tlp_dw2_o = '0;

    tlp_payload_valid_o = 1'b0;
    tlp_payload_data_o  = '0;

    formatter_error_o   = 1'b0;


    // ==========================================================
    // DWORD 0
    //
    // [31:29] Fmt
    // [28:24] Type
    // [23:10] Reserved / unsupported fields in this model
    // [9:0]   Length
    // ==========================================================

    tlp_dw0_o[31:29] = header_i.fmt;
    tlp_dw0_o[28:24] = header_i.tlp_type;
    tlp_dw0_o[9:0]   = header_i.length_dw;


    // ==========================================================
    // Packet-specific formatting
    // ==========================================================

    case (kind)


      // ========================================================
      // MEMORY READ
      // ========================================================

      TLP_KIND_MEM_RD: begin

        // DWORD 1
        //
        // [31:16] Requester ID
        // [15:8]  Tag
        // [7:4]   Last DW Byte Enable
        // [3:0]   First DW Byte Enable

        tlp_dw1_o[31:16] = header_i.requester_id;
        tlp_dw1_o[15:8]  = header_i.tag;
        tlp_dw1_o[7:4]   = header_i.last_be;
        tlp_dw1_o[3:0]   = header_i.first_be;


        // DWORD 2
        //
        // 32-bit DWORD-aligned address

        tlp_dw2_o[31:2] = header_i.address[31:2];
        tlp_dw2_o[1:0]  = 2'b00;


        // Memory Read has no payload.

        tlp_payload_valid_o = 1'b0;
        tlp_payload_data_o  = '0;

      end


      // ========================================================
      // MEMORY WRITE
      // ========================================================

      TLP_KIND_MEM_WR: begin

        // DWORD 1

        tlp_dw1_o[31:16] = header_i.requester_id;
        tlp_dw1_o[15:8]  = header_i.tag;
        tlp_dw1_o[7:4]   = header_i.last_be;
        tlp_dw1_o[3:0]   = header_i.first_be;


        // DWORD 2

        tlp_dw2_o[31:2] = header_i.address[31:2];
        tlp_dw2_o[1:0]  = 2'b00;


        // Memory Write carries data.

        tlp_payload_valid_o =
          tx_valid_i && payload_valid_i;

        tlp_payload_data_o =
          payload_data_i;

      end


      // ========================================================
      // COMPLETION WITHOUT DATA
      // ========================================================

      TLP_KIND_CPL: begin

        // DWORD 1
        //
        // [31:16] Completer ID
        // [15:13] Completion Status
        // [12]    BCM = 0 in this project
        // [11:0]  Byte Count

        tlp_dw1_o[31:16] = header_i.completer_id;
        tlp_dw1_o[15:13] = header_i.cpl_status;
        tlp_dw1_o[12]    = 1'b0;
        tlp_dw1_o[11:0]  = header_i.byte_count;


        // DWORD 2
        //
        // [31:16] Requester ID
        // [15:8]  Tag
        // [7]     Reserved
        // [6:0]   Lower Address

        tlp_dw2_o[31:16] = header_i.requester_id;
        tlp_dw2_o[15:8]  = header_i.tag;
        tlp_dw2_o[7]     = 1'b0;
        tlp_dw2_o[6:0]   = header_i.lower_address;


        tlp_payload_valid_o = 1'b0;
        tlp_payload_data_o  = '0;

      end


      // ========================================================
      // COMPLETION WITH DATA
      // ========================================================

      TLP_KIND_CPLD: begin

        // DWORD 1

        tlp_dw1_o[31:16] = header_i.completer_id;
        tlp_dw1_o[15:13] = header_i.cpl_status;
        tlp_dw1_o[12]    = 1'b0;
        tlp_dw1_o[11:0]  = header_i.byte_count;


        // DWORD 2

        tlp_dw2_o[31:16] = header_i.requester_id;
        tlp_dw2_o[15:8]  = header_i.tag;
        tlp_dw2_o[7]     = 1'b0;
        tlp_dw2_o[6:0]   = header_i.lower_address;


        tlp_payload_valid_o =
          tx_valid_i && payload_valid_i;

        tlp_payload_data_o =
          payload_data_i;

      end


      // ========================================================
      // Unsupported TLP
      // ========================================================

      default: begin

        formatter_error_o = tx_valid_i;

        tlp_payload_valid_o = 1'b0;
        tlp_payload_data_o  = '0;

      end

    endcase

  end


endmodule