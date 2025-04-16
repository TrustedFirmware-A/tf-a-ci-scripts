#!/usr/bin/env python3
#
# Copyright (c) 2019-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

"""
Check if a given file includes the copyright boiler plate.
This checker supports the following comment styles:
    /*
    *
    //
    #
"""

import argparse
import datetime
import collections
import fnmatch
import shlex
import os
import re
import sys
import utils
from itertools import islice

# File extensions to check
VALID_FILE_EXTENSIONS = ('.c', '.conf', '.dts', '.dtsi', '.editorconfig',
                         '.h', '.i', '.ld', 'Makefile', '.mk', '.msvc',
                         '.py', '.S', '.scat', '.sh', '.rs')

# Paths inside the tree to ignore. Hidden folders and files are always ignored.
# They mustn't end in '/'.
IGNORED_FOLDERS = (
    'include/lib/hob',
    'include/lib/libfdt',
    'lib/compiler-rt',
    'lib/hob',
    'lib/libfdt',
    'lib/zlib'
)

# List of ignored files in folders that aren't ignored
IGNORED_FILES = (
    'include/tools_share/uuid.h'
)

# Supported comment styles (Python regex)
COMMENT_PATTERN = '(\*|/\*|\#|//)'

# Any combination of spaces and/or tabs
SPACING = '[ \t]*'

# Line must start with a comment and optional spacing
LINE_START = '^' + SPACING + COMMENT_PATTERN + SPACING

# Line end with optional spacing
EOL = SPACING + '$'

# Year or period as YYYY or YYYY-YYYY
TIME_PERIOD = '[0-9]{4}(-[0-9]{4})?'

# Any string with valid license ID, don't allow adding postfix
LICENSE_ID = '.*(BSD-3-Clause|BSD-2-Clause-FreeBSD|MIT)([ ,.\);].*)?'

# File must contain both lines to pass the check
COPYRIGHT_LINE = LINE_START + 'Copyright' + '.*' + TIME_PERIOD + '.*' + EOL
LICENSE_ID_LINE = LINE_START + 'SPDX-License-Identifier:' + LICENSE_ID + EOL

# Compiled license patterns
COPYRIGHT_PATTERN = re.compile(COPYRIGHT_LINE, re.MULTILINE)
LICENSE_ID_PATTERN = re.compile(LICENSE_ID_LINE, re.MULTILINE)

CURRENT_YEAR = str(datetime.datetime.now().year)

COPYRIGHT_OK = 0
COPYRIGHT_ERROR = 1

def check_copyright(path, args, encoding='utf-8'):
    '''Checks a file for a correct copyright header.'''

    result = COPYRIGHT_OK

    with open(path, encoding=encoding) as file_:
        file_content = file_.read()

    copyright_line = COPYRIGHT_PATTERN.search(file_content)
    if not copyright_line:
        print("ERROR: Missing copyright in " + file_.name)
        result = COPYRIGHT_ERROR
    elif CURRENT_YEAR not in copyright_line.group():
        print("WARNING: Copyright is out of date in " + file_.name + ": '" +
              copyright_line.group() + "'")

    if not LICENSE_ID_PATTERN.search(file_content):
        print("ERROR: License ID error in " + file_.name)
        result = COPYRIGHT_ERROR

    return result

def main(args):
    print("Checking the copyrights in the code...")

    if args.verbose:
        print ("Copyright regexp: " + COPYRIGHT_LINE)
        print ("License regexp: " + LICENSE_ID_LINE)

    if args.patch:
        print("Checking files added between patches " + args.from_ref
              + " and " + args.to_ref + "...")

        (rc, stdout, stderr) = utils.shell_command(['git', 'diff',
            '--diff-filter=ACRT', '--name-only', args.from_ref, args.to_ref ])
        if rc:
            return COPYRIGHT_ERROR

        files = stdout.splitlines()

    else:
        print("Checking all files tracked by git...")

        (rc, stdout, stderr) = utils.shell_command([ 'git', 'ls-files' ])
        if rc:
            return COPYRIGHT_ERROR

        files = stdout.splitlines()

    count_ok = 0
    count_warning = 0
    count_error = 0

    for f in files:

        if utils.file_is_ignored(f, VALID_FILE_EXTENSIONS, IGNORED_FILES, IGNORED_FOLDERS):
            if args.verbose:
                print("Ignoring file " + f)
            continue

        if args.verbose:
            print("Checking file " + f)

        rc = check_copyright(f, args)

        if rc == COPYRIGHT_OK:
            count_ok += 1
        elif rc == COPYRIGHT_ERROR:
            count_error += 1

    print("\nSummary:")
    print("\t{} files analyzed".format(count_ok + count_error))

    if count_error == 0:
        print("\tNo errors found")
        return COPYRIGHT_OK
    else:
        print("\t{} errors found".format(count_error))
        return COPYRIGHT_ERROR

def parse_cmd_line(argv, prog_name):
    parser = argparse.ArgumentParser(
        prog=prog_name,
        formatter_class=argparse.RawTextHelpFormatter,
        description="Check copyright of all files of codebase",
        epilog="""
For each source file in the tree, checks that the copyright header
has the correct format.
""")

    parser.add_argument("--tree", "-t",
                        help="Path to the source tree to check (default: %(default)s)",
                        default=os.curdir)

    parser.add_argument("--verbose", "-v",
                        help="Increase verbosity to the source tree to check (default: %(default)s)",
                        action='store_true', default=False)

    parser.add_argument("--patch", "-p",
                        help="""
Patch mode.
Instead of checking all files in the source tree, the script will consider
only files that are modified by the latest patch(es).""",
                        action="store_true")

    (rc, stdout, stderr) = utils.shell_command(['git', 'merge-base', 'HEAD', 'refs/remotes/origin/master'])
    if rc:
        print("Git merge-base command failed. Cannot determine base commit.")
        sys.exit(rc)
    merge_bases = stdout.splitlines()

    # This should not happen, but it's better to be safe.
    if len(merge_bases) > 1:
        print("WARNING: Multiple merge bases found. Using the first one as base commit.")

    parser.add_argument("--from-ref",
                        help="Base commit in patch mode (default: %(default)s)",
                        default=merge_bases[0])
    parser.add_argument("--to-ref",
                        help="Final commit in patch mode (default: %(default)s)",
                        default="HEAD")

    args = parser.parse_args(argv)
    return args


if __name__ == "__main__":
    args = parse_cmd_line(sys.argv[1:], sys.argv[0])

    os.chdir(args.tree)

    rc = main(args)

    sys.exit(rc)
