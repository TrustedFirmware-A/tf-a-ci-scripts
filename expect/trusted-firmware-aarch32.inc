#
# Copyright (c) 2019-2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with AArch32 Trusted Firmware-A.
#
# This script is not standalone and should be sourced by a top expect script.
#

# Initial boot message won't be present if we're starting at SP_MIN. Skip
# waiting for them by inspecting the environment variable
# 'skip_early_boot_msgs'.
if {![info exists ::env(skip_early_boot_msgs)]} {
	expect_string "Booting Trusted Firmware"

	expect {
		"BL1: Booting BL2" { message "BL2 booting" }

		# Catch all 3 possible BL2 loading error messages, namely:
		#   "Failure in pre image load handling of BL2"
		#   "Failed to load BL2 firmware."
		#   "Failure in post image load handling of BL2"
		-re "Fail.*load.*BL2" {
			message "BL2 loading error"
			exit_uart -1
		}
	    }

	expect_string "BL1: Booting BL32"
} else {
	message "Skipping early boot messages from BL1 and BL2"
}

expect_string "SP_MIN:" "SP_MIN is booting"
