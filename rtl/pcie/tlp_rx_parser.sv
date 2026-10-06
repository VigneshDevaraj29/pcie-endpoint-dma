module tlp_rx_parser
  import pcie_tlp_pkg::*;
(
  input  logic          tlp_valid_i,

  input  logic [31:0]   tlp_dw0_i,
  input  logic [31:0]   tlp_dw1_i,
  input  logic [31:0]   tlp_dw2_i,

  output logic          parsed_valid_o,
  output logic          supported_o,

  output tlp_header_t   header_o,
  output tlp_kind_e     kind_o
);


  // ============================================================
  // TLP Header Parser
  //
  // Current project scope:
  //
  //   - 3DW Memory Read
  //   - 3DW Memory Write
  //   - Completion without Data
  //   - Completion with Data
  //
  // 4DW requests and other PCIe TLP types are currently marked
  // unsupported.
  // ============================================================

  always_comb begin

    // ----------------------------------------------------------
    // Default values
    // ----------------------------------------------------------

    header_o       = '0;
    kind_o         = TLP_KIND_UNSUPPORTED;

    parsed_valid_o = tlp_valid_i;
    supported_o    = 1'b0;


    // ----------------------------------------------------------
    // Parse only when a header is valid
    // ----------------------------------------------------------

    if (tlp_valid_i) begin

      // ========================================================
      // DWORD 0
      //
      // [31:29] = Fmt
      // [28:24] = Type
      // [9:0]   = Length in DWORDs
      // ========================================================

      header_o.fmt =
        tlp_fmt_e'(tlp_dw0_i[31:29]);

      header_o.tlp_type =
        tlp_type_e'(tlp_dw0_i[28:24]);

      header_o.length_dw =
        tlp_dw0_i[9:0];


      // --------------------------------------------------------
      // Determine decoded packet type using Fmt + Type
      // --------------------------------------------------------

      kind_o = get_tlp_kind(header_o);


      // ========================================================
      // Decode fields depending on TLP type
      // ========================================================

      case (kind_o)


        // ======================================================
        // MEMORY READ / MEMORY WRITE
        // ======================================================
        //
        // DWORD 1
        //
        // [31:16] Requester ID
        // [15:8]  Tag
        // [7:4]   Last DW Byte Enable
        // [3:0]   First DW Byte Enable
        //
        // DWORD 2
        //
        // [31:2]  Address
        // [1:0]   Reserved / alignment bits for this model
        //
        // ======================================================

        TLP_KIND_MEM_RD,
        TLP_KIND_MEM_WR: begin

          header_o.requester_id =
            tlp_dw1_i[31:16];

          header_o.tag =
            tlp_dw1_i[15:8];

          header_o.last_be =
            tlp_dw1_i[7:4];

          header_o.first_be =
            tlp_dw1_i[3:0];


          // Memory requests in our initial model are
          // DWORD-aligned.
          //
          // Keep address[1:0] = 00.

          header_o.address = {
            tlp_dw2_i[31:2],
            2'b00
          };


          supported_o = 1'b1;

        end


        // ======================================================
        // COMPLETION / COMPLETION WITH DATA
        // ======================================================
        //
        // DWORD 1
        //
        // [31:16] Completer ID
        // [15:13] Completion Status
        // [12]    BCM
        // [11:0]  Byte Count
        //
        // DWORD 2
        //
        // [31:16] Requester ID
        // [15:8]  Tag
        // [7]     Reserved
        // [6:0]   Lower Address
        //
        // ======================================================

        TLP_KIND_CPL,
        TLP_KIND_CPLD: begin

          header_o.completer_id =
            tlp_dw1_i[31:16];

          header_o.cpl_status =
            cpl_status_e'(tlp_dw1_i[15:13]);

          header_o.byte_count =
            tlp_dw1_i[11:0];


          header_o.requester_id =
            tlp_dw2_i[31:16];

          header_o.tag =
            tlp_dw2_i[15:8];

          header_o.lower_address =
            tlp_dw2_i[6:0];


          supported_o = 1'b1;

        end


        // ======================================================
        // Unsupported packet
        // ======================================================

        default: begin

          supported_o = 1'b0;

        end

      endcase

    end

  end


endmodule