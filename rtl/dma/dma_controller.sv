module dma_controller #(
  parameter int ADDR_WIDTH = 32
)(
  input  logic                    clk,
  input  logic                    rst_n,


  // ============================================================
  // DMA Configuration
  // ============================================================

  input  logic                    start_i,

  input  logic [ADDR_WIDTH-1:0]   src_addr_i,
  input  logic [ADDR_WIDTH-1:0]   dst_addr_i,

  input  logic [31:0]             length_bytes_i,


  // ============================================================
  // DMA Read Engine Interface
  // ============================================================

  output logic                    read_cmd_valid_o,
  input  logic                    read_cmd_ready_i,

  output logic [ADDR_WIDTH-1:0]   read_cmd_addr_o,

  input  logic                    read_done_i,
  input  logic                    read_error_i,

  input  logic [31:0]             read_data_i,


  // ============================================================
  // DMA Write Engine Interface
  // ============================================================

  output logic                    write_cmd_valid_o,
  input  logic                    write_cmd_ready_i,

  output logic [ADDR_WIDTH-1:0]   write_cmd_addr_o,

  output logic [31:0]             write_cmd_data_o,

  output logic [3:0]              write_cmd_byte_en_o,

  input  logic                    write_done_i,
  input  logic                    write_error_i,


  // ============================================================
  // DMA Status
  // ============================================================

  output logic                    busy_o,
  output logic                    done_o,
  output logic                    error_o
);


  // ============================================================
  // State Machine
  // ============================================================

  typedef enum logic [2:0] {

    ST_IDLE,
    ST_ISSUE_READ,
    ST_WAIT_READ,
    ST_ISSUE_WRITE,
    ST_WAIT_WRITE,
    ST_DONE,
    ST_ERROR

  } state_e;


  state_e state_q;
  state_e state_d;


  // ============================================================
  // DMA Transfer Registers
  // ============================================================

  logic [ADDR_WIDTH-1:0] src_addr_q;
  logic [ADDR_WIDTH-1:0] dst_addr_q;

  logic [31:0] remaining_bytes_q;

  logic [31:0] read_data_q;


  // ============================================================
  // Start Validation
  // ============================================================

  logic start_valid;


  always_comb begin

    start_valid =
      (length_bytes_i != 0) &&
      (length_bytes_i[1:0] == 2'b00) &&
      (src_addr_i[1:0] == 2'b00) &&
      (dst_addr_i[1:0] == 2'b00);

  end


  // ============================================================
  // Sequential Transfer State
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state_q <= ST_IDLE;

      src_addr_q <= '0;
      dst_addr_q <= '0;

      remaining_bytes_q <= '0;

      read_data_q <= '0;

    end
    else begin

      state_q <= state_d;


      // --------------------------------------------------------
      // Start New DMA Transfer
      // --------------------------------------------------------

      if (state_q == ST_IDLE &&
          start_i &&
          start_valid) begin

        src_addr_q <= src_addr_i;
        dst_addr_q <= dst_addr_i;

        remaining_bytes_q <= length_bytes_i;

      end


      // --------------------------------------------------------
      // Capture Read Completion Data
      // --------------------------------------------------------

      if (state_q == ST_WAIT_READ &&
          read_done_i) begin

        read_data_q <= read_data_i;

      end


      // --------------------------------------------------------
      // Advance to Next DWORD
      // --------------------------------------------------------

      if (state_q == ST_WAIT_WRITE &&
          write_done_i &&
          (remaining_bytes_q > 32'd4)) begin

        src_addr_q <= src_addr_q + 32'd4;
        dst_addr_q <= dst_addr_q + 32'd4;

        remaining_bytes_q <=
          remaining_bytes_q - 32'd4;

      end


      // --------------------------------------------------------
      // Last DWORD Finished
      // --------------------------------------------------------

      if (state_q == ST_WAIT_WRITE &&
          write_done_i &&
          (remaining_bytes_q <= 32'd4)) begin

        remaining_bytes_q <= '0;

      end

    end

  end


  // ============================================================
  // DMA Control FSM
  // ============================================================

  always_comb begin

    state_d = state_q;


    // ----------------------------------------------------------
    // Defaults
    // ----------------------------------------------------------

    busy_o  = 1'b1;
    done_o  = 1'b0;
    error_o = 1'b0;


    read_cmd_valid_o = 1'b0;
    read_cmd_addr_o  = src_addr_q;


    write_cmd_valid_o   = 1'b0;
    write_cmd_addr_o    = dst_addr_q;
    write_cmd_data_o    = read_data_q;
    write_cmd_byte_en_o = 4'b1111;


    case (state_q)


      // ========================================================
      // IDLE
      // ========================================================

      ST_IDLE: begin

        busy_o = 1'b0;


        if (start_i) begin

          if (start_valid)
            state_d = ST_ISSUE_READ;
          else
            state_d = ST_ERROR;

        end

      end


      // ========================================================
      // ISSUE PCIe MEMORY READ
      // ========================================================

      ST_ISSUE_READ: begin

        read_cmd_valid_o = 1'b1;
        read_cmd_addr_o  = src_addr_q;


        if (read_cmd_ready_i)
          state_d = ST_WAIT_READ;

      end


      // ========================================================
      // WAIT FOR READ COMPLETION
      // ========================================================

      ST_WAIT_READ: begin

        if (read_error_i)
          state_d = ST_ERROR;

        else if (read_done_i)
          state_d = ST_ISSUE_WRITE;

      end


      // ========================================================
      // ISSUE PCIe MEMORY WRITE
      // ========================================================

      ST_ISSUE_WRITE: begin

        write_cmd_valid_o = 1'b1;

        write_cmd_addr_o = dst_addr_q;
        write_cmd_data_o = read_data_q;

        write_cmd_byte_en_o = 4'b1111;


        if (write_cmd_ready_i)
          state_d = ST_WAIT_WRITE;

      end


      // ========================================================
      // WAIT FOR POSTED WRITE TO BE ACCEPTED
      // ========================================================

      ST_WAIT_WRITE: begin

        if (write_error_i)
          state_d = ST_ERROR;

        else if (write_done_i) begin

          if (remaining_bytes_q <= 32'd4)
            state_d = ST_DONE;

          else
            state_d = ST_ISSUE_READ;

        end

      end


      // ========================================================
      // COMPLETE
      // ========================================================

      ST_DONE: begin

        busy_o = 1'b0;
        done_o = 1'b1;

        state_d = ST_IDLE;

      end


      // ========================================================
      // ERROR
      // ========================================================

      ST_ERROR: begin

        busy_o  = 1'b0;
        error_o = 1'b1;

        state_d = ST_IDLE;

      end


      default: begin

        state_d = ST_IDLE;

      end

    endcase

  end


endmodule