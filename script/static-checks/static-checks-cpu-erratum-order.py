#!/usr/bin/env python3
#
# Copyright (c) 2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

import argparse
import os
import re
import subprocess
import sys
import logging
from pathlib import Path


def subprocess_run(cmd, **kwargs):
    logging.debug("Running command: %r %r", cmd, kwargs)
    return subprocess.run(cmd, **kwargs)


def parse_workarounds(filepath: str):
    """
    Parse the file line by line. For every start marker ('workaround_reset_start'
    or 'workaround_runtime_start'), we look for its matching end marker
    ('workaround_reset_end' or 'workaround_runtime_end').

    If a start is missing its end, or if we find an end with no corresponding
    start, set error value to True which is to be returned as a tuple along with
    the list of dictionaries.

    Returns:
        A list of dictionaries. Each dictionary has:
            - start_line: line number of the workaround start
            - end_line: line number of the matching workaround end
            - marker_type: 'reset' or 'runtime'
            - erratum_number: integer if it's an ERRATUM (from ERRATUM(X)), else None
            - cve_year: integer if it's a CVE, else None
            - cve_number: integer if it's a CVE, else None
        Error value set to True if we fail to match workaround start to an end.
    """

    # Read all lines in memory
    with open(filepath, "r") as f:
        lines = f.readlines()

    # We'll keep a stack of active "starts" that haven't yet found their "end"
    start_stack = []
    results = []
    error = False

    # Regex patterns for capturing ERRATUM and CVE
    # Example: ERRATUM(123) or CVE-2022-789
    erratum_pattern = re.compile(r"ERRATUM\s*\(\s*(\d+)\s*\)", re.IGNORECASE)
    cve_pattern = re.compile(r"CVE[-_:]?(\d{4})[-_:]?(\d+)", re.IGNORECASE)

    for i, line in enumerate(lines, start=1):
        stripped = line.strip()

        # ----------------------------------------------------------------------
        # 1) Check for "start" markers
        #    We look first for 'workaround_reset_start' or 'workaround_runtime_start'
        # ----------------------------------------------------------------------
        if "workaround_reset_start" in stripped:
            marker_type = "reset"
            # Attempt to extract ERRATUM or CVE
            erratum_match = erratum_pattern.search(stripped)
            cve_match = cve_pattern.search(stripped)

            if erratum_match:
                erratum_number = int(erratum_match.group(1))
                cve_year, cve_number = None, None
            elif cve_match:
                erratum_number = None
                cve_year = int(cve_match.group(1))
                cve_number = int(cve_match.group(2))
            else:
                error |= True
                logging.error(
                    f"Couldn't find a valid Errata number or CVE year "
                    f"in marker type {marker_type} in line number {i}"
                )
                return results, error

            # Push onto the stack
            start_stack.append({
                "start_line": i,
                "marker_type": marker_type,      # 'reset'
                "erratum_number": erratum_number,
                "cve_year": cve_year,
                "cve_number": cve_number
            })

        elif "workaround_runtime_start" in stripped:
            marker_type = "runtime"
            # Attempt to extract ERRATUM or CVE
            erratum_match = erratum_pattern.search(stripped)
            cve_match = cve_pattern.search(stripped)

            if erratum_match:
                erratum_number = int(erratum_match.group(1))
                cve_year, cve_number = None, None
            elif cve_match:
                erratum_number = None
                cve_year = int(cve_match.group(1))
                cve_number = int(cve_match.group(2))
            else:
                error |= True
                logging.error(
                    f"Couldn't find a valid Errata number or CVE year "
                    f"in marker type {marker_type} in line number {i}"
                )
                return results, error

            # Push onto the stack
            start_stack.append({
                "start_line": i,
                "marker_type": marker_type,      # 'runtime'
                "erratum_number": erratum_number,
                "cve_year": cve_year,
                "cve_number": cve_number
            })

        # ----------------------------------------------------------------------
        # 2) Check for "end" markers
        #    We look for 'workaround_reset_end' or 'workaround_runtime_end'
        # ----------------------------------------------------------------------
        elif "workaround_reset_end" in stripped:
            # Attempt to pop the most recent start
            if not start_stack:
                logging.error(
                    f"[Line {i}] Found 'workaround_reset_end' "
                    f"without matching 'workaround_reset_start'."
                )
                error |= True
                break

            # Pop the most recent start
            last_item = start_stack.pop()

            # Check the marker type
            if last_item["marker_type"] != "reset":
                error = True
                logging.error(
                    f"[Line {i}] Found 'workaround_reset_end' "
                    f"that does not match "
                    f"the most recent '{last_item['marker_type']}' "
                    f"start at line {last_item['start_line']}."
                )
                error |= True
                break

            last_item["end_line"] = i
            results.append(last_item)

        elif "workaround_runtime_end" in stripped:
            # We need a matching "runtime" start
            if not start_stack:
                logging.error(
                    f"[Line {i}] Found 'workaround_runtime_end' "
                    f"without matching start."
                )
                error |= True
                break

            # Pop the most recent start
            last_item = start_stack.pop()

            # Check the marker type
            if last_item["marker_type"] != "runtime":
                logging.error(
                    f"[Line {i}] Found 'workaround_runtime_end' "
                    f"that does not match "
                    f"the most recent '{last_item['marker_type']}' "
                    f"start at line {last_item['start_line']}."
                )
                error |= True
                break

            last_item["end_line"] = i
            results.append(last_item)

    # ----------------------------------------------------------------------
    # After processing all lines, if the stack is not empty, it means some
    # starts have no matching ends
    # ----------------------------------------------------------------------
    if start_stack:
        first_unmatched = start_stack[0]
        logging.error(
            f"'workaround_{first_unmatched[1]}_start' "
            f"at line {first_unmatched[0]} "
            f"did not have a matching end marker."
        )

    return results, error


def check_ascending_order(data):
    """
    Ensures that:
      1) All ERRATUM blocks appear first (in ascending order of their erratum_number),
      2) Then all CVE blocks appear (in ascending order of their cve_year and if the
            year is the same, ascending by cve_number as well).

    Returns:
    False, If an ERRATUM appears after a CVE has started, or if the ordering within
    ERRATUMs or CVEs is incorrect, else returns True.
    """

    # Sort everything by the line number where the workaround starts
    data_sorted = sorted(data, key=lambda x: x["start_line"])

    # We'll gather ERRATUM items first, in the order they appear,
    # then CVE items. If we ever see an ERRATUM after we've started
    # collecting CVEs, we'll raise an error.
    found_cve = False
    errata_list = []
    cve_list = []

    for item in data_sorted:
        # Is this entry an ERRATUM or a CVE?
        if item["erratum_number"] is not None:  # This is an ERRATUM
            if found_cve:
                # We already encountered a CVE, so no more ERRATUMs allowed
                logging.error(
                    f"ERRATUM({item['erratum_number']}) found "
                    f"at line {item['start_line']} "
                    f"after the first CVE has already appeared."
                )
                return False
            errata_list.append(item)
        elif item["cve_year"] is not None:      # This is a CVE
            found_cve = True
            cve_list.append(item)
        else:
            # If neither erratum_number nor cve_year is present
            # return False to fail the check.
            logging.error(
                f"ERRATUM or CVE year not found at "
                f"line {item['start_line']}"
                )
            return False

    # -------------------------------------------------------------
    # 1) Check ascending order of ERRATUM IDs
    # -------------------------------------------------------------
    prev_erratum = 0
    for erratum_item in errata_list:
        eno = erratum_item["erratum_number"]
        if prev_erratum and eno < prev_erratum:
            logging.error(
                f"ERRATUM IDs are not in ascending order! "
                f"Found ERRATUM({eno}) "
                f"after ERRATUM({prev_erratum})."
            )
            return False
        prev_erratum = eno

    # -------------------------------------------------------------
    # 2) Check CVE year (and then CVE number) are ascending
    # -------------------------------------------------------------
    prev_cve_year = 0
    prev_cve_number = 0
    for cve_item in cve_list:
        year = cve_item["cve_year"]
        num = cve_item["cve_number"]

        if prev_cve_year and year < prev_cve_year:
            logging.error(
                f"CVE years are not in ascending order! "
                f"Found CVE({year},...) "
                f"after CVE({prev_cve_year},...)."
            )
            return False
        elif year == prev_cve_year:
        # Years match, so check if this CVE number < previous CVE number
            if num < prev_cve_number:
                logging.error(
                    f"CVE Numbers are not in ascending order! "
                    f"Found CVE({year, num} ,...) "
                    f"after CVE({prev_cve_year, prev_cve_number},...)."
                )
                return False

        # Update previous references
        prev_cve_year = year
        prev_cve_number = num

    # If we reach here, then the ordering is correct return True.
    return True


def patch_has_cpu_files(base_commit, end_commit):
    """Get the output of a git diff and analyse each modified file."""

    # Get patches of the affected commits with one line of context.
    gitdiff = subprocess_run(
        [
            "git",
            "diff",
            "--name-only",
            base_commit + ".." + end_commit,
            "lib/cpus/aarch64/"
        ],
        stdout=subprocess.PIPE,
    )

    if gitdiff.returncode != 0:
        return False

    cpu_files_modified = gitdiff.stdout.decode("utf-8").splitlines()
    return cpu_files_modified


def list_files_in_directory(dir_path):
    """
    Returns a list of files in the specified directory.
    Args:
    dir_path: The path to the directory.

    Returns:
        A list of file names in the directory.
    """
    try:
        files = [
            os.path.join(dir_path, f) for f in os.listdir(dir_path)
            if os.path.isfile(os.path.join(dir_path, f))
        ]
        return files
    except FileNotFoundError:
        return f"Directory not found: {dir_path}"
    except NotADirectoryError:
        return f"Not a directory: {dir_path}"
    except Exception as e:
        return f"An error occurred: {e}"


def parse_cmd_line(argv, prog_name):
    parser = argparse.ArgumentParser(
        prog=prog_name,
        formatter_class=argparse.RawTextHelpFormatter,
        description="Check alphabetical order of #includes",
        epilog="""
For each source file in the tree, checks that #include's C preprocessor
directives are ordered alphabetically (as mandated by the Trusted
Firmware coding style). System header includes must come before user
header includes.
""",
    )

    parser.add_argument(
        "--tree",
        "-t",
        help="Path to the source tree to check (default: %(default)s)",
        default=os.curdir,
    )
    parser.add_argument(
        "--patch",
        "-p",
        help="""
Patch mode.
Instead of checking all files in the source tree, the script will consider
only files that are modified by the latest patch(es).""",
        action="store_true",
    )
    parser.add_argument(
        "--from-ref",
        help="Base commit in patch mode (default: %(default)s)",
        default="master",
    )
    parser.add_argument(
        "--to-ref",
        help="Final commit in patch mode (default: %(default)s)",
        default="HEAD",
    )
    parser.add_argument(
        "--debug",
        help="Enable debug logging",
        action="store_true",
    )

    args = parser.parse_args(argv)
    return args


if __name__ == "__main__":
    args = parse_cmd_line(sys.argv[1:], sys.argv[0])

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    os.chdir(args.tree)

    if args.patch:
        logging.info(
            "Checking CPU files modified between patches "
            + args.from_ref
            + " and "
            + args.to_ref
            + "  ..."
        )
        list_cpu_files = patch_has_cpu_files(args.from_ref, args.to_ref)
        if not list_cpu_files:
            logging.info(f"No CPU files Modified")
            sys.exit(0)
    else:
        dir_path = "lib/cpus/aarch64/"
        logging.info(f"Checking all CPU files in directory `{dir_path}`")
        list_cpu_files = list_files_in_directory(dir_path)
        if not list_cpu_files:
            logging.error(f"`lib/cpus/aarch64/` directory is empty")
            sys.exit(1)

    failure = False
    for file in list_cpu_files:
            logging.info(f"Checking File {file} .....")
            # 1. Parse the file for workaround blocks
            parsed_data, error = parse_workarounds(file)
            if error:
                failure |= True

            if args.debug:
                for entry in parsed_data:
                    logging.debug(entry)

            if not parsed_data:
                logging.info(f"No Workarounds found in {file}.")
                continue

            # 2. Check ascending order of Erratum IDs and CVE years
            if check_ascending_order(parsed_data):
                # 3. Print out if all is well
                logging.info(
                    f"Workarounds matched correctly, and Errata "
                    f"IDs and CVE's are in ascending order.")
            else:
                logging.error(
                    f"Workarounds didn't match correctly, or Errata "
                    f"IDs and CVE's are not in ascending order.")
                failure |= True

    if failure:
        sys.exit(1)

    sys.exit(0)
