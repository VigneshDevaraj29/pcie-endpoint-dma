module bar_decoder #(
  parameter int ADDR_WIDTH = 32,

  // BAR0 occupies 4 KB starting at 0x8000_0000
  parameter logic [ADDR_WIDTH-1:0] BAR0_BASE_ADDR = 32'h8000_0000,
  parameter int unsigned           BAR0_SIZE_BYTES = 4096
)(
  input  logic                  req_valid_i,
  input  logic [ADDR_WIDTH-1:0] address_i,

  output logic                  bar_hit_o,
  output logic                  addr_error_o,
  output logic [ADDR_WIDTH-1:0] local_addr_o
);


  logic [ADDR_WIDTH-1:0] bar0_end_addr;


  // ============================================================
  // BAR0 Address Range
  // ============================================================

  always_comb begin

    bar0_end_addr = BAR0_BASE_ADDR + BAR0_SIZE_BYTES;

  end


  // ============================================================
  // BAR Decode
  // ============================================================

  always_comb begin

    bar_hit_o    = 1'b0;
    addr_error_o = 1'b0;
    local_addr_o = '0;

    if (req_valid_i) begin

      if ((address_i >= BAR0_BASE_ADDR) &&
          (address_i <  bar0_end_addr)) begin

        bar_hit_o    = 1'b1;
        addr_error_o = 1'b0;

        // Convert PCIe address into endpoint-local offset
        local_addr_o = address_i - BAR0_BASE_ADDR;

      end
      else begin

        bar_hit_o    = 1'b0;
        addr_error_o = 1'b1;
        local_addr_o = '0;

      end

    end

  end


endmodule
