#
# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with a Busybox filesystem
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string+=('i;init.sh')
expect_string+=('i;.* # ')
expect_string+=('i;;;;@')
