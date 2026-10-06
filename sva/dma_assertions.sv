module dma_assertions
#(
  parameter int ADDR_WIDTH = 32
)(
  input logic                  clk,
  input logic                  rst_n,

  input logic                  start_i,

  input logic [ADDR_WIDTH-1:0] src_addr_i,
  input logic [ADDR_WIDTH-1:0] dst_addr_i,

  input logic [31:0]           length_bytes_i,

  input logic                  busy_i,
  input logic                  done_i,
  input logic                  error_i,

  input logic                  read_cmd_valid_i,
  input logic                  read_cmd_ready_i,

  input logic [ADDR_WIDTH-1:0] read_cmd_addr_i,

  input logic                  write_cmd_valid_i,
  input logic                  write_cmd_ready_i,

  input logic [ADDR_WIDTH-1:0] write_cmd_addr_i,
  input logic [31:0]           write_cmd_data_i
);


  // ============================================================
  // DONE and ERROR Cannot Occur Together
  // ============================================================

  property p_done_error_exclusive;

    @(posedge clk)
    disable iff (!rst_n)

    !(done_i && error_i);

  endproperty


  a_done_error_exclusive:
    assert property (
      p_done_error_exclusive
    )
    else
      $error(
        "DMA ASSERTION: DONE and ERROR asserted together"
      );


  // ============================================================
  // DMA Commands Must Be DWORD-Aligned
  // ============================================================

  property p_read_address_aligned;

    @(posedge clk)
    disable iff (!rst_n)

    read_cmd_valid_i

    |->

    (read_cmd_addr_i[1:0] == 2'b00);

  endproperty


  a_read_address_aligned:
    assert property (
      p_read_address_aligned
    )
    else
      $error(
        "DMA ASSERTION: Unaligned read command"
      );


  property p_write_address_aligned;

    @(posedge clk)
    disable iff (!rst_n)

    write_cmd_valid_i

    |->

    (write_cmd_addr_i[1:0] == 2'b00);

  endproperty


  a_write_address_aligned:
    assert property (
      p_write_address_aligned
    )
    else
      $error(
        "DMA ASSERTION: Unaligned write command"
      );


  // ============================================================
  // Read Command Must Stay Stable Under Backpressure
  // ============================================================

  property p_read_cmd_stable;

    @(posedge clk)
    disable iff (!rst_n)

    read_cmd_valid_i &&
    !read_cmd_ready_i

    |=> (
      read_cmd_valid_i &&
      $stable(read_cmd_addr_i)
    );

  endproperty


  a_read_cmd_stable:
    assert property (
      p_read_cmd_stable
    )
    else
      $error(
        "DMA ASSERTION: Read command changed while stalled"
      );


  // ============================================================
  // Write Command Must Stay Stable Under Backpressure
  // ============================================================

  property p_write_cmd_stable;

    @(posedge clk)
    disable iff (!rst_n)

    write_cmd_valid_i &&
    !write_cmd_ready_i

    |=> (
      write_cmd_valid_i &&
      $stable(write_cmd_addr_i) &&
      $stable(write_cmd_data_i)
    );

  endproperty


  a_write_cmd_stable:
    assert property (
      p_write_cmd_stable
    )
    else
      $error(
        "DMA ASSERTION: Write command changed while stalled"
      );


  // ============================================================
  // Read and Write Command Should Not Be Issued Together
  // ============================================================

  property p_no_simultaneous_commands;

    @(posedge clk)
    disable iff (!rst_n)

    !(read_cmd_valid_i &&
      write_cmd_valid_i);

  endproperty


  a_no_simultaneous_commands:
    assert property (
      p_no_simultaneous_commands
    )
    else
      $error(
        "DMA ASSERTION: Read and write commands active together"
      );


  // ============================================================
  // Valid Start Configuration Must Be Aligned
  // ============================================================

  property p_start_alignment;

    @(posedge clk)
    disable iff (!rst_n)

    start_i &&
    (length_bytes_i != 0)

    |-> (
      src_addr_i[1:0] == 2'b00 &&
      dst_addr_i[1:0] == 2'b00
    );

  endproperty


  a_start_alignment:
    assert property (
      p_start_alignment
    )
    else
      $error(
        "DMA ASSERTION: DMA start address not DWORD aligned"
      );


endmodule