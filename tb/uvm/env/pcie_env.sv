class pcie_env extends uvm_env;

  `uvm_component_utils(pcie_env)


  pcie_agent      pcie_ag;
  dma_agent       dma_ag;

  pcie_scoreboard scoreboard;
  pcie_coverage   coverage;


  function new(
    string name = "pcie_env",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  function void build_phase(
    uvm_phase phase
  );

    super.build_phase(phase);


    pcie_ag =
      pcie_agent::type_id::create(
        "pcie_ag",
        this
      );


    pcie_ag.is_active =
      UVM_ACTIVE;


    dma_ag =
      dma_agent::type_id::create(
        "dma_ag",
        this
      );


    scoreboard =
      pcie_scoreboard::type_id::create(
        "scoreboard",
        this
      );


    coverage =
      pcie_coverage::type_id::create(
        "coverage",
        this
      );

  endfunction


  function void connect_phase(
    uvm_phase phase
  );

    super.connect_phase(phase);


    pcie_ag.monitor.analysis_port.connect(
      scoreboard.pcie_imp
    );


    pcie_ag.monitor.analysis_port.connect(
      coverage.analysis_export
    );


    dma_ag.monitor.analysis_port.connect(
      scoreboard.dma_imp
    );

  endfunction


endclass