class pcie_dma_seq extends pcie_base_seq;

  `uvm_object_utils(pcie_dma_seq)

  localparam logic [31:0] BAR0 =
    32'h8000_0000;


  function new(
    string name = "pcie_dma_seq"
  );
    super.new(name);
  endfunction


  task body();

    logic [7:0] dma_tag;


    `uvm_info(
      get_type_name(),
      "Starting PCIe DMA sequence",
      UVM_MEDIUM
    )


    // ============================================================
    // Register toggle stimulus
    //
    // Exercise SRC/DST/LENGTH register bits in both directions.
    // Do NOT start DMA yet.
    // ============================================================

    send_mem_write(
      BAR0 + 32'h00,
      32'hAAAA_AAA8
    );

    send_mem_write(
      BAR0 + 32'h04,
      32'h5555_5554
    );

    send_mem_write(
      BAR0 + 32'h08,
      32'hAAAA_AAA8
    );


    send_mem_write(
      BAR0 + 32'h00,
      32'h5555_5554
    );

    send_mem_write(
      BAR0 + 32'h04,
      32'hAAAA_AAA8
    );

    send_mem_write(
      BAR0 + 32'h08,
      32'h5555_5554
    );


    // ============================================================
    // Restore normal DMA configuration
    // ============================================================

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


    // ============================================================
    // Start DMA
    // ============================================================

    send_mem_write(
      BAR0 + 32'h0C,
      32'h1
    );


    wait_for_dma_read(
      dma_tag
    );


    repeat (3)
      @(posedge p_sequencer.vif.clk);


    send_cpld(
      dma_tag,
      32'hCAFE_BABE
    );


    repeat (30)
      @(posedge p_sequencer.vif.clk);

  endtask


endclass