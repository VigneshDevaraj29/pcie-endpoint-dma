module dma_regs #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input  logic                      clk,
  input  logic                      rst_n,

  // ============================================================
  // Local Register Interface
  // ============================================================

  input  logic                      cfg_valid_i,
  input  logic                      cfg_write_i,
  input  logic [7:0]                cfg_addr_i,

  input  logic [DATA_WIDTH-1:0]     cfg_wdata_i,
  input  logic [(DATA_WIDTH/8)-1:0] cfg_be_i,

  output logic                      cfg_ready_o,
  output logic                      cfg_rsp_valid_o,
  output logic [DATA_WIDTH-1:0]     cfg_rdata_o,
  output logic                      cfg_error_o,


  // ============================================================
  // DMA Configuration Outputs
  // ============================================================

  output logic [ADDR_WIDTH-1:0]     dma_src_addr_o,
  output logic [ADDR_WIDTH-1:0]     dma_dst_addr_o,

  output logic [31:0]               dma_length_bytes_o,

  output logic                      dma_start_pulse_o,


  // ============================================================
  // DMA Status Inputs
  // ============================================================

  input  logic                      dma_busy_i,
  input  logic                      dma_done_i,
  input  logic                      dma_error_i
);


  // ============================================================
  // Register Address Map
  // ============================================================

  localparam logic [7:0] REG_SRC_ADDR = 8'h00;
  localparam logic [7:0] REG_DST_ADDR = 8'h04;
  localparam logic [7:0] REG_LENGTH   = 8'h08;
  localparam logic [7:0] REG_CONTROL  = 8'h0C;
  localparam logic [7:0] REG_STATUS   = 8'h10;


  // CONTROL
  //
  // bit 0 = START
  // bit 1 = CLEAR STATUS
  //
  // STATUS
  //
  // bit 0 = BUSY
  // bit 1 = DONE
  // bit 2 = ERROR


  // ============================================================
  // Internal Registers
  // ============================================================

  logic [ADDR_WIDTH-1:0] src_addr_q;
  logic [ADDR_WIDTH-1:0] dst_addr_q;

  logic [31:0] length_q;

  logic done_status_q;
  logic error_status_q;


  logic [DATA_WIDTH-1:0] read_data_d;
  logic                  address_valid_d;


  integer i;


  // ============================================================
  // Register Read Decode
  // ============================================================

  always_comb begin

    read_data_d    = '0;
    address_valid_d = 1'b1;

    case (cfg_addr_i)

      REG_SRC_ADDR: begin
        read_data_d = src_addr_q;
      end


      REG_DST_ADDR: begin
        read_data_d = dst_addr_q;
      end


      REG_LENGTH: begin
        read_data_d = length_q;
      end


      REG_CONTROL: begin
        read_data_d = '0;
      end


      REG_STATUS: begin

        read_data_d = '0;

        read_data_d[0] = dma_busy_i;
        read_data_d[1] = done_status_q;
        read_data_d[2] = error_status_q;

      end


      default: begin

        read_data_d     = '0;
        address_valid_d = 1'b0;

      end

    endcase

  end


  // ============================================================
  // Always Ready
  // ============================================================

  assign cfg_ready_o = 1'b1;


  // ============================================================
  // Register Update
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      src_addr_q <= '0;
      dst_addr_q <= '0;

      length_q <= '0;

      done_status_q  <= 1'b0;
      error_status_q <= 1'b0;

      dma_start_pulse_o <= 1'b0;

      cfg_rsp_valid_o <= 1'b0;
      cfg_rdata_o     <= '0;
      cfg_error_o     <= 1'b0;

    end
    else begin

      // --------------------------------------------------------
      // Defaults
      // --------------------------------------------------------

      dma_start_pulse_o <= 1'b0;

      cfg_rsp_valid_o <= 1'b0;
      cfg_error_o     <= 1'b0;


      // --------------------------------------------------------
      // Capture DMA Status
      // --------------------------------------------------------

      if (dma_done_i)
        done_status_q <= 1'b1;

      if (dma_error_i)
        error_status_q <= 1'b1;


      // --------------------------------------------------------
      // Register Access
      // --------------------------------------------------------

      if (cfg_valid_i && cfg_ready_o) begin

        cfg_rsp_valid_o <= 1'b1;
        cfg_error_o     <= !address_valid_d;


        // ======================================================
        // WRITE
        // ======================================================

        if (cfg_write_i && address_valid_d) begin

          case (cfg_addr_i)


            REG_SRC_ADDR: begin

              for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin

                if (cfg_be_i[i])
                  src_addr_q[i*8 +: 8]
                    <= cfg_wdata_i[i*8 +: 8];

              end

            end


            REG_DST_ADDR: begin

              for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin

                if (cfg_be_i[i])
                  dst_addr_q[i*8 +: 8]
                    <= cfg_wdata_i[i*8 +: 8];

              end

            end


            REG_LENGTH: begin

              for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin

                if (cfg_be_i[i])
                  length_q[i*8 +: 8]
                    <= cfg_wdata_i[i*8 +: 8];

              end

            end


            REG_CONTROL: begin

              // START

              if (cfg_be_i[0] &&
                  cfg_wdata_i[0] &&
                  !dma_busy_i) begin

                dma_start_pulse_o <= 1'b1;

                done_status_q  <= 1'b0;
                error_status_q <= 1'b0;

              end


              // CLEAR STATUS

              if (cfg_be_i[0] &&
                  cfg_wdata_i[1]) begin

                done_status_q  <= 1'b0;
                error_status_q <= 1'b0;

              end

            end


            default: begin
            end

          endcase

        end


        // ======================================================
        // READ
        // ======================================================

        else if (!cfg_write_i) begin

          cfg_rdata_o <= read_data_d;

        end

      end

    end

  end


  // ============================================================
  // Outputs
  // ============================================================

  assign dma_src_addr_o     = src_addr_q;
  assign dma_dst_addr_o     = dst_addr_q;
  assign dma_length_bytes_o = length_q;


endmodule