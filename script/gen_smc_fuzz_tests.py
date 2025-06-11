# !/usr/bin/env python
#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#


#python3 gen_smc_fuzz_tests.py -n <number of tests>
#This script generates the tftf config and group files for fuzzing
import argparse
import random

parser = argparse.ArgumentParser(
                prog='gen_smc_fuzz_tests.py',
                description='Generates the tftf config and group files for fuzzing tests in CI',
                epilog='one argument input')

parser.add_argument('-n', '--numtests',help="number of tests")

args = parser.parse_args()

print("starting fuzzing generation of tests for CI")

gitadd = "git add "

for i in range(int(args.numtests)):
	rnum = str(hex(random.randint(1, 100000000)))
	tftfconfilename = "fvp-smcfuzzing_" + rnum
	tftfconfilenamepath = "../tftf_config/" + tftfconfilename
	configfile = open(tftfconfilenamepath, "w")
	cline = "CROSS_COMPILE=aarch64-none-elf-\n"
	cline += "PLAT=fvp\n"
	cline += "TESTS=smcfuzzing\n"
	cline += "SMC_FUZZING=1\n"
	cline += "SMC_FUZZ_DTS=smc_fuzz/dts/sdei_coverage.dts\n"
	cline += "SMC_FUZZER_DEBUG=1\n"
	cline += "SMC_FUZZ_SANITY_LEVEL=3\n"
	cline += "SMC_FUZZ_CALLS_PER_INSTANCE=10000\n"
	cline += "SMC_FUZZ_DEFFILE=sdei_and_vendor_smc_calls.txt\n"
	cline += "SMC_FUZZ_SEEDS=" + rnum
	configfile.write(cline)
	configfile.close()
	groupfile = "fvp-aarch64-sdei," + tftfconfilename + ":fvp-tftf-fip.tftf-aemv8a-tftf.fuzz"
	groupfilepath = "../group/tf-l3-fuzzing/" + groupfile
	gfile = open(groupfilepath, "w")
	gline = "#\n"
	gline += "# Copyright (c) 2025, Arm Limited. All rights reserved.\n"
	gline += "#\n"
	gline += "# SPDX-License-Identifier: BSD-3-Clause\n"
	gline += "#\n"
	gfile.write(gline)
	gfile.close()
	gitadd += "./tftf_config/" + tftfconfilename + " "
	gitadd += "./group/tf-l3-fuzzing/" + groupfile + " "
gaddcom = open("../gitadd", "w")
gaddcom.write(gitadd)
gaddcom.close()
