class dma_status_item extends uvm_sequence_item;

  logic dma_busy;
  logic dma_done;
  logic dma_error;

  logic unexpected_completion;

  int unsigned outstanding_count;

  logic tx_formatter_error;


  `uvm_object_utils_begin(dma_status_item)

    `uvm_field_int(dma_busy, UVM_DEFAULT)
    `uvm_field_int(dma_done, UVM_DEFAULT)
    `uvm_field_int(dma_error, UVM_DEFAULT)

    `uvm_field_int(
      unexpected_completion,
      UVM_DEFAULT
    )

    `uvm_field_int(
      outstanding_count,
      UVM_DEFAULT
    )

    `uvm_field_int(
      tx_formatter_error,
      UVM_DEFAULT
    )

  `uvm_object_utils_end


  function new(
    string name = "dma_status_item"
  );

    super.new(name);

  endfunction


endclass