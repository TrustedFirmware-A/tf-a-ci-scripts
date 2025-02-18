#
# Copyright (c) 2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Expect script for Trusted Firmware Test Framework
#

expect_string "Booting trusted firmware test framework" "TFTF is booting"

expect_re "Running at NS-EL(1|2)"

if {[info exists ::env(measured_boot)]} {
    capture_and_compare_log tftf_event_log "TEST COMPLETE" tfa_event_log
}

expect {
	"Tests Failed  : 0" {
		expect_string "Exiting tests." "all TFTF tests passed"
		exit_uart 0
	}
	"Tests Passed  : 0" {
		expect_string "Exiting tests." "no TFTF tests passed"
		exit_uart -1
	}
	-re "Tests Failed  : \[^0]" {
		expect_string "Exiting tests." "one or more TFTF tests failed"
		exit_uart -1
	}
}
