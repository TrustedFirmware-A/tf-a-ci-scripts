#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Expect script for monitoring the results of the TFA event log hash
# verification script
#

set mismatched_marker "MISMATCH"
set missing_marker "not found"

set compare_hash_path $env(ci_root)
append compare_hash_path "/script/verify_hashes.py"

set hash_verification_output [exec python3 $compare_hash_path 2>@1]
puts $hash_verification_output
if {[regexp $mismatched_marker|$missing_marker $hash_verification_output]} {
    message "Hash mismatch or missing hash detected"
    exit_uart -1
}
