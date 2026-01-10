#
# Copyright (c) 2024, Arm Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# This script is used to account for differences between change log format
# produced by NodeJS module "standard-version" and format actually used
# by the TF-A LTS project.
#
import sys
import os
import re


TAIL_RE = rf"\(https://review.trustedfirmware.org/plugins/gitiles/{os.environ.get('GERRIT_PROJECT_PREFIX', '')}TF-A/trusted-firmware-a/\+/refs/tags/.+lts.+\) \(\d+-\d+-\d+\)$"
PREFIX_RE = r"^## \[lts-[0-9.]+\]" + TAIL_RE
NOPREFIX_RE = r"^###? \[[0-9.]+\]" + TAIL_RE


def main():
    with open(sys.argv[2]) as f:
        for l in f:
            if sys.argv[1] == "remove-prefix":
                if re.match(PREFIX_RE, l):
                    l = re.sub(r"\[lts-([0-9.]+)\]", r"[\1]", l)
            elif sys.argv[1] == "add-prefix":
                if re.match(NOPREFIX_RE, l):
                    l = re.sub(r"\[([0-9.]+)\]", r"[lts-\1]", l)
                    # stadard-version generates "###", while change-log.md uses "##"
                    l = l.replace("### ", "## ")
            else:
                assert sys.argv[1], "'add-prefix' or 'remove-prefix' expected"
            sys.stdout.write(l)


if __name__ == "__main__":
    main()
