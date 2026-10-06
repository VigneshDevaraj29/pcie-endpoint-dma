`timescale 1ns/1ps

module pcie_endpoint_smoke_tb;

  import pcie_tlp_pkg::*;


  // ============================================================
  // Parameters
  // ============================================================

  localparam logic [31:0] BAR0_BASE_ADDR =
    32'h8000_0000;

  localparam logic [15:0] HOST_REQUESTER_ID =
    16'hBEEF;


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
  // Status
  // ============================================================

  logic dma_busy;
  logic dma_done;
  logic dma_error;

  logic unexpected_completion;

  logic [4:0] outstanding_count;

  logic tx_formatter_error;


  // ============================================================
  // Test Status
  // ============================================================

  int error_count;


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
  // Clear RX Interface
  // ============================================================

  task automatic clear_rx();

    rx_valid        = 1'b0;

    rx_dw0          = '0;
    rx_dw1          = '0;
    rx_dw2          = '0;

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
  // Send Memory Write TLP
  // ============================================================

  task automatic send_mem_write(
    input logic [31:0] address,
    input logic [31:0] data,
    input logic [3:0]  byte_en
  );

    @(negedge clk);


    // ----------------------------------------------------------
    // DW0
    // ----------------------------------------------------------

    rx_dw0 = '0;

    rx_dw0[31:29] =
      TLP_FMT_3DW_DATA;

    rx_dw0[28:24] =
      TLP_TYPE_MEM;

    rx_dw0[9:0] =
      10'd1;


    // ----------------------------------------------------------
    // DW1
    // ----------------------------------------------------------

    rx_dw1 = '0;

    rx_dw1[31:16] =
      HOST_REQUESTER_ID;

    rx_dw1[15:8] =
      8'h00;

    rx_dw1[7:4] =
      4'b0000;

    rx_dw1[3:0] =
      byte_en;


    // ----------------------------------------------------------
    // DW2
    // ----------------------------------------------------------

    rx_dw2 =
      address;


    // ----------------------------------------------------------
    // Payload
    // ----------------------------------------------------------

    rx_payload_valid =
      1'b1;

    rx_payload_data =
      data;


    rx_valid =
      1'b1;


    // ----------------------------------------------------------
    // Wait for DUT acceptance
    // ----------------------------------------------------------

    do begin
      @(posedge clk);
    end while (!rx_ready);

    #1ps;
    clear_rx();

  endtask


  // ============================================================
  // Send Memory Read TLP
  // ============================================================

  task automatic send_mem_read(
    input logic [31:0] address,
    input logic [7:0]  tag
  );

    @(negedge clk);


    // ----------------------------------------------------------
    // DW0
    // ----------------------------------------------------------

    rx_dw0 = '0;

    rx_dw0[31:29] =
      TLP_FMT_3DW_NO_DATA;

    rx_dw0[28:24] =
      TLP_TYPE_MEM;

    rx_dw0[9:0] =
      10'd1;


    // ----------------------------------------------------------
    // DW1
    // ----------------------------------------------------------

    rx_dw1 = '0;

    rx_dw1[31:16] =
      HOST_REQUESTER_ID;

    rx_dw1[15:8] =
      tag;

    rx_dw1[7:4] =
      4'b0000;

    rx_dw1[3:0] =
      4'b1111;


    // ----------------------------------------------------------
    // DW2
    // ----------------------------------------------------------

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
  // Wait For Completion With Data
  // ============================================================

  task automatic wait_for_cpld(
    input logic [7:0]  expected_tag,
    input logic [31:0] expected_data
  );

    bit found;

    found = 1'b0;


    for (int cycle = 0;
         cycle < 50;
         cycle++) begin

      @(negedge clk);

      if (tx_valid &&
          tx_ready) begin


        if (
          (tx_dw0[28:24] == TLP_TYPE_CPL) &&
          (tx_dw2[15:8]  == expected_tag)
        ) begin

          found = 1'b1;


          if (tx_dw0[31:29] !=
              TLP_FMT_3DW_DATA) begin

            $error(
              "Expected CplD but received different Fmt"
            );

            error_count++;

          end


          if (tx_payload_valid !== 1'b1) begin

            $error(
              "CplD payload_valid not asserted"
            );

            error_count++;

          end


          if (tx_payload_data !==
              expected_data) begin

            $error(
              "CplD data mismatch expected=%h got=%h",
              expected_data,
              tx_payload_data
            );

            error_count++;

          end


          break;

        end

      end

    end


    if (!found) begin

      $error(
        "Completion not received for tag %h",
        expected_tag
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Wait For Completion Without Data
  // ============================================================

  task automatic wait_for_cpl_status(
    input logic [7:0]  expected_tag,
    input cpl_status_e expected_status
  );

    bit found;

    found = 1'b0;


    for (int cycle = 0;
         cycle < 50;
         cycle++) begin

      @(negedge clk);

      if (tx_valid &&
          tx_ready &&
          tx_dw0[28:24] == TLP_TYPE_CPL &&
          tx_dw2[15:8] == expected_tag) begin

        found = 1'b1;


        if (tx_dw1[15:13] !=
            expected_status) begin

          $error(
            "Completion status mismatch expected=%b got=%b",
            expected_status,
            tx_dw1[15:13]
          );

          error_count++;

        end


        break;

      end

    end


    if (!found) begin

      $error(
        "Completion not received for tag %h",
        expected_tag
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Ensure Posted Write Generates No Completion
  // ============================================================

  task automatic check_no_completion(
    input int cycles
  );

    repeat (cycles) begin

      @(posedge clk);

      #1;


      if (tx_valid &&
          tx_dw0[28:24] == TLP_TYPE_CPL) begin

        $error(
          "Posted Memory Write generated unexpected completion"
        );

        error_count++;

      end

    end

  endtask


  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    error_count = 0;


    reset_dut();


    $display(
      "============================================"
    );

    $display(
      " PCIe ENDPOINT SMOKE TEST START"
    );

    $display(
      "============================================"
    );


    // ==========================================================
    // TEST 1
    //
    // Host Memory Write into Endpoint Memory
    // ==========================================================

    $display(
      "TEST 1: Endpoint Memory Write"
    );


    send_mem_write(
      BAR0_BASE_ADDR + 32'h0000_0100,
      32'hDEAD_BEEF,
      4'b1111
    );


    check_no_completion(3);


    // ==========================================================
    // TEST 2
    //
    // Read Back Endpoint Memory
    // ==========================================================

    $display(
      "TEST 2: Endpoint Memory Read"
    );


    send_mem_read(
      BAR0_BASE_ADDR + 32'h0000_0100,
      8'h22
    );


    wait_for_cpld(
      8'h22,
      32'hDEAD_BEEF
    );


    // ==========================================================
    // TEST 3
    //
    // Invalid BAR Read -> UR Completion
    // ==========================================================

    $display(
      "TEST 3: Invalid BAR Read"
    );


    send_mem_read(
      32'h9000_0000,
      8'h33
    );


    wait_for_cpl_status(
      8'h33,
      CPL_STATUS_UR
    );


    // ==========================================================
    // Final Checks
    // ==========================================================

    if (tx_formatter_error) begin

      $error(
        "TX formatter error asserted"
      );

      error_count++;

    end


    if (error_count == 0) begin

      $display("");
      $display(
        "============================================"
      );

      $display(
        " PCIe ENDPOINT SMOKE TEST: PASS"
      );

      $display(
        "============================================"
      );

    end
    else begin

      $display("");
      $display(
        "============================================"
      );

      $display(
        " PCIe ENDPOINT SMOKE TEST: FAIL"
      );

      $display(
        " Errors = %0d",
        error_count
      );

      $display(
        "============================================"
      );

      $fatal(1);

    end


    $finish;

  end


endmodule