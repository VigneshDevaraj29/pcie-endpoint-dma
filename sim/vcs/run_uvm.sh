#!/bin/bash

set -e


TEST=${1:-pcie_smoke_test}

SEED=${2:-1}


BUILD_DIR="sim/vcs/build/uvm"

LOG_DIR="logs/uvm"


mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"


echo "=========================================="
echo " UVM TEST"
echo " Test : $TEST"
echo " Seed : $SEED"
echo "=========================================="


vcs \
    -full64 \
    -sverilog \
    -ntb_opts uvm \
    -debug_access+all \
    -timescale=1ns/1ps \
    -f sim/filelists/uvm.f \
    -top tb_top \
    -o "$BUILD_DIR/simv" \
    -l "$LOG_DIR/${TEST}_compile.log"


echo ""
echo "Compilation complete."
echo "Running UVM simulation..."
echo ""


"$BUILD_DIR/simv" \
    +UVM_TESTNAME="$TEST" \
    +UVM_VERBOSITY=UVM_MEDIUM \
    +ntb_random_seed="$SEED" \
    -l "$LOG_DIR/${TEST}_seed_${SEED}.log"


echo ""
echo "=========================================="
echo " UVM TEST COMPLETE"
echo "=========================================="