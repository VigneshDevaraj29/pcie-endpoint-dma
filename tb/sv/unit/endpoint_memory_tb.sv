`timescale 1ns/1ps

module endpoint_memory_tb;

  localparam int ADDR_WIDTH     = 32;
  localparam int DATA_WIDTH     = 32;
  localparam int MEM_SIZE_BYTES = 256;

  logic clk;
  logic rst_n;

  logic                     req_valid;
  logic                     req_write;
  logic [ADDR_WIDTH-1:0]    local_addr;
  logic [DATA_WIDTH-1:0]    write_data;
  logic [(DATA_WIDTH/8)-1:0] byte_en;

  logic                     req_ready;
  logic                     rsp_valid;
  logic [DATA_WIDTH-1:0]    read_data;
  logic                     addr_error;

  int error_count;


  endpoint_memory #(
    .ADDR_WIDTH     (ADDR_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .MEM_SIZE_BYTES (MEM_SIZE_BYTES)
  ) dut (
    .clk          (clk),
    .rst_n        (rst_n),

    .req_valid_i  (req_valid),
    .req_write_i  (req_write),

    .local_addr_i (local_addr),
    .write_data_i (write_data),
    .byte_en_i    (byte_en),

    .req_ready_o  (req_ready),

    .rsp_valid_o  (rsp_valid),
    .read_data_o  (read_data),
    .addr_error_o (addr_error)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  task automatic reset_dut();

    rst_n      = 0;
    req_valid  = 0;
    req_write  = 0;
    local_addr = '0;
    write_data = '0;
    byte_en    = '0;

    repeat (3) @(posedge clk);

    rst_n = 1;

    @(posedge clk);

  endtask


  task automatic write_word(
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [3:0]  be
  );

    @(negedge clk);

    req_valid  = 1;
    req_write  = 1;
    local_addr = addr;
    write_data = data;
    byte_en    = be;

    @(posedge clk);

    #1;

    if (!rsp_valid) begin
      $error("Write response missing");
      error_count++;
    end

    req_valid = 0;

  endtask


  task automatic read_word(
    input logic [31:0] addr,
    input logic [31:0] expected
  );

    @(negedge clk);

    req_valid  = 1;
    req_write  = 0;
    local_addr = addr;

    @(posedge clk);

    #1;

    if (!rsp_valid) begin
      $error("Read response missing");
      error_count++;
    end

    if (read_data !== expected) begin
      $error(
        "Read mismatch addr=%h expected=%h got=%h",
        addr,
        expected,
        read_data
      );

      error_count++;
    end

    req_valid = 0;

  endtask


  initial begin

    error_count = 0;

    reset_dut();


    // Full word write/read

    write_word(
      32'h0000_0010,
      32'hDEAD_BEEF,
      4'b1111
    );

    read_word(
      32'h0000_0010,
      32'hDEAD_BEEF
    );


    // Partial byte write

    write_word(
      32'h0000_0010,
      32'h1234_5678,
      4'b0011
    );

    read_word(
      32'h0000_0010,
      32'hDEAD_5678
    );


    // Unaligned address

    @(negedge clk);

    req_valid  = 1;
    req_write  = 0;
    local_addr = 32'h0000_0011;

    @(posedge clk);

    #1;

    if (!addr_error) begin
      $error("Unaligned access did not generate error");
      error_count++;
    end

    req_valid = 0;


    // Out-of-range address

    @(negedge clk);

    req_valid  = 1;
    req_write  = 0;
    local_addr = MEM_SIZE_BYTES;

    @(posedge clk);

    #1;

    if (!addr_error) begin
      $error("Out-of-range access did not generate error");
      error_count++;
    end

    req_valid = 0;


    if (error_count == 0)
      $display("ENDPOINT MEMORY TEST: PASS");
    else begin
      $display("ENDPOINT MEMORY TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule