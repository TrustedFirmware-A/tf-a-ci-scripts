#
# Copyright (c) 2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

trap {
    puts "<<received SIGINT, exiting>>"
    exit_uart 0
} SIGINT
