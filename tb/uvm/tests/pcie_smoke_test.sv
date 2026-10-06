class pcie_smoke_test extends pcie_base_test;

  `uvm_component_utils(pcie_smoke_test)


  function new(
    string name = "pcie_smoke_test",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  task run_phase(
    uvm_phase phase
  );

    pcie_smoke_seq seq;


    phase.raise_objection(this);


    seq =
      pcie_smoke_seq::type_id::create(
        "seq"
      );


    seq.start(
      env.pcie_ag.sequencer
    );


    repeat (20)
      @(posedge env.pcie_ag.sequencer.vif.clk);


    phase.drop_objection(this);

  endtask


endclass