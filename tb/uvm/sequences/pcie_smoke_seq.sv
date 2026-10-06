class pcie_smoke_seq extends pcie_base_seq;

  `uvm_object_utils(pcie_smoke_seq)


  localparam logic [31:0] BAR0 =
    32'h8000_0000;


  function new(
    string name = "pcie_smoke_seq"
  );

    super.new(name);

  endfunction


  task body();

    `uvm_info(
      get_type_name(),
      "Starting PCIe smoke sequence",
      UVM_MEDIUM
    )


   send_mem_write(
  BAR0 + 32'h104,
  32'hA5A5_5A5A,
  4'h3
);

    repeat (5)
      @(posedge p_sequencer.vif.clk);


    send_mem_read(
      BAR0 + 32'h100,
      8'h22
    );


    repeat (10)
      @(posedge p_sequencer.vif.clk);


    send_mem_read(
      32'h9000_0000,
      8'h33
    );


    repeat (10)
      @(posedge p_sequencer.vif.clk);

  endtask


endclass