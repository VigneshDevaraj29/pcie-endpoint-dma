package pcie_tlp_pkg;

  // ============================================================
  // Project Parameters
  // ============================================================

  parameter int ADDR_WIDTH = 32;
  parameter int DATA_WIDTH = 32;
  parameter int TAG_WIDTH  = 8;


  // ============================================================
  // PCIe TLP Format (Fmt)
  // ============================================================
  //
  // 000 = 3DW header, no data
  // 001 = 4DW header, no data
  // 010 = 3DW header, with data
  // 011 = 4DW header, with data
  //
  // Initially our project will support 3DW headers.
  // ============================================================

  typedef enum logic [2:0] {

    TLP_FMT_3DW_NO_DATA = 3'b000,
    TLP_FMT_4DW_NO_DATA = 3'b001,
    TLP_FMT_3DW_DATA    = 3'b010,
    TLP_FMT_4DW_DATA    = 3'b011

  } tlp_fmt_e;


  // ============================================================
  // PCIe TLP Type
  // ============================================================

  typedef enum logic [4:0] {

    TLP_TYPE_MEM = 5'b00000,
    TLP_TYPE_CPL = 5'b01010

  } tlp_type_e;


  // ============================================================
  // Internal decoded TLP classification
  //
  // This is OUR internal representation.
  // It is not an actual PCIe header field.
  // ============================================================

  typedef enum logic [2:0] {

    TLP_KIND_MEM_RD,
    TLP_KIND_MEM_WR,
    TLP_KIND_CPL,
    TLP_KIND_CPLD,
    TLP_KIND_UNSUPPORTED

  } tlp_kind_e;


  // ============================================================
  // Completion Status
  // ============================================================

  typedef enum logic [2:0] {

    CPL_STATUS_SC  = 3'b000,   // Successful Completion
    CPL_STATUS_UR  = 3'b001,   // Unsupported Request
    CPL_STATUS_CRS = 3'b010,   // Configuration Request Retry
    CPL_STATUS_CA  = 3'b100    // Completer Abort

  } cpl_status_e;


  // ============================================================
  // Decoded TLP Header Structure
  // ============================================================

  typedef struct packed {

    // Common fields
    tlp_fmt_e              fmt;
    tlp_type_e             tlp_type;
    logic [9:0]            length_dw;


    // Memory Request fields
    logic [15:0]           requester_id;
    logic [TAG_WIDTH-1:0]  tag;

    logic [3:0]            last_be;
    logic [3:0]            first_be;

    logic [ADDR_WIDTH-1:0] address;


    // Completion-specific fields
    logic [15:0]           completer_id;
    cpl_status_e           cpl_status;

    logic [11:0]           byte_count;
    logic [6:0]            lower_address;

  } tlp_header_t;


  // ============================================================
  // Determine the TLP type using Fmt + Type
  // ============================================================

  function automatic tlp_kind_e get_tlp_kind(
    input tlp_header_t hdr
  );

    case ({hdr.fmt, hdr.tlp_type})

      {TLP_FMT_3DW_NO_DATA, TLP_TYPE_MEM}:
        return TLP_KIND_MEM_RD;

      {TLP_FMT_3DW_DATA, TLP_TYPE_MEM}:
        return TLP_KIND_MEM_WR;

      {TLP_FMT_3DW_NO_DATA, TLP_TYPE_CPL}:
        return TLP_KIND_CPL;

      {TLP_FMT_3DW_DATA, TLP_TYPE_CPL}:
        return TLP_KIND_CPLD;

      default:
        return TLP_KIND_UNSUPPORTED;

    endcase

  endfunction


  // ============================================================
  // Check whether transaction is posted
  //
  // MemWr = Posted
  // No completion expected
  // ============================================================

  function automatic logic is_posted(
    input tlp_header_t hdr
  );

    return (get_tlp_kind(hdr) == TLP_KIND_MEM_WR);

  endfunction


  // ============================================================
  // Check whether transaction needs a completion
  //
  // MemRd = Non-Posted
  // Completion expected
  // ============================================================

  function automatic logic needs_completion(
    input tlp_header_t hdr
  );

    return (get_tlp_kind(hdr) == TLP_KIND_MEM_RD);

  endfunction


endpackage