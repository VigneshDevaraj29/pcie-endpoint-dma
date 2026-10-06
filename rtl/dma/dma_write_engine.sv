module dma_write_engine
  import pcie_tlp_pkg::*;
#(
  parameter int ADDR_WIDTH = 32,

  parameter logic [15:0] REQUESTER_ID = 16'h0100
)(
  input  logic                     clk,
  input  logic                     rst_n,


  // ============================================================
  // DMA Write Command
  // ============================================================

  input  logic                     cmd_valid_i,
  output logic                     cmd_ready_o,

  input  logic [ADDR_WIDTH-1:0]    cmd_address_i,
  input  logic [31:0]              cmd_data_i,

  input  logic [3:0]               cmd_byte_en_i,


  // ============================================================
  // PCIe Memory Write Output
  // ============================================================

  output logic                     tx_valid_o,
  input  logic                     tx_ready_i,

  output tlp_header_t              tx_header_o,

  output logic                     tx_payload_valid_o,
  output logic [31:0]              tx_payload_data_o,


  // ============================================================
  // Status
  // ============================================================

  output logic                     write_done_o,
  output logic                     write_error_o,

  output logic                     busy_o
);


  // ============================================================
  // State Machine
  // ============================================================

  typedef enum logic [1:0] {

    ST_IDLE,
    ST_SEND,
    ST_DONE,
    ST_ERROR

  } state_e;


  state_e state_q;
  state_e state_d;


  // ============================================================
  // Command Registers
  // ============================================================

  logic [ADDR_WIDTH-1:0] address_q;

  logic [31:0] data_q;

  logic [3:0] byte_en_q;


  // ============================================================
  // Sequential Logic
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state_q <= ST_IDLE;

      address_q <= '0;
      data_q    <= '0;
      byte_en_q <= '0;

    end
    else begin

      state_q <= state_d;


      if (state_q == ST_IDLE &&
          cmd_valid_i &&
          cmd_ready_o) begin

        address_q <= cmd_address_i;
        data_q    <= cmd_data_i;
        byte_en_q <= cmd_byte_en_i;

      end

    end

  end


  // ============================================================
  // Main Control Logic
  // ============================================================

  always_comb begin

    state_d = state_q;


    // ----------------------------------------------------------
    // Defaults
    // ----------------------------------------------------------

    cmd_ready_o = 1'b0;

    busy_o = 1'b1;

    write_done_o  = 1'b0;
    write_error_o = 1'b0;


    tx_valid_o = 1'b0;

    tx_header_o = '0;

    tx_payload_valid_o = 1'b0;
    tx_payload_data_o  = '0;


    case (state_q)


      // ========================================================
      // IDLE
      // ========================================================

      ST_IDLE: begin

        cmd_ready_o = 1'b1;
        busy_o      = 1'b0;


        if (cmd_valid_i) begin

          if (cmd_address_i[1:0] != 2'b00)
            state_d = ST_ERROR;
          else
            state_d = ST_SEND;

        end

      end


      // ========================================================
      // SEND MEMORY WRITE
      //
      // Memory Write is POSTED.
      // No Completion is expected.
      // ========================================================

      ST_SEND: begin

        tx_valid_o = 1'b1;


        tx_header_o.fmt =
          TLP_FMT_3DW_DATA;

        tx_header_o.tlp_type =
          TLP_TYPE_MEM;

        tx_header_o.length_dw =
          10'd1;

        tx_header_o.requester_id =
          REQUESTER_ID;

        tx_header_o.tag =
          '0;

        tx_header_o.first_be =
          byte_en_q;

        tx_header_o.last_be =
          4'b0000;

        tx_header_o.address =
          address_q;


        tx_payload_valid_o = 1'b1;
        tx_payload_data_o  = data_q;


        if (tx_ready_i)
          state_d = ST_DONE;

      end


      // ========================================================
      // DONE
      // ========================================================

      ST_DONE: begin

        busy_o       = 1'b0;
        write_done_o = 1'b1;

        state_d = ST_IDLE;

      end


      // ========================================================
      // ERROR
      // ========================================================

      ST_ERROR: begin

        busy_o        = 1'b0;
        write_error_o = 1'b1;

        state_d = ST_IDLE;

      end


      default: begin

        state_d = ST_IDLE;

      end

    endcase

  end


endmodule