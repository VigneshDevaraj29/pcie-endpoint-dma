module request_handler
  import pcie_tlp_pkg::*;
#(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // ============================================================
  // Incoming Parsed PCIe Request
  // ============================================================

  input  logic                      req_valid_i,
  output logic                      req_ready_o,

  input  tlp_header_t               header_i,
  input  tlp_kind_e                 kind_i,

  // First payload DW for Memory Write
  input  logic [DATA_WIDTH-1:0]     payload_data_i,


  // ============================================================
  // BAR Decoder Inputs
  // ============================================================

  input  logic                      bar_hit_i,
  input  logic [ADDR_WIDTH-1:0]     local_addr_i,


  // ============================================================
  // Endpoint Memory Interface
  // ============================================================

  output logic                      mem_req_valid_o,
  output logic                      mem_req_write_o,

  output logic [ADDR_WIDTH-1:0]     mem_local_addr_o,
  output logic [DATA_WIDTH-1:0]     mem_write_data_o,
  output logic [(DATA_WIDTH/8)-1:0] mem_byte_en_o,

  input  logic                      mem_req_ready_i,

  input  logic                      mem_rsp_valid_i,
  input  logic [DATA_WIDTH-1:0]     mem_read_data_i,
  input  logic                      mem_addr_error_i,


  // ============================================================
  // Completion Request Interface
  //
  // Sent later to completion_engine.sv
  // ============================================================

  output logic                      cpl_req_valid_o,
  output cpl_status_e               cpl_status_o,

  output logic                      cpl_data_valid_o,
  output logic [DATA_WIDTH-1:0]     cpl_data_o,

  output logic [15:0]               cpl_requester_id_o,
  output logic [TAG_WIDTH-1:0]      cpl_tag_o,
  output logic [6:0]                cpl_lower_addr_o,


  // ============================================================
  // Status
  // ============================================================

  output logic                      busy_o
);


  // ============================================================
  // State Machine
  // ============================================================

  typedef enum logic [1:0] {

    ST_IDLE,
    ST_WAIT_MEM_RD,
    ST_WAIT_MEM_WR

  } state_e;


  state_e state_q;
  state_e state_d;


  // ============================================================
  // Stored Request Information
  //
  // Needed while waiting for a Memory Read response.
  // ============================================================

  logic [15:0]          saved_requester_id_q;
  logic [TAG_WIDTH-1:0] saved_tag_q;
  logic [6:0]           saved_lower_addr_q;


  logic save_read_info;


  // ============================================================
  // Sequential State / Request Storage
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state_q              <= ST_IDLE;

      saved_requester_id_q <= '0;
      saved_tag_q          <= '0;
      saved_lower_addr_q   <= '0;

    end
    else begin

      state_q <= state_d;


      if (save_read_info) begin

        saved_requester_id_q <= header_i.requester_id;
        saved_tag_q          <= header_i.tag;

        saved_lower_addr_q   <= header_i.address[6:0];

      end

    end

  end


  // ============================================================
  // Main Request Handling Logic
  // ============================================================

  always_comb begin

    // ----------------------------------------------------------
    // Defaults
    // ----------------------------------------------------------

    state_d = state_q;

    req_ready_o = 1'b0;
    busy_o      = 1'b1;


    // Memory defaults

    mem_req_valid_o  = 1'b0;
    mem_req_write_o  = 1'b0;

    mem_local_addr_o = '0;
    mem_write_data_o = '0;
    mem_byte_en_o    = '0;


    // Completion defaults

    cpl_req_valid_o     = 1'b0;
    cpl_status_o        = CPL_STATUS_SC;

    cpl_data_valid_o    = 1'b0;
    cpl_data_o          = '0;

    cpl_requester_id_o  = '0;
    cpl_tag_o           = '0;
    cpl_lower_addr_o    = '0;


    save_read_info = 1'b0;


    // ==========================================================
    // State Machine
    // ==========================================================

    case (state_q)


      // ========================================================
      // IDLE
      // ========================================================

      ST_IDLE: begin

        req_ready_o = 1'b1;
        busy_o      = 1'b0;


        if (req_valid_i) begin


          // ====================================================
          // MEMORY WRITE
          //
          // Posted transaction.
          // No PCIe completion is generated.
          // ====================================================

          if (kind_i == TLP_KIND_MEM_WR) begin

            if (bar_hit_i) begin

              mem_req_valid_o  = 1'b1;
              mem_req_write_o  = 1'b1;

              mem_local_addr_o = local_addr_i;
              mem_write_data_o = payload_data_i;

              mem_byte_en_o    = header_i.first_be;


              if (mem_req_ready_i) begin

                state_d = ST_WAIT_MEM_WR;

              end

            end

          end


          // ====================================================
          // MEMORY READ
          //
          // Non-posted transaction.
          // Completion with Data is required.
          // ====================================================

          else if (kind_i == TLP_KIND_MEM_RD) begin

            // --------------------------------------------------
            // Valid BAR address
            // --------------------------------------------------

            if (bar_hit_i) begin

              mem_req_valid_o  = 1'b1;
              mem_req_write_o  = 1'b0;

              mem_local_addr_o = local_addr_i;


              if (mem_req_ready_i) begin

                save_read_info = 1'b1;

                state_d = ST_WAIT_MEM_RD;

              end

            end


            // --------------------------------------------------
            // Invalid BAR address
            //
            // Generate Unsupported Request completion.
            // --------------------------------------------------

            else begin

              cpl_req_valid_o    = 1'b1;
              cpl_status_o       = CPL_STATUS_UR;

              cpl_data_valid_o   = 1'b0;
              cpl_data_o         = '0;

              cpl_requester_id_o = header_i.requester_id;
              cpl_tag_o          = header_i.tag;

              cpl_lower_addr_o   = header_i.address[6:0];

            end

          end

        end

      end


      // ========================================================
      // WAIT FOR MEMORY READ RESPONSE
      // ========================================================

      ST_WAIT_MEM_RD: begin

        busy_o = 1'b1;


        if (mem_rsp_valid_i) begin

          cpl_req_valid_o    = 1'b1;

          cpl_requester_id_o = saved_requester_id_q;
          cpl_tag_o          = saved_tag_q;
          cpl_lower_addr_o   = saved_lower_addr_q;


          // ----------------------------------------------------
          // Memory access error
          // ----------------------------------------------------

          if (mem_addr_error_i) begin

            cpl_status_o      = CPL_STATUS_CA;

            cpl_data_valid_o  = 1'b0;
            cpl_data_o        = '0;

          end


          // ----------------------------------------------------
          // Successful Memory Read
          // ----------------------------------------------------

          else begin

            cpl_status_o      = CPL_STATUS_SC;

            cpl_data_valid_o  = 1'b1;
            cpl_data_o        = mem_read_data_i;

          end


          state_d = ST_IDLE;

        end

      end


      // ========================================================
      // WAIT FOR MEMORY WRITE RESPONSE
      //
      // Memory Write is posted, therefore no PCIe completion
      // is generated.
      // ========================================================

      ST_WAIT_MEM_WR: begin

        busy_o = 1'b1;


        if (mem_rsp_valid_i) begin

          state_d = ST_IDLE;

        end

      end


      // ========================================================
      // DEFAULT
      // ========================================================

      default: begin

        state_d = ST_IDLE;

      end

    endcase

  end


endmodule