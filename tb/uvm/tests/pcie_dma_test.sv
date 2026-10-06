class pcie_dma_test extends pcie_base_test;

  `uvm_component_utils(pcie_dma_test)


  function new(
    string name = "pcie_dma_test",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  task run_phase(
    uvm_phase phase
  );

    pcie_dma_seq seq;


    phase.raise_objection(this);


    seq =
      pcie_dma_seq::type_id::create(
        "seq"
      );


    seq.start(
      env.pcie_ag.sequencer
    );


    repeat (30)
      @(posedge env.pcie_ag.sequencer.vif.clk);


    phase.drop_objection(this);

  endtask


endclass