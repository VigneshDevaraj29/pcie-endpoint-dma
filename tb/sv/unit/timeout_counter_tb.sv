`timescale 1ns/1ps

module timeout_counter_tb;

  localparam int TIMEOUT_CYCLES = 4;

  logic clk;
  logic rst_n;

  logic start;
  logic clear;

  logic active;
  logic timeout;

  logic [$clog2(TIMEOUT_CYCLES+1)-1:0]
        count;

  int error_count;


  timeout_counter #(
    .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
  ) dut (
    .clk       (clk),
    .rst_n     (rst_n),

    .start_i   (start),
    .clear_i   (clear),

    .active_o  (active),
    .timeout_o (timeout),

    .count_o   (count)
  );


  initial clk = 0;
  always #5 clk = ~clk;


  initial begin

    error_count = 0;

    rst_n = 0;
    start = 0;
    clear = 0;

    repeat (3) @(posedge clk);

    rst_n = 1;


    @(negedge clk);
    start = 1;

    @(posedge clk);
    #1ps; // hold start_i high past posedge so RTL samples it before TB de-asserts
    start = 0;


    if (!active) begin
      $error("Counter not active after start");
      error_count++;
    end


    repeat (TIMEOUT_CYCLES)
      @(posedge clk);


    #1;

    if (!timeout) begin
      $error("Timeout not asserted");
      error_count++;
    end


    @(negedge clk);

    clear = 1;

    @(posedge clk);

    #1;

    clear = 0;


    if (timeout || active) begin
      $error("Clear failed");
      error_count++;
    end


    if (error_count == 0)
      $display("TIMEOUT COUNTER TEST: PASS");
    else begin
      $display("TIMEOUT COUNTER TEST: FAIL errors=%0d",
               error_count);
      $fatal(1);
    end

    $finish;

  end

endmodule