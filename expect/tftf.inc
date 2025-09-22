#
# Copyright (c) 2023-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Expect script for Trusted Firmware Test Framework
#

expect_string "Booting trusted firmware test framework" "TFTF is booting"

expect_re "Running at NS-EL(1|2)"

# Compares event log of TF-A in BL2 against event logs of BL32 and BL33
# currently not available for all measured boot tests
if {[info exists ::env(measured_boot)]} {
    capture_and_compare_log tftf_event_log "TEST COMPLETE" $TFA_EVENT_LOG
}

set uart_return_value ""
expect {
	"Tests Failed  : 0" {
		expect_string "Exiting tests." "all TFTF tests passed"
		set uart_return_value 0
	}
	"Tests Passed  : 0" {
		expect_string "Exiting tests." "no TFTF tests passed"
		set uart_return_value -1
	}
	-re "Tests Failed  : \[^0]" {
		expect_string "Exiting tests." "one or more TFTF tests failed"
		set uart_return_value -1
	}
}

# Verifies the hashes in the TF-A event log for measured boot tests
if {[info exists ::env(verify_hashes)]} {
	message "Starting measured boot hash verification"
	source [file join [file dirname [info script]] compare_hashes.inc]
}

exit_uart $uart_return_value
