#
# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with an Buildroot file system
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string+=('i;Run /sbin/init')
expect_string+=("i;buildroot login:")
expect_string+=("i;#;;;root")
expect_string+=('i;(Power down|System halted);;;poweroff')
expect_string+=('i;;;;@')
