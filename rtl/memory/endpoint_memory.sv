module endpoint_memory #(
  parameter int ADDR_WIDTH     = 32,
  parameter int DATA_WIDTH     = 32,
  parameter int MEM_SIZE_BYTES = 4096
)(
  input  logic                      clk,
  input  logic                      rst_n,

  input  logic                      req_valid_i,
  input  logic                      req_write_i,

  input  logic [ADDR_WIDTH-1:0]     local_addr_i,
  input  logic [DATA_WIDTH-1:0]     write_data_i,
  input  logic [(DATA_WIDTH/8)-1:0] byte_en_i,

  output logic                      req_ready_o,

  output logic                      rsp_valid_o,
  output logic [DATA_WIDTH-1:0]     read_data_o,
  output logic                      addr_error_o
);


  // ============================================================
  // Memory Parameters
  // ============================================================

  localparam int BYTES_PER_WORD = DATA_WIDTH / 8;
  localparam int OFFSET_BITS    = $clog2(BYTES_PER_WORD);
  localparam int DEPTH          = MEM_SIZE_BYTES / BYTES_PER_WORD;
  localparam int INDEX_WIDTH    = $clog2(DEPTH);


  // ============================================================
  // Internal Memory
  // ============================================================

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  logic [INDEX_WIDTH-1:0] word_index;

  logic address_valid;
  logic address_aligned;


  // ============================================================
  // Address Decode
  // ============================================================

  always_comb begin

    word_index = local_addr_i[
      OFFSET_BITS + INDEX_WIDTH - 1 :
      OFFSET_BITS
    ];


    address_valid =
      (local_addr_i < MEM_SIZE_BYTES);


    address_aligned =
      (local_addr_i[OFFSET_BITS-1:0] == '0);

  end


  // ============================================================
  // Memory is always ready in this simplified model
  // ============================================================

  assign req_ready_o = 1'b1;


  // ============================================================
  // Read / Write Operation
  // ============================================================

  integer i;

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      rsp_valid_o  <= 1'b0;
      read_data_o  <= '0;
      addr_error_o <= 1'b0;

    end
    else begin

      // Default response values
      rsp_valid_o  <= 1'b0;
      addr_error_o <= 1'b0;


      if (req_valid_i && req_ready_o) begin

        // ------------------------------------------------------
        // Invalid / Unaligned Address
        // ------------------------------------------------------

        if (!address_valid || !address_aligned) begin

          rsp_valid_o  <= 1'b1;
          addr_error_o <= 1'b1;
          read_data_o  <= '0;

        end


        // ------------------------------------------------------
        // Memory Write
        // ------------------------------------------------------

        else if (req_write_i) begin

          for (i = 0; i < BYTES_PER_WORD; i = i + 1) begin

            if (byte_en_i[i]) begin

              mem[word_index][i*8 +: 8]
                <= write_data_i[i*8 +: 8];

            end

          end

          rsp_valid_o  <= 1'b1;
          addr_error_o <= 1'b0;

        end


        // ------------------------------------------------------
        // Memory Read
        // ------------------------------------------------------

        else begin

          read_data_o  <= mem[word_index];

          rsp_valid_o  <= 1'b1;
          addr_error_o <= 1'b0;

        end

      end

    end

  end


endmodule