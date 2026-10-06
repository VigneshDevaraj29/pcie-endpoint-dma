`timescale 1ns/1ps

module pcie_error_integration_tb;

  import pcie_tlp_pkg::*;


  // ============================================================
  // Parameters
  // ============================================================

  localparam logic [31:0] BAR0_BASE_ADDR =
    32'h8000_0000;

  localparam logic [15:0] HOST_REQUESTER_ID =
    16'hBEEF;

  localparam int TEST_TIMEOUT_CYCLES =
    8;


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
  // Test Variables
  // ============================================================

  int error_count;


  // ============================================================
  // DUT
  // ============================================================

  pcie_endpoint_dma_top #(
    .COMPLETION_TIMEOUT_CYCLES(
      TEST_TIMEOUT_CYCLES
    )
  ) dut (
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
  // Clear RX
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
  // Memory Write
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

    rx_dw1[3:0] =
      4'hF;


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
  // Memory Read
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

    rx_dw1[3:0] =
      4'hF;


    rx_dw2 =
      address;


    rx_payload_valid =
      1'b0;

    rx_valid =
      1'b1;


    do begin
      @(posedge clk);
    end while (!rx_ready);

    #1ps;
    clear_rx();

  endtask


  // ============================================================
  // Send Completion
  // ============================================================

  task automatic send_completion(
    input logic [7:0]        tag,
    input cpl_status_e       status,
    input logic              with_data,
    input logic [31:0]       data
  );

    @(negedge clk);


    rx_dw0 = '0;

    if (with_data)
      rx_dw0[31:29] =
        TLP_FMT_3DW_DATA;
    else
      rx_dw0[31:29] =
        TLP_FMT_3DW_NO_DATA;


    rx_dw0[28:24] =
      TLP_TYPE_CPL;


    if (with_data)
      rx_dw0[9:0] = 10'd1;
    else
      rx_dw0[9:0] = 10'd0;


    rx_dw1 = '0;

    rx_dw1[31:16] =
      16'hCAFE;

    rx_dw1[15:13] =
      status;


    if (with_data)
      rx_dw1[11:0] = 12'd4;


    rx_dw2 = '0;

    rx_dw2[31:16] =
      16'h0100;

    rx_dw2[15:8] =
      tag;


    rx_payload_valid =
      with_data;

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
  // Wait For UR Completion
  // ============================================================

  task automatic wait_for_ur(
    input logic [7:0] expected_tag
  );

    bit found;

    found = 1'b0;


    for (int cycle = 0;
         cycle < 50;
         cycle++) begin

      @(negedge clk);

      if (
        tx_valid &&
        tx_dw0[28:24] ==
          TLP_TYPE_CPL &&
        tx_dw2[15:8] ==
          expected_tag
      ) begin

        found = 1'b1;


        if (tx_dw1[15:13] !=
            CPL_STATUS_UR) begin

          $error(
            "Expected UR completion"
          );

          error_count++;

        end


        break;

      end

    end


    if (!found) begin

      $error(
        "UR completion was not generated"
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Wait For DMA Read TLP
  // ============================================================

  task automatic wait_for_dma_read(
    output logic [7:0] tag
  );

    bit found;

    found = 1'b0;

    tag = '0;


    for (int cycle = 0;
         cycle < 100;
         cycle++) begin

      @(negedge clk);

      if (
        tx_valid &&
        tx_dw0[31:29] ==
          TLP_FMT_3DW_NO_DATA &&
        tx_dw0[28:24] ==
          TLP_TYPE_MEM
      ) begin

        tag =
          tx_dw1[15:8];

        found =
          1'b1;

        break;

      end

    end


    if (!found) begin

      $error(
        "DMA Memory Read was not generated"
      );

      error_count++;

    end

  endtask


  // ============================================================
  // Configure And Start One DWORD DMA
  // ============================================================

  task automatic start_dma();

    send_mem_write(
      BAR0_BASE_ADDR + 32'h00,
      32'h1000_0000
    );

    send_mem_write(
      BAR0_BASE_ADDR + 32'h04,
      32'h2000_0000
    );

    send_mem_write(
      BAR0_BASE_ADDR + 32'h08,
      32'd4
    );

    send_mem_write(
      BAR0_BASE_ADDR + 32'h0C,
      32'h1
    );

  endtask


  // ============================================================
  // Main Test
  // ============================================================

  initial begin

    logic [7:0] dma_tag;


    error_count = 0;


    reset_dut();


    $display(
      "=============================================="
    );

    $display(
      " PCIe ERROR INTEGRATION TEST START"
    );

    $display(
      "=============================================="
    );


    // ==========================================================
    // TEST 1
    // Invalid BAR Read -> UR
    // ==========================================================

    $display(
      "TEST 1: Invalid BAR -> UR"
    );


    send_mem_read(
      32'h9000_0000,
      8'h41
    );


    wait_for_ur(
      8'h41
    );


    // ==========================================================
    // TEST 2
    // Unexpected Completion Tag
    // ==========================================================

    $display(
      "TEST 2: Unexpected Completion"
    );


    send_completion(
      8'hEE,
      CPL_STATUS_SC,
      1'b1,
      32'h1111_2222
    );


    // unexpected_completion_o is combinational during RX.
    // Table should remain empty afterward.

    if (outstanding_count != 0) begin

      $error(
        "Unexpected completion modified outstanding table"
      );

      error_count++;

    end


    // ==========================================================
    // TEST 3
    // DMA Completion Error
    // ==========================================================

    $display(
      "TEST 3: DMA Completion Error"
    );


    start_dma();


    wait_for_dma_read(
      dma_tag
    );


    send_completion(
      dma_tag,
      CPL_STATUS_CA,
      1'b0,
      32'h0
    );


    begin

      bit error_seen;

      error_seen = 1'b0;


      for (int cycle = 0;
           cycle < 50;
           cycle++) begin

        @(posedge clk);

        #1;


        if (dma_error) begin

          error_seen = 1'b1;
          break;

        end

      end


      if (!error_seen) begin

        $error(
          "DMA error not asserted after bad completion"
        );

        error_count++;

      end

    end


    repeat (5)
      @(posedge clk);


    // ==========================================================
    // TEST 4
    // Completion Timeout
    // ==========================================================

    $display(
      "TEST 4: DMA Completion Timeout"
    );


    start_dma();


    wait_for_dma_read(
      dma_tag
    );


    // Intentionally do not return a completion.

    begin

      bit timeout_error_seen;

      timeout_error_seen = 1'b0;


      for (int cycle = 0;
           cycle < 50;
           cycle++) begin

        @(posedge clk);

        #1;


        if (dma_error) begin

          timeout_error_seen = 1'b1;
          break;

        end

      end


      if (!timeout_error_seen) begin

        $error(
          "DMA completion timeout did not generate error"
        );

        error_count++;

      end

    end


    // Allow cancellation to remove outstanding entry.

    repeat (5)
      @(posedge clk);


    if (outstanding_count != 0) begin

      $error(
        "Outstanding table not cleared after timeout"
      );

      error_count++;

    end
      // ==========================================================
      // TEST 5
      // TX Backpressure Stability
      // ==========================================================

      $display(
        "TEST 5: TX Backpressure Stability"
      );

      // Stall TX before generating a response.
      tx_ready = 1'b0;

      // Invalid BAR read should generate a UR completion.
      send_mem_read(
        32'h9000_0000,
        8'h52
      );

      begin

        bit tx_seen;

        tx_seen = 1'b0;

        // Wait until DUT presents the TX packet.
        for (int cycle = 0;
             cycle < 50;
             cycle++) begin

          @(posedge clk);
          #1;

          if (tx_valid) begin
            tx_seen = 1'b1;
            break;
          end

        end

        if (!tx_seen) begin

          $error(
            "TX transaction not generated during backpressure test"
          );

          error_count++;

        end
        else begin

          // Keep the transaction stalled for several clocks.
          repeat (3) begin
            @(posedge clk);
            #1;
          end

        end

      end

      // Release TX backpressure.
      @(negedge clk);
      tx_ready = 1'b1;

      repeat (3)
        @(posedge clk);

    // ==========================================================
    // General Checks
    // ==========================================================

    if (tx_formatter_error) begin

      $error(
        "TX formatter error asserted"
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
        " PCIe ERROR INTEGRATION TEST: PASS"
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
        " PCIe ERROR INTEGRATION TEST: FAIL"
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
