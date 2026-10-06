`timescale 1ns/1ps

module dma_write_engine_tb;

  import pcie_tlp_pkg::*;

  logic clk;
  logic rst_n;

  logic        cmd_valid;
  logic        cmd_ready;

  logic [31:0] cmd_address;
  logic [31:0] cmd_data;
  logic [3:0]  cmd_byte_en;

  logic        tx_valid;
  logic        tx_ready;

  tlp_header_t tx_header;

  logic        tx_payload_valid;
  logic [31:0] tx_payload_data;

  logic        write_done;
  logic        write_error;

  logic        busy;

  int error_count;


  dma_write_engine dut (
    .clk                (clk),
    .rst_n              (rst_n),

    .cmd_valid_i        (cmd_valid),
    .cmd_ready_o        (cmd_ready),

    .cmd_address_i      (cmd_address),
    .cmd_data_i         (cmd_data),
    .cmd_byte_en_i      (cmd_byte_en),

    .tx_valid_o         (tx_valid),
    .tx_ready_i         (tx_ready),

    .tx_header_o        (tx_header),

    .tx_payload_valid_o (tx_payload_valid),
    .tx_payload_data_o  (tx_payload_data),

    .write_done_o       (write_done),
    .write_error_o      (write_error),

    .busy_o             (busy)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  initial begin

    error_count = 0;

    rst_n = 0;

    cmd_valid   = 0;
    cmd_address = 0;
    cmd_data    = 0;
    cmd_byte_en = 0;

    tx_ready = 1;

    repeat (3) @(posedge clk);

    rst_n = 1;


    // Valid write

    wait(cmd_ready);
    @(negedge clk);

    cmd_valid   = 1;
    cmd_address = 32'h2000_0000;

    cmd_data    = 32'hDEAD_BEEF;
    cmd_byte_en = 4'hF;

    @(posedge clk);
    #1ps; // hold cmd_valid high past posedge so RTL samples it before TB de-asserts
    cmd_valid = 0;


    wait(tx_valid);

    #1;

    if (tx_header.fmt != TLP_FMT_3DW_DATA ||
        tx_header.address != 32'h2000_0000 ||
        !tx_payload_valid ||
        tx_payload_data != 32'hDEAD_BEEF) begin

      $error("DMA Memory Write TLP incorrect");
      error_count++;

    end


    wait(write_done);


    // Invalid unaligned write

    wait(cmd_ready);
    @(negedge clk);

    cmd_valid   = 1;
    cmd_address = 32'h2000_0001;

    @(posedge clk);
    #1ps; // hold cmd_valid high past posedge so RTL samples it before TB de-asserts
    cmd_valid = 0;


          wait(write_error);

      // Allow ST_ERROR -> ST_IDLE transition to occur
      @(posedge clk);
      #1ps;


      if (error_count == 0)
      $display("DMA WRITE ENGINE TEST: PASS");
    else begin
      $display("DMA WRITE ENGINE TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule