
//
// PCIe top-level assertions
//
bind pcie_endpoint_dma_top pcie_assertions pcie_assertions_i (
  .clk                (clk),
  .rst_n              (rst_n),

  .rx_valid_i         (rx_valid_i),
  .rx_ready_i         (rx_ready_o),
  .rx_dw0_i           (rx_dw0_i),
  .rx_dw1_i           (rx_dw1_i),
  .rx_dw2_i           (rx_dw2_i),
  .rx_payload_valid_i (rx_payload_valid_i),

  .tx_valid_i         (tx_valid_o),
  .tx_ready_i         (tx_ready_i),
  .tx_dw0_i           (tx_dw0_o),
  .tx_dw1_i           (tx_dw1_o),
  .tx_dw2_i           (tx_dw2_o),
  .tx_payload_valid_i (tx_payload_valid_o)
);


//
// DMA controller assertions
//
bind dma_controller dma_assertions #(
  .ADDR_WIDTH(ADDR_WIDTH)
) dma_assertions_i (
  .clk                (clk),
  .rst_n              (rst_n),

  .start_i            (start_i),
  .src_addr_i         (src_addr_i),
  .dst_addr_i         (dst_addr_i),
  .length_bytes_i     (length_bytes_i),

  .busy_i             (busy_o),
  .done_i             (done_o),
  .error_i            (error_o),

  .read_cmd_valid_i   (read_cmd_valid_o),
  .read_cmd_ready_i   (read_cmd_ready_i),
  .read_cmd_addr_i    (read_cmd_addr_o),

  .write_cmd_valid_i  (write_cmd_valid_o),
  .write_cmd_ready_i  (write_cmd_ready_i),
  .write_cmd_addr_i   (write_cmd_addr_o),
  .write_cmd_data_i   (write_cmd_data_o)
);


//
// Outstanding-request/tag assertions
//
bind outstanding_req_table tag_assertions #(
  .NUM_ENTRIES(NUM_ENTRIES)
) tag_assertions_i (
  .clk                 (clk),
  .rst_n               (rst_n),

  .alloc_valid_i       (alloc_valid_i),
  .alloc_ready_i       (alloc_ready_o),
  .alloc_tag_i         (alloc_tag_i),
  .alloc_duplicate_i   (alloc_duplicate_o),

  .cpl_valid_i         (cpl_valid_i),
  .cpl_match_i         (cpl_match_o),
  .cpl_unexpected_i    (cpl_unexpected_o),
  .cpl_tag_i           (cpl_tag_i),

  .cancel_valid_i      (cancel_valid_i),
  .cancel_match_i      (cancel_match_o),
  .cancel_tag_i        (cancel_tag_i),

  .table_full_i        (table_full_o),
  .outstanding_count_i (outstanding_count_o)
);

