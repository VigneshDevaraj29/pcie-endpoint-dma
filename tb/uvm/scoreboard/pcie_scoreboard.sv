`uvm_analysis_imp_decl(_pcie)
`uvm_analysis_imp_decl(_dma)


class pcie_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(pcie_scoreboard)


  localparam logic [31:0] BAR0 =
    32'h8000_0000;

  localparam logic [31:0] MEM_BASE =
    BAR0 + 32'h100;


  uvm_analysis_imp_pcie #(
    pcie_seq_item,
    pcie_scoreboard
  ) pcie_imp;


  uvm_analysis_imp_dma #(
    dma_status_item,
    pcie_scoreboard
  ) dma_imp;


  bit [31:0] memory_model [bit [31:0]];


  bit [31:0] expected_cpl_data [bit [7:0]];

  bit        expected_ur [bit [7:0]];


  bit [31:0] dma_src;
  bit [31:0] dma_dst;
  bit [31:0] dma_length;

  bit        dma_active;
  bit        dma_waiting_cpl;
  bit        dma_expect_write;

  bit [7:0]  dma_tag;

  bit [31:0] dma_data;


  int unsigned error_count;


  function new(
    string name = "pcie_scoreboard",
    uvm_component parent = null
  );

    super.new(name, parent);

    pcie_imp =
      new("pcie_imp", this);

    dma_imp =
      new("dma_imp", this);

  endfunction


  function void write_pcie(
    pcie_seq_item item
  );

    if (
      item.direction ==
      pcie_seq_item::PCIE_DIR_RX
    )
      process_rx(item);

    else
      process_tx(item);

  endfunction


  function void process_rx(
    pcie_seq_item item
  );

    // Host Memory Write

    if (item.kind == TLP_KIND_MEM_WR) begin


      // DMA SRC

      if (item.address == BAR0 + 32'h00)
        dma_src = item.payload_data;


      // DMA DST

      else if (item.address == BAR0 + 32'h04)
        dma_dst = item.payload_data;


      // DMA LENGTH

      else if (item.address == BAR0 + 32'h08)
        dma_length = item.payload_data;


      // DMA CONTROL.START

      else if (
        item.address ==
        BAR0 + 32'h0C &&
        item.payload_data[0]
      ) begin

        dma_active       = 1'b1;
        dma_waiting_cpl  = 1'b0;
        dma_expect_write = 1'b0;

      end


      // Endpoint memory

      else if (item.address >= MEM_BASE) begin

        memory_model[item.address] =
          item.payload_data;

      end

    end


    // Host Memory Read

    else if (item.kind == TLP_KIND_MEM_RD) begin

      if (memory_model.exists(item.address)) begin

        expected_cpl_data[item.tag] =
          memory_model[item.address];

      end

      else if (
        item.address < BAR0 ||
        item.address >= BAR0 + 4096
      ) begin

        expected_ur[item.tag] =
          1'b1;

      end

    end

      // Completion to DMA

      else if (
        (item.kind == TLP_KIND_CPLD ||
         item.kind == TLP_KIND_CPL) &&
        dma_waiting_cpl &&
        item.tag == dma_tag
      ) begin

        if (
          item.kind == TLP_KIND_CPLD &&
          item.cpl_status == CPL_STATUS_SC
        ) begin

          dma_data =
            item.payload_data;

          dma_waiting_cpl =
            1'b0;

          dma_expect_write =
            1'b1;

        end

        else if (
          item.cpl_status != CPL_STATUS_SC
        ) begin

          dma_waiting_cpl =
            1'b0;

          dma_expect_write =
            1'b0;

          dma_active =
            1'b0;

        end

      end

  endfunction


  function void process_tx(
    pcie_seq_item item
  );

    // Endpoint completion

    if (item.kind == TLP_KIND_CPLD) begin

      if (
        expected_cpl_data.exists(
          item.tag
        )
      ) begin

        if (
          item.payload_data !==
          expected_cpl_data[item.tag]
        ) begin

          `uvm_error(
            "SB_CPLD",
            $sformatf(
              "Completion data mismatch tag=%0h exp=%08h got=%08h",
              item.tag,
              expected_cpl_data[item.tag],
              item.payload_data
            )
          )

          error_count++;

        end


        expected_cpl_data.delete(
          item.tag
        );

      end

    end


    else if (item.kind == TLP_KIND_CPL) begin

      if (
        expected_ur.exists(item.tag)
      ) begin

        if (
          item.cpl_status !=
          CPL_STATUS_UR
        ) begin

          `uvm_error(
            "SB_UR",
            "Expected UR completion"
          )

          error_count++;

        end


        expected_ur.delete(
          item.tag
        );

      end

    end


    // DMA Memory Read

    else if (
      item.kind == TLP_KIND_MEM_RD &&
      dma_active
    ) begin

      if (item.address != dma_src) begin

        `uvm_error(
          "SB_DMA_RD",
          $sformatf(
            "DMA source mismatch exp=%08h got=%08h",
            dma_src,
            item.address
          )
        )

        error_count++;

      end


      dma_tag =
        item.tag;

      dma_waiting_cpl =
        1'b1;

    end


    // DMA Memory Write

    else if (
      item.kind == TLP_KIND_MEM_WR &&
      dma_expect_write
    ) begin

      if (
        item.address != dma_dst
      ) begin

        `uvm_error(
          "SB_DMA_WR_ADDR",
          $sformatf(
            "DMA destination mismatch exp=%08h got=%08h",
            dma_dst,
            item.address
          )
        )

        error_count++;

      end


      if (
        item.payload_data !=
        dma_data
      ) begin

        `uvm_error(
          "SB_DMA_WR_DATA",
          $sformatf(
            "DMA data mismatch exp=%08h got=%08h",
            dma_data,
            item.payload_data
          )
        )

        error_count++;

      end


      dma_expect_write =
        1'b0;

      dma_active =
        1'b0;

    end

  endfunction


  function void write_dma(
    dma_status_item item
  );

    if (item.tx_formatter_error) begin

      `uvm_error(
        "SB_FORMATTER",
        "TX formatter error detected"
      )

      error_count++;

    end

  endfunction


    function void report_phase(
    uvm_phase phase
  );

    super.report_phase(phase);


    if (expected_cpl_data.num() != 0) begin

      `uvm_error(
        "SCOREBOARD",
        $sformatf(
          "Pending expected completions = %0d",
          expected_cpl_data.num()
        )
      )

      error_count++;

    end


    if (expected_ur.num() != 0) begin

      `uvm_error(
        "SCOREBOARD",
        $sformatf(
          "Pending expected UR completions = %0d",
          expected_ur.num()
        )
      )

      error_count++;

    end


    if (
      dma_active ||
      dma_waiting_cpl ||
      dma_expect_write
    ) begin

      `uvm_error(
        "SCOREBOARD",
        $sformatf(
          "DMA scoreboard state incomplete: active=%0b waiting_cpl=%0b expect_write=%0b",
          dma_active,
          dma_waiting_cpl,
          dma_expect_write
        )
      )

      error_count++;

    end


    if (error_count == 0) begin

      `uvm_info(
        "SCOREBOARD",
        "PCIe scoreboard completed with no errors",
        UVM_LOW
      )

    end

    else begin

      `uvm_error(
        "SCOREBOARD",
        $sformatf(
          "Scoreboard errors = %0d",
          error_count
        )
      )

    end

  endfunction


endclass