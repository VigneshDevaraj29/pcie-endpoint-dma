class pcie_monitor extends uvm_monitor;

  `uvm_component_utils(pcie_monitor)


  virtual pcie_if vif;


  uvm_analysis_port #(pcie_seq_item)
    analysis_port;


  function new(
    string name = "pcie_monitor",
    uvm_component parent = null
  );

    super.new(name, parent);

    analysis_port =
      new("analysis_port", this);

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
        "pcie_monitor could not get pcie_if"
      )

    end

  endfunction


  task run_phase(
    uvm_phase phase
  );

    pcie_seq_item item;


    wait(vif.rst_n);


    forever begin

      @(posedge vif.clk);



      // ========================================================
      // RX accepted by DUT
      // ========================================================

      if (
        vif.rx_valid &&
        vif.rx_ready
      ) begin

        item =
          pcie_seq_item::type_id::create(
            "rx_item"
          );

        item.direction =
          pcie_seq_item::PCIE_DIR_RX;

        item.dw0 =
          vif.rx_dw0;

        item.dw1 =
          vif.rx_dw1;

        item.dw2 =
          vif.rx_dw2;

        item.payload_valid =
          vif.rx_payload_valid;

        item.payload_data =
          vif.rx_payload_data;

        item.decode_tlp();
        analysis_port.write(item);

      end


      // ========================================================
      // TX accepted by external host
      // ========================================================

      if (
        vif.tx_valid &&
        vif.tx_ready
      ) begin

        item =
          pcie_seq_item::type_id::create(
            "tx_item"
          );

        item.direction =
          pcie_seq_item::PCIE_DIR_TX;

        item.dw0 =
          vif.tx_dw0;

        item.dw1 =
          vif.tx_dw1;

        item.dw2 =
          vif.tx_dw2;

        item.payload_valid =
          vif.tx_payload_valid;

        item.payload_data =
          vif.tx_payload_data;

        item.decode_tlp();
        analysis_port.write(item);

      end

    end

  endtask


endclass
