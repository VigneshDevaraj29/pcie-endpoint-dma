#!/bin/bash

set -e


if [ $# -ne 1 ]; then

    echo "Usage:"
    echo "  $0 smoke"
    echo "  $0 dma"
    echo "  $0 error"

    exit 1

fi


TEST=$1


case "$TEST" in

    smoke)

        FILELIST="sim/filelists/smoke_integration.f"

        TOP="pcie_endpoint_smoke_tb"

        ;;


    dma)

        FILELIST="sim/filelists/dma_integration.f"

        TOP="pcie_dma_integration_tb"

        ;;


    error)

        FILELIST="sim/filelists/error_integration.f"

        TOP="pcie_error_integration_tb"

        ;;


    *)

        echo "Unknown integration test: $TEST"
        exit 1

        ;;

esac


BUILD_DIR="sim/vcs/build/integration_${TEST}"

LOG_DIR="logs/integration"


mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"


echo "=========================================="
echo " INTEGRATION TEST"
echo " Test : $TEST"
echo " Top  : $TOP"
echo "=========================================="


vcs \
    -full64 \
    -sverilog \
    -debug_access+all \
    -timescale=1ns/1ps \
    -f "$FILELIST" \
    -top "$TOP" \
    -o "$BUILD_DIR/simv" \
    -l "$LOG_DIR/${TEST}_compile.log"


echo ""
echo "Running simulation..."
echo ""


"$BUILD_DIR/simv" \
    -l "$LOG_DIR/${TEST}_run.log"


echo ""
echo "=========================================="
echo " INTEGRATION TEST COMPLETE"
echo "=========================================="