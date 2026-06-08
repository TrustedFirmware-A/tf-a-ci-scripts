#
# Copyright (c) 2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Expect script for Trusted Firmware Test Framework
#

expect_string "elr_el3"
expect_string "esr_el3"
expect_string "mpidr_el1"
expect_string "sp_el0"
expect_string "isr_el1"
expect_string "icc_hppir0_el1"
expect_string "icc_hppir1_el1"
expect_string "icc_ctlr_el3"
