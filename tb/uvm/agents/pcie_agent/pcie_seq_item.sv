class pcie_seq_item extends uvm_sequence_item;

  typedef enum bit {
    PCIE_DIR_RX = 1'b0,
    PCIE_DIR_TX = 1'b1
  } pcie_direction_e;


  rand pcie_direction_e direction;

  rand tlp_kind_e       kind;

  rand logic [9:0]      length_dw;

  rand logic [15:0]     requester_id;
  rand logic [15:0]     completer_id;

  rand logic [7:0]      tag;

  rand logic [3:0]      first_be;
  rand logic [3:0]      last_be;

  rand logic [31:0]     address;

  rand cpl_status_e     cpl_status;

  rand logic [11:0]     byte_count;
  rand logic [6:0]      lower_address;

  rand logic            payload_valid;
  rand logic [31:0]     payload_data;


  logic [31:0] dw0;
  logic [31:0] dw1;
  logic [31:0] dw2;


  constraint c_alignment {
    address[1:0] == 2'b00;
  }


  constraint c_length {
    length_dw inside {[1:16]};
  }


  constraint c_be {
    first_be != 4'b0000;
  }


  `uvm_object_utils_begin(pcie_seq_item)

    `uvm_field_enum(
      pcie_direction_e,
      direction,
      UVM_DEFAULT
    )

    `uvm_field_enum(
      tlp_kind_e,
      kind,
      UVM_DEFAULT
    )

    `uvm_field_int(length_dw, UVM_DEFAULT)

    `uvm_field_int(requester_id, UVM_DEFAULT)
    `uvm_field_int(completer_id, UVM_DEFAULT)

    `uvm_field_int(tag, UVM_DEFAULT)

    `uvm_field_int(first_be, UVM_DEFAULT)
    `uvm_field_int(last_be, UVM_DEFAULT)

    `uvm_field_int(address, UVM_DEFAULT)

    `uvm_field_enum(
      cpl_status_e,
      cpl_status,
      UVM_DEFAULT
    )

    `uvm_field_int(byte_count, UVM_DEFAULT)
    `uvm_field_int(lower_address, UVM_DEFAULT)

    `uvm_field_int(payload_valid, UVM_DEFAULT)
    `uvm_field_int(payload_data, UVM_DEFAULT)

  `uvm_object_utils_end


  function new(string name = "pcie_seq_item");

    super.new(name);

  endfunction


  function void pack_tlp();

    dw0 = '0;
    dw1 = '0;
    dw2 = '0;


    case (kind)


      TLP_KIND_MEM_RD: begin

        dw0[31:29] = TLP_FMT_3DW_NO_DATA;
        dw0[28:24] = TLP_TYPE_MEM;
        dw0[9:0]   = length_dw;

        dw1[31:16] = requester_id;
        dw1[15:8]  = tag;
        dw1[7:4]   = last_be;
        dw1[3:0]   = first_be;

        dw2[31:2]  = address[31:2];

        payload_valid = 1'b0;

      end


      TLP_KIND_MEM_WR: begin

        dw0[31:29] = TLP_FMT_3DW_DATA;
        dw0[28:24] = TLP_TYPE_MEM;
        dw0[9:0]   = length_dw;

        dw1[31:16] = requester_id;
        dw1[15:8]  = tag;
        dw1[7:4]   = last_be;
        dw1[3:0]   = first_be;

        dw2[31:2]  = address[31:2];

        payload_valid = 1'b1;

      end


      TLP_KIND_CPL: begin

        dw0[31:29] = TLP_FMT_3DW_NO_DATA;
        dw0[28:24] = TLP_TYPE_CPL;
        dw0[9:0]   = 10'd0;

        dw1[31:16] = completer_id;
        dw1[15:13] = cpl_status;
        dw1[11:0]  = byte_count;

        dw2[31:16] = requester_id;
        dw2[15:8]  = tag;
        dw2[6:0]   = lower_address;

        payload_valid = 1'b0;

      end


      TLP_KIND_CPLD: begin

        dw0[31:29] = TLP_FMT_3DW_DATA;
        dw0[28:24] = TLP_TYPE_CPL;
        dw0[9:0]   = length_dw;

        dw1[31:16] = completer_id;
        dw1[15:13] = cpl_status;
        dw1[11:0]  = byte_count;

        dw2[31:16] = requester_id;
        dw2[15:8]  = tag;
        dw2[6:0]   = lower_address;

        payload_valid = 1'b1;

      end


      default: begin

        dw0 = '0;
        dw1 = '0;
        dw2 = '0;

      end

    endcase

  endfunction


  function void decode_tlp();

    tlp_fmt_e  fmt;
    tlp_type_e tlp_type;

    fmt =
      tlp_fmt_e'(dw0[31:29]);

    tlp_type =
      tlp_type_e'(dw0[28:24]);

    length_dw =
      dw0[9:0];


    if (
      fmt == TLP_FMT_3DW_NO_DATA &&
      tlp_type == TLP_TYPE_MEM
    )
      kind = TLP_KIND_MEM_RD;

    else if (
      fmt == TLP_FMT_3DW_DATA &&
      tlp_type == TLP_TYPE_MEM
    )
      kind = TLP_KIND_MEM_WR;

    else if (
      fmt == TLP_FMT_3DW_NO_DATA &&
      tlp_type == TLP_TYPE_CPL
    )
      kind = TLP_KIND_CPL;

    else if (
      fmt == TLP_FMT_3DW_DATA &&
      tlp_type == TLP_TYPE_CPL
    )
      kind = TLP_KIND_CPLD;

    else
      kind = TLP_KIND_UNSUPPORTED;


    case (kind)

      TLP_KIND_MEM_RD,
      TLP_KIND_MEM_WR: begin

        requester_id =
          dw1[31:16];

        tag =
          dw1[15:8];

        last_be =
          dw1[7:4];

        first_be =
          dw1[3:0];

        address = {
          dw2[31:2],
          2'b00
        };

      end


      TLP_KIND_CPL,
      TLP_KIND_CPLD: begin

        completer_id =
          dw1[31:16];

        cpl_status =
          cpl_status_e'(dw1[15:13]);

        byte_count =
          dw1[11:0];

        requester_id =
          dw2[31:16];

        tag =
          dw2[15:8];

        lower_address =
          dw2[6:0];

      end

      default: begin
      end

    endcase

  endfunction


endclass