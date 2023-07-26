#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

import argparse
import os
import re
import sys
import utils

# File extensions to check
VALID_FILE_EXTENSIONS = ('.c', '.S', '.h')

# Paths inside the tree to ignore. Hidden folders and files are always ignored.
# They mustn't end in '/'.
IGNORED_FOLDERS = (
    "tools",
    "docs"
)

# List of ignored files in folders that aren't ignored
IGNORED_FILES = ()

# Regular expression for searching the Banned APIs. This is taken from the
# Coding guideline in TF-A repo
BANNED_APIS = ["strcpy", "wcscpy", "strncpy", "strcat", "wcscat", "strncat",
               "sprintf", "vsprintf", "strtok", "atoi", "atol", "atoll",
               "itoa", "ltoa", "lltoa"]
BANNED_PATTERN = re.compile('\(|'.join(BANNED_APIS))

COMMENTS_PATTERN = re.compile(r"//|/\*|\*/")


def filter_comments(f):
    '''
    filter_comments(f) -> iterator for line number, filtered line

    Given an iterable of lines (such as a file), return another iterable of
    lines, with the comments filtered out and removed.
    '''

    in_comment = False
    for line_num, line in enumerate(f):
        line = line.rstrip('\n')

        temp = ""
        breaker = len(line) if in_comment else 0
        for match in COMMENTS_PATTERN.finditer(line):
            content = match.group(0)
            start, end = match.span()

            if in_comment:
                if content == "*/":
                    in_comment = False
                    breaker = end
            else:
                if content == "/*":
                    in_comment = True
                    temp += line[breaker:start]
                    breaker = len(line)
                elif content == "//":
                    temp += line[breaker:start]
                    breaker = len(line)
                    break

        temp += line[breaker:]
        if temp:
            yield line_num + 1, temp


def file_check_banned_api(path, encoding='utf-8'):
    '''
    Reads all lines from a file in path and checks for any banned APIs.
    The combined number of errors and uses of banned APIs is returned. If the
    result is equal to 0, the file is clean and contains no banned APIs.
    '''

    count = 0

    try:
        f = open(path, encoding=encoding)
    except FileNotFoundError:
        print("ERROR: could not open " + path)
        utils.print_exception_info()
        return True

    try:
        for line_num, line in filter_comments(f):
            match = BANNED_PATTERN.search(line)
            if match:
                location = "line {} of file {}".format(line_num, path)
                print("BANNED API: in " + location)

                # NOTE: this preview of the error is not perfect if comments
                # have been removed - however, it does good enough most of the
                # time.
                start, end = match.span()
                print(">>> {}".format(line))
                print("    {}^{}".format(start * " ", (end - start - 1) * "~"))

                count += 1
    except:
        print("ERROR: unexpected exception while parsing " + path)
        utils.print_exception_info()
        count += 1

    f.close()

    return count


def get_tree_files():
    '''
    Get all files in the git repository
    '''

    # Get patches of the affected commits with one line of context.
    (rc, stdout, stderr) = utils.shell_command(['git', 'ls-files'])
    if rc != 0:
        return False

    lines = stdout.splitlines()
    return lines


def get_patch_files(base_commit, end_commit):
    '''
    Get all files that have changed in a given patch
    '''

    # Get patches of the affected commits with one line of context.
    (rc, stdout, stderr) = utils.shell_command([
        'git', 'diff-tree', '--diff-filter=ACMRT', '-r', '--name-only',
        base_commit, end_commit])

    if rc != 0:
        return False

    paths = stdout.splitlines()
    return paths


def parse_cmd_line():
    parser = argparse.ArgumentParser(
        description="Check Banned APIs",
        epilog="""
            For each source file in the tree, checks whether Banned APIs as
            described in the list are used or not.
        """
    )

    parser.add_argument("--tree", "-t",
                        help="""
                        Path to the source tree to check (default: %(default)s)
                        """,
                        default=os.curdir)
    parser.add_argument("--patch", "-p",
                        help="""
                        Patch mode. Instead of checking all files in
                        the source tree, the script will consider only files
                        that are modified by the latest patch(es).
                        """,
                        action="store_true")
    parser.add_argument("--from-ref",
                        help="""
                        Base commit in patch mode (default: %(default)s)
                        """,
                        default="lts-v2.8")
    parser.add_argument("--to-ref",
                        help="""
                        Final commit in patch mode (default: %(default)s)
                        """,
                        default="HEAD")
    parser.add_argument("--verbose", "-v",
                        help="Print verbose output",
                        action="store_true")
    args = parser.parse_args()
    return args


if __name__ == "__main__":
    args = parse_cmd_line()

    os.chdir(args.tree)

    if args.patch:
        print("Checking files modified between patches " + args.from_ref +
              " and " + args.to_ref + "...\n")
        files = get_patch_files(args.from_ref, args.to_ref)
    else:
        print("Checking all files git repo " + os.path.abspath(args.tree) +
              "...\n")
        files = get_tree_files()

    total_errors = 0
    for filename in files:
        ignored = utils.file_is_ignored(filename, VALID_FILE_EXTENSIONS,
                                        IGNORED_FILES, IGNORED_FOLDERS)
        if ignored:
            if args.verbose:
                print("INFO: Skipping ignored file " + filename)
            continue

        if args.verbose:
            print("INFO: Checking " + filename)

        total_errors += file_check_banned_api(filename)

    print(str(total_errors) + " errors found")

    if total_errors == 0:
        sys.exit(0)
    else:
        sys.exit(1)
