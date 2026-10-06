#!/usr/bin/env python3

import argparse
import subprocess
import sys
import time
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]

LOG_DIR = PROJECT_ROOT / "logs" / "regression"
LOG_DIR.mkdir(parents=True, exist_ok=True)


UNIT_TESTS = [
    "tlp_rx_parser_tb",
    "bar_decoder_tb",
    "endpoint_memory_tb",
    "request_handler_tb",
    "completion_engine_tb",
    "tlp_tx_formatter_tb",
    "outstanding_req_table_tb",
    "sync_fifo_tb",
    "timeout_counter_tb",
    "dma_regs_tb",
    "dma_read_engine_tb",
    "dma_write_engine_tb",
    "dma_controller_tb",
]


INTEGRATION_TESTS = [
    "smoke",
    "dma",
    "error",
]


UVM_TESTS = [
    "pcie_smoke_test",
    "pcie_dma_test",
    "pcie_error_test",
]


def run_command(command, name):
    print("=" * 70)
    print(f"RUNNING: {name}")
    print("=" * 70)

    start_time = time.time()

    result = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        universal_newlines=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    elapsed = time.time() - start_time

    log_file = LOG_DIR / f"{name}.log"

    log_file.write_text(result.stdout)

    passed = result.returncode == 0

    print(
        f"{name}: "
        f"{'PASS' if passed else 'FAIL'} "
        f"({elapsed:.2f}s)"
    )

    return {
        "name": name,
        "passed": passed,
        "returncode": result.returncode,
        "time": elapsed,
        "log": str(log_file),
    }


def run_unit_tests():
    results = []

    for test in UNIT_TESTS:

        command = [
            "./sim/vcs/run_unit.sh",
            test,
        ]

        results.append(
            run_command(
                command,
                f"unit_{test}",
            )
        )

    return results


def run_integration_tests():
    results = []

    for test in INTEGRATION_TESTS:

        command = [
            "./sim/vcs/run_integration.sh",
            test,
        ]

        results.append(
            run_command(
                command,
                f"integration_{test}",
            )
        )

    return results


def run_uvm_tests(seeds):
    results = []

    for test in UVM_TESTS:

        for seed in seeds:

            command = [
                "./sim/vcs/run_uvm.sh",
                test,
                str(seed),
            ]

            name = (
                f"uvm_{test}_seed_{seed}"
            )

            results.append(
                run_command(
                    command,
                    name,
                )
            )

    return results


def print_summary(results):
    print()
    print("=" * 70)
    print("PCIe ENDPOINT + DMA REGRESSION SUMMARY")
    print("=" * 70)

    passed = 0
    failed = 0

    for result in results:

        status = (
            "PASS"
            if result["passed"]
            else "FAIL"
        )

        print(
            f"{result['name']:<45} "
            f"{status:<6} "
            f"{result['time']:.2f}s"
        )

        if result["passed"]:
            passed += 1
        else:
            failed += 1

    print("-" * 70)

    print(f"TOTAL : {len(results)}")
    print(f"PASS  : {passed}")
    print(f"FAIL  : {failed}")

    print("=" * 70)

    return failed


def main():

    parser = argparse.ArgumentParser(
        description=(
            "PCIe Endpoint + DMA regression runner"
        )
    )

    parser.add_argument(
        "--unit",
        action="store_true",
        help="Run all unit tests",
    )

    parser.add_argument(
        "--integration",
        action="store_true",
        help="Run all integration tests",
    )

    parser.add_argument(
        "--uvm",
        action="store_true",
        help="Run all UVM tests",
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Run complete regression",
    )

    parser.add_argument(
        "--seeds",
        type=int,
        default=1,
        help="Number of UVM seeds",
    )

    parser.add_argument(
        "--start-seed",
        type=int,
        default=1,
        help="First UVM seed",
    )

    args = parser.parse_args()


    if not any(
        [
            args.unit,
            args.integration,
            args.uvm,
            args.all,
        ]
    ):
        parser.print_help()
        sys.exit(1)


    results = []


    if args.unit or args.all:
        results.extend(
            run_unit_tests()
        )


    if args.integration or args.all:
        results.extend(
            run_integration_tests()
        )


    if args.uvm or args.all:

        seeds = list(
            range(
                args.start_seed,
                args.start_seed
                + args.seeds,
            )
        )

        results.extend(
            run_uvm_tests(seeds)
        )


    failed = print_summary(results)


    if failed:
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()