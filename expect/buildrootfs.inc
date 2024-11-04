#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with an Buildroot file system
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string "Run /sbin/init as init process" "Linux is booting"
expect_string "buildroot login:" "Linux reached the login prompt"
send "root\r"
expect_re "# " "Linux reached the root prompt"
send "poweroff\r"

expect_re "(Power down|System halted)" "Linux shut down successfully"
exit_uart 0
