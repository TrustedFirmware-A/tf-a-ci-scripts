#!/usr/bin/env python3
#
# Copyright (c) 2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# Script to prepare a textual body of a comment to pass on the command line
# to Gerrit: limit it to acceptable size and quote properly.

import sys
import shlex


SIZE_LIMIT = 16000


body = ""

with open(sys.argv[1], "r") as f:
    for l in f:
        body += l
        if len(body) >= SIZE_LIMIT:
            body += """\
[...]

WARNING: The report was trimmed due to size limit of a Gerrit comment.
Follow the link at the beginning to see the full report.
"""
            break

sys.stdout.write(shlex.quote(body))
