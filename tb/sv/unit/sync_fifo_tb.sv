`timescale 1ns/1ps

module sync_fifo_tb;

  localparam int WIDTH = 32;
  localparam int DEPTH = 4;

  logic clk;
  logic rst_n;

  logic             wr_en;
  logic [WIDTH-1:0] wr_data;

  logic             rd_en;
  logic [WIDTH-1:0] rd_data;

  logic             full;
  logic             empty;

  logic [$clog2(DEPTH+1)-1:0]
                    count;

  int error_count;


  sync_fifo #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk       (clk),
    .rst_n     (rst_n),

    .wr_en_i   (wr_en),
    .wr_data_i (wr_data),

    .rd_en_i   (rd_en),
    .rd_data_o (rd_data),

    .full_o    (full),
    .empty_o   (empty),
    .count_o   (count)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  task automatic write_fifo(input logic [31:0] data);

    @(negedge clk);

    wr_en   = 1;
    wr_data = data;

    @(posedge clk);

    wr_en = 0;

  endtask


  task automatic read_fifo(input logic [31:0] expected);

    @(negedge clk);

    if (rd_data !== expected) begin

      $error(
        "FIFO read mismatch expected=%h got=%h",
        expected,
        rd_data
      );

      error_count++;

    end

    rd_en = 1;

    @(posedge clk);

    rd_en = 0;

  endtask


  initial begin

    error_count = 0;

    rst_n   = 0;
    wr_en   = 0;
    rd_en   = 0;
    wr_data = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;


    if (!empty) begin
      $error("FIFO not empty after reset");
      error_count++;
    end


    write_fifo(32'h1111_1111);
    write_fifo(32'h2222_2222);
    write_fifo(32'h3333_3333);
    write_fifo(32'h4444_4444);


    #1;

    if (!full || count != DEPTH) begin
      $error("FIFO full/count check failed");
      error_count++;
    end


    read_fifo(32'h1111_1111);
    read_fifo(32'h2222_2222);
    read_fifo(32'h3333_3333);
    read_fifo(32'h4444_4444);


    #1;

    if (!empty || count != 0) begin
      $error("FIFO empty/count check failed");
      error_count++;
    end


    if (error_count == 0)
      $display("SYNC FIFO TEST: PASS");
    else begin
      $display("SYNC FIFO TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule