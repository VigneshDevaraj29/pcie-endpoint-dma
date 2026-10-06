module timeout_counter #(
  parameter int unsigned TIMEOUT_CYCLES = 1024
)(
  input  logic clk,
  input  logic rst_n,

  // Control
  input  logic start_i,
  input  logic clear_i,

  // Status
  output logic active_o,
  output logic timeout_o,

  output logic [$clog2(TIMEOUT_CYCLES+1)-1:0] count_o
);


  // ============================================================
  // Local Parameters
  // ============================================================

  localparam int COUNTER_WIDTH =
    (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES + 1);


  // ============================================================
  // Internal Signals
  // ============================================================

  logic [COUNTER_WIDTH-1:0] count_q;
  logic                     active_q;
  logic                     timeout_q;


  // ============================================================
  // Sequential Timeout Logic
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      count_q   <= '0;
      active_q  <= 1'b0;
      timeout_q <= 1'b0;

    end
    else begin

      // --------------------------------------------------------
      // Clear has highest priority
      // --------------------------------------------------------

      if (clear_i) begin

        count_q   <= '0;
        active_q  <= 1'b0;
        timeout_q <= 1'b0;

      end


      // --------------------------------------------------------
      // Start / Restart Counter
      // --------------------------------------------------------

      else if (start_i) begin

        count_q   <= '0;
        active_q  <= 1'b1;
        timeout_q <= 1'b0;

      end


      // --------------------------------------------------------
      // Active Timeout Counting
      // --------------------------------------------------------

      else if (active_q) begin

        if (count_q >= TIMEOUT_CYCLES - 1) begin

          count_q   <= count_q;
          active_q  <= 1'b0;
          timeout_q <= 1'b1;

        end
        else begin

          count_q <= count_q + 1'b1;

        end

      end

    end

  end


  // ============================================================
  // Outputs
  // ============================================================

  assign active_o  = active_q;
  assign timeout_o = timeout_q;
  assign count_o   = count_q;


endmodule