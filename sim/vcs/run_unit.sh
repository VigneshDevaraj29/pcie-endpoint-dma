#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "  $0 <testbench_name>"
    echo ""
    echo "Example:"
    echo "  $0 tlp_rx_parser_tb"
    exit 1
fi


TEST=$1

TB_FILE="tb/sv/unit/${TEST}.sv"

BUILD_DIR="sim/vcs/build/${TEST}"

LOG_DIR="logs/unit"


if [ ! -f "$TB_FILE" ]; then
    echo "ERROR: Testbench not found:"
    echo "  $TB_FILE"
    exit 1
fi


mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"


echo "=========================================="
echo " UNIT TEST"
echo " Test : $TEST"
echo "=========================================="


vcs \
    -full64 \
    -sverilog \
    -debug_access+all \
    -timescale=1ns/1ps \
    -f sim/filelists/rtl.f \
    "$TB_FILE" \
    -top "$TEST" \
    -o "$BUILD_DIR/simv" \
    -l "$LOG_DIR/${TEST}_compile.log"


echo ""
echo "Compilation complete."
echo "Running simulation..."
echo ""


"$BUILD_DIR/simv" \
    -l "$LOG_DIR/${TEST}_run.log"


echo ""
echo "=========================================="
echo " UNIT TEST COMPLETE"
echo "=========================================="