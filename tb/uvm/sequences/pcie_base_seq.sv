class pcie_base_seq extends
  uvm_sequence #(pcie_seq_item);

  `uvm_object_utils(pcie_base_seq)

  `uvm_declare_p_sequencer(pcie_sequencer)


  localparam logic [15:0] HOST_ID =
    16'hBEEF;


  function new(
    string name = "pcie_base_seq"
  );

    super.new(name);

  endfunction


  task send_mem_write(
    logic [31:0] addr,
    logic [31:0] data,
    logic [3:0]  be = 4'hF
  );

    pcie_seq_item req;


    req =
      pcie_seq_item::type_id::create(
        "mem_write_req"
      );


    start_item(req);


    req.kind =
      TLP_KIND_MEM_WR;

    req.length_dw =
      10'd1;

    req.requester_id =
      HOST_ID;

    req.tag =
      8'h00;

    req.first_be =
      be;

    req.last_be =
      4'h0;

    req.address =
      addr;

    req.payload_valid =
      1'b1;

    req.payload_data =
      data;


    finish_item(req);

  endtask


  task send_mem_read(
    logic [31:0] addr,
    logic [7:0]  tag
  );

    pcie_seq_item req;


    req =
      pcie_seq_item::type_id::create(
        "mem_read_req"
      );


    start_item(req);


    req.kind =
      TLP_KIND_MEM_RD;

    req.length_dw =
      10'd1;

    req.requester_id =
      HOST_ID;

    req.tag =
      tag;

    req.first_be =
      4'hF;

    req.last_be =
      4'h0;

    req.address =
      addr;

    req.payload_valid =
      1'b0;


    finish_item(req);

  endtask


  task send_cpld(
    logic [7:0]      tag,
    logic [31:0]     data,
    cpl_status_e     status = CPL_STATUS_SC
  );

    pcie_seq_item req;


    req =
      pcie_seq_item::type_id::create(
        "cpld_req"
      );


    start_item(req);


    req.kind =
      TLP_KIND_CPLD;

    req.length_dw =
      10'd1;

    req.completer_id =
      16'hCAFE;

    req.cpl_status =
      status;

    req.byte_count =
      12'd4;

    req.requester_id =
      16'h0100;

    req.tag =
      tag;

    req.lower_address =
      7'h00;

    req.payload_valid =
      1'b1;

    req.payload_data =
      data;


    finish_item(req);

  endtask


  task send_cpl(
    logic [7:0]  tag,
    cpl_status_e status
  );

    pcie_seq_item req;


    req =
      pcie_seq_item::type_id::create(
        "cpl_req"
      );


    start_item(req);


    req.kind =
      TLP_KIND_CPL;

    req.completer_id =
      16'hCAFE;

    req.cpl_status =
      status;

    req.byte_count =
      12'd0;

    req.requester_id =
      16'h0100;

    req.tag =
      tag;

    req.lower_address =
      7'h00;

    req.payload_valid =
      1'b0;


    finish_item(req);

  endtask


  task wait_for_dma_read(
    output logic [7:0] tag
  );

    tag = '0;


    forever begin

      @(posedge p_sequencer.vif.clk);

      #1step;


      if (
        p_sequencer.vif.tx_valid &&
        p_sequencer.vif.tx_ready &&
        p_sequencer.vif.tx_dw0[31:29] ==
          TLP_FMT_3DW_NO_DATA &&
        p_sequencer.vif.tx_dw0[28:24] ==
          TLP_TYPE_MEM
      ) begin

        tag =
          p_sequencer.vif.tx_dw1[15:8];

        break;

      end

    end

  endtask


endclass