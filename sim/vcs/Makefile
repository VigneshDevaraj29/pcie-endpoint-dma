.PHONY: \
	unit-parser \
	unit-bar \
	unit-memory \
	unit-request \
	unit-completion \
	unit-formatter \
	unit-outstanding \
	unit-fifo \
	unit-timeout \
	unit-dma-regs \
	unit-dma-read \
	unit-dma-write \
	unit-dma-controller \
	integration-smoke \
	integration-dma \
	integration-error \
	uvm-smoke \
	uvm-dma \
	uvm-error \
	clean


unit-parser:
	./sim/vcs/run_unit.sh tlp_rx_parser_tb

unit-bar:
	./sim/vcs/run_unit.sh bar_decoder_tb

unit-memory:
	./sim/vcs/run_unit.sh endpoint_memory_tb

unit-request:
	./sim/vcs/run_unit.sh request_handler_tb

unit-completion:
	./sim/vcs/run_unit.sh completion_engine_tb

unit-formatter:
	./sim/vcs/run_unit.sh tlp_tx_formatter_tb

unit-outstanding:
	./sim/vcs/run_unit.sh outstanding_req_table_tb

unit-fifo:
	./sim/vcs/run_unit.sh sync_fifo_tb

unit-timeout:
	./sim/vcs/run_unit.sh timeout_counter_tb

unit-dma-regs:
	./sim/vcs/run_unit.sh dma_regs_tb

unit-dma-read:
	./sim/vcs/run_unit.sh dma_read_engine_tb

unit-dma-write:
	./sim/vcs/run_unit.sh dma_write_engine_tb

unit-dma-controller:
	./sim/vcs/run_unit.sh dma_controller_tb


integration-smoke:
	./sim/vcs/run_integration.sh smoke

integration-dma:
	./sim/vcs/run_integration.sh dma

integration-error:
	./sim/vcs/run_integration.sh error


uvm-smoke:
	./sim/vcs/run_uvm.sh pcie_smoke_test

uvm-dma:
	./sim/vcs/run_uvm.sh pcie_dma_test

uvm-error:
	./sim/vcs/run_uvm.sh pcie_error_test


clean:
	rm -rf sim/vcs/build
	rm -rf csrc
	rm -rf simv
	rm -rf simv.daidir
	rm -rf ucli.key
	rm -rf DVEfiles
	rm -rf vc_hdrs.h