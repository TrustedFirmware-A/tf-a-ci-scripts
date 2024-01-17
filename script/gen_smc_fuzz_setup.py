# !/usr/bin/env python
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Script to generate the header file compiled into fuzzer for creating
# the various enum values used to identify the specific fuzzer function called.
# This is intended to replace the orignal string output of the fuzzer.
# There are two arguments...  one to specify the device tree file input to the fuzzer
# and the other to give the name and path of the header file.

import re
import argparse

parser = argparse.ArgumentParser(
                    prog='gen_smc_fuzz_setup',
                    description='Creates a header file to assign enum values to fuzzing function names',
                    epilog='Two argument input')

parser.add_argument('-dts', '--devtree',help="Device tree file to analyze .")
parser.add_argument('-hdf', '--headfile',help="Header file to create .")

args = parser.parse_args()

addresses = {}
numl = 1
dt_file = open(args.devtree, "r")
hdr_file = open(args.headfile, "w")
dt_lines = dt_file.readlines()
dt_file.close()
for line in dt_lines:
    if "functionname" in line:
        grp = re.search(r'functionname\s*=\s*\"(\w+)\"',line)
        fnme = grp.group(1)
        if fnme not in addresses:
            addresses[fnme] = 1;
            print("#define", fnme, numl,file=hdr_file)
            numl = numl + 1
hdr_file.close()
