#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with an OpenEmbedded file system
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string "INIT:" "Linux is booting"
expect_string "root@genericarmv8:~#" "Linux reached the root prompt"
send "shutdown -h now\r"

expect_re "(Power down|System halted)" "Linux shut down successfully"
exit_uart 0
