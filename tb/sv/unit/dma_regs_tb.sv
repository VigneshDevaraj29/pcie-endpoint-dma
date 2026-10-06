`timescale 1ns/1ps

module dma_regs_tb;

  logic clk;
  logic rst_n;

  logic        cfg_valid;
  logic        cfg_write;
  logic [7:0]  cfg_addr;

  logic [31:0] cfg_wdata;
  logic [3:0]  cfg_be;

  logic        cfg_ready;
  logic        cfg_rsp_valid;
  logic [31:0] cfg_rdata;
  logic        cfg_error;

  logic [31:0] dma_src_addr;
  logic [31:0] dma_dst_addr;
  logic [31:0] dma_length_bytes;

  logic        dma_start_pulse;

  logic        dma_busy;
  logic        dma_done;
  logic        dma_error;

  int error_count;


  dma_regs dut (
    .clk                (clk),
    .rst_n              (rst_n),

    .cfg_valid_i        (cfg_valid),
    .cfg_write_i        (cfg_write),
    .cfg_addr_i         (cfg_addr),

    .cfg_wdata_i        (cfg_wdata),
    .cfg_be_i           (cfg_be),

    .cfg_ready_o        (cfg_ready),
    .cfg_rsp_valid_o    (cfg_rsp_valid),
    .cfg_rdata_o        (cfg_rdata),
    .cfg_error_o        (cfg_error),

    .dma_src_addr_o     (dma_src_addr),
    .dma_dst_addr_o     (dma_dst_addr),

    .dma_length_bytes_o (dma_length_bytes),

    .dma_start_pulse_o  (dma_start_pulse),

    .dma_busy_i         (dma_busy),
    .dma_done_i         (dma_done),
    .dma_error_i        (dma_error)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  task automatic cfg_write_reg(
    input logic [7:0] addr,
    input logic [31:0] data
  );

    @(negedge clk);

    cfg_valid = 1;
    cfg_write = 1;

    cfg_addr  = addr;
    cfg_wdata = data;
    cfg_be    = 4'hF;

    @(posedge clk);

    #1;

    cfg_valid = 0;

  endtask


  task automatic cfg_read_reg(
    input logic [7:0] addr,
    input logic [31:0] expected
  );

    @(negedge clk);

    cfg_valid = 1;
    cfg_write = 0;

    cfg_addr = addr;

    @(posedge clk);

    #1;

    cfg_valid = 0;

    if (cfg_rdata !== expected) begin

      $error(
        "Register read mismatch addr=%h exp=%h got=%h",
        addr,
        expected,
        cfg_rdata
      );

      error_count++;

    end

  endtask


  initial begin

    error_count = 0;

    rst_n = 0;

    cfg_valid = 0;
    cfg_write = 0;
    cfg_addr  = 0;
    cfg_wdata = 0;
    cfg_be    = 0;

    dma_busy  = 0;
    dma_done  = 0;
    dma_error = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;


    cfg_write_reg(8'h00, 32'h1000_0000);
    cfg_write_reg(8'h04, 32'h2000_0000);
    cfg_write_reg(8'h08, 32'd64);


    if (dma_src_addr != 32'h1000_0000 ||
        dma_dst_addr != 32'h2000_0000 ||
        dma_length_bytes != 32'd64) begin

      $error("DMA register programming failed");
      error_count++;

    end


    cfg_read_reg(
      8'h00,
      32'h1000_0000
    );


    // Start

    @(negedge clk);

    cfg_valid = 1;
    cfg_write = 1;

    cfg_addr  = 8'h0C;
    cfg_wdata = 32'h1;
    cfg_be    = 4'hF;

    @(posedge clk);

    #1;

    if (!dma_start_pulse) begin
      $error("DMA start pulse missing");
      error_count++;
    end

    cfg_valid = 0;


    if (error_count == 0)
      $display("DMA REGS TEST: PASS");
    else begin
      $display("DMA REGS TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule