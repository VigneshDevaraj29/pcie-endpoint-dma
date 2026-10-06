class dma_agent extends uvm_agent;

  `uvm_component_utils(dma_agent)


  dma_monitor monitor;


  function new(
    string name = "dma_agent",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  function void build_phase(
    uvm_phase phase
  );

    super.build_phase(phase);


    monitor =
      dma_monitor::type_id::create(
        "monitor",
        this
      );

  endfunction


endclass