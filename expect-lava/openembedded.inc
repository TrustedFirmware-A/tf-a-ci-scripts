#
# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with an OpenEmbedded file system
#
# This script is not standalone and should be sourced by a top expect script.
#

expect_string+=('i;INIT:')
expect_string+=('i;root@genericarmv8:~#')
expect_string+=('i;(Power down|System halted);;;shutdown -h now')
expect_string+=('i;;;;@')
