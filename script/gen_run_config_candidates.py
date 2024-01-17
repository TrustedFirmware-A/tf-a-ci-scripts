#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Output to stdout the chosen run configuration fragments for a given run
# configuration. With -p, the script prints all fragments considered without
# validating whether it exists.

import argparse
import os
import sys

parser = argparse.ArgumentParser(description="Choose run configurations")
parser.add_argument("--print-only", "-p", action="store_true", default=False,
        help="Print only; don't check for matching run configs.")
parser.add_argument("--unit-testing", action="store_true", default=False,
        help="Use to indicate if it is a unit testing config or not")
parser.add_argument("args", nargs=argparse.REMAINDER, help="Run configuration")
opts = parser.parse_args()

if len(opts.args) != 1:
    raise Exception("Exactly one argument expected")

# Obtain path to run_config directory
script_root = os.path.dirname(os.path.abspath(sys.argv[0]))
if (not opts.unit_testing):
    run_config_dir = os.path.join(script_root, os.pardir, "run_config")
else:
    run_config_dir = os.path.join(script_root, os.pardir, "run_config_tfut")

arg = opts.args[0]
run_config = arg.split(":")[-1]
if not run_config:
    raise Exception("Couldn't extract run config from " + arg)

if run_config == "nil":
    sys.exit(0)

fragments = run_config.split("-")
if 'bmcov' in fragments:
    fragments.remove('bmcov')
exit_code = 0

# Stems are fragments, except with everything after dot removed.
stems = list(map(lambda f: f.split(".")[0], fragments))

# Consider each fragment in turn
for frag_idx, chosen_fragment in enumerate(fragments):
    # Choose all stems upto the current fragment
    chosen = ["-".join(stems[0:i] + [chosen_fragment])
            for i in range(frag_idx + 1)]

    for i, fragment in enumerate(reversed(chosen)):
        if opts.print_only:
            print(fragment)
        else:
            # Output only if a matching run config exists
            if os.path.isfile(os.path.join(run_config_dir, fragment)):
                # Stop looking for generic once a specific fragment is found
                print(fragment)
                break
    else:
        # Ignore if the first fragment doesn't exist, which is usually the
        # platform name. Otherwise, print a warning for not finding matches for
        # the fragment.
        if (not opts.print_only) and (i > 0):
            print("warning: {}: no matches for fragment '{}'".format(
                arg, fragment), file=sys.stderr)
            exit_code = 1
sys.exit(exit_code)
