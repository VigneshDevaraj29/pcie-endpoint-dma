class dma_monitor extends uvm_monitor;

  `uvm_component_utils(dma_monitor)


  virtual dma_status_if vif;


  uvm_analysis_port #(dma_status_item)
    analysis_port;


  function new(
    string name = "dma_monitor",
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
          virtual dma_status_if
        )::get(
          this,
          "",
          "vif",
          vif
        )) begin

      `uvm_fatal(
        "NO_VIF",
        "dma_monitor could not get dma_status_if"
      )

    end

  endfunction


  task run_phase(
    uvm_phase phase
  );

    dma_status_item item;


    wait(vif.rst_n);


    forever begin

      @(posedge vif.clk);

      #1step;


      item =
        dma_status_item::type_id::create(
          "dma_status"
        );


      item.dma_busy =
        vif.dma_busy;

      item.dma_done =
        vif.dma_done;

      item.dma_error =
        vif.dma_error;

      item.unexpected_completion =
        vif.unexpected_completion;

      item.outstanding_count =
        vif.outstanding_count;

      item.tx_formatter_error =
        vif.tx_formatter_error;


      analysis_port.write(item);

    end

  endtask


endclass