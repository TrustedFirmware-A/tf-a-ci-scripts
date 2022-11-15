#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with a Linux kernel
#
# This script is not standalone and should be sourced by a top expect script.
#

# Expect 8 CPUs in total by default
if {[info exists ::env(num_cpus)]} {
	set num_cpus $env(num_cpus)
} else {
	set num_cpus 8
}

expect_string "Linux version" "Linux printed its version"
expect_re "SMP: Total of $num_cpus processors activated" "Linux successfully brought up all secondary cores"
expect_string "Freeing unused kernel memory" "Linux booted successfully"
