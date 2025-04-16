#!/usr/bin/env python3
#
# Copyright (c) 2019-2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# After lava job is dispatched, its results will be collected in
# $WORKSPACE/job_results.yaml file. Parse that file, and exit from this script
# with the respective exit status

import argparse
import os
import sys
import yaml


def report_job_failure():
    job_url = os.environ["JOB_URL"]
    build_number = os.environ["BUILD_NUMBER"]
    print()
    print("Job failed!")
    print("See " + "/".join([job_url.rstrip("/"), build_number, "artifact",
                             "job_output.log"]))
    print()
    sys.exit(1)


def report_job_success():
    print()
    print("Job success.")
    print()
    sys.exit(0)

def scmi_parse_phase(results, case, special_case, expected_skip_count):
    pass_count = 0
    fail_count = 0
    false_fail_count = 0
    skip_count = 0

    for phase in results:
        if phase["metadata"]["definition"] == case:
            if phase["metadata"]["result"] == "pass":
                pass_count += 1
            elif phase["metadata"]["result"] == "skip":
                skip_count += 1
            else:
                if special_case != "" and phase["metadata"]["case"] == special_case:
                    false_fail_count += 1
                else:
                    fail_count += 1

    print(case)
    print("pass_count " + str(pass_count))
    print("fail_count " + str(fail_count))
    if special_case != "":
        print("false_fail_count " + str(false_fail_count))
    print("skip_count " + str(skip_count) + " out of expected " + str(expected_skip_count))
    if (fail_count > 0) or (skip_count > expected_skip_count):
        report_job_failure()

def parse_scp_scmi_results():
    #
    # All protocols but sensor
    #
    all_prot_expected_skip_count = 9
    scmi_parse_phase(results, "scp-scmi-all-protocol", "", all_prot_expected_skip_count)

def parse_cmd_line():
    parser = argparse.ArgumentParser(description="Parse results from LAVA. "
        "The results must be provided as a YAML file.")
    parser.add_argument("--payload-type", default="linux", type=str,
        help="Type of payload that was used in the test (default: %(default)s)")
    parser.add_argument("--file",
        default=os.path.join(os.environ["WORKSPACE"], "job_results.yaml"),
        type=str, help="YAML file to parse (default: %(default)s)")
    args = parser.parse_args()
    return args


args = parse_cmd_line()

with open(args.file) as fd:
    results = yaml.safe_load(fd)

    # Iterate through results. Find the element whose name is "job" in the
    # "lava" suite. It contains the result of the overall LAVA run.
    for phase in results:
        if phase["name"] == "job" and phase["suite"] == "lava":
            break
    else:
        raise Exception("Couldn't find 'job' phase in 'lava' suite in results")

    if phase["result"] != "pass":
        report_job_failure()

    # If we've simply booted to the Linux shell prompt then we don't need to
    # further analyze the results from LAVA.
    if args.payload_type == "linux":
        report_job_success()

    # If we've run TFTF or SCMI tests instead, then do some further parsing.
    elif args.payload_type == "tftf":
        session = "TFTF"
        suite = "tftf"
    elif args.payload_type == "scp_tests_scmi":
        session = "SCMI"
        suite = "scp-scmi"
        parse_scp_scmi_results()

        print("All tests passed.")
        report_job_success()
    else:
        raise Exception("Payload not defined")

    # Then count the number of tests that failed/skipped.
    test_failures = 0
    test_skips = 0
    for phase in filter(lambda p: p["suite"] == suite, results):
        metadata = phase["metadata"]
        testcase_name = metadata["case"]
        testcase_result = metadata["result"]
        if testcase_result == "fail":
            test_failures += 1
            print("=> FAILED: " + testcase_name)
        elif testcase_result == "skip":
            test_skips += 1
            print("   SKIPPED: " + testcase_name)

    # Print a test summary
    print()
    if test_failures == 0 and test_skips == 0:
        print("All tests passed.")
    else:
        print("{} tests failed; {} skipped. All other tests passed.".format(
            test_failures, test_skips))

    if test_failures == 0:
        report_job_success()
    else:
        report_job_failure()
