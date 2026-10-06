`timescale 1ns/1ps

module pcie_dma_integration_tb;

  import pcie_tlp_pkg::*;


  // ============================================================
  // Parameters
  // ============================================================

  localparam logic [31:0] BAR0_BASE_ADDR =
    32'h8000_0000;

  localparam logic [15:0] HOST_REQUESTER_ID =
    16'hBEEF;

  localparam logic [31:0] DMA_SOURCE_ADDR =
    32'h1000_0000;

  localparam logic [31:0] DMA_DEST_ADDR =
    32'h2000_0000;

  localparam logic [31:0] DMA_TEST_DATA =
    32'hCAFE_BABE;


  // ============================================================
  // Clock / Reset
  // ============================================================

  logic clk;
  logic rst_n;


  // ============================================================
  // PCIe RX
  // ============================================================

  logic        rx_valid;
  logic        rx_ready;

  logic [31:0] rx_dw0;
  logic [31:0] rx_dw1;
  logic [31:0] rx_dw2;

  logic        rx_payload_valid;
  logic [31:0] rx_payload_data;


  // ============================================================
  // PCIe TX
  // ============================================================

  logic        tx_valid;
  logic        tx_ready;

  logic [31:0] tx_dw0;
  logic [31:0] tx_dw1;
  logic [31:0] tx_dw2;

  logic        tx_payload_valid;
  logic [31:0] tx_payload_data;


  // ============================================================
  // DUT Status
  // ============================================================

  logic dma_busy;
  logic dma_done;
  logic dma_error;

  logic unexpected_completion;

  logic [4:0] outstanding_count;

  logic tx_formatter_error;


  // ============================================================
  // Test Variables
  // ============================================================

  int error_count;

  logic [7:0] captured_dma_read_tag;


  // ============================================================
  // DUT
  // ============================================================

  pcie_endpoint_dma_top dut (
    .clk                     (clk),
    .rst_n                   (rst_n),

    .rx_valid_i              (rx_valid),
    .rx_ready_o              (rx_ready),

    .rx_dw0_i                (rx_dw0),
    .rx_dw1_i                (rx_dw1),
    .rx_dw2_i                (rx_dw2),

    .rx_payload_valid_i      (rx_payload_valid),
    .rx_payload_data_i       (rx_payload_data),

    .tx_valid_o              (tx_valid),
    .tx_ready_i              (tx_ready),

    .tx_dw0_o                (tx_dw0),
    .tx_dw1_o                (tx_dw1),
    .tx_dw2_o                (tx_dw2),

    .tx_payload_valid_o      (tx_payload_valid),
    .tx_payload_data_o       (tx_payload_data),

    .dma_busy_o              (dma_busy),
    .dma_done_o              (dma_done),
    .dma_error_o             (dma_error),

    .unexpected_completion_o (unexpected_completion),

    .outstanding_count_o     (outstanding_count),

    .tx_formatter_error_o    (tx_formatter_error)
  );


  // ============================================================
  // Clock
  // ============================================================

  initial begin

    clk = 1'b0;

    forever #5 clk = ~clk;

  end


  // ============================================================
  // Clear PCIe RX
  // ============================================================

  task automatic clear_rx();

    rx_valid         = 1'b0;

    rx_dw0           = '0;
    rx_dw1           = '0;
    rx_dw2           = '0;

    rx_payload_valid = 1'b0;
    rx_payload_data  = '0;

  endtask


  // ============================================================
  // Reset
  // ============================================================

  task automatic reset_dut();

    rst_n = 1'b0;

    clear_rx();

    tx_ready = 1'b1;

    repeat (5)
      @(posedge clk);

    rst_n = 1'b1;

    repeat (2)
      @(posedge clk);

  endtask


  // ============================================================
  // Host -> Endpoint Memory Write
  //
  // Used to configure DMA registers.
  // ============================================================

  task automatic send_mem_write(
    input logic [31:0] address,
    input logic [31:0] data
  );

    @(negedge clk);


    rx_dw0 = '0;

    rx_dw0[31:29] =
      TLP_FMT_3DW_DATA;

    rx_dw0[28:24] =
      TLP_TYPE_MEM;

    rx_dw0[9:0] =
      10'd1;


    rx_dw1 = '0;

    rx_dw1[31:16] =
      HOST_REQUESTER_ID;

    rx_dw1[15:8] =
      8'h00;

    rx_dw1[7:4] =
      4'b0000;

    rx_dw1[3:0] =
      4'b1111;


    rx_dw2 =
      address;


    rx_payload_valid =
      1'b1;

    rx_payload_data =
      data;

    rx_valid =
      1'b1;


    do begin
      @(posedge clk);
    end while (!rx_ready);

    #1ps;
    clear_rx();

  endtask

      // ============================================================
    // Host -> Endpoint Memory Read
    // ============================================================

    task automatic send_mem_read(
      input logic [31:0] address,
      input logic [7:0]  tag
    );

      @(negedge clk);

      rx_dw0 = '0;

      rx_dw0[31:29] =
        TLP_FMT_3DW_NO_DATA;

      rx_dw0[28:24] =
        TLP_TYPE_MEM;

      rx_dw0[9:0] =
        10'd1;


      rx_dw1 = '0;

      rx_dw1[31:16] =
        HOST_REQUESTER_ID;

      rx_dw1[15:8] =
        tag;

      rx_dw1[7:4] =
        4'b0000;

      rx_dw1[3:0] =
        4'b1111;


      rx_dw2 =
        address;


      rx_payload_valid =
        1'b0;

      rx_payload_data =
        '0;

      rx_valid =
        1'b1;


      do begin
        @(posedge clk);
      end while (!rx_ready);

      #1ps;

      clear_rx();

    endtask

  // ============================================================
  // Send Completion With Data
  //
  // Emulates the remote PCIe completer responding to the
  // endpoint DMA Memory Read.
  // ============================================================

  task automatic send_cpld(
    input logic [7:0]  tag,
    input logic [31:0] data
  );

    @(negedge clk);


    // ----------------------------------------------------------
    // DW0
    // ----------------------------------------------------------

    rx_dw0 = '0;

    rx_dw0[31:29] =
      TLP_FMT_3DW_DATA;

    rx_dw0[28:24] =
      TLP_TYPE_CPL;

    rx_dw0[9:0] =
      10'd1;


    // ----------------------------------------------------------
    // DW1
    // ----------------------------------------------------------

    rx_dw1 = '0;

    rx_dw1[31:16] =
      16'hCAFE;

    rx_dw1[15:13] =
      CPL_STATUS_SC;

    rx_dw1[11:0] =
      12'd4;


    // ----------------------------------------------------------
    // DW2
    // ----------------------------------------------------------

    rx_dw2 = '0;

    rx_dw2[31:16] =
      16'h0100;

    rx_dw2[15:8] =
      tag;

    rx_dw2[6:0] =
      7'h00;


    // ----------------------------------------------------------
    // Payload
    // ----------------------------------------------------------

    rx_payload_valid =
      1'b1;

    rx_payload_data =
      data;

    rx_valid =
      1'b1;


    do begin
      @(posedge clk);
    end while (!rx_ready);

    #1ps;
    clear_rx();

  endtask


  // ============================================================
  // Wait For DMA Memory Read TLP
  // ============================================================

  task automatic wait_for_dma_read();

    bit found;

    found = 1'b0;


    for (int cycle = 0;
         cycle < 100;
         cycle++) begin

      @(negedge clk);

      if (
        tx_valid &&
        tx_ready &&
        tx_dw0[31:29] ==
          TLP_FMT_3DW_NO_DATA &&
        tx_dw0[28:24] ==
          TLP_TYPE_MEM
      ) begin

        found = 1'b1;


        captured_dma_read_tag =
          tx_dw1[15:8];


        if (tx_dw2 !== DMA_SOURCE_ADDR) begin

          $error(
            "DMA MemRd address mismatch expected=%h got=%h",
            DMA_SOURCE_ADDR,
            tx_dw2
          );

          error_count++;

        end


        if (tx_dw0[9:0] != 10'd1) begin

          $error(
            "DMA MemRd length should be 1 DW"
          );

          error_count++;

        end


        break;

      end

    end


    if (!found) begin

      $error(
        "DMA Memory Read TLP not generated"
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Wait For DMA Memory Write TLP
  // ============================================================

  task automatic wait_for_dma_write();

    bit found;

    found = 1'b0;


    for (int cycle = 0;
         cycle < 100;
         cycle++) begin

      @(negedge clk);

      if (
        tx_valid &&
        tx_ready &&
        tx_dw0[31:29] ==
          TLP_FMT_3DW_DATA &&
        tx_dw0[28:24] ==
          TLP_TYPE_MEM
      ) begin

        found = 1'b1;


        if (tx_dw2 !== DMA_DEST_ADDR) begin

          $error(
            "DMA MemWr address mismatch expected=%h got=%h",
            DMA_DEST_ADDR,
            tx_dw2
          );

          error_count++;

        end


        if (!tx_payload_valid) begin

          $error(
            "DMA MemWr payload_valid missing"
          );

          error_count++;

        end


        if (tx_payload_data !==
            DMA_TEST_DATA) begin

          $error(
            "DMA MemWr data mismatch expected=%h got=%h",
            DMA_TEST_DATA,
            tx_payload_data
          );

          error_count++;

        end


        break;

      end

    end


    if (!found) begin

      $error(
        "DMA Memory Write TLP not generated"
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    error_count = 0;

    captured_dma_read_tag = '0;


    reset_dut();


    $display(
      "=============================================="
    );

    $display(
      " PCIe DMA INTEGRATION TEST START"
    );

    $display(
      "=============================================="
    );


    // ==========================================================
    // Program DMA Source Address
    // BAR0 + 0x00
    // ==========================================================

    send_mem_write(
      BAR0_BASE_ADDR + 32'h00,
      DMA_SOURCE_ADDR
    );


    // ==========================================================
    // Program DMA Destination Address
    // BAR0 + 0x04
    // ==========================================================

    send_mem_write(
      BAR0_BASE_ADDR + 32'h04,
      DMA_DEST_ADDR
    );


    // ==========================================================
    // Program DMA Length = 4 Bytes
    // BAR0 + 0x08
    // ==========================================================

    send_mem_write(
      BAR0_BASE_ADDR + 32'h08,
      32'd4
    );


    // ==========================================================
    // Start DMA
    // BAR0 + 0x0C
    // CONTROL.START = 1
    // ==========================================================

    send_mem_write(
      BAR0_BASE_ADDR + 32'h0C,
      32'h0000_0001
    );


    // ==========================================================
    // Endpoint should issue PCIe MemRd
    // ==========================================================

    wait_for_dma_read();
 
          // ==========================================================
      // START while DMA is BUSY
      //
      // dma_regs should ignore CONTROL.START while dma_busy = 1.
      // The active DMA must continue unchanged.
      // ==========================================================

      $display(
        "TEST: START while DMA busy"
      );

      if (!dma_busy) begin

        $error(
          "DMA should be busy after issuing Memory Read"
        );

        error_count++;

      end


      // Attempt another START while the current DMA is active.
      send_mem_write(
        BAR0_BASE_ADDR + 32'h0C,
        32'h0000_0001
      );


      // The original transaction must still be active.
      #1;

      if (!dma_busy) begin

        $error(
          "DMA busy dropped after START was issued while busy"
        );

        error_count++;

      end


      if (outstanding_count != 1) begin

        $error(
          "START while busy changed outstanding count: expected=1 got=%0d",
          outstanding_count
        );

        error_count++;

      end


      // Ensure the ignored START did not create another DMA MemRd.
      repeat (5) begin

        @(negedge clk);

        if (
          tx_valid &&
          tx_ready &&
          tx_dw0[31:29] == TLP_FMT_3DW_NO_DATA &&
          tx_dw0[28:24] == TLP_TYPE_MEM
        ) begin

          $error(
            "START while busy generated an unexpected second DMA MemRd"
          );

          error_count++;

        end

      end

    // ==========================================================
    // Outstanding entry should exist
    // ==========================================================

    if (outstanding_count == 0) begin

      $error(
        "No outstanding request after DMA MemRd"
      );

      error_count++;

    end


    // ==========================================================
    // Return Completion Data
    // ==========================================================

    send_cpld(
      captured_dma_read_tag,
      DMA_TEST_DATA
    );


    // ==========================================================
    // Endpoint should issue posted MemWr
    // ==========================================================

    wait_for_dma_write();


    // ==========================================================
    // Wait For DMA Completion
    // ==========================================================

    begin

      bit done_seen;

      done_seen = 1'b0;


      for (int cycle = 0;
           cycle < 100;
           cycle++) begin

        @(posedge clk);

        #1;


        if (dma_done) begin

          done_seen = 1'b1;
          break;

        end

      end


      if (!done_seen) begin

        $error(
          "DMA done was not asserted"
        );

        error_count++;

      end

    end

          // ==========================================================
      // Second DMA after first DMA completion
      //
      // Verify that a fresh START is accepted after the previous
      // DMA has completely finished.
      // ==========================================================

      $display(
        "TEST: Restart DMA after completion"
      );


      // Reuse the already programmed:
      // SRC    = DMA_SOURCE_ADDR
      // DST    = DMA_DEST_ADDR
      // LENGTH = 4 bytes

      send_mem_write(
        BAR0_BASE_ADDR + 32'h0C,
        32'h0000_0001
      );


      // Endpoint must issue another DMA Memory Read.
      wait_for_dma_read();


      if (!dma_busy) begin

        $error(
          "Second DMA did not enter busy state"
        );

        error_count++;

      end


      if (outstanding_count != 1) begin

        $error(
          "Second DMA outstanding count incorrect: expected=1 got=%0d",
          outstanding_count
        );

        error_count++;

      end


      // Return completion for DMA #2.
      send_cpld(
        captured_dma_read_tag,
        DMA_TEST_DATA
      );


      // DMA #2 must issue the corresponding Memory Write.
      wait_for_dma_write();


      // ----------------------------------------------------------
      // Wait for DMA #2 completion
      // ----------------------------------------------------------

      begin

        bit second_done_seen;

        second_done_seen = 1'b0;

        for (int cycle = 0;
             cycle < 100;
             cycle++) begin

          @(posedge clk);
          #1;

          if (dma_done) begin

            second_done_seen = 1'b1;
            break;

          end

        end


        if (!second_done_seen) begin

          $error(
            "Second DMA done was not asserted"
          );

          error_count++;

        end

      end


      repeat (3)
        @(posedge clk);


      if (dma_error) begin

        $error(
          "Second DMA unexpectedly asserted error"
        );

        error_count++;

      end


      if (outstanding_count != 0) begin

        $error(
          "Outstanding request table not empty after second DMA"
        );

        error_count++;

      end

    // ==========================================================
    // Final Checks
    // ==========================================================

    if (dma_error) begin

      $error(
        "DMA error unexpectedly asserted"
      );

      error_count++;

    end


    if (unexpected_completion) begin

      $error(
        "Unexpected completion flag asserted"
      );

      error_count++;

    end


    if (tx_formatter_error) begin

      $error(
        "TX formatter error asserted"
      );

      error_count++;

    end


    repeat (3)
      @(posedge clk);


    if (outstanding_count != 0) begin

      $error(
        "Outstanding request table not empty after completion"
      );

      error_count++;

    end

      // ==========================================================
      // TX ARBITRATION CONTENTION TEST
      //
      // Priority:
      //   1. Endpoint Completion
      //   2. DMA Memory Read
      //
      // Hold TX stalled, make a DMA MemRd pending, then generate
      // a host-read Completion. When TX is released, Completion
      // must transmit first and DMA MemRd must follow.
      // ==========================================================

      $display(
        "TEST: Completion vs DMA Read TX arbitration"
      );


      // ----------------------------------------------------------
      // Put known data in endpoint memory for the host read.
      // ----------------------------------------------------------

      send_mem_write(
        BAR0_BASE_ADDR + 32'h0000_0100,
        32'hD00D_F00D
      );


      // ----------------------------------------------------------
      // Stall the common PCIe TX output.
      // ----------------------------------------------------------

      @(negedge clk);
      tx_ready = 1'b0;


      // ----------------------------------------------------------
      // Start another DMA.
      //
      // SRC/DST/LENGTH remain programmed from earlier tests.
      // ----------------------------------------------------------

      send_mem_write(
        BAR0_BASE_ADDR + 32'h0C,
        32'h0000_0001
      );


      // ----------------------------------------------------------
      // Wait until the DMA Memory Read is pending while TX stalled.
      // ----------------------------------------------------------

      begin

        bit dma_pending_seen;

        dma_pending_seen = 1'b0;

        for (int cycle = 0;
             cycle < 100;
             cycle++) begin

          @(negedge clk);

          if (
            tx_valid &&
            !tx_ready &&
            tx_dw0[31:29] == TLP_FMT_3DW_NO_DATA &&
            tx_dw0[28:24] == TLP_TYPE_MEM
          ) begin

            dma_pending_seen = 1'b1;
            break;

          end

        end


        if (!dma_pending_seen) begin

          $error(
            "DMA MemRd did not become pending during TX stall"
          );

          error_count++;

        end

      end


      if (outstanding_count != 1) begin

        $error(
          "Expected one outstanding DMA request during arbitration test, got=%0d",
          outstanding_count
        );

        error_count++;

      end


      // ----------------------------------------------------------
      // While DMA MemRd is still stalled, inject a host MemRd.
      // This creates an endpoint Completion which has higher TX
      // priority than the already-pending DMA read.
      // ----------------------------------------------------------

      send_mem_read(
        BAR0_BASE_ADDR + 32'h0000_0100,
        8'h5A
      );


      // ----------------------------------------------------------
      // With TX still stalled, arbiter output must switch to the
      // higher-priority Completion.
      // ----------------------------------------------------------

      begin

        bit completion_pending_seen;

        completion_pending_seen = 1'b0;

        for (int cycle = 0;
             cycle < 100;
             cycle++) begin

          @(negedge clk);

          if (
            tx_valid &&
            !tx_ready &&
            tx_dw0[28:24] == TLP_TYPE_CPL &&
            tx_dw2[15:8] == 8'h5A
          ) begin

            completion_pending_seen = 1'b1;

            if (!tx_payload_valid) begin

              $error(
                "Arbitrated host Completion missing payload"
              );

              error_count++;

            end


            if (tx_payload_data !== 32'hD00D_F00D) begin

              $error(
                "Arbitrated host Completion data mismatch expected=D00DF00D got=%08h",
                tx_payload_data
              );

              error_count++;

            end

            break;

          end

        end


        if (!completion_pending_seen) begin

          $error(
            "Completion did not win arbitration over pending DMA MemRd"
          );

          error_count++;

        end

      end


      // ----------------------------------------------------------
      // Release TX.
      //
      // Because Completion currently owns the arbiter, it must be
      // the first transaction accepted.
      // ----------------------------------------------------------

      @(negedge clk);
      tx_ready = 1'b1;

      @(posedge clk);
      #1ps;


      // ----------------------------------------------------------
      // After Completion is consumed, the previously stalled DMA
      // MemRd must still be present and transmit next.
      //
      // Existing task also captures its DMA tag.
      // ----------------------------------------------------------

      wait_for_dma_read();


      // ----------------------------------------------------------
      // Complete the DMA read normally.
      // ----------------------------------------------------------

      send_cpld(
        captured_dma_read_tag,
        DMA_TEST_DATA
      );


      // DMA must still generate its posted Memory Write.
      wait_for_dma_write();


      // ----------------------------------------------------------
      // Wait for arbitration-test DMA completion.
      // ----------------------------------------------------------

      begin

        bit arbitration_dma_done_seen;

        arbitration_dma_done_seen = 1'b0;

        for (int cycle = 0;
             cycle < 100;
             cycle++) begin

          @(posedge clk);
          #1;

          if (dma_done) begin

            arbitration_dma_done_seen = 1'b1;
            break;

          end

        end


        if (!arbitration_dma_done_seen) begin

          $error(
            "DMA did not complete after TX arbitration contention"
          );

          error_count++;

        end

      end


      repeat (3)
        @(posedge clk);


      if (dma_error) begin

        $error(
          "DMA error asserted after TX arbitration contention"
        );

        error_count++;

      end


      if (unexpected_completion) begin

        $error(
          "Unexpected completion asserted during TX arbitration test"
        );

        error_count++;

      end


      if (tx_formatter_error) begin

        $error(
          "TX formatter error asserted during arbitration test"
        );

        error_count++;

      end


      if (outstanding_count != 0) begin

        $error(
          "Outstanding table not empty after TX arbitration test"
        );

        error_count++;

      end

          // ==========================================================
      // RESET DURING ACTIVE DMA
      //
      // Start a DMA and wait until its Memory Read is outstanding.
      // Assert reset while the DMA is waiting for completion.
      // Reset must clear all active DMA/outstanding state.
      //
      // Then reprogram the DMA registers and prove a fresh DMA
      // works normally after reset.
      // ==========================================================

      $display(
        "TEST: Reset during active DMA and recovery"
      );


      // ----------------------------------------------------------
      // Start DMA and allow its Memory Read to become outstanding.
      // ----------------------------------------------------------

      send_mem_write(
        BAR0_BASE_ADDR + 32'h0C,
        32'h0000_0001
      );


      wait_for_dma_read();


      if (!dma_busy) begin

        $error(
          "DMA should be busy before mid-transaction reset"
        );

        error_count++;

      end


      if (outstanding_count != 1) begin

        $error(
          "Expected one outstanding request before reset, got=%0d",
          outstanding_count
        );

        error_count++;

      end


      // ----------------------------------------------------------
      // Reset while DMA is waiting for its Completion.
      // ----------------------------------------------------------

      reset_dut();


      // ----------------------------------------------------------
      // All active state must be cleared by reset.
      // ----------------------------------------------------------

      if (dma_busy) begin

        $error(
          "DMA busy remained asserted after reset"
        );

        error_count++;

      end


      if (outstanding_count != 0) begin

        $error(
          "Outstanding request table not cleared by reset: count=%0d",
          outstanding_count
        );

        error_count++;

      end


      if (dma_error) begin

        $error(
          "DMA error unexpectedly asserted after reset"
        );

        error_count++;

      end


      if (unexpected_completion) begin

        $error(
          "Unexpected completion flag asserted after reset"
        );

        error_count++;

      end


      if (tx_formatter_error) begin

        $error(
          "TX formatter error asserted after reset"
        );

        error_count++;

      end


      // ----------------------------------------------------------
      // Reset clears the DMA configuration registers, so program
      // SRC, DST and LENGTH again before restarting.
      // ----------------------------------------------------------

      send_mem_write(
        BAR0_BASE_ADDR + 32'h00,
        DMA_SOURCE_ADDR
      );

      send_mem_write(
        BAR0_BASE_ADDR + 32'h04,
        DMA_DEST_ADDR
      );

      send_mem_write(
        BAR0_BASE_ADDR + 32'h08,
        32'd4
      );


      // ----------------------------------------------------------
      // Start a fresh DMA after reset.
      // ----------------------------------------------------------

      send_mem_write(
        BAR0_BASE_ADDR + 32'h0C,
        32'h0000_0001
      );


      wait_for_dma_read();


      if (!dma_busy) begin

        $error(
          "DMA failed to restart after reset"
        );

        error_count++;

      end


      if (outstanding_count != 1) begin

        $error(
          "Post-reset DMA outstanding count incorrect: expected=1 got=%0d",
          outstanding_count
        );

        error_count++;

      end


      // ----------------------------------------------------------
      // Complete the post-reset DMA normally.
      // ----------------------------------------------------------

      send_cpld(
        captured_dma_read_tag,
        DMA_TEST_DATA
      );


      wait_for_dma_write();


      // ----------------------------------------------------------
      // Wait for post-reset DMA completion.
      // ----------------------------------------------------------

      begin

        bit post_reset_done_seen;

        post_reset_done_seen = 1'b0;

        for (int cycle = 0;
             cycle < 100;
             cycle++) begin

          @(posedge clk);
          #1;

          if (dma_done) begin

            post_reset_done_seen = 1'b1;
            break;

          end

        end


        if (!post_reset_done_seen) begin

          $error(
            "Post-reset DMA did not complete"
          );

          error_count++;

        end

      end


      repeat (3)
        @(posedge clk);


      if (dma_error) begin

        $error(
          "Post-reset DMA produced unexpected error"
        );

        error_count++;

      end


      if (outstanding_count != 0) begin

        $error(
          "Outstanding table not empty after post-reset DMA"
        );

        error_count++;

      end

    // ==========================================================
    // Final Result
    // ==========================================================

    if (error_count == 0) begin

      $display("");
      $display(
        "=============================================="
      );

      $display(
        " PCIe DMA INTEGRATION TEST: PASS"
      );

      $display(
        "=============================================="
      );

    end
    else begin

      $display("");
      $display(
        "=============================================="
      );

      $display(
        " PCIe DMA INTEGRATION TEST: FAIL"
      );

      $display(
        " Errors = %0d",
        error_count
      );

      $display(
        "=============================================="
      );

      $fatal(1);

    end


    $finish;

  end


endmodule