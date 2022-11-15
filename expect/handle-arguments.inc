#
# Copyright (c) 2019-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to handle the arguments and initialise the expect session.
#
# This script is not standalone and should be sourced by a top expect script.

source [file join [file dirname [info script]] utils.inc]

# Store environment variables into local variables
set timeout [get_param timeout 30]

if { [postprocessing] != 1 } {
    # Open a Telnet connection to the required UART port
    set uart_port [get_param uart_port]
    set telnet_pid [spawn telnet localhost $uart_port]
} else {
    # Read directly from the UART log file
    set uart_log_file [get_param uart_log_file]
    set telnet_pid [spawn cat $uart_log_file]
}

expect_after {
    eof {
        puts "<<stream closed prematurely, exiting>>"
        exit -1
    }

    timeout {
        exit_timeout
    }
}
