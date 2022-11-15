#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

puts "<<test completed, waiting for EOF or timeout>>"

expect {
    "Exiting tests." {
        puts "<<expected hang, found TFTF completion>>"
    }

    "PANIC in EL3." {
        puts "<<expected hang, found crash dump>>"
    }

    "Unhandled Exception in EL3." {
        puts "<<expected hang, found crash dump>>"
    }

    "Unhandled Exception from EL" {
        puts "<<expected hang, found crash dump>>"
    }

    eof {
        puts "<<stream closed as expected, exiting>>"
        exit 0
    }

    timeout {
        puts "<<timeout triggered as expected, exiting>>"
        exit_uart 0
    }
}

exit_uart -1
