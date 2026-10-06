class pcie_sequencer extends
  uvm_sequencer #(pcie_seq_item);

  `uvm_component_utils(pcie_sequencer)


  virtual pcie_if vif;


  function new(
    string name = "pcie_sequencer",
    uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  function void build_phase(
    uvm_phase phase
  );

    super.build_phase(phase);


    if (!uvm_config_db#(
          virtual pcie_if
        )::get(
          this,
          "",
          "vif",
          vif
        )) begin

      `uvm_fatal(
        "NO_VIF",
        "pcie_sequencer could not get pcie_if"
      )

    end

  endfunction


endclass