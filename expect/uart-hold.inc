#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# If we exit from the UART when any of the model's UARTs receive lots of prints
# then the model will stall, so we either wait for the UART to close naturally
# or we wait for somebody to explicitly tell us to exit.
#
# https://jira.arm.com/browse/SDDKW-43675
#

set timeout -1

source [file join [file dirname [info script]] terminable.inc]

puts "<<test complete, waiting for EOF or SIGINT>>"
expect eof
