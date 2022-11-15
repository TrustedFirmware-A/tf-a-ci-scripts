#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with a Busybox filesystem
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string "init.sh" "Linux is booting"
expect_re ".* # " "Linux reached the root prompt"
exit_uart 0
