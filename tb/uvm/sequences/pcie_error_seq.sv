class pcie_error_seq extends pcie_base_seq;

  `uvm_object_utils(pcie_error_seq)


  localparam logic [31:0] BAR0 =
    32'h8000_0000;


  function new(
    string name = "pcie_error_seq"
  );

    super.new(name);

  endfunction


  task body();

    logic [7:0] dma_tag;


    `uvm_info(
      get_type_name(),
      "Starting PCIe error sequence",
      UVM_MEDIUM
    )


    // Invalid BAR Read

    send_mem_read(
      32'h9000_0000,
      8'h41
    );


    repeat (10)
      @(posedge p_sequencer.vif.clk);


    // Unexpected Completion

    send_cpld(
      8'hEE,
      32'h1111_2222
    );


    repeat (5)
      @(posedge p_sequencer.vif.clk);


    // DMA + Completer Abort

    send_mem_write(
      BAR0 + 32'h00,
      32'h1000_0000
    );

    send_mem_write(
      BAR0 + 32'h04,
      32'h2000_0000
    );

    send_mem_write(
      BAR0 + 32'h08,
      32'd4
    );

    send_mem_write(
      BAR0 + 32'h0C,
      32'h1
    );


      wait_for_dma_read(
        dma_tag
      );

      // Allow the TX monitor/scoreboard to observe
      // the DMA read before returning its completion.
      @(posedge p_sequencer.vif.clk);

      send_cpl(
        dma_tag,
        CPL_STATUS_CA
      );

    repeat (20)
      @(posedge p_sequencer.vif.clk);

  endtask


endclass