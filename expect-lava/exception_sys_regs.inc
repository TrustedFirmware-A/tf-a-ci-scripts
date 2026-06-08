#
# Copyright (c) 2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Expect script for Trusted Firmware Test Framework
#

expect_string+=("i;elr_el3")
expect_string+=("i;esr_el3")
expect_string+=("i;mpidr_el1")
expect_string+=("i;sp_el0")
expect_string+=("i;isr_el1")
expect_string+=("i;icc_hppir0_el1")
expect_string+=("i;icc_hppir1_el1")
expect_string+=("i;icc_ctlr_el3")
