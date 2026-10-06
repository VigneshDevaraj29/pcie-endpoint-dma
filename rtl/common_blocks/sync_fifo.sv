module sync_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 16
)(
  input  logic                         clk,
  input  logic                         rst_n,

  // Write side
  input  logic                         wr_en_i,
  input  logic [WIDTH-1:0]             wr_data_i,

  // Read side
  input  logic                         rd_en_i,
  output logic [WIDTH-1:0]             rd_data_o,

  // Status
  output logic                         full_o,
  output logic                         empty_o,
  output logic [$clog2(DEPTH+1)-1:0]   count_o
);


  // ============================================================
  // Local Parameters
  // ============================================================

  localparam int PTR_WIDTH =
    (DEPTH <= 1) ? 1 : $clog2(DEPTH);


  // ============================================================
  // FIFO Storage
  // ============================================================

  logic [WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_WIDTH-1:0] wr_ptr_q;
  logic [PTR_WIDTH-1:0] rd_ptr_q;

  logic [$clog2(DEPTH+1)-1:0] count_q;


  // ============================================================
  // Status
  // ============================================================

  assign empty_o = (count_q == 0);

  assign full_o  = (count_q == DEPTH);

  assign count_o = count_q;


  // ============================================================
  // Read Data
  // ============================================================

  assign rd_data_o = mem[rd_ptr_q];


  // ============================================================
  // FIFO Control
  // ============================================================

  logic write_fire;
  logic read_fire;


  always_comb begin

    write_fire =
      wr_en_i && !full_o;

    read_fire =
      rd_en_i && !empty_o;

  end


  // ============================================================
  // Pointer Helper
  // ============================================================

  function automatic logic [PTR_WIDTH-1:0] next_ptr(
    input logic [PTR_WIDTH-1:0] ptr
  );

    if (ptr == DEPTH-1)
      next_ptr = '0;
    else
      next_ptr = ptr + 1'b1;

  endfunction


  // ============================================================
  // Sequential FIFO Logic
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;

    end
    else begin


      // --------------------------------------------------------
      // Write
      // --------------------------------------------------------

      if (write_fire) begin

        mem[wr_ptr_q] <= wr_data_i;

        wr_ptr_q <= next_ptr(wr_ptr_q);

      end


      // --------------------------------------------------------
      // Read
      // --------------------------------------------------------

      if (read_fire) begin

        rd_ptr_q <= next_ptr(rd_ptr_q);

      end


      // --------------------------------------------------------
      // Occupancy Counter
      // --------------------------------------------------------

      case ({write_fire, read_fire})

        2'b10:
          count_q <= count_q + 1'b1;

        2'b01:
          count_q <= count_q - 1'b1;

        2'b11:
          count_q <= count_q;

        default:
          count_q <= count_q;

      endcase

    end

  end


endmodule