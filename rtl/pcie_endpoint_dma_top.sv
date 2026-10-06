module pcie_endpoint_dma_top
  import pcie_tlp_pkg::*;
#(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,

  parameter logic [ADDR_WIDTH-1:0] BAR0_BASE_ADDR =
    32'h8000_0000,

  parameter int unsigned BAR0_SIZE_BYTES =
    4096,

  // BAR0 local map:
  //
  // 0x000 - 0x01F : DMA registers
  // 0x100 - ...   : Endpoint memory

  parameter int unsigned DMA_REG_SPACE_BYTES =
    32,

  parameter logic [ADDR_WIDTH-1:0] MEM_BASE_OFFSET =
    32'h0000_0100,

  parameter int unsigned ENDPOINT_MEM_SIZE_BYTES =
    2048,

  parameter int OUTSTANDING_ENTRIES =
    16,

  parameter int COMPLETION_TIMEOUT_CYCLES =
    1024,

  parameter logic [15:0] ENDPOINT_ID =
    16'h0100
)(
  input  logic                     clk,
  input  logic                     rst_n,


  // ============================================================
  // PCIe RX Interface
  //
  // Simplified 3DW Transaction Layer interface.
  // ============================================================

  input  logic                     rx_valid_i,
  output logic                     rx_ready_o,

  input  logic [31:0]              rx_dw0_i,
  input  logic [31:0]              rx_dw1_i,
  input  logic [31:0]              rx_dw2_i,

  input  logic                     rx_payload_valid_i,
  input  logic [DATA_WIDTH-1:0]    rx_payload_data_i,


  // ============================================================
  // PCIe TX Interface
  // ============================================================

  output logic                     tx_valid_o,
  input  logic                     tx_ready_i,

  output logic [31:0]              tx_dw0_o,
  output logic [31:0]              tx_dw1_o,
  output logic [31:0]              tx_dw2_o,

  output logic                     tx_payload_valid_o,
  output logic [DATA_WIDTH-1:0]    tx_payload_data_o,


  // ============================================================
  // Status / Debug
  // ============================================================

  output logic                     dma_busy_o,
  output logic                     dma_done_o,
  output logic                     dma_error_o,

  output logic                     unexpected_completion_o,

  output logic [$clog2(OUTSTANDING_ENTRIES+1)-1:0]
                                   outstanding_count_o,

  output logic                     tx_formatter_error_o
);


  // ============================================================
  // Local Constants
  // ============================================================

  localparam logic [ADDR_WIDTH-1:0] DMA_REG_END_ADDR =
    DMA_REG_SPACE_BYTES;

  localparam logic [ADDR_WIDTH-1:0] ENDPOINT_MEM_END_ADDR =
    MEM_BASE_OFFSET + ENDPOINT_MEM_SIZE_BYTES;


  // ============================================================
  // RX Parser Signals
  // ============================================================

  tlp_header_t parsed_header;
  tlp_kind_e   parsed_kind;

  logic        parsed_valid;
  logic        parsed_supported;


  logic        rx_fire;

  logic        incoming_mem_request;
  logic        incoming_completion;


  // ============================================================
  // BAR Decoder Signals
  // ============================================================

  logic                    bar_hit;
  logic                    bar_addr_error;

  logic [ADDR_WIDTH-1:0]   bar_local_addr;


  // ============================================================
  // Request Handler Signals
  // ============================================================

  logic                    request_handler_valid;
  logic                    request_handler_ready;
  logic                    request_handler_busy;


  logic                    handler_mem_req_valid;
  logic                    handler_mem_req_write;

  logic [ADDR_WIDTH-1:0]   handler_mem_local_addr;

  logic [DATA_WIDTH-1:0]   handler_mem_write_data;

  logic [(DATA_WIDTH/8)-1:0]
                           handler_mem_byte_en;

  logic                    handler_mem_req_ready;


  logic                    handler_mem_rsp_valid;

  logic [DATA_WIDTH-1:0]   handler_mem_read_data;

  logic                    handler_mem_addr_error;


  // ============================================================
  // Request Handler -> Completion Engine
  // ============================================================

  logic                    handler_cpl_req_valid;

  cpl_status_e             handler_cpl_status;

  logic                    handler_cpl_data_valid;

  logic [DATA_WIDTH-1:0]   handler_cpl_data;

  logic [15:0]             handler_cpl_requester_id;

  logic [TAG_WIDTH-1:0]    handler_cpl_tag;

  logic [6:0]              handler_cpl_lower_addr;


  // ============================================================
  // Completion Engine Signals
  // ============================================================

  logic                    completion_req_ready;


  logic                    completion_tx_valid;
  logic                    completion_tx_ready;

  tlp_header_t             completion_tx_header;

  logic                    completion_tx_payload_valid;

  logic [DATA_WIDTH-1:0]   completion_tx_payload_data;


  // ============================================================
  // Local Target Decode
  // ============================================================

  logic local_target_dma_regs;
  logic local_target_memory;
  logic local_target_invalid;


  // ============================================================
  // DMA Register Interface
  // ============================================================

  logic                    dma_cfg_valid;
  logic                    dma_cfg_write;

  logic [7:0]              dma_cfg_addr;

  logic [DATA_WIDTH-1:0]   dma_cfg_wdata;

  logic [(DATA_WIDTH/8)-1:0]
                           dma_cfg_be;


  logic                    dma_cfg_ready;

  logic                    dma_cfg_rsp_valid;

  logic [DATA_WIDTH-1:0]   dma_cfg_rdata;

  logic                    dma_cfg_error;


  logic [ADDR_WIDTH-1:0]   dma_src_addr;

  logic [ADDR_WIDTH-1:0]   dma_dst_addr;

  logic [31:0]             dma_length_bytes;

  logic                    dma_start_pulse;


  // ============================================================
  // Endpoint Memory Interface
  // ============================================================

  logic                    endpoint_mem_req_valid;

  logic                    endpoint_mem_req_write;

  logic [ADDR_WIDTH-1:0]   endpoint_mem_local_addr;

  logic [DATA_WIDTH-1:0]   endpoint_mem_write_data;

  logic [(DATA_WIDTH/8)-1:0]
                           endpoint_mem_byte_en;


  logic                    endpoint_mem_req_ready;

  logic                    endpoint_mem_rsp_valid;

  logic [DATA_WIDTH-1:0]   endpoint_mem_read_data;

  logic                    endpoint_mem_addr_error;


  // ============================================================
  // Invalid Local Target Response
  // ============================================================

  logic invalid_rsp_valid_q;


  // ============================================================
  // DMA Controller Signals
  // ============================================================

  logic                    dma_controller_busy;
  logic                    dma_controller_done;
  logic                    dma_controller_error;


  logic                    dma_read_cmd_valid;
  logic                    dma_read_cmd_ready;

  logic [ADDR_WIDTH-1:0]   dma_read_cmd_addr;


  logic                    dma_write_cmd_valid;
  logic                    dma_write_cmd_ready;

  logic [ADDR_WIDTH-1:0]   dma_write_cmd_addr;

  logic [31:0]             dma_write_cmd_data;

  logic [3:0]              dma_write_cmd_be;


  logic                    dma_read_done;
  logic                    dma_read_error;

  logic [31:0]             dma_read_data;


  logic                    dma_write_done;
  logic                    dma_write_error;


  // ============================================================
  // DMA Read Engine TX
  // ============================================================

  logic                    dma_read_tx_valid;
  logic                    dma_read_tx_ready;

  tlp_header_t             dma_read_tx_header;

  logic                    dma_read_tx_payload_valid;

  logic [31:0]             dma_read_tx_payload_data;

  logic                    dma_read_busy;


  // ============================================================
  // DMA Write Engine TX
  // ============================================================

  logic                    dma_write_tx_valid;
  logic                    dma_write_tx_ready;

  tlp_header_t             dma_write_tx_header;

  logic                    dma_write_tx_payload_valid;

  logic [31:0]             dma_write_tx_payload_data;

  logic                    dma_write_busy;


  // ============================================================
  // Outstanding Request Table
  // ============================================================

  logic                    outstanding_alloc_valid;
  logic                    outstanding_alloc_ready;

  logic [TAG_WIDTH-1:0]    outstanding_alloc_tag;

  logic [ADDR_WIDTH-1:0]   outstanding_alloc_address;

  logic [9:0]              outstanding_alloc_length;

  logic                    outstanding_alloc_duplicate;


  logic                    outstanding_cpl_valid;

  logic                    outstanding_cpl_match;

  logic                    outstanding_cpl_unexpected;

  logic [ADDR_WIDTH-1:0]   outstanding_matched_address;

  logic [9:0]              outstanding_matched_length;


  logic                    outstanding_cancel_valid;

  logic [TAG_WIDTH-1:0]    outstanding_cancel_tag;

  logic                    outstanding_cancel_match;


  logic                    outstanding_table_full;


  // ============================================================
  // TX Arbitration Signals
  // ============================================================

  logic                    arb_tx_valid;

  tlp_header_t             arb_tx_header;

  logic                    arb_tx_payload_valid;

  logic [DATA_WIDTH-1:0]   arb_tx_payload_data;


  logic                    formatter_input_ready;


  // ============================================================
  // TLP RX Parser
  // ============================================================

  tlp_rx_parser u_tlp_rx_parser (
    .tlp_valid_i          (rx_valid_i),

    .tlp_dw0_i            (rx_dw0_i),
    .tlp_dw1_i            (rx_dw1_i),
    .tlp_dw2_i            (rx_dw2_i),

    .parsed_valid_o       (parsed_valid),

    .supported_o          (parsed_supported),

    .header_o             (parsed_header),

    .kind_o               (parsed_kind)
  );


  // ============================================================
  // Incoming Packet Classification
  // ============================================================

  always_comb begin

    incoming_mem_request =
      (parsed_kind == TLP_KIND_MEM_RD) ||
      (parsed_kind == TLP_KIND_MEM_WR);


    incoming_completion =
      (parsed_kind == TLP_KIND_CPL) ||
      (parsed_kind == TLP_KIND_CPLD);

  end


  // ============================================================
  // RX Ready
  // ============================================================

  always_comb begin

    rx_ready_o = 1'b1;


    // ----------------------------------------------------------
    // Incoming Memory Requests
    // ----------------------------------------------------------

    if (incoming_mem_request) begin

      rx_ready_o =
        request_handler_ready &&
        completion_req_ready;


      // Memory Write requires payload in this simplified model.

      if (parsed_kind == TLP_KIND_MEM_WR)
        rx_ready_o =
          rx_ready_o &&
          rx_payload_valid_i;

    end


    // ----------------------------------------------------------
    // Incoming Completion
    // ----------------------------------------------------------

    else if (incoming_completion) begin

      rx_ready_o = 1'b1;

    end


    // ----------------------------------------------------------
    // Unsupported packets are consumed and discarded.
    // ----------------------------------------------------------

    else begin

      rx_ready_o = 1'b1;

    end

  end


  assign rx_fire =
    rx_valid_i &&
    rx_ready_o;


  // ============================================================
  // BAR0 Decoder
  // ============================================================

  bar_decoder #(
    .ADDR_WIDTH       (ADDR_WIDTH),
    .BAR0_BASE_ADDR   (BAR0_BASE_ADDR),
    .BAR0_SIZE_BYTES  (BAR0_SIZE_BYTES)
  ) u_bar_decoder (
    .req_valid_i      (
      rx_valid_i &&
      incoming_mem_request
    ),

    .address_i        (parsed_header.address),

    .bar_hit_o        (bar_hit),

    .addr_error_o     (bar_addr_error),

    .local_addr_o     (bar_local_addr)
  );


  // ============================================================
  // Request Handler Input
  // ============================================================

  assign request_handler_valid =
    rx_fire &&
    incoming_mem_request;


  // ============================================================
  // Request Handler
  // ============================================================

  request_handler #(
    .ADDR_WIDTH       (ADDR_WIDTH),
    .DATA_WIDTH       (DATA_WIDTH)
  ) u_request_handler (
    .clk               (clk),
    .rst_n             (rst_n),

    .req_valid_i       (request_handler_valid),

    .req_ready_o       (request_handler_ready),

    .header_i          (parsed_header),
    .kind_i            (parsed_kind),

    .payload_data_i    (rx_payload_data_i),

    .bar_hit_i         (bar_hit),
    .local_addr_i      (bar_local_addr),

    .mem_req_valid_o   (handler_mem_req_valid),
    .mem_req_write_o   (handler_mem_req_write),

    .mem_local_addr_o  (handler_mem_local_addr),

    .mem_write_data_o  (handler_mem_write_data),

    .mem_byte_en_o     (handler_mem_byte_en),

    .mem_req_ready_i   (handler_mem_req_ready),

    .mem_rsp_valid_i   (handler_mem_rsp_valid),

    .mem_read_data_i   (handler_mem_read_data),

    .mem_addr_error_i  (handler_mem_addr_error),

    .cpl_req_valid_o   (handler_cpl_req_valid),

    .cpl_status_o      (handler_cpl_status),

    .cpl_data_valid_o  (handler_cpl_data_valid),

    .cpl_data_o        (handler_cpl_data),

    .cpl_requester_id_o(
      handler_cpl_requester_id
    ),

    .cpl_tag_o         (handler_cpl_tag),

    .cpl_lower_addr_o  (
      handler_cpl_lower_addr
    ),

    .busy_o            (request_handler_busy)
  );


  // ============================================================
  // BAR0 Local Target Decode
  // ============================================================

  always_comb begin

    local_target_dma_regs = 1'b0;
    local_target_memory   = 1'b0;
    local_target_invalid  = 1'b0;


    if (handler_mem_local_addr <
        DMA_REG_END_ADDR) begin

      local_target_dma_regs = 1'b1;

    end


    else if (
      (handler_mem_local_addr >= MEM_BASE_OFFSET) &&
      (handler_mem_local_addr < ENDPOINT_MEM_END_ADDR)
    ) begin

      local_target_memory = 1'b1;

    end


    else begin

      local_target_invalid = 1'b1;

    end

  end


  // ============================================================
  // Local Request Ready MUX
  // ============================================================

  always_comb begin

    handler_mem_req_ready = 1'b0;


    if (local_target_dma_regs)
      handler_mem_req_ready =
        dma_cfg_ready;


    else if (local_target_memory)
      handler_mem_req_ready =
        endpoint_mem_req_ready;


    else if (local_target_invalid)
      handler_mem_req_ready =
        1'b1;

  end


  // ============================================================
  // DMA Register Routing
  // ============================================================

  assign dma_cfg_valid =
    handler_mem_req_valid &&
    local_target_dma_regs;


  assign dma_cfg_write =
    handler_mem_req_write;


  assign dma_cfg_addr =
    handler_mem_local_addr[7:0];


  assign dma_cfg_wdata =
    handler_mem_write_data;


  assign dma_cfg_be =
    handler_mem_byte_en;


  // ============================================================
  // DMA Registers
  // ============================================================

  dma_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH)
  ) u_dma_regs (
    .clk                (clk),
    .rst_n              (rst_n),

    .cfg_valid_i        (dma_cfg_valid),
    .cfg_write_i        (dma_cfg_write),

    .cfg_addr_i         (dma_cfg_addr),

    .cfg_wdata_i        (dma_cfg_wdata),
    .cfg_be_i           (dma_cfg_be),

    .cfg_ready_o        (dma_cfg_ready),

    .cfg_rsp_valid_o    (dma_cfg_rsp_valid),

    .cfg_rdata_o        (dma_cfg_rdata),

    .cfg_error_o        (dma_cfg_error),

    .dma_src_addr_o     (dma_src_addr),

    .dma_dst_addr_o     (dma_dst_addr),

    .dma_length_bytes_o (dma_length_bytes),

    .dma_start_pulse_o  (dma_start_pulse),

    .dma_busy_i         (dma_controller_busy),

    .dma_done_i         (dma_controller_done),

    .dma_error_i        (dma_controller_error)
  );


  // ============================================================
  // Endpoint Memory Routing
  // ============================================================

  assign endpoint_mem_req_valid =
    handler_mem_req_valid &&
    local_target_memory;


  assign endpoint_mem_req_write =
    handler_mem_req_write;


  assign endpoint_mem_local_addr =
    handler_mem_local_addr -
    MEM_BASE_OFFSET;


  assign endpoint_mem_write_data =
    handler_mem_write_data;


  assign endpoint_mem_byte_en =
    handler_mem_byte_en;


  // ============================================================
  // Endpoint Memory
  // ============================================================

  endpoint_memory #(
    .ADDR_WIDTH      (ADDR_WIDTH),
    .DATA_WIDTH      (DATA_WIDTH),
    .MEM_SIZE_BYTES  (ENDPOINT_MEM_SIZE_BYTES)
  ) u_endpoint_memory (
    .clk             (clk),
    .rst_n           (rst_n),

    .req_valid_i     (endpoint_mem_req_valid),

    .req_write_i     (endpoint_mem_req_write),

    .local_addr_i    (endpoint_mem_local_addr),

    .write_data_i    (endpoint_mem_write_data),

    .byte_en_i       (endpoint_mem_byte_en),

    .req_ready_o     (endpoint_mem_req_ready),

    .rsp_valid_o     (endpoint_mem_rsp_valid),

    .read_data_o     (endpoint_mem_read_data),

    .addr_error_o    (endpoint_mem_addr_error)
  );


  // ============================================================
  // Invalid Local Address Response
  // ============================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      invalid_rsp_valid_q <= 1'b0;

    end
    else begin

      invalid_rsp_valid_q <= 1'b0;


      if (
        handler_mem_req_valid &&
        handler_mem_req_ready &&
        local_target_invalid
      ) begin

        invalid_rsp_valid_q <= 1'b1;

      end

    end

  end


  // ============================================================
  // Local Response MUX
  // ============================================================

  always_comb begin

    handler_mem_rsp_valid  = 1'b0;

    handler_mem_read_data  = '0;

    handler_mem_addr_error = 1'b0;


    if (dma_cfg_rsp_valid) begin

      handler_mem_rsp_valid  =
        1'b1;

      handler_mem_read_data  =
        dma_cfg_rdata;

      handler_mem_addr_error =
        dma_cfg_error;

    end


    else if (endpoint_mem_rsp_valid) begin

      handler_mem_rsp_valid  =
        1'b1;

      handler_mem_read_data  =
        endpoint_mem_read_data;

      handler_mem_addr_error =
        endpoint_mem_addr_error;

    end


    else if (invalid_rsp_valid_q) begin

      handler_mem_rsp_valid  =
        1'b1;

      handler_mem_read_data  =
        '0;

      handler_mem_addr_error =
        1'b1;

    end

  end


  // ============================================================
  // Completion Engine
  // ============================================================

  completion_engine #(
    .DATA_WIDTH   (DATA_WIDTH),
    .COMPLETER_ID (ENDPOINT_ID)
  ) u_completion_engine (
    .clk                  (clk),
    .rst_n                (rst_n),

    .cpl_req_valid_i      (handler_cpl_req_valid),

    .cpl_req_ready_o      (completion_req_ready),

    .cpl_status_i         (handler_cpl_status),

    .cpl_data_valid_i     (handler_cpl_data_valid),

    .cpl_data_i           (handler_cpl_data),

    .requester_id_i       (
      handler_cpl_requester_id
    ),

    .tag_i                (handler_cpl_tag),

    .lower_addr_i         (
      handler_cpl_lower_addr
    ),

    .tx_valid_o           (completion_tx_valid),

    .tx_ready_i           (completion_tx_ready),

    .tx_header_o          (completion_tx_header),

    .tx_payload_valid_o   (
      completion_tx_payload_valid
    ),

    .tx_payload_data_o    (
      completion_tx_payload_data
    )
  );


  // ============================================================
  // DMA Controller
  // ============================================================

  dma_controller #(
    .ADDR_WIDTH (ADDR_WIDTH)
  ) u_dma_controller (
    .clk                 (clk),
    .rst_n               (rst_n),

    .start_i             (dma_start_pulse),

    .src_addr_i          (dma_src_addr),

    .dst_addr_i          (dma_dst_addr),

    .length_bytes_i      (dma_length_bytes),

    .read_cmd_valid_o    (dma_read_cmd_valid),

    .read_cmd_ready_i    (dma_read_cmd_ready),

    .read_cmd_addr_o     (dma_read_cmd_addr),

    .read_done_i         (dma_read_done),

    .read_error_i        (dma_read_error),

    .read_data_i         (dma_read_data),

    .write_cmd_valid_o   (dma_write_cmd_valid),

    .write_cmd_ready_i   (dma_write_cmd_ready),

    .write_cmd_addr_o    (dma_write_cmd_addr),

    .write_cmd_data_o    (dma_write_cmd_data),

    .write_cmd_byte_en_o (dma_write_cmd_be),

    .write_done_i        (dma_write_done),

    .write_error_i       (dma_write_error),

    .busy_o              (dma_controller_busy),

    .done_o              (dma_controller_done),

    .error_o             (dma_controller_error)
  );


  // ============================================================
  // Outstanding Completion Input
  // ============================================================

  assign outstanding_cpl_valid =
    rx_fire &&
    incoming_completion;


  // ============================================================
  // DMA Read Engine
  // ============================================================

  dma_read_engine #(
    .ADDR_WIDTH                (ADDR_WIDTH),

    .REQUESTER_ID              (ENDPOINT_ID),

    .COMPLETION_TIMEOUT_CYCLES (
      COMPLETION_TIMEOUT_CYCLES
    )
  ) u_dma_read_engine (
    .clk                 (clk),
    .rst_n               (rst_n),

    .cmd_valid_i         (dma_read_cmd_valid),

    .cmd_ready_o         (dma_read_cmd_ready),

    .cmd_address_i       (dma_read_cmd_addr),

    .alloc_valid_o       (outstanding_alloc_valid),

    .alloc_ready_i       (outstanding_alloc_ready),

    .alloc_duplicate_i   (
      outstanding_alloc_duplicate
    ),

    .alloc_tag_o         (outstanding_alloc_tag),

    .alloc_address_o     (
      outstanding_alloc_address
    ),

    .alloc_length_dw_o   (
      outstanding_alloc_length
    ),

    .cancel_valid_o      (
      outstanding_cancel_valid
    ),

    .cancel_tag_o        (
      outstanding_cancel_tag
    ),

    .tx_valid_o          (dma_read_tx_valid),

    .tx_ready_i          (dma_read_tx_ready),

    .tx_header_o         (dma_read_tx_header),

    .tx_payload_valid_o  (
      dma_read_tx_payload_valid
    ),

    .tx_payload_data_o   (
      dma_read_tx_payload_data
    ),

    .cpl_valid_i         (
      outstanding_cpl_valid
    ),

    .cpl_header_i        (parsed_header),

    .cpl_payload_valid_i (
      rx_payload_valid_i
    ),

    .cpl_payload_data_i  (
      rx_payload_data_i
    ),

    .read_done_o         (dma_read_done),

    .read_error_o        (dma_read_error),

    .read_data_o         (dma_read_data),

    .busy_o              (dma_read_busy)
  );


  // ============================================================
  // Outstanding Request Table
  // ============================================================

  outstanding_req_table #(
    .ADDR_WIDTH  (ADDR_WIDTH),

    .NUM_ENTRIES (OUTSTANDING_ENTRIES)
  ) u_outstanding_req_table (
    .clk                    (clk),
    .rst_n                  (rst_n),

    .alloc_valid_i          (
      outstanding_alloc_valid
    ),

    .alloc_ready_o          (
      outstanding_alloc_ready
    ),

    .alloc_tag_i            (
      outstanding_alloc_tag
    ),

    .alloc_address_i        (
      outstanding_alloc_address
    ),

    .alloc_length_dw_i      (
      outstanding_alloc_length
    ),

    .alloc_duplicate_o      (
      outstanding_alloc_duplicate
    ),

    .cpl_valid_i            (
      outstanding_cpl_valid
    ),

    .cpl_tag_i              (
      parsed_header.tag
    ),

    .cpl_match_o            (
      outstanding_cpl_match
    ),

    .cpl_unexpected_o       (
      outstanding_cpl_unexpected
    ),

    .matched_address_o      (
      outstanding_matched_address
    ),

    .matched_length_dw_o    (
      outstanding_matched_length
    ),

    .cancel_valid_i         (
      outstanding_cancel_valid
    ),

    .cancel_tag_i           (
      outstanding_cancel_tag
    ),

    .cancel_match_o         (
      outstanding_cancel_match
    ),

    .table_full_o           (
      outstanding_table_full
    ),

    .outstanding_count_o    (
      outstanding_count_o
    )
  );


  // ============================================================
  // DMA Write Engine
  // ============================================================

  dma_write_engine #(
    .ADDR_WIDTH   (ADDR_WIDTH),

    .REQUESTER_ID (ENDPOINT_ID)
  ) u_dma_write_engine (
    .clk                (clk),
    .rst_n              (rst_n),

    .cmd_valid_i        (dma_write_cmd_valid),

    .cmd_ready_o        (dma_write_cmd_ready),

    .cmd_address_i      (dma_write_cmd_addr),

    .cmd_data_i         (dma_write_cmd_data),

    .cmd_byte_en_i      (dma_write_cmd_be),

    .tx_valid_o         (dma_write_tx_valid),

    .tx_ready_i         (dma_write_tx_ready),

    .tx_header_o        (dma_write_tx_header),

    .tx_payload_valid_o (
      dma_write_tx_payload_valid
    ),

    .tx_payload_data_o  (
      dma_write_tx_payload_data
    ),

    .write_done_o       (dma_write_done),

    .write_error_o      (dma_write_error),

    .busy_o             (dma_write_busy)
  );


  // ============================================================
  // TX Arbitration
  //
  // Priority:
  //
  // 1. Endpoint Completions
  // 2. DMA Memory Reads
  // 3. DMA Memory Writes
  // ============================================================

  always_comb begin

    arb_tx_valid         = 1'b0;

    arb_tx_header        = '0;

    arb_tx_payload_valid = 1'b0;

    arb_tx_payload_data  = '0;


    completion_tx_ready = 1'b0;

    dma_read_tx_ready   = 1'b0;

    dma_write_tx_ready  = 1'b0;


    // ----------------------------------------------------------
    // Priority 1 : Completion
    // ----------------------------------------------------------

    if (completion_tx_valid) begin

      arb_tx_valid =
        completion_tx_valid;

      arb_tx_header =
        completion_tx_header;

      arb_tx_payload_valid =
        completion_tx_payload_valid;

      arb_tx_payload_data =
        completion_tx_payload_data;


      completion_tx_ready =
        formatter_input_ready;

    end


    // ----------------------------------------------------------
    // Priority 2 : DMA Read Request
    // ----------------------------------------------------------

    else if (dma_read_tx_valid) begin

      arb_tx_valid =
        dma_read_tx_valid;

      arb_tx_header =
        dma_read_tx_header;

      arb_tx_payload_valid =
        dma_read_tx_payload_valid;

      arb_tx_payload_data =
        dma_read_tx_payload_data;


      dma_read_tx_ready =
        formatter_input_ready;

    end


    // ----------------------------------------------------------
    // Priority 3 : DMA Write Request
    // ----------------------------------------------------------

    else if (dma_write_tx_valid) begin

      arb_tx_valid =
        dma_write_tx_valid;

      arb_tx_header =
        dma_write_tx_header;

      arb_tx_payload_valid =
        dma_write_tx_payload_valid;

      arb_tx_payload_data =
        dma_write_tx_payload_data;


      dma_write_tx_ready =
        formatter_input_ready;

    end

  end


  // ============================================================
  // TLP TX Formatter
  // ============================================================

  tlp_tx_formatter #(
    .DATA_WIDTH (DATA_WIDTH)
  ) u_tlp_tx_formatter (
    .tx_valid_i          (arb_tx_valid),

    .tx_ready_o          (formatter_input_ready),

    .header_i            (arb_tx_header),

    .payload_valid_i     (
      arb_tx_payload_valid
    ),

    .payload_data_i      (
      arb_tx_payload_data
    ),

    .tlp_valid_o         (tx_valid_o),

    .tlp_ready_i         (tx_ready_i),

    .tlp_dw0_o           (tx_dw0_o),

    .tlp_dw1_o           (tx_dw1_o),

    .tlp_dw2_o           (tx_dw2_o),

    .tlp_payload_valid_o (
      tx_payload_valid_o
    ),

    .tlp_payload_data_o  (
      tx_payload_data_o
    ),

    .formatter_error_o   (
      tx_formatter_error_o
    )
  );


  // ============================================================
  // Top-Level Status
  // ============================================================

  assign dma_busy_o =
    dma_controller_busy;


  assign dma_done_o =
    dma_controller_done;


  assign dma_error_o =
    dma_controller_error;


  assign unexpected_completion_o =
    outstanding_cpl_unexpected;


endmodule