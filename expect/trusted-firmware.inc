#
# Copyright (c) 2019-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with AArch64 Trusted Firmware-A.
#
# This script is not standalone and should be sourced by a top expect script.
#

set TFA_EVENT_LOG [get_param tfa_log "tfa_event_log"]

# Initial boot message won't be present if we're starting at BL31. Skip waiting
# for them by inspecting the environment variable 'skip_early_boot_msgs'.
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

	# Capture the event log from TF-A if we are running with measured boot
	# enabled.
	if {[info exists ::env(measured_boot)] || [info exists ::env(verify_hashes)]} {
		capture_log $TFA_EVENT_LOG "BL1: Booting BL31|Finished using crypto library"
	} else {
		expect_string "BL1: Booting BL31"
	}
} else {
	message "Skipping early boot messages from BL1 and BL2"
	if {[info exists ::env(verify_hashes)]} {
		capture_log $TFA_EVENT_LOG "BL1: Booting BL31|BL2: Booting BL31|Finished using crypto library"
	}
}
