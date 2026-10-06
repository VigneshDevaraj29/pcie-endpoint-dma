`timescale 1ns/1ps

module request_handler_tb;

  import pcie_tlp_pkg::*;

  logic clk;
  logic rst_n;

  logic         req_valid;
  logic         req_ready;

  tlp_header_t  header;
  tlp_kind_e    kind;

  logic [31:0]  payload_data;

  logic         bar_hit;
  logic [31:0]  local_addr;

  logic         mem_req_valid;
  logic         mem_req_write;

  logic [31:0]  mem_local_addr;
  logic [31:0]  mem_write_data;
  logic [3:0]   mem_byte_en;

  logic         mem_req_ready;

  logic         mem_rsp_valid;
  logic [31:0]  mem_read_data;
  logic         mem_addr_error;

  logic         cpl_req_valid;
  cpl_status_e  cpl_status;

  logic         cpl_data_valid;
  logic [31:0]  cpl_data;

  logic [15:0]  cpl_requester_id;
  logic [7:0]   cpl_tag;
  logic [6:0]   cpl_lower_addr;

  logic         busy;

  int error_count;


  request_handler dut (
    .clk                 (clk),
    .rst_n               (rst_n),

    .req_valid_i         (req_valid),
    .req_ready_o         (req_ready),

    .header_i            (header),
    .kind_i              (kind),

    .payload_data_i      (payload_data),

    .bar_hit_i           (bar_hit),
    .local_addr_i        (local_addr),

    .mem_req_valid_o     (mem_req_valid),
    .mem_req_write_o     (mem_req_write),

    .mem_local_addr_o    (mem_local_addr),
    .mem_write_data_o    (mem_write_data),
    .mem_byte_en_o       (mem_byte_en),

    .mem_req_ready_i     (mem_req_ready),

    .mem_rsp_valid_i     (mem_rsp_valid),
    .mem_read_data_i     (mem_read_data),
    .mem_addr_error_i    (mem_addr_error),

    .cpl_req_valid_o     (cpl_req_valid),
    .cpl_status_o        (cpl_status),

    .cpl_data_valid_o    (cpl_data_valid),
    .cpl_data_o          (cpl_data),

    .cpl_requester_id_o  (cpl_requester_id),
    .cpl_tag_o           (cpl_tag),
    .cpl_lower_addr_o    (cpl_lower_addr),

    .busy_o              (busy)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  task automatic reset_dut();

    rst_n          = 0;

    req_valid      = 0;
    header         = '0;
    kind           = TLP_KIND_UNSUPPORTED;

    payload_data   = '0;

    bar_hit        = 0;
    local_addr     = '0;

    mem_req_ready  = 1;

    mem_rsp_valid  = 0;
    mem_read_data  = '0;
    mem_addr_error = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;

    @(posedge clk);

  endtask


  task automatic test_mem_write();

    @(negedge clk);

    header = '0;

    header.requester_id = 16'h1234;
    header.first_be     = 4'b1111;

    kind         = TLP_KIND_MEM_WR;
    req_valid    = 1;
    bar_hit      = 1;
    local_addr   = 32'h100;

    payload_data = 32'hDEAD_BEEF;

    #1;

    if (!mem_req_valid ||
        !mem_req_write ||
        mem_write_data != 32'hDEAD_BEEF) begin

      $error("Memory write request incorrect");
      error_count++;

    end

    @(posedge clk);

    req_valid = 0;

    @(negedge clk);

    mem_rsp_valid = 1;

    @(posedge clk);

    mem_rsp_valid = 0;

  endtask


  task automatic test_mem_read();

    @(negedge clk);

    header = '0;

    header.requester_id = 16'h5678;
    header.tag          = 8'h22;
    header.address      = 32'h8000_0120;

    kind       = TLP_KIND_MEM_RD;

    req_valid  = 1;
    bar_hit    = 1;
    local_addr = 32'h120;

    #1;

    if (!mem_req_valid ||
        mem_req_write) begin

      $error("Memory read request incorrect");
      error_count++;

    end

    @(posedge clk);

    req_valid = 0;

    @(negedge clk);

    mem_rsp_valid = 1;
    mem_read_data = 32'hCAFE_BABE;

    #1;

    if (!cpl_req_valid ||
        !cpl_data_valid ||
        cpl_data != 32'hCAFE_BABE ||
        cpl_tag != 8'h22) begin

      $error("Read completion generation incorrect");
      error_count++;

    end

    @(posedge clk);

    mem_rsp_valid = 0;

  endtask


  task automatic test_invalid_bar_read();

    @(negedge clk);

    header = '0;

    header.requester_id = 16'hAAAA;
    header.tag          = 8'h33;
    header.address      = 32'h9000_0000;

    kind      = TLP_KIND_MEM_RD;
    req_valid = 1;
    bar_hit   = 0;

    #1;

    if (!cpl_req_valid ||
        cpl_status != CPL_STATUS_UR ||
        cpl_tag != 8'h33) begin

      $error("Invalid BAR UR completion incorrect");
      error_count++;

    end

    @(posedge clk);

    req_valid = 0;

  endtask


  initial begin

    error_count = 0;

    reset_dut();

    test_mem_write();
    test_mem_read();
    test_invalid_bar_read();

    if (error_count == 0)
      $display("REQUEST HANDLER TEST: PASS");
    else begin
      $display("REQUEST HANDLER TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule