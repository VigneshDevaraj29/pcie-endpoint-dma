#!/usr/bin/env python3

import argparse
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]


ERROR_PATTERNS = [
    r"UVM_ERROR\s*:\s*(\d+)",
    r"UVM_FATAL\s*:\s*(\d+)",
    r"\$error",
    r"TEST:\s*FAIL",
    r"TEST FAIL",
]


PASS_PATTERNS = [
    r"TEST:\s*PASS",
    r"TEST PASS",
    r"UVM_ERROR\s*:\s*0",
    r"UVM_FATAL\s*:\s*0",
]


def analyze_log(log_path):

    text = log_path.read_text(
        errors="ignore"
    )

    uvm_errors = 0
    uvm_fatals = 0


    error_match = re.findall(
        r"UVM_ERROR\s*:\s*(\d+)",
        text,
    )

    if error_match:
        uvm_errors = int(
            error_match[-1]
        )


    fatal_match = re.findall(
        r"UVM_FATAL\s*:\s*(\d+)",
        text,
    )

    if fatal_match:
        uvm_fatals = int(
            fatal_match[-1]
        )


    explicit_fail = bool(
        re.search(
            r"TEST\s*:\s*FAIL|TEST FAIL",
            text,
            re.IGNORECASE,
        )
    )


    explicit_pass = bool(
        re.search(
            r"TEST\s*:\s*PASS|TEST PASS",
            text,
            re.IGNORECASE,
        )
    )


    passed = (
        uvm_errors == 0
        and uvm_fatals == 0
        and not explicit_fail
    )


    return {
        "file": str(log_path),
        "passed": passed,
        "uvm_errors": uvm_errors,
        "uvm_fatals": uvm_fatals,
        "explicit_pass": explicit_pass,
    }


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--log-dir",
        default="logs",
        help="Directory containing logs",
    )

    args = parser.parse_args()


    log_dir = (
        PROJECT_ROOT / args.log_dir
    )


    if not log_dir.exists():

        print(
            f"Log directory not found: "
            f"{log_dir}"
        )

        return


    logs = sorted(
        log_dir.rglob("*.log")
    )


    if not logs:

        print("No log files found.")

        return


    print("=" * 80)
    print("PCIe ENDPOINT + DMA LOG SUMMARY")
    print("=" * 80)


    total = 0
    passed = 0
    failed = 0


    for log in logs:

        result = analyze_log(log)

        status = (
            "PASS"
            if result["passed"]
            else "FAIL"
        )


        relative = log.relative_to(
            PROJECT_ROOT
        )


        print(
            f"{str(relative):<55} "
            f"{status:<6} "
            f"ERR={result['uvm_errors']} "
            f"FATAL={result['uvm_fatals']}"
        )


        total += 1

        if result["passed"]:
            passed += 1
        else:
            failed += 1


    print("-" * 80)

    print(f"TOTAL LOGS : {total}")
    print(f"PASS       : {passed}")
    print(f"FAIL       : {failed}")

    print("=" * 80)


if __name__ == "__main__":
    main()