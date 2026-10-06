# ==============================================================
# PCIe Endpoint + DMA
# Coverage Helper Script
# ==============================================================

puts "=============================================="
puts " PCIe Endpoint + DMA Coverage"
puts "=============================================="

set project_name "pcie_endpoint_dma"

set coverage_dir "coverage"

set report_dir "$coverage_dir/reports"

file mkdir $coverage_dir
file mkdir $report_dir


puts "Project       : $project_name"
puts "Coverage Dir  : $coverage_dir"
puts "Report Dir    : $report_dir"


# --------------------------------------------------------------
# This script is intended to be used with VCS/URG-generated
# coverage databases.
#
# The actual coverage merge/report command will be driven by
# shell/Python automation.
# --------------------------------------------------------------


if {[file exists "$coverage_dir"]} {

    puts "Coverage directory exists."

} else {

    puts "Creating coverage directory."

    file mkdir "$coverage_dir"

}


puts ""
puts "Coverage types targeted:"
puts "  - Line"
puts "  - Condition"
puts "  - Toggle"
puts "  - FSM"
puts "  - Branch"
puts "  - Functional Coverage"
puts "  - Assertions"

puts ""
puts "Coverage setup complete."
puts "=============================================="