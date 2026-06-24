#!/usr/bin/env awk

#
# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This is a script to categorize tests within this repo by type. This script is
# intended to be run with the output of `find group -type f`, run from within
# the root directory of this repo piped into it. See the bash script with the
# same name for an usage example.

BEGIN {
	# We're breaking records upon the "/" character so that we can have an
	# aggregation that's keyed by test group, if we want to.
	FS = "/";

	categories[0] = "\"L1\"";
	categories[1] = "\"L2\"";
	categories[2] = "\"L3\"";
	categories[3] = "\"Release\"";
	categories[4] = "\"Disabled\"";
}

# Here we filter out any records without exactly 3 fields (i.e. 3-level paths)
# and categorize the rest.
NF == 3 {
	if (/-l1/) {
		category = 0;
	} else if (/-l2/) {
		category = 1;
	} else if (/-l3/) {
		category = 2;
	} else if (/-unstable/) {
		category = 4;
	} else {
		category = 3;
	}

	# Each of these categorizes a test into a category, based on a regular
	# expression. When you add another test category, you should also add
	# printing to the print group loop below.
	if (/linux/ || /uboot/ || /edk2/ || /:fvp-([a-z0-9.]-)*spm/ || /:juno-([a-z0-9.]-)*scmi/) {
		integration[category] += 1;
	} else if (/tftf/) {
		component[category] += 1;
	} else if (/scan_build/) {
		static[category] += 1;
	} else if (/:nil/ || /norun/) {
		build[category] += 1;
	} else {
		print $0 " No test category; excluding from data" >> "/dev/stderr";
	}
}

END {
	for (category = 0; category in categories; category++) {
		# This prints a single test group, by name. When you add another
		# category (with another map), add another field to this print.
		printf("%s	%d	%d	%d	%d\n",
			categories[category],
			build[category],
			static[category],
			component[category],
			integration[category]);
	}
}
