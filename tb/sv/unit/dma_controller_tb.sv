`timescale 1ns/1ps

module dma_controller_tb;

  logic clk;
  logic rst_n;

  logic        start;
  logic [31:0] src_addr;
  logic [31:0] dst_addr;
  logic [31:0] length_bytes;

  logic        read_cmd_valid;
  logic        read_cmd_ready;
  logic [31:0] read_cmd_addr;

  logic        read_done;
  logic        read_error;
  logic [31:0] read_data;

  logic        write_cmd_valid;
  logic        write_cmd_ready;

  logic [31:0] write_cmd_addr;
  logic [31:0] write_cmd_data;
  logic [3:0]  write_cmd_be;

  logic        write_done;
  logic        write_error;

  logic        busy;
  logic        done;
  logic        error;

  int error_count;


  dma_controller dut (
    .clk                 (clk),
    .rst_n               (rst_n),

    .start_i             (start),

    .src_addr_i          (src_addr),
    .dst_addr_i          (dst_addr),
    .length_bytes_i      (length_bytes),

    .read_cmd_valid_o    (read_cmd_valid),
    .read_cmd_ready_i    (read_cmd_ready),

    .read_cmd_addr_o     (read_cmd_addr),

    .read_done_i         (read_done),
    .read_error_i        (read_error),

    .read_data_i         (read_data),

    .write_cmd_valid_o   (write_cmd_valid),
    .write_cmd_ready_i   (write_cmd_ready),

    .write_cmd_addr_o    (write_cmd_addr),
    .write_cmd_data_o    (write_cmd_data),
    .write_cmd_byte_en_o (write_cmd_be),

    .write_done_i        (write_done),
    .write_error_i       (write_error),

    .busy_o              (busy),
    .done_o              (done),
    .error_o             (error)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  initial begin

    error_count = 0;

    rst_n = 0;

    start        = 0;
    src_addr     = 0;
    dst_addr     = 0;
    length_bytes = 0;

    read_cmd_ready = 0;
    read_done      = 0;
    read_error     = 0;
    read_data      = 0;

    write_cmd_ready = 0;
    write_done      = 0;
    write_error     = 0;

    repeat (3)
      @(posedge clk);

    rst_n = 1;


    // ==========================================================
    // TEST 1
    // One DWORD DMA with read/write backpressure
    // ==========================================================

    $display(
      "TEST 1: One DWORD DMA with backpressure"
    );

    read_cmd_ready  = 0;
    write_cmd_ready = 0;

    @(negedge clk);

    src_addr     = 32'h1000_0000;
    dst_addr     = 32'h2000_0000;
    length_bytes = 32'd4;
    start        = 1;

    @(posedge clk);
    #1ps;

    start = 0;


    // ----------------------------------------------------------
    // Read command stall
    // ----------------------------------------------------------

    wait(read_cmd_valid);

    #1;

    if (read_cmd_addr != 32'h1000_0000) begin
      $error("DMA source address incorrect");
      error_count++;
    end

    repeat (3) begin
      @(posedge clk);
      #1;
    end

    @(negedge clk);
    read_cmd_ready = 1;

    @(posedge clk);
    #1ps;


    // ----------------------------------------------------------
    // Return read data
    // ----------------------------------------------------------

    @(negedge clk);

    read_data = 32'hCAFE_BABE;
    read_done = 1;

    @(posedge clk);
    #1ps;

    read_done = 0;


    // ----------------------------------------------------------
    // Write command stall
    // ----------------------------------------------------------

    wait(write_cmd_valid);

    #1;

    if (write_cmd_addr != 32'h2000_0000 ||
        write_cmd_data != 32'hCAFE_BABE ||
        write_cmd_be != 4'hF) begin

      $error("DMA write command incorrect");
      error_count++;

    end

    repeat (3) begin
      @(posedge clk);
      #1;
    end

    @(negedge clk);
    write_cmd_ready = 1;

    @(posedge clk);
    #1ps;


    // ----------------------------------------------------------
    // Complete write
    // ----------------------------------------------------------

    @(negedge clk);

    write_done = 1;

    @(posedge clk);
    #1ps;

    write_done = 0;


    wait(done);

    if (error) begin
      $error("DMA controller unexpected error");
      error_count++;
    end

    @(posedge clk);
    #1ps;


    // ==========================================================
    // TEST 2
    // 8-byte DMA
    // Exercises ST_WAIT_WRITE -> ST_ISSUE_READ
    // ==========================================================

    $display(
      "TEST 2: Eight-byte DMA"
    );

    read_cmd_ready  = 1;
    write_cmd_ready = 1;

    @(negedge clk);

    src_addr     = 32'h3000_0000;
    dst_addr     = 32'h4000_0000;
    length_bytes = 32'd8;
    start        = 1;

    @(posedge clk);
    #1ps;

    start = 0;


    // ----------------------------------------------------------
    // First DWORD read
    // ----------------------------------------------------------

    wait(read_cmd_valid);

    #1;

    if (read_cmd_addr != 32'h3000_0000) begin
      $error(
        "First 8-byte DMA read address incorrect"
      );
      error_count++;
    end

    @(posedge clk);
    #1ps;

    @(negedge clk);

    read_data = 32'h1111_2222;
    read_done = 1;

    @(posedge clk);
    #1ps;

    read_done = 0;


    // ----------------------------------------------------------
    // First DWORD write
    // ----------------------------------------------------------

    wait(write_cmd_valid);

    #1;

    if (write_cmd_addr != 32'h4000_0000 ||
        write_cmd_data != 32'h1111_2222) begin

      $error(
        "First 8-byte DMA write incorrect"
      );
      error_count++;

    end

    @(posedge clk);
    #1ps;

    @(negedge clk);

    write_done = 1;

    @(posedge clk);
    #1ps;

    write_done = 0;


    // ----------------------------------------------------------
    // Second DWORD read
    // This proves controller looped back to ISSUE_READ.
    // ----------------------------------------------------------

    wait(read_cmd_valid);

    #1;

    if (read_cmd_addr != 32'h3000_0004) begin

      $error(
        "Second 8-byte DMA read address incorrect"
      );
      error_count++;

    end

    @(posedge clk);
    #1ps;

    @(negedge clk);

    read_data = 32'h3333_4444;
    read_done = 1;

    @(posedge clk);
    #1ps;

    read_done = 0;


    // ----------------------------------------------------------
    // Second DWORD write
    // ----------------------------------------------------------

    wait(write_cmd_valid);

    #1;

    if (write_cmd_addr != 32'h4000_0004 ||
        write_cmd_data != 32'h3333_4444) begin

      $error(
        "Second 8-byte DMA write incorrect"
      );
      error_count++;

    end

    @(posedge clk);
    #1ps;

    @(negedge clk);

    write_done = 1;

    @(posedge clk);
    #1ps;

    write_done = 0;


    wait(done);

    if (error) begin

      $error(
        "Eight-byte DMA produced unexpected error"
      );
      error_count++;

    end

    @(posedge clk);
    #1ps;
          // ==========================================================
      // TEST 3
      // 256-byte DMA = 64 DWORDs
      // Stress repeated read/write iteration and address increments.
      // ==========================================================

      $display(
        "TEST 3: 256-byte DMA / 64 DWORD stress"
      );

      read_cmd_ready  = 1;
      write_cmd_ready = 1;

      @(negedge clk);

      src_addr     = 32'h7000_0000;
      dst_addr     = 32'h7100_0000;
      length_bytes = 32'd256;
      start        = 1;

      @(posedge clk);
      #1ps;

      start = 0;


      // ----------------------------------------------------------
      // Complete exactly 64 DWORD transfers.
      // ----------------------------------------------------------

      for (int dword_idx = 0;
           dword_idx < 64;
           dword_idx++) begin

        // ========================================================
        // READ COMMAND
        // ========================================================

        wait(read_cmd_valid);

        #1;

        if (read_cmd_addr !=
            (32'h7000_0000 + (dword_idx * 4))) begin

          $error(
  "256-byte DMA read address incorrect: index=%0d expected=%08h actual=%08h",
  dword_idx,
  (32'h7000_0000 + (dword_idx * 4)),
  read_cmd_addr
);

          error_count++;

        end

        // read_cmd_ready is already 1, so accept command.
        @(posedge clk);
        #1ps;


        // ========================================================
        // RETURN READ DATA
        // ========================================================

        @(negedge clk);

        read_data =
          32'hA500_0000 + dword_idx;

        read_done = 1;

        @(posedge clk);
        #1ps;

        read_done = 0;


        // ========================================================
        // WRITE COMMAND
        // ========================================================

        wait(write_cmd_valid);

        #1;

        if (write_cmd_addr !=
            (32'h7100_0000 + (dword_idx * 4))) begin

          $error(
  "256-byte DMA write address incorrect: index=%0d expected=%08h actual=%08h",
  dword_idx,
  (32'h7100_0000 + (dword_idx * 4)),
  write_cmd_addr
);

          error_count++;

        end

        if (write_cmd_data !=
            (32'hA500_0000 + dword_idx)) begin

          $error(
  "256-byte DMA write data incorrect: index=%0d expected=%08h actual=%08h",
  dword_idx,
  (32'hA500_0000 + dword_idx),
  write_cmd_data
);

          error_count++;

        end

        if (write_cmd_be != 4'hF) begin

          $error(
  "256-byte DMA byte enable incorrect: index=%0d expected=F actual=%h",
  dword_idx,
  write_cmd_be
);

          error_count++;

        end

        // write_cmd_ready is already 1, so accept command.
        @(posedge clk);
        #1ps;


        // ========================================================
        // COMPLETE WRITE
        // ========================================================

        @(negedge clk);

        write_done = 1;

        @(posedge clk);
        #1ps;

        write_done = 0;

      end


      // ----------------------------------------------------------
      // Exactly 64 DWORDs should complete the DMA.
      // ----------------------------------------------------------

      wait(done);

      if (error) begin

        $error(
          "256-byte DMA produced unexpected error"
        );

        error_count++;

      end


      // Let DONE return to IDLE.
      @(posedge clk);
      #1ps;


      // ----------------------------------------------------------
      // Ensure controller did not issue a 65th transaction.
      // ----------------------------------------------------------

      repeat (3) begin

        @(posedge clk);
        #1;

        if (read_cmd_valid ||
            write_cmd_valid) begin

          $error(
            "256-byte DMA issued command after 64 DWORDs"
          );

          error_count++;

        end

      end

    // ==========================================================
    // TEST 4
    // Write error
    // Exercises ST_WAIT_WRITE -> ST_ERROR
    // ==========================================================

    $display(
      "TEST 4: DMA write error"
    );

    read_cmd_ready  = 1;
    write_cmd_ready = 1;

    @(negedge clk);

    src_addr     = 32'h5000_0000;
    dst_addr     = 32'h6000_0000;
    length_bytes = 32'd4;
    start        = 1;

    @(posedge clk);
    #1ps;

    start = 0;


    // ----------------------------------------------------------
    // Complete read normally
    // ----------------------------------------------------------

    wait(read_cmd_valid);

    @(posedge clk);
    #1ps;

    @(negedge clk);

    read_data = 32'hABCD_1234;
    read_done = 1;

    @(posedge clk);
    #1ps;

    read_done = 0;


    // ----------------------------------------------------------
    // Reach write phase and inject write error
    // ----------------------------------------------------------

    wait(write_cmd_valid);

    @(posedge clk);
    #1ps;

    @(negedge clk);

    write_error = 1;

    @(posedge clk);
    #1ps;

    write_error = 0;


    wait(error);

    // Allow ST_ERROR -> ST_IDLE transition.
    @(posedge clk);
    #1ps;


    // ==========================================================
    // TEST 5
    // Invalid transfer length
    // Exercises ST_IDLE -> ST_ERROR
    // ==========================================================

    $display(
      "TEST 5: Invalid transfer length"
    );

    @(negedge clk);

    length_bytes = 32'd3;
    start = 1;

    @(posedge clk);
    #1ps;

    start = 0;


    wait(error);

    @(posedge clk);
    #1ps;


    // ==========================================================
    // Final result
    // ==========================================================

    if (error_count == 0)
      $display(
        "DMA CONTROLLER TEST: PASS"
      );
    else begin

      $display(
        "DMA CONTROLLER TEST: FAIL errors=%0d",
        error_count
      );

      $fatal(1);

    end

    $finish;

  end

endmodule