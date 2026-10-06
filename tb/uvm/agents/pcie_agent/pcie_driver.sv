class pcie_driver extends
  uvm_driver #(pcie_seq_item);

  `uvm_component_utils(pcie_driver)


  virtual pcie_if vif;


  function new(
    string name = "pcie_driver",
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
        "pcie_driver could not get pcie_if"
      )

    end

  endfunction


  task run_phase(
    uvm_phase phase
  );

    pcie_seq_item req;


    drive_idle();


    wait(vif.rst_n == 1'b1);


    forever begin

      seq_item_port.get_next_item(req);

      drive_item(req);

      seq_item_port.item_done();

    end

  endtask


  task drive_idle();

    vif.rx_valid         <= 1'b0;

    vif.rx_dw0           <= '0;
    vif.rx_dw1           <= '0;
    vif.rx_dw2           <= '0;

    vif.rx_payload_valid <= 1'b0;
    vif.rx_payload_data  <= '0;

    vif.tx_ready         <= 1'b1;

  endtask


  task drive_item(
    pcie_seq_item req
  );

    req.pack_tlp();


    @(negedge vif.clk);


    vif.rx_dw0           <= req.dw0;
    vif.rx_dw1           <= req.dw1;
    vif.rx_dw2           <= req.dw2;

    vif.rx_payload_valid <=
      req.payload_valid;

    vif.rx_payload_data <=
      req.payload_data;

    vif.rx_valid <= 1'b1;


    do begin

      @(posedge vif.clk);

    end
    while (!vif.rx_ready);


    @(negedge vif.clk);

    vif.rx_valid         <= 1'b0;
    vif.rx_payload_valid <= 1'b0;

    vif.rx_dw0           <= '0;
    vif.rx_dw1           <= '0;
    vif.rx_dw2           <= '0;

    vif.rx_payload_data  <= '0;

  endtask


endclass